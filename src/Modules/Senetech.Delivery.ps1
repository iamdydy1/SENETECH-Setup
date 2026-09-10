# SENETECH V1.6 - sales delivery / customer handoff tools
# ASCII-only source for Windows PowerShell 5.1 compatibility.

$script:DeliveryRoot = Join-Path $env:ProgramData 'SENETECH\Delivery'
$script:WelcomeRoot = Join-Path $env:ProgramData 'SENETECH\Welcome'
$script:DeliveryCleanupTask = 'SENETECH Delivery Cleanup'

function Test-SenetechDeliveryAdmin {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Get-SenetechTechnicianContext {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $sid = [string]$identity.User.Value
    $userName = [Environment]::UserName
    $profilePath = [Environment]::GetFolderPath('UserProfile')
    $isBuiltinAdmin = $sid -match '-500$'
    $isLocal = $false
    try {
        $account = Get-CimInstance Win32_UserAccount -Filter ("SID='{0}'" -f $sid) -ErrorAction Stop | Select-Object -First 1
        if ($account) { $isLocal = [bool]$account.LocalAccount }
    } catch { }
    return [pscustomobject]@{
        UserName = $userName
        Sid = $sid
        ProfilePath = $profilePath
        IsBuiltinAdministrator = $isBuiltinAdmin
        IsLocalAccount = $isLocal
    }
}

function Get-SenetechInstalledPrograms {
    $items = @()
    $locations = @(
        @{ Path='HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'; Scope='Machine64' },
        @{ Path='HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'; Scope='Machine32' },
        @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'; Scope='CurrentUser' }
    )
    foreach ($loc in $locations) {
        foreach ($p in @(Get-ItemProperty -Path $loc.Path -ErrorAction SilentlyContinue)) {
            $name = [string]$p.DisplayName
            if ([string]::IsNullOrWhiteSpace($name)) { continue }
            if ($p.ReleaseType -match 'Update|Hotfix|Security Update') { continue }
            $items += [pscustomobject]@{
                Name = $name.Trim()
                Version = [string]$p.DisplayVersion
                Publisher = [string]$p.Publisher
                UninstallString = [string]$p.UninstallString
                QuietUninstallString = [string]$p.QuietUninstallString
                WindowsInstaller = [int]($p.WindowsInstaller -as [int])
                SystemComponent = [int]($p.SystemComponent -as [int])
                NoRemove = [int]($p.NoRemove -as [int])
                KeyName = [string]$p.PSChildName
                Scope = [string]$loc.Scope
            }
        }
    }
    return @($items | Sort-Object Name,Version,Scope -Unique)
}

function Test-SenetechProtectedProgram($Program) {
    $name = [string]$Program.Name
    $publisher = [string]$Program.Publisher
    if ($Program.SystemComponent -eq 1 -or $Program.NoRemove -eq 1) { return $true }
    if ($name -match '^(Security Update|Update for|Hotfix|KB\d+)') { return $true }

    # Windows and shared Microsoft runtimes required by many applications.
    $windowsPatterns = @(
        '^Microsoft Edge$', '^Microsoft Edge WebView2 Runtime$', '^Microsoft OneDrive$',
        '^Microsoft Update Health Tools$', '^Windows ', '^Microsoft Windows ',
        '^Microsoft Visual C\+\+', '^Microsoft\.NET', '^Microsoft .NET',
        '^Microsoft Windows Desktop Runtime', '^Microsoft ASP\.NET Core',
        '^Microsoft DirectX', '^WebView2 Runtime'
    )
    foreach ($pattern in $windowsPatterns) { if ($name -match $pattern) { return $true } }

    # Hardware drivers and low-level device components are never removed automatically.
    $hardwarePublisher = $publisher -match '(?i)Intel|Advanced Micro Devices|AMD|NVIDIA|Realtek|Synaptics|ELAN|Qualcomm|Broadcom|MediaTek|Marvell|Cirrus|Dolby|DTS|SteelSeries ApS'
    $driverName = $name -match '(?i)driver|chipset|firmware|bluetooth|wireless|wi-fi|ethernet|network|audio|display|graphics|serial io|management engine|touchpad|hotkey|thunderbolt|usb|physx'
    if ($hardwarePublisher -and $driverName) { return $true }

    return $false
}

function Get-SenetechDeliveryInventory {
    $all = @(Get-SenetechInstalledPrograms)
    $rows = @()
    foreach ($p in $all) {
        $protected = Test-SenetechProtectedProgram $p
        $rows += [pscustomobject]@{
            Name = $p.Name
            Version = $p.Version
            Publisher = $p.Publisher
            Scope = $p.Scope
            Protected = $protected
            Action = if ($protected) { 'Conserver' } else { 'Supprimer en mode PC propre' }
            Program = $p
        }
    }
    return @($rows)
}

function Show-SenetechDeliveryInventory {
    $rows = @(Get-SenetechDeliveryInventory)
    $win = New-Object System.Windows.Window
    $win.Title = 'SENETECH - Apercu avant livraison'
    $win.Width = 980
    $win.Height = 650
    $win.WindowStartupLocation = 'CenterOwner'
    $win.Owner = $window
    $win.Background = '#0B1320'
    $win.Foreground = '#E5EEF5'

    $panel = New-Object System.Windows.Controls.DockPanel
    $header = New-Object System.Windows.Controls.TextBlock
    $removeCount = @($rows | Where-Object { -not $_.Protected }).Count
    $keepCount = @($rows | Where-Object { $_.Protected }).Count
    $header.Text = "Applications detectees : $($rows.Count) | a supprimer : $removeCount | protegees : $keepCount"
    $header.Margin = '14'
    $header.FontSize = 15
    [System.Windows.Controls.DockPanel]::SetDock($header,'Top')
    [void]$panel.Children.Add($header)

    $footer = New-Object System.Windows.Controls.StackPanel
    $footer.Orientation='Horizontal'; $footer.HorizontalAlignment='Right'; $footer.Margin='12'
    [System.Windows.Controls.DockPanel]::SetDock($footer,'Bottom')
    $close = New-Object System.Windows.Controls.Button; $close.Content='Fermer'; $close.Padding='16,8'; $close.Margin='5'
    $close.Add_Click({ $win.Close() })
    [void]$footer.Children.Add($close); [void]$panel.Children.Add($footer)

    $displayRows = @($rows | Select-Object Name,Version,Publisher,Scope,Action)
    $grid = New-Object System.Windows.Controls.DataGrid
    $grid.Margin='12'; $grid.AutoGenerateColumns=$true; $grid.IsReadOnly=$true
    $grid.ItemsSource=$displayRows
    $grid.HeadersVisibility='Column'; $grid.GridLinesVisibility='Horizontal'
    [void]$panel.Children.Add($grid)
    $win.Content=$panel
    [void]$win.ShowDialog()
}

function Invoke-SenetechQuietCommand([string]$Command) {
    if ([string]::IsNullOrWhiteSpace($Command)) { return 1603 }
    $p = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/d','/s','/c',('"' + $Command + '"')) -WindowStyle Hidden -Wait -PassThru
    return [int]$p.ExitCode
}

function Invoke-SenetechProgramRemoval($Program) {
    Write-Log ("Suppression application : {0}" -f $Program.Name) 'INFO'

    # MSI products can be removed deterministically and silently.
    if ($Program.WindowsInstaller -eq 1 -or $Program.KeyName -match '^\{[0-9A-Fa-f-]+\}$') {
        $productCode = if ($Program.KeyName -match '^\{[0-9A-Fa-f-]+\}$') { $Program.KeyName } else { $null }
        if ($productCode) {
            $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/x',$productCode,'/qn','/norestart') -Wait -PassThru -WindowStyle Hidden
            if ($p.ExitCode -in @(0,1605,1614,3010)) { return $true }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($Program.QuietUninstallString)) {
        $code = Invoke-SenetechQuietCommand $Program.QuietUninstallString
        if ($code -in @(0,1605,1614,3010)) { return $true }
    }

    # Prefer WinGet for desktop applications when a vendor did not publish a quiet uninstaller.
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($winget) {
        $args = @('uninstall','--name',$Program.Name,'--exact','--silent','--accept-source-agreements','--disable-interactivity')
        $p = Start-Process -FilePath $winget.Source -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
        if ($p.ExitCode -eq 0) { return $true }
    }

    return $false
}

function Invoke-SenetechThirdPartyCleanup {
    $candidates = @(Get-SenetechInstalledPrograms | Where-Object { -not (Test-SenetechProtectedProgram $_) })
    if ($candidates.Count -eq 0) {
        Write-Log 'Aucune application tierce a supprimer.' 'OK'
        return [pscustomobject]@{ Removed=@(); Failed=@() }
    }

    $removed = @(); $failed = @(); $i = 0
    foreach ($program in $candidates) {
        $i++
        try {
            Set-Progress ([Math]::Min(72,20 + [int](50*$i/$candidates.Count))) ("Suppression : {0}" -f $program.Name)
            if (Invoke-SenetechProgramRemoval $program) {
                $removed += $program.Name
                Write-Log ("Application supprimee : {0}" -f $program.Name) 'OK'
            } else {
                $failed += $program.Name
                Write-Log ("Suppression automatique impossible : {0}" -f $program.Name) 'ATTENTION'
            }
        } catch {
            $failed += $program.Name
            Write-Log ("Erreur suppression {0} : {1}" -f $program.Name,$_.Exception.Message) 'ATTENTION'
        }
    }
    Add-SenetechHistory 'Nettoyage applications vente' $(if($failed.Count -eq 0){'OK'}else{'ATTENTION'}) ("supprimees=$($removed.Count) echecs=$($failed.Count)")
    return [pscustomobject]@{ Removed=$removed; Failed=$failed }
}

function Invoke-SenetechTechnicianTraceCleanup {
    try { [void](Invoke-SenetechCleanup) } catch { }
    $recent = Join-Path $env:APPDATA 'Microsoft\Windows\Recent'
    if (Test-Path -LiteralPath $recent) {
        Get-ChildItem -LiteralPath $recent -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    try { Clear-History -ErrorAction SilentlyContinue } catch { }
    foreach ($path in @(
        (Join-Path $env:TEMP 'SENETECH-*'),
        (Join-Path $env:LOCALAPPDATA 'Temp\SENETECH-*')
    )) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Log 'Traces de session technicien nettoyees. Le profil complet sera retire au prochain demarrage.' 'OK'
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
    $content = @"
`$ErrorActionPreference = 'SilentlyContinue'
`$log = '$($logPath.Replace("'","''"))'
function Log([string]`$m) { Add-Content -LiteralPath `$log -Encoding UTF8 -Value (('[{0}] {1}' -f (Get-Date -Format 's'),`$m)) }
if (-not (Test-Path -LiteralPath '$($commitPath.Replace("'","''"))')) { Log 'No OOBE commit marker. Cleanup skipped.'; exit 0 }
Start-Sleep -Seconds 12
`$sid = '$sid'
`$user = '$($user.Replace("'","''"))'
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
Remove-Item -LiteralPath '$($commitPath.Replace("'","''"))' -Force -ErrorAction SilentlyContinue
try { Unregister-ScheduledTask -TaskName '$script:DeliveryCleanupTask' -Confirm:`$false -ErrorAction SilentlyContinue } catch { }
Log 'SENETECH delivery cleanup completed.'
"@
    [IO.File]::WriteAllText($scriptPath,$content,(New-Object Text.UTF8Encoding($true)))
    return $scriptPath
}

function Register-SenetechCleanupAfterOobe($Context) {
    $scriptPath = New-SenetechCleanupAfterOobeScript $Context
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $scriptPath)
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
    Register-ScheduledTask -TaskName $script:DeliveryCleanupTask -Action $action -Trigger $trigger -Settings $settings -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
    Write-Log 'Suppression differee du profil technicien programmee.' 'OK'
}

function Unregister-SenetechDeliveryCleanup {
    try { Unregister-ScheduledTask -TaskName $script:DeliveryCleanupTask -Confirm:$false -ErrorAction SilentlyContinue } catch { }
    Remove-Item -LiteralPath (Join-Path $script:DeliveryRoot 'COMMIT-OOBE.flag') -Force -ErrorAction SilentlyContinue
}

function Remove-SenetechWelcomeRegistration {
    $defaultHive = Join-Path $env:SystemDrive 'Users\Default\NTUSER.DAT'
    if (-not (Test-Path -LiteralPath $defaultHive)) { return }
    $mount = 'HKU\SENETECH_DEFAULT'
    try {
        & reg.exe unload $mount 2>$null | Out-Null
        & reg.exe load $mount $defaultHive | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $key = 'Registry::HKEY_USERS\SENETECH_DEFAULT\Software\Microsoft\Windows\CurrentVersion\RunOnce'
            Remove-ItemProperty -Path $key -Name 'SENETECH Welcome' -Force -ErrorAction SilentlyContinue
        }
    } finally {
        Start-Sleep -Milliseconds 200
        & reg.exe unload $mount 2>$null | Out-Null
    }
}

function Install-SenetechWelcomeForNewOwner {
    $source = Join-Path $script:EngineDir 'Client\SENETECH-Welcome.ps1'
    if (-not (Test-Path -LiteralPath $source)) { throw 'Module SENETECH Welcome introuvable.' }
    New-Item -ItemType Directory -Path $script:WelcomeRoot -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination (Join-Path $script:WelcomeRoot 'SENETECH-Welcome.ps1') -Force
    Copy-Item -LiteralPath (Join-Path $script:EngineDir 'Catalog\apps.json') -Destination (Join-Path $script:WelcomeRoot 'apps.json') -Force
    Copy-Item -LiteralPath (Join-Path $script:EngineDir 'Catalog\profiles.json') -Destination (Join-Path $script:WelcomeRoot 'profiles.json') -Force
    $logo = Join-Path $script:EngineDir 'Assets\SENETECH-Logo.png'
    if (Test-Path -LiteralPath $logo) { Copy-Item -LiteralPath $logo -Destination (Join-Path $script:WelcomeRoot 'SENETECH-Logo.png') -Force }
    try { & icacls.exe $script:WelcomeRoot /grant '*S-1-5-32-545:(OI)(CI)M' /T /C | Out-Null } catch { }

    $defaultHive = Join-Path $env:SystemDrive 'Users\Default\NTUSER.DAT'
    if (-not (Test-Path -LiteralPath $defaultHive)) { throw 'Profil Default Windows introuvable.' }
    $mount = 'HKU\SENETECH_DEFAULT'
    & reg.exe unload $mount 2>$null | Out-Null
    & reg.exe load $mount $defaultHive | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Impossible de charger le profil Default Windows.' }
    try {
        $command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + (Join-Path $script:WelcomeRoot 'SENETECH-Welcome.ps1') + '"'
        $key = 'Registry::HKEY_USERS\SENETECH_DEFAULT\Software\Microsoft\Windows\CurrentVersion\RunOnce'
        New-Item -Path $key -Force | Out-Null
        New-ItemProperty -Path $key -Name 'SENETECH Welcome' -PropertyType String -Value $command -Force | Out-Null
    } finally {
        Start-Sleep -Milliseconds 300
        & reg.exe unload $mount | Out-Null
    }
    Write-Log 'SENETECH Welcome programme pour le premier profil client.' 'OK'
    Add-SenetechHistory 'SENETECH Welcome client' 'OK'
}

function Invoke-SenetechOobeSeal {
    $sysprep = Join-Path $env:WINDIR 'System32\Sysprep\Sysprep.exe'
    if (-not (Test-Path -LiteralPath $sysprep)) { throw 'Sysprep Windows introuvable.' }
    Write-Log 'Preparation OOBE Windows en cours. Le PC sera ensuite eteint.' 'INFO'
    Set-Progress 92 'Preparation OOBE Windows'
    $p = Start-Process -FilePath $sysprep -ArgumentList @('/oobe','/quit','/quiet') -PassThru -Wait
    if ($p.ExitCode -ne 0) {
        throw "Sysprep a echoue (code $($p.ExitCode)). Consultez C:\Windows\System32\Sysprep\Panther\setuperr.log."
    }
    New-Item -ItemType Directory -Path $script:DeliveryRoot -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $script:DeliveryRoot 'COMMIT-OOBE.flag') -Encoding ASCII -Value (Get-Date -Format 's')
    Add-SenetechHistory 'Passage OOBE' 'OK'
    Set-Progress 100 'PC pret pour livraison'
    Write-Log 'OOBE prepare. Extinction du PC dans 15 secondes.' 'OK'
    Start-Process -FilePath 'shutdown.exe' -ArgumentList @('/s','/t','15','/c','SENETECH : PC finalise pour livraison') -WindowStyle Hidden
}

function Start-SenetechDeliveryFinalization([string]$Mode, [bool]$EnableWelcome) {
    if (-not (Test-SenetechDeliveryAdmin)) { throw 'SENETECH doit etre execute en administrateur.' }
    $context = Get-SenetechTechnicianContext
    $modeLabel = if ($Mode -eq 'clean') { 'PC propre / vierge' } else { 'Configuration client conservee' }
    Add-SenetechHistory 'Finalisation vente demandee' 'INFO' $modeLabel

    if ($Mode -eq 'clean') {
        Set-Progress 15 'Nettoyage des applications tierces'
        $result = Invoke-SenetechThirdPartyCleanup
        if ($result.Failed.Count -gt 0) {
            $failedText = ($result.Failed | Select-Object -First 12) -join "`n - "
            throw "Certaines applications n ont pas pu etre supprimees automatiquement :`n - $failedText`n`nLa finalisation est arretee pour eviter de livrer un PC incomplet."
        }
        $remaining = @(Get-SenetechInstalledPrograms | Where-Object { -not (Test-SenetechProtectedProgram $_) })
        if ($remaining.Count -gt 0) {
            throw "Il reste $($remaining.Count) application(s) tierce(s) detectee(s). Relancez l apercu avant de finaliser."
        }
    }

    Set-Progress 75 'Nettoyage des traces technicien'
    Invoke-SenetechTechnicianTraceCleanup
    Register-SenetechCleanupAfterOobe $context
    try {
        if ($EnableWelcome) { Install-SenetechWelcomeForNewOwner }
        Invoke-SenetechOobeSeal
    } catch {
        Unregister-SenetechDeliveryCleanup
        if ($EnableWelcome) { Remove-SenetechWelcomeRegistration }
        throw
    }
}

function Show-SenetechDeliveryWizard {
    $context = Get-SenetechTechnicianContext
    $win = New-Object System.Windows.Window
    $win.Title='SENETECH - Finaliser pour la vente'
    $win.Width=720; $win.Height=650; $win.WindowStartupLocation='CenterOwner'; $win.Owner=$window
    $win.Background='#0B1320'; $win.Foreground='#E5EEF5'

    $scroll = New-Object System.Windows.Controls.ScrollViewer; $scroll.VerticalScrollBarVisibility='Auto'
    $panel = New-Object System.Windows.Controls.StackPanel; $panel.Margin='24'
    $title = New-Object System.Windows.Controls.TextBlock; $title.Text='FINALISER POUR LA VENTE'; $title.FontSize=25; $title.FontWeight='Bold'; $title.Margin='0,0,0,8'
    $sub = New-Object System.Windows.Controls.TextBlock; $sub.Text='Choisissez ce que le client doit recevoir. Windows, les mises a jour et les pilotes sont conserves.'; $sub.TextWrapping='Wrap'; $sub.Foreground='#9FB4C8'; $sub.Margin='0,0,0,18'
    [void]$panel.Children.Add($title); [void]$panel.Children.Add($sub)

    $clean = New-Object System.Windows.Controls.RadioButton; $clean.Content='PC propre / vierge - supprimer les applications tierces detectees'; $clean.IsChecked=$true; $clean.Margin='0,8'; $clean.FontSize=14
    $configured = New-Object System.Windows.Controls.RadioButton; $configured.Content='PC configure pour le client - conserver les applications installees'; $configured.Margin='0,8'; $configured.FontSize=14
    [void]$panel.Children.Add($clean); [void]$panel.Children.Add($configured)

    $info = New-Object System.Windows.Controls.TextBlock
    $info.Text = "Profil technicien actuel : $($context.UserName)`nCe profil sera supprime automatiquement au prochain demarrage client."
    $info.TextWrapping='Wrap'; $info.Margin='0,14'; $info.Foreground='#7FC7E8'
    [void]$panel.Children.Add($info)

    $welcome = New-Object System.Windows.Controls.CheckBox; $welcome.Content='Afficher SENETECH Welcome au premier profil client'; $welcome.IsChecked=$true; $welcome.Margin='0,8'
    [void]$panel.Children.Add($welcome)

    $warning = New-Object System.Windows.Controls.Border; $warning.Background='#301B1B'; $warning.Padding='12'; $warning.Margin='0,14'
    $warningText = New-Object System.Windows.Controls.TextBlock
    $warningText.Text='IMPORTANT : la finalisation nettoie la session technicien, supprime son profil au prochain demarrage, remet Windows en OOBE puis eteint le PC. Ne rallumez ensuite la machine que pour la livrer ou tester le parcours client.'
    $warningText.TextWrapping='Wrap'; $warningText.Foreground='#FFB3B3'; $warning.Child=$warningText
    [void]$panel.Children.Add($warning)

    $preview = New-Object System.Windows.Controls.Button; $preview.Content='Voir les applications detectees'; $preview.Padding='14,8'; $preview.Margin='0,4,0,14'; $preview.HorizontalAlignment='Left'
    $preview.Add_Click({ Show-SenetechDeliveryInventory })
    [void]$panel.Children.Add($preview)

    $confirmLabel = New-Object System.Windows.Controls.TextBlock; $confirmLabel.Text='Pour activer le bouton final, tapez VENTE :'; $confirmLabel.Margin='0,4'
    $confirm = New-Object System.Windows.Controls.TextBox; $confirm.Height=32; $confirm.Margin='0,0,0,14'; $confirm.MaxLength=10
    [void]$panel.Children.Add($confirmLabel); [void]$panel.Children.Add($confirm)

    $buttons = New-Object System.Windows.Controls.StackPanel; $buttons.Orientation='Horizontal'; $buttons.HorizontalAlignment='Right'
    $cancel = New-Object System.Windows.Controls.Button; $cancel.Content='Annuler'; $cancel.Padding='16,9'; $cancel.Margin='5'
    $final = New-Object System.Windows.Controls.Button; $final.Content='FINALISER ET PREPARER OOBE'; $final.Padding='16,9'; $final.Margin='5'; $final.IsEnabled=$false
    $confirm.Add_TextChanged({ $final.IsEnabled = ($confirm.Text.Trim().ToUpperInvariant() -eq 'VENTE') })
    $cancel.Add_Click({ $win.Close() })
    $final.Add_Click({
        $mode = if ($clean.IsChecked -eq $true) { 'clean' } else { 'configured' }
        $label = if ($mode -eq 'clean') { 'supprimer les applications tierces + traces technicien' } else { 'conserver les applications + supprimer les traces technicien' }
        $answer = [System.Windows.MessageBox]::Show("Confirmer : $label ?`n`nLe profil technicien sera supprime et Windows demarrera ensuite sur Bienvenue/OOBE.",'SENETECH - Confirmation finale',[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Warning)
        if ($answer -ne [System.Windows.MessageBoxResult]::Yes) { return }
        $win.Close()
        try {
            Set-ControlsEnabled $false
            Start-SenetechDeliveryFinalization -Mode $mode -EnableWelcome ($welcome.IsChecked -eq $true)
        } catch {
            Write-Log ("Finalisation vente interrompue : {0}" -f $_.Exception.Message) 'ERREUR'
            [System.Windows.MessageBox]::Show($_.Exception.Message,'SENETECH - Finalisation interrompue',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
            Set-ControlsEnabled $true
        }
    })
    [void]$buttons.Children.Add($cancel); [void]$buttons.Children.Add($final); [void]$panel.Children.Add($buttons)
    $scroll.Content=$panel; $win.Content=$scroll
    [void]$win.ShowDialog()
}

function Add-SenetechDeliveryUi {
    if (-not $script:LeftPanel) { return }
    $group = New-Object System.Windows.Controls.GroupBox
    $group.Header='7. Livraison / Vente'; $group.Padding='12'; $group.Margin='0,12,0,0'
    $panel = New-Object System.Windows.Controls.StackPanel
    $text = New-Object System.Windows.Controls.TextBlock
    $text.Text='Nettoyage final, suppression du profil technicien, OOBE Windows et SENETECH Welcome pour le nouveau proprietaire.'
    $text.TextWrapping='Wrap'; $text.Margin='0,0,0,9'; $text.Foreground='#9FB4C8'
    $script:DeliveryButton = New-Object System.Windows.Controls.Button
    $script:DeliveryButton.Content='FINALISER POUR LA VENTE'; $script:DeliveryButton.Padding='12,9'; $script:DeliveryButton.Margin='0,0,0,4'
    $script:DeliveryButton.Add_Click({ Show-SenetechDeliveryWizard })
    [void]$panel.Children.Add($text); [void]$panel.Children.Add($script:DeliveryButton)
    $group.Content=$panel; [void]$script:LeftPanel.Children.Add($group)
}

function Initialize-SenetechDeliveryFeatures {
    Add-SenetechDeliveryUi
    Write-Log 'Module Livraison / Vente SENETECH charge.' 'OK'
}
