param(
    [string]$CurrentVersion = '0.0.0.0',
    [ValidateSet('stable','develop')][string]$UpdateChannel = 'stable',
    [string]$InstallDir = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [int]$WaitForProcessId = 0,
    [switch]$CheckOnly,
    [switch]$NoRestart
)

# SENETECH future Inno updater.
# This file is intentionally kept separate from the active legacy updater
# until the first full Inno installer has passed Windows installation tests.

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

$Repo = 'iamdydy1/SENETECH-Setup'
$ApiBase = "https://api.github.com/repos/$Repo"
$LogDir = Join-Path $env:ProgramData 'SENETECH\Logs'
$LogPath = Join-Path $LogDir 'SENETECH-Inno-Updater.log'
$TempRoot = Join-Path $env:TEMP 'SENETECH-Inno-Update'
$ManifestPath = Join-Path $TempRoot 'installer-manifest.json'
$InstallerPath = Join-Path $TempRoot 'SENETECH-Update.exe'

function Write-InnoUpdateLog([string]$Message) {
    try {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
        $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$UpdateChannel.ToUpperInvariant(),$Message
        Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
    } catch { }
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
        finally { $sha.Dispose() }
    } finally { $stream.Dispose() }
}

function New-NonceUrl([string]$Url) {
    $nonce = [guid]::NewGuid().ToString('N')
    $sep = if ($Url.Contains('?')) { '&' } else { '?' }
    return ($Url + $sep + 'senetech=' + $nonce)
}

function Download-File([string]$Url,[string]$Destination,[int]$TimeoutSec=120) {
    if ([string]::IsNullOrWhiteSpace($Url) -or -not $Url.StartsWith('https://',[StringComparison]::OrdinalIgnoreCase)) {
        throw "Refused non-HTTPS URL: $Url"
    }
    $parent = Split-Path -Parent $Destination
    if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $headers = @{ 'User-Agent' = "SENETECH-Setup/$CurrentVersion"; 'Cache-Control'='no-cache'; 'Pragma'='no-cache' }
    Invoke-WebRequest -UseBasicParsing -Uri (New-NonceUrl $Url) -Headers $headers -OutFile $Destination -TimeoutSec $TimeoutSec
    if (-not (Test-Path -LiteralPath $Destination)) { throw "Download missing: $Url" }
}

function Get-LatestSenetechRelease {
    $headers = @{ 'User-Agent' = "SENETECH-Setup/$CurrentVersion"; 'Accept'='application/vnd.github+json'; 'Cache-Control'='no-cache' }
    $url = New-NonceUrl "$ApiBase/releases?per_page=30"
    $releases = @(Invoke-RestMethod -UseBasicParsing -Uri $url -Headers $headers -TimeoutSec 30)

    if ($UpdateChannel -eq 'develop') {
        $match = @($releases | Where-Object {
            -not [bool]$_.draft -and [bool]$_.prerelease -and ([string]$_.tag_name -like 'dev-v*')
        } | Sort-Object {[datetime]$_.published_at} -Descending | Select-Object -First 1)
    } else {
        $match = @($releases | Where-Object {
            -not [bool]$_.draft -and -not [bool]$_.prerelease -and
            (([string]$_.tag_name -like 'stable-v*') -or ([string]$_.name -like '*STABLE*'))
        } | Sort-Object {[datetime]$_.published_at} -Descending | Select-Object -First 1)
    }

    if ($match.Count -eq 0) { return $null }
    return $match[0]
}

function Get-Asset($Release,[string]$Name) {
    return @($Release.assets | Where-Object { [string]$_.name -eq $Name } | Select-Object -First 1)
}

function Wait-ForSenetechExit([int]$Pid,[int]$TimeoutSeconds=45) {
    if ($Pid -le 0) { return }
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $p = Get-Process -Id $Pid -ErrorAction SilentlyContinue
        if (-not $p) { return }
        Start-Sleep -Milliseconds 500
    }
    throw "SENETECH process $Pid did not exit within $TimeoutSeconds seconds."
}

function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

Write-InnoUpdateLog "Inno updater start. Current=$CurrentVersion InstallDir=$InstallDir"

try {
    $release = Get-LatestSenetechRelease
    if (-not $release) {
        Write-InnoUpdateLog 'No compatible GitHub Release found.'
        exit 0
    }

    Write-InnoUpdateLog ("Selected release: {0}" -f [string]$release.tag_name)

    $manifestAsset = Get-Asset $release 'installer-manifest.json'
    if ($manifestAsset.Count -eq 0) { throw 'installer-manifest.json asset missing from release.' }

    Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null

    Download-File ([string]$manifestAsset[0].browser_download_url) $ManifestPath 45
    $manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

    if ([string]$manifest.packageType -ne 'inno') { throw 'Release packageType is not inno.' }
    if ([string]$manifest.channel -ne $UpdateChannel) { throw "Release channel mismatch: $($manifest.channel)" }
    if ([string]::IsNullOrWhiteSpace([string]$manifest.fileName)) { throw 'Installer fileName missing.' }
    if ([string]::IsNullOrWhiteSpace([string]$manifest.sha256)) { throw 'Installer SHA-256 missing.' }

    $localVersion = New-Object System.Version($CurrentVersion)
    $remoteVersion = New-Object System.Version([string]$manifest.version)
    if ($remoteVersion -le $localVersion) {
        Write-InnoUpdateLog ("Already current. Remote={0}" -f $remoteVersion)
        exit 0
    }

    $installerAsset = Get-Asset $release ([string]$manifest.fileName)
    if ($installerAsset.Count -eq 0) { throw "Installer asset missing: $($manifest.fileName)" }

    Write-InnoUpdateLog ("Update available: {0} -> {1}" -f $localVersion,$remoteVersion)
    if ($CheckOnly) {
        Write-Output ([pscustomobject]@{
            UpdateAvailable = $true
            CurrentVersion = $localVersion.ToString()
            Version = $remoteVersion.ToString()
            Channel = $UpdateChannel
            Tag = [string]$release.tag_name
            FileName = [string]$manifest.fileName
            Size = [int64]$manifest.size
            Sha256 = [string]$manifest.sha256
        })
        exit 10
    }

    Download-File ([string]$installerAsset[0].browser_download_url) $InstallerPath 180

    if ([int64]$manifest.size -gt 0) {
        $actualSize = (Get-Item -LiteralPath $InstallerPath).Length
        if ($actualSize -ne [int64]$manifest.size) {
            throw "Installer size mismatch. expected=$($manifest.size) actual=$actualSize"
        }
    }

    $actualHash = Get-Sha256 $InstallerPath
    if ($actualHash -ne ([string]$manifest.sha256).ToLowerInvariant()) {
        throw "Installer SHA-256 mismatch. actual=$actualHash"
    }
    Write-InnoUpdateLog 'Installer size/SHA-256 verification OK.'

    # Do not wait for the running SENETECH process here. The application may be
    # synchronously waiting for this updater to finish. Inno Setup owns the
    # shutdown with /CLOSEAPPLICATIONS, then performs the in-place replacement.
    Write-InnoUpdateLog ("Launching Inno; running SENETECH pid hint={0}" -f $WaitForProcessId)

    $arguments = @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/CLOSEAPPLICATIONS')
    if (Test-IsAdministrator) {
        $p = Start-Process -FilePath $InstallerPath -ArgumentList $arguments -PassThru -Wait
    } else {
        $p = Start-Process -FilePath $InstallerPath -ArgumentList $arguments -Verb RunAs -PassThru -Wait
    }
    if ($p.ExitCode -ne 0) { throw "Inno Setup failed with exit code $($p.ExitCode)." }

    Write-InnoUpdateLog ("Inno installation completed: {0}" -f $remoteVersion)

    $app = Join-Path $InstallDir 'SENETECH-Setup.exe'
    if (-not $NoRestart -and (Test-Path -LiteralPath $app)) {
        Start-Process -FilePath $app -WorkingDirectory $InstallDir
        Write-InnoUpdateLog 'SENETECH restarted.'
    }

    Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    exit 0
} catch {
    Write-InnoUpdateLog ("ERROR: " + $_.Exception.Message)
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        [System.Windows.MessageBox]::Show(
            ("La mise a jour SENETECH via Inno Setup a echoue.`r`n`r`n" + $_.Exception.Message + "`r`n`r`nJournal : $LogPath"),
            'SENETECH - Mise a jour',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    } catch { }
    exit 1
}
