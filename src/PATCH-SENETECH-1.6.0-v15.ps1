param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'

# Apply previous V1.6.0.12 patch first.
$previousPatch = Join-Path $env:TEMP 'SENETECH-PATCH-1.6.0-v14.ps1'
$previousPatchUrl = 'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/develop/src/PATCH-SENETECH-1.6.0-v14.ps1'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri $previousPatchUrl -OutFile $previousPatch
    & $previousPatch -StageDir $StageDir
} finally {
    Remove-Item -LiteralPath $previousPatch -Force -ErrorAction SilentlyContinue
}

$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$enginePath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.ps1'
$engineText = [IO.File]::ReadAllText($enginePath,$utf8Bom)

# Load the spelling/accents override after every V1.6 module is defined but
# before UI initialization. The module itself is ASCII-only and generates
# accented French characters at runtime, preserving PowerShell 5.1 safety.
$needle = ". `$deliveryRegistryFixModule`r`nInitialize-SenetechV16Features"
if (-not $engineText.Contains($needle)) {
    $needle = ". `$deliveryRegistryFixModule`nInitialize-SenetechV16Features"
}
if (-not $engineText.Contains($needle)) {
    throw 'Patch V1.6.0.13 impossible : point de chargement interface francaise introuvable.'
}

$replacement = ". `$deliveryRegistryFixModule`r`n`$frenchUiModule = Join-Path `$script:EngineDir 'Modules\Senetech.FrenchUi.ps1'`r`nif (-not (Test-Path -LiteralPath `$frenchUiModule)) { throw 'Module interface francaise SENETECH V1.6.0.13 introuvable.' }`r`n. `$frenchUiModule`r`nInitialize-SenetechV16Features"
$engineText = $engineText.Replace($needle,$replacement)

$engineText = $engineText.Replace("`$script:AppVersion = '1.6.0.12'", "`$script:AppVersion = '1.6.0.13'")
$engineText = $engineText.Replace("`$script:DisplayVersion = '1.6.0 DEV - build 12'", "`$script:DisplayVersion = '1.6.0 DEV - build 13'")
$engineText = $engineText.Replace('Title="SENETECH Setup V1.6.0 DEV - build 12"','Title="SENETECH Setup V1.6.0 DEV - build 13"')
$engineText = $engineText.Replace('VERSION 1.6.0 DEV - BUILD 12" Foreground','VERSION 1.6.0 DEV - BUILD 13" Foreground')
$engineText = $engineText.Replace('SENETECH Setup V1.6.0 DEV - build 12 demarre','SENETECH Setup V1.6.0 DEV - build 13 demarre')
[IO.File]::WriteAllText($enginePath,$engineText,$utf8Bom)

$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath,$utf8NoBom)
    $manifestText = $manifestText.Replace('version="1.6.0.12"','version="1.6.0.13"')
    [IO.File]::WriteAllText($manifestPath,$manifestText,$utf8NoBom)
}

Set-Content -LiteralPath (Join-Path $StageDir 'VERSION.txt') -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.13
Affichage : 1.6.0 DEV - build 13
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Mises a jour : GitHub + SHA-256 + rollback
Correctif : orthographe, accents et formulations francaises de l interface
'@

Write-Output 'SENETECH V1.6.0 DEV build 13 - interface francaise corrigee.'
