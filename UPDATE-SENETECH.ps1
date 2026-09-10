param(
    [string]$CurrentVersion = '1.5.1.0',
    [string]$InstallDir = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [string]$UpdateChannel = 'stable',
    [int]$WaitForProcessId = 0,
    [switch]$NoRestart
)

$ErrorActionPreference = 'Stop'
$UpdateChannel = if (([string]$UpdateChannel).ToLowerInvariant() -eq 'develop') { 'develop' } else { 'stable' }
$UpdateBranch = if ($UpdateChannel -eq 'develop') { 'develop' } else { 'main' }
$ManifestUrl = "https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/$UpdateBranch/version.json"
$TempRoot = Join-Path $env:TEMP 'SENETECH-Update'
$ZipPath = Join-Path $TempRoot 'SENETECH-package.zip'
$StageDir = Join-Path $TempRoot 'stage'
$LogPath = Join-Path $env:TEMP 'SENETECH-Update.log'
$CleanupScript = Join-Path $env:TEMP 'SENETECH-Cleanup.cmd'

function Write-Log([string]$Text) {
    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $UpdateChannel.ToUpperInvariant(), $Text
    try {
        if (Test-Path $LogPath) {
            $info = Get-Item $LogPath -ErrorAction SilentlyContinue
            if ($info -and $info.Length -gt 1MB) { Remove-Item $LogPath -Force -ErrorAction SilentlyContinue }
        }
        Add-Content -Path $LogPath -Value $line -Encoding UTF8
    } catch {}
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
        finally { $sha.Dispose() }
    } finally { $stream.Dispose() }
}

try {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
    $headers = @{ 'User-Agent' = "SENETECH-Setup/$CurrentVersion" }

    Write-Log "Checking $ManifestUrl"
    $manifest = Invoke-RestMethod -Uri $ManifestUrl -Headers $headers -UseBasicParsing

    if (-not $manifest.enabled) { Write-Log 'Update service disabled.'; exit 0 }

    $local = New-Object System.Version($CurrentVersion)
    $remote = New-Object System.Version([string]$manifest.version)
    if ($remote -le $local) { Write-Log "Already current: $CurrentVersion"; exit 0 }

    $downloadUrl = [string]$manifest.downloadUrl
    if ([string]::IsNullOrWhiteSpace($downloadUrl)) { throw 'No downloadUrl is defined in version.json.' }
    if (-not $downloadUrl.StartsWith('https://', [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Update download URL must use HTTPS.' }
    if ([string]::IsNullOrWhiteSpace([string]$manifest.sha256)) { throw 'No SHA-256 is defined in version.json.' }

    Remove-Item $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $CleanupScript -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $StageDir -Force | Out-Null

    Write-Log "Downloading SENETECH $($manifest.version)"
    Invoke-WebRequest -Uri $downloadUrl -Headers $headers -OutFile $ZipPath -UseBasicParsing

    if ($manifest.PSObject.Properties.Name -contains 'packageSize') {
        $expectedSize = [int64]$manifest.packageSize
        if ($expectedSize -gt 0) {
            $actualSize = (Get-Item -LiteralPath $ZipPath).Length
            if ($actualSize -ne $expectedSize) { throw "Package size mismatch: $actualSize bytes" }
            Write-Log "Package size verification OK: $actualSize bytes."
        }
    }

    $actualHash = Get-Sha256 $ZipPath
    $expectedHash = ([string]$manifest.sha256).ToLowerInvariant()
    if ($actualHash -ne $expectedHash) { throw "Package SHA-256 mismatch: $actualHash" }
    Write-Log 'SHA-256 verification OK.'

    if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
        Expand-Archive -Path $ZipPath -DestinationPath $StageDir -Force
    } else {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $StageDir)
    }
    Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue

    $required = @(
        'SENETECH-Setup.exe',
        '_SENETECH\SENETECH-Setup.ps1',
        '_SENETECH\SENETECH-Setup.manifest'
    )
    foreach ($relative in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $StageDir $relative))) {
            throw "Incomplete SENETECH package: missing $relative"
        }
    }

    $waitBlock = ''
    if ($WaitForProcessId -gt 0) {
        $waitBlock = @"
:WAIT_FOR_SENETECH
tasklist /FI "PID eq $WaitForProcessId" /NH | find "$WaitForProcessId" >nul
if not errorlevel 1 (
  ping 127.0.0.1 -n 2 >nul
  goto WAIT_FOR_SENETECH
)
"@
    }

    $restartLine = ''
    if (-not $NoRestart) {
        $exePath = Join-Path $InstallDir 'SENETECH-Setup.exe'
        $restartLine = 'start "" "' + $exePath + '"'
    }

    $cleanupText = @"
@echo off
ping 127.0.0.1 -n 5 >nul
rd /s /q "$TempRoot" 2>nul
del /f /q "%~f0" >nul 2>&1
"@
    Set-Content -Path $CleanupScript -Value $cleanupText -Encoding ASCII

    $applyScript = Join-Path $TempRoot 'APPLY-SENETECH-UPDATE.cmd'
    $applyText = @"
@echo off
setlocal
$waitBlock
ping 127.0.0.1 -n 2 >nul
if not exist "$InstallDir" mkdir "$InstallDir" >nul 2>&1
xcopy "$StageDir\*" "$InstallDir\" /E /I /Y /Q >nul
if errorlevel 1 exit /b 1
$restartLine
start "" /b "$CleanupScript"
exit /b 0
"@
    Set-Content -Path $applyScript -Value $applyText -Encoding ASCII

    Write-Log 'Package ready. Applying update.'
    Start-Process -FilePath $applyScript -WindowStyle Hidden
    exit 10
}
catch {
    Write-Log ('ERROR: ' + $_.Exception.Message)
    try { Remove-Item $TempRoot -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    exit 1
}
