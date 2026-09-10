param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'

# Apply previous V1.6.0.8 patch first.
$previousPatch = Join-Path $env:TEMP 'SENETECH-PATCH-1.6.0-v10.ps1'
$previousPatchUrl = 'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/develop/src/PATCH-SENETECH-1.6.0-v10.ps1'
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

# Delivery module is already loaded earlier. Load this override after Display so
# the delivery wizard and inventory use the same screen/DPI metrics as the main UI.
$needle = ". `$displayModule`r`nInitialize-SenetechV16Features"
if (-not $engineText.Contains($needle)) {
    $needle = ". `$displayModule`nInitialize-SenetechV16Features"
}
if (-not $engineText.Contains($needle)) {
    throw 'Patch V1.6.0.9 impossible : point de chargement interface Livraison introuvable.'
}

$replacement = ". `$displayModule`r`n`$deliveryDisplayFixModule = Join-Path `$script:EngineDir 'Modules\Senetech.DeliveryDisplayFix.ps1'`r`nif (-not (Test-Path -LiteralPath `$deliveryDisplayFixModule)) { throw 'Module affichage Livraison SENETECH V1.6.0.9 introuvable.' }`r`n. `$deliveryDisplayFixModule`r`nInitialize-SenetechV16Features"
$engineText = $engineText.Replace($needle,$replacement)

$engineText = $engineText.Replace("`$script:AppVersion = '1.6.0.8'", "`$script:AppVersion = '1.6.0.9'")
[IO.File]::WriteAllText($enginePath,$engineText,$utf8Bom)

$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath,$utf8NoBom)
    $manifestText = $manifestText.Replace('version="1.6.0.8"','version="1.6.0.9"')
    [IO.File]::WriteAllText($manifestPath,$manifestText,$utf8NoBom)
}

Set-Content -LiteralPath (Join-Path $StageDir 'VERSION.txt') -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.9
Affichage : 1.6.0 DEV
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Mises a jour : GitHub + SHA-256 + rollback
Correctif : fenetre Livraison/Vente lisible et responsive sur petits ecrans
'@

Write-Output 'SENETECH V1.6.0 DEV build 9 - fenetre Livraison responsive appliquee.'
