param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$enginePath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.ps1'
$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
$versionPath = Join-Path $StageDir 'VERSION.txt'

if (-not (Test-Path -LiteralPath $enginePath)) {
    throw "Moteur SENETECH introuvable : $enginePath"
}

# Rescue route for both cases:
# - an existing/hybrid V1.6 runtime (17..23): normalize directly;
# - a Stable 1.5.1 staging directory: build only to V1.6.0.19, then jump
#   directly to the hardened normalizer. This intentionally skips the old
#   build-20 channel patch that can fail with "updater principal introuvable".
$pin = '04beb60182b49cd0b20ae1cfcb082d3aa3351b4a'

function Invoke-PinnedPatch([string]$RelativePath,[string]$Label) {
    $url = "https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/$pin/$RelativePath"
    $tmp = Join-Path $env:TEMP ("SENETECH-RESCUE-" + [guid]::NewGuid().ToString('N') + '.ps1')
    try {
        Invoke-WebRequest -UseBasicParsing -Uri ($url + '?senetech=' + [guid]::NewGuid().ToString('N')) -OutFile $tmp -TimeoutSec 45
        & $tmp -StageDir $StageDir
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            throw "$Label en echec : code $LASTEXITCODE"
        }
    } finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}

$engineText = [IO.File]::ReadAllText($enginePath,$utf8Bom)
$isV16 = $false
foreach ($candidate in 17..23) {
    if ($engineText.Contains("`$script:AppVersion = '1.6.0.$candidate'") -or
        $engineText.Contains("1.6.0 DEV - build $candidate") -or
        $engineText.Contains("1.6.0 DEV - BUILD $candidate")) {
        $isV16 = $true
        break
    }
}

if (-not $isV16) {
    # v21 builds the official Stable base only up to build 19.
    # It does NOT execute the fragile build-20 updater-channel patch.
    Invoke-PinnedPatch 'src/PATCH-SENETECH-1.6.0-v21.ps1' 'Construction V1.6 build 19'
}

# v27 accepts builds 17..22 and installs the hardened startup diagnostics.
# If the stage is already build 23, no v27 call is needed.
$engineText = [IO.File]::ReadAllText($enginePath,$utf8Bom)
if (-not $engineText.Contains("`$script:AppVersion = '1.6.0.23'")) {
    Invoke-PinnedPatch 'src/PATCH-SENETECH-1.6.0-v27.ps1' 'Normalisation V1.6 build 23'
}

$engineText = [IO.File]::ReadAllText($enginePath,$utf8Bom)
if (-not $engineText.Contains("`$script:AppVersion = '1.6.0.23'")) {
    throw 'Migration de secours impossible : build 23 intermediaire non obtenu.'
}

# Promote the fully normalized runtime to build 24.
$engineText = $engineText.Replace("`$script:AppVersion = '1.6.0.23'", "`$script:AppVersion = '1.6.0.24'")
$engineText = $engineText.Replace("`$script:DisplayVersion = '1.6.0 DEV - build 23'", "`$script:DisplayVersion = '1.6.0 DEV - build 24'")
$engineText = $engineText.Replace('Title="SENETECH Setup V1.6.0 DEV - build 23"','Title="SENETECH Setup V1.6.0 DEV - build 24"')
$engineText = $engineText.Replace('VERSION 1.6.0 DEV - BUILD 23" Foreground','VERSION 1.6.0 DEV - BUILD 24" Foreground')
$engineText = $engineText.Replace('SENETECH Setup V1.6.0 DEV - build 23 demarre','SENETECH Setup V1.6.0 DEV - build 24 demarre')

if (-not $engineText.Contains("`$script:AppVersion = '1.6.0.24'")) {
    throw 'Migration de secours : normalisation AppVersion vers build 24 impossible.'
}
if ($engineText.Contains('Title=\"SENETECH Setup')) {
    throw 'Migration de secours : guillemets XAML invalides detectes.'
}
[IO.File]::WriteAllText($enginePath,$engineText,$utf8Bom)

if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath,$utf8NoBom)
    $manifestText = $manifestText.Replace('version="1.6.0.23"','version="1.6.0.24"')
    [IO.File]::WriteAllText($manifestPath,$manifestText,$utf8NoBom)
}

Set-Content -LiteralPath $versionPath -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.24
Affichage : 1.6.0 DEV - build 24
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Migration : secours V1.6 hybride + fallback Stable sans patch build 20
Updater : V23 durci avec cache-bypass, preflight, logs et rollback propre
Journal : C:\ProgramData\SENETECH\Logs\SENETECH-Updater.log
'@

Write-Output 'SENETECH V1.6.0 DEV build 24 - migration de secours appliquee.'
