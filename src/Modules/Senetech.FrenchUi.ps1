# SENETECH V1.6 - French UI spelling and accent-safe overrides
# ASCII-only source. Accented characters are generated at runtime for Windows PowerShell 5.1.

function Convert-SenetechFrenchText {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return '' }
    $value = $Text
    $map = [ordered]@{
        '{agrave}' = [string]([char]0x00E0)
        '{acirc}' = [string]([char]0x00E2)
        '{cced}' = [string]([char]0x00E7)
        '{eacute}' = [string]([char]0x00E9)
        '{egrave}' = [string]([char]0x00E8)
        '{ecirc}' = [string]([char]0x00EA)
        '{euml}' = [string]([char]0x00EB)
        '{icirc}' = [string]([char]0x00EE)
        '{iuml}' = [string]([char]0x00EF)
        '{ocirc}' = [string]([char]0x00F4)
        '{ugrave}' = [string]([char]0x00F9)
        '{ucirc}' = [string]([char]0x00FB)
        '{uuml}' = [string]([char]0x00FC)
        '{Agrave}' = [string]([char]0x00C0)
        '{Eacute}' = [string]([char]0x00C9)
    }
    foreach ($token in $map.Keys) { $value = $value.Replace($token,$map[$token]) }
    return $value
}

function FR([string]$Text) { return (Convert-SenetechFrenchText $Text) }

function Add-SenetechTechnicianUi {
    $group = New-Object System.Windows.Controls.GroupBox
    $group.Header = '6. Outils technicien'
    $group.Padding = '12'
    $group.Margin = '0,12,0,0'

    $panel = New-Object System.Windows.Controls.StackPanel

    $script:CreateRestoreCheck = New-Object System.Windows.Controls.CheckBox
    $script:CreateRestoreCheck.Content = (FR 'Cr{eacute}er un point de restauration avant les modifications')
    $script:CreateRestoreCheck.IsChecked = $true
    $script:CreateRestoreCheck.Margin = '0,4'

    $script:ApplyTweaksCheck = New-Object System.Windows.Controls.CheckBox
    $script:ApplyTweaksCheck.Content = (FR 'Appliquer les optimisations du profil (r{eacute}versibles)')
    $script:ApplyTweaksCheck.IsChecked = $true
    $script:ApplyTweaksCheck.Margin = '0,4'

    $script:UpdateInstalledAppsCheck = New-Object System.Windows.Controls.CheckBox
    $script:UpdateInstalledAppsCheck.Content = (FR 'Mettre {agrave} jour les applications du catalogue d{eacute}j{agrave} install{eacute}es')
    $script:UpdateInstalledAppsCheck.IsChecked = $true
    $script:UpdateInstalledAppsCheck.Margin = '0,4'

    $script:CleanupAfterCheck = New-Object System.Windows.Controls.CheckBox
    $script:CleanupAfterCheck.Content = (FR 'Nettoyer les fichiers temporaires en fin de pr{eacute}paration')
    $script:CleanupAfterCheck.IsChecked = $true
    $script:CleanupAfterCheck.Margin = '0,4'

    $script:OptionalUpdatesCheck = New-Object System.Windows.Controls.CheckBox
    $script:OptionalUpdatesCheck.Content = (FR 'Inclure les mises {agrave} jour Windows facultatives / Preview')
    $script:OptionalUpdatesCheck.IsChecked = $false
    $script:OptionalUpdatesCheck.Margin = '0,4'

    $buttons = New-Object System.Windows.Controls.WrapPanel
    $buttons.Margin = '0,9,0,0'
    $specs = @(
        @('UpdateAppsButton',(FR 'Mettre {agrave} jour les applications')),
        @('CleanupButton','Nettoyer Windows'),
        @('StartupButton',(FR 'D{eacute}marrage Windows')),
        @('RefreshCatalogButton','Actualiser le catalogue'),
        @('UndoTweaksButton','Annuler les optimisations'),
        @('RollbackButton',(FR 'Restaurer la version pr{eacute}c{eacute}dente'))
    )
    foreach ($spec in $specs) {
        $b = New-Object System.Windows.Controls.Button
        $b.Content = $spec[1]
        $b.Padding = '12,7'
        $b.Margin = '0,0,8,8'
        Set-Variable -Name $spec[0] -Value $b -Scope Script
        [void]$buttons.Children.Add($b)
    }

    foreach ($c in @($script:CreateRestoreCheck,$script:ApplyTweaksCheck,$script:UpdateInstalledAppsCheck,$script:CleanupAfterCheck,$script:OptionalUpdatesCheck,$buttons)) {
        [void]$panel.Children.Add($c)
    }

    $hint = New-Object System.Windows.Controls.TextBlock
    $hint.Text = (FR 'Les actions sensibles cr{eacute}ent une sauvegarde lorsque cela est possible. Aucun effacement de disque ni red{eacute}marrage automatique.')
    $hint.TextWrapping = 'Wrap'
    $hint.Foreground = '#6FAFD1'
    $hint.Margin = '0,5,0,0'
    [void]$panel.Children.Add($hint)

    $group.Content = $panel
    [void]$script:LeftPanel.Children.Add($group)

    $script:UpdateAppsButton.Add_Click({
        try {
            Set-ControlsEnabled $false
            $script:AppResults += @(Invoke-SenetechAppUpdates)
            Set-Progress 100 (FR 'Applications contr{ocirc}l{eacute}es')
        } catch { Write-Log $_.Exception.Message 'ERREUR' }
        finally { Set-ControlsEnabled $true }
    })

    $script:CleanupButton.Add_Click({
        $a = [System.Windows.MessageBox]::Show((FR 'Nettoyer les fichiers temporaires Windows et la Corbeille ?'),'SENETECH - Nettoyage',[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Question)
        if ($a -eq [System.Windows.MessageBoxResult]::Yes) {
            try {
                Set-ControlsEnabled $false
                [void](Invoke-SenetechCleanup)
                Set-Progress 100 (FR 'Nettoyage termin{eacute}')
            } finally { Set-ControlsEnabled $true }
        }
    })

    $script:StartupButton.Add_Click({ Show-SenetechStartupManager })
    $script:RefreshCatalogButton.Add_Click({
        try {
            Set-ControlsEnabled $false
            if (Update-SenetechCatalog) { Initialize-SenetechDynamicCatalog; Set-Profile 'Essentiel' }
            Set-Progress 100 (FR 'Catalogue actualis{eacute}')
        } finally { Set-ControlsEnabled $true }
    })
    $script:UndoTweaksButton.Add_Click({ Undo-SenetechProfileOptimizations })
    $script:RollbackButton.Add_Click({ Start-SenetechRollback })
}

function Show-SenetechStartupManager {
    $items = @(Get-SenetechStartupItems)
    $win = New-Object System.Windows.Window
    $win.Title = (FR 'SENETECH - D{eacute}marrage Windows')
    $win.Width = 760
    $win.Height = 560
    $win.WindowStartupLocation = 'CenterOwner'
    $win.Owner = $window
    $win.Background = '#0B1320'
    $win.Foreground = '#E5EEF5'

    $rootPanel = New-Object System.Windows.Controls.DockPanel
    $footer = New-Object System.Windows.Controls.StackPanel
    $footer.Orientation = 'Horizontal'
    $footer.HorizontalAlignment = 'Right'
    $footer.Margin = '12'
    [System.Windows.Controls.DockPanel]::SetDock($footer,'Bottom')

    $disableButton = New-Object System.Windows.Controls.Button
    $disableButton.Content = (FR 'D{eacute}sactiver la s{eacute}lection')
    $disableButton.Padding = '12,7'
    $disableButton.Margin = '4'

    $restoreButton = New-Object System.Windows.Controls.Button
    $restoreButton.Content = (FR 'Restaurer les {eacute}l{eacute}ments SENETECH')
    $restoreButton.Padding = '12,7'
    $restoreButton.Margin = '4'

    $closeButton = New-Object System.Windows.Controls.Button
    $closeButton.Content = 'Fermer'
    $closeButton.Padding = '12,7'
    $closeButton.Margin = '4'

    [void]$footer.Children.Add($disableButton)
    [void]$footer.Children.Add($restoreButton)
    [void]$footer.Children.Add($closeButton)
    [void]$rootPanel.Children.Add($footer)

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = 'Auto'
    $scroll.Margin = '12'
    $list = New-Object System.Windows.Controls.StackPanel

    foreach ($item in $items) {
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Content = ('{0} - {1}' -f $item.Name,$item.Source)
        $cb.ToolTip = $item.Command
        $cb.Tag = $item
        $cb.Margin = '4'
        $cb.Foreground = '#D5DFEC'
        [void]$list.Children.Add($cb)
    }

    if ($items.Count -eq 0) {
        $text = New-Object System.Windows.Controls.TextBlock
        $text.Text = (FR 'Aucun {eacute}l{eacute}ment de d{eacute}marrage classique d{eacute}tect{eacute}.')
        $text.Margin = '8'
        [void]$list.Children.Add($text)
    }

    $scroll.Content = $list
    [void]$rootPanel.Children.Add($scroll)
    $win.Content = $rootPanel

    $disableButton.Add_Click({
        $selected = @($list.Children | Where-Object { $_ -is [System.Windows.Controls.CheckBox] -and $_.IsChecked -eq $true })
        foreach ($cb in $selected) {
            try {
                Disable-SenetechStartupItem $cb.Tag
                $cb.IsEnabled = $false
                $cb.IsChecked = $false
            } catch { Write-Log $_.Exception.Message 'ATTENTION' }
        }
        if ($selected.Count -gt 0) {
            Write-Log (FR ('{0} {eacute}l{eacute}ment(s) de d{eacute}marrage d{eacute}sactiv{eacute}(s).' -f $selected.Count)) 'OK'
        }
    })

    $restoreButton.Add_Click({
        Restore-SenetechStartupItems
        [System.Windows.MessageBox]::Show((FR 'Les {eacute}l{eacute}ments d{eacute}sactiv{eacute}s par SENETECH ont {eacute}t{eacute} restaur{eacute}s.'),'SENETECH Setup') | Out-Null
    })

    $closeButton.Add_Click({ $win.Close() })
    [void]$win.ShowDialog()
}

function Show-SenetechDeliveryInventory {
    try {
        Write-Log (FR 'Ouverture de l''aper{cced}u des applications avant livraison...') 'INFO'
        $rows = @(Get-SenetechDeliveryInventory)
        if ($null -eq $rows) { $rows = @() }

        $size = $null
        try {
            if (Get-Command Get-SenetechDialogSize -ErrorAction SilentlyContinue) {
                $size = Get-SenetechDialogSize -PreferredWidth 1040 -PreferredHeight 720
            }
        } catch { }
        if (-not $size) {
            $work = [System.Windows.SystemParameters]::WorkArea
            $size = [pscustomobject]@{
                Width = [Math]::Min(1040.0,[double]$work.Width * 0.94)
                Height = [Math]::Min(720.0,[double]$work.Height * 0.92)
                WorkWidth = [double]$work.Width
                WorkHeight = [double]$work.Height
                Compact = ([double]$work.Width -le 1450 -or [double]$work.Height -le 820)
            }
        }

        $inventoryWindow = New-Object System.Windows.Window
        $inventoryWindow.Title = (FR 'SENETECH - Applications d{eacute}tect{eacute}es avant livraison')
        try {
            if (Get-Command Set-SenetechReadableDialogWindow -ErrorAction SilentlyContinue) {
                Set-SenetechReadableDialogWindow $inventoryWindow $size
            } else {
                $inventoryWindow.Width = [double]$size.Width
                $inventoryWindow.Height = [double]$size.Height
                $inventoryWindow.WindowStartupLocation = 'CenterOwner'
                try { if ($window -and $window.IsVisible) { $inventoryWindow.Owner = $window } } catch { }
                $inventoryWindow.Background = '#0B1320'
                $inventoryWindow.Foreground = '#F4F7FB'
                $inventoryWindow.FontSize = 14
            }
        } catch {
            $inventoryWindow.Width = 900
            $inventoryWindow.Height = 620
            $inventoryWindow.WindowStartupLocation = 'CenterScreen'
            $inventoryWindow.Background = '#0B1320'
            $inventoryWindow.Foreground = '#F4F7FB'
            $inventoryWindow.FontSize = 14
        }

        $root = New-Object System.Windows.Controls.DockPanel
        $removeCount = @($rows | Where-Object { -not [bool]$_.Protected }).Count
        $keepCount = @($rows | Where-Object { [bool]$_.Protected }).Count

        $header = New-Object System.Windows.Controls.TextBlock
        $header.Text = (FR ('Applications d{eacute}tect{eacute}es : {0}   |   {Agrave} supprimer : {1}   |   Prot{eacute}g{eacute}es : {2}' -f $rows.Count,$removeCount,$keepCount))
        $header.Margin = '16,14,16,8'
        $header.FontSize = 15
        $header.FontWeight = 'SemiBold'
        $header.Foreground = '#FFFFFF'
        $header.TextWrapping = 'Wrap'
        [System.Windows.Controls.DockPanel]::SetDock($header,'Top')
        [void]$root.Children.Add($header)

        $help = New-Object System.Windows.Controls.TextBlock
        $help.Text = (FR 'CONSERVER = Windows, pilote, runtime ou composant prot{eacute}g{eacute}. SUPPRIMER = application tierce retir{eacute}e uniquement en mode PC propre.')
        $help.Margin = '16,0,16,10'
        $help.FontSize = 13
        $help.Foreground = '#C8D8E8'
        $help.TextWrapping = 'Wrap'
        [System.Windows.Controls.DockPanel]::SetDock($help,'Top')
        [void]$root.Children.Add($help)

        $footer = New-Object System.Windows.Controls.StackPanel
        $footer.Orientation = 'Horizontal'
        $footer.HorizontalAlignment = 'Right'
        $footer.Margin = '12'
        [System.Windows.Controls.DockPanel]::SetDock($footer,'Bottom')

        $closeButton = New-Object System.Windows.Controls.Button
        $closeButton.Content = 'Fermer'
        $closeButton.Padding = '18,9'
        $closeButton.Margin = '5'
        $closeButton.FontSize = 14
        $closeButton.MinWidth = 100
        $closeHandler = { try { $inventoryWindow.Close() } catch { } }.GetNewClosure()
        $closeButton.Add_Click($closeHandler)
        [void]$footer.Children.Add($closeButton)
        [void]$root.Children.Add($footer)

        $lines = New-Object System.Collections.Generic.List[string]
        foreach ($row in $rows) {
            $action = if ([bool]$row.Protected) { 'CONSERVER' } else { 'SUPPRIMER' }
            $name = [string]$row.Name
            $version = [string]$row.Version
            $publisher = [string]$row.Publisher
            $scope = [string]$row.Scope
            if ([string]::IsNullOrWhiteSpace($version)) { $version = '-' }
            if ([string]::IsNullOrWhiteSpace($publisher)) { $publisher = '-' }
            [void]$lines.Add((FR ('[{0}] {1} | Version : {2} | {Eacute}diteur : {3} | {4}' -f $action,$name,$version,$publisher,$scope)))
        }
        if ($lines.Count -eq 0) {
            [void]$lines.Add((FR 'Aucune application classique d{eacute}tect{eacute}e dans les cl{eacute}s de d{eacute}sinstallation Windows.'))
        }

        $text = New-Object System.Windows.Controls.TextBox
        $text.Text = ($lines -join [Environment]::NewLine)
        $text.Margin = '12'
        $text.IsReadOnly = $true
        $text.AcceptsReturn = $true
        $text.TextWrapping = 'NoWrap'
        $text.VerticalScrollBarVisibility = 'Auto'
        $text.HorizontalScrollBarVisibility = 'Auto'
        $text.Background = '#0E1A28'
        $text.Foreground = '#F4F7FB'
        $text.BorderBrush = '#35506B'
        $text.BorderThickness = '1'
        $text.FontFamily = 'Consolas'
        $text.FontSize = 13
        $text.Padding = '10'
        [void]$root.Children.Add($text)

        $inventoryWindow.Content = $root
        Write-Log (FR ('Aper{cced}u des applications pr{ecirc}t : {0} d{eacute}tect{eacute}e(s), {1} {agrave} supprimer, {2} prot{eacute}g{eacute}e(s).' -f $rows.Count,$removeCount,$keepCount)) 'OK'
        [void]$inventoryWindow.ShowDialog()
    } catch {
        $message = (FR 'Impossible d''ouvrir l''aper{cced}u des applications : ') + $_.Exception.Message
        try { Write-Log $message 'ERREUR' } catch { }
        try {
            [System.Windows.MessageBox]::Show($message,(FR 'SENETECH - Aper{cced}u des applications'),[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
        } catch { }
    }
}

function Show-SenetechDeliveryWizard {
    $context = Get-SenetechTechnicianContext
    $size = Get-SenetechDialogSize -PreferredWidth 860 -PreferredHeight 720
    $win = New-Object System.Windows.Window
    $win.Title = 'SENETECH - Finaliser pour la vente'
    Set-SenetechReadableDialogWindow $win $size

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = 'Auto'
    $scroll.HorizontalScrollBarVisibility = 'Disabled'

    $panel = New-Object System.Windows.Controls.StackPanel
    $panel.Margin = $(if($size.Compact){'20,16,20,18'}else{'28,22,28,24'})

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = 'FINALISER POUR LA VENTE'
    $title.FontSize = $(if($size.Compact){24}else{27})
    $title.FontWeight = 'Bold'
    $title.Foreground = '#FFFFFF'
    $title.Margin = '0,0,0,8'

    $sub = New-Object System.Windows.Controls.TextBlock
    $sub.Text = (FR 'Choisissez ce que le client doit recevoir. Windows, les mises {agrave} jour et les pilotes sont conserv{eacute}s.')
    $sub.TextWrapping = 'Wrap'
    $sub.FontSize = 14
    $sub.Foreground = '#D8E6F3'
    $sub.Margin = '0,0,0,16'
    [void]$panel.Children.Add($title)
    [void]$panel.Children.Add($sub)

    $clean = New-Object System.Windows.Controls.RadioButton
    $clean.Content = (FR 'PC propre / vierge - supprimer les applications tierces d{eacute}tect{eacute}es')
    $clean.IsChecked = $true
    $clean.Margin = '0,8'
    $clean.FontSize = 15
    $clean.Foreground = '#F4F7FB'

    $configured = New-Object System.Windows.Controls.RadioButton
    $configured.Content = (FR 'PC configur{eacute} pour le client - conserver les applications install{eacute}es')
    $configured.Margin = '0,8'
    $configured.FontSize = 15
    $configured.Foreground = '#F4F7FB'
    [void]$panel.Children.Add($clean)
    [void]$panel.Children.Add($configured)

    $infoBorder = New-Object System.Windows.Controls.Border
    $infoBorder.Background = '#10263A'
    $infoBorder.Padding = '12'
    $infoBorder.Margin = '0,12,0,10'
    $info = New-Object System.Windows.Controls.TextBlock
    $info.Text = (FR ("Profil technicien actuel : $($context.UserName)`nCe profil sera supprim{eacute} automatiquement au prochain d{eacute}marrage du client."))
    $info.TextWrapping = 'Wrap'
    $info.FontSize = 14
    $info.Foreground = '#9DDEFF'
    $infoBorder.Child = $info
    [void]$panel.Children.Add($infoBorder)

    $welcome = New-Object System.Windows.Controls.CheckBox
    $welcome.Content = (FR 'Afficher SENETECH Welcome sur le premier profil du client')
    $welcome.IsChecked = $true
    $welcome.Margin = '0,8'
    $welcome.FontSize = 14
    $welcome.Foreground = '#F4F7FB'
    [void]$panel.Children.Add($welcome)

    $warning = New-Object System.Windows.Controls.Border
    $warning.Background = '#421F24'
    $warning.BorderBrush = '#B65D65'
    $warning.BorderThickness = '1'
    $warning.Padding = '12'
    $warning.Margin = '0,12'
    $warningText = New-Object System.Windows.Controls.TextBlock
    $warningText.Text = (FR 'IMPORTANT : la finalisation nettoie la session technicien, supprime son profil au prochain d{eacute}marrage, remet Windows en OOBE puis {eacute}teint le PC. Ne rallumez ensuite la machine que pour la livrer ou tester le parcours client.')
    $warningText.TextWrapping = 'Wrap'
    $warningText.FontSize = 14
    $warningText.FontWeight = 'SemiBold'
    $warningText.Foreground = '#FFD7D7'
    $warning.Child = $warningText
    [void]$panel.Children.Add($warning)

    $preview = New-Object System.Windows.Controls.Button
    $preview.Content = (FR 'Voir les applications d{eacute}tect{eacute}es')
    $preview.Padding = '15,9'
    $preview.Margin = '0,4,0,14'
    $preview.HorizontalAlignment = 'Left'
    $preview.FontSize = 14
    $preview.Add_Click({ Show-SenetechDeliveryInventory })
    [void]$panel.Children.Add($preview)

    $confirmLabel = New-Object System.Windows.Controls.TextBlock
    $confirmLabel.Text = 'Pour activer le bouton final, tapez VENTE :'
    $confirmLabel.Margin = '0,4,0,6'
    $confirmLabel.FontSize = 14
    $confirmLabel.FontWeight = 'SemiBold'
    $confirmLabel.Foreground = '#FFFFFF'

    $confirm = New-Object System.Windows.Controls.TextBox
    $confirm.Height = 38
    $confirm.Margin = '0,0,0,14'
    $confirm.MaxLength = 10
    $confirm.FontSize = 16
    $confirm.Padding = '8,5'
    $confirm.Background = '#FFFFFF'
    $confirm.Foreground = '#111827'
    [void]$panel.Children.Add($confirmLabel)
    [void]$panel.Children.Add($confirm)

    $buttons = New-Object System.Windows.Controls.WrapPanel
    $buttons.HorizontalAlignment = 'Right'

    $cancel = New-Object System.Windows.Controls.Button
    $cancel.Content = 'Annuler'
    $cancel.Padding = '18,10'
    $cancel.Margin = '5'
    $cancel.FontSize = 14
    $cancel.MinWidth = 100

    $final = New-Object System.Windows.Controls.Button
    $final.Content = (FR 'FINALISER ET PR{Eacute}PARER OOBE')
    $final.Padding = '18,10'
    $final.Margin = '5'
    $final.FontSize = 14
    $final.MinWidth = 250
    $final.IsEnabled = $false

    $confirm.Add_TextChanged({ $final.IsEnabled = ($confirm.Text.Trim().ToUpperInvariant() -eq 'VENTE') })
    $cancel.Add_Click({ $win.Close() })
    $final.Add_Click({
        $mode = if ($clean.IsChecked -eq $true) { 'clean' } else { 'configured' }
        $label = if ($mode -eq 'clean') {
            (FR 'supprimer les applications tierces et les traces du technicien')
        } else {
            (FR 'conserver les applications et supprimer les traces du technicien')
        }
        $answer = [System.Windows.MessageBox]::Show((FR ("Confirmer : $label ?`n`nLe profil technicien sera supprim{eacute} et Windows d{eacute}marrera ensuite sur l''{eacute}cran Bienvenue/OOBE.")),'SENETECH - Confirmation finale',[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Warning)
        if ($answer -ne [System.Windows.MessageBoxResult]::Yes) { return }
        $win.Close()
        try {
            Set-ControlsEnabled $false
            Start-SenetechDeliveryFinalization -Mode $mode -EnableWelcome ($welcome.IsChecked -eq $true)
        } catch {
            Write-Log (FR ('Finalisation de la vente interrompue : {0}' -f $_.Exception.Message)) 'ERREUR'
            [System.Windows.MessageBox]::Show($_.Exception.Message,(FR 'SENETECH - Finalisation interrompue'),[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
            Set-ControlsEnabled $true
        }
    })

    [void]$buttons.Children.Add($cancel)
    [void]$buttons.Children.Add($final)
    [void]$panel.Children.Add($buttons)

    $scroll.Content = $panel
    $win.Content = $scroll
    if ($size.Compact) { Write-Log (FR 'Fen{ecirc}tre Livraison adapt{eacute}e au mode Compact.') 'OK' }
    [void]$win.ShowDialog()
}

function Add-SenetechDeliveryUi {
    if (-not $script:LeftPanel) { return }
    $group = New-Object System.Windows.Controls.GroupBox
    $group.Header = '7. Livraison / Vente'
    $group.Padding = '12'
    $group.Margin = '0,12,0,0'

    $panel = New-Object System.Windows.Controls.StackPanel
    $text = New-Object System.Windows.Controls.TextBlock
    $text.Text = (FR 'Nettoyage final, suppression du profil technicien, OOBE Windows et SENETECH Welcome pour le nouveau propri{eacute}taire.')
    $text.TextWrapping = 'Wrap'
    $text.Margin = '0,0,0,9'
    $text.Foreground = '#9FB4C8'

    $script:DeliveryButton = New-Object System.Windows.Controls.Button
    $script:DeliveryButton.Content = 'FINALISER POUR LA VENTE'
    $script:DeliveryButton.Padding = '12,9'
    $script:DeliveryButton.Margin = '0,0,0,4'
    $script:DeliveryButton.Add_Click({ Show-SenetechDeliveryWizard })

    [void]$panel.Children.Add($text)
    [void]$panel.Children.Add($script:DeliveryButton)
    $group.Content = $panel
    [void]$script:LeftPanel.Children.Add($group)
}
