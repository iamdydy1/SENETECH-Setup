param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'

# Apply the current V1.6 feature patch first.
$previousPatch = Join-Path $env:TEMP 'SENETECH-PATCH-1.6.0-v2.ps1'
$previousPatchUrl = 'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/develop/src/PATCH-SENETECH-1.6.0-v2.ps1'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri $previousPatchUrl -OutFile $previousPatch
    & $previousPatch -StageDir $StageDir
} finally {
    Remove-Item -LiteralPath $previousPatch -Force -ErrorAction SilentlyContinue
}

# Windows PowerShell 5.1 can interpret UTF-8 scripts without a BOM as the
# current ANSI code page. Normalize every SENETECH PowerShell runtime file to
# UTF-8 with BOM so punctuation and future localized strings remain correct.
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$engineDir = Join-Path $StageDir '_SENETECH'
foreach ($file in @(Get-ChildItem -LiteralPath $engineDir -Filter '*.ps1' -File -Recurse -ErrorAction Stop)) {
    $text = [IO.File]::ReadAllText($file.FullName, $utf8NoBom)
    [IO.File]::WriteAllText($file.FullName, $text, $utf8Bom)
}

# Technical hotfix build number. Display name remains V1.6.0 DEV.
$enginePath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.ps1'
$engineText = [IO.File]::ReadAllText($enginePath, $utf8Bom)
$engineText = $engineText.Replace('$script:AppVersion = ''1.6.0.0''', '$script:AppVersion = ''1.6.0.1''')
[IO.File]::WriteAllText($enginePath, $engineText, $utf8Bom)

$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath, $utf8NoBom)
    $manifestText = $manifestText.Replace('version="1.6.0.0"', 'version="1.6.0.1"')
    [IO.File]::WriteAllText($manifestPath, $manifestText, $utf8NoBom)
}

Set-Content -LiteralPath (Join-Path $StageDir 'VERSION.txt') -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.1
Affichage : 1.6.0 DEV
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Mises a jour : GitHub + SHA-256 + rollback
Correctif : UTF-8 Windows PowerShell 5.1
'@

Write-Output 'SENETECH V1.6.0 DEV build 1 - correctif UTF-8 applique.'
