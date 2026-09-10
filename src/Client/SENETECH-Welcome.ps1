# SENETECH Welcome - first owner application chooser and configured-app reconciliation
# ASCII-only source for Windows PowerShell 5.1 compatibility.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$done = Join-Path $root 'completed.flag'
$configuredPath = Join-Path $root 'configured-apps.json'
if (Test-Path -LiteralPath $done) { exit 0 }

$culture = [Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName
$isFr = ($culture -eq 'fr')

function Convert-WelcomeFrenchText([string]$Text) {
    if (-not $isFr) { return $Text }
    $map = [ordered]@{
        '{agrave}'=[string]([char]0x00E0); '{cced}'=[string]([char]0x00E7)
        '{eacute}'=[string]([char]0x00E9); '{egrave}'=[string]([char]0x00E8)
        '{ecirc}'=[string]([char]0x00EA); '{ocirc}'=[string]([char]0x00F4)
        '{ugrave}'=[string]([char]0x00F9)
    }
    $value = $Text
    foreach ($token in $map.Keys) { $value = $value.Replace($token,$map[$token]) }
    return $value
}

function T([string]$fr,[string]$en) {
    if ($isFr) { return (Convert-WelcomeFrenchText $fr) }
    return $en
}

function Set-WelcomeRetry {
    try {
        New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Force | Out-Null
        $command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $MyInvocation.MyCommand.Path + '"'
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name 'SENETECH Welcome' -Value $command -Force
    } catch { }
}

function Remove-WelcomeRetry {
    try { Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name 'SENETECH Welcome' -Force -ErrorAction SilentlyContinue } catch { }
}

function Schedule-WelcomeCleanup {
    $cleanup = Join-Path $env:TEMP ('SENETECH-Welcome-Cleanup-' + [guid]::NewGuid().ToString('N') + '.cmd')
    $content = @"
@echo off
ping 127.0.0.1 -n 5 >nul
rd /s /q "$root" >nul 2>&1
del /f /q "%~f0" >nul 2>&1
"@
    Set-Content -LiteralPath $cleanup -Value $content -Encoding ASCII
    Start-Process -FilePath $cleanup -WindowStyle Hidden
}

function Mark-Completed([string]$Choice) {
    Set-Content -LiteralPath $done -Encoding ASCII -Value ((Get-Date -Format 's') + ' ' + $Choice)
    Remove-WelcomeRetry
}

function Get-WelcomeAppInstallerPackages {
    $packages = @()
    try { $packages += @(Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue) } catch { }
    try { $packages += @(Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue) } catch { }
    return @($packages | Where-Object { $_ -and $_.InstallLocation } | Sort-Object Version -Descending -Unique)
}

function Find-WelcomeWinget {
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and (Test-Path -LiteralPath $cmd.Source)) { return [string]$cmd.Source }

    foreach ($pkg in @(Get-WelcomeAppInstallerPackages)) {
        $candidate = Join-Path ([string]$pkg.InstallLocation) 'winget.exe'
        if (Test-Path -LiteralPath $candidate) { return $candidate }
        try {
            $nested = Get-ChildItem -LiteralPath ([string]$pkg.InstallLocation) -Filter 'winget.exe' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($nested -and (Test-Path -LiteralPath $nested.FullName)) { return [string]$nested.FullName }
        } catch { }
    }

    $alias = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path -LiteralPath $alias) { return $alias }
    return $null
}

function Repair-WelcomeWingetRegistration {
    $winget = Find-WelcomeWinget
    if ($winget) { return $winget }

    foreach ($pkg in @(Get-WelcomeAppInstallerPackages)) {
        try {
            $manifest = Join-Path ([string]$pkg.InstallLocation) 'AppxManifest.xml'
            if (Test-Path -LiteralPath $manifest) {
                Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ForceApplicationShutdown -ErrorAction Stop
                Start-Sleep -Seconds 2
                $winget = Find-WelcomeWinget
                if ($winget) { return $winget }
            }
        } catch { }
    }
    return $null
}

function Get-RegistryPropertySafe($Object,[string]$Name) {
    try {
        $p = $Object.PSObject.Properties[$Name]
        if ($null -ne $p) { return $p.Value }
    } catch { }
    return $null
}

function Test-WelcomeRegistryApp([string]$RegistryPattern) {
    if ([string]::IsNullOrWhiteSpace($RegistryPattern)) { return $false }
    $locations = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($location in $locations) {
        foreach ($entry in @(Get-ItemProperty -Path $location -ErrorAction SilentlyContinue)) {
            $displayName = [string](Get-RegistryPropertySafe $entry 'DisplayName')
            if ($displayName -and $displayName.IndexOf($RegistryPattern,[StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
        }
    }
    return $false
}

function Test-WelcomeWingetApp($App,[string]$Winget) {
    if ([string]::IsNullOrWhiteSpace($Winget) -or [string]::IsNullOrWhiteSpace([string]$App.id)) { return $false }
    $out = Join-Path $env:TEMP ('SENETECH-Welcome-list-' + [guid]::NewGuid().ToString('N') + '.txt')
    $err = Join-Path $env:TEMP ('SENETECH-Welcome-list-' + [guid]::NewGuid().ToString('N') + '.err')
    try {
        $p = Start-Process -FilePath $Winget -ArgumentList @('list','--id',[string]$App.id,'--exact','--accept-source-agreements','--disable-interactivity') -PassThru -Wait -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err
        $text = ''
        if (Test-Path -LiteralPath $out) { $text += [IO.File]::ReadAllText($out) }
        if (Test-Path -LiteralPath $err) { $text += "`n" + [IO.File]::ReadAllText($err) }
        return ($text -match [regex]::Escape([string]$App.id))
    } catch { return $false }
    finally { Remove-Item -LiteralPath $out,$err -Force -ErrorAction SilentlyContinue }
}

function Test-WelcomeAppInstalled($App,[string]$Winget) {
    $registry = ''
    try {
        $prop = $App.PSObject.Properties['registry']
        if ($prop) { $registry = [string]$prop.Value }
    } catch { }
    if ($registry -and (Test-WelcomeRegistryApp $registry)) { return $true }
    return (Test-WelcomeWingetApp $App $Winget)
}

function Install-WelcomeApp($App,[string]$Winget) {
    if (Test-WelcomeAppInstalled $App $Winget) { return $true }
    if ([string]::IsNullOrWhiteSpace($Winget)) { return $false }

    $locale = [Globalization.CultureInfo]::CurrentUICulture.Name
    if ([string]::IsNullOrWhiteSpace($locale)) { $locale = 'fr-FR' }
    try {
        $args = @('install','--id',[string]$App.id,'--exact','--silent','--locale',$locale,'--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
        $p = Start-Process -FilePath $Winget -ArgumentList $args -PassThru -Wait -WindowStyle Hidden
        if ([int]$p.ExitCode -ne 0) {
            $args = @('install','--id',[string]$App.id,'--exact','--silent','--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
            [void](Start-Process -FilePath $Winget -ArgumentList $args -PassThru -Wait -WindowStyle Hidden)
        }
    } catch { }

    Start-Sleep -Milliseconds 700
    return (Test-WelcomeAppInstalled $App $Winget)
}

$appsPath = Join-Path $root 'apps.json'
$profilesPath = Join-Path $root 'profiles.json'
if (-not (Test-Path -LiteralPath $appsPath) -or -not (Test-Path -LiteralPath $profilesPath)) {
    Set-WelcomeRetry
    exit 0
}

$catalog = Get-Content -LiteralPath $appsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$profilesData = Get-Content -LiteralPath $profilesPath -Raw -Encoding UTF8 | ConvertFrom-Json
$apps = @($catalog.apps)
$profiles = @($profilesData.profiles)
$configuredApps = @()
if (Test-Path -LiteralPath $configuredPath) {
    try {
        $configuredData = Get-Content -LiteralPath $configuredPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $configuredApps = @($configuredData.apps)
    } catch { $configuredApps = @() }
}

$window = New-Object System.Windows.Window
$window.Title = 'SENETECH Welcome'
$work = [System.Windows.SystemParameters]::WorkArea
$window.Width = [Math]::Min(900.0,[double]$work.Width * 0.94)
$window.Height = [Math]::Min(700.0,[double]$work.Height * 0.92)
$window.MinWidth = [Math]::Min(640.0,[double]$window.Width)
$window.MinHeight = [Math]::Min(520.0,[double]$window.Height)
$window.WindowStartupLocation = 'CenterScreen'
$window.Background = '#0B1320'
$window.Foreground = '#F4F7FB'
$window.FontSize = 14

$rootPanel = New-Object System.Windows.Controls.DockPanel
$header = New-Object System.Windows.Controls.StackPanel
$header.Margin = '24,22,24,8'
[System.Windows.Controls.DockPanel]::SetDock($header,'Top')

$logoPath = Join-Path $root 'SENETECH-Logo.png'
if (Test-Path -LiteralPath $logoPath) {
    try {
        $img = New-Object System.Windows.Controls.Image
        $img.Height = 72
        $img.HorizontalAlignment = 'Left'
        $img.Margin = '0,0,0,10'
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit(); $bitmap.UriSource = New-Object Uri($logoPath); $bitmap.CacheOption='OnLoad'; $bitmap.EndInit()
        $img.Source = $bitmap
        [void]$header.Children.Add($img)
    } catch { }
}

$title = New-Object System.Windows.Controls.TextBlock
$title.Text = T 'Bienvenue sur votre PC pr{eacute}par{eacute} par SENETECH' 'Welcome to your SENETECH-prepared PC'
$title.FontSize = 25; $title.FontWeight = 'Bold'; $title.Foreground = '#FFFFFF'
$desc = New-Object System.Windows.Controls.TextBlock
$desc.Text = T 'SENETECH v{eacute}rifie d''abord la configuration pr{eacute}par{eacute}e par le technicien, puis vous pouvez choisir des applications suppl{eacute}mentaires. Tout ajout est facultatif.' 'SENETECH first verifies the configuration prepared by the technician, then you may choose optional additional applications.'
$desc.TextWrapping = 'Wrap'; $desc.Foreground = '#C8D8E8'; $desc.Margin = '0,6,0,8'
[void]$header.Children.Add($title); [void]$header.Children.Add($desc); [void]$rootPanel.Children.Add($header)

$footer = New-Object System.Windows.Controls.WrapPanel
$footer.HorizontalAlignment = 'Right'; $footer.Margin = '20'
[System.Windows.Controls.DockPanel]::SetDock($footer,'Bottom')
$status = New-Object System.Windows.Controls.TextBlock
$status.Text = ''; $status.VerticalAlignment = 'Center'; $status.Margin = '0,0,14,0'; $status.Foreground = '#9DDEFF'; $status.TextWrapping = 'Wrap'; $status.MaxWidth = 430
$retry = New-Object System.Windows.Controls.Button
$retry.Content = T 'R{eacute}essayer' 'Retry'; $retry.Padding = '16,9'; $retry.Margin = '5'; $retry.Visibility = 'Collapsed'
$noThanks = New-Object System.Windows.Controls.Button
$noThanks.Content = T 'Non merci' 'No thanks'; $noThanks.Padding = '16,9'; $noThanks.Margin = '5'
$install = New-Object System.Windows.Controls.Button
$install.Content = T 'Installer la s{eacute}lection' 'Install selection'; $install.Padding = '16,9'; $install.Margin = '5'
[void]$footer.Children.Add($status); [void]$footer.Children.Add($retry); [void]$footer.Children.Add($noThanks); [void]$footer.Children.Add($install); [void]$rootPanel.Children.Add($footer)

$body = New-Object System.Windows.Controls.StackPanel
$body.Margin = '24,8,24,8'
$configInfo = New-Object System.Windows.Controls.TextBlock
$configInfo.TextWrapping = 'Wrap'; $configInfo.Margin = '0,0,0,10'; $configInfo.Foreground = '#9DDEFF'
$configInfo.Text = if ($configuredApps.Count -gt 0) { T ("Configuration client {agrave} v{eacute}rifier : $($configuredApps.Count) application(s).") ("Customer configuration to verify: $($configuredApps.Count) app(s).") } else { T 'Aucune application impos{eacute}e par la pr{eacute}paration technicien.' 'No required application was recorded by the technician preparation.' }
[void]$body.Children.Add($configInfo)

$profileRow = New-Object System.Windows.Controls.StackPanel
$profileRow.Orientation = 'Horizontal'; $profileRow.Margin = '0,0,0,12'
$profileLabel = New-Object System.Windows.Controls.TextBlock
$profileLabel.Text = T 'Profil :' 'Profile:'; $profileLabel.VerticalAlignment = 'Center'; $profileLabel.Margin = '0,0,10,0'
$profileCombo = New-Object System.Windows.Controls.ComboBox
$profileCombo.Width = 260; $profileCombo.Height = 32
foreach ($p in $profiles) { [void]$profileCombo.Items.Add([string]$p.name) }
[void]$profileRow.Children.Add($profileLabel); [void]$profileRow.Children.Add($profileCombo); [void]$body.Children.Add($profileRow)

$scroll = New-Object System.Windows.Controls.ScrollViewer
$scroll.VerticalScrollBarVisibility = 'Auto'
$list = New-Object System.Windows.Controls.WrapPanel
$checks = @{}
foreach ($app in $apps) {
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Content = [string]$app.name; $cb.Tag = $app; $cb.Width = 260; $cb.Margin = '4,5'; $cb.Foreground = '#E5EEF5'
    $checks[[string]$app.key] = $cb
    [void]$list.Children.Add($cb)
}
$scroll.Content = $list; [void]$body.Children.Add($scroll); [void]$rootPanel.Children.Add($body)
$window.Content = $rootPanel

function Select-Profile([string]$Name) {
    foreach ($cb in $checks.Values) { $cb.IsChecked = $false }
    $p = $profiles | Where-Object { [string]$_.name -eq $Name } | Select-Object -First 1
    if ($p) { foreach ($key in @($p.apps)) { if ($checks.ContainsKey([string]$key)) { $checks[[string]$key].IsChecked = $true } } }
}
$profileCombo.Add_SelectionChanged({ if ($profileCombo.SelectedItem) { Select-Profile ([string]$profileCombo.SelectedItem) } })
if ($profileCombo.Items.Count -gt 0) { $profileCombo.SelectedIndex = 0 }

function Set-WelcomeControls([bool]$Enabled) {
    $install.IsEnabled = $Enabled; $noThanks.IsEnabled = $Enabled; $profileCombo.IsEnabled = $Enabled
    foreach ($cb in $checks.Values) { $cb.IsEnabled = $Enabled }
}

$script:ConfiguredReady = ($configuredApps.Count -eq 0)
$script:ConfiguredLastFailures = @()

function Invoke-ConfiguredReconciliation {
    $script:ConfiguredLastFailures = @()
    if ($configuredApps.Count -eq 0) {
        $script:ConfiguredReady = $true
        $configInfo.Text = T 'Configuration technicien : aucun logiciel obligatoire {agrave} r{eacute}concilier.' 'Technician configuration: no required app to reconcile.'
        return $true
    }

    Set-WelcomeControls $false; $retry.Visibility = 'Collapsed'
    $winget = Repair-WelcomeWingetRegistration
    if (-not $winget) {
        $script:ConfiguredReady = $false; $script:ConfiguredLastFailures = @('WinGet')
        $status.Text = T 'WinGet est indisponible. Connectez le PC {agrave} Internet puis r{eacute}essayez.' 'WinGet is unavailable. Connect the PC to the Internet and retry.'
        $retry.Visibility = 'Visible'; Set-WelcomeRetry
        return $false
    }

    $ok = 0; $i = 0
    foreach ($app in $configuredApps) {
        $i++
        $status.Text = (T 'V{eacute}rification de la configuration : ' 'Checking prepared configuration: ') + [string]$app.name + " ($i/$($configuredApps.Count))"
        $window.Dispatcher.Invoke([action]{},[Windows.Threading.DispatcherPriority]::Background)
        if (Test-WelcomeAppInstalled $app $winget) { $ok++; continue }
        if (Install-WelcomeApp $app $winget) { $ok++ } else { $script:ConfiguredLastFailures += [string]$app.name }
    }

    if ($script:ConfiguredLastFailures.Count -eq 0) {
        $script:ConfiguredReady = $true
        $configInfo.Text = T ("Configuration technicien v{eacute}rifi{eacute}e : $ok/$($configuredApps.Count) application(s) pr{eacute}sente(s).") ("Technician configuration verified: $ok/$($configuredApps.Count) app(s) present.")
        $status.Text = T 'Configuration pr{eacute}par{eacute}e : OK. Vous pouvez maintenant choisir des applications facultatives.' 'Prepared configuration: OK. You may now choose optional applications.'
        Remove-WelcomeRetry; Set-WelcomeControls $true
        return $true
    }

    $script:ConfiguredReady = $false
    $status.Text = T ("Configuration incompl{egrave}te : $($script:ConfiguredLastFailures.Count) application(s) {agrave} r{eacute}essayer.") ("Configuration incomplete: $($script:ConfiguredLastFailures.Count) app(s) to retry.")
    $retry.Visibility = 'Visible'; Set-WelcomeRetry
    return $false
}

$retry.Add_Click({ [void](Invoke-ConfiguredReconciliation) })

$noThanks.Add_Click({
    if (-not $script:ConfiguredReady) {
        [System.Windows.MessageBox]::Show((T 'La configuration pr{eacute}par{eacute}e par le technicien n''est pas encore compl{egrave}te. Utilisez R{eacute}essayer.' 'The technician-prepared configuration is not complete yet. Use Retry.'),'SENETECH Welcome') | Out-Null
        return
    }
    Mark-Completed 'declined-optional-apps'; $window.Close(); Schedule-WelcomeCleanup
})

$install.Add_Click({
    if (-not $script:ConfiguredReady) {
        [System.Windows.MessageBox]::Show((T 'La configuration pr{eacute}par{eacute}e doit d''abord {ecirc}tre valid{eacute}e.' 'The prepared configuration must be validated first.'),'SENETECH Welcome') | Out-Null
        return
    }
    $selected = @($checks.Values | Where-Object { $_.IsChecked -eq $true })
    if ($selected.Count -eq 0) {
        [System.Windows.MessageBox]::Show((T 'Aucune application s{eacute}lectionn{eacute}e.' 'No application selected.'),'SENETECH Welcome') | Out-Null
        return
    }
    $winget = Repair-WelcomeWingetRegistration
    if (-not $winget) {
        Set-WelcomeRetry
        [System.Windows.MessageBox]::Show((T 'WinGet est indisponible. Connectez le PC {agrave} Internet puis r{eacute}essayez.' 'WinGet is unavailable. Connect the PC to the Internet and retry.'),'SENETECH Welcome') | Out-Null
        return
    }

    Set-WelcomeControls $false; $retry.Visibility = 'Collapsed'
    $ok = 0; $failures = @(); $i = 0
    foreach ($cb in $selected) {
        $i++; $app = $cb.Tag
        $status.Text = (T 'Installation et v{eacute}rification : ' 'Installing and verifying: ') + [string]$app.name + " ($i/$($selected.Count))"
        $window.Dispatcher.Invoke([action]{},[Windows.Threading.DispatcherPriority]::Background)
        if (Test-WelcomeAppInstalled $app $winget) { $ok++; continue }
        if (Install-WelcomeApp $app $winget) { $ok++ } else { $failures += [string]$app.name }
    }

    if ($failures.Count -gt 0) {
        $status.Text = T ("$ok application(s) valid{eacute}e(s), $($failures.Count) en {eacute}chec. Vous pouvez r{eacute}essayer.") ("$ok app(s) verified, $($failures.Count) failed. You may retry.")
        Set-WelcomeRetry; Set-WelcomeControls $true
        [System.Windows.MessageBox]::Show((T ("Certaines applications n''ont pas pu {ecirc}tre valid{eacute}es :`n - " + ($failures -join "`n - ")) ("Some applications could not be verified:`n - " + ($failures -join "`n - "))),'SENETECH Welcome',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }

    Mark-Completed ("optional-installed=$ok")
    $status.Text = T 'Installation termin{eacute}e et v{eacute}rifi{eacute}e.' 'Installation completed and verified.'
    [System.Windows.MessageBox]::Show((T ("Installation termin{eacute}e : $ok application(s) valid{eacute}e(s).") ("Installation completed: $ok app(s) verified.")),'SENETECH Welcome') | Out-Null
    $window.Close(); Schedule-WelcomeCleanup
})

$window.Add_ContentRendered({ if (-not $script:ConfiguredReady) { [void](Invoke-ConfiguredReconciliation) } })
[void]$window.ShowDialog()
