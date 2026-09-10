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
$ZipPath = Join-Path $TempRoot 'package.zip'
$StageDir = Join-Path $TempRoot 'stage'
$LogPath = Join-Path $env:TEMP 'SENETECH-Update.log'
$Cleanup = Join-Path $env:TEMP 'SENETECH-Cleanup.cmd'

function Log([string]$Text) {
    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $UpdateChannel.ToUpperInvariant(), $Text
    try { Add-Content -Path $LogPath -Value $line -Encoding UTF8 } catch {}
}

function Hash256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
        finally { $sha.Dispose() }
    }
    finally { $stream.Dispose() }
}

try {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
    $headers = @{ 'User-Agent' = "SENETECH-Setup/$CurrentVersion" }
    Log "Checking $ManifestUrl"
    $m = Invoke-RestMethod -Uri $ManifestUrl -Headers $headers -UseBasicParsing

    if (-not $m.enabled) { exit 0 }
    if ((New-Object Version([string]$m.version)) -le (New-Object Version($CurrentVersion))) { exit 0 }

    if (Test-Path $TempRoot) { Remove-Item $TempRoot -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path $Cleanup) { Remove-Item $Cleanup -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $StageDir -Force | Out-Null

    Log "Downloading SENETECH $($m.version)"
    if ($m.packageParts -and @($m.packageParts).Count -gt 0) {
        $b = New-Object Text.StringBuilder
        foreach ($url in @($m.packageParts)) {
            $t = (Invoke-WebRequest -Uri ([string]$url) -Headers $headers -UseBasicParsing).Content
            [void]$b.Append((([string]$t) -replace '\s',''))
        }
        [IO.File]::WriteAllBytes($ZipPath, [Convert]::FromBase64String($b.ToString()))
    }
    elseif (-not [string]::IsNullOrWhiteSpace([string]$m.downloadUrl)) {
        Invoke-WebRequest -Uri ([string]$m.downloadUrl) -Headers $headers -OutFile $ZipPath -UseBasicParsing
    }
    else { throw 'No update package source.' }

    if (-not [string]::IsNullOrWhiteSpace([string]$m.sha256)) {
        if ((Hash256 $ZipPath) -ne ([string]$m.sha256).ToLowerInvariant()) { throw 'Package SHA-256 mismatch.' }
    }

    if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
        Expand-Archive -Path $ZipPath -DestinationPath $StageDir -Force
    }
    else {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $StageDir)
    }
    Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue

    if (-not [string]::IsNullOrWhiteSpace([string]$m.patchUrl)) {
        $patch = Join-Path $TempRoot 'patch.ps1'
        Invoke-WebRequest -Uri ([string]$m.patchUrl) -Headers $headers -OutFile $patch -UseBasicParsing
        if (-not [string]::IsNullOrWhiteSpace([string]$m.patchSha256)) {
            if ((Hash256 $patch) -ne ([string]$m.patchSha256).ToLowerInvariant()) { throw 'Patch SHA-256 mismatch.' }
        }
        $pa = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -StageDir "{1}"' -f $patch, $StageDir
        $pp = Start-Process powershell.exe -ArgumentList $pa -WindowStyle Hidden -Wait -PassThru
        if ($pp.ExitCode -ne 0) { throw "Patch failed: $($pp.ExitCode)" }
    }

    $wait = ''
    if ($WaitForProcessId -gt 0) {
        $wait = @"
:WAIT
tasklist /FI "PID eq $WaitForProcessId" /NH | find "$WaitForProcessId" >nul
if not errorlevel 1 (
 ping 127.0.0.1 -n 2 >nul
 goto WAIT
)
"@
    }

    $restart = ''
    if (-not $NoRestart) { $restart = 'start "" "' + (Join-Path $InstallDir 'SENETECH-Setup.exe') + '"' }

    $cleanupText = @"
@echo off
ping 127.0.0.1 -n 5 >nul
rd /s /q "$TempRoot" 2>nul
del /f /q "%~f0" >nul 2>&1
"@
    Set-Content -Path $Cleanup -Value $cleanupText -Encoding ASCII

    $apply = Join-Path $TempRoot 'apply.cmd'
    $applyText = @"
@echo off
setlocal
$wait
ping 127.0.0.1 -n 2 >nul
xcopy "$StageDir\*" "$InstallDir\" /E /I /Y /Q >nul
$restart
start "" /b "$Cleanup"
exit /b 0
"@
    Set-Content -Path $apply -Value $applyText -Encoding ASCII
    Start-Process $apply -WindowStyle Hidden
    exit 10
}
catch {
    Log ('ERROR: ' + $_.Exception.Message)
    try { if (Test-Path $TempRoot) { Remove-Item $TempRoot -Recurse -Force -ErrorAction SilentlyContinue } } catch {}
    exit 1
}
