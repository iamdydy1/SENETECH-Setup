# SENETECH Reporter - simplified user interface
# ASCII-only source for Windows PowerShell 5.1 compatibility.

function Get-SenetechReporterUiLabel {
    param([string]$Text)
    return $Text.Replace('__agrave__',[string]([char]0x00E0)).Replace('__eacute__',[string]([char]0x00E9)).Replace('__egrave__',[string]([char]0x00E8)).Replace('__ecirc__',[string]([char]0x00EA)).Replace('__ocirc__',[string]([char]0x00F4)).Replace('__cced__',[string]([char]0x00E7))
}

function Confirm-SenetechReporterConsent([switch]$ForcePrompt) {
    Initialize-SenetechReporterStorage
    $hasChoice = $false
    if (Test-Path -LiteralPath $script:ReporterConfigPath) {
        try {
            $existing = Get-Content -LiteralPath $script:ReporterConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $hasChoice = ($null -ne $existing.enabled)
        } catch { }
    }
    if ($hasChoice -and -not $ForcePrompt) { return $script:ReporterEnabled }

    $message = Get-SenetechReporterUiLabel @'
Autoriser l'envoi automatique __agrave__ SENETECH ?

SENETECH peut envoyer uniquement des informations de fonctionnement : version SENETECH et Windows, fabricant/mod__egrave__le du PC, __eacute__tape en cours, r__eacute__sultat, message d'erreur et un court extrait du journal si n__eacute__cessaire.

Aucun nom, e-mail, fichier personnel, mot de passe, num__eacute__ro de s__eacute__rie ou webhook Discord n'est envoy__eacute__.

Vous pouvez d__eacute__sactiver l'envoi __agrave__ tout moment depuis Assistance SENETECH.
'@

    try {
        $answer = [System.Windows.MessageBox]::Show(
            $message,
            Get-SenetechReporterUiLabel 'SENETECH - Autorisation d''envoi',
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Information
        )
        Save-SenetechReporterConfig ($answer -eq [System.Windows.MessageBoxResult]::Yes)
    } catch {
        Save-SenetechReporterConfig $false
    }
    return $script:ReporterEnabled
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
            $script:ReporterStatusText.Text = Get-SenetechReporterUiLabel 'Envoi automatique : D__eacute__SACTIV__eacute__'
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
                Get-SenetechReporterUiLabel 'Rapport envoy__eacute__ avec succ__egrave__s. Vous pouvez le retrouver dans le suivi SENETECH.',
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
    $hint.Text = Get-SenetechReporterUiLabel 'Les erreurs, avertissements et succ__egrave__s importants peuvent __ecirc__tre envoy__eacute__s automatiquement lorsque l''envoi est autoris__eacute__.'
    $hint.TextWrapping = 'Wrap'
    $hint.Foreground = '#6FAFD1'
    $hint.Margin = '0,3,0,0'
    [void]$panel.Children.Add($hint)

    $group.Content = $panel
    [void]$script:LeftPanel.Children.Add($group)
    & $updateStatus
}
