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

# Direct incremental path for machines already running a recent V1.6 DEV build.
$build = $null
foreach ($candidate in 18..21) {
    if ($engineText.Contains("`$script:AppVersion = '1.6.0.$candidate'")) {
        $build = [int]$candidate
        break
    }
}
if ($null -eq $build) {
    throw 'Patch incremental V1.6.0.22 refuse : version source attendue entre build 18 et build 21.'
}

# Build 19 functionality: simplified Reporter UI.
if (-not $engineText.Contains('Senetech.ReporterUi.ps1')) {
    $needle = ". `$reporterModule`r`nInitialize-SenetechV16Features`r`nInitialize-SenetechReporter"
    if (-not $engineText.Contains($needle)) { $needle = ". `$reporterModule`nInitialize-SenetechV16Features`nInitialize-SenetechReporter" }
    if (-not $engineText.Contains($needle)) { throw 'Patch incremental : point de chargement Reporter introuvable.' }
    $replacement = ". `$reporterModule`r`n`$reporterUiModule = Join-Path `$script:EngineDir 'Modules\Senetech.ReporterUi.ps1'`r`nif (-not (Test-Path -LiteralPath `$reporterUiModule)) { throw 'Module interface Reporter SENETECH introuvable.' }`r`n. `$reporterUiModule`r`nInitialize-SenetechV16Features`r`nInitialize-SenetechReporter"
    $engineText = $engineText.Replace($needle,$replacement)
}

# Build 20 functionality: channel-aware updater wrapper.
if ($engineText.Contains("'UPDATE-SENETECH.ps1'")) {
    $engineText = $engineText.Replace("'UPDATE-SENETECH.ps1'","'UPDATE-SENETECH-CHANNEL.ps1'")
}

# Guarded updater startup marker. It is written before Reporter consent so a user
# taking time to answer the consent dialog cannot trigger a false rollback.
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

# Promote the supported source build directly to build 22.
$engineText = $engineText.Replace("`$script:AppVersion = '1.6.0.$build'", "`$script:AppVersion = '1.6.0.22'")
$engineText = $engineText.Replace("`$script:DisplayVersion = '1.6.0 DEV - build $build'", "`$script:DisplayVersion = '1.6.0 DEV - build 22'")
$engineText = $engineText.Replace("Title=`"SENETECH Setup V1.6.0 DEV - build $build`"",'Title="SENETECH Setup V1.6.0 DEV - build 22"')
$engineText = $engineText.Replace("VERSION 1.6.0 DEV - BUILD $build`" Foreground",'VERSION 1.6.0 DEV - BUILD 22" Foreground')
$engineText = $engineText.Replace("SENETECH Setup V1.6.0 DEV - build $build demarre",'SENETECH Setup V1.6.0 DEV - build 22 demarre')
[IO.File]::WriteAllText($enginePath,$engineText,$utf8Bom)

if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath,$utf8NoBom)
    $manifestText = $manifestText.Replace("version=`"1.6.0.$build`"",'version="1.6.0.22"')
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
Correctif : les builds V1.6 existantes ne rejouent plus toute la chaine de patches depuis Stable
Correctif : sortie et erreur PowerShell du patch enregistrees dans le journal updater
'@

Write-Output ("SENETECH V1.6.0 DEV build 22 - mise a jour incrementale appliquee depuis build " + $build + '.')
