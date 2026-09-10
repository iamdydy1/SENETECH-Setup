# SENETECH V1.6 - extended technician features
# Loaded by SENETECH-Setup.ps1 after the WPF controls and legacy functions exist.

$script:CatalogDir = Join-Path $script:EngineDir 'Catalog'
$script:AppsCatalogPath = Join-Path $script:CatalogDir 'apps.json'
$script:ProfilesCatalogPath = Join-Path $script:CatalogDir 'profiles.json'
$script:HistoryFile = Join-Path $script:LogDir 'SENETECH-History.jsonl'
$script:TweakSnapshotFile = Join-Path $script:Root 'SENETECH-Tweaks-Backup.json'
$script:StartupBackupFile = Join-Path $script:Root 'SENETECH-Startup-Backup.json'
$script:RollbackRoot = Join-Path $script:EngineDir 'Rollback\previous'
$script:CatalogData = $null
$script:ProfilesData = $null
$script:CurrentProfileName = 'Essentiel'

function Add-SenetechHistory([string]$Action, [string]$Status = 'OK', [string]$Details = '') {
    try {
        $entry = [ordered]@{
            timestamp = (Get-Date).ToString('o')
            version = $script:AppVersion
            channel = $script:UpdateChannel
            computer = $env:COMPUTERNAME
            action = $Action
            status = $Status
            details = $Details
        } | ConvertTo-Json -Compress
        Add-Content -LiteralPath $script:HistoryFile -Value $entry -Encoding UTF8
    } catch { }
}

function Get-SenetechCatalogUrl([string]$FileName) {
    return ('https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/{0}/catalog/{1}' -f $script:UpdateBranch, $FileName)
}

function Import-SenetechCatalogFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "Catalogue introuvable : $Path" }
    return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Update-SenetechCatalog([switch]$Silent) {
    if (-not (Test-Internet 3500)) {
        if (-not $Silent) { Write-Log 'Catalogue : hors ligne, utilisation de la copie locale.' 'ATTENTION' }
        return $false
    }
    New-Item -ItemType Directory -Force -Path $script:CatalogDir | Out-Null
    $downloads = @(
        @{ Name='apps.json'; Target=$script:AppsCatalogPath },
        @{ Name='profiles.json'; Target=$script:ProfilesCatalogPath }
    )
    $ok = $true
    foreach ($item in $downloads) {
        $tmp = $item.Target + '.new'
        try {
            Invoke-WebRequest -UseBasicParsing -Uri (Get-SenetechCatalogUrl $item.Name) -OutFile $tmp -Headers @{ 'User-Agent'=('SENETECH-Setup/{0}' -f $script:AppVersion) }
            $parsed = Import-SenetechCatalogFile $tmp
            if (-not $parsed.schemaVersion) { throw 'schemaVersion absent' }
            Move-Item -LiteralPath $tmp -Destination $item.Target -Force
        } catch {
            $ok = $false
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            Write-Log ("Catalogue {0} non actualise : {1}" -f $item.Name, $_.Exception.Message) 'ATTENTION'
        }
    }
    if ($ok) {
        Write-Log ('Catalogue SENETECH actualise depuis {0}.' -f $script:UpdateBranch) 'OK'
        Add-SenetechHistory 'Catalogue actualise' 'OK' $script:UpdateBranch
    }
    return $ok
}

function Resolve-SenetechAppId($AppDef) {
    if ((Get-AppArchitecture) -eq 'x86') {
        $x86Property = $AppDef.PSObject.Properties['idX86']
        if ($null -ne $x86Property -and $x86Property.Value) { return [string]$x86Property.Value }
    }
    return [string]$AppDef.id
}

function Initialize-SenetechDynamicCatalog([switch]$RefreshRemote) {
    if ($RefreshRemote) { [void](Update-SenetechCatalog -Silent) }
    $script:CatalogData = Import-SenetechCatalogFile $script:AppsCatalogPath
    $script:ProfilesData = Import-SenetechCatalogFile $script:ProfilesCatalogPath

    $script:AppsPanel.Children.Clear()
    $script:ProfileCombo.Items.Clear()
    $script:appMap = [ordered]@{}

    foreach ($def in @($script:CatalogData.apps)) {
        $check = New-Object System.Windows.Controls.CheckBox
        $check.Content = [string]$def.name
        $check.Margin = '0,4,18,4'
        $check.ToolTip = ('{0} | WinGet: {1}' -f [string]$def.category, (Resolve-SenetechAppId $def))
        [void]$script:AppsPanel.Children.Add($check)

        $silentArgs = @()
        $silentProperty = $def.PSObject.Properties['silentArgs']
        if ($null -ne $silentProperty -and $silentProperty.Value) { $silentArgs = @($silentProperty.Value | ForEach-Object { [string]$_ }) }
        $script:appMap[[string]$def.key] = @{
            Check = $check
            Id = (Resolve-SenetechAppId $def)
            Name = [string]$def.name
            Registry = [string]$def.registry
            Category = [string]$def.category
            SilentArgs = $silentArgs
        }
    }

    foreach ($profile in @($script:ProfilesData.profiles)) {
        $item = New-Object System.Windows.Controls.ComboBoxItem
        $item.Content = [string]$profile.name
        [void]$script:ProfileCombo.Items.Add($item)
    }
    if ($script:ProfileCombo.Items.Count -gt 0) { $script:ProfileCombo.SelectedIndex = 0 }
    Write-Log ("Catalogue charge : {0} applications, {1} profils." -f $script:appMap.Count, $script:ProfileCombo.Items.Count) 'OK'
}

function Get-SenetechProfileDefinition([string]$ProfileName) {
    return @($script:ProfilesData.profiles | Where-Object { [string]$_.name -eq $ProfileName } | Select-Object -First 1)[0]
}

function Set-Profile([string]$Profile) {
    foreach ($app in $script:appMap.Values) { $app.Check.IsChecked = $false }
    $script:CurrentProfileName = $Profile
    $profileDef = Get-SenetechProfileDefinition $Profile
    if ($null -eq $profileDef) { return }
    foreach ($key in @($profileDef.apps)) {
        if ($script:appMap.Contains([string]$key)) { $script:appMap[[string]$key].Check.IsChecked = $true }
    }
    $gpuProp = $profileDef.PSObject.Properties['gpuHelper']
    $script:GpuHelperCheck.IsChecked = ($null -ne $gpuProp -and [bool]$gpuProp.Value)
}

function Invoke-OfflineInstaller($app, $installer) {
    $extension = $installer.Extension.ToLowerInvariant()
    if ($extension -eq '.msi') {
        return Invoke-ProcessVisible -FilePath 'msiexec.exe' -Arguments @('/i',('"' + $installer.FullName + '"'),'/qn','/norestart')
    }
    if ($extension -in @('.msix','.msixbundle','.appx','.appxbundle')) {
        try { Add-AppxPackage -Path $installer.FullName -ForceApplicationShutdown; return 0 }
        catch { Write-Log $_.Exception.Message 'ATTENTION'; return 1 }
    }
    $args = @()
    $prop = $app.PSObject.Properties['SilentArgs']
    if ($null -ne $prop -and $prop.Value) { $args = @($prop.Value | ForEach-Object { [string]$_ }) }
    if ($args.Count -eq 0) { $args = @('/S') }
    return Invoke-ProcessVisible -FilePath $installer.FullName -Arguments $args
}

function Get-PreferredLocale {
    try {
        $name = [System.Globalization.CultureInfo]::CurrentUICulture.Name
        if ($name -match '^fr') { return 'fr-FR' }
        if ($name -match '^en') { return 'en-US' }
        if ($name -match '^es') { return 'es-ES' }
        if ($name) { return $name }
    } catch { }
    return 'fr-FR'
}
