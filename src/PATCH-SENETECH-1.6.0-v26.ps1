param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$enginePath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.ps1'
$versionPath = Join-Path $StageDir 'VERSION.txt'
$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'

if (-not (Test-Path -LiteralPath $enginePath)) { throw "Moteur SENETECH introuvable : $enginePath" }
$engineText = [IO.File]::ReadAllText($enginePath,$utf8Bom)

# Some machines report build 18 in the wrapper/window while the embedded
# PowerShell engine still contains build 17 markers. Accept builds 17..22 and
# repair every mixed marker instead of trusting a single displayed version.
$sourceBuild = $null
foreach ($candidate in 17..22) {
    if ($engineText.Contains("`$script:AppVersion = '1.6.0.$candidate'")) {
        $sourceBuild = [int]$candidate
        break
    }
}
if ($null -eq $sourceBuild) {
    foreach ($candidate in 17..22) {
        if ($engineText.Contains("1.6.0 DEV - build $candidate") -or $engineText.Contains("1.6.0 DEV - BUILD $candidate")) {
            $sourceBuild = [int]$candidate
            break
        }
    }
}
if ($null -eq $sourceBuild) {
    throw 'Patch incremental V1.6.0.22 refuse : moteur source non reconnu comme V1.6 build 17 a 22.'
}

# Ensure build 18 Reporter integration exists when the actual engine is still 17.
if (-not $engineText.Contains('Senetech.Reporter.ps1')) {
    $needle = ". `$cacheSafetyModule`r`nInitialize-SenetechV16Features"
    if (-not $engineText.Contains($needle)) { $needle = ". `$cacheSafetyModule`nInitialize-SenetechV16Features" }
    if (-not $engineText.Contains($needle)) { throw 'Patch incremental : point de chargement CacheSafety/Reporter introuvable.' }
    $replacement = ". `$cacheSafetyModule`r`n`$reporterModule = Join-Path `$script:EngineDir 'Modules\Senetech.Reporter.ps1'`r`nif (-not (Test-Path -LiteralPath `$reporterModule)) { throw 'Module SENETECH Reporter introuvable.' }`r`n. `$reporterModule`r`nInitialize-SenetechV16Features`r`nInitialize-SenetechReporter"
    $engineText = $engineText.Replace($needle,$replacement)
}

# Ensure build 19 Reporter UI integration exists.
if (-not $engineText.Contains('Senetech.ReporterUi.ps1')) {
    $needle = ". `$reporterModule`r`nInitialize-SenetechV16Features`r`nInitialize-SenetechReporter"
    if (-not $engineText.Contains($needle)) { $needle = ". `$reporterModule`nInitialize-SenetechV16Features`nInitialize-SenetechReporter" }
    if (-not $engineText.Contains($needle)) { throw 'Patch incremental : point de chargement Reporter UI introuvable.' }
    $replacement = ". `$reporterModule`r`n`$reporterUiModule = Join-Path `$script:EngineDir 'Modules\Senetech.ReporterUi.ps1'`r`nif (-not (Test-Path -LiteralPath `$reporterUiModule)) { throw 'Module interface Reporter SENETECH introuvable.' }`r`n. `$reporterUiModule`r`nInitialize-SenetechV16Features`r`nInitialize-SenetechReporter"
    $engineText = $engineText.Replace($needle,$replacement)
}

# Ensure build 20 channel-aware updater is used.
$engineText = $engineText.Replace("'UPDATE-SENETECH.ps1'","'UPDATE-SENETECH-CHANNEL.ps1'")

# Ensure guarded-updater startup marker exists. Insert it before Reporter consent.
if (-not $engineText.Contains("'startup.ok'")) {
    $needle = "Initialize-SenetechV16Features`r`nInitialize-SenetechReporter"
    if (-not $engineText.Contains($needle)) { $needle = "Initialize-SenetechV16Features`nInitialize-SenetechReporter" }
    if (-not $engineText.Contains($needle)) { throw 'Patch incremental : point de verification de demarrage introuvable.' }
    $replacement = @"
Initialize-SenetechV16Features
try {
    `$startupStateDir = Join-Path `$env:ProgramData 'SENETECH'
    New-Item -ItemType Directory -Path `$startupStateDir -Force -ErrorAction SilentlyContinue | Out-Null
    `$startupMarker = Join-Path `$startupStateDir 'startup.ok'
    Set-Content -LiteralPath `$startupMarker -Encoding ASCII -Value ('version=' + `$script:AppVersion + ';time=' + (Get-Date).ToString('o'))
} catch { }
Initialize-SenetechReporter
"@
    $engineText = $engineText.Replace($needle,$replacement.TrimEnd("`r","`n"))
}

# Normalize ALL mixed version markers. This intentionally loops through every
# possible source build so title/header/engine cannot disagree after the update.
foreach ($candidate in 17..22) {
    $engineText = $engineText.Replace("`$script:AppVersion = '1.6.0.$candidate'", "`$script:AppVersion = '1.6.0.22'")
    $engineText = $engineText.Replace("`$script:DisplayVersion = '1.6.0 DEV - build $candidate'", "`$script:DisplayVersion = '1.6.0 DEV - build 22'")
    $engineText = $engineText.Replace("Title=`"SENETECH Setup V1.6.0 DEV - build $candidate`"", 'Title="SENETECH Setup V1.6.0 DEV - build 22"')
    $engineText = $engineText.Replace("VERSION 1.6.0 DEV - BUILD $candidate`" Foreground", 'VERSION 1.6.0 DEV - BUILD 22" Foreground')
    $engineText = $engineText.Replace("SENETECH Setup V1.6.0 DEV - build $candidate demarre", 'SENETECH Setup V1.6.0 DEV - build 22 demarre')
}
# Also normalize the original no-build V1.6 labels if one survived an old patch.
$engineText = $engineText.Replace("`$script:DisplayVersion = '1.6.0 DEV'", "`$script:DisplayVersion = '1.6.0 DEV - build 22'")
$engineText = $engineText.Replace('Title="SENETECH Setup V1.6.0 DEV"','Title="SENETECH Setup V1.6.0 DEV - build 22"')
$engineText = $engineText.Replace('VERSION 1.6.0 DEV" Foreground','VERSION 1.6.0 DEV - BUILD 22" Foreground')
$engineText = $engineText.Replace('SENETECH Setup V1.6.0 DEV demarre','SENETECH Setup V1.6.0 DEV - build 22 demarre')

if (-not $engineText.Contains("`$script:AppVersion = '1.6.0.22'")) {
    throw 'Patch incremental : normalisation AppVersion impossible.'
}
[IO.File]::WriteAllText($enginePath,$engineText,$utf8Bom)

if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath,$utf8NoBom)
    foreach ($candidate in 17..22) {
        $manifestText = $manifestText.Replace("version=`"1.6.0.$candidate`"",'version="1.6.0.22"')
    }
    [IO.File]::WriteAllText($manifestPath,$manifestText,$utf8NoBom)
}

Set-Content -LiteralPath $versionPath -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.22
Affichage : 1.6.0 DEV - build 22
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Mises a jour : incremental DEV + verification + rollback + journal permanent
Journal : C:\ProgramData\SENETECH\Logs\SENETECH-Updater.log
Correctif : prise en charge des runtimes hybrides build 17/18
Correctif : versions internes, titre et en-tete normalises vers build 22
'@

Write-Output ("SENETECH V1.6.0 DEV build 22 - runtime hybride repare depuis moteur build " + $sourceBuild + '.')
