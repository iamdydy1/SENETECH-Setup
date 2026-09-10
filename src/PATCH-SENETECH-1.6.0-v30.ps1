param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$enginePath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.ps1'
$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
$versionPath = Join-Path $StageDir 'VERSION.txt'

if (-not (Test-Path -LiteralPath $enginePath)) {
    throw "Moteur SENETECH introuvable : $enginePath"
}

# Recovery principle: rebuild from the exact last runtime proven to open on the
# real Windows test machine (V1.6.0.17 commit 7dc64fd). Reporter and later
# startup instrumentation are deliberately excluded from application startup.
$pin = '7dc64fd1216068f3353f5ff4d65d750c26c75009'
$build17PatchUrl = "https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/$pin/src/PATCH-SENETECH-1.6.0-v19.ps1"
$tmpPatch = Join-Path $env:TEMP ('SENETECH-RECOVERY-B17-' + [guid]::NewGuid().ToString('N') + '.ps1')

$engineText = [IO.File]::ReadAllText($enginePath,$utf8Bom)
$isBuild17 = $engineText.Contains("`$script:AppVersion = '1.6.0.17'")
if (-not $isBuild17) {
    if ($engineText -match "\$script:AppVersion\s*=\s*'1\.6\.0\.(1[8-9]|2[0-9])'") {
        throw 'Recovery build 25 exige une base Stable propre; runtime DEV tardif detecte.'
    }
    try {
        Invoke-WebRequest -UseBasicParsing -Uri ($build17PatchUrl + '?senetech=' + [guid]::NewGuid().ToString('N')) -OutFile $tmpPatch -TimeoutSec 45
        & $tmpPatch -StageDir $StageDir
    } finally {
        Remove-Item -LiteralPath $tmpPatch -Force -ErrorAction SilentlyContinue
    }
}

$engineText = [IO.File]::ReadAllText($enginePath,$utf8Bom)
if (-not $engineText.Contains("`$script:AppVersion = '1.6.0.17'")) {
    throw 'Recovery build 25 : moteur build 17 non obtenu.'
}
if ($engineText.Contains('Senetech.Reporter.ps1') -or $engineText.Contains('Initialize-SenetechReporter')) {
    throw 'Recovery build 25 : integration Reporter inattendue dans le moteur de base.'
}
if ($engineText.Contains('startup.begin') -or $engineText.Contains('startup.ok') -or $engineText.Contains('startup.error')) {
    throw 'Recovery build 25 : instrumentation de demarrage inattendue dans le moteur de base.'
}

$engineText = $engineText.Replace("`$script:AppVersion = '1.6.0.17'", "`$script:AppVersion = '1.6.0.25'")
$engineText = $engineText.Replace("`$script:DisplayVersion = '1.6.0 DEV - build 17'", "`$script:DisplayVersion = '1.6.0 DEV - build 25 RECOVERY'")
$engineText = $engineText.Replace('Title="SENETECH Setup V1.6.0 DEV - build 17"','Title="SENETECH Setup V1.6.0 DEV - build 25 RECOVERY"')
$engineText = $engineText.Replace('VERSION 1.6.0 DEV - BUILD 17" Foreground','VERSION 1.6.0 DEV - BUILD 25 RECOVERY" Foreground')
$engineText = $engineText.Replace('SENETECH Setup V1.6.0 DEV - build 17 demarre','SENETECH Setup V1.6.0 DEV - build 25 RECOVERY demarre')

if (-not $engineText.Contains("`$script:AppVersion = '1.6.0.25'")) {
    throw 'Recovery build 25 : normalisation AppVersion impossible.'
}
if ($engineText.Contains('Title=\"SENETECH Setup')) {
    throw 'Recovery build 25 : guillemets XAML invalides detectes.'
}
[IO.File]::WriteAllText($enginePath,$engineText,$utf8Bom)

if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath,$utf8NoBom)
    $manifestText = $manifestText.Replace('version="1.6.0.17"','version="1.6.0.25"')
    [IO.File]::WriteAllText($manifestPath,$manifestText,$utf8NoBom)
}

Set-Content -LiteralPath $versionPath -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.25
Affichage : 1.6.0 DEV - build 25 RECOVERY
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Base moteur : snapshot exact V1.6.0.17 commit 7dc64fd
Reporter : desactive dans cette build de recuperation
Instrumentation startup : desactivee dans cette build de recuperation
Updater : V23 durci livre en overlay pour les mises a jour suivantes
Objectif : restaurer un SENETECH qui s ouvre avant de reintegrer les fonctions 18+
'@

Write-Output 'SENETECH V1.6.0 DEV build 25 RECOVERY - snapshot last-known-good build 17 applique.'
