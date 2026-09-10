param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'

# Apply complete build 18 first.
$previousPatch = Join-Path $env:TEMP 'SENETECH-PATCH-1.6.0-v20.ps1'
$previousPatchUrl = 'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/develop/src/PATCH-SENETECH-1.6.0-v20.ps1'
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

$needle = ". `$reporterModule`r`nInitialize-SenetechV16Features`r`nInitialize-SenetechReporter"
if (-not $engineText.Contains($needle)) { $needle = ". `$reporterModule`nInitialize-SenetechV16Features`nInitialize-SenetechReporter" }
if (-not $engineText.Contains($needle)) { throw 'Patch V1.6.0.19 impossible : point de chargement Reporter introuvable.' }

$replacement = ". `$reporterModule`r`n`$reporterUiModule = Join-Path `$script:EngineDir 'Modules\Senetech.ReporterUi.ps1'`r`nif (-not (Test-Path -LiteralPath `$reporterUiModule)) { throw 'Module interface Reporter SENETECH V1.6.0.19 introuvable.' }`r`n. `$reporterUiModule`r`nInitialize-SenetechV16Features`r`nInitialize-SenetechReporter"
$engineText = $engineText.Replace($needle,$replacement)

$engineText = $engineText.Replace("`$script:AppVersion = '1.6.0.18'", "`$script:AppVersion = '1.6.0.19'")
$engineText = $engineText.Replace("`$script:DisplayVersion = '1.6.0 DEV - build 18'", "`$script:DisplayVersion = '1.6.0 DEV - build 19'")
$engineText = $engineText.Replace('Title="SENETECH Setup V1.6.0 DEV - build 18"','Title="SENETECH Setup V1.6.0 DEV - build 19"')
$engineText = $engineText.Replace('VERSION 1.6.0 DEV - BUILD 18" Foreground','VERSION 1.6.0 DEV - BUILD 19" Foreground')
$engineText = $engineText.Replace('SENETECH Setup V1.6.0 DEV - build 18 demarre','SENETECH Setup V1.6.0 DEV - build 19 demarre')
[IO.File]::WriteAllText($enginePath,$engineText,$utf8Bom)

$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath,$utf8NoBom)
    $manifestText = $manifestText.Replace('version="1.6.0.18"','version="1.6.0.19"')
    [IO.File]::WriteAllText($manifestPath,$manifestText,$utf8NoBom)
}

Set-Content -LiteralPath (Join-Path $StageDir 'VERSION.txt') -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.19
Affichage : 1.6.0 DEV - build 19
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Reporter : Cloudflare Worker, interface simplifiee Assistance SENETECH
'@

Write-Output 'SENETECH V1.6.0 DEV build 19 - interface Reporter simplifiee.'
