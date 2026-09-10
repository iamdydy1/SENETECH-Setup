param(
    [string]$CurrentVersion = '1.5.1.0',
    [string]$InstallDir = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [string]$UpdateChannel = 'stable',
    [int]$WaitForProcessId = 0,
    [switch]$NoRestart
)

$ErrorActionPreference = 'Stop'
$UpdateChannel = if (([string]$UpdateChannel).ToLowerInvariant() -eq 'develop') { 'develop' } else { 'stable' }
$UpdateBranch = if ($UpdateChannel -eq 'develop') { 'develop' } else { 'main' }
$ManifestUrl = "https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/$UpdateBranch/version.json"
$TempRoot = Join-Path $env:TEMP 'SENETECH-Update'
$ZipPath = Join-Path $TempRoot 'SENETECH-package.zip'
$StageDir = Join-Path $TempRoot 'stage'
$BackupDir = Join-Path $TempRoot 'backup'
$LogPath = Join-Path $env:TEMP 'SENETECH-Update.log'
$CleanupScript = Join-Path $env:TEMP 'SENETECH-Cleanup.cmd'

function Write-UpdateLog([string]$Text) {
    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $UpdateChannel.ToUpperInvariant(), $Text
    try {
        if (Test-Path $LogPath) {
            $info = Get-Item $LogPath -ErrorAction SilentlyContinue
            if ($info -and $info.Length -gt 1MB) { Remove-Item $LogPath -Force -ErrorAction SilentlyContinue }
        }
        Add-Content -Path $LogPath -Value $line -Encoding UTF8
    } catch { }
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
        finally { $sha.Dispose() }
    } finally { $stream.Dispose() }
}

function Assert-Https([string]$Url, [string]$Label) {
    if ([string]::IsNullOrWhiteSpace($Url) -or -not $Url.StartsWith('https://',[StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label doit utiliser HTTPS."
    }
}

function Copy-SenetechRuntime([string]$Source, [string]$Destination) {
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    foreach ($name in @('SENETECH-Setup.exe','VERSION.txt','LISEZ-MOI.txt','CHANGELOG.txt')) {
        $src = Join-Path $Source $name
        if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $Destination $name) -Force }
    }
    $engineSrc = Join-Path $Source '_SENETECH'
    if (Test-Path -LiteralPath $engineSrc) {
        $engineDst = Join-Path $Destination '_SENETECH'
        New-Item -ItemType Directory -Force -Path $engineDst | Out-Null
        Get-ChildItem -LiteralPath $engineSrc -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne 'Rollback' } |
            Copy-Item -Destination $engineDst -Recurse -Force
    }
}

function Get-SafeStagePath([string]$RelativePath) {
    if ([string]::IsNullOrWhiteSpace($RelativePath)) { throw 'Chemin overlay vide.' }
    $root = [IO.Path]::GetFullPath($StageDir).TrimEnd('\') + '\'
    $candidate = [IO.Path]::GetFullPath((Join-Path $StageDir $RelativePath))
    if (-not $candidate.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)) { throw "Chemin overlay refuse : $RelativePath" }
    return $candidate
}

try {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }
    $headers = @{ 'User-Agent' = "SENETECH-Setup/$CurrentVersion" }
    Write-UpdateLog "Checking $ManifestUrl"
    $manifest = Invoke-RestMethod -Uri $ManifestUrl -Headers $headers -UseBasicParsing
    if (-not $manifest.enabled) { Write-UpdateLog 'Update service disabled.'; exit 0 }

    $local = New-Object System.Version($CurrentVersion)
    $remote = New-Object System.Version([string]$manifest.version)
    if ($remote -le $local) { Write-UpdateLog "Already current: $CurrentVersion"; exit 0 }

    $baseUrl = if ($manifest.PSObject.Properties.Name -contains 'baseDownloadUrl' -and $manifest.baseDownloadUrl) { [string]$manifest.baseDownloadUrl } else { [string]$manifest.downloadUrl }
    $baseHash = if ($manifest.PSObject.Properties.Name -contains 'baseSha256' -and $manifest.baseSha256) { [string]$manifest.baseSha256 } else { [string]$manifest.sha256 }
    $baseSize = if ($manifest.PSObject.Properties.Name -contains 'basePackageSize' -and $manifest.basePackageSize) { [int64]$manifest.basePackageSize } elseif ($manifest.packageSize) { [int64]$manifest.packageSize } else { 0 }
    Assert-Https $baseUrl 'URL du package'
    if ([string]::IsNullOrWhiteSpace($baseHash)) { throw 'SHA-256 du package absent.' }

    Remove-Item $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $CleanupScript -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $StageDir,$BackupDir -Force | Out-Null

    Write-UpdateLog "Downloading base package for SENETECH $($manifest.version)"
    Invoke-WebRequest -Uri $baseUrl -Headers $headers -OutFile $ZipPath -UseBasicParsing
    if ($baseSize -gt 0) {
        $actualSize = (Get-Item -LiteralPath $ZipPath).Length
        if ($actualSize -ne $baseSize) { throw "Package size mismatch: $actualSize bytes" }
        Write-UpdateLog "Base package size OK: $actualSize bytes."
    }
    $actualHash = Get-Sha256 $ZipPath
    if ($actualHash -ne $baseHash.ToLowerInvariant()) { throw "Package SHA-256 mismatch: $actualHash" }
    Write-UpdateLog 'Base package SHA-256 verification OK.'

    if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) { Expand-Archive -Path $ZipPath -DestinationPath $StageDir -Force }
    else { Add-Type -AssemblyName System.IO.Compression.FileSystem; [IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $StageDir) }
    Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue

    if ($manifest.PSObject.Properties.Name -contains 'patchUrl' -and $manifest.patchUrl) {
        $patchUrl = [string]$manifest.patchUrl
        Assert-Https $patchUrl 'URL du patch'
        $patchPath = Join-Path $TempRoot 'SENETECH-DEVELOP-PATCH.ps1'
        Invoke-WebRequest -Uri $patchUrl -Headers $headers -OutFile $patchPath -UseBasicParsing
        if ($manifest.PSObject.Properties.Name -contains 'patchSha256' -and $manifest.patchSha256) {
            $patchHash = Get-Sha256 $patchPath
            if ($patchHash -ne ([string]$manifest.patchSha256).ToLowerInvariant()) { throw "Patch SHA-256 mismatch: $patchHash" }
        }
        Write-UpdateLog 'Applying SENETECH development patch.'
        $patchProcess = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$patchPath+'"'),'-StageDir',('"'+$StageDir+'"')) -PassThru -WindowStyle Hidden -Wait
        if ($patchProcess.ExitCode -ne 0) { throw "Development patch failed with code $($patchProcess.ExitCode)." }
    }

    if ($manifest.PSObject.Properties.Name -contains 'overlayFiles' -and $manifest.overlayFiles) {
        foreach ($overlay in @($manifest.overlayFiles)) {
            $url = [string]$overlay.url
            $relative = [string]$overlay.path
            Assert-Https $url "Overlay $relative"
            $target = Get-SafeStagePath $relative
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            Invoke-WebRequest -Uri $url -Headers $headers -OutFile $target -UseBasicParsing
            if ($overlay.PSObject.Properties.Name -contains 'sha256' -and $overlay.sha256) {
                $overlayHash = Get-Sha256 $target
                if ($overlayHash -ne ([string]$overlay.sha256).ToLowerInvariant()) { throw "Overlay SHA-256 mismatch: $relative" }
            }
            Write-UpdateLog "Overlay installed: $relative"
        }
    }

    $required = @('SENETECH-Setup.exe','_SENETECH\SENETECH-Setup.ps1','_SENETECH\SENETECH-Setup.manifest')
    if ($manifest.PSObject.Properties.Name -contains 'requiredFiles' -and $manifest.requiredFiles) { $required += @($manifest.requiredFiles | ForEach-Object { [string]$_ }) }
    foreach ($relative in ($required | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath (Join-Path $StageDir $relative))) { throw "Incomplete SENETECH package: missing $relative" }
    }

    if (Test-Path -LiteralPath $InstallDir) {
        Copy-SenetechRuntime -Source $InstallDir -Destination $BackupDir
        Write-UpdateLog "Current runtime backed up from $InstallDir"
    }

    $waitBlock = ''
    if ($WaitForProcessId -gt 0) {
        $waitBlock = @"
:WAIT_FOR_SENETECH
tasklist /FI "PID eq $WaitForProcessId" /NH | find "$WaitForProcessId" >nul
if not errorlevel 1 (
  ping 127.0.0.1 -n 2 >nul
  goto WAIT_FOR_SENETECH
)
"@
    }
    $restartLine = ''
    if (-not $NoRestart) { $exePath = Join-Path $InstallDir 'SENETECH-Setup.exe'; $restartLine = 'start "" "' + $exePath + '"' }
    $rollbackDir = Join-Path $InstallDir '_SENETECH\Rollback\previous'
    $rollbackMeta = Join-Path $rollbackDir 'rollback.json'
    $escapedCurrent = $CurrentVersion.Replace('"','')
    $escapedRemote = ([string]$manifest.version).Replace('"','')
    $cleanupText = @"
@echo off
ping 127.0.0.1 -n 5 >nul
rd /s /q "$TempRoot" 2>nul
del /f /q "%~f0" >nul 2>&1
"@
    Set-Content -Path $CleanupScript -Value $cleanupText -Encoding ASCII
    $applyScript = Join-Path $TempRoot 'APPLY-SENETECH-UPDATE.cmd'
    $applyText = @"
@echo off
setlocal
$waitBlock
ping 127.0.0.1 -n 2 >nul
if not exist "$InstallDir" mkdir "$InstallDir" >nul 2>&1
if exist "$BackupDir" (
  if exist "$rollbackDir" rd /s /q "$rollbackDir"
  mkdir "$rollbackDir" >nul 2>&1
  xcopy "$BackupDir\*" "$rollbackDir\" /E /I /Y /Q >nul
  >"$rollbackMeta" echo {"fromVersion":"$escapedCurrent","replacedBy":"$escapedRemote"}
)
xcopy "$StageDir\*" "$InstallDir\" /E /I /Y /Q >nul
if errorlevel 1 exit /b 1
$restartLine
start "" /b "$CleanupScript"
exit /b 0
"@
    Set-Content -Path $applyScript -Value $applyText -Encoding ASCII
    Write-UpdateLog 'Package ready. Backup created; applying update.'
    Start-Process -FilePath $applyScript -WindowStyle Hidden
    exit 10
}
catch {
    Write-UpdateLog ('ERROR: ' + $_.Exception.Message)
    try { Remove-Item $TempRoot -Recurse -Force -ErrorAction SilentlyContinue } catch { }
    exit 1
}
