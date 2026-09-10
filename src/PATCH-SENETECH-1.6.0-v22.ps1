param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'

# Apply complete build 19 first.
$previousPatch = Join-Path $env:TEMP 'SENETECH-PATCH-1.6.0-v21.ps1'
$previousPatchUrl = 'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/develop/src/PATCH-SENETECH-1.6.0-v21.ps1'
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

# A DEV build can be newer numerically than Stable. The legacy updater therefore
# refuses the lower Stable manifest. Route update actions through a wrapper that
# treats Stable as an explicit channel switch while preserving SHA-256 and backup.
if (-not $engineText.Contains("'UPDATE-SENETECH.ps1'")) {
    throw 'Patch V1.6.0.20 impossible : updater principal introuvable.'
}
$engineText = $engineText.Replace("'UPDATE-SENETECH.ps1'","'UPDATE-SENETECH-CHANNEL.ps1'")

$engineText = $engineText.Replace("`$script:AppVersion = '1.6.0.19'", "`$script:AppVersion = '1.6.0.20'")
$engineText = $engineText.Replace("`$script:DisplayVersion = '1.6.0 DEV - build 19'", "`$script:DisplayVersion = '1.6.0 DEV - build 20'")
$engineText = $engineText.Replace('Title="SENETECH Setup V1.6.0 DEV - build 19"','Title="SENETECH Setup V1.6.0 DEV - build 20"')
$engineText = $engineText.Replace('VERSION 1.6.0 DEV - BUILD 19" Foreground','VERSION 1.6.0 DEV - BUILD 20" Foreground')
$engineText = $engineText.Replace('SENETECH Setup V1.6.0 DEV - build 19 demarre','SENETECH Setup V1.6.0 DEV - build 20 demarre')
[IO.File]::WriteAllText($enginePath,$engineText,$utf8Bom)

$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath,$utf8NoBom)
    $manifestText = $manifestText.Replace('version="1.6.0.19"','version="1.6.0.20"')
    [IO.File]::WriteAllText($manifestPath,$manifestText,$utf8NoBom)
}

Set-Content -LiteralPath (Join-Path $StageDir 'VERSION.txt') -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.20
Affichage : 1.6.0 DEV - build 20
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Reporter : Cloudflare Worker + Assistance SENETECH
Correctif : passage Develop vers Stable reel avec backup et verification SHA-256
'@

Write-Output 'SENETECH V1.6.0 DEV build 20 - changement Stable/Develop corrige.'
