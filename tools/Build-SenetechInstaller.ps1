param(
    [Parameter(Mandatory=$true)][string]$Version,
    [ValidateSet('stable','develop')][string]$Channel = 'develop',
    [string]$SourceDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'dist\runtime'),
    [string]$OutputDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'dist\installer'),
    [string]$IssPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'installer\SENETECH.iss')
)

$ErrorActionPreference = 'Stop'

if ($Version -notmatch '^\d+\.\d+\.\d+\.\d+$') {
    throw "Version invalide '$Version'. Format requis : X.Y.Z.W (ex: 1.6.0.26)."
}
if (-not (Test-Path -LiteralPath $IssPath)) { throw "Script Inno Setup introuvable : $IssPath" }
if (-not (Test-Path -LiteralPath $SourceDir)) { throw "Runtime complet introuvable : $SourceDir" }
foreach ($required in @('SENETECH-Setup.exe','VERSION.txt','_SENETECH\SENETECH-Setup.ps1','_SENETECH\SENETECH-Setup.manifest')) {
    if (-not (Test-Path -LiteralPath (Join-Path $SourceDir $required))) { throw "Runtime incomplet : $required" }
}

$isccCandidates = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
    (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
    'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
$iscc = $isccCandidates | Select-Object -First 1
if (-not $iscc) { throw 'ISCC.exe (Inno Setup 6) introuvable.' }

Remove-Item -LiteralPath $OutputDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$channelLabel = if ($Channel -eq 'stable') { 'STABLE' } else { 'DEV' }

Write-Host "[SENETECH] Compilation Inno Setup $Version $channelLabel"
& $iscc "/DAppVersion=$Version" "/DChannel=$channelLabel" "/DSourceDir=$SourceDir" "/DOutputDir=$OutputDir" $IssPath
if ($LASTEXITCODE -ne 0) { throw "Compilation Inno Setup échouée (code $LASTEXITCODE)." }

$expectedName = "SENETECH-Setup-$Version-$channelLabel.exe"
$installer = Join-Path $OutputDir $expectedName
if (-not (Test-Path -LiteralPath $installer)) { throw "Installateur attendu introuvable : $installer" }

$hash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
$size = (Get-Item -LiteralPath $installer).Length
$metadata = [ordered]@{
    schemaVersion = 1
    product = 'SENETECH Setup'
    packageType = 'inno'
    version = $Version
    channel = $Channel
    fileName = $expectedName
    size = $size
    sha256 = $hash
    appExe = 'SENETECH-Setup.exe'
    appId = '{D57F5D8B-58E9-4D92-9D48-6EA0A2AC3F2E}'
    defaultInstallDir = 'C:\Program Files\SENETECH'
    builtAt = (Get-Date).ToUniversalTime().ToString('o')
}
$metadataPath = Join-Path $OutputDir 'installer-manifest.json'
$metadata | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $metadataPath -Encoding UTF8
("{0}  {1}" -f $hash,$expectedName) | Set-Content -LiteralPath (Join-Path $OutputDir ($expectedName + '.sha256')) -Encoding ASCII

Write-Host "[SENETECH] Installateur : $installer"
Write-Host "[SENETECH] Taille : $size octets"
Write-Host "[SENETECH] SHA-256 : $hash"
