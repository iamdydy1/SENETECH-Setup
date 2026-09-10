param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'

# Apply complete build 20 first.
$previousPatch = Join-Path $env:TEMP 'SENETECH-PATCH-1.6.0-v22.ps1'
$previousPatchUrl = 'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/develop/src/PATCH-SENETECH-1.6.0-v22.ps1'
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

# Build 21 adds a startup marker after the main V1.6 feature initialization.
# The updater uses this marker to verify that the new runtime really started.
$needle = "Initialize-SenetechV16Features`r`nInitialize-SenetechReporter"
if (-not $engineText.Contains($needle)) {
    $needle = "Initialize-SenetechV16Features`nInitialize-SenetechReporter"
}
if (-not $engineText.Contains($needle)) {
    throw 'Patch V1.6.0.21 impossible : point de verification de demarrage introuvable.'
}

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

$engineText = $engineText.Replace("`$script:AppVersion = '1.6.0.20'", "`$script:AppVersion = '1.6.0.21'")
$engineText = $engineText.Replace("`$script:DisplayVersion = '1.6.0 DEV - build 20'", "`$script:DisplayVersion = '1.6.0 DEV - build 21'")
$engineText = $engineText.Replace('Title="SENETECH Setup V1.6.0 DEV - build 20"','Title="SENETECH Setup V1.6.0 DEV - build 21"')
$engineText = $engineText.Replace('VERSION 1.6.0 DEV - BUILD 20" Foreground','VERSION 1.6.0 DEV - BUILD 21" Foreground')
$engineText = $engineText.Replace('SENETECH Setup V1.6.0 DEV - build 20 demarre','SENETECH Setup V1.6.0 DEV - build 21 demarre')
[IO.File]::WriteAllText($enginePath,$engineText,$utf8Bom)

$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath,$utf8NoBom)
    $manifestText = $manifestText.Replace('version="1.6.0.20"','version="1.6.0.21"')
    [IO.File]::WriteAllText($manifestPath,$manifestText,$utf8NoBom)
}

Set-Content -LiteralPath (Join-Path $StageDir 'VERSION.txt') -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.21
Affichage : 1.6.0 DEV - build 21
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Mises a jour : updater garde avec timeout, verification, rollback et journal permanent
Journal : C:\ProgramData\SENETECH\Logs\SENETECH-Updater.log
Verification : marqueur de demarrage apres initialisation V1.6
Correctif : plus de boucle PID infinie ni de fermeture silencieuse sans diagnostic
'@

Write-Output 'SENETECH V1.6.0 DEV build 21 - updater garde et verification de demarrage actives.'
