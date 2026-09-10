param(
    [string]$CurrentVersion = '1.5.1.0',
    [string]$InstallDir = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [string]$UpdateChannel = 'stable',
    [int]$HostProcessId = 0,
    [switch]$Silent
)

$ErrorActionPreference = 'Stop'
$UpdateChannel = if ($UpdateChannel.ToLowerInvariant() -eq 'develop') { 'develop' } else { 'stable' }
$Branch = if ($UpdateChannel -eq 'develop') { 'develop' } else { 'main' }
$ManifestUrl = "https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/$Branch/version.json"
$UpdaterUrl = "https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/$Branch/UPDATE-SENETECH.ps1"

function Message([string]$Text,[string]$Title='SENETECH Setup',[bool]$Error=$false) {
    if ($Silent) { return }
    Add-Type -AssemblyName System.Windows.Forms
    $icon = if ($Error) { [System.Windows.Forms.MessageBoxIcon]::Error } else { [System.Windows.Forms.MessageBoxIcon]::Information }
    [System.Windows.Forms.MessageBox]::Show($Text,$Title,[System.Windows.Forms.MessageBoxButtons]::OK,$icon) | Out-Null
}

try {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
    $headers = @{ 'User-Agent' = "SENETECH-Setup/$CurrentVersion" }
    $m = Invoke-RestMethod -Uri $ManifestUrl -Headers $headers -UseBasicParsing
    if (-not $m.enabled) { Message 'Le service de mise a jour est temporairement desactive.'; exit 0 }
    $local = New-Object Version($CurrentVersion)
    $remote = New-Object Version([string]$m.version)
    if ($remote -le $local) { Message "SENETECH V$($m.displayVersion) est deja a jour.`r`nCanal : $UpdateChannel"; exit 0 }

    if (-not $Silent) {
        Add-Type -AssemblyName System.Windows.Forms
        $notes = if ($m.releaseNotes) { "`r`n`r`nNouveautes :`r`n- " + (@($m.releaseNotes) -join "`r`n- ") } else { '' }
        $text = "Une nouvelle version de SENETECH est disponible.`r`n`r`nVersion installee : $CurrentVersion`r`nNouvelle version : $($m.displayVersion)`r`nCanal : $UpdateChannel$notes`r`n`r`nVoulez-vous l'installer maintenant ?"
        $r = [System.Windows.Forms.MessageBox]::Show($text,'SENETECH - Mise a jour disponible',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Information)
        if ($r -ne [System.Windows.Forms.DialogResult]::Yes) { exit 2 }
    }

    $updater = Join-Path $env:TEMP 'SENETECH-UPDATE-SERVICE.ps1'
    Invoke-WebRequest -Uri $UpdaterUrl -Headers $headers -OutFile $updater -UseBasicParsing
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$updater+'"'),'-CurrentVersion',('"'+$CurrentVersion+'"'),'-InstallDir',('"'+$InstallDir+'"'),'-UpdateChannel',('"'+$UpdateChannel+'"'))
    if ($HostProcessId -gt 0) { $args += @('-WaitForProcessId',[string]$HostProcessId) }
    Start-Process powershell.exe -ArgumentList ($args -join ' ') -WindowStyle Hidden
    exit 10
}
catch {
    Message "Impossible de verifier les mises a jour SENETECH.`r`n`r`n$($_.Exception.Message)" 'SENETECH - Mise a jour' $true
    exit 1
}
