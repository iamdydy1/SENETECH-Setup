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

# Build 26 intentionally keeps the exact Recovery/last-known-good runtime logic.
# Only visible version markers are changed; diagnostics are delivered as standalone overlays.
if (-not $engineText.Contains("`$script:AppVersion = '1.6.0.25'")) {
    throw 'Build 26 diagnostic exige le moteur Recovery 1.6.0.25.'
}

$engineText = $engineText.Replace("`$script:AppVersion = '1.6.0.25'", "`$script:AppVersion = '1.6.0.26'")
$engineText = $engineText.Replace("`$script:DisplayVersion = '1.6.0 DEV - build 25 RECOVERY'", "`$script:DisplayVersion = '1.6.0 DEV - build 26 DIAGNOSTIC'")
$engineText = $engineText.Replace('Title="SENETECH Setup V1.6.0 DEV - build 25 RECOVERY"','Title="SENETECH Setup V1.6.0 DEV - build 26 DIAGNOSTIC"')
$engineText = $engineText.Replace('VERSION 1.6.0 DEV - BUILD 25 RECOVERY" Foreground','VERSION 1.6.0 DEV - BUILD 26 DIAGNOSTIC" Foreground')
$engineText = $engineText.Replace('SENETECH Setup V1.6.0 DEV - build 25 RECOVERY demarre','SENETECH Setup V1.6.0 DEV - build 26 DIAGNOSTIC demarre')

if (-not $engineText.Contains("`$script:AppVersion = '1.6.0.26'")) {
    throw 'Build 26 diagnostic : normalisation AppVersion impossible.'
}
if ($engineText.Contains('Senetech.Reporter.ps1') -or $engineText.Contains('Initialize-SenetechReporter')) {
    throw 'Build 26 diagnostic : Reporter ne doit pas etre injecte dans le moteur last-known-good.'
}
[IO.File]::WriteAllText($enginePath,$engineText,$utf8Bom)

if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath,$utf8NoBom)
    $manifestText = $manifestText.Replace('version="1.6.0.25"','version="1.6.0.26"')
    [IO.File]::WriteAllText($manifestPath,$manifestText,$utf8NoBom)
}

Set-Content -LiteralPath $versionPath -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.26
Affichage : 1.6.0 DEV - build 26 DIAGNOSTIC
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Base moteur : Recovery / last-known-good build 17
Diagnostic Developer : SENETECH-DEV-DIAGNOSTIC.cmd
Logs Developer : C:\ProgramData\SENETECH\Logs\Developer
Reporter : envoi diagnostic distant uniquement si le consentement Reporter est actif
Objectif : collecter erreurs PowerShell, stack traces, evenements Windows et inventaire runtime sans modifier le demarrage normal
'@

Write-Output 'SENETECH V1.6.0 DEV build 26 DIAGNOSTIC - moteur Recovery conserve, kit diagnostic ajoute.'
