param(
    [string]$ManifestPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'version.json')
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "version.json introuvable : $ManifestPath"
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$version = [string]$manifest.version
$channel = [string]$manifest.channel

if ($version -notmatch '^\d+\.\d+\.\d+\.\d+$') {
    throw "Version invalide dans version.json : $version"
}
if ($channel -notin @('develop','stable')) {
    throw "Canal invalide dans version.json : $channel"
}

$runtimeDir = Join-Path $repoRoot 'dist\runtime'
$installerDir = Join-Path $repoRoot 'dist\installer'

Write-Host ''
Write-Host '============================================================'
Write-Host " SENETECH - Build installateur complet"
Write-Host " Version : $version"
Write-Host " Canal   : $channel"
Write-Host '============================================================'
Write-Host ''

& (Join-Path $PSScriptRoot 'Prepare-SenetechFullPackage.ps1') -ManifestPath $ManifestPath -OutputDir $runtimeDir
if ($LASTEXITCODE -ne 0) {
    throw "Assemblage du runtime en echec : code $LASTEXITCODE"
}

& (Join-Path $PSScriptRoot 'Build-SenetechInstaller.ps1') -Version $version -Channel $channel -SourceDir $runtimeDir -OutputDir $installerDir
if ($LASTEXITCODE -ne 0) {
    throw "Compilation Inno Setup en echec : code $LASTEXITCODE"
}

$label = if ($channel -eq 'stable') { 'STABLE' } else { 'DEV' }
$installer = Join-Path $installerDir "SENETECH-Setup-$version-$label.exe"
$hashFile = "$installer.sha256"
$metadata = Join-Path $installerDir 'installer-manifest.json'

if (-not (Test-Path -LiteralPath $installer)) {
    throw "Installateur final introuvable : $installer"
}

Write-Host ''
Write-Host '============================================================'
Write-Host ' BUILD SENETECH TERMINE'
Write-Host " Installateur : $installer"
Write-Host " SHA-256      : $hashFile"
Write-Host " Manifest     : $metadata"
Write-Host '============================================================'
Write-Host ''

try {
    Start-Process explorer.exe -ArgumentList ('"' + $installerDir + '"')
} catch { }
