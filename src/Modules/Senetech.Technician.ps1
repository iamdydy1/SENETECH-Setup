# SENETECH V1.6 - technician tools, diagnostics, rollback and maintenance

function New-SenetechRestorePoint([string]$Reason = 'Avant preparation SENETECH') {
    try {
        $systemDrive = $env:SystemDrive + '\\'
        Enable-ComputerRestore -Drive $systemDrive -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description $Reason -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Log 'Point de restauration Windows cree.' 'OK'
        Add-SenetechHistory 'Point de restauration' 'OK' $Reason
        return $true
    } catch {
        Write-Log ("Point de restauration non cree : {0}" -f $_.Exception.Message) 'ATTENTION'
        Add-SenetechHistory 'Point de restauration' 'ATTENTION' $_.Exception.Message
        return $false
    }
}

function Get-RegistryValueSnapshot([string]$Path, [string]$Name) {
    $exists = Test-Path -LiteralPath $Path
    $hasValue = $false
    $value = $null
    if ($exists) {
        try {
            $obj = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop
            $value = $obj.$Name
            $hasValue = $true
        } catch { }
    }
    return [ordered]@{ path=$Path; name=$Name; existed=$exists; hadValue=$hasValue; value=$value }
}

function Save-SenetechTweakSnapshot {
    if (Test-Path -LiteralPath $script:TweakSnapshotFile) { return }
    $targets = @(
        @{Path='HKCU:\Software\Microsoft\GameBar';Name='AllowAutoGameMode'},
        @{Path='HKCU:\Software\Microsoft\GameBar';Name='AutoGameModeEnabled'},
        @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize';Name='EnableTransparency'},
        @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects';Name='VisualFXSetting'}
    )
    $snapshot = [ordered]@{ createdAt=(Get-Date).ToString('o'); values=@() }
    foreach ($t in $targets) { $snapshot.values += Get-RegistryValueSnapshot $t.Path $t.Name }
    $snapshot | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $script:TweakSnapshotFile -Encoding UTF8
}

function Set-SenetechRegDword([string]$Path, [string]$Name, [int]$Value) {
    New-Item -Path $Path -Force | Out-Null
    New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
}

function Apply-SenetechProfileOptimizations([string]$ProfileName) {
    $def = Get-SenetechProfileDefinition $ProfileName
    if ($null -eq $def) { return }
    $applyProp = $def.PSObject.Properties['applyTweaks']
    if ($null -eq $applyProp -or -not [bool]$applyProp.Value) { return }
    Save-SenetechTweakSnapshot
    $presetProp = $def.PSObject.Properties['tweakPreset']
    $preset = if ($null -ne $presetProp) { [string]$presetProp.Value } else { '' }
    switch ($preset) {
        'gaming' {
            Set-SenetechRegDword 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1
            Set-SenetechRegDword 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
            Write-Log 'Optimisations Gaming appliquees : Game Mode active.' 'OK'
        }
        'light' {
            Set-SenetechRegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0
            Set-SenetechRegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 2
            Write-Log 'Optimisations PC leger appliquees : effets visuels reduits.' 'OK'
        }
    }
    Add-SenetechHistory 'Optimisations profil' 'OK' $ProfileName
}

function Undo-SenetechProfileOptimizations {
    if (-not (Test-Path -LiteralPath $script:TweakSnapshotFile)) {
        [System.Windows.MessageBox]::Show('Aucune sauvegarde d optimisations SENETECH n est disponible.', 'SENETECH Setup') | Out-Null
        return
    }
    try {
        $snapshot = Get-Content -LiteralPath $script:TweakSnapshotFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($item in @($snapshot.values)) {
            $path = [string]$item.path
            $name = [string]$item.name
            if ([bool]$item.hadValue) {
                New-Item -Path $path -Force | Out-Null
                Set-ItemProperty -LiteralPath $path -Name $name -Value $item.value -Force
            } else {
                Remove-ItemProperty -LiteralPath $path -Name $name -ErrorAction SilentlyContinue
            }
        }
        Remove-Item -LiteralPath $script:TweakSnapshotFile -Force
        Write-Log 'Optimisations SENETECH annulees.' 'OK'
        Add-SenetechHistory 'Annulation optimisations' 'OK'
        [System.Windows.MessageBox]::Show('Les optimisations SENETECH ont ete annulees.', 'SENETECH Setup') | Out-Null
    } catch {
        Write-Log ("Impossible d annuler les optimisations : {0}" -f $_.Exception.Message) 'ERREUR'
    }
}

function Invoke-SenetechAppUpdates {
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) { throw 'WinGet est introuvable.' }
    if (-not (Test-Internet)) { throw 'Connexion Internet requise.' }
    $installed = @()
    foreach ($app in $script:appMap.Values) {
        $version = Get-InstalledAppVersion $app.Registry
        if ($version -ne '-') { $installed += [pscustomobject]$app }
    }
    if ($installed.Count -eq 0) { Write-Log 'Aucune application du catalogue detectee pour mise a jour.'; return @() }
    $results = @()
    $locale = Get-PreferredLocale
    $index = 0
    foreach ($app in $installed) {
        $index++
        Set-Progress ([Math]::Min(90, 10 + [int](80*$index/$installed.Count))) ("Mise a jour : {0}" -f $app.Name)
        $args = @('upgrade','--id',$app.Id,'--exact','--silent','--accept-package-agreements','--accept-source-agreements','--disable-interactivity','--locale',$locale)
        $code = Invoke-ProcessVisible -FilePath $winget.Source -Arguments $args
        $version = Get-InstalledAppVersion $app.Registry
        $status = if ($code -eq 0) { 'OK' } else { 'A JOUR / NON APPLICABLE' }
        $results += [pscustomobject]@{ Name=$app.Name; Id=$app.Id; Status=$status; Version=$version; ExitCode=$code; Source='WinGet upgrade'; Locale=$locale }
        Write-Log ("{0} : {1} (code {2})" -f $app.Name, $status, $code) $(if($code -eq 0){'OK'}else{'INFO'})
    }
    Add-SenetechHistory 'Mise a jour applications' 'OK' ("{0} application(s) controlee(s)" -f $installed.Count)
    return @($results)
}

function Get-DirectorySizeSafe([string]$Path) {
    try { return [int64]((Get-ChildItem -LiteralPath $Path -File -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum) } catch { return 0 }
}

function Invoke-SenetechCleanup {
    $targets = @($env:TEMP, (Join-Path $env:SystemRoot 'Temp')) | Select-Object -Unique
    [int64]$before = 0
    foreach ($target in $targets) { if (Test-Path -LiteralPath $target) { $before += Get-DirectorySizeSafe $target } }
    foreach ($target in $targets) {
        if (Test-Path -LiteralPath $target) {
            Get-ChildItem -LiteralPath $target -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue } catch { }
    [int64]$after = 0
    foreach ($target in $targets) { if (Test-Path -LiteralPath $target) { $after += Get-DirectorySizeSafe $target } }
    $freed = [Math]::Max(0, $before - $after)
    $freedMb = [Math]::Round($freed / 1MB, 0)
    Write-Log ("Nettoyage termine : environ {0} Mo liberes." -f $freedMb) 'OK'
    Add-SenetechHistory 'Nettoyage Windows' 'OK' ("$freedMb Mo")
    return $freedMb
}

function Get-SenetechStartupItems {
    $items = @()
    $locations = @(
        @{ Hive='HKCU'; Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive='HKLM'; Path='HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive='HKLM32'; Path='HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' }
    )
    foreach ($loc in $locations) {
        if (-not (Test-Path -LiteralPath $loc.Path)) { continue }
        $key = Get-ItemProperty -LiteralPath $loc.Path -ErrorAction SilentlyContinue
        foreach ($p in $key.PSObject.Properties) {
            if ($p.Name -match '^PS(Path|ParentPath|ChildName|Drive|Provider)$') { continue }
            $items += [pscustomobject]@{ Type='Registry'; Source=$loc.Hive; Path=$loc.Path; Name=$p.Name; Command=[string]$p.Value }
        }
    }
    $startupFolders = @([Environment]::GetFolderPath('Startup'),[Environment]::GetFolderPath('CommonStartup')) | Select-Object -Unique
    foreach ($folder in $startupFolders) {
        if (-not $folder -or -not (Test-Path -LiteralPath $folder)) { continue }
        foreach ($file in @(Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue)) {
            $items += [pscustomobject]@{ Type='File'; Source='Startup'; Path=$file.FullName; Name=$file.Name; Command=$file.FullName }
        }
    }
    return @($items)
}

function Read-SenetechStartupBackup {
    if (-not (Test-Path -LiteralPath $script:StartupBackupFile)) { return @() }
    try { return @(Get-Content -LiteralPath $script:StartupBackupFile -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return @() }
}
function Write-SenetechStartupBackup($Items) { @($Items) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $script:StartupBackupFile -Encoding UTF8 }
function Disable-SenetechStartupItem($Item) {
    $backup = @(Read-SenetechStartupBackup)
    if ($Item.Type -eq 'Registry') {
        $backup += [pscustomobject]@{ Type='Registry'; Path=$Item.Path; Name=$Item.Name; Command=$Item.Command }
        Remove-ItemProperty -LiteralPath $Item.Path -Name $Item.Name -ErrorAction Stop
    } else {
        $disabledDir = Join-Path $script:Root 'SENETECH-Startup-Disabled'
        New-Item -ItemType Directory -Force -Path $disabledDir | Out-Null
        $dest = Join-Path $disabledDir ([IO.Path]::GetFileName($Item.Path))
        $backup += [pscustomobject]@{ Type='File'; Path=$Item.Path; Name=$Item.Name; Command=$dest }
        Move-Item -LiteralPath $Item.Path -Destination $dest -Force
    }
    Write-SenetechStartupBackup $backup
    Add-SenetechHistory 'Demarrage desactive' 'OK' $Item.Name
}
function Restore-SenetechStartupItems {
    $backup = @(Read-SenetechStartupBackup)
    foreach ($item in $backup) {
        try {
            if ([string]$item.Type -eq 'Registry') {
                New-Item -Path ([string]$item.Path) -Force | Out-Null
                Set-ItemProperty -LiteralPath ([string]$item.Path) -Name ([string]$item.Name) -Value ([string]$item.Command) -Force
            } elseif (Test-Path -LiteralPath ([string]$item.Command)) {
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent ([string]$item.Path)) | Out-Null
                Move-Item -LiteralPath ([string]$item.Command) -Destination ([string]$item.Path) -Force
            }
        } catch { Write-Log ("Restauration demarrage impossible pour {0}: {1}" -f $item.Name, $_.Exception.Message) 'ATTENTION' }
    }
    Remove-Item -LiteralPath $script:StartupBackupFile -Force -ErrorAction SilentlyContinue
    Add-SenetechHistory 'Demarrage restaure' 'OK' ("{0} element(s)" -f $backup.Count)
}

function Show-SenetechStartupManager {
    $items = @(Get-SenetechStartupItems)
    $win = New-Object System.Windows.Window
    $win.Title = 'SENETECH - Demarrage Windows'; $win.Width = 760; $win.Height = 560; $win.WindowStartupLocation = 'CenterOwner'; $win.Owner = $window
    $win.Background = '#0B1320'; $win.Foreground = '#E5EEF5'
    $rootPanel = New-Object System.Windows.Controls.DockPanel
    $footer = New-Object System.Windows.Controls.StackPanel; $footer.Orientation = 'Horizontal'; $footer.HorizontalAlignment = 'Right'; $footer.Margin = '12'
    [System.Windows.Controls.DockPanel]::SetDock($footer, 'Bottom')
    $disableButton = New-Object System.Windows.Controls.Button; $disableButton.Content = 'Desactiver la selection'; $disableButton.Padding='12,7'; $disableButton.Margin='4'
    $restoreButton = New-Object System.Windows.Controls.Button; $restoreButton.Content = 'Restaurer les elements SENETECH'; $restoreButton.Padding='12,7'; $restoreButton.Margin='4'
    $closeButton = New-Object System.Windows.Controls.Button; $closeButton.Content = 'Fermer'; $closeButton.Padding='12,7'; $closeButton.Margin='4'
    [void]$footer.Children.Add($disableButton); [void]$footer.Children.Add($restoreButton); [void]$footer.Children.Add($closeButton); [void]$rootPanel.Children.Add($footer)
    $scroll = New-Object System.Windows.Controls.ScrollViewer; $scroll.VerticalScrollBarVisibility='Auto'; $scroll.Margin='12'
    $list = New-Object System.Windows.Controls.StackPanel
    foreach ($item in $items) {
        $cb = New-Object System.Windows.Controls.CheckBox; $cb.Content = ('{0}  —  {1}' -f $item.Name, $item.Source); $cb.ToolTip = $item.Command; $cb.Tag = $item; $cb.Margin='4'; $cb.Foreground='#D5DFEC'
        [void]$list.Children.Add($cb)
    }
    if ($items.Count -eq 0) { $text = New-Object System.Windows.Controls.TextBlock; $text.Text='Aucun element de demarrage classique detecte.'; $text.Margin='8'; [void]$list.Children.Add($text) }
    $scroll.Content = $list; [void]$rootPanel.Children.Add($scroll); $win.Content=$rootPanel
    $disableButton.Add_Click({
        $selected = @($list.Children | Where-Object { $_ -is [System.Windows.Controls.CheckBox] -and $_.IsChecked -eq $true })
        foreach ($cb in $selected) { try { Disable-SenetechStartupItem $cb.Tag; $cb.IsEnabled=$false; $cb.IsChecked=$false } catch { Write-Log $_.Exception.Message 'ATTENTION' } }
        if ($selected.Count -gt 0) { Write-Log ("{0} element(s) de demarrage desactive(s)." -f $selected.Count) 'OK' }
    })
    $restoreButton.Add_Click({ Restore-SenetechStartupItems; [System.Windows.MessageBox]::Show('Les elements desactives par SENETECH ont ete restaures.', 'SENETECH Setup') | Out-Null })
    $closeButton.Add_Click({ $win.Close() }); [void]$win.ShowDialog()
}

function Start-SenetechRollback {
    if (-not (Test-Path -LiteralPath $script:RollbackRoot)) { [System.Windows.MessageBox]::Show('Aucune version precedente sauvegardee par SENETECH.', 'SENETECH - Retour version') | Out-Null; return }
    $answer = [System.Windows.MessageBox]::Show('Revenir a la version SENETECH precedente sauvegardee ? SENETECH va se fermer puis redemarrer.', 'SENETECH - Retour version', [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
    if ($answer -ne [System.Windows.MessageBoxResult]::Yes) { return }
    $cmdPath = Join-Path $env:TEMP 'SENETECH-Rollback.cmd'; $root = $script:Root; $backup = $script:RollbackRoot; $exe = Join-Path $root 'SENETECH-Setup.exe'
    $cmd = @"
@echo off
:WAIT
tasklist /FI "PID eq $PID" /NH | find "$PID" >nul
if not errorlevel 1 (ping 127.0.0.1 -n 2 >nul & goto WAIT)
xcopy "$backup\*" "$root\" /E /I /Y /Q >nul
start "" "$exe"
del /f /q "%~f0" >nul 2>&1
"@
    Set-Content -LiteralPath $cmdPath -Value $cmd -Encoding ASCII; Add-SenetechHistory 'Rollback SENETECH' 'OK'; Start-Process -FilePath $cmdPath -WindowStyle Hidden
    try { $script:NetworkTimer.Stop() } catch { }; $window.Close()
}

function Get-SenetechSecuritySnapshot {
    $tpm = 'Non detecte'; try { if ((Get-Tpm -ErrorAction Stop).TpmPresent) { $tpm = 'TPM present' } } catch { }
    $secureBoot = 'Inconnu'; try { $secureBoot = if (Confirm-SecureBootUEFI -ErrorAction Stop) { 'Active' } else { 'Desactive' } } catch { }
    $freeSystem = '-'; try { $drive = Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $env:SystemDrive); if ($drive) { $freeSystem = ('{0} Go libres / {1} Go' -f [Math]::Round([double]$drive.FreeSpace/1GB,1), [Math]::Round([double]$drive.Size/1GB,1)) } } catch { }
    return [pscustomobject]@{ TPM=$tpm; SecureBoot=$secureBoot; SystemDrive=$freeSystem; StartupCount=@(Get-SenetechStartupItems).Count }
}

function Add-SenetechTechnicianUi {
    $group = New-Object System.Windows.Controls.GroupBox; $group.Header = '6. Outils technicien'; $group.Padding='12'; $group.Margin='0,12,0,0'
    $panel = New-Object System.Windows.Controls.StackPanel
    $script:CreateRestoreCheck = New-Object System.Windows.Controls.CheckBox; $script:CreateRestoreCheck.Content='Creer un point de restauration avant les modifications'; $script:CreateRestoreCheck.IsChecked=$true; $script:CreateRestoreCheck.Margin='0,4'
    $script:ApplyTweaksCheck = New-Object System.Windows.Controls.CheckBox; $script:ApplyTweaksCheck.Content='Appliquer les optimisations du profil (reversibles)'; $script:ApplyTweaksCheck.IsChecked=$true; $script:ApplyTweaksCheck.Margin='0,4'
    $script:UpdateInstalledAppsCheck = New-Object System.Windows.Controls.CheckBox; $script:UpdateInstalledAppsCheck.Content='Mettre a jour les applications du catalogue deja installees'; $script:UpdateInstalledAppsCheck.IsChecked=$true; $script:UpdateInstalledAppsCheck.Margin='0,4'
    $script:CleanupAfterCheck = New-Object System.Windows.Controls.CheckBox; $script:CleanupAfterCheck.Content='Nettoyer les fichiers temporaires en fin de preparation'; $script:CleanupAfterCheck.IsChecked=$true; $script:CleanupAfterCheck.Margin='0,4'
    $script:OptionalUpdatesCheck = New-Object System.Windows.Controls.CheckBox; $script:OptionalUpdatesCheck.Content='Inclure les mises a jour Windows facultatives / Preview'; $script:OptionalUpdatesCheck.IsChecked=$false; $script:OptionalUpdatesCheck.Margin='0,4'
    $buttons = New-Object System.Windows.Controls.WrapPanel; $buttons.Margin='0,9,0,0'
    foreach ($spec in @(@('UpdateAppsButton','Mettre a jour les applications'),@('CleanupButton','Nettoyer Windows'),@('StartupButton','Demarrage Windows'),@('RefreshCatalogButton','Actualiser le catalogue'),@('UndoTweaksButton','Annuler optimisations'),@('RollbackButton','Retour version SENETECH'))) {
        $b = New-Object System.Windows.Controls.Button; $b.Content=$spec[1]; $b.Padding='12,7'; $b.Margin='0,0,8,8'; Set-Variable -Name $spec[0] -Value $b -Scope Script; [void]$buttons.Children.Add($b)
    }
    foreach($c in @($script:CreateRestoreCheck,$script:ApplyTweaksCheck,$script:UpdateInstalledAppsCheck,$script:CleanupAfterCheck,$script:OptionalUpdatesCheck,$buttons)){ [void]$panel.Children.Add($c) }
    $hint = New-Object System.Windows.Controls.TextBlock; $hint.Text='Les actions sensibles creent une sauvegarde quand cela est possible. Aucun effacement de disque ni redemarrage automatique.'; $hint.TextWrapping='Wrap'; $hint.Foreground='#6FAFD1'; $hint.Margin='0,5,0,0'; [void]$panel.Children.Add($hint)
    $group.Content=$panel; [void]$script:LeftPanel.Children.Add($group)
    $script:UpdateAppsButton.Add_Click({ try { Set-ControlsEnabled $false; $script:AppResults += @(Invoke-SenetechAppUpdates); Set-Progress 100 'Applications controlees' } catch { Write-Log $_.Exception.Message 'ERREUR' } finally { Set-ControlsEnabled $true } })
    $script:CleanupButton.Add_Click({ $a=[System.Windows.MessageBox]::Show('Nettoyer les fichiers temporaires Windows et la Corbeille ?','SENETECH - Nettoyage',[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Question); if($a -eq [System.Windows.MessageBoxResult]::Yes){ try{ Set-ControlsEnabled $false; [void](Invoke-SenetechCleanup); Set-Progress 100 'Nettoyage termine' } finally { Set-ControlsEnabled $true } } })
    $script:StartupButton.Add_Click({ Show-SenetechStartupManager })
    $script:RefreshCatalogButton.Add_Click({ try { Set-ControlsEnabled $false; if(Update-SenetechCatalog){ Initialize-SenetechDynamicCatalog; Set-Profile 'Essentiel' }; Set-Progress 100 'Catalogue actualise' } finally { Set-ControlsEnabled $true } })
    $script:UndoTweaksButton.Add_Click({ Undo-SenetechProfileOptimizations }); $script:RollbackButton.Add_Click({ Start-SenetechRollback })
}

function Initialize-SenetechV16Features {
    Initialize-SenetechDynamicCatalog -RefreshRemote; Add-SenetechTechnicianUi
    $security = Get-SenetechSecuritySnapshot
    Write-Log ("Securite : {0} | Secure Boot : {1} | Systeme : {2} | Demarrage : {3} element(s)" -f $security.TPM,$security.SecureBoot,$security.SystemDrive,$security.StartupCount)
    Add-SenetechHistory 'Demarrage SENETECH' 'OK' ('V' + $script:DisplayVersion)
}

function Install-WindowsUpdates([bool]$IncludeSoftware, [bool]$IncludeDrivers) {
    if (-not (Test-Internet)) { throw 'Connexion Internet indisponible pour Windows Update.' }
    $engine = Join-Path $script:EngineDir 'Moteur-WindowsUpdate.ps1'; $engineLog = Join-Path $script:LogDir ("WindowsUpdate-{0}.log" -f $script:SessionStamp); $rebootMarker = Join-Path $script:LogDir ("Reboot-{0}.txt" -f $script:SessionStamp)
    $optional = if ($script:OptionalUpdatesCheck -and $script:OptionalUpdatesCheck.IsChecked -eq $true) { 1 } else { 0 }
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $engine + '"'),'-Software',$(if($IncludeSoftware){'1'}else{'0'}),'-Drivers',$(if($IncludeDrivers){'1'}else{'0'}),'-Optional',[string]$optional,'-LogPath',('"' + $engineLog + '"'),'-RebootMarker',('"' + $rebootMarker + '"'))
    $code = Invoke-ProcessVisible -FilePath 'powershell.exe' -Arguments $arguments
    if (Test-Path -LiteralPath $engineLog) { Get-Content -LiteralPath $engineLog -ErrorAction SilentlyContinue | ForEach-Object { Write-Log $_ 'WU' } }
    if (Test-Path -LiteralPath $rebootMarker) { $script:RebootRequired = $true }
    if ($code -ne 0) { throw "Le moteur Windows Update a signale une erreur (code $code)." }
    Add-SenetechHistory 'Windows Update' 'OK' ("Software=$IncludeSoftware Drivers=$IncludeDrivers Optional=$optional")
}
