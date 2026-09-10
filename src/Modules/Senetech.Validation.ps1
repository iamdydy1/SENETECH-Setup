# SENETECH V1.6 - preparation validation, application verification and cache integrity
# ASCII-only source. French accents are generated through FR() when available.

$script:SenetechValidationRoot = Join-Path $env:ProgramData 'SENETECH\Validation'
$script:SenetechBackupRoot = Join-Path $env:ProgramData 'SENETECH\Backups'
$script:PreparationBackupPath = $null
$script:LastValidation = $null

function Get-SenetechValidationText([string]$Text) {
    try {
        if (Get-Command FR -ErrorAction SilentlyContinue) { return (FR $Text) }
    } catch { }
    return $Text
}

function Get-SenetechFileSha256([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) { return '' }
    try {
        if (Get-Command Get-FileHash -ErrorAction SilentlyContinue) {
            return ([string](Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash).ToLowerInvariant()
        }
    } catch { }
    $stream = [IO.File]::OpenRead($Path)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
        finally { $sha.Dispose() }
    } finally { $stream.Dispose() }
}

function Test-SenetechAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Find-SenetechCachedInstallerRaw($App) {
    $folder = Get-AppCacheDirectory $App
    if (-not (Test-Path -LiteralPath $folder)) { return $null }
    return Get-ChildItem -LiteralPath $folder -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch '[\\/]_nouveau-' -and
            $_.FullName -notmatch '[\\/]_ancien-' -and
            $_.Extension.ToLowerInvariant() -in @('.msi','.exe','.msix','.msixbundle','.appx','.appxbundle')
        } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function Get-SenetechCacheMetadataPath($App) {
    return Join-Path (Get-AppCacheDirectory $App) 'SENETECH-Cache.json'
}

function Write-SenetechCacheMetadata($App, $Installer, [string]$Locale, [string]$Origin) {
    if ($null -eq $Installer -or -not (Test-Path -LiteralPath $Installer.FullName)) { return $false }
    $hash = Get-SenetechFileSha256 $Installer.FullName
    if ([string]::IsNullOrWhiteSpace($hash)) { return $false }
    $meta = [ordered]@{
        schemaVersion = 1
        appId = [string]$App.Id
        appName = [string]$App.Name
        fileName = [string]$Installer.Name
        length = [int64]$Installer.Length
        sha256 = $hash
        locale = $Locale
        origin = $Origin
        verifiedAt = (Get-Date).ToString('o')
    }
    $metaPath = Get-SenetechCacheMetadataPath $App
    $meta | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $metaPath -Encoding UTF8
    return (Test-Path -LiteralPath $metaPath)
}

function Test-SenetechCachedInstallerIntegrity($App, $Installer, [switch]$AllowLegacy) {
    if ($null -eq $Installer -or -not (Test-Path -LiteralPath $Installer.FullName)) { return $false }
    if ([int64]$Installer.Length -le 0) {
        Write-Log (Get-SenetechValidationText ('Cache invalide pour {0} : fichier vide.' -f $App.Name)) 'ATTENTION'
        return $false
    }

    $metaPath = Get-SenetechCacheMetadataPath $App
    if (-not (Test-Path -LiteralPath $metaPath)) {
        if (-not $AllowLegacy) { return $false }
        try {
            [void](Write-SenetechCacheMetadata $App $Installer (Get-CachedInstallerLocale $App) 'legacy-baseline')
            Write-Log (Get-SenetechValidationText ('Cache existant valid{eacute} pour {0} ; empreinte SHA-256 cr{eacute}{eacute}e.' -f $App.Name)) 'INFO'
            return $true
        } catch {
            Write-Log (Get-SenetechValidationText ('Cache existant utilisable pour {0}, mais son empreinte n''a pas pu {ecirc}tre enregistr{eacute}e.' -f $App.Name)) 'ATTENTION'
            return $true
        }
    }

    try {
        $meta = Get-Content -LiteralPath $metaPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ([string]$meta.fileName -ne [string]$Installer.Name) {
            Write-Log (Get-SenetechValidationText ('Cache invalide pour {0} : nom de fichier diff{eacute}rent de l''empreinte enregistr{eacute}e.' -f $App.Name)) 'ATTENTION'
            return $false
        }
        if ([int64]$meta.length -ne [int64]$Installer.Length) {
            Write-Log (Get-SenetechValidationText ('Cache invalide pour {0} : taille du fichier modifi{eacute}e.' -f $App.Name)) 'ATTENTION'
            return $false
        }
        $actualHash = Get-SenetechFileSha256 $Installer.FullName
        if ([string]::IsNullOrWhiteSpace($actualHash) -or $actualHash -ne ([string]$meta.sha256).ToLowerInvariant()) {
            Write-Log (Get-SenetechValidationText ('Cache invalide pour {0} : empreinte SHA-256 diff{eacute}rente.' -f $App.Name)) 'ERREUR'
            return $false
        }
        return $true
    } catch {
        Write-Log (Get-SenetechValidationText ('Impossible de v{eacute}rifier le cache de {0} : {1}' -f $App.Name,$_.Exception.Message)) 'ATTENTION'
        return $false
    }
}

# Override the legacy cache lookup. A cached installer is returned only when its
# recorded integrity is valid. Old caches receive a first local baseline hash.
function Get-CachedInstaller($App) {
    $installer = Find-SenetechCachedInstallerRaw $App
    if ($null -eq $installer) { return $null }
    if (Test-SenetechCachedInstallerIntegrity $App $installer -AllowLegacy) { return $installer }
    return $null
}

function Get-SenetechWingetForValidation([switch]$BootstrapIfMissing) {
    try {
        if (Get-Command Get-SenetechWingetCommand -ErrorAction SilentlyContinue) {
            if ($BootstrapIfMissing) { return (Get-SenetechWingetCommand -BootstrapIfMissing) }
            return (Get-SenetechWingetCommand)
        }
    } catch { }
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd }
    return $null
}

function Test-SenetechWingetInstalled($App, $Winget) {
    if ($null -eq $Winget -or [string]::IsNullOrWhiteSpace([string]$App.Id)) { return $false }
    $stdout = Join-Path $env:TEMP ('SENETECH-winget-list-' + [guid]::NewGuid().ToString('N') + '.txt')
    $stderr = Join-Path $env:TEMP ('SENETECH-winget-list-' + [guid]::NewGuid().ToString('N') + '.err')
    try {
        $args = @('list','--id',[string]$App.Id,'--exact','--accept-source-agreements','--disable-interactivity')
        $p = Start-Process -FilePath $Winget.Source -ArgumentList $args -PassThru -Wait -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $text = ''
        if (Test-Path -LiteralPath $stdout) { $text += [IO.File]::ReadAllText($stdout) }
        if (Test-Path -LiteralPath $stderr) { $text += "`n" + [IO.File]::ReadAllText($stderr) }
        return ($text -match [regex]::Escape([string]$App.Id))
    } catch { return $false }
    finally {
        Remove-Item -LiteralPath $stdout,$stderr -Force -ErrorAction SilentlyContinue
    }
}

function Get-SenetechAppInstalledState($App, [switch]$UseWingetFallback, $Winget = $null) {
    $version = '-'
    try { $version = Get-InstalledAppVersion ([string]$App.Registry) } catch { $version = '-' }
    if (-not [string]::IsNullOrWhiteSpace($version) -and $version -ne '-') {
        return [pscustomobject]@{ Installed=$true; Version=$version; Detection='Registre' }
    }

    if ($UseWingetFallback) {
        if ($null -eq $Winget) { $Winget = Get-SenetechWingetForValidation }
        if ($Winget -and (Test-SenetechWingetInstalled $App $Winget)) {
            return [pscustomobject]@{ Installed=$true; Version='Detectee par WinGet'; Detection='WinGet' }
        }
    }
    return [pscustomobject]@{ Installed=$false; Version='-'; Detection='Aucune' }
}

# Stronger offline download routine. The previous cache is kept until the new
# download has completed and received a SHA-256 fingerprint.
function Save-AppsForOffline($Apps) {
    $winget = Get-SenetechWingetForValidation -BootstrapIfMissing
    if (-not $winget) { throw (Get-SenetechValidationText 'WinGet est introuvable apr{egrave}s la tentative de r{eacute}paration automatique.') }
    if (-not (Test-Internet)) { throw (Get-SenetechValidationText 'Internet est n{eacute}cessaire pour pr{eacute}parer le cache hors ligne.') }
    if ($Apps.Count -eq 0) { throw (Get-SenetechValidationText 'S{eacute}lectionnez au moins une application {agrave} mettre en cache.') }

    $locale = Get-PreferredLocale
    Write-Log (Get-SenetechValidationText ('Langue pr{eacute}f{eacute}r{eacute}e des installateurs : {0}' -f $locale)) 'INFO'
    $index = 0
    foreach ($app in $Apps) {
        $index++
        $folder = Get-AppCacheDirectory $app
        New-Item -ItemType Directory -Force -Path $folder | Out-Null

        $oldInstaller = Find-SenetechCachedInstallerRaw $app
        if ($oldInstaller -and (Test-SenetechCachedInstallerIntegrity $app $oldInstaller -AllowLegacy)) {
            Write-Log (Get-SenetechValidationText ('Cache d{eacute}j{agrave} pr{eacute}sent et valid{eacute} pour {0}. Recherche d''une version actualis{eacute}e...' -f $app.Name)) 'INFO'
        }

        $staging = Join-Path $folder ('_nouveau-{0}-{1}' -f $script:SessionStamp,$index)
        New-Item -ItemType Directory -Force -Path $staging | Out-Null
        $downloadLocale = $locale
        $code = -1
        try {
            Write-Log (Get-SenetechValidationText ('T{eacute}l{eacute}chargement hors ligne de {0} ({1}/{2})...' -f $app.Name,$index,$Apps.Count)) 'INFO'
            $arguments = @('download','--id',$app.Id,'--exact','--architecture',(Get-AppArchitecture),'--locale',$locale,'--download-directory',('"' + $staging + '"'),'--skip-license','--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
            $code = Invoke-ProcessVisible -FilePath $winget.Source -Arguments $arguments
            if ($code -ne 0) {
                Write-Log (Get-SenetechValidationText ('Version {0} indisponible pour {1}, nouvel essai avec la langue par d{eacute}faut de l''{eacute}diteur.' -f $locale,$app.Name)) 'ATTENTION'
                $downloadLocale = 'Editeur / automatique'
                $arguments = @('download','--id',$app.Id,'--exact','--architecture',(Get-AppArchitecture),'--download-directory',('"' + $staging + '"'),'--skip-license','--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
                $code = Invoke-ProcessVisible -FilePath $winget.Source -Arguments $arguments
            }

            $newInstaller = Get-ChildItem -LiteralPath $staging -File -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension.ToLowerInvariant() -in @('.msi','.exe','.msix','.msixbundle','.appx','.appxbundle') } |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1

            if ($code -eq 0 -and $newInstaller -and [int64]$newInstaller.Length -gt 0) {
                $newHash = Get-SenetechFileSha256 $newInstaller.FullName
                if ([string]::IsNullOrWhiteSpace($newHash)) { throw 'SHA-256 du nouvel installateur impossible.' }

                $oldDir = Join-Path $folder ('_ancien-{0}-{1}' -f $script:SessionStamp,$index)
                New-Item -ItemType Directory -Force -Path $oldDir | Out-Null
                foreach ($item in @(Get-ChildItem -LiteralPath $folder -Force -ErrorAction SilentlyContinue)) {
                    if ($item.FullName -eq $staging -or $item.FullName -eq $oldDir) { continue }
                    Move-Item -LiteralPath $item.FullName -Destination $oldDir -Force
                }

                try {
                    Get-ChildItem -LiteralPath $staging -Force -ErrorAction Stop | Move-Item -Destination $folder -Force
                    Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
                    Set-Content -LiteralPath (Join-Path $folder 'SENETECH-Langue.txt') -Value $downloadLocale -Encoding UTF8
                    $promoted = Find-SenetechCachedInstallerRaw $app
                    if (-not $promoted) { throw 'Installateur absent apres promotion du cache.' }
                    if (-not (Write-SenetechCacheMetadata $app $promoted $downloadLocale 'winget-download')) { throw 'Metadonnees du cache impossibles a enregistrer.' }
                    if (-not (Test-SenetechCachedInstallerIntegrity $app $promoted)) { throw 'Verification finale du cache echouee.' }
                    Remove-Item -LiteralPath $oldDir -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Log (Get-SenetechValidationText ('Cache valid{eacute} : {0} | SHA-256 OK | ancien cache supprim{eacute} apr{egrave}s validation.' -f $promoted.Name)) 'OK'
                } catch {
                    Write-Log (Get-SenetechValidationText ('Validation du nouveau cache de {0} impossible : restauration de l''ancien cache.' -f $app.Name)) 'ERREUR'
                    Get-ChildItem -LiteralPath $folder -Force -ErrorAction SilentlyContinue |
                        Where-Object { $_.FullName -ne $oldDir } |
                        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                    if (Test-Path -LiteralPath $oldDir) {
                        Get-ChildItem -LiteralPath $oldDir -Force -ErrorAction SilentlyContinue | Move-Item -Destination $folder -Force
                        Remove-Item -LiteralPath $oldDir -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    throw
                }
            } elseif ($oldInstaller -and (Test-Path -LiteralPath $oldInstaller.FullName)) {
                Write-Log (Get-SenetechValidationText ('T{eacute}l{eacute}chargement impossible pour {0} ; l''ancien cache est conserv{eacute}.' -f $app.Name)) 'ATTENTION'
            } else {
                Write-Log (Get-SenetechValidationText ('Impossible de mettre {0} en cache (code {1}).' -f $app.Name,$code)) 'ATTENTION'
            }
        } finally {
            if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
    Update-OfflineStatus
}

# Stronger application installation routine: check before, install only when
# necessary, then verify the application is really present. Exit code 0 alone is
# no longer considered proof of a successful installation.
function Install-SelectedApps($Apps) {
    $online = Test-Internet
    $winget = $null
    if ($online) { $winget = Get-SenetechWingetForValidation -BootstrapIfMissing }
    $useWinget = ($online -and $null -ne $winget)

    if ($online -and -not $winget) {
        Write-Log (Get-SenetechValidationText 'WinGet reste indisponible : utilisation du cache USB valid{eacute} lorsqu''il existe.') 'ATTENTION'
    }

    $locale = Get-PreferredLocale
    Write-Log (Get-SenetechValidationText ('Langue Windows d{eacute}tect{eacute}e pour les applications : {0}' -f $locale)) 'INFO'
    $index = 0
    $results = @()

    foreach ($app in $Apps) {
        $index++
        $before = Get-SenetechAppInstalledState $app -UseWingetFallback:$useWinget -Winget $winget
        if ($before.Installed) {
            Write-Log (Get-SenetechValidationText ('{0} est d{eacute}j{agrave} install{eacute}. Aucun t{eacute}l{eacute}chargement inutile. Version : {1}' -f $app.Name,$before.Version)) 'OK'
            $results += [pscustomobject]@{ Name=$app.Name; Id=$app.Id; Status='OK'; Version=$before.Version; ExitCode='SKIP'; Source=('Deja installee / ' + $before.Detection); Locale='-' }
            continue
        }

        $source = if ($useWinget) { 'Internet / WinGet' } else { 'Cache USB' }
        $resultLocale = if ($useWinget) { $locale } else { Get-CachedInstallerLocale $app }
        Write-Log (Get-SenetechValidationText ('Installation de {0} ({1}/{2}) depuis {3}...' -f $app.Name,$index,$Apps.Count,$source)) 'INFO'
        $code = -1

        try {
            if ($useWinget) {
                $arguments = @('install','--id',$app.Id,'--exact','--silent','--locale',$locale,'--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
                $code = Invoke-ProcessVisible -FilePath $winget.Source -Arguments $arguments
                if ($code -ne 0) {
                    Write-Log (Get-SenetechValidationText ('Installation de {0} indisponible en {1}, nouvel essai avec la langue propos{eacute}e par l''{eacute}diteur.' -f $app.Name,$locale)) 'ATTENTION'
                    $resultLocale = 'Editeur / automatique'
                    $arguments = @('install','--id',$app.Id,'--exact','--silent','--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
                    $code = Invoke-ProcessVisible -FilePath $winget.Source -Arguments $arguments
                }
            } else {
                $installer = Get-CachedInstaller $app
                if ($null -eq $installer) {
                    Write-Log (Get-SenetechValidationText ('Aucun installateur hors ligne valid{eacute} pour {0}.' -f $app.Name)) 'ERREUR'
                    $results += [pscustomobject]@{ Name=$app.Name; Id=$app.Id; Status='ABSENT DU CACHE'; Version='-'; ExitCode='-'; Source=$source; Locale=$resultLocale }
                    continue
                }
                Write-Log (Get-SenetechValidationText ('Cache v{eacute}rifi{eacute} avant installation : {0}.' -f $installer.Name)) 'OK'
                $code = Invoke-OfflineInstaller $app $installer
            }
        } catch {
            Write-Log (Get-SenetechValidationText ('Erreur pendant l''installation de {0} : {1}' -f $app.Name,$_.Exception.Message)) 'ATTENTION'
        }

        Start-Sleep -Milliseconds 700
        $after = Get-SenetechAppInstalledState $app -UseWingetFallback:$useWinget -Winget $winget
        if ($after.Installed) {
            Write-Log (Get-SenetechValidationText ('V{eacute}rification OK : {0} est bien install{eacute}. Version : {1}' -f $app.Name,$after.Version)) 'OK'
            $results += [pscustomobject]@{ Name=$app.Name; Id=$app.Id; Status='OK'; Version=$after.Version; ExitCode=$code; Source=$source; Locale=$resultLocale }
        } else {
            Write-Log (Get-SenetechValidationText ('V{eacute}rification {eacute}chou{eacute}e : {0} n''est pas d{eacute}tect{eacute} apr{egrave}s l''installation (code {1}).' -f $app.Name,$code)) 'ERREUR'
            $results += [pscustomobject]@{ Name=$app.Name; Id=$app.Id; Status='ECHEC VERIFICATION'; Version='-'; ExitCode=$code; Source=$source; Locale=$resultLocale }
            $script:OperationNotes += (Get-SenetechValidationText ('Application non valid{eacute}e apr{egrave}s installation : {0}.' -f $app.Name))
        }
    }
    return @($results)
}

function Test-SenetechCatalogIntegrity {
    $failures = New-Object System.Collections.Generic.List[string]
    try {
        if ($null -eq $script:CatalogData -or $null -eq $script:ProfilesData) {
            [void]$failures.Add('Catalogue ou profils non charges.')
            return @($failures)
        }
        $keys = @{}
        $ids = @{}
        foreach ($app in @($script:CatalogData.apps)) {
            $key = [string]$app.key
            $id = [string]$app.id
            if ([string]::IsNullOrWhiteSpace($key) -or [string]::IsNullOrWhiteSpace($id) -or [string]::IsNullOrWhiteSpace([string]$app.name)) {
                [void]$failures.Add('Une application du catalogue est incomplete.')
                continue
            }
            if ($keys.ContainsKey($key.ToLowerInvariant())) { [void]$failures.Add(('Cle application dupliquee : ' + $key)) }
            else { $keys[$key.ToLowerInvariant()] = $true }
            if ($ids.ContainsKey($id.ToLowerInvariant())) { [void]$failures.Add(('ID WinGet duplique : ' + $id)) }
            else { $ids[$id.ToLowerInvariant()] = $true }
        }
        foreach ($profile in @($script:ProfilesData.profiles)) {
            foreach ($key in @($profile.apps)) {
                if (-not $keys.ContainsKey(([string]$key).ToLowerInvariant())) {
                    [void]$failures.Add(('Profil ' + [string]$profile.name + ' : application inconnue ' + [string]$key))
                }
            }
        }
    } catch {
        [void]$failures.Add(('Verification catalogue impossible : ' + $_.Exception.Message))
    }
    return @($failures)
}

function New-SenetechPreparationBackup {
    param([array]$SelectedApps)
    New-Item -ItemType Directory -Path $script:SenetechBackupRoot -Force | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $jsonPath = Join-Path $script:SenetechBackupRoot ('Preparation-' + $env:COMPUTERNAME + '-' + $stamp + '.json')

    $programs = @()
    try {
        if (Get-Command Get-SenetechInstalledPrograms -ErrorAction SilentlyContinue) {
            $programs = @(Get-SenetechInstalledPrograms | Select-Object Name,Version,Publisher,Scope)
        }
    } catch { }

    $startup = @()
    try { $startup = @(Get-SenetechStartupItems | Select-Object Type,Source,Path,Name,Command) } catch { }

    $drivers = @()
    try {
        $drivers = @(Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
            Where-Object { $_.DeviceName } |
            Select-Object DeviceName,Manufacturer,DriverProviderName,DriverVersion,DriverDate,IsSigned)
    } catch { }

    $snapshot = [ordered]@{
        schemaVersion = 1
        type = 'SENETECH preparation state backup'
        createdAt = (Get-Date).ToString('o')
        computer = $env:COMPUTERNAME
        user = $env:USERNAME
        senetechVersion = $script:AppVersion
        displayVersion = $script:DisplayVersion
        channel = $script:UpdateChannel
        selectedProfile = $script:CurrentProfileName
        selectedApps = @($SelectedApps | ForEach-Object { [ordered]@{ Name=$_.Name; Id=$_.Id; Registry=$_.Registry } })
        installedPrograms = $programs
        startupItems = $startup
        signedDrivers = $drivers
    }

    $snapshot | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
    if (-not (Test-Path -LiteralPath $jsonPath) -or (Get-Item -LiteralPath $jsonPath).Length -le 0) {
        throw (Get-SenetechValidationText 'La sauvegarde d''{eacute}tat SENETECH n''a pas pu {ecirc}tre cr{eacute}{eacute}e. La pr{eacute}paration est arr{ecirc}t{eacute}e avant modification.')
    }
    $hash = Get-SenetechFileSha256 $jsonPath
    if ([string]::IsNullOrWhiteSpace($hash)) { throw 'SHA-256 de la sauvegarde impossible.' }
    Set-Content -LiteralPath ($jsonPath + '.sha256') -Encoding ASCII -Value $hash

    $script:PreparationBackupPath = $jsonPath
    Write-Log (Get-SenetechValidationText ('Sauvegarde d''{eacute}tat cr{eacute}{eacute}e avant modification : {0}' -f $jsonPath)) 'OK'
    Add-SenetechHistory 'Sauvegarde etat preparation' 'OK' $jsonPath
    return $jsonPath
}

function Invoke-SenetechPreparationPreflight {
    param([array]$SelectedApps)
    $failures = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]

    if (-not (Test-SenetechAdministrator)) { [void]$failures.Add('SENETECH doit etre execute en administrateur.') }
    if ([string]::IsNullOrWhiteSpace($script:PreparationBackupPath) -or -not (Test-Path -LiteralPath $script:PreparationBackupPath)) {
        [void]$failures.Add('Sauvegarde d etat avant preparation absente.')
    }

    foreach ($failure in @(Test-SenetechCatalogIntegrity)) { [void]$failures.Add([string]$failure) }

    try {
        $drive = Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $env:SystemDrive) -ErrorAction Stop | Select-Object -First 1
        if ($drive) {
            $freeGb = [Math]::Round([double]$drive.FreeSpace / 1GB,1)
            if ($freeGb -lt 2) { [void]$failures.Add(('Espace disque insuffisant : ' + $freeGb + ' Go libres.')) }
            elseif ($freeGb -lt 8) { [void]$warnings.Add(('Espace disque faible : ' + $freeGb + ' Go libres.')) }
        }
    } catch { [void]$warnings.Add('Espace disque non verifie.') }

    $online = Test-Internet
    if ($AppsCheck.IsChecked -eq $true -and $SelectedApps.Count -gt 0) {
        $winget = $null
        if ($online) { $winget = Get-SenetechWingetForValidation -BootstrapIfMissing }
        if (-not $winget) {
            $missing = @()
            foreach ($app in $SelectedApps) { if ($null -eq (Get-CachedInstaller $app)) { $missing += $app.Name } }
            if ($missing.Count -gt 0) {
                [void]$failures.Add(('WinGet indisponible et cache absent pour : ' + ($missing -join ', ')))
            } else {
                [void]$warnings.Add('WinGet indisponible : toutes les applications selectionnees utiliseront le cache USB verifie.')
            }
        }
    }

    if (($UpdatesCheck.IsChecked -eq $true -or $DriversCheck.IsChecked -eq $true)) {
        $engine = Join-Path $script:EngineDir 'Moteur-WindowsUpdate.ps1'
        if (-not (Test-Path -LiteralPath $engine)) { [void]$failures.Add('Moteur Windows Update SENETECH absent.') }
        if (-not $online) {
            if ($UpdatesCheck.IsChecked -eq $true) { [void]$warnings.Add('Windows Update ne pourra pas etre execute sans Internet.') }
            if ($DriversCheck.IsChecked -eq $true) {
                $infCount = @(Get-ChildItem -LiteralPath $script:OfflineDriverDir -Filter '*.inf' -File -Recurse -ErrorAction SilentlyContinue).Count
                if ($infCount -eq 0) { [void]$warnings.Add('Aucun pilote hors ligne disponible sans Internet.') }
            }
        }
    }

    foreach ($w in $warnings) { Write-Log (Get-SenetechValidationText ('CHECK - Attention : {0}' -f $w)) 'ATTENTION' }
    foreach ($f in $failures) { Write-Log (Get-SenetechValidationText ('CHECK - Bloquant : {0}' -f $f)) 'ERREUR' }

    $passed = ($failures.Count -eq 0)
    if ($passed) { Write-Log (Get-SenetechValidationText ('CHECK initial valid{eacute} : sauvegarde, catalogue et pr{eacute}requis contr{ocirc}l{eacute}s.')) 'OK' }
    return [pscustomobject]@{ Passed=$passed; Failures=@($failures); Warnings=@($warnings); Online=$online }
}

function Invoke-SenetechPreparationValidation {
    param([array]$SelectedApps, [array]$AppResults, $Hardware)
    $failures = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]
    $checks = New-Object System.Collections.Generic.List[object]

    if (-not [string]::IsNullOrWhiteSpace($script:PreparationBackupPath) -and (Test-Path -LiteralPath $script:PreparationBackupPath)) {
        $hashPath = $script:PreparationBackupPath + '.sha256'
        if (Test-Path -LiteralPath $hashPath) {
            $expected = ([string](Get-Content -LiteralPath $hashPath -ErrorAction SilentlyContinue | Select-Object -First 1)).Trim().ToLowerInvariant()
            $actual = Get-SenetechFileSha256 $script:PreparationBackupPath
            if ($expected -and $actual -eq $expected) { [void]$checks.Add([pscustomobject]@{ Name='Sauvegarde etat'; Status='OK'; Details=$script:PreparationBackupPath }) }
            else { [void]$failures.Add('Empreinte de la sauvegarde d etat invalide.') }
        } else { [void]$failures.Add('Empreinte SHA-256 de la sauvegarde absente.') }
    } else { [void]$failures.Add('Sauvegarde d etat finale introuvable.') }

    $winget = Get-SenetechWingetForValidation
    if ($AppsCheck.IsChecked -eq $true) {
        foreach ($app in $SelectedApps) {
            $state = Get-SenetechAppInstalledState $app -UseWingetFallback:($null -ne $winget) -Winget $winget
            if ($state.Installed) {
                [void]$checks.Add([pscustomobject]@{ Name=[string]$app.Name; Status='OK'; Details=([string]$state.Version + ' / ' + [string]$state.Detection) })
            } else {
                [void]$failures.Add((Get-SenetechValidationText ('Application s{eacute}lectionn{eacute}e non d{eacute}tect{eacute}e : {0}' -f $app.Name)))
            }
        }
    }

    foreach ($result in @($AppResults)) {
        if ([string]$result.Status -notin @('OK','WINDOWS UPDATE')) {
            $text = ('{0} : {1}' -f [string]$result.Name,[string]$result.Status)
            if (-not $failures.Contains($text)) { [void]$failures.Add($text) }
        }
    }

    if ($Hardware) {
        try {
            if (@($Hardware.DeviceErrors).Count -gt 0) { [void]$warnings.Add(('Peripheriques Windows en erreur : ' + @($Hardware.DeviceErrors).Count)) }
        } catch { }
        try {
            $badDisks = @($Hardware.Disks | Where-Object { $_.Health -and $_.Health -notin @('Healthy','OK','Unknown','Non disponible') })
            if ($badDisks.Count -gt 0) { [void]$warnings.Add(('Stockage a controler : ' + $badDisks.Count + ' disque(s).')) }
        } catch { }
        try {
            if ($Hardware.Activation -and [string]$Hardware.Activation -ne 'Active') { [void]$warnings.Add('Activation Windows a verifier.') }
        } catch { }
    }

    if ($script:RebootRequired) { [void]$warnings.Add('Un redemarrage Windows est requis pour terminer certaines mises a jour.') }

    New-Item -ItemType Directory -Path $script:SenetechValidationRoot -Force | Out-Null
    $validationPath = Join-Path $script:SenetechValidationRoot ('Validation-' + $env:COMPUTERNAME + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
    $data = [ordered]@{
        createdAt = (Get-Date).ToString('o')
        senetechVersion = $script:AppVersion
        profile = $script:CurrentProfileName
        passed = ($failures.Count -eq 0)
        failures = @($failures)
        warnings = @($warnings)
        checks = @($checks)
        backup = $script:PreparationBackupPath
    }
    $data | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $validationPath -Encoding UTF8

    foreach ($f in $failures) { Write-Log (Get-SenetechValidationText ('CHECK FINAL - {Eacute}CHEC : {0}' -f $f)) 'ERREUR' }
    foreach ($w in $warnings) { Write-Log (Get-SenetechValidationText ('CHECK FINAL - Attention : {0}' -f $w)) 'ATTENTION' }
    if ($failures.Count -eq 0) {
        Write-Log (Get-SenetechValidationText ('CHECK FINAL VALID{Eacute} : applications, sauvegarde et {eacute}tat du PC contr{ocirc}l{eacute}s.')) 'OK'
    }

    Add-SenetechHistory 'Controle final preparation' $(if($failures.Count -eq 0){'OK'}else{'ERREUR'}) ("echecs=$($failures.Count) avertissements=$($warnings.Count)")
    return [pscustomobject]@{ Passed=($failures.Count -eq 0); Failures=@($failures); Warnings=@($warnings); Checks=@($checks); Path=$validationPath }
}
