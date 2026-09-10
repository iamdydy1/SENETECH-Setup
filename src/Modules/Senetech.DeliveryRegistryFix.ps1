# SENETECH V1.6 - safe registry inventory for Delivery / Sale mode
# ASCII-only source for Windows PowerShell 5.1 compatibility.

function Get-SenetechRegistryPropertyValue {
    param(
        [Parameter(Mandatory=$true)]$Object,
        [Parameter(Mandatory=$true)][string]$Name,
        $Default = $null
    )
    if ($null -eq $Object) { return $Default }
    try {
        $property = $Object.PSObject.Properties[$Name]
        if ($null -ne $property) { return $property.Value }
    } catch { }
    return $Default
}

function Get-SenetechInstalledPrograms {
    $items = @()
    $locations = @(
        @{ Path='HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'; Scope='Machine64' },
        @{ Path='HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'; Scope='Machine32' },
        @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'; Scope='CurrentUser' }
    )

    foreach ($loc in $locations) {
        $entries = @()
        try { $entries = @(Get-ItemProperty -Path $loc.Path -ErrorAction SilentlyContinue) } catch { $entries = @() }

        foreach ($p in $entries) {
            $displayName = Get-SenetechRegistryPropertyValue -Object $p -Name 'DisplayName' -Default ''
            $name = [string]$displayName
            if ([string]::IsNullOrWhiteSpace($name)) { continue }

            $releaseType = [string](Get-SenetechRegistryPropertyValue -Object $p -Name 'ReleaseType' -Default '')
            if ($releaseType -match 'Update|Hotfix|Security Update') { continue }

            $windowsInstallerRaw = Get-SenetechRegistryPropertyValue -Object $p -Name 'WindowsInstaller' -Default 0
            $systemComponentRaw = Get-SenetechRegistryPropertyValue -Object $p -Name 'SystemComponent' -Default 0
            $noRemoveRaw = Get-SenetechRegistryPropertyValue -Object $p -Name 'NoRemove' -Default 0

            $windowsInstaller = 0
            $systemComponent = 0
            $noRemove = 0
            try { $windowsInstaller = [int]$windowsInstallerRaw } catch { }
            try { $systemComponent = [int]$systemComponentRaw } catch { }
            try { $noRemove = [int]$noRemoveRaw } catch { }

            $items += [pscustomobject]@{
                Name = $name.Trim()
                Version = [string](Get-SenetechRegistryPropertyValue -Object $p -Name 'DisplayVersion' -Default '')
                Publisher = [string](Get-SenetechRegistryPropertyValue -Object $p -Name 'Publisher' -Default '')
                UninstallString = [string](Get-SenetechRegistryPropertyValue -Object $p -Name 'UninstallString' -Default '')
                QuietUninstallString = [string](Get-SenetechRegistryPropertyValue -Object $p -Name 'QuietUninstallString' -Default '')
                WindowsInstaller = $windowsInstaller
                SystemComponent = $systemComponent
                NoRemove = $noRemove
                KeyName = [string](Get-SenetechRegistryPropertyValue -Object $p -Name 'PSChildName' -Default '')
                Scope = [string]$loc.Scope
            }
        }
    }

    # Do not let duplicate registry entries create duplicate removal attempts.
    $dedup = [ordered]@{}
    foreach ($item in $items) {
        $key = ('{0}|{1}|{2}' -f $item.Name,$item.Version,$item.Scope).ToLowerInvariant()
        if (-not $dedup.Contains($key)) { $dedup[$key] = $item }
    }

    Write-Log (('Inventaire registre Livraison : {0} application(s) valide(s).' -f $dedup.Count)) 'INFO'
    return @($dedup.Values | Sort-Object Name,Version,Scope)
}
