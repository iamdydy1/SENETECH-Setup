# SENETECH V1.6 - responsive delivery dialogs
# ASCII-only source for Windows PowerShell 5.1 compatibility.

function Get-SenetechDialogSize {
    param(
        [double]$PreferredWidth = 860,
        [double]$PreferredHeight = 700
    )

    $work = [System.Windows.SystemParameters]::WorkArea
    $w = [double]$work.Width
    $h = [double]$work.Height
    try {
        if (Get-Command Get-SenetechDisplayMetrics -ErrorAction SilentlyContinue) {
            $m = Get-SenetechDisplayMetrics
            $w = [double]$m.WorkWidth
            $h = [double]$m.WorkHeight
        }
    } catch { }

    $compact = ($w -le 1450 -or $h -le 820)
    $width = [Math]::Min($PreferredWidth, [Math]::Max(620.0, $w * $(if($compact){0.96}else{0.86})))
    $height = [Math]::Min($PreferredHeight, [Math]::Max(520.0, $h * $(if($compact){0.94}else{0.88})))

    return [pscustomobject]@{ Width=$width; Height=$height; Compact=$compact; WorkWidth=$w; WorkHeight=$h }
}

function Set-SenetechReadableDialogWindow($Win, $Size) {
    $Win.Width = [double]$Size.Width
    $Win.Height = [double]$Size.Height
    $Win.MaxWidth = [double]$Size.WorkWidth
    $Win.MaxHeight = [double]$Size.WorkHeight
    $Win.MinWidth = [Math]::Min(620.0,[double]$Size.Width)
    $Win.MinHeight = [Math]::Min(500.0,[double]$Size.Height)
    $Win.WindowStartupLocation = 'CenterOwner'
    $Win.Owner = $window
    $Win.Background = '#0B1320'
    $Win.Foreground = '#F4F7FB'
    $Win.FontSize = 14
    $Win.UseLayoutRounding = $true
    $Win.SnapsToDevicePixels = $true
}

function Show-SenetechDeliveryInventory {
    $rows = @(Get-SenetechDeliveryInventory)
    $size = Get-SenetechDialogSize -PreferredWidth 1080 -PreferredHeight 720
    $win = New-Object System.Windows.Window
    $win.Title = 'SENETECH - Apercu avant livraison'
    Set-SenetechReadableDialogWindow $win $size

    $panel = New-Object System.Windows.Controls.DockPanel
    $header = New-Object System.Windows.Controls.TextBlock
    $removeCount = @($rows | Where-Object { -not $_.Protected }).Count
    $keepCount = @($rows | Where-Object { $_.Protected }).Count
    $header.Text = "Applications detectees : $($rows.Count) | a supprimer : $removeCount | protegees : $keepCount"
    $header.Margin = '16,14,16,10'
    $header.FontSize = 15
    $header.FontWeight = 'SemiBold'
    $header.Foreground = '#F4F7FB'
    [System.Windows.Controls.DockPanel]::SetDock($header,'Top')
    [void]$panel.Children.Add($header)

    $footer = New-Object System.Windows.Controls.StackPanel
    $footer.Orientation='Horizontal'; $footer.HorizontalAlignment='Right'; $footer.Margin='12'
    [System.Windows.Controls.DockPanel]::SetDock($footer,'Bottom')
    $close = New-Object System.Windows.Controls.Button; $close.Content='Fermer'; $close.Padding='18,9'; $close.Margin='5'; $close.FontSize=14
    $close.Add_Click({ $win.Close() })
    [void]$footer.Children.Add($close); [void]$panel.Children.Add($footer)

    $displayRows = @($rows | Select-Object Name,Version,Publisher,Scope,Action)
    $grid = New-Object System.Windows.Controls.DataGrid
    $grid.Margin='12'; $grid.AutoGenerateColumns=$true; $grid.IsReadOnly=$true
    $grid.ItemsSource=$displayRows
    $grid.HeadersVisibility='Column'; $grid.GridLinesVisibility='Horizontal'
    $grid.FontSize=13
    $grid.RowHeight=30
    $grid.ColumnHeaderHeight=32
    [void]$panel.Children.Add($grid)
    $win.Content=$panel
    [void]$win.ShowDialog()
}

function Show-SenetechDeliveryWizard {
    $context = Get-SenetechTechnicianContext
    $size = Get-SenetechDialogSize -PreferredWidth 860 -PreferredHeight 720
    $win = New-Object System.Windows.Window
    $win.Title='SENETECH - Finaliser pour la vente'
    Set-SenetechReadableDialogWindow $win $size

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility='Auto'
    $scroll.HorizontalScrollBarVisibility='Disabled'
    $scroll.Padding='0'

    $panel = New-Object System.Windows.Controls.StackPanel
    $panel.Margin = $(if($size.Compact){'20,16,20,18'}else{'28,22,28,24'})

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text='FINALISER POUR LA VENTE'
    $title.FontSize=$(if($size.Compact){24}else{27})
    $title.FontWeight='Bold'
    $title.Foreground='#FFFFFF'
    $title.Margin='0,0,0,8'

    $sub = New-Object System.Windows.Controls.TextBlock
    $sub.Text='Choisissez ce que le client doit recevoir. Windows, les mises a jour et les pilotes sont conserves.'
    $sub.TextWrapping='Wrap'
    $sub.FontSize=14
    $sub.Foreground='#D8E6F3'
    $sub.Margin='0,0,0,16'
    [void]$panel.Children.Add($title); [void]$panel.Children.Add($sub)

    $clean = New-Object System.Windows.Controls.RadioButton
    $clean.Content='PC propre / vierge - supprimer les applications tierces detectees'
    $clean.IsChecked=$true; $clean.Margin='0,8'; $clean.FontSize=15; $clean.Foreground='#F4F7FB'

    $configured = New-Object System.Windows.Controls.RadioButton
    $configured.Content='PC configure pour le client - conserver les applications installees'
    $configured.Margin='0,8'; $configured.FontSize=15; $configured.Foreground='#F4F7FB'
    [void]$panel.Children.Add($clean); [void]$panel.Children.Add($configured)

    $infoBorder = New-Object System.Windows.Controls.Border
    $infoBorder.Background='#10263A'; $infoBorder.Padding='12'; $infoBorder.Margin='0,12,0,10'
    $info = New-Object System.Windows.Controls.TextBlock
    $info.Text = "Profil technicien actuel : $($context.UserName)`nCe profil sera supprime automatiquement au prochain demarrage client."
    $info.TextWrapping='Wrap'; $info.FontSize=14; $info.Foreground='#9DDEFF'
    $infoBorder.Child=$info
    [void]$panel.Children.Add($infoBorder)

    $welcome = New-Object System.Windows.Controls.CheckBox
    $welcome.Content='Afficher SENETECH Welcome au premier profil client'
    $welcome.IsChecked=$true; $welcome.Margin='0,8'; $welcome.FontSize=14; $welcome.Foreground='#F4F7FB'
    [void]$panel.Children.Add($welcome)

    $warning = New-Object System.Windows.Controls.Border
    $warning.Background='#421F24'; $warning.BorderBrush='#B65D65'; $warning.BorderThickness='1'; $warning.Padding='12'; $warning.Margin='0,12'
    $warningText = New-Object System.Windows.Controls.TextBlock
    $warningText.Text='IMPORTANT : la finalisation nettoie la session technicien, supprime son profil au prochain demarrage, remet Windows en OOBE puis eteint le PC. Ne rallumez ensuite la machine que pour la livrer ou tester le parcours client.'
    $warningText.TextWrapping='Wrap'; $warningText.FontSize=14; $warningText.FontWeight='SemiBold'; $warningText.Foreground='#FFD7D7'; $warning.Child=$warningText
    [void]$panel.Children.Add($warning)

    $preview = New-Object System.Windows.Controls.Button
    $preview.Content='Voir les applications detectees'; $preview.Padding='15,9'; $preview.Margin='0,4,0,14'; $preview.HorizontalAlignment='Left'; $preview.FontSize=14
    $preview.Add_Click({ Show-SenetechDeliveryInventory })
    [void]$panel.Children.Add($preview)

    $confirmLabel = New-Object System.Windows.Controls.TextBlock
    $confirmLabel.Text='Pour activer le bouton final, tapez VENTE :'; $confirmLabel.Margin='0,4,0,6'; $confirmLabel.FontSize=14; $confirmLabel.FontWeight='SemiBold'; $confirmLabel.Foreground='#FFFFFF'
    $confirm = New-Object System.Windows.Controls.TextBox
    $confirm.Height=38; $confirm.Margin='0,0,0,14'; $confirm.MaxLength=10; $confirm.FontSize=16; $confirm.Padding='8,5'; $confirm.Background='#FFFFFF'; $confirm.Foreground='#111827'
    [void]$panel.Children.Add($confirmLabel); [void]$panel.Children.Add($confirm)

    $buttons = New-Object System.Windows.Controls.WrapPanel
    $buttons.HorizontalAlignment='Right'
    $cancel = New-Object System.Windows.Controls.Button
    $cancel.Content='Annuler'; $cancel.Padding='18,10'; $cancel.Margin='5'; $cancel.FontSize=14; $cancel.MinWidth=100
    $final = New-Object System.Windows.Controls.Button
    $final.Content='FINALISER ET PREPARER OOBE'; $final.Padding='18,10'; $final.Margin='5'; $final.FontSize=14; $final.MinWidth=250; $final.IsEnabled=$false
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
    if ($size.Compact) { Write-Log 'Fenetre Livraison adaptee au mode Compact.' 'OK' }
    [void]$win.ShowDialog()
}
