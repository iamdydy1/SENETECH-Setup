# SENETECH V1.6.0.2 - startup manager encoding-safe override
# This file intentionally uses ASCII-only source text for Windows PowerShell 5.1 compatibility.

function Show-SenetechStartupManager {
    $items = @(Get-SenetechStartupItems)
    $win = New-Object System.Windows.Window
    $win.Title = 'SENETECH - Demarrage Windows'
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
    [System.Windows.Controls.DockPanel]::SetDock($footer, 'Bottom')

    $disableButton = New-Object System.Windows.Controls.Button
    $disableButton.Content = 'Desactiver la selection'
    $disableButton.Padding = '12,7'
    $disableButton.Margin = '4'

    $restoreButton = New-Object System.Windows.Controls.Button
    $restoreButton.Content = 'Restaurer les elements SENETECH'
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
        $cb.Content = ('{0} - {1}' -f $item.Name, $item.Source)
        $cb.ToolTip = $item.Command
        $cb.Tag = $item
        $cb.Margin = '4'
        $cb.Foreground = '#D5DFEC'
        [void]$list.Children.Add($cb)
    }

    if ($items.Count -eq 0) {
        $text = New-Object System.Windows.Controls.TextBlock
        $text.Text = 'Aucun element de demarrage classique detecte.'
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
            } catch {
                Write-Log $_.Exception.Message 'ATTENTION'
            }
        }
        if ($selected.Count -gt 0) {
            Write-Log ("{0} element(s) de demarrage desactive(s)." -f $selected.Count) 'OK'
        }
    })

    $restoreButton.Add_Click({
        Restore-SenetechStartupItems
        [System.Windows.MessageBox]::Show('Les elements desactives par SENETECH ont ete restaures.', 'SENETECH Setup') | Out-Null
    })

    $closeButton.Add_Click({ $win.Close() })
    [void]$win.ShowDialog()
}
