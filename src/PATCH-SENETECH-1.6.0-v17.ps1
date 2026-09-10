param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'

# Apply previous V1.6.0.14 patch first.
$previousPatch = Join-Path $env:TEMP 'SENETECH-PATCH-1.6.0-v16.ps1'
$previousPatchUrl = 'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/develop/src/PATCH-SENETECH-1.6.0-v16.ps1'
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

# Build 15 is a startup-recovery build. Senetech.FrenchUi.ps1 was fixed so its
# accent-token map no longer contains case-insensitive duplicate hashtable keys.
$engineText = $engineText.Replace("`$script:AppVersion = '1.6.0.14'", "`$script:AppVersion = '1.6.0.15'")
$engineText = $engineText.Replace("`$script:DisplayVersion = '1.6.0 DEV - build 14'", "`$script:DisplayVersion = '1.6.0 DEV - build 15'")
$engineText = $engineText.Replace('Title="SENETECH Setup V1.6.0 DEV - build 14"','Title="SENETECH Setup V1.6.0 DEV - build 15"')
$engineText = $engineText.Replace('VERSION 1.6.0 DEV - BUILD 14" Foreground','VERSION 1.6.0 DEV - BUILD 15" Foreground')
$engineText = $engineText.Replace('SENETECH Setup V1.6.0 DEV - build 14 demarre','SENETECH Setup V1.6.0 DEV - build 15 demarre')
[IO.File]::WriteAllText($enginePath,$engineText,$utf8Bom)

$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath,$utf8NoBom)
    $manifestText = $manifestText.Replace('version="1.6.0.14"','version="1.6.0.15"')
    [IO.File]::WriteAllText($manifestPath,$manifestText,$utf8NoBom)
}

Set-Content -LiteralPath (Join-Path $StageDir 'VERSION.txt') -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.15
Affichage : 1.6.0 DEV - build 15
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Mises a jour : GitHub + SHA-256 + rollback
Correctif critique : demarrage restaure apres correction du module interface francaise
'@

Write-Output 'SENETECH V1.6.0 DEV build 15 - correctif critique de demarrage applique.'