# SENETECH Welcome - first owner application chooser
# ASCII-only source for Windows PowerShell 5.1 compatibility.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$done = Join-Path $root 'completed.flag'
if (Test-Path -LiteralPath $done) { exit 0 }

$culture = [Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName
$isFr = ($culture -eq 'fr')
function T([string]$fr,[string]$en) { if ($isFr) { return $fr } else { return $en } }

$appsPath = Join-Path $root 'apps.json'
$profilesPath = Join-Path $root 'profiles.json'
if (-not (Test-Path -LiteralPath $appsPath) -or -not (Test-Path -LiteralPath $profilesPath)) { exit 0 }
$catalog = Get-Content -LiteralPath $appsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$profilesData = Get-Content -LiteralPath $profilesPath -Raw -Encoding UTF8 | ConvertFrom-Json
$apps = @($catalog.apps)
$profiles = @($profilesData.profiles)

$window = New-Object System.Windows.Window
$window.Title='SENETECH Welcome'
$window.Width=900; $window.Height=700; $window.WindowStartupLocation='CenterScreen'
$window.Background='#0B1320'; $window.Foreground='#E5EEF5'

$rootPanel = New-Object System.Windows.Controls.DockPanel
$header = New-Object System.Windows.Controls.StackPanel; $header.Margin='24,22,24,8'
[System.Windows.Controls.DockPanel]::SetDock($header,'Top')
$logoPath = Join-Path $root 'SENETECH-Logo.png'
if (Test-Path -LiteralPath $logoPath) {
    try {
        $img = New-Object System.Windows.Controls.Image; $img.Height=72; $img.HorizontalAlignment='Left'; $img.Margin='0,0,0,10'
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit(); $bitmap.UriSource = New-Object Uri($logoPath); $bitmap.CacheOption='OnLoad'; $bitmap.EndInit(); $img.Source=$bitmap
        [void]$header.Children.Add($img)
    } catch { }
}
$title = New-Object System.Windows.Controls.TextBlock; $title.Text=(T 'Bienvenue sur votre PC prepare par SENETECH' 'Welcome to your SENETECH-prepared PC'); $title.FontSize=25; $title.FontWeight='Bold'
$desc = New-Object System.Windows.Controls.TextBlock; $desc.Text=(T 'Choisissez un profil ou personnalisez les applications que vous souhaitez installer. Tout est facultatif.' 'Choose a profile or customize the applications you want to install. Everything is optional.'); $desc.TextWrapping='Wrap'; $desc.Foreground='#9FB4C8'; $desc.Margin='0,6,0,8'
[void]$header.Children.Add($title); [void]$header.Children.Add($desc); [void]$rootPanel.Children.Add($header)

$footer = New-Object System.Windows.Controls.StackPanel; $footer.Orientation='Horizontal'; $footer.HorizontalAlignment='Right'; $footer.Margin='20'
[System.Windows.Controls.DockPanel]::SetDock($footer,'Bottom')
$status = New-Object System.Windows.Controls.TextBlock; $status.Text=''; $status.VerticalAlignment='Center'; $status.Margin='0,0,14,0'; $status.Foreground='#7FC7E8'
$noThanks = New-Object System.Windows.Controls.Button; $noThanks.Content=(T 'Non merci' 'No thanks'); $noThanks.Padding='16,9'; $noThanks.Margin='5'
$install = New-Object System.Windows.Controls.Button; $install.Content=(T 'Installer la selection' 'Install selection'); $install.Padding='16,9'; $install.Margin='5'
[void]$footer.Children.Add($status); [void]$footer.Children.Add($noThanks); [void]$footer.Children.Add($install); [void]$rootPanel.Children.Add($footer)

$body = New-Object System.Windows.Controls.StackPanel; $body.Margin='24,8,24,8'
$profileRow = New-Object System.Windows.Controls.StackPanel; $profileRow.Orientation='Horizontal'; $profileRow.Margin='0,0,0,12'
$profileLabel = New-Object System.Windows.Controls.TextBlock; $profileLabel.Text=(T 'Profil :' 'Profile:'); $profileLabel.VerticalAlignment='Center'; $profileLabel.Margin='0,0,10,0'
$profileCombo = New-Object System.Windows.Controls.ComboBox; $profileCombo.Width=260; $profileCombo.Height=32
foreach ($p in $profiles) { [void]$profileCombo.Items.Add([string]$p.name) }
[void]$profileRow.Children.Add($profileLabel); [void]$profileRow.Children.Add($profileCombo); [void]$body.Children.Add($profileRow)

$scroll = New-Object System.Windows.Controls.ScrollViewer; $scroll.VerticalScrollBarVisibility='Auto'
$list = New-Object System.Windows.Controls.WrapPanel
$checks = @{}
foreach ($app in $apps) {
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Content = [string]$app.name
    $cb.Tag = $app
    $cb.Width=260; $cb.Margin='4,5'; $cb.Foreground='#D5DFEC'
    $checks[[string]$app.key] = $cb
    [void]$list.Children.Add($cb)
}
$scroll.Content=$list; [void]$body.Children.Add($scroll)
[void]$rootPanel.Children.Add($body)
$window.Content=$rootPanel

function Select-Profile([string]$name) {
    foreach ($cb in $checks.Values) { $cb.IsChecked=$false }
    $p = $profiles | Where-Object { [string]$_.name -eq $name } | Select-Object -First 1
    if ($p) {
        foreach ($key in @($p.apps)) { if ($checks.ContainsKey([string]$key)) { $checks[[string]$key].IsChecked=$true } }
    }
}
$profileCombo.Add_SelectionChanged({ if ($profileCombo.SelectedItem) { Select-Profile ([string]$profileCombo.SelectedItem) } })
if ($profileCombo.Items.Count -gt 0) { $profileCombo.SelectedIndex=0 }

function Mark-Completed([string]$choice) {
    Set-Content -LiteralPath $done -Encoding ASCII -Value ((Get-Date -Format 's') + ' ' + $choice)
}

$noThanks.Add_Click({ Mark-Completed 'declined'; $window.Close() })
$install.Add_Click({
    $selected = @($checks.Values | Where-Object { $_.IsChecked -eq $true })
    if ($selected.Count -eq 0) {
        [System.Windows.MessageBox]::Show((T 'Aucune application selectionnee.' 'No application selected.'),'SENETECH Welcome') | Out-Null
        return
    }
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        [System.Windows.MessageBox]::Show((T 'WinGet est indisponible. Relancez SENETECH Welcome apres installation de App Installer.' 'WinGet is unavailable. Retry SENETECH Welcome after installing App Installer.'),'SENETECH Welcome') | Out-Null
        New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Force | Out-Null
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name 'SENETECH Welcome' -Value ('powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $MyInvocation.MyCommand.Path + '"') -Force
        return
    }
    $install.IsEnabled=$false; $noThanks.IsEnabled=$false; $profileCombo.IsEnabled=$false
    foreach ($cb in $checks.Values) { $cb.IsEnabled=$false }
    $ok=0; $fail=0; $i=0
    foreach ($cb in $selected) {
        $i++
        $app = $cb.Tag
        $status.Text = (T 'Installation : ' 'Installing: ') + [string]$app.name + " ($i/$($selected.Count))"
        $window.Dispatcher.Invoke([action]{},[Windows.Threading.DispatcherPriority]::Background)
        try {
            $args = @('install','--id',[string]$app.id,'--exact','--silent','--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
            $p = Start-Process -FilePath $winget.Source -ArgumentList $args -PassThru -Wait -WindowStyle Hidden
            if ($p.ExitCode -eq 0) { $ok++ } else { $fail++ }
        } catch { $fail++ }
    }
    Mark-Completed ("installed=$ok failed=$fail")
    $status.Text = T 'Installation terminee.' 'Installation completed.'
    [System.Windows.MessageBox]::Show((T "Installation terminee : $ok reussie(s), $fail a verifier." "Installation completed: $ok succeeded, $fail to review."),'SENETECH Welcome') | Out-Null
    $window.Close()
})

[void]$window.ShowDialog()
