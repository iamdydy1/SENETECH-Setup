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

# Rescue all recent V1.6 DEV states, including hybrid build 17/18 machines.
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
    throw 'Patch incremental V1.6.0.23 refuse : moteur source non reconnu comme V1.6 build 17 a 22.'
}

# Ensure Reporter integration exists. Reporter must never be required for the core UI to start.
if (-not $engineText.Contains('Senetech.Reporter.ps1')) {
    $needle = ". `$cacheSafetyModule`r`nInitialize-SenetechV16Features"
    if (-not $engineText.Contains($needle)) { $needle = ". `$cacheSafetyModule`nInitialize-SenetechV16Features" }
    if (-not $engineText.Contains($needle)) { throw 'Patch incremental : point de chargement CacheSafety/Reporter introuvable.' }
    $replacement = ". `$cacheSafetyModule`r`n`$reporterModule = Join-Path `$script:EngineDir 'Modules\Senetech.Reporter.ps1'`r`nif (-not (Test-Path -LiteralPath `$reporterModule)) { throw 'Module SENETECH Reporter introuvable.' }`r`n. `$reporterModule`r`nInitialize-SenetechV16Features`r`nInitialize-SenetechReporter"
    $engineText = $engineText.Replace($needle,$replacement)
}

# Ensure simplified Reporter UI integration exists.
if (-not $engineText.Contains('Senetech.ReporterUi.ps1')) {
    $needle = ". `$reporterModule`r`nInitialize-SenetechV16Features`r`nInitialize-SenetechReporter"
    if (-not $engineText.Contains($needle)) { $needle = ". `$reporterModule`nInitialize-SenetechV16Features`nInitialize-SenetechReporter" }
    if (-not $engineText.Contains($needle)) { throw 'Patch incremental : point de chargement Reporter UI introuvable.' }
    $replacement = ". `$reporterModule`r`n`$reporterUiModule = Join-Path `$script:EngineDir 'Modules\Senetech.ReporterUi.ps1'`r`nif (-not (Test-Path -LiteralPath `$reporterUiModule)) { throw 'Module interface Reporter SENETECH introuvable.' }`r`n. `$reporterUiModule`r`nInitialize-SenetechV16Features`r`nInitialize-SenetechReporter"
    $engineText = $engineText.Replace($needle,$replacement)
}

# Route channel switches through the wrapper.
$engineText = $engineText.Replace("'UPDATE-SENETECH.ps1'","'UPDATE-SENETECH-CHANNEL.ps1'")

# Replace the old build-21/22 startup marker block, if present, with a two-phase
# startup diagnostic block. Otherwise replace the plain V1.6/Reporter call pair.
$startupBlock = @'
$startupStateDir = Join-Path $env:ProgramData 'SENETECH'
$startupBeginPath = Join-Path $startupStateDir 'startup.begin'
$startupOkPath = Join-Path $startupStateDir 'startup.ok'
$startupErrorPath = Join-Path $startupStateDir 'startup.error'
try {
    New-Item -ItemType Directory -Path $startupStateDir -Force -ErrorAction SilentlyContinue | Out-Null
    Remove-Item -LiteralPath $startupOkPath,$startupErrorPath -Force -ErrorAction SilentlyContinue
    Set-Content -LiteralPath $startupBeginPath -Encoding ASCII -Value ('version=' + $script:AppVersion + ';pid=' + $PID + ';time=' + (Get-Date).ToString('o'))
} catch { }

try {
    Initialize-SenetechV16Features
} catch {
    try {
        Set-Content -LiteralPath $startupErrorPath -Encoding UTF8 -Value ('version=' + $script:AppVersion + ';phase=V16;error=' + $_.Exception.Message)
    } catch { }
    throw
}

try {
    Set-Content -LiteralPath $startupOkPath -Encoding ASCII -Value ('version=' + $script:AppVersion + ';pid=' + $PID + ';time=' + (Get-Date).ToString('o'))
} catch { }

# Reporter is optional. It must never prevent SENETECH from opening.
try {
    Initialize-SenetechReporter
} catch {
    try { Write-Log ('SENETECH Reporter non bloquant : ' + $_.Exception.Message) 'ATTENTION' } catch { }
}
'@

$oldMarkerPattern = '(?s)Initialize-SenetechV16Features\r?\ntry\s*\{\r?\n\s*\$startupStateDir\s*=\s*Join-Path\s+\$env:ProgramData\s+''SENETECH''.*?\r?\n\}\r?\nInitialize-SenetechReporter'
$oldMarkerMatch = [regex]::Match($engineText,$oldMarkerPattern,[System.Text.RegularExpressions.RegexOptions]::Singleline)
if ($oldMarkerMatch.Success) {
    $engineText = $engineText.Substring(0,$oldMarkerMatch.Index) + $startupBlock.TrimEnd("`r","`n") + $engineText.Substring($oldMarkerMatch.Index + $oldMarkerMatch.Length)
} else {
    $plain = "Initialize-SenetechV16Features`r`nInitialize-SenetechReporter"
    if (-not $engineText.Contains($plain)) { $plain = "Initialize-SenetechV16Features`nInitialize-SenetechReporter" }
    if (-not $engineText.Contains($plain)) { throw 'Patch incremental : point d instrumentation de demarrage introuvable.' }
    $engineText = $engineText.Replace($plain,$startupBlock.TrimEnd("`r","`n"))
}

# Repair any quote escaping accidentally written by build 22 patches.
$engineText = $engineText.Replace('Title=\"SENETECH Setup V1.6.0 DEV - build 22\"','Title="SENETECH Setup V1.6.0 DEV - build 22"')
$engineText = $engineText.Replace('VERSION 1.6.0 DEV - BUILD 22\" Foreground','VERSION 1.6.0 DEV - BUILD 22" Foreground')

# Normalize all internal and visible version markers to build 23.
foreach ($candidate in 17..22) {
    $engineText = $engineText.Replace("`$script:AppVersion = '1.6.0.$candidate'", "`$script:AppVersion = '1.6.0.23'")
    $engineText = $engineText.Replace("`$script:DisplayVersion = '1.6.0 DEV - build $candidate'", "`$script:DisplayVersion = '1.6.0 DEV - build 23'")
    $engineText = $engineText.Replace("Title=`"SENETECH Setup V1.6.0 DEV - build $candidate`"", "Title=`"SENETECH Setup V1.6.0 DEV - build 23`"")
    $engineText = $engineText.Replace("VERSION 1.6.0 DEV - BUILD $candidate`" Foreground", "VERSION 1.6.0 DEV - BUILD 23`" Foreground")
    $engineText = $engineText.Replace("SENETECH Setup V1.6.0 DEV - build $candidate demarre", "SENETECH Setup V1.6.0 DEV - build 23 demarre")
}
$engineText = $engineText.Replace("`$script:DisplayVersion = '1.6.0 DEV'", "`$script:DisplayVersion = '1.6.0 DEV - build 23'")
$engineText = $engineText.Replace('Title="SENETECH Setup V1.6.0 DEV"','Title="SENETECH Setup V1.6.0 DEV - build 23"')
$engineText = $engineText.Replace('VERSION 1.6.0 DEV" Foreground','VERSION 1.6.0 DEV - BUILD 23" Foreground')
$engineText = $engineText.Replace('SENETECH Setup V1.6.0 DEV demarre','SENETECH Setup V1.6.0 DEV - build 23 demarre')

if (-not $engineText.Contains("`$script:AppVersion = '1.6.0.23'")) {
    throw 'Patch incremental : normalisation AppVersion vers build 23 impossible.'
}
if ($engineText.Contains('Title=\"SENETECH Setup V1.6.0 DEV - build 23\"')) {
    throw 'Patch incremental : guillemets XAML invalides detectes apres normalisation.'
}
[IO.File]::WriteAllText($enginePath,$engineText,$utf8Bom)

if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath,$utf8NoBom)
    $manifestText = $manifestText.Replace('version=\"1.6.0.22\"','version="1.6.0.22"')
    foreach ($candidate in 17..22) {
        $manifestText = $manifestText.Replace("version=`"1.6.0.$candidate`"","version=`"1.6.0.23`"")
    }
    [IO.File]::WriteAllText($manifestPath,$manifestText,$utf8NoBom)
}

Set-Content -LiteralPath $versionPath -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.23
Affichage : 1.6.0 DEV - build 23
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Mises a jour : incremental DEV + demarrage diagnostique + rollback propre
Journal : C:\ProgramData\SENETECH\Logs\SENETECH-Updater.log
Diagnostic demarrage : startup.begin / startup.ok / startup.error
Correctif : guillemets XAML valides, Reporter non bloquant et versions coherentes
'@

Write-Output ("SENETECH V1.6.0 DEV build 23 - runtime fiabilise depuis moteur build " + $sourceBuild + '.')
