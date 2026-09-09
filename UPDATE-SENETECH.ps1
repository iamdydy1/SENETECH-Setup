param(
    [Parameter(Mandatory=$false)]
    [string]$CurrentVersion = "1.3.0.0",

    [Parameter(Mandatory=$false)]
    [string]$InstallDir = (Split-Path -Parent $MyInvocation.MyCommand.Path)
)

$ErrorActionPreference = "Stop"
$ManifestUrl = "https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/main/version.json"
$TempRoot = Join-Path $env:TEMP "SENETECH-Update"
$ZipPath = Join-Path $TempRoot "SENETECH-update.zip"
$StageDir = Join-Path $TempRoot "stage"

function Write-Log([string]$Message) {
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$stamp] $Message"
}

try {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    } catch {}

    Write-Log "Verification des mises a jour SENETECH..."
    $manifest = Invoke-RestMethod -Uri $ManifestUrl -UseBasicParsing

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
        throw "Aucune URL de telechargement n'est definie dans version.json."
    }

    if (Test-Path $TempRoot) {
        Remove-Item $TempRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $TempRoot | Out-Null
    New-Item -ItemType Directory -Path $StageDir | Out-Null

    Write-Log "Nouvelle version detectee : $($manifest.version)"
    Write-Log "Telechargement..."
    Invoke-WebRequest -Uri $manifest.downloadUrl -OutFile $ZipPath -UseBasicParsing

    if (-not [string]::IsNullOrWhiteSpace([string]$manifest.sha256)) {
        $actualHash = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
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

    $ApplyScript = Join-Path $TempRoot "APPLY-SENETECH-UPDATE.cmd"
    $cmd = @"
@echo off
setlocal
ping 127.0.0.1 -n 3 >nul
xcopy "$StageDir\*" "$InstallDir\" /E /I /Y /Q >nul
start "" "$InstallDir\SENETECH-Setup.exe"
exit /b 0
"@
    Set-Content -Path $ApplyScript -Value $cmd -Encoding ASCII

    Write-Log "Mise a jour prete. SENETECH va etre remplace puis relance."
    Start-Process -FilePath $ApplyScript -WindowStyle Hidden
    exit 10
}
catch {
    Write-Log "ERREUR: $($_.Exception.Message)"
    exit 1
}
