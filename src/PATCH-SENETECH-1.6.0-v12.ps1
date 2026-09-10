param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'

# Apply previous V1.6.0.9 patch first.
$previousPatch = Join-Path $env:TEMP 'SENETECH-PATCH-1.6.0-v11.ps1'
$previousPatchUrl = 'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/develop/src/PATCH-SENETECH-1.6.0-v11.ps1'
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

# Load the crash-safe inventory override after the delivery display override.
$needle = ". `$deliveryDisplayFixModule`r`nInitialize-SenetechV16Features"
if (-not $engineText.Contains($needle)) {
    $needle = ". `$deliveryDisplayFixModule`nInitialize-SenetechV16Features"
}
if (-not $engineText.Contains($needle)) {
    throw 'Patch V1.6.0.10 impossible : point de chargement apercu Livraison introuvable.'
}

$replacement = ". `$deliveryDisplayFixModule`r`n`$deliveryInventoryFixModule = Join-Path `$script:EngineDir 'Modules\Senetech.DeliveryInventoryFix.ps1'`r`nif (-not (Test-Path -LiteralPath `$deliveryInventoryFixModule)) { throw 'Module apercu Livraison SENETECH V1.6.0.10 introuvable.' }`r`n. `$deliveryInventoryFixModule`r`nInitialize-SenetechV16Features"
$engineText = $engineText.Replace($needle,$replacement)

$engineText = $engineText.Replace("`$script:AppVersion = '1.6.0.9'", "`$script:AppVersion = '1.6.0.10'")
[IO.File]::WriteAllText($enginePath,$engineText,$utf8Bom)

$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath,$utf8NoBom)
    $manifestText = $manifestText.Replace('version="1.6.0.9"','version="1.6.0.10"')
    [IO.File]::WriteAllText($manifestPath,$manifestText,$utf8NoBom)
}

Set-Content -LiteralPath (Join-Path $StageDir 'VERSION.txt') -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.10
Affichage : 1.6.0 DEV
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Mises a jour : GitHub + SHA-256 + rollback
Correctif : apercu applications Livraison anti-crash sous Windows PowerShell 5.1
'@

Write-Output 'SENETECH V1.6.0 DEV build 10 - apercu applications Livraison securise.'
