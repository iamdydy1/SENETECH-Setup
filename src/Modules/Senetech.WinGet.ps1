# SENETECH V1.6 - WinGet bootstrap and resolution
# ASCII-only source for Windows PowerShell 5.1 compatibility.

$script:SenetechWingetBootstrapAttempted = $false

function Get-SenetechAppInstallerPackages {
    $packages = @()
    try { $packages += @(Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue) } catch { }
    try { $packages += @(Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue) } catch { }
    return @($packages | Where-Object { $_ -and $_.InstallLocation } | Sort-Object Version -Descending -Unique)
}

function Find-SenetechWingetCommand {
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and (Test-Path -LiteralPath $cmd.Source)) {
        return [pscustomobject]@{ Source=[string]$cmd.Source; Name='winget.exe'; Version='' }
    }

    foreach ($pkg in @(Get-SenetechAppInstallerPackages)) {
        $candidate = Join-Path ([string]$pkg.InstallLocation) 'winget.exe'
        if (Test-Path -LiteralPath $candidate) {
            return [pscustomobject]@{ Source=$candidate; Name='winget.exe'; Version=[string]$pkg.Version }
        }
        try {
            $nested = Get-ChildItem -LiteralPath ([string]$pkg.InstallLocation) -Filter 'winget.exe' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($nested -and (Test-Path -LiteralPath $nested.FullName)) {
                return [pscustomobject]@{ Source=[string]$nested.FullName; Name='winget.exe'; Version=[string]$pkg.Version }
            }
        } catch { }
    }

    $aliasPath = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path -LiteralPath $aliasPath) {
        return [pscustomobject]@{ Source=$aliasPath; Name='winget.exe'; Version='' }
    }
    return $null
}

function Register-SenetechExistingAppInstaller {
    $packages = @(Get-SenetechAppInstallerPackages)
    if ($packages.Count -eq 0) { return $null }

    $pkg = $packages | Select-Object -First 1
    Write-Log ('App Installer deja present : version {0}. Recherche de WinGet dans {1}' -f $pkg.Version,$pkg.InstallLocation) 'INFO'

    $winget = Find-SenetechWingetCommand
    if ($winget) {
        Write-Log ('WinGet retrouve dans App Installer existant : {0}' -f $winget.Source) 'OK'
        return $winget
    }

    $manifest = Join-Path ([string]$pkg.InstallLocation) 'AppxManifest.xml'
    if (-not (Test-Path -LiteralPath $manifest)) {
        Write-Log 'App Installer est present mais son AppxManifest.xml est introuvable.' 'ATTENTION'
        return $null
    }

    try {
        Write-Log 'Reenregistrement du package App Installer deja installe pour le compte technicien...' 'INFO'
        Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ForceApplicationShutdown -ErrorAction Stop
        Start-Sleep -Seconds 2
        $winget = Find-SenetechWingetCommand
        if ($winget) {
            Write-Log ('WinGet reactive sans telecharger une version plus ancienne : {0}' -f $winget.Source) 'OK'
            Add-SenetechHistory 'Reenregistrement App Installer' 'OK' ([string]$pkg.Version)
            return $winget
        }
    } catch {
        Write-Log ('Reenregistrement App Installer non concluant : {0}' -f $_.Exception.Message) 'ATTENTION'
    }
    return $null
}

function Install-SenetechWinget {
    $existing = Find-SenetechWingetCommand
    if ($existing) { return $existing }

    $registered = Register-SenetechExistingAppInstaller
    if ($registered) { return $registered }

    if ($script:SenetechWingetBootstrapAttempted) { return $null }
    $script:SenetechWingetBootstrapAttempted = $true

    if (-not (Test-Internet 5000)) {
        Write-Log 'WinGet absent et Internet indisponible : installation automatique impossible.' 'ATTENTION'
        return $null
    }

    Write-Log 'WinGet reellement absent : installation/reparation de Windows Package Manager...' 'INFO'
    Set-Progress 18 'Installation de WinGet'
    Add-SenetechHistory 'Bootstrap WinGet' 'INFO' 'Debut'

    $oldProgress = $ProgressPreference
    $repo = $null
    $previousPolicy = $null
    try {
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }
        $ProgressPreference = 'SilentlyContinue'

        Import-Module PackageManagement -ErrorAction SilentlyContinue
        Import-Module PowerShellGet -ErrorAction SilentlyContinue

        $nuget = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
        if (-not $nuget -or ([version]$nuget.Version -lt [version]'2.8.5.201')) {
            Write-Log 'Installation du fournisseur NuGet requis par WinGet...' 'INFO'
            Install-PackageProvider -Name NuGet -MinimumVersion '2.8.5.201' -Force -Scope AllUsers -ErrorAction Stop | Out-Null
        }

        $repo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
        if ($repo) {
            $previousPolicy = [string]$repo.InstallationPolicy
            if ($previousPolicy -ne 'Trusted') {
                Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
            }
        }

        $clientModule = Get-Module -ListAvailable -Name Microsoft.WinGet.Client -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
        if (-not $clientModule) {
            Write-Log 'Installation du module officiel Microsoft.WinGet.Client...' 'INFO'
            Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -Scope AllUsers -AllowClobber -Confirm:$false -ErrorAction Stop
        }

        Import-Module Microsoft.WinGet.Client -Force -ErrorAction Stop
        Write-Log 'Reparation du package App Installer / WinGet...' 'INFO'
        try {
            Repair-WinGetPackageManager -AllUsers -Force -Latest -ErrorAction Stop | Out-Null
        } catch {
            Write-Log ('Reparation Microsoft retournee : {0}' -f $_.Exception.Message) 'ATTENTION'
            $reuse = Register-SenetechExistingAppInstaller
            if ($reuse) { return $reuse }
            throw
        }
        Start-Sleep -Seconds 2

        $winget = Find-SenetechWingetCommand
        if (-not $winget) { $winget = Register-SenetechExistingAppInstaller }
        if (-not $winget) { throw 'WinGet reste introuvable apres la reparation.' }

        Write-Log ('WinGet est maintenant disponible : {0}' -f $winget.Source) 'OK'
        Add-SenetechHistory 'Bootstrap WinGet' 'OK' $winget.Source
        return $winget
    } catch {
        Write-Log ('Installation automatique de WinGet impossible : {0}' -f $_.Exception.Message) 'ERREUR'
        Add-SenetechHistory 'Bootstrap WinGet' 'ERREUR' $_.Exception.Message
        return $null
    } finally {
        $ProgressPreference = $oldProgress
        if ($repo -and $previousPolicy -and $previousPolicy -ne 'Trusted') {
            try { Set-PSRepository -Name PSGallery -InstallationPolicy $previousPolicy -ErrorAction SilentlyContinue } catch { }
        }
    }
}

function Get-SenetechWingetCommand {
    param([switch]$BootstrapIfMissing)
    $winget = Find-SenetechWingetCommand
    if ($winget) { return $winget }
    if ($BootstrapIfMissing) { return Install-SenetechWinget }
    return $null
}

# Override the V1.6 app-upgrade function so a fresh Windows installation can
# bootstrap WinGet before trying to update catalog applications.
function Invoke-SenetechAppUpdates {
    if (-not (Test-Internet)) { throw 'Connexion Internet requise.' }
    $winget = Get-SenetechWingetCommand -BootstrapIfMissing
    if (-not $winget) { throw 'WinGet est introuvable apres la tentative d installation automatique.' }

    $installed = @()
    foreach ($app in $script:appMap.Values) {
        $version = Get-InstalledAppVersion $app.Registry
        if ($version -ne '-') { $installed += [pscustomobject]$app }
    }
    if ($installed.Count -eq 0) {
        Write-Log 'Aucune application du catalogue detectee pour mise a jour.'
        return @()
    }

    $results = @()
    $locale = Get-PreferredLocale
    $index = 0
    foreach ($app in $installed) {
        $index++
        Set-Progress ([Math]::Min(90, 10 + [int](80*$index/$installed.Count))) ("Mise a jour : {0}" -f $app.Name)
        if ([string]$app.Id -eq 'Mozilla.Firefox' -and (@(Get-Process -Name 'firefox' -ErrorAction SilentlyContinue).Count -gt 0)) {
            $version = Get-InstalledAppVersion $app.Registry
            $results += [pscustomobject]@{ Name=$app.Name; Id=$app.Id; Status='REPORTEE - FIREFOX OUVERT'; Version=$version; ExitCode='SKIP'; Source='Protection profil Firefox'; Locale=$locale }
            Write-Log 'Mozilla Firefox : mise a jour reportee car Firefox est ouvert. Fermez Firefox puis relancez la mise a jour des applications.' 'ATTENTION'
            continue
        }
        $args = @('upgrade','--id',$app.Id,'--exact','--source','winget','--silent','--accept-package-agreements','--accept-source-agreements','--disable-interactivity','--locale',$locale)
        $code = Invoke-ProcessVisible -FilePath $winget.Source -Arguments $args
        $version = Get-InstalledAppVersion $app.Registry
        $status = if ($code -eq 0) { 'OK' } else { 'A JOUR / NON APPLICABLE' }
        $results += [pscustomobject]@{ Name=$app.Name; Id=$app.Id; Status=$status; Version=$version; ExitCode=$code; Source='WinGet upgrade'; Locale=$locale }
        Write-Log ("{0} : {1} (code {2})" -f $app.Name, $status, $code) $(if($code -eq 0){'OK'}else{'INFO'})
    }
    Add-SenetechHistory 'Mise a jour applications' 'OK' ("{0} application(s) controlee(s)" -f $installed.Count)
    return @($results)
}
