param(
    [int]$Software = 1,
    [int]$Drivers = 1,
    [int]$Optional = 0,
    [Parameter(Mandatory = $true)][string]$LogPath,
    [Parameter(Mandatory = $true)][string]$RebootMarker
)

$ErrorActionPreference = 'Stop'
function Add-EngineLog([string]$Message) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
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
        if ($collection.Count -eq 0) { Add-EngineLog "Aucune mise a jour $type applicable."; continue }
        Add-EngineLog "Telechargement de $($collection.Count) mise(s) a jour."
        $downloader = $session.CreateUpdateDownloader(); $downloader.Updates = $collection
        $downloadResult = $downloader.Download(); Add-EngineLog "Telechargement termine, resultat $($downloadResult.ResultCode)."
        $ready = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($update in $collection) { if ($update.IsDownloaded) { [void]$ready.Add($update) } }
        if ($ready.Count -gt 0) {
            Add-EngineLog "Installation de $($ready.Count) mise(s) a jour."
            $installer = $session.CreateUpdateInstaller(); $installer.Updates = $ready
            $installResult = $installer.Install()
            Add-EngineLog "Installation terminee, resultat $($installResult.ResultCode), redemarrage requis : $($installResult.RebootRequired)."
            if ($installResult.RebootRequired) { Set-Content -LiteralPath $RebootMarker -Value 'REBOOT_REQUIRED' -Encoding ASCII }
        }
    }
    Add-EngineLog 'Moteur Windows Update termine.'
    exit 0
} catch {
    Add-EngineLog ("ERREUR : " + $_.Exception.Message)
    exit 1
}
