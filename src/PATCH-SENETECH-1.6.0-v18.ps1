param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'

# Apply previous V1.6.0.15 startup-recovery patch first.
$previousPatch = Join-Path $env:TEMP 'SENETECH-PATCH-1.6.0-v17.ps1'
$previousPatchUrl = 'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/develop/src/PATCH-SENETECH-1.6.0-v17.ps1'
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

# Build 14 already loads Validation before Initialize-SenetechV16Features.
# Add the final rollback/sale/cache safety overrides after Validation so they are
# the active implementations at runtime.
$needle = ". `$validationModule`r`nInitialize-SenetechV16Features"
if (-not $engineText.Contains($needle)) { $needle = ". `$validationModule`nInitialize-SenetechV16Features" }
if (-not $engineText.Contains($needle)) { throw 'Patch V1.6.0.16 impossible : point de chargement validation introuvable.' }

$replacement = ". `$validationModule`r`n`$releaseSafetyModule = Join-Path `$script:EngineDir 'Modules\Senetech.ReleaseSafety.ps1'`r`nif (-not (Test-Path -LiteralPath `$releaseSafetyModule)) { throw 'Module securite release SENETECH V1.6.0.16 introuvable.' }`r`n. `$releaseSafetyModule`r`n`$cacheSafetyModule = Join-Path `$script:EngineDir 'Modules\Senetech.CacheSafety.ps1'`r`nif (-not (Test-Path -LiteralPath `$cacheSafetyModule)) { throw 'Module securite cache SENETECH V1.6.0.16 introuvable.' }`r`n. `$cacheSafetyModule`r`nInitialize-SenetechV16Features"
$engineText = $engineText.Replace($needle,$replacement)

$engineText = $engineText.Replace("`$script:AppVersion = '1.6.0.15'", "`$script:AppVersion = '1.6.0.16'")
$engineText = $engineText.Replace("`$script:DisplayVersion = '1.6.0 DEV - build 15'", "`$script:DisplayVersion = '1.6.0 DEV - build 16'")
$engineText = $engineText.Replace('Title="SENETECH Setup V1.6.0 DEV - build 15"','Title="SENETECH Setup V1.6.0 DEV - build 16"')
$engineText = $engineText.Replace('VERSION 1.6.0 DEV - BUILD 15" Foreground','VERSION 1.6.0 DEV - BUILD 16" Foreground')
$engineText = $engineText.Replace('SENETECH Setup V1.6.0 DEV - build 15 demarre','SENETECH Setup V1.6.0 DEV - build 16 demarre')
[IO.File]::WriteAllText($enginePath,$engineText,$utf8Bom)

$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath,$utf8NoBom)
    $manifestText = $manifestText.Replace('version="1.6.0.15"','version="1.6.0.16"')
    [IO.File]::WriteAllText($manifestPath,$manifestText,$utf8NoBom)
}

Set-Content -LiteralPath (Join-Path $StageDir 'VERSION.txt') -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.16
Affichage : 1.6.0 DEV - build 16
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Mises a jour : GitHub + SHA-256 + rollback
Audit : validation complete, rollback securise, cache transactionnel et livraison client renforcee
'@

Write-Output 'SENETECH V1.6.0 DEV build 16 - couches de securite release appliquees.'
