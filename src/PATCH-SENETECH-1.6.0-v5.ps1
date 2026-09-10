param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'

# Apply previous V1.6.0.2 patch first.
$previousPatch = Join-Path $env:TEMP 'SENETECH-PATCH-1.6.0-v4.ps1'
$previousPatchUrl = 'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/develop/src/PATCH-SENETECH-1.6.0-v4.ps1'
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
$engineText = [IO.File]::ReadAllText($enginePath, $utf8Bom)

# Load the sales-delivery module after the startup compatibility override.
$needle = ". `$startupFixModule`r`nInitialize-SenetechV16Features"
if (-not $engineText.Contains($needle)) {
    $needle = ". `$startupFixModule`nInitialize-SenetechV16Features"
}
if (-not $engineText.Contains($needle)) {
    throw 'Patch V1.6.0.3 impossible : point de chargement livraison introuvable.'
}
$replacement = ". `$startupFixModule`r`n`$deliveryModule = Join-Path `$script:EngineDir 'Modules\Senetech.Delivery.ps1'`r`nif (-not (Test-Path -LiteralPath `$deliveryModule)) { throw 'Module Livraison SENETECH V1.6.0.3 introuvable.' }`r`n. `$deliveryModule`r`nInitialize-SenetechV16Features`r`nInitialize-SenetechDeliveryFeatures"
$engineText = $engineText.Replace($needle, $replacement)

# Ensure the new delivery button is disabled during long-running operations.
$engineText = $engineText.Replace("'RollbackButton','CreateRestoreCheck'", "'RollbackButton','DeliveryButton','CreateRestoreCheck'")

$engineText = $engineText.Replace("`$script:AppVersion = '1.6.0.2'", "`$script:AppVersion = '1.6.0.3'")
[IO.File]::WriteAllText($enginePath, $engineText, $utf8Bom)

$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath, $utf8NoBom)
    $manifestText = $manifestText.Replace('version="1.6.0.2"', 'version="1.6.0.3"')
    [IO.File]::WriteAllText($manifestPath, $manifestText, $utf8NoBom)
}

Set-Content -LiteralPath (Join-Path $StageDir 'VERSION.txt') -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.3
Affichage : 1.6.0 DEV
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Mises a jour : GitHub + SHA-256 + rollback
Nouveau : Finaliser pour la vente + OOBE + SENETECH Welcome
'@

Write-Output 'SENETECH V1.6.0 DEV build 3 - mode Livraison / Vente applique.'
