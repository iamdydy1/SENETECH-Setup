# SENETECH V1.6 - WinGet bootstrap and resolution
# ASCII-only source for Windows PowerShell 5.1 compatibility.

$script:SenetechWingetBootstrapAttempted = $false

function Find-SenetechWingetCommand {
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and (Test-Path -LiteralPath $cmd.Source)) { return $cmd }

    $packages = @()
    try { $packages += @(Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue) } catch { }
    try { $packages += @(Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue) } catch { }

    foreach ($pkg in @($packages | Sort-Object Version -Descending)) {
        if (-not $pkg.InstallLocation) { continue }
        $candidate = Join-Path ([string]$pkg.InstallLocation) 'winget.exe'
        if (Test-Path -LiteralPath $candidate) {
            return [pscustomobject]@{ Source=$candidate; Name='winget.exe'; Version=[string]$pkg.Version }
        }
    }

    $aliasPath = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path -LiteralPath $aliasPath) {
        return [pscustomobject]@{ Source=$aliasPath; Name='winget.exe'; Version='' }
    }
    return $null
}

function Install-SenetechWinget {
    $existing = Find-SenetechWingetCommand
    if ($existing) { return $existing }

    if ($script:SenetechWingetBootstrapAttempted) { return $null }
    $script:SenetechWingetBootstrapAttempted = $true

    if (-not (Test-Internet 5000)) {
        Write-Log 'WinGet absent et Internet indisponible : installation automatique impossible.' 'ATTENTION'
        return $null
    }

    Write-Log 'WinGet absent : installation automatique de Windows Package Manager...' 'INFO'
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
        Write-Log 'Installation / reparation du package App Installer et WinGet...' 'INFO'
        Repair-WinGetPackageManager -AllUsers -Force -Latest -ErrorAction Stop | Out-Null
        Start-Sleep -Seconds 2

        $winget = Find-SenetechWingetCommand
        if (-not $winget) { throw 'WinGet reste introuvable apres la reparation officielle.' }

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
