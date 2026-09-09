param(
    [Parameter(Mandatory=$false)]
    [string]$CurrentVersion = "1.4.2.0",

    [Parameter(Mandatory=$false)]
    [string]$InstallDir = (Split-Path -Parent $MyInvocation.MyCommand.Path),

    [Parameter(Mandatory=$false)]
    [int]$HostProcessId = 0,

    [Parameter(Mandatory=$false)]
    [switch]$Silent
)

$ErrorActionPreference = "Stop"
$ManifestUrl = "https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/main/version.json"
$UpdaterUrl = "https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/main/UPDATE-SENETECH.ps1"

function Show-Info([string]$Message, [string]$Title = "SENETECH Setup") {
    if ($Silent) { return }
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

function Show-ErrorBox([string]$Message) {
    if ($Silent) { return }
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        "SENETECH - Mise a jour",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

function Ask-Update([string]$RemoteVersion, [string[]]$Notes, [bool]$Mandatory) {
    if ($Silent) { return $false }

    Add-Type -AssemblyName System.Windows.Forms

    $notesText = ""
    if ($Notes -and $Notes.Count -gt 0) {
        $notesText = "`r`n`r`nNouveautes :`r`n- " + ($Notes -join "`r`n- ")
    }

    $prefix = "Une nouvelle version de SENETECH est disponible.`r`n`r`nVersion installee : $CurrentVersion`r`nNouvelle version : $RemoteVersion"
    if ($Mandatory) {
        $prefix += "`r`n`r`nCette mise a jour est marquee comme importante."
    }

    $message = $prefix + $notesText + "`r`n`r`nVoulez-vous l'installer maintenant ?"

    $result = [System.Windows.Forms.MessageBox]::Show(
        $message,
        "SENETECH - Mise a jour disponible",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )

    return ($result -eq [System.Windows.Forms.DialogResult]::Yes)
}

try {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    } catch {}

    $headers = @{ "User-Agent" = "SENETECH-Setup/$CurrentVersion" }
    $manifest = Invoke-RestMethod -Uri $ManifestUrl -Headers $headers -UseBasicParsing

    if (-not $manifest.enabled) {
        Show-Info "Le service de mise a jour SENETECH est configure, mais les mises a jour distantes ne sont pas encore activees."
        exit 0
    }

    $local = New-Object System.Version($CurrentVersion)
    $remote = New-Object System.Version([string]$manifest.version)

    if ($remote -le $local) {
        Show-Info "SENETECH V$($manifest.displayVersion) est deja a jour."
        exit 0
    }

    $notes = @()
    if ($manifest.releaseNotes) {
        $notes = @($manifest.releaseNotes | ForEach-Object { [string]$_ })
    }

    $accepted = Ask-Update -RemoteVersion ([string]$manifest.displayVersion) -Notes $notes -Mandatory ([bool]$manifest.mandatory)
    if (-not $accepted) {
        exit 2
    }

    $updaterPath = Join-Path $env:TEMP "SENETECH-UPDATE-SERVICE.ps1"
    Invoke-WebRequest -Uri $UpdaterUrl -Headers $headers -OutFile $updaterPath -UseBasicParsing

    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", ('"' + $updaterPath + '"'),
        "-CurrentVersion", ('"' + $CurrentVersion + '"'),
        "-InstallDir", ('"' + $InstallDir + '"')
    )

    if ($HostProcessId -gt 0) {
        $args += @("-WaitForProcessId", [string]$HostProcessId)
    }

    Start-Process -FilePath "powershell.exe" -ArgumentList ($args -join " ") -WindowStyle Hidden

    # Exit code 10 = la mise a jour a ete acceptee.
    # L'application hote doit alors se fermer pour permettre son remplacement.
    exit 10
}
catch {
    Show-ErrorBox "Impossible de verifier les mises a jour SENETECH.`r`n`r`n$($_.Exception.Message)"
    exit 1
}
