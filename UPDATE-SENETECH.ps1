param(
    [Parameter(Mandatory=$false)]
    [string]$CurrentVersion = "1.4.2.0",

    [Parameter(Mandatory=$false)]
    [string]$InstallDir = (Split-Path -Parent $MyInvocation.MyCommand.Path),

    [Parameter(Mandatory=$false)]
    [int]$WaitForProcessId = 0,

    [Parameter(Mandatory=$false)]
    [switch]$NoRestart
)

$ErrorActionPreference = "Stop"
$ManifestUrl = "https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/main/version.json"
$TempRoot = Join-Path $env:TEMP "SENETECH-Update"
$ZipPath = Join-Path $TempRoot "SENETECH-update.zip"
$StageDir = Join-Path $TempRoot "stage"
$LogPath = Join-Path $env:TEMP "SENETECH-Update.log"

function Reset-LogIfNeeded {
    try {
        if (Test-Path $LogPath) {
            $log = Get-Item $LogPath -ErrorAction Stop
            if ($log.Length -gt 1048576) {
                Remove-Item $LogPath -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {}
}

function Write-Log([string]$Message) {
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$stamp] $Message"
    Write-Host $line
    try { Add-Content -Path $LogPath -Value $line -Encoding UTF8 } catch {}
}

function Get-RemoteManifest {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    } catch {}

    $headers = @{ "User-Agent" = "SENETECH-Setup/$CurrentVersion" }
    return Invoke-RestMethod -Uri $ManifestUrl -Headers $headers -UseBasicParsing
}

function Get-Sha256([string]$Path) {
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $bytes = $sha.ComputeHash($stream)
            return ([System.BitConverter]::ToString($bytes)).Replace("-", "").ToLowerInvariant()
        }
        finally {
            $sha.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

Reset-LogIfNeeded

try {
    Write-Log "Verification des mises a jour SENETECH..."
    $manifest = Get-RemoteManifest

    if (-not $manifest.enabled) {
        Write-Log "Les mises a jour distantes sont actuellement desactivees."
        exit 0
    }

    $local = New-Object System.Version($CurrentVersion)
    $remote = New-Object System.Version([string]$manifest.version)

    if ($remote -le $local) {
        Write-Log "SENETECH est deja a jour ($CurrentVersion)."
        exit 0
    }

    if ([string]::IsNullOrWhiteSpace([string]$manifest.downloadUrl)) {
        throw "Aucune URL de telechargement n'est definie pour la version $($manifest.version)."
    }

    # Toujours repartir d'un dossier temporaire propre pour eviter l'accumulation.
    if (Test-Path $TempRoot) {
        Remove-Item $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $TempRoot | Out-Null
    New-Item -ItemType Directory -Path $StageDir | Out-Null

    Write-Log "Nouvelle version detectee : $($manifest.version)"
    Write-Log "Telechargement de la mise a jour..."
    $headers = @{ "User-Agent" = "SENETECH-Setup/$CurrentVersion" }
    Invoke-WebRequest -Uri ([string]$manifest.downloadUrl) -Headers $headers -OutFile $ZipPath -UseBasicParsing

    if (-not [string]::IsNullOrWhiteSpace([string]$manifest.sha256)) {
        $actualHash = Get-Sha256 -Path $ZipPath
        $expectedHash = ([string]$manifest.sha256).ToLowerInvariant()
        if ($actualHash -ne $expectedHash) {
            throw "Le SHA-256 du fichier telecharge ne correspond pas au manifeste. Mise a jour annulee."
        }
        Write-Log "Verification SHA-256 OK."
    }

    Write-Log "Extraction de la mise a jour..."
    if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
        Expand-Archive -Path $ZipPath -DestinationPath $StageDir -Force
    } else {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $StageDir)
    }

    # Le ZIP n'est plus utile une fois extrait.
    Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue

    $ApplyScript = Join-Path $TempRoot "APPLY-SENETECH-UPDATE.cmd"
    $restartLine = ""
    if (-not $NoRestart) {
        $restartLine = 'start "" "' + (Join-Path $InstallDir "SENETECH-Setup.exe") + '"'
    }

    $waitBlock = ""
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

    # Un second CMD supprime le dossier temporaire apres l'installation,
    # afin que les anciennes MAJ ne restent jamais sur le PC.
    $cleanupLine = 'start "" /b cmd.exe /c "ping 127.0.0.1 -n 5 >nul & rd /s /q ""' + $TempRoot + '"""'

    $cmd = @"
@echo off
setlocal
$waitBlock
ping 127.0.0.1 -n 2 >nul
xcopy "$StageDir\*" "$InstallDir\" /E /I /Y /Q >nul
$restartLine
$cleanupLine
exit /b 0
"@
    Set-Content -Path $ApplyScript -Value $cmd -Encoding ASCII

    Write-Log "Mise a jour prete a etre appliquee."
    Start-Process -FilePath $ApplyScript -WindowStyle Hidden
    exit 10
}
catch {
    Write-Log "ERREUR: $($_.Exception.Message)"
    try {
        if (Test-Path $TempRoot) {
            Remove-Item $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    } catch {}
    exit 1
}
