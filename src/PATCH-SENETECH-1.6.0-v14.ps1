param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'

# Apply previous V1.6.0.11 patch first.
$previousPatch = Join-Path $env:TEMP 'SENETECH-PATCH-1.6.0-v13.ps1'
$previousPatchUrl = 'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/develop/src/PATCH-SENETECH-1.6.0-v13.ps1'
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

# Force a new technical build so machines that already report 1.6.0.11 receive
# the DisplayName inventory fix again, and expose the build visibly in the UI.
$engineText = $engineText.Replace("`$script:AppVersion = '1.6.0.11'", "`$script:AppVersion = '1.6.0.12'")
$engineText = $engineText.Replace("`$script:DisplayVersion = '1.6.0 DEV'", "`$script:DisplayVersion = '1.6.0 DEV - build 12'")
$engineText = $engineText.Replace('Title="SENETECH Setup V1.6.0 DEV"','Title="SENETECH Setup V1.6.0 DEV - build 12"')
$engineText = $engineText.Replace('VERSION 1.6.0 DEV" Foreground','VERSION 1.6.0 DEV - BUILD 12" Foreground')
$engineText = $engineText.Replace('SENETECH Setup V1.6.0 DEV demarre','SENETECH Setup V1.6.0 DEV - build 12 demarre')
[IO.File]::WriteAllText($enginePath,$engineText,$utf8Bom)

$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath,$utf8NoBom)
    $manifestText = $manifestText.Replace('version="1.6.0.11"','version="1.6.0.12"')
    [IO.File]::WriteAllText($manifestPath,$manifestText,$utf8NoBom)
}

Set-Content -LiteralPath (Join-Path $StageDir 'VERSION.txt') -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.12
Affichage : 1.6.0 DEV - build 12
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Mises a jour : GitHub + SHA-256 + rollback
Correctif : reinjection du correctif inventaire DisplayName + build visible dans interface
'@

Write-Output 'SENETECH V1.6.0 DEV build 12 - version visible et correctif inventaire reinjecte.'
