# SENETECH Reporter - simplified user interface
# ASCII-only source for Windows PowerShell 5.1 compatibility.

function Get-SenetechReporterUiLabel {
    param([string]$Text)
    return $Text.Replace('__agrave__',[string]([char]0x00E0)).Replace('__eacute__',[string]([char]0x00E9))
}

function Add-SenetechReporterUi {
    if (-not $script:LeftPanel) { return }

    $group = New-Object System.Windows.Controls.GroupBox
    $group.Header = '8. Assistance SENETECH'
    $group.Padding = '12'
    $group.Margin = '0,12,0,0'

    $panel = New-Object System.Windows.Controls.StackPanel

    $script:ReporterStatusText = New-Object System.Windows.Controls.TextBlock
    $script:ReporterStatusText.TextWrapping = 'Wrap'
    $script:ReporterStatusText.Margin = '0,0,0,8'
    $script:ReporterStatusText.Foreground = '#9FB4C8'

    $buttons = New-Object System.Windows.Controls.WrapPanel

    $send = New-Object System.Windows.Controls.Button
    $send.Content = Get-SenetechReporterUiLabel 'Envoyer un rapport __agrave__ SENETECH'
    $send.Padding = '12,7'
    $send.Margin = '0,0,8,8'

    $choice = New-Object System.Windows.Controls.Button
    $choice.Padding = '12,7'
    $choice.Margin = '0,0,8,8'

    $updateStatus = {
        if ($script:ReporterEnabled) {
            $script:ReporterStatusText.Text = 'Envoi automatique : ACTIF | ID : ' + $script:ReporterInstallationId
            $choice.Content = Get-SenetechReporterUiLabel 'D__eacute__sactiver / modifier'
        } else {
            $script:ReporterStatusText.Text = 'Envoi automatique : DESACTIVE'
            $choice.Content = Get-SenetechReporterUiLabel 'Autoriser l''envoi'
        }
    }

    $send.Add_Click({
        if (-not $script:ReporterEnabled) {
            [void](Confirm-SenetechReporterConsent -ForcePrompt)
            & $updateStatus
            if (-not $script:ReporterEnabled) { return }
        }

        $ok = Send-SenetechReporterEvent -Severity 'SUCCESS' -Stage 'Rapport manuel' -Message 'Rapport manuel envoye depuis SENETECH Setup.'
        if ($ok) {
            [System.Windows.MessageBox]::Show(
                Get-SenetechReporterUiLabel 'Rapport envoy__eacute__ avec succ__eacute__s. Vous pouvez le retrouver dans le suivi SENETECH.',
                'SENETECH'
            ) | Out-Null
        } else {
            [System.Windows.MessageBox]::Show(
                Get-SenetechReporterUiLabel 'Envoi impossible pour le moment. Le rapport sera retent__eacute__ automatiquement.',
                'SENETECH'
            ) | Out-Null
        }
    })

    $choice.Add_Click({
        [void](Confirm-SenetechReporterConsent -ForcePrompt)
        & $updateStatus
    })

    [void]$buttons.Children.Add($send)
    [void]$buttons.Children.Add($choice)
    [void]$panel.Children.Add($script:ReporterStatusText)
    [void]$panel.Children.Add($buttons)

    $hint = New-Object System.Windows.Controls.TextBlock
    $hint.Text = Get-SenetechReporterUiLabel 'SENETECH peut envoyer automatiquement les erreurs, avertissements et succ__eacute__s importants lorsque l''envoi est autoris__eacute__.'
    $hint.TextWrapping = 'Wrap'
    $hint.Foreground = '#6FAFD1'
    $hint.Margin = '0,3,0,0'
    [void]$panel.Children.Add($hint)

    $group.Content = $panel
    [void]$script:LeftPanel.Children.Add($group)
    & $updateStatus
}
