param(
    [int]$Software = 1,
    [int]$Drivers = 1,
    [int]$Optional = 0,
    [Parameter(Mandatory = $true)][string]$LogPath,
    [Parameter(Mandatory = $true)][string]$RebootMarker
)

$ErrorActionPreference = 'Stop'
$script:EngineHadFailure = $false
$script:EngineHadWarning = $false

function Add-EngineLog([string]$Message) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
}

function Test-SenetechUpdateResult([int]$Code,[string]$Phase) {
    # Microsoft Update Agent OperationResultCode:
    # 2 = Succeeded, 3 = SucceededWithErrors, 4 = Failed, 5 = Aborted.
    if ($Code -eq 3) {
        $script:EngineHadWarning = $true
        Add-EngineLog ("ATTENTION : $Phase terminee avec erreurs partielles (resultat $Code).")
    } elseif ($Code -in @(4,5)) {
        $script:EngineHadFailure = $true
        Add-EngineLog ("ERREUR : $Phase en echec ou annulee (resultat $Code).")
    } elseif ($Code -ne 2) {
        $script:EngineHadWarning = $true
        Add-EngineLog ("ATTENTION : resultat inattendu pour $Phase : $Code.")
    }
}

try {
    Add-EngineLog 'Demarrage du moteur Windows Update SENETECH V1.6.'
    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $types = @()
    if ($Software -eq 1) { $types += 'Software' }
    if ($Drivers -eq 1) { $types += 'Driver' }

    foreach ($type in $types) {
        Add-EngineLog "Recherche : $type"
        $result = $searcher.Search("IsInstalled=0 and IsHidden=0 and Type='$type'")
        $collection = New-Object -ComObject Microsoft.Update.UpdateColl

        foreach ($update in $result.Updates) {
            $isPreview = $update.Title -match '(?i)preview|apercu|facultative|optional'
            if ($isPreview -and $Optional -ne 1) {
                Add-EngineLog "Ignoree (facultative) : $($update.Title)"
                continue
            }
            if (-not $update.EulaAccepted) { $update.AcceptEula() }
            [void]$collection.Add($update)
            Add-EngineLog "Selection : $($update.Title)"
        }

        if ($collection.Count -eq 0) {
            Add-EngineLog "Aucune mise a jour $type applicable."
            continue
        }

        Add-EngineLog "Telechargement de $($collection.Count) mise(s) a jour."
        $downloader = $session.CreateUpdateDownloader()
        $downloader.Updates = $collection
        $downloadResult = $downloader.Download()
        Add-EngineLog "Telechargement termine, resultat $($downloadResult.ResultCode)."
        Test-SenetechUpdateResult ([int]$downloadResult.ResultCode) ("Telechargement $type")

        $ready = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($update in $collection) {
            if ($update.IsDownloaded) { [void]$ready.Add($update) }
        }

        if ($ready.Count -eq 0) {
            $script:EngineHadFailure = $true
            Add-EngineLog "ERREUR : aucune mise a jour $type n est disponible pour installation apres le telechargement."
            continue
        }

        if ($ready.Count -lt $collection.Count) {
            $script:EngineHadWarning = $true
            Add-EngineLog "ATTENTION : $($ready.Count)/$($collection.Count) mise(s) a jour $type seulement sont pretes a etre installees."
        }

        Add-EngineLog "Installation de $($ready.Count) mise(s) a jour."
        $installer = $session.CreateUpdateInstaller()
        $installer.Updates = $ready
        $installResult = $installer.Install()
        Add-EngineLog "Installation terminee, resultat $($installResult.ResultCode), redemarrage requis : $($installResult.RebootRequired)."
        Test-SenetechUpdateResult ([int]$installResult.ResultCode) ("Installation $type")

        if ($installResult.RebootRequired) {
            Set-Content -LiteralPath $RebootMarker -Value 'REBOOT_REQUIRED' -Encoding ASCII
        }
    }

    if ($script:EngineHadFailure) {
        Add-EngineLog 'Moteur Windows Update termine avec au moins un echec bloquant.'
        exit 2
    }
    if ($script:EngineHadWarning) {
        Add-EngineLog 'Moteur Windows Update termine avec avertissement(s), sans echec bloquant.'
    } else {
        Add-EngineLog 'Moteur Windows Update termine avec succes.'
    }
    exit 0
} catch {
    Add-EngineLog ("ERREUR : " + $_.Exception.Message)
    exit 1
}
