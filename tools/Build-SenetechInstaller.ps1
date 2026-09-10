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

# Inno Setup resolves relative Source/Output paths from the .iss location.
# Always feed absolute paths so local builds and GitHub Actions produce the same result.
$IssPath = (Resolve-Path -LiteralPath $IssPath).Path
$SourceDir = (Resolve-Path -LiteralPath $SourceDir).Path
$OutputDir = [IO.Path]::GetFullPath($OutputDir)

foreach ($required in @('SENETECH-Setup.exe','VERSION.txt','_SENETECH\SENETECH-Setup.ps1','_SENETECH\SENETECH-Setup.manifest')) {
    if (-not (Test-Path -LiteralPath (Join-Path $SourceDir $required))) { throw "Runtime incomplet : $required" }
}

function Find-InnoCompiler {
    $candidates = @()

    try {
        $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) { $candidates += [string]$cmd.Source }
    } catch { }

    foreach ($base in @(${env:ProgramFiles(x86)}, $env:ProgramFiles, $env:LOCALAPPDATA)) {
        if ([string]::IsNullOrWhiteSpace([string]$base)) { continue }
        foreach ($folder in @(
            'Inno Setup 7\ISCC.exe',
            'Inno Setup 6\ISCC.exe',
            'Programs\Inno Setup 7\ISCC.exe',
            'Programs\Inno Setup 6\ISCC.exe'
        )) {
            try { $candidates += (Join-Path $base $folder) } catch { }
        }
    }

    foreach ($regPath in @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )) {
        try {
            foreach ($entry in @(Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue | Where-Object {
                [string]$_.DisplayName -like 'Inno Setup*'
            })) {
                if ($entry.InstallLocation) {
                    $candidates += (Join-Path ([string]$entry.InstallLocation) 'ISCC.exe')
                }
            }
        } catch { }
    }

    return @($candidates |
        Where-Object { $_ -and (Test-Path -LiteralPath $_) } |
        Select-Object -Unique |
        Select-Object -First 1)
}

$iscc = Find-InnoCompiler
if (-not $iscc) {
    throw 'ISCC.exe introuvable. Installez Inno Setup 7 ou 6 puis relancez le build.'
}
Write-Host "[SENETECH] Inno Setup compiler : $iscc"

Remove-Item -LiteralPath $OutputDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$channelLabel = if ($Channel -eq 'stable') { 'STABLE' } else { 'DEV' }

Write-Host "[SENETECH] Compilation Inno Setup $Version $channelLabel"
Write-Host "[SENETECH] Source runtime : $SourceDir"
Write-Host "[SENETECH] Output installer : $OutputDir"

& $iscc "/DAppVersion=$Version" "/DChannel=$channelLabel" "/DSourceDir=$SourceDir" "/DOutputDir=$OutputDir" $IssPath
if ($LASTEXITCODE -ne 0) { throw "Compilation Inno Setup échouée (code $LASTEXITCODE)." }

$expectedName = "SENETECH-Setup-$Version-$channelLabel.exe"
$installer = Join-Path $OutputDir $expectedName
if (-not (Test-Path -LiteralPath $installer)) { throw "Installateur attendu introuvable : $installer" }

$hash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
$size = (Get-Item -LiteralPath $installer).Length
$metadata = [ordered]@{
    schemaVersion = 2
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
$metadata | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $metadataPath -Encoding UTF8
("{0}  {1}" -f $hash,$expectedName) | Set-Content -LiteralPath (Join-Path $OutputDir ($expectedName + '.sha256')) -Encoding ASCII

Write-Host "[SENETECH] Installateur : $installer"
Write-Host "[SENETECH] Taille : $size octets"
Write-Host "[SENETECH] SHA-256 : $hash"
