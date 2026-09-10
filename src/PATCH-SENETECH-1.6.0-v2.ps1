param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'
$enginePath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.ps1'
if (-not (Test-Path -LiteralPath $enginePath)) { throw "Moteur SENETECH introuvable : $enginePath" }

function Replace-Required([string]$Text, [string]$Old, [string]$New, [string]$Label) {
    # Here-strings may carry a final line break depending on the host. Removing only
    # trailing CR/LF makes the patch deterministic against the V1.5.1 source file.
    $oldValue = $Old.TrimEnd("`r","`n")
    $newValue = $New.TrimEnd("`r","`n")
    $index = $Text.IndexOf($oldValue, [System.StringComparison]::Ordinal)
    if ($index -lt 0) { throw "Patch V1.6 impossible, marqueur absent : $Label" }
    return $Text.Substring(0,$index) + $newValue + $Text.Substring($index + $oldValue.Length)
}

$s = Get-Content -LiteralPath $enginePath -Raw -Encoding UTF8
$s = Replace-Required $s '# SENETECH Setup V1.5.1 - Windows 10 and 11 preparation assistant' '# SENETECH Setup V1.6.0 DEV - Windows 10 and 11 preparation assistant' 'header'
$s = Replace-Required $s '$script:AppVersion = ''1.5.1.0''' '$script:AppVersion = ''1.6.0.0''' 'AppVersion'
$s = Replace-Required $s '$script:DisplayVersion = ''1.5.1''' '$script:DisplayVersion = ''1.6.0 DEV''' 'DisplayVersion'
$s = Replace-Required $s 'Title="SENETECH Setup V1.5.1"' 'Title="SENETECH Setup V1.6.0 DEV"' 'WindowTitle'
$s = Replace-Required $s 'VERSION 1.5.1" Foreground' 'VERSION 1.6.0 DEV" Foreground' 'HeaderVersion'
$s = Replace-Required $s 'SENETECH Setup V1.5.1 demarre' 'SENETECH Setup V1.6.0 DEV demarre' 'StartupLog'
$s = Replace-Required $s 'x:Name="StartButton" Content="COMMENCER"' 'x:Name="StartButton" Content="PR&#201;PARER CE PC"' 'PrepareButton'

$old = @'
<ScrollViewer Grid.Column="0" VerticalScrollBarVisibility="Auto" Margin="0,0,10,0">
        <StackPanel>
'@
$new = @'
<ScrollViewer Grid.Column="0" VerticalScrollBarVisibility="Auto" Margin="0,0,10,0">
        <StackPanel x:Name="LeftPanel">
'@
$s = Replace-Required $s $old $new 'LeftPanel'

$old = @'
</ComboBox>
              <WrapPanel>
'@
$new = @'
</ComboBox>
              <WrapPanel x:Name="AppsPanel">
'@
$s = Replace-Required $s $old $new 'AppsPanel'

$old = @'
$names = @('BrandLogo','StatusBadge','PcText','CpuText','RamText','GpuText','WindowsText','InternetText','ProfileCombo',
'@
$new = @'
$names = @('BrandLogo','StatusBadge','PcText','CpuText','RamText','GpuText','WindowsText','InternetText','ProfileCombo','LeftPanel','AppsPanel',
'@
$s = Replace-Required $s $old $new 'NamedControls'

$moduleBlock = @'
# SENETECH V1.6 - modules developpeur.
$catalogModule = Join-Path $script:EngineDir 'Modules\Senetech.Catalog.ps1'
$technicianModule = Join-Path $script:EngineDir 'Modules\Senetech.Technician.ps1'
if (-not (Test-Path -LiteralPath $catalogModule)) { throw 'Module catalogue SENETECH V1.6 introuvable.' }
if (-not (Test-Path -LiteralPath $technicianModule)) { throw 'Module technicien SENETECH V1.6 introuvable.' }
. $catalogModule
. $technicianModule
Initialize-SenetechV16Features

$SettingsButton.Add_Click({
'@
$s = Replace-Required $s '$SettingsButton.Add_Click({' $moduleBlock 'ModuleLoader'

$old = @'
    if ($DiagnosticCheck.IsChecked -eq $true) { $summary += 'Diagnostic et rapport' }
'@
$new = @'
    if ($DiagnosticCheck.IsChecked -eq $true) { $summary += 'Diagnostic et rapport' }
    if ($script:CreateRestoreCheck.IsChecked -eq $true) { $summary += 'Point de restauration Windows avant modifications' }
    if ($script:UpdateInstalledAppsCheck.IsChecked -eq $true) { $summary += 'Mise a jour des applications deja installees' }
    if ($script:ApplyTweaksCheck.IsChecked -eq $true) { $summary += ('Optimisations reversibles du profil ' + $script:CurrentProfileName) }
    if ($script:CleanupAfterCheck.IsChecked -eq $true) { $summary += 'Nettoyage des fichiers temporaires' }
'@
$s = Replace-Required $s $old $new 'SummaryV16'

$old = @'
        Set-Progress 3 'Preparation'
        if (-not $script:Hardware) {
'@
$new = @'
        Set-Progress 3 'Preparation'
        if ($script:CreateRestoreCheck.IsChecked -eq $true) {
            Set-Progress 6 'Point de restauration'
            [void](New-SenetechRestorePoint ('Avant preparation SENETECH ' + $script:DisplayVersion))
        }
        if (-not $script:Hardware) {
'@
$s = Replace-Required $s $old $new 'RestorePointWorkflow'

$old = @'
        if ($online -and ($UpdatesCheck.IsChecked -eq $true -or $DriversCheck.IsChecked -eq $true)) {
'@
$new = @'
        if ($online -and $script:UpdateInstalledAppsCheck.IsChecked -eq $true) {
            Set-Progress 45 'Mise a jour des applications installees'
            $script:AppResults += @(Invoke-SenetechAppUpdates)
        } elseif (-not $online -and $script:UpdateInstalledAppsCheck.IsChecked -eq $true) {
            $script:OperationNotes += 'Mise a jour des applications ignoree : Internet indisponible.'
        }
        if ($online -and ($UpdatesCheck.IsChecked -eq $true -or $DriversCheck.IsChecked -eq $true)) {
'@
$s = Replace-Required $s $old $new 'AppUpgradeWorkflow'

$old = @'
        Set-Progress 85 'Controle final'
        $script:Hardware = Get-HardwareSnapshot
'@
$new = @'
        if ($script:ApplyTweaksCheck.IsChecked -eq $true) {
            Set-Progress 80 'Optimisations du profil'
            Apply-SenetechProfileOptimizations $script:CurrentProfileName
        }
        if ($script:CleanupAfterCheck.IsChecked -eq $true) {
            Set-Progress 83 'Nettoyage Windows'
            [void](Invoke-SenetechCleanup)
        }
        Set-Progress 85 'Controle final'
        $script:Hardware = Get-HardwareSnapshot
'@
$s = Replace-Required $s $old $new 'FinalWorkflow'

$old = @'
        Write-Log 'Preparation SENETECH terminee. Verifiez le rapport et redemarrez manuellement le PC.' 'OK'
'@
$new = @'
        Write-Log 'Preparation SENETECH terminee. Verifiez le rapport et redemarrez manuellement le PC.' 'OK'
        Add-SenetechHistory 'Preparation PC terminee' 'OK' $script:CurrentProfileName
'@
$s = Replace-Required $s $old $new 'HistoryWorkflow'

$old = @'
    $designed = $null
    $full = $null
    try {
        $designed = @(Get-CimInstance -Namespace root/WMI -ClassName BatteryStaticData -ErrorAction Stop | Select-Object -First 1).DesignedCapacity
        $full = @(Get-CimInstance -Namespace root/WMI -ClassName BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1).FullChargedCapacity
    } catch { }
'@
$new = @'
    $designed = $null
    $full = $null
    $cycles = $null
    try {
        $designed = @(Get-CimInstance -Namespace root/WMI -ClassName BatteryStaticData -ErrorAction Stop | Select-Object -First 1).DesignedCapacity
        $full = @(Get-CimInstance -Namespace root/WMI -ClassName BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1).FullChargedCapacity
    } catch { }
    try {
        $cycles = @(Get-CimInstance -Namespace root/WMI -ClassName BatteryCycleCount -ErrorAction Stop | Select-Object -First 1).CycleCount
    } catch { }
'@
$s = Replace-Required $s $old $new 'BatteryCyclesRead'

$old = @'
        FullChargeCapacity = $full
        HealthPercent = $health
'@
$new = @'
        FullChargeCapacity = $full
        HealthPercent = $health
        CycleCount = $cycles
'@
$s = Replace-Required $s $old $new 'BatteryCyclesObject'

$old = @'
        DeviceErrors = $errors
    }
'@
$new = @'
        DeviceErrors = $errors
        Security = Get-SenetechSecuritySnapshot
    }
'@
$s = Replace-Required $s $old $new 'SecuritySnapshot'

$old = @'
        $healthText = if ($null -ne $info.Battery.HealthPercent) { " - sante estimee : $($info.Battery.HealthPercent)%" } else { '' }
        "Detectee - charge : $($info.Battery.Charge)%$healthText"
'@
$new = @'
        $healthText = if ($null -ne $info.Battery.HealthPercent) { " - sante estimee : $($info.Battery.HealthPercent)%" } else { '' }
        $cycleText = if ($null -ne $info.Battery.CycleCount) { " - cycles : $($info.Battery.CycleCount)" } else { '' }
        "Detectee - charge : $($info.Battery.Charge)%$healthText$cycleText"
'@
$s = Replace-Required $s $old $new 'BatteryCyclesReport'

$old = '<tr><th>Batterie</th><td>$(Convert-Html $batteryText)</td></tr></table>'
$new = @'
<tr><th>Batterie</th><td>$(Convert-Html $batteryText)</td></tr>
<tr><th>TPM</th><td>$(Convert-Html $info.Security.TPM)</td></tr><tr><th>Secure Boot</th><td>$(Convert-Html $info.Security.SecureBoot)</td></tr>
<tr><th>Disque systeme</th><td>$(Convert-Html $info.Security.SystemDrive)</td></tr><tr><th>Elements au demarrage</th><td>$($info.Security.StartupCount)</td></tr></table>
'@
$s = Replace-Required $s $old $new 'SecurityReport'

$old = @'
    $script:DiagnosticCheck.IsEnabled = $Enabled
    if (-not $script:IsInstalledMode) {
'@
$new = @'
    $script:DiagnosticCheck.IsEnabled = $Enabled
    foreach ($controlName in @('UpdateAppsButton','CleanupButton','StartupButton','RefreshCatalogButton','UndoTweaksButton','RollbackButton','CreateRestoreCheck','ApplyTweaksCheck','UpdateInstalledAppsCheck','CleanupAfterCheck','OptionalUpdatesCheck')) {
        $v = Get-Variable -Name $controlName -Scope Script -ErrorAction SilentlyContinue
        if ($v -and $null -ne $v.Value) { $v.Value.IsEnabled = $Enabled }
    }
    if (-not $script:IsInstalledMode) {
'@
$s = Replace-Required $s $old $new 'ControlsV16'

[IO.File]::WriteAllText($enginePath, $s, (New-Object Text.UTF8Encoding($true)))

$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
if (Test-Path -LiteralPath $manifestPath) {
    $m = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8
    $m = $m.Replace('version="1.5.1.0"','version="1.6.0.0"')
    [IO.File]::WriteAllText($manifestPath, $m, (New-Object Text.UTF8Encoding($false)))
}

Set-Content -LiteralPath (Join-Path $StageDir 'VERSION.txt') -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.0
Affichage : 1.6.0 DEV
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Mises a jour : GitHub + SHA-256 + rollback
'@
Set-Content -LiteralPath (Join-Path $StageDir 'LISEZ-MOI.txt') -Encoding UTF8 -Value @'
SENETECH Setup V1.6.0 DEV

Version de test du canal Developpeur. Ne pas distribuer aux clients avant validation.
'@
Set-Content -LiteralPath (Join-Path $StageDir 'CHANGELOG.txt') -Encoding UTF8 -Value @'
SENETECH Setup V1.6.0 DEV

Catalogue dynamique, nouveaux profils, mise a jour applications, restauration, optimisations reversibles, nettoyage, demarrage Windows, Windows Update avance, diagnostics enrichis, historique et rollback.
'@

Write-Output 'SENETECH V1.6.0 DEV patch applique.'
