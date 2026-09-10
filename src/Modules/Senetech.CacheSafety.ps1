# SENETECH V1.6 - transactional offline cache replacement
# Loaded after Senetech.Validation.ps1. ASCII-only for Windows PowerShell 5.1.

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
        $oldValid = $false
        if ($oldInstaller) {
            $oldValid = Test-SenetechCachedInstallerIntegrity $app $oldInstaller -AllowLegacy
            if ($oldValid) {
                Write-Log (Get-SenetechValidationText ('Cache d{eacute}j{agrave} pr{eacute}sent et valid{eacute} pour {0}. L''ancien fichier restera intact jusqu''{agrave} la validation du nouveau.' -f $app.Name)) 'OK'
            }
        }

        $transactionRoot = Join-Path $folder ('_transaction-' + $script:SessionStamp + '-' + $index)
        $newRoot = Join-Path $transactionRoot 'new'
        $backupRoot = Join-Path $transactionRoot 'backup'
        New-Item -ItemType Directory -Force -Path $newRoot,$backupRoot | Out-Null

        $downloadLocale = $locale
        $code = -1
        try {
            Write-Log (Get-SenetechValidationText ('T{eacute}l{eacute}chargement hors ligne de {0} ({1}/{2})...' -f $app.Name,$index,$Apps.Count)) 'INFO'
            $args = @('download','--id',$app.Id,'--exact','--architecture',(Get-AppArchitecture),'--locale',$locale,'--download-directory',('"' + $newRoot + '"'),'--skip-license','--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
            $code = Invoke-ProcessVisible -FilePath $winget.Source -Arguments $args
            if ($code -ne 0) {
                Write-Log (Get-SenetechValidationText ('Version {0} indisponible pour {1}, nouvel essai avec la langue propos{eacute}e par l''{eacute}diteur.' -f $locale,$app.Name)) 'ATTENTION'
                $downloadLocale = 'Editeur / automatique'
                $args = @('download','--id',$app.Id,'--exact','--architecture',(Get-AppArchitecture),'--download-directory',('"' + $newRoot + '"'),'--skip-license','--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
                $code = Invoke-ProcessVisible -FilePath $winget.Source -Arguments $args
            }

            $newInstaller = Get-ChildItem -LiteralPath $newRoot -File -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension.ToLowerInvariant() -in @('.msi','.exe','.msix','.msixbundle','.appx','.appxbundle') } |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1

            if ($code -ne 0 -or -not $newInstaller -or [int64]$newInstaller.Length -le 0) {
                if ($oldValid) {
                    Write-Log (Get-SenetechValidationText ('Nouveau t{eacute}l{eacute}chargement non valid{eacute} pour {0}. L''ancien cache reste disponible.' -f $app.Name)) 'ATTENTION'
                    continue
                }
                throw (Get-SenetechValidationText ('Aucun installateur valide n''a {eacute}t{eacute} t{eacute}l{eacute}charg{eacute} pour {0} (code {1}).' -f $app.Name,$code))
            }

            $newHash = Get-SenetechFileSha256 $newInstaller.FullName
            if ([string]::IsNullOrWhiteSpace($newHash)) { throw 'SHA-256 du nouvel installateur impossible.' }

            # Copy the current cache to the transaction backup. Nothing in the
            # active cache is removed until this safety copy is complete.
            $activeItems = @(Get-ChildItem -LiteralPath $folder -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -ne $transactionRoot -and $_.Name -notlike '_transaction-*' })
            foreach ($item in $activeItems) {
                Copy-Item -LiteralPath $item.FullName -Destination $backupRoot -Recurse -Force -ErrorAction Stop
            }
            if ($oldValid) {
                $backupInstaller = Get-ChildItem -LiteralPath $backupRoot -File -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.Extension.ToLowerInvariant() -in @('.msi','.exe','.msix','.msixbundle','.appx','.appxbundle') } |
                    Select-Object -First 1
                if (-not $backupInstaller -or [int64]$backupInstaller.Length -le 0) {
                    throw (Get-SenetechValidationText 'La copie de sauvegarde de l''ancien cache est incompl{egrave}te. Remplacement annul{eacute}.')
                }
            }

            try {
                foreach ($item in $activeItems) { Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop }
                Get-ChildItem -LiteralPath $newRoot -Force -ErrorAction Stop | Copy-Item -Destination $folder -Recurse -Force -ErrorAction Stop
                Set-Content -LiteralPath (Join-Path $folder 'SENETECH-Langue.txt') -Value $downloadLocale -Encoding UTF8

                $promoted = Find-SenetechCachedInstallerRaw $app
                if (-not $promoted) { throw 'Installateur absent apres remplacement du cache.' }
                if (-not (Write-SenetechCacheMetadata $app $promoted $downloadLocale 'winget-download')) { throw 'Metadonnees du cache impossibles a enregistrer.' }
                if (-not (Test-SenetechCachedInstallerIntegrity $app $promoted)) { throw 'Verification SHA-256 finale du cache echouee.' }

                Write-Log (Get-SenetechValidationText ('Cache valid{eacute} : {0} | taille OK | SHA-256 OK.' -f $promoted.Name)) 'OK'
                Add-SenetechHistory 'Cache application valide' 'OK' ([string]$app.Name)
            } catch {
                Write-Log (Get-SenetechValidationText ('Remplacement du cache de {0} interrompu : restauration automatique de la sauvegarde.' -f $app.Name)) 'ERREUR'
                Get-ChildItem -LiteralPath $folder -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -ne $transactionRoot } |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                Get-ChildItem -LiteralPath $backupRoot -Force -ErrorAction SilentlyContinue |
                    Copy-Item -Destination $folder -Recurse -Force -ErrorAction SilentlyContinue
                if ($oldValid) {
                    $restored = Find-SenetechCachedInstallerRaw $app
                    if (-not $restored -or -not (Test-SenetechCachedInstallerIntegrity $app $restored -AllowLegacy)) {
                        throw (Get-SenetechValidationText ('Restauration de l''ancien cache de {0} non valid{eacute}e.' -f $app.Name))
                    }
                }
                throw
            }
        } catch {
            Write-Log (Get-SenetechValidationText ('Cache {0} : {1}' -f $app.Name,$_.Exception.Message)) 'ERREUR'
            if (-not $oldValid) { $script:OperationNotes += (Get-SenetechValidationText ('Cache non disponible pour {0}.' -f $app.Name)) }
        } finally {
            Remove-Item -LiteralPath $transactionRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Update-OfflineStatus
}

# Build 18 reporter is loaded as a late overlay instead of extending the nested
# patch chain. It wraps the final active workflows and initializes after Delivery.
$reporterBootstrap = Join-Path $script:EngineDir 'Modules\Senetech.ReporterBootstrap.ps1'
if (-not (Test-Path -LiteralPath $reporterBootstrap)) {
    throw 'Module SENETECH ReporterBootstrap V1.6.0.18 introuvable.'
}
. $reporterBootstrap
