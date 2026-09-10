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
if (-not $engineText.Contains("`$script:AppVersion = '1.6.0.26'")) {
    throw 'Build 27 exige le moteur diagnostic 1.6.0.26.'
}

$engineText = $engineText.Replace("`$script:AppVersion = '1.6.0.26'", "`$script:AppVersion = '1.6.0.27'")
$engineText = $engineText.Replace("`$script:DisplayVersion = '1.6.0 DEV - build 26 DIAGNOSTIC'", "`$script:DisplayVersion = '1.6.0 DEV - build 27 FIREFOX SAFETY'")
$engineText = $engineText.Replace('Title="SENETECH Setup V1.6.0 DEV - build 26 DIAGNOSTIC"','Title="SENETECH Setup V1.6.0 DEV - build 27 FIREFOX SAFETY"')
$engineText = $engineText.Replace('VERSION 1.6.0 DEV - BUILD 26 DIAGNOSTIC" Foreground','VERSION 1.6.0 DEV - BUILD 27 FIREFOX SAFETY" Foreground')
$engineText = $engineText.Replace('SENETECH Setup V1.6.0 DEV - build 26 DIAGNOSTIC demarre','SENETECH Setup V1.6.0 DEV - build 27 FIREFOX SAFETY demarre')

if (-not $engineText.Contains("`$script:AppVersion = '1.6.0.27'")) { throw 'Build 27 : normalisation AppVersion impossible.' }
[IO.File]::WriteAllText($enginePath,$engineText,$utf8Bom)

if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath,$utf8NoBom)
    $manifestText = $manifestText.Replace('version="1.6.0.26"','version="1.6.0.27"')
    [IO.File]::WriteAllText($manifestPath,$manifestText,$utf8NoBom)
}

Set-Content -LiteralPath $versionPath -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.27
Affichage : 1.6.0 DEV - build 27 FIREFOX SAFETY
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Correctif Firefox : detection par registre, WinGet, processus et executable
Protection profil : aucune reinstallation si Firefox existe hors registre
Mise a jour Firefox : reportee automatiquement lorsque Firefox est ouvert
Donnees utilisateur : aucun profil Firefox supprime ou modifie
Diagnostic Developer : SENETECH-DEV-DIAGNOSTIC.cmd
Logs Developer : C:\ProgramData\SENETECH\Logs\Developer
'@

Write-Output 'SENETECH V1.6.0 DEV build 27 FIREFOX SAFETY applique.'
