param(
    [string]$ManifestPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'version.json'),
    [string]$OutputDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'dist\runtime')
)

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
        finally { $sha.Dispose() }
    } finally { $stream.Dispose() }
}

function Download-File([string]$Url,[string]$Destination) {
    if ([string]::IsNullOrWhiteSpace($Url) -or -not $Url.StartsWith('https://',[StringComparison]::OrdinalIgnoreCase)) {
        throw "URL HTTPS invalide : $Url"
    }
    $parent = Split-Path -Parent $Destination
    if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $headers = @{ 'User-Agent'='SENETECH-FullPackageBuilder'; 'Cache-Control'='no-cache'; 'Pragma'='no-cache' }
    $nonce = [guid]::NewGuid().ToString('N')
    $sep = if ($Url.Contains('?')) { '&' } else { '?' }
    Invoke-WebRequest -UseBasicParsing -Uri ($Url + $sep + 'senetech=' + $nonce) -Headers $headers -OutFile $Destination -TimeoutSec 120
    if (-not (Test-Path -LiteralPath $Destination)) { throw "Téléchargement absent : $Url" }
}

function Assert-Hash([string]$Path,[string]$Expected,[string]$Label) {
    if ([string]::IsNullOrWhiteSpace($Expected)) { throw "SHA-256 absent pour $Label" }
    $actual = Get-Sha256 $Path
    if ($actual -ne $Expected.ToLowerInvariant()) { throw "$Label SHA-256 mismatch. attendu=$Expected réel=$actual" }
}

function Get-SafeOutputPath([string]$RelativePath) {
    $root = [IO.Path]::GetFullPath($OutputDir).TrimEnd('\') + '\'
    $candidate = [IO.Path]::GetFullPath((Join-Path $OutputDir $RelativePath))
    if (-not $candidate.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)) {
        throw "Chemin overlay refusé : $RelativePath"
    }
    return $candidate
}

if (-not (Test-Path -LiteralPath $ManifestPath)) { throw "Manifest introuvable : $ManifestPath" }
$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $manifest.enabled) { throw 'Le manifest sélectionné est désactivé.' }

$tempRoot = Join-Path $env:TEMP ('SENETECH-FULL-' + [guid]::NewGuid().ToString('N'))
$zipPath = Join-Path $tempRoot 'base.zip'
$patchPath = Join-Path $tempRoot 'patch.ps1'

try {
    Remove-Item -LiteralPath $OutputDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $OutputDir,$tempRoot -Force | Out-Null

    $baseUrl = if ($manifest.PSObject.Properties.Name -contains 'baseDownloadUrl' -and $manifest.baseDownloadUrl) { [string]$manifest.baseDownloadUrl } else { [string]$manifest.downloadUrl }
    $baseHash = if ($manifest.PSObject.Properties.Name -contains 'baseSha256' -and $manifest.baseSha256) { [string]$manifest.baseSha256 } else { [string]$manifest.sha256 }
    $baseSize = if ($manifest.PSObject.Properties.Name -contains 'basePackageSize' -and $manifest.basePackageSize) { [int64]$manifest.basePackageSize } elseif ($manifest.packageSize) { [int64]$manifest.packageSize } else { 0 }

    Write-Host "[SENETECH] Base package : $baseUrl"
    Download-File $baseUrl $zipPath
    if ($baseSize -gt 0) {
        $actualSize = (Get-Item -LiteralPath $zipPath).Length
        if ($actualSize -ne $baseSize) { throw "Taille package incorrecte. attendu=$baseSize réel=$actualSize" }
    }
    Assert-Hash $zipPath $baseHash 'Package de base'

    if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
        Expand-Archive -LiteralPath $zipPath -DestinationPath $OutputDir -Force
    } else {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::ExtractToDirectory($zipPath,$OutputDir)
    }

    if ($manifest.PSObject.Properties.Name -contains 'patchUrl' -and $manifest.patchUrl) {
        Write-Host "[SENETECH] Patch complet : $($manifest.patchUrl)"
        Download-File ([string]$manifest.patchUrl) $patchPath
        if ($manifest.PSObject.Properties.Name -contains 'patchSha256' -and $manifest.patchSha256) {
            Assert-Hash $patchPath ([string]$manifest.patchSha256) 'Patch complet'
        } else {
            throw 'Le patch complet doit avoir un SHA-256 avant construction de l installateur.'
        }

        $stdout = Join-Path $tempRoot 'patch.stdout.log'
        $stderr = Join-Path $tempRoot 'patch.stderr.log'
        $args = '-NoProfile -ExecutionPolicy Bypass -File "' + $patchPath + '" -StageDir "' + $OutputDir + '"'
        $p = Start-Process powershell.exe -ArgumentList $args -PassThru -Wait -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        if ($p.ExitCode -ne 0) {
            $detail = if (Test-Path $stderr) { (Get-Content $stderr -Tail 20 -ErrorAction SilentlyContinue) -join ' | ' } else { '' }
            throw "Patch complet en échec (code $($p.ExitCode)) : $detail"
        }
    }

    foreach ($overlay in @($manifest.overlayFiles)) {
        $url = [string]$overlay.url
        $relative = [string]$overlay.path
        $target = Get-SafeOutputPath $relative
        Write-Host "[SENETECH] Overlay : $relative"
        Download-File $url $target
        if ($overlay.PSObject.Properties.Name -contains 'sha256' -and -not [string]::IsNullOrWhiteSpace([string]$overlay.sha256)) {
            Assert-Hash $target ([string]$overlay.sha256) "Overlay $relative"
        } else {
            Write-Warning "Overlay sans SHA-256 : $relative. Autorisé temporairement pour DEV, interdit pour une publication Stable."
        }
    }

    $required = @('SENETECH-Setup.exe','_SENETECH\SENETECH-Setup.ps1','_SENETECH\SENETECH-Setup.manifest')
    if ($manifest.PSObject.Properties.Name -contains 'requiredFiles' -and $manifest.requiredFiles) {
        $required += @($manifest.requiredFiles | ForEach-Object { [string]$_ })
    }
    foreach ($relative in ($required | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath (Join-Path $OutputDir $relative))) {
            throw "Package complet incomplet : $relative"
        }
    }

    $scripts = @(Get-ChildItem -LiteralPath $OutputDir -Filter '*.ps1' -File -Recurse -ErrorAction Stop)
    foreach ($file in $scripts) {
        $tokens = $null; $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
        if ($errors -and $errors.Count -gt 0) {
            throw "Erreur syntaxe PowerShell : $($file.FullName) : $($errors[0].Message)"
        }
    }

    $sourceRecord = [ordered]@{
        schemaVersion = 1
        product = 'SENETECH Setup'
        version = [string]$manifest.version
        channel = [string]$manifest.channel
        builtAt = (Get-Date).ToUniversalTime().ToString('o')
        manifestPath = [IO.Path]::GetFullPath($ManifestPath)
        manifestSha256 = Get-Sha256 $ManifestPath
        fileCount = @(Get-ChildItem -LiteralPath $OutputDir -File -Recurse).Count
        powershellFileCount = $scripts.Count
    }
    $sourceRecord | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $OutputDir 'SENETECH-BUILD-SOURCE.json') -Encoding UTF8

    Write-Host "[SENETECH] Package complet prêt : $OutputDir"
    Write-Host "[SENETECH] Version : $($manifest.version) | Canal : $($manifest.channel) | Scripts validés : $($scripts.Count)"
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
