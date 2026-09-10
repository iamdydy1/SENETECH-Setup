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
$ApplyScript = Join-Path $env:TEMP 'SENETECH-ApplyUpdate.ps1'
$TempLogPath = Join-Path $env:TEMP 'SENETECH-Update.log'
$PersistentLogDir = Join-Path $env:ProgramData 'SENETECH\Logs'
$PersistentLogPath = Join-Path $PersistentLogDir 'SENETECH-Updater.log'
$StartupMarkerPath = Join-Path $env:ProgramData 'SENETECH\startup.ok'

function Initialize-UpdateLog {
    try { New-Item -ItemType Directory -Path $PersistentLogDir -Force | Out-Null } catch { }
}

function Write-UpdateLog([string]$Text) {
    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $UpdateChannel.ToUpperInvariant(), $Text
    foreach ($path in @($PersistentLogPath,$TempLogPath)) {
        try {
            $parent = Split-Path -Parent $path
            if ($parent) { New-Item -ItemType Directory -Path $parent -Force -ErrorAction SilentlyContinue | Out-Null }
            if (Test-Path -LiteralPath $path) {
                $info = Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
                if ($info -and $info.Length -gt 2MB) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
            }
            Add-Content -LiteralPath $path -Value $line -Encoding UTF8
        } catch { }
    }
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
    foreach ($name in @('SENETECH-Setup.exe','VERSION.txt','LISEZ-MOI.txt','CHANGELOG.txt','UPDATE-SENETECH.ps1','UPDATE-SENETECH-CHANNEL.ps1')) {
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

function Quote-PsLiteral([string]$Value) {
    if ($null -eq $Value) { return "''" }
    return "'" + $Value.Replace("'","''") + "'"
}

Initialize-UpdateLog
Write-UpdateLog "Updater start. Current=$CurrentVersion InstallDir=$InstallDir PID=$WaitForProcessId"

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
    Remove-Item $ApplyScript -Force -ErrorAction SilentlyContinue
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

    if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
        Expand-Archive -Path $ZipPath -DestinationPath $StageDir -Force
    } else {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $StageDir)
    }
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
    if ($manifest.PSObject.Properties.Name -contains 'requiredFiles' -and $manifest.requiredFiles) {
        $required += @($manifest.requiredFiles | ForEach-Object { [string]$_ })
    }
    foreach ($relative in ($required | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath (Join-Path $StageDir $relative))) {
            throw "Incomplete SENETECH package: missing $relative"
        }
    }
    Write-UpdateLog 'Staged package validation OK.'

    if (Test-Path -LiteralPath $InstallDir) {
        Copy-SenetechRuntime -Source $InstallDir -Destination $BackupDir
        if (-not (Test-Path -LiteralPath (Join-Path $BackupDir 'SENETECH-Setup.exe'))) {
            throw 'Backup validation failed: SENETECH-Setup.exe missing.'
        }
        Write-UpdateLog "Current runtime backed up from $InstallDir"
    }

    $startupVerification = $false
    if ($manifest.PSObject.Properties.Name -contains 'startupVerification') {
        $startupVerification = [bool]$manifest.startupVerification
    }

    $qInstall = Quote-PsLiteral $InstallDir
    $qStage = Quote-PsLiteral $StageDir
    $qBackup = Quote-PsLiteral $BackupDir
    $qPersistent = Quote-PsLiteral $PersistentLogPath
    $qTempLog = Quote-PsLiteral $TempLogPath
    $qMarker = Quote-PsLiteral $StartupMarkerPath
    $qRemote = Quote-PsLiteral ([string]$manifest.version)
    $qCurrent = Quote-PsLiteral $CurrentVersion
    $qChannel = Quote-PsLiteral $UpdateChannel
    $qTempRoot = Quote-PsLiteral $TempRoot
    $pidValue = [int]$WaitForProcessId
    $noRestartValue = if ($NoRestart) { '$true' } else { '$false' }
    $verifyValue = if ($startupVerification) { '$true' } else { '$false' }

    $applyText = @"
`$ErrorActionPreference = 'Stop'
`$InstallDir = $qInstall
`$StageDir = $qStage
`$BackupDir = $qBackup
`$PersistentLogPath = $qPersistent
`$TempLogPath = $qTempLog
`$StartupMarkerPath = $qMarker
`$RemoteVersion = $qRemote
`$CurrentVersion = $qCurrent
`$Channel = $qChannel
`$TempRoot = $qTempRoot
`$WaitForProcessId = $pidValue
`$NoRestart = $noRestartValue
`$StartupVerification = $verifyValue

function Log([string]`$Text) {
    `$line = '[{0}] [{1}] APPLY {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), `$Channel.ToUpperInvariant(), `$Text
    foreach (`$path in @(`$PersistentLogPath,`$TempLogPath)) {
        try {
            `$parent = Split-Path -Parent `$path
            if (`$parent) { New-Item -ItemType Directory -Path `$parent -Force -ErrorAction SilentlyContinue | Out-Null }
            Add-Content -LiteralPath `$path -Value `$line -Encoding UTF8
        } catch { }
    }
}

function Copy-Tree([string]`$Source,[string]`$Destination) {
    if (-not (Test-Path -LiteralPath `$Source)) { throw "Source missing: `$Source" }
    New-Item -ItemType Directory -Path `$Destination -Force | Out-Null
    if (Get-Command robocopy.exe -ErrorAction SilentlyContinue) {
        & robocopy.exe `$Source `$Destination /E /R:2 /W:1 /COPY:DAT /DCOPY:DAT /NFL /NDL /NJH /NJS /NP | Out-Null
        `$code = `$LASTEXITCODE
        if (`$code -gt 7) { throw "Robocopy failed with code `$code" }
    } else {
        Copy-Item -Path (Join-Path `$Source '*') -Destination `$Destination -Recurse -Force -ErrorAction Stop
    }
}

function Restart-Runtime([string]`$Directory) {
    `$exe = Join-Path `$Directory 'SENETECH-Setup.exe'
    if (-not (Test-Path -LiteralPath `$exe)) { throw "Executable missing: `$exe" }
    return Start-Process -FilePath `$exe -WorkingDirectory `$Directory -PassThru
}

function Restore-PreviousRuntime {
    Log 'Rollback started.'
    if (-not (Test-Path -LiteralPath (Join-Path `$BackupDir 'SENETECH-Setup.exe'))) {
        throw 'Rollback backup is incomplete.'
    }
    Copy-Tree `$BackupDir `$InstallDir
    Log 'Rollback copy completed.'
    if (-not `$NoRestart) {
        try {
            `$old = Restart-Runtime `$InstallDir
            Log ("Previous runtime relaunched. PID=" + `$old.Id)
        } catch {
            Log ("Previous runtime relaunch failed: " + `$_.Exception.Message)
        }
    }
}

try {
    Log ("Apply start. Current=" + `$CurrentVersion + " Remote=" + `$RemoteVersion + " PID=" + `$WaitForProcessId)

    if (`$WaitForProcessId -gt 0) {
        `$deadline = (Get-Date).AddSeconds(15)
        while (Get-Process -Id `$WaitForProcessId -ErrorAction SilentlyContinue) {
            if ((Get-Date) -ge `$deadline) {
                Log ("Host PID still alive after timeout; forcing stop: " + `$WaitForProcessId)
                Stop-Process -Id `$WaitForProcessId -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
                break
            }
            Start-Sleep -Milliseconds 500
        }
        if (Get-Process -Id `$WaitForProcessId -ErrorAction SilentlyContinue) {
            throw "Unable to stop previous SENETECH process PID `$WaitForProcessId"
        }
        Log 'Previous SENETECH process is stopped.'
    }

    `$rollbackDir = Join-Path `$InstallDir '_SENETECH\Rollback\previous'
    if (Test-Path -LiteralPath `$BackupDir) {
        if (Test-Path -LiteralPath `$rollbackDir) { Remove-Item -LiteralPath `$rollbackDir -Recurse -Force -ErrorAction SilentlyContinue }
        Copy-Tree `$BackupDir `$rollbackDir
        `$meta = @{ fromVersion=`$CurrentVersion; replacedBy=`$RemoteVersion; date=(Get-Date).ToString('o') } | ConvertTo-Json -Compress
        Set-Content -LiteralPath (Join-Path `$rollbackDir 'rollback.json') -Value `$meta -Encoding UTF8
        Log 'Rollback snapshot stored.'
    }

    Copy-Tree `$StageDir `$InstallDir
    Log 'New runtime copied.'

    foreach (`$required in @('SENETECH-Setup.exe','_SENETECH\SENETECH-Setup.ps1','_SENETECH\SENETECH-Setup.manifest')) {
        if (-not (Test-Path -LiteralPath (Join-Path `$InstallDir `$required))) {
            throw "Post-copy validation failed: missing `$required"
        }
    }

    `$versionFile = Join-Path `$InstallDir 'VERSION.txt'
    if (Test-Path -LiteralPath `$versionFile) {
        `$versionText = Get-Content -LiteralPath `$versionFile -Raw -ErrorAction SilentlyContinue
        if (`$versionText -and -not `$versionText.Contains(`$RemoteVersion)) {
            throw "Post-copy version validation failed: expected `$RemoteVersion"
        }
    }
    Log 'Post-copy validation OK.'

    if (-not `$NoRestart) {
        Remove-Item -LiteralPath `$StartupMarkerPath -Force -ErrorAction SilentlyContinue
        `$newProcess = Restart-Runtime `$InstallDir
        Log ("Restart requested. PID=" + `$newProcess.Id)

        if (`$StartupVerification) {
            `$startDeadline = (Get-Date).AddSeconds(20)
            `$verified = `$false
            while ((Get-Date) -lt `$startDeadline) {
                if (Test-Path -LiteralPath `$StartupMarkerPath) {
                    try {
                        `$marker = Get-Content -LiteralPath `$StartupMarkerPath -Raw -ErrorAction Stop
                        if (`$marker -and `$marker.Contains("version=`$RemoteVersion")) {
                            `$verified = `$true
                            break
                        }
                    } catch { }
                }
                if (`$newProcess.HasExited -and `$newProcess.ExitCode -ne 0) { break }
                Start-Sleep -Milliseconds 500
            }
            if (-not `$verified) {
                throw "Startup verification failed for SENETECH `$RemoteVersion"
            }
            Log 'Startup verification marker OK.'
        } else {
            Start-Sleep -Seconds 3
            if (`$newProcess.HasExited -and `$newProcess.ExitCode -ne 0) {
                throw "SENETECH exited immediately with code `$(`$newProcess.ExitCode)"
            }
            Log 'Restart command completed.'
        }
    }

    Log 'UPDATE SUCCESS.'
    Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c',('ping 127.0.0.1 -n 4 >nul & rd /s /q "' + `$TempRoot + '" 2>nul & del /f /q "' + `$MyInvocation.MyCommand.Path + '" >nul 2>&1')) -WindowStyle Hidden
    exit 0
}
catch {
    Log ('UPDATE APPLY ERROR: ' + `$_.Exception.Message)
    try {
        Restore-PreviousRuntime
        Log 'ROLLBACK SUCCESS.'
    } catch {
        Log ('ROLLBACK ERROR: ' + `$_.Exception.Message)
    }
    try {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            "La mise a jour SENETECH a echoue et a ete annulee.`r`n`r`nL ancienne version a ete restauree si possible.`r`n`r`nJournal :`r`n`$PersistentLogPath",
            'SENETECH - Mise a jour',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    } catch { }
    exit 1
}
"@

    Set-Content -LiteralPath $ApplyScript -Value $applyText -Encoding UTF8
    Write-UpdateLog 'Package ready. Starting guarded apply process.'
    Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$ApplyScript+'"')) -WindowStyle Hidden
    exit 10
}
catch {
    Write-UpdateLog ('PREPARE ERROR: ' + $_.Exception.Message)
    try {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            "Impossible de preparer la mise a jour SENETECH.`r`n`r`n$($_.Exception.Message)`r`n`r`nJournal :`r`n$PersistentLogPath",
            'SENETECH - Mise a jour',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    } catch { }
    try { Remove-Item $TempRoot -Recurse -Force -ErrorAction SilentlyContinue } catch { }
    exit 1
}
