# SENETECH V1.6 - release safety overrides for rollback and sale handoff
# ASCII-only source for Windows PowerShell 5.1 compatibility.

function Test-SenetechProtectedProgram($Program) {
    $name = [string]$Program.Name
    $publisher = [string]$Program.Publisher

    # Never uninstall the running technician runtime during sale cleanup.
    # It is removed later by the SYSTEM cleanup task after OOBE is committed.
    if ($name -eq 'SENETECH Setup' -or $publisher -eq 'SENETECH') { return $true }

    if ($Program.SystemComponent -eq 1 -or $Program.NoRemove -eq 1) { return $true }
    if ($name -match '^(Security Update|Update for|Hotfix|KB\d+)') { return $true }

    $windowsPatterns = @(
        '^Microsoft Edge$', '^Microsoft Edge WebView2 Runtime$', '^Microsoft OneDrive$',
        '^Microsoft Update Health Tools$', '^Windows ', '^Microsoft Windows ',
        '^Microsoft Visual C\+\+', '^Microsoft\.NET', '^Microsoft .NET',
        '^Microsoft Windows Desktop Runtime', '^Microsoft ASP\.NET Core',
        '^Microsoft DirectX', '^WebView2 Runtime'
    )
    foreach ($pattern in $windowsPatterns) { if ($name -match $pattern) { return $true } }

    $hardwarePublisher = $publisher -match '(?i)Intel|Advanced Micro Devices|AMD|NVIDIA|Realtek|Synaptics|ELAN|Qualcomm|Broadcom|MediaTek|Marvell|Cirrus|Dolby|DTS|SteelSeries ApS'
    $driverName = $name -match '(?i)driver|chipset|firmware|bluetooth|wireless|wi-fi|ethernet|network|audio|display|graphics|serial io|management engine|touchpad|hotkey|thunderbolt|usb|physx'
    if ($hardwarePublisher -and $driverName) { return $true }
    return $false
}

function Copy-SenetechRuntimeSafetyBackup([string]$Source,[string]$Destination) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    foreach ($name in @('SENETECH-Setup.exe','VERSION.txt','LISEZ-MOI.txt','CHANGELOG.txt')) {
        $src = Join-Path $Source $name
        if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $Destination $name) -Force }
    }
    $engineSrc = Join-Path $Source '_SENETECH'
    if (Test-Path -LiteralPath $engineSrc) {
        $engineDst = Join-Path $Destination '_SENETECH'
        New-Item -ItemType Directory -Path $engineDst -Force | Out-Null
        Get-ChildItem -LiteralPath $engineSrc -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne 'Rollback' } |
            Copy-Item -Destination $engineDst -Recurse -Force
    }
}

function Test-SenetechRuntimeBackup([string]$Root) {
    if ([string]::IsNullOrWhiteSpace($Root) -or -not (Test-Path -LiteralPath $Root)) { return $false }
    foreach ($relative in @('SENETECH-Setup.exe','_SENETECH\SENETECH-Setup.ps1','_SENETECH\SENETECH-Setup.manifest')) {
        $path = Join-Path $Root $relative
        if (-not (Test-Path -LiteralPath $path) -or (Get-Item -LiteralPath $path).Length -le 0) { return $false }
    }
    return $true
}

function Start-SenetechRollback {
    if (-not (Test-SenetechRuntimeBackup $script:RollbackRoot)) {
        [System.Windows.MessageBox]::Show((Get-SenetechValidationText 'La sauvegarde de la version pr{eacute}c{eacute}dente est absente ou incompl{egrave}te. Le rollback est bloqu{eacute} pour {eacute}viter d''endommager SENETECH.'), 'SENETECH - Rollback', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
        Write-Log (Get-SenetechValidationText 'Rollback refus{eacute} : sauvegarde pr{eacute}c{eacute}dente incompl{egrave}te.') 'ERREUR'
        return
    }

    $answer = [System.Windows.MessageBox]::Show((Get-SenetechValidationText 'Restaurer la version SENETECH pr{eacute}c{eacute}dente ? Une copie de la version actuelle sera cr{eacute}{eacute}e avant la restauration.'), 'SENETECH - Rollback', [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
    if ($answer -ne [System.Windows.MessageBoxResult]::Yes) { return }

    $safety = Join-Path $script:EngineDir ('Rollback\before-rollback-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    try {
        Copy-SenetechRuntimeSafetyBackup $script:Root $safety
        if (-not (Test-SenetechRuntimeBackup $safety)) { throw 'Sauvegarde de securite du runtime actuel incomplete.' }
    } catch {
        Write-Log (Get-SenetechValidationText ('Rollback annul{eacute} : impossible de sauvegarder la version actuelle : {0}' -f $_.Exception.Message)) 'ERREUR'
        [System.Windows.MessageBox]::Show($_.Exception.Message,'SENETECH - Rollback',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
        return
    }

    $cmdPath = Join-Path $env:TEMP 'SENETECH-Rollback-Safe.cmd'
    $root = $script:Root
    $backup = $script:RollbackRoot
    $exe = Join-Path $root 'SENETECH-Setup.exe'
    $engine = Join-Path $root '_SENETECH\SENETECH-Setup.ps1'
    $manifest = Join-Path $root '_SENETECH\SENETECH-Setup.manifest'
    $log = Join-Path $env:TEMP 'SENETECH-Rollback.log'

    $cmd = @"
@echo off
setlocal
:WAIT
tasklist /FI "PID eq $PID" /NH | find "$PID" >nul
if not errorlevel 1 (ping 127.0.0.1 -n 2 >nul & goto WAIT)
echo [%date% %time%] Rollback start>"$log"
xcopy "$backup\*" "$root\" /E /I /Y /Q >>"$log" 2>&1
if errorlevel 1 goto RESTORE_CURRENT
if not exist "$exe" goto RESTORE_CURRENT
if not exist "$engine" goto RESTORE_CURRENT
if not exist "$manifest" goto RESTORE_CURRENT
echo [%date% %time%] Rollback verified>>"$log"
start "" /D "$root" "$exe"
del /f /q "%~f0" >nul 2>&1
exit /b 0
:RESTORE_CURRENT
echo [%date% %time%] Rollback failed - restoring current runtime>>"$log"
xcopy "$safety\*" "$root\" /E /I /Y /Q >>"$log" 2>&1
if exist "$exe" start "" /D "$root" "$exe"
del /f /q "%~f0" >nul 2>&1
exit /b 1
"@
    Set-Content -LiteralPath $cmdPath -Value $cmd -Encoding ASCII
    Add-SenetechHistory 'Rollback SENETECH' 'INFO' ('backup=' + $script:RollbackRoot + ' safety=' + $safety)
    Write-Log (Get-SenetechValidationText 'Rollback pr{eacute}par{eacute} : sauvegarde actuelle v{eacute}rifi{eacute}e, restauration apr{egrave}s fermeture.') 'OK'
    Start-Process -FilePath $cmdPath -WindowStyle Hidden
    try { $script:NetworkTimer.Stop() } catch { }
    $window.Close()
}

function Get-SenetechConfiguredAppsForClient {
    $items = @()
    foreach ($app in $script:appMap.Values) {
        try {
            $candidate = [pscustomobject]$app
            $state = Get-SenetechAppInstalledState $candidate
            if ($state.Installed) {
                $items += [pscustomobject]@{
                    id = [string]$candidate.Id
                    name = [string]$candidate.Name
                    registry = [string]$candidate.Registry
                }
            }
        } catch { }
    }
    return @($items | Sort-Object id -Unique)
}

function Save-SenetechConfiguredAppsForWelcome {
    New-Item -ItemType Directory -Path $script:WelcomeRoot -Force | Out-Null
    $items = @(Get-SenetechConfiguredAppsForClient)
    $data = [ordered]@{
        schemaVersion = 1
        createdAt = (Get-Date).ToString('o')
        mode = 'configured-client'
        apps = $items
    }
    $path = Join-Path $script:WelcomeRoot 'configured-apps.json'
    $data | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $path -Encoding UTF8
    Write-Log (Get-SenetechValidationText ('Configuration client enregistr{eacute}e : {0} application(s) {agrave} rev{eacute}rifier au premier profil.' -f $items.Count)) 'OK'
    return $path
}

function Invoke-SenetechTechnicianTraceCleanup {
    try { [void](Invoke-SenetechCleanup) } catch { }
    $recent = Join-Path $env:APPDATA 'Microsoft\Windows\Recent'
    if (Test-Path -LiteralPath $recent) {
        Get-ChildItem -LiteralPath $recent -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    try { Clear-History -ErrorAction SilentlyContinue } catch { }
    foreach ($path in @((Join-Path $env:TEMP 'SENETECH-*'),(Join-Path $env:LOCALAPPDATA 'Temp\SENETECH-*'))) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Preparation backups are technician-only data and must not remain on a sold PC.
    foreach ($path in @($script:SenetechBackupRoot,$script:SenetechValidationRoot)) {
        if ($path -and (Test-Path -LiteralPath $path)) { Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue }
    }

    Write-Log (Get-SenetechValidationText 'Traces de la session technicien nettoy{eacute}es. Le profil complet sera retir{eacute} au prochain d{eacute}marrage.') 'OK'
    Add-SenetechHistory 'Nettoyage traces technicien' 'OK'
}

function New-SenetechCleanupAfterOobeScript($Context) {
    New-Item -ItemType Directory -Path $script:DeliveryRoot -Force | Out-Null
    $scriptPath = Join-Path $script:DeliveryRoot 'Cleanup-After-OOBE.ps1'
    $logPath = Join-Path $script:DeliveryRoot 'Cleanup-After-OOBE.log'
    $commitPath = Join-Path $script:DeliveryRoot 'COMMIT-OOBE.flag'
    $sid = [string]$Context.Sid
    $user = [string]$Context.UserName
    $builtin = if ($Context.IsBuiltinAdministrator) { '$true' } else { '$false' }
    $installedRoot = Join-Path $env:ProgramFiles 'SENETECH'
    $startMenu = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\SENETECH Setup.lnk'
    $desktop = Join-Path $env:Public 'Desktop\SENETECH Setup.lnk'

    $content = @"
`$ErrorActionPreference = 'SilentlyContinue'
`$log = '$($logPath.Replace("'","''"))'
function Log([string]`$m) { Add-Content -LiteralPath `$log -Encoding UTF8 -Value (('[{0}] {1}' -f (Get-Date -Format 's'),`$m)) }
if (-not (Test-Path -LiteralPath '$($commitPath.Replace("'","''"))')) { Log 'No OOBE commit marker. Cleanup skipped.'; exit 0 }
Start-Sleep -Seconds 12
`$sid = '$sid'
`$isBuiltin = $builtin
try {
    `$profile = Get-CimInstance Win32_UserProfile -Filter ("SID='{0}'" -f `$sid) | Select-Object -First 1
    if (`$profile -and -not `$profile.Loaded) { Remove-CimInstance -InputObject `$profile; Log ('Profile removed: ' + `$sid) }
} catch { Log ('Profile cleanup error: ' + `$_.Exception.Message) }
if (-not `$isBuiltin) {
    try {
        `$local = Get-LocalUser -ErrorAction SilentlyContinue | Where-Object { `$_.SID.Value -eq `$sid } | Select-Object -First 1
        if (`$local) { Remove-LocalUser -Name `$local.Name -ErrorAction Stop; Log ('Local account removed: ' + `$local.Name) }
    } catch { Log ('Account cleanup error: ' + `$_.Exception.Message) }
}
try { Remove-Item -LiteralPath '$($startMenu.Replace("'","''"))' -Force -ErrorAction SilentlyContinue } catch { }
try { Remove-Item -LiteralPath '$($desktop.Replace("'","''"))' -Force -ErrorAction SilentlyContinue } catch { }
try { Remove-Item -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\SENETECH Setup' -Recurse -Force -ErrorAction SilentlyContinue } catch { }
try {
    if (Test-Path -LiteralPath '$($installedRoot.Replace("'","''"))') {
        Remove-Item -LiteralPath '$($installedRoot.Replace("'","''"))' -Recurse -Force -ErrorAction SilentlyContinue
        Log 'Installed SENETECH technician runtime removed.'
    }
} catch { Log ('SENETECH runtime cleanup error: ' + `$_.Exception.Message) }
Remove-Item -LiteralPath '$($commitPath.Replace("'","''"))' -Force -ErrorAction SilentlyContinue
try { Unregister-ScheduledTask -TaskName '$script:DeliveryCleanupTask' -Confirm:`$false -ErrorAction SilentlyContinue } catch { }
Log 'SENETECH delivery cleanup completed.'
"@
    [IO.File]::WriteAllText($scriptPath,$content,(New-Object Text.UTF8Encoding($true)))
    return $scriptPath
}

function Start-SenetechDeliveryFinalization([string]$Mode,[bool]$EnableWelcome) {
    if (-not (Test-SenetechDeliveryAdmin)) { throw 'SENETECH doit etre execute en administrateur.' }
    $context = Get-SenetechTechnicianContext
    $modeLabel = if ($Mode -eq 'clean') { 'PC propre / vierge' } else { 'Configuration client conservee' }
    Add-SenetechHistory 'Finalisation vente demandee' 'INFO' $modeLabel

    # Configured-client mode needs Welcome to reconcile applications that were
    # installed only in the technician profile.
    if ($Mode -eq 'configured' -and -not $EnableWelcome) {
        $EnableWelcome = $true
        Write-Log (Get-SenetechValidationText 'SENETECH Welcome activ{eacute} automatiquement en mode PC configur{eacute}, afin de rev{eacute}rifier les applications sur le profil client.') 'INFO'
    }

    if ($Mode -eq 'clean') {
        Set-Progress 15 (Get-SenetechValidationText 'Nettoyage des applications tierces')
        $result = Invoke-SenetechThirdPartyCleanup
        if ($result.Failed.Count -gt 0) {
            $failedText = ($result.Failed | Select-Object -First 12) -join "`n - "
            throw (Get-SenetechValidationText ("Certaines applications n''ont pas pu {ecirc}tre supprim{eacute}es automatiquement :`n - " + $failedText + "`n`nLa finalisation est arr{ecirc}t{eacute}e pour {eacute}viter de livrer un PC incomplet."))
        }
        $remaining = @(Get-SenetechInstalledPrograms | Where-Object { -not (Test-SenetechProtectedProgram $_) })
        if ($remaining.Count -gt 0) {
            throw (Get-SenetechValidationText ("Il reste $($remaining.Count) application(s) tierce(s) d{eacute}tect{eacute}e(s). Relancez l''aper{cced}u avant de finaliser."))
        }
    }

    # Prepare client reconciliation files before technician traces are removed.
    if ($EnableWelcome) {
        Install-SenetechWelcomeForNewOwner
        if ($Mode -eq 'configured') { [void](Save-SenetechConfiguredAppsForWelcome) }
    }

    Set-Progress 75 (Get-SenetechValidationText 'Nettoyage des traces technicien')
    Invoke-SenetechTechnicianTraceCleanup
    Register-SenetechCleanupAfterOobe $context
    try {
        Invoke-SenetechOobeSeal
    } catch {
        Unregister-SenetechDeliveryCleanup
        if ($EnableWelcome) { Remove-SenetechWelcomeRegistration }
        throw
    }
}
