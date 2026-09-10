param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'

# Fallback path for a machine entering Develop from Stable. Existing V1.6 builds
# use PATCH-SENETECH-1.6.0-v24.ps1 directly and do not execute this chain.
$previousPatch = Join-Path $env:TEMP 'SENETECH-PATCH-1.6.0-v23.ps1'
$previousPatchUrl = 'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/develop/src/PATCH-SENETECH-1.6.0-v23.ps1'
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

if (-not $engineText.Contains("`$script:AppVersion = '1.6.0.21'")) {
    throw 'Patch fallback V1.6.0.22 : build 21 intermediaire introuvable.'
}
$engineText = $engineText.Replace("`$script:AppVersion = '1.6.0.21'", "`$script:AppVersion = '1.6.0.22'")
$engineText = $engineText.Replace("`$script:DisplayVersion = '1.6.0 DEV - build 21'", "`$script:DisplayVersion = '1.6.0 DEV - build 22'")
$engineText = $engineText.Replace('Title="SENETECH Setup V1.6.0 DEV - build 21"','Title="SENETECH Setup V1.6.0 DEV - build 22"')
$engineText = $engineText.Replace('VERSION 1.6.0 DEV - BUILD 21" Foreground','VERSION 1.6.0 DEV - BUILD 22" Foreground')
$engineText = $engineText.Replace('SENETECH Setup V1.6.0 DEV - build 21 demarre','SENETECH Setup V1.6.0 DEV - build 22 demarre')
[IO.File]::WriteAllText($enginePath,$engineText,$utf8Bom)

$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath,$utf8NoBom)
    $manifestText = $manifestText.Replace('version="1.6.0.21"','version="1.6.0.22"')
    [IO.File]::WriteAllText($manifestPath,$manifestText,$utf8NoBom)
}

Set-Content -LiteralPath (Join-Path $StageDir 'VERSION.txt') -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.22
Affichage : 1.6.0 DEV - build 22
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Mises a jour : updater garde + voie incrementale V1.6
Journal : C:\ProgramData\SENETECH\Logs\SENETECH-Updater.log
'@

Write-Output 'SENETECH V1.6.0 DEV build 22 - fallback Stable vers Develop applique.'
