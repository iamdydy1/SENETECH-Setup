param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'

# Apply the complete V1.6.0.17 build first.
$previousPatch = Join-Path $env:TEMP 'SENETECH-PATCH-1.6.0-v19.ps1'
$previousPatchUrl = 'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/develop/src/PATCH-SENETECH-1.6.0-v19.ps1'
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

# Load Reporter after all validation/safety implementations so its wrappers
# observe the final active functions.
$needle = ". `$cacheSafetyModule`r`nInitialize-SenetechV16Features"
if (-not $engineText.Contains($needle)) { $needle = ". `$cacheSafetyModule`nInitialize-SenetechV16Features" }
if (-not $engineText.Contains($needle)) { throw 'Patch V1.6.0.18 impossible : point de chargement CacheSafety introuvable.' }
$replacement = ". `$cacheSafetyModule`r`n`$reporterModule = Join-Path `$script:EngineDir 'Modules\Senetech.Reporter.ps1'`r`nif (-not (Test-Path -LiteralPath `$reporterModule)) { throw 'Module SENETECH Reporter V1.6.0.18 introuvable.' }`r`n. `$reporterModule`r`nInitialize-SenetechV16Features"
$engineText = $engineText.Replace($needle,$replacement)

# Initialize the Reporter after Delivery so sections remain in visual order:
# 6. Outils technicien, 7. Livraison/Vente, 8. Rapports techniques.
$initNeedle = "Initialize-SenetechV16Features`r`nInitialize-SenetechDeliveryFeatures"
if (-not $engineText.Contains($initNeedle)) { $initNeedle = "Initialize-SenetechV16Features`nInitialize-SenetechDeliveryFeatures" }
if (-not $engineText.Contains($initNeedle)) { throw 'Patch V1.6.0.18 impossible : initialisation Livraison introuvable.' }
$engineText = $engineText.Replace($initNeedle,"Initialize-SenetechV16Features`r`nInitialize-SenetechDeliveryFeatures`r`nInitialize-SenetechReporter")

# The legacy updater refuses a lower Stable version because it only compares
# semantic versions. Use a channel-aware wrapper so a deliberate DEV -> Stable
# switch can restore the official Stable package with the usual SHA-256/backup.
if (-not $engineText.Contains("'UPDATE-SENETECH.ps1'")) { throw 'Patch V1.6.0.18 impossible : updater principal introuvable.' }
$engineText = $engineText.Replace("'UPDATE-SENETECH.ps1'","'UPDATE-SENETECH-CHANNEL.ps1'")

$engineText = $engineText.Replace("`$script:AppVersion = '1.6.0.17'", "`$script:AppVersion = '1.6.0.18'")
$engineText = $engineText.Replace("`$script:DisplayVersion = '1.6.0 DEV - build 17'", "`$script:DisplayVersion = '1.6.0 DEV - build 18'")
$engineText = $engineText.Replace('Title="SENETECH Setup V1.6.0 DEV - build 17"','Title="SENETECH Setup V1.6.0 DEV - build 18"')
$engineText = $engineText.Replace('VERSION 1.6.0 DEV - BUILD 17" Foreground','VERSION 1.6.0 DEV - BUILD 18" Foreground')
$engineText = $engineText.Replace('SENETECH Setup V1.6.0 DEV - build 17 demarre','SENETECH Setup V1.6.0 DEV - build 18 demarre')
[IO.File]::WriteAllText($enginePath,$engineText,$utf8Bom)

$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath,$utf8NoBom)
    $manifestText = $manifestText.Replace('version="1.6.0.17"','version="1.6.0.18"')
    [IO.File]::WriteAllText($manifestPath,$manifestText,$utf8NoBom)
}

Set-Content -LiteralPath (Join-Path $StageDir 'VERSION.txt') -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.18
Affichage : 1.6.0 DEV - build 18
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Mises a jour : GitHub + SHA-256 + rollback
Nouveau : SENETECH Reporter via Cloudflare avec consentement
Nouveau : succes, avertissements, erreurs et file d attente de rapports
Correctif : passage Develop vers Stable reel avec sauvegarde avant remplacement
'@

Write-Output 'SENETECH V1.6.0 DEV build 18 - Reporter et changement de canal appliques.'
