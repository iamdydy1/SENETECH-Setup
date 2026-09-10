param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'

# Apply the complete build 17 patch first.
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

$needle = ". `$cacheSafetyModule`r`nInitialize-SenetechV16Features"
if (-not $engineText.Contains($needle)) { $needle = ". `$cacheSafetyModule`nInitialize-SenetechV16Features" }
if (-not $engineText.Contains($needle)) { throw 'Patch V1.6.0.18 impossible : point de chargement CacheSafety introuvable.' }

$replacement = ". `$cacheSafetyModule`r`n`$reporterModule = Join-Path `$script:EngineDir 'Modules\Senetech.Reporter.ps1'`r`nif (-not (Test-Path -LiteralPath `$reporterModule)) { throw 'Module SENETECH Reporter V1.6.0.18 introuvable.' }`r`n. `$reporterModule`r`nInitialize-SenetechV16Features`r`nInitialize-SenetechReporter"
$engineText = $engineText.Replace($needle,$replacement)

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
Nouveau : SENETECH Reporter via Cloudflare avec consentement, succes, avertissements et erreurs
'@

Write-Output 'SENETECH V1.6.0 DEV build 18 - Reporter Cloudflare integre.'
