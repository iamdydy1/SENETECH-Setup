# SENETECH V1.6 - safe delivery inventory preview
# ASCII-only source for Windows PowerShell 5.1 compatibility.

function Show-SenetechDeliveryInventory {
    try {
        Write-Log 'Ouverture de l apercu des applications avant livraison...' 'INFO'
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
        $inventoryWindow.Title = 'SENETECH - Applications detectees avant livraison'
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
        $header.Text = ('Applications detectees : {0}   |   A supprimer : {1}   |   Protegees : {2}' -f $rows.Count,$removeCount,$keepCount)
        $header.Margin = '16,14,16,8'
        $header.FontSize = 15
        $header.FontWeight = 'SemiBold'
        $header.Foreground = '#FFFFFF'
        $header.TextWrapping = 'Wrap'
        [System.Windows.Controls.DockPanel]::SetDock($header,'Top')
        [void]$root.Children.Add($header)

        $help = New-Object System.Windows.Controls.TextBlock
        $help.Text = 'CONSERVER = Windows, pilote, runtime ou composant protege. SUPPRIMER = application tierce retiree seulement en mode PC propre.'
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

        # A plain read-only TextBox is used instead of WPF DataGrid. DataGrid
        # auto-generation can terminate some Windows PowerShell 5.1/WPF hosts
        # when it reflects heterogeneous PSCustomObject values.
        $lines = New-Object System.Collections.Generic.List[string]
        foreach ($row in $rows) {
            $action = if ([bool]$row.Protected) { 'CONSERVER' } else { 'SUPPRIMER' }
            $name = [string]$row.Name
            $version = [string]$row.Version
            $publisher = [string]$row.Publisher
            $scope = [string]$row.Scope
            if ([string]::IsNullOrWhiteSpace($version)) { $version = '-' }
            if ([string]::IsNullOrWhiteSpace($publisher)) { $publisher = '-' }
            [void]$lines.Add(('[{0}] {1} | Version: {2} | Editeur: {3} | {4}' -f $action,$name,$version,$publisher,$scope))
        }
        if ($lines.Count -eq 0) { [void]$lines.Add('Aucune application classique detectee dans les cles de desinstallation Windows.') }

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
        Write-Log (('Apercu applications pret : {0} detectee(s), {1} a supprimer, {2} protegee(s).' -f $rows.Count,$removeCount,$keepCount)) 'OK'
        [void]$inventoryWindow.ShowDialog()
    } catch {
        $message = 'Impossible d ouvrir l apercu des applications : ' + $_.Exception.Message
        try { Write-Log $message 'ERREUR' } catch { }
        try {
            [System.Windows.MessageBox]::Show($message,'SENETECH - Apercu applications',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
        } catch { }
        return
    }
}
