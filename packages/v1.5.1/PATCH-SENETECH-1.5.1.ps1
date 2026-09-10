param(
    [Parameter(Mandatory=$true)]
    [string]$StageDir
)

$ErrorActionPreference = 'Stop'
$Utf8Bom = New-Object System.Text.UTF8Encoding -ArgumentList $true
$headers = @{ 'User-Agent' = 'SENETECH-Setup/1.5.1' }

function Replace-Required([string]$Text,[string]$Old,[string]$New,[string]$Name) {
    if (-not $Text.Contains($Old)) { throw ('Patch V1.5.1 : ancre introuvable : ' + $Name) }
    return $Text.Replace($Old,$New)
}
function Replace-BytePattern([byte[]]$Data,[byte[]]$Old,[byte[]]$New) {
    if ($Old.Length -ne $New.Length) { throw 'Binary replacement length mismatch.' }
    for ($i=0; $i -le ($Data.Length-$Old.Length); $i++) {
        $ok=$true
        for ($j=0; $j -lt $Old.Length; $j++) { if ($Data[$i+$j] -ne $Old[$j]) { $ok=$false; break } }
        if ($ok) { [Array]::Copy($New,0,$Data,$i,$New.Length); $i += $Old.Length-1 }
    }
}

# Repart de la V1.5.0 officielle afin que ce patch fonctionne aussi depuis V1.4.x.
$basePatchUrl = 'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/main/packages/v1.5.0/PATCH-SENETECH-1.5.0.ps1'
$basePatch = Join-Path $env:TEMP 'SENETECH-PATCH-1.5.0.ps1'
Invoke-WebRequest -Uri $basePatchUrl -Headers $headers -OutFile $basePatch -UseBasicParsing
$pa = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -StageDir "{1}"' -f $basePatch,$StageDir
$pp = Start-Process powershell.exe -ArgumentList $pa -WindowStyle Hidden -Wait -PassThru
Remove-Item $basePatch -Force -ErrorAction SilentlyContinue
if ($pp.ExitCode -ne 0) { throw ('Patch V1.5.0 prerequisite failed: ' + $pp.ExitCode) }

$enginePath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.ps1'
$text = [IO.File]::ReadAllText($enginePath)
$text = $text.Replace('# SENETECH Setup V1.5.0 - Windows 10 and 11 preparation assistant','# SENETECH Setup V1.5.1 - Windows 10 and 11 preparation assistant')
$text = $text.Replace("`$script:AppVersion = '1.5.0.0'","`$script:AppVersion = '1.5.1.0'")
$text = $text.Replace("`$script:DisplayVersion = '1.5.0'","`$script:DisplayVersion = '1.5.1'")

$old = @'
$script:UpdateManifestUrl = 'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/main/version.json'
$script:UpdaterUrl = 'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/main/UPDATE-SENETECH.ps1'
$script:InstalledRoot = Join-Path $env:ProgramFiles 'SENETECH'
'@
$new = @'
$script:SettingsFile = Join-Path $script:Root 'SENETECH-Settings.json'
$script:UpdateChannel = 'stable'
$script:UpdateBranch = 'main'
$script:UpdateManifestUrl = ''
$script:UpdaterUrl = ''

function Set-SenetechUpdateEndpoints([string]$Channel) {
    $normalized = if (([string]$Channel).ToLowerInvariant() -eq 'develop') { 'develop' } else { 'stable' }
    $branch = if ($normalized -eq 'develop') { 'develop' } else { 'main' }
    $script:UpdateChannel = $normalized
    $script:UpdateBranch = $branch
    $baseUrl = ('https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/{0}' -f $branch)
    $script:UpdateManifestUrl = $baseUrl + '/version.json'
    $script:UpdaterUrl = $baseUrl + '/UPDATE-SENETECH.ps1'
}

function Load-SenetechSettings {
    $channel = 'stable'
    try {
        if (Test-Path -LiteralPath $script:SettingsFile) {
            $settings = Get-Content -LiteralPath $script:SettingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($settings.updateChannel -and ([string]$settings.updateChannel).ToLowerInvariant() -eq 'develop') { $channel = 'develop' }
        }
    } catch { $channel = 'stable' }
    Set-SenetechUpdateEndpoints $channel
}

function Save-SenetechSettings([string]$Channel) {
    Set-SenetechUpdateEndpoints $Channel
    $data = [ordered]@{ product='SENETECH Setup'; updateChannel=$script:UpdateChannel; updatedAt=(Get-Date).ToString('o') } | ConvertTo-Json
    [System.IO.File]::WriteAllText($script:SettingsFile,$data,(New-Object System.Text.UTF8Encoding($true)))
}

Load-SenetechSettings
$script:InstalledRoot = Join-Path $env:ProgramFiles 'SENETECH'
'@
$text = Replace-Required $text $old.Trim() $new.Trim() 'update channels'

$text = $text.Replace("        updateChannel = 'github'","        updateChannel = 'stable'")
$old = @'
    [System.IO.File]::WriteAllText((Join-Path $destination $script:InstallMarkerName), $marker, (New-Object System.Text.UTF8Encoding($true)))

    Register-SenetechInstalledApp $destination
'@
$new = @'
    [System.IO.File]::WriteAllText((Join-Path $destination $script:InstallMarkerName), $marker, (New-Object System.Text.UTF8Encoding($true)))
    $installedSettings = [ordered]@{ product='SENETECH Setup'; updateChannel='stable'; updatedAt=(Get-Date).ToString('o') } | ConvertTo-Json
    [System.IO.File]::WriteAllText((Join-Path $destination 'SENETECH-Settings.json'), $installedSettings, (New-Object System.Text.UTF8Encoding($true)))

    Register-SenetechInstalledApp $destination
'@
$text = Replace-Required $text $old.Trim() $new.Trim() 'installed stable settings'

$text = $text.Replace('Title="SENETECH Setup V1.5.0"','Title="SENETECH Setup V1.5.1"')
$text = $text.Replace('VERSION 1.5.0" Foreground="#6FAFD1"','VERSION 1.5.1" Foreground="#6FAFD1"')

$old = @'
      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
      <TextBlock x:Name="FooterText" VerticalAlignment="Center" Foreground="#94A3B8" Text="Commencez par analyser le PC."/>
      <Button Grid.Column="1" x:Name="UpdateButton" Content="Mise &#224; jour" ToolTip="Rechercher une nouvelle version de SENETECH" Padding="16,10" Margin="6,0"/>
      <Button Grid.Column="2" x:Name="AnalyzeButton" Content="Analyser le PC" Padding="18,10" Margin="6,0"/>
      <Button Grid.Column="3" x:Name="ReportButton" Content="Ouvrir le rapport" Padding="18,10" Margin="6,0" IsEnabled="False"/>
      <Button Grid.Column="4" x:Name="RestartButton" Content="Red&#233;marrer" Padding="18,10" Margin="6,0" IsEnabled="False"/>
      <Button Grid.Column="5" x:Name="StartButton" Content="COMMENCER" Padding="26,11" Margin="6,0" Background="#0284C7" BorderBrush="#38BDF8" Foreground="White" FontWeight="Bold"/>
'@
$new = @'
      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
      <TextBlock x:Name="FooterText" VerticalAlignment="Center" Foreground="#94A3B8" Text="Commencez par analyser le PC."/>
      <Button Grid.Column="1" x:Name="SettingsButton" Content="Param&#232;tres" ToolTip="Canal de mise &#224; jour Stable ou D&#233;veloppeur" Padding="16,10" Margin="6,0"/>
      <Button Grid.Column="2" x:Name="UpdateButton" Content="Mise &#224; jour" ToolTip="Rechercher une nouvelle version de SENETECH" Padding="16,10" Margin="6,0"/>
      <Button Grid.Column="3" x:Name="AnalyzeButton" Content="Analyser le PC" Padding="18,10" Margin="6,0"/>
      <Button Grid.Column="4" x:Name="ReportButton" Content="Ouvrir le rapport" Padding="18,10" Margin="6,0" IsEnabled="False"/>
      <Button Grid.Column="5" x:Name="RestartButton" Content="Red&#233;marrer" Padding="18,10" Margin="6,0" IsEnabled="False"/>
      <Button Grid.Column="6" x:Name="StartButton" Content="COMMENCER" Padding="26,11" Margin="6,0" Background="#0284C7" BorderBrush="#38BDF8" Foreground="White" FontWeight="Bold"/>
'@
$text = Replace-Required $text $old.Trim() $new.Trim() 'settings footer'
$text = $text.Replace("'OfflineStatusText','LogBox','Progress','FooterText','UpdateButton','AnalyzeButton'","'OfflineStatusText','LogBox','Progress','FooterText','SettingsButton','UpdateButton','AnalyzeButton'")
$text = $text.Replace("function Update-DeploymentUi {`n    if (`$script:IsInstalledMode) {`n        `$script:ModeHeaderText.Text = 'MODE INSTALLE'","function Update-DeploymentUi {`n    `$channelLabel = if (`$script:UpdateChannel -eq 'develop') { 'DEVELOPPEUR' } else { 'STABLE' }`n    if (`$script:IsInstalledMode) {`n        `$script:ModeHeaderText.Text = ('MODE INSTALLE  •  {0}' -f `$channelLabel)")
$text = $text.Replace("        `$script:ModeHeaderText.Text = 'MODE PORTABLE'","        `$script:ModeHeaderText.Text = ('MODE PORTABLE  •  {0}' -f `$channelLabel)")

$anchor = 'function New-BrandBitmap([string]$Path) {'
$settings = @'
function Show-SenetechSettings {
    $settingsXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Paramètres SENETECH" Height="345" Width="520" ResizeMode="NoResize" WindowStartupLocation="CenterOwner" Background="#0B1320" Foreground="#E5EEF5">
  <Grid Margin="22"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
    <TextBlock Text="PARAMÈTRES DE MISE À JOUR" Foreground="#6FAFD1" FontSize="16" FontWeight="Bold"/>
    <TextBlock Grid.Row="1" Margin="0,8,0,16" Foreground="#94A3B8" TextWrapping="Wrap" Text="Choisissez le canal utilisé par cette copie de SENETECH. Le mode Portable / Installé ne change pas."/>
    <GroupBox Grid.Row="2" Header="Canal de mise à jour" Padding="12" BorderBrush="#334155"><StackPanel>
      <RadioButton x:Name="StableRadio" Content="Stable — Recommandé" FontWeight="SemiBold" Margin="0,5"/><TextBlock Margin="22,0,0,10" Foreground="#94A3B8" TextWrapping="Wrap" Text="Versions validées destinées aux clients et aux PC vendus."/>
      <RadioButton x:Name="DevelopRadio" Content="Développeur — Versions de test" FontWeight="SemiBold" Margin="0,5"/><TextBlock Margin="22,0,0,0" Foreground="#F0B35A" TextWrapping="Wrap" Text="Peut recevoir des fonctions non encore validées. À utiliser pour les tests SENETECH."/>
    </StackPanel></GroupBox>
    <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,18,0,0"><Button x:Name="CancelButton" Content="Annuler" Padding="18,8" Margin="0,0,8,0"/><Button x:Name="SaveButton" Content="Enregistrer" Padding="18,8" Background="#0284C7" Foreground="White"/></StackPanel>
  </Grid>
</Window>
'@
    [xml]$settingsXml = $settingsXaml
    $settingsReader = New-Object System.Xml.XmlNodeReader $settingsXml
    $settingsWindow = [Windows.Markup.XamlReader]::Load($settingsReader)
    $settingsWindow.Owner = $window
    $stableRadio=$settingsWindow.FindName('StableRadio'); $developRadio=$settingsWindow.FindName('DevelopRadio'); $saveButton=$settingsWindow.FindName('SaveButton'); $cancelButton=$settingsWindow.FindName('CancelButton')
    if ($script:UpdateChannel -eq 'develop') { $developRadio.IsChecked=$true } else { $stableRadio.IsChecked=$true }
    $script:SettingsSaved=$false
    $saveButton.Add_Click({ $selected=if($developRadio.IsChecked -eq $true){'develop'}else{'stable'}; Save-SenetechSettings $selected; $script:SettingsSaved=$true; $settingsWindow.DialogResult=$true; $settingsWindow.Close() })
    $cancelButton.Add_Click({ $settingsWindow.DialogResult=$false; $settingsWindow.Close() })
    [void]$settingsWindow.ShowDialog()
    if ($script:SettingsSaved) { Update-DeploymentUi; $label=if($script:UpdateChannel -eq 'develop'){'Développeur'}else{'Stable'}; Write-Log ('Canal de mise a jour selectionne : {0} ({1}).' -f $label,$script:UpdateBranch) 'UPDATE'; return $true }
    return $false
}

function New-BrandBitmap([string]$Path) {
'@
$text = Replace-Required $text $anchor $settings.TrimStart() 'settings dialog'
$text = $text.Replace("Write-Log ('Verification GitHub de SENETECH V{0}...' -f `$script:DisplayVersion) 'UPDATE'","Write-Log ('Verification GitHub de SENETECH V{0} | canal {1} ({2})...' -f `$script:DisplayVersion, `$script:UpdateChannel.ToUpperInvariant(), `$script:UpdateBranch) 'UPDATE'")
$text = $text.Replace("            '-InstallDir', ('\"' + `$script:Root + '\"'),`n            '-WaitForProcessId', [string]`$PID","            '-InstallDir', ('\"' + `$script:Root + '\"'),`n            '-UpdateChannel', ('\"' + `$script:UpdateChannel + '\"'),`n            '-WaitForProcessId', [string]`$PID")
$text = $text.Replace("    `$script:UpdateButton.IsEnabled = `$Enabled","    `$script:SettingsButton.IsEnabled = `$Enabled`n    `$script:UpdateButton.IsEnabled = `$Enabled")
$old = @'
$UpdateButton.Add_Click({
    Invoke-SenetechUpdateCheck
})
'@
$new = @'
$SettingsButton.Add_Click({
    try { if (Show-SenetechSettings) { Invoke-SenetechUpdateCheck -SilentWhenCurrent } }
    catch { Write-Log ('Erreur parametres SENETECH : {0}' -f $_.Exception.Message) 'ERREUR'; [System.Windows.MessageBox]::Show($_.Exception.Message,'SENETECH - Parametres') | Out-Null }
})

$UpdateButton.Add_Click({
    Invoke-SenetechUpdateCheck
})
'@
$text = Replace-Required $text $old.Trim() $new.Trim() 'settings handler'
$text = $text.Replace('Write-Log ("SENETECH Setup V1.5.0 demarre | Mode : {0} | Langue Windows : {1} | Architecture : {2}" -f $script:DeploymentMode, (Get-PreferredLocale), (Get-AppArchitecture))','Write-Log ("SENETECH Setup V1.5.1 demarre | Mode : {0} | Canal : {1} ({2}) | Langue Windows : {3} | Architecture : {4}" -f $script:DeploymentMode, $script:UpdateChannel.ToUpperInvariant(), $script:UpdateBranch, (Get-PreferredLocale), (Get-AppArchitecture))')

[IO.File]::WriteAllText($enginePath,$text,$Utf8Bom)

$manifestPath=Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
if(Test-Path $manifestPath){ $m=[IO.File]::ReadAllText($manifestPath).Replace('1.5.0.0','1.5.1.0'); [IO.File]::WriteAllText($manifestPath,$m,(New-Object Text.UTF8Encoding($false))) }
$version=@"
SENETECH Setup
Version 1.5.1.0
Canal par defaut : Stable (branche main)
Canal optionnel : Developpeur (branche develop)
Architecture : Windows 10 / 11
Mode : Portable + installation Windows integree
"@
[IO.File]::WriteAllText((Join-Path $StageDir 'VERSION.txt'),$version.TrimStart(),$Utf8Bom)
$exe=Join-Path $StageDir 'SENETECH-Setup.exe'
if(Test-Path $exe){ $bytes=[IO.File]::ReadAllBytes($exe); $a=[Text.Encoding]::ASCII; $u=[Text.Encoding]::Unicode; Replace-BytePattern $bytes ($a.GetBytes('1.5.0.0')) ($a.GetBytes('1.5.1.0')); Replace-BytePattern $bytes ($u.GetBytes('1.5.0.0')) ($u.GetBytes('1.5.1.0')); [IO.File]::WriteAllBytes($exe,$bytes) }
$verify=[IO.File]::ReadAllText($enginePath)
if($verify -notmatch "AppVersion = '1\.5\.1\.0'"){throw 'Verification V1.5.1 impossible.'}
if($verify -notmatch 'Show-SenetechSettings'){throw 'Parametres canal absents.'}
exit 0
