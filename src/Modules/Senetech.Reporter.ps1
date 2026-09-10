# SENETECH V1.6 - remote technical reporter via Cloudflare Worker
# ASCII-only source for Windows PowerShell 5.1 compatibility.
# No Discord webhook is stored in SENETECH. The Worker owns the Discord secret.

$script:ReporterEndpoint = 'https://senetech-reporter.senexantwendy.workers.dev/report'
$script:ReporterHealthEndpoint = 'https://senetech-reporter.senexantwendy.workers.dev/health'
$script:ReporterRoot = Join-Path $env:ProgramData 'SENETECH\Reporter'
$script:ReporterConfigPath = Join-Path $script:ReporterRoot 'consent.json'
$script:ReporterQueuePath = Join-Path $script:ReporterRoot 'Queue'
$script:ReporterEnabled = $false
$script:ReporterInstallationId = $null
$script:ReporterLastSent = @{}
$script:ReporterInitialized = $false

function Get-SenetechReporterLocalized([string]$Text) {
    try {
        if (Get-Command FR -ErrorAction SilentlyContinue) { return (FR $Text) }
    } catch { }
    return $Text
}

function Protect-SenetechReporterText([AllowNull()][string]$Text, [int]$MaxLength = 1000) {
    if ($null -eq $Text) { return '' }
    $value = [string]$Text
    try {
        $profile = [Environment]::GetFolderPath('UserProfile')
        if (-not [string]::IsNullOrWhiteSpace($profile)) { $value = $value.Replace($profile,'[PROFILE]') }
    } catch { }
    try {
        $userName = [Environment]::UserName
        if (-not [string]::IsNullOrWhiteSpace($userName)) { $value = $value.Replace($userName,'[USER]') }
    } catch { }
    $value = [regex]::Replace($value,'(?i)https://(?:discord(?:app)?\.com)/api/webhooks/[^\s\"'']+','[REDACTED_WEBHOOK]')
    $value = [regex]::Replace($value,'(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b','[EMAIL]')
    $value = [regex]::Replace($value,'\b(?:\d{1,3}\.){3}\d{1,3}\b','[IP]')
    $value = $value.Replace('```','')
    if ($value.Length -gt $MaxLength) { $value = $value.Substring(0,$MaxLength) }
    return $value
}

function Initialize-SenetechReporterStorage {
    New-Item -ItemType Directory -Path $script:ReporterRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $script:ReporterQueuePath -Force | Out-Null

    $config = $null
    if (Test-Path -LiteralPath $script:ReporterConfigPath) {
        try { $config = Get-Content -LiteralPath $script:ReporterConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $config = $null }
    }

    if ($config -and $config.installationId) {
        $script:ReporterInstallationId = [string]$config.installationId
    } else {
        $script:ReporterInstallationId = 'SNTPC-' + ([guid]::NewGuid().ToString('N').Substring(0,10).ToUpperInvariant())
    }

    if ($config -and $null -ne $config.enabled) {
        $script:ReporterEnabled = [bool]$config.enabled
    } else {
        $script:ReporterEnabled = $false
    }
}

function Save-SenetechReporterConfig([bool]$Enabled) {
    New-Item -ItemType Directory -Path $script:ReporterRoot -Force | Out-Null
    if ([string]::IsNullOrWhiteSpace($script:ReporterInstallationId)) {
        $script:ReporterInstallationId = 'SNTPC-' + ([guid]::NewGuid().ToString('N').Substring(0,10).ToUpperInvariant())
    }
    $data = [ordered]@{
        schemaVersion = 1
        enabled = $Enabled
        installationId = $script:ReporterInstallationId
        updatedAt = (Get-Date).ToString('o')
        endpoint = $script:ReporterEndpoint
    }
    $data | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:ReporterConfigPath -Encoding UTF8
    $script:ReporterEnabled = $Enabled
}

function Confirm-SenetechReporterConsent([switch]$ForcePrompt) {
    Initialize-SenetechReporterStorage
    $hasChoice = $false
    if (Test-Path -LiteralPath $script:ReporterConfigPath) {
        try {
            $existing = Get-Content -LiteralPath $script:ReporterConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $hasChoice = ($null -ne $existing.enabled)
        } catch { }
    }
    if ($hasChoice -and -not $ForcePrompt) { return $script:ReporterEnabled }

    $message = Get-SenetechReporterLocalized @'
Autoriser SENETECH a envoyer des rapports techniques anonymises ?

Les rapports peuvent contenir :
- version de SENETECH et de Windows ;
- fabricant/modele du PC ;
- etape en cours et resultat (succes, avertissement ou erreur) ;
- extrait technique du journal en cas de probleme ;
- identifiant aleatoire de cette installation.

SENETECH n envoie pas le nom de la personne, son e-mail, ses fichiers personnels, son numero de serie, ses mots de passe ni le webhook Discord.

Vous pouvez modifier ce choix depuis la section Rapports techniques.
'@
    try {
        $answer = [System.Windows.MessageBox]::Show(
            $message,
            'SENETECH - Rapports techniques',
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Information
        )
        Save-SenetechReporterConfig ($answer -eq [System.Windows.MessageBoxResult]::Yes)
    } catch {
        Save-SenetechReporterConfig $false
    }
    return $script:ReporterEnabled
}

function Get-SenetechReporterMachineInfo {
    $manufacturer = 'PC'
    $model = 'Non disponible'
    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop | Select-Object -First 1
        if ($cs.Manufacturer) { $manufacturer = [string]$cs.Manufacturer }
        if ($cs.Model) { $model = [string]$cs.Model }
    } catch { }

    $windows = 'Windows'
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop | Select-Object -First 1
        if ($os) { $windows = ('{0} - build {1}' -f [string]$os.Caption,[string]$os.BuildNumber) }
    } catch { }

    return [pscustomobject]@{
        Model = Protect-SenetechReporterText (('{0} {1} | {2}' -f $manufacturer,$model,$script:ReporterInstallationId)) 220
        Windows = Protect-SenetechReporterText $windows 220
    }
}

function Get-SenetechReporterLogTail([int]$Lines = 12) {
    $file = $null
    try {
        if ($script:LogDir -and (Test-Path -LiteralPath $script:LogDir)) {
            $file = Get-ChildItem -LiteralPath $script:LogDir -File -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
        }
    } catch { }
    if (-not $file) { return '' }
    try {
        $tail = @(Get-Content -LiteralPath $file.FullName -Tail $Lines -ErrorAction Stop) -join "`n"
        return Protect-SenetechReporterText $tail 850
    } catch { return '' }
}

function New-SenetechReporterPayload {
    param(
        [Parameter(Mandatory=$true)][string]$Severity,
        [Parameter(Mandatory=$true)][string]$Stage,
        [string]$Message = '',
        [string]$ErrorCode = '',
        [string]$Log = '',
        [string]$IncidentId = ''
    )
    if ([string]::IsNullOrWhiteSpace($IncidentId)) {
        $IncidentId = 'SNT-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + ([guid]::NewGuid().ToString('N').Substring(0,4).ToUpperInvariant())
    }
    $machine = Get-SenetechReporterMachineInfo
    if ([string]::IsNullOrWhiteSpace($Log) -and $Severity.ToUpperInvariant() -eq 'ERROR') { $Log = Get-SenetechReporterLogTail }

    return [ordered]@{
        incidentId = $IncidentId
        severity = $Severity.ToUpperInvariant()
        version = [string]$script:DisplayVersion
        windows = $machine.Windows
        model = $machine.Model
        stage = Protect-SenetechReporterText $Stage 300
        errorCode = Protect-SenetechReporterText $ErrorCode 180
        error = Protect-SenetechReporterText $Message 1000
        log = Protect-SenetechReporterText $Log 850
    }
}

function Invoke-SenetechReporterPost($Payload) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $json = $Payload | ConvertTo-Json -Depth 7 -Compress
        $response = Invoke-WebRequest -UseBasicParsing -Uri $script:ReporterEndpoint -Method Post -ContentType 'application/json' -Body $json -TimeoutSec 5 -ErrorAction Stop
        if ([int]$response.StatusCode -lt 200 -or [int]$response.StatusCode -ge 300) { return $false }
        return $true
    } catch {
        return $false
    }
}

function Save-SenetechReporterQueued($Payload) {
    try {
        New-Item -ItemType Directory -Path $script:ReporterQueuePath -Force | Out-Null
        $name = (Get-Date -Format 'yyyyMMdd-HHmmssfff') + '-' + ([guid]::NewGuid().ToString('N').Substring(0,6)) + '.json'
        $path = Join-Path $script:ReporterQueuePath $name
        $Payload | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $path -Encoding UTF8
        $files = @(Get-ChildItem -LiteralPath $script:ReporterQueuePath -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
        if ($files.Count -gt 40) { $files | Select-Object -Skip 40 | Remove-Item -Force -ErrorAction SilentlyContinue }
    } catch { }
}

function Send-SenetechReporterEvent {
    param(
        [Parameter(Mandatory=$true)][ValidateSet('SUCCESS','INFO','WARNING','ERROR')][string]$Severity,
        [Parameter(Mandatory=$true)][string]$Stage,
        [string]$Message = '',
        [string]$ErrorCode = '',
        [string]$Log = '',
        [switch]$Force
    )
    if (-not $script:ReporterEnabled -and -not $Force) { return $false }

    # Prevent duplicate bursts from wrappers/catches reporting the same event.
    $key = ($Severity + '|' + $Stage + '|' + $Message)
    $now = Get-Date
    if ($script:ReporterLastSent.ContainsKey($key)) {
        $elapsed = ($now - [datetime]$script:ReporterLastSent[$key]).TotalSeconds
        if ($elapsed -lt 20) { return $true }
    }
    $script:ReporterLastSent[$key] = $now

    $payload = New-SenetechReporterPayload -Severity $Severity -Stage $Stage -Message $Message -ErrorCode $ErrorCode -Log $Log
    $sent = Invoke-SenetechReporterPost $payload
    if ($sent) {
        try { Write-Log ("REPORTER OK : {0} | {1}" -f $Severity,$Stage) 'OK' } catch { }
        return $true
    }

    if ($script:ReporterEnabled) { Save-SenetechReporterQueued $payload }
    try { Write-Log ("REPORTER en attente : {0} | {1}" -f $Severity,$Stage) 'ATTENTION' } catch { }
    return $false
}

function Flush-SenetechReporterQueue {
    if (-not $script:ReporterEnabled -or -not (Test-Path -LiteralPath $script:ReporterQueuePath)) { return }
    $items = @(Get-ChildItem -LiteralPath $script:ReporterQueuePath -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -First 5)
    foreach ($item in $items) {
        try {
            $payload = Get-Content -LiteralPath $item.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            if (Invoke-SenetechReporterPost $payload) { Remove-Item -LiteralPath $item.FullName -Force -ErrorAction SilentlyContinue }
            else { break }
        } catch { Remove-Item -LiteralPath $item.FullName -Force -ErrorAction SilentlyContinue }
    }
}

function Add-SenetechReporterUi {
    if (-not $script:LeftPanel) { return }
    $group = New-Object System.Windows.Controls.GroupBox
    $group.Header = '8. Rapports techniques'
    $group.Padding = '12'
    $group.Margin = '0,12,0,0'
    $panel = New-Object System.Windows.Controls.StackPanel

    $script:ReporterStatusText = New-Object System.Windows.Controls.TextBlock
    $script:ReporterStatusText.TextWrapping = 'Wrap'
    $script:ReporterStatusText.Margin = '0,0,0,8'
    $script:ReporterStatusText.Foreground = '#9FB4C8'

    $buttons = New-Object System.Windows.Controls.WrapPanel
    $test = New-Object System.Windows.Controls.Button
    $test.Content = Get-SenetechReporterLocalized 'Tester l envoi vers SENETECH'
    $test.Padding = '12,7'; $test.Margin = '0,0,8,8'
    $choice = New-Object System.Windows.Controls.Button
    $choice.Content = Get-SenetechReporterLocalized 'Modifier l autorisation'
    $choice.Padding = '12,7'; $choice.Margin = '0,0,8,8'

    $updateStatus = {
        if ($script:ReporterEnabled) {
            $script:ReporterStatusText.Text = Get-SenetechReporterLocalized ('Rapports anonymises : ACTIFS | ID : ' + $script:ReporterInstallationId)
        } else {
            $script:ReporterStatusText.Text = Get-SenetechReporterLocalized 'Rapports anonymises : DESACTIVES'
        }
    }

    $test.Add_Click({
        if (-not $script:ReporterEnabled) {
            [System.Windows.MessageBox]::Show((Get-SenetechReporterLocalized 'Activez d abord les rapports techniques.'),'SENETECH Reporter') | Out-Null
            return
        }
        $ok = Send-SenetechReporterEvent -Severity 'SUCCESS' -Stage 'Test Reporter' -Message 'Test manuel : liaison SENETECH vers Cloudflare puis Discord.'
        if ($ok) { [System.Windows.MessageBox]::Show('Rapport de test envoye. Verifiez Discord.','SENETECH Reporter') | Out-Null }
        else { [System.Windows.MessageBox]::Show('Envoi impossible pour le moment. Le rapport a ete place en attente.','SENETECH Reporter') | Out-Null }
    })
    $choice.Add_Click({ [void](Confirm-SenetechReporterConsent -ForcePrompt); & $updateStatus })

    [void]$buttons.Children.Add($test); [void]$buttons.Children.Add($choice)
    [void]$panel.Children.Add($script:ReporterStatusText); [void]$panel.Children.Add($buttons)
    $group.Content = $panel
    [void]$script:LeftPanel.Children.Add($group)
    & $updateStatus
}

function Register-SenetechReporterUnhandledException {
    try {
        if ($window -and $window.Dispatcher) {
            $window.Dispatcher.add_UnhandledException({
                param($sender,$eventArgs)
                try {
                    $ex = $eventArgs.Exception
                    [void](Send-SenetechReporterEvent -Severity 'ERROR' -Stage 'Exception WPF non geree' -Message ([string]$ex.Message) -ErrorCode ([string]$ex.HResult))
                } catch { }
            })
        }
    } catch { }
}

# Wrap selected major workflows. Reporter failures never block the original action.
if (Get-Command Install-SelectedApps -ErrorAction SilentlyContinue) {
    $script:ReporterOriginalInstallSelectedApps = ${function:Install-SelectedApps}
    function Install-SelectedApps($Apps) {
        try {
            $result = @(& $script:ReporterOriginalInstallSelectedApps $Apps)
            $bad = @($result | Where-Object { [string]$_.Status -notin @('OK','WINDOWS UPDATE') })
            $lines = @($result | ForEach-Object { '{0} : {1} ({2})' -f [string]$_.Name,[string]$_.Status,[string]$_.Version }) -join "`n"
            if ($bad.Count -gt 0) {
                [void](Send-SenetechReporterEvent -Severity 'ERROR' -Stage 'Installation applications' -Message ("{0} application(s) non validee(s) sur {1}." -f $bad.Count,$result.Count) -Log $lines)
            } else {
                [void](Send-SenetechReporterEvent -Severity 'SUCCESS' -Stage 'Installation applications' -Message ("{0} application(s) controlee(s) avec succes." -f $result.Count) -Log $lines)
            }
            return @($result)
        } catch {
            [void](Send-SenetechReporterEvent -Severity 'ERROR' -Stage 'Installation applications' -Message $_.Exception.Message -ErrorCode ([string]$_.Exception.HResult))
            throw
        }
    }
}

if (Get-Command Install-WindowsUpdates -ErrorAction SilentlyContinue) {
    $script:ReporterOriginalInstallWindowsUpdates = ${function:Install-WindowsUpdates}
    function Install-WindowsUpdates([bool]$IncludeSoftware,[bool]$IncludeDrivers) {
        try {
            $value = & $script:ReporterOriginalInstallWindowsUpdates $IncludeSoftware $IncludeDrivers
            [void](Send-SenetechReporterEvent -Severity 'SUCCESS' -Stage 'Windows Update' -Message ("Windows Update termine. Logiciels={0}, Pilotes={1}, Redemarrage={2}." -f $IncludeSoftware,$IncludeDrivers,$script:RebootRequired))
            return $value
        } catch {
            [void](Send-SenetechReporterEvent -Severity 'ERROR' -Stage 'Windows Update' -Message $_.Exception.Message -ErrorCode ([string]$_.Exception.HResult))
            throw
        }
    }
}

if (Get-Command Get-HardwareSnapshot -ErrorAction SilentlyContinue) {
    $script:ReporterOriginalHardwareSnapshot = ${function:Get-HardwareSnapshot}
    function Get-HardwareSnapshot {
        try {
            $value = & $script:ReporterOriginalHardwareSnapshot
            [void](Send-SenetechReporterEvent -Severity 'SUCCESS' -Stage 'Analyse du materiel' -Message 'Analyse materielle terminee sans erreur bloquante.')
            return $value
        } catch {
            [void](Send-SenetechReporterEvent -Severity 'ERROR' -Stage 'Analyse du materiel' -Message $_.Exception.Message -ErrorCode ([string]$_.Exception.HResult))
            throw
        }
    }
}

if (Get-Command Invoke-SenetechPreparationValidation -ErrorAction SilentlyContinue) {
    $script:ReporterOriginalPreparationValidation = ${function:Invoke-SenetechPreparationValidation}
    function Invoke-SenetechPreparationValidation {
        param([array]$SelectedApps,[array]$AppResults,$Hardware)
        try {
            $value = & $script:ReporterOriginalPreparationValidation -SelectedApps $SelectedApps -AppResults $AppResults -Hardware $Hardware
            $details = @()
            if ($value.Failures) { $details += @($value.Failures | ForEach-Object { 'ECHEC : ' + [string]$_ }) }
            if ($value.Warnings) { $details += @($value.Warnings | ForEach-Object { 'ATTENTION : ' + [string]$_ }) }
            $log = ($details -join "`n")
            if ($value.Passed) {
                [void](Send-SenetechReporterEvent -Severity 'SUCCESS' -Stage 'Controle final preparation' -Message ("Preparation validee avec {0} avertissement(s)." -f @($value.Warnings).Count) -Log $log)
            } else {
                [void](Send-SenetechReporterEvent -Severity 'ERROR' -Stage 'Controle final preparation' -Message ("Preparation non validee : {0} echec(s)." -f @($value.Failures).Count) -Log $log)
            }
            return $value
        } catch {
            [void](Send-SenetechReporterEvent -Severity 'ERROR' -Stage 'Controle final preparation' -Message $_.Exception.Message -ErrorCode ([string]$_.Exception.HResult))
            throw
        }
    }
}

if (Get-Command Start-SenetechDeliveryFinalization -ErrorAction SilentlyContinue) {
    $script:ReporterOriginalDeliveryFinalization = ${function:Start-SenetechDeliveryFinalization}
    function Start-SenetechDeliveryFinalization([string]$Mode,[bool]$EnableWelcome) {
        [void](Send-SenetechReporterEvent -Severity 'INFO' -Stage 'Livraison / Vente' -Message ("Finalisation demarree. Mode={0}, Welcome={1}." -f $Mode,$EnableWelcome))
        try {
            $value = & $script:ReporterOriginalDeliveryFinalization $Mode $EnableWelcome
            [void](Send-SenetechReporterEvent -Severity 'SUCCESS' -Stage 'Livraison / Vente' -Message 'Finalisation executee ; OOBE programme et extinction demandee.')
            return $value
        } catch {
            [void](Send-SenetechReporterEvent -Severity 'ERROR' -Stage 'Livraison / Vente' -Message $_.Exception.Message -ErrorCode ([string]$_.Exception.HResult))
            throw
        }
    }
}

function Initialize-SenetechReporter {
    if ($script:ReporterInitialized) { return }
    $script:ReporterInitialized = $true
    Initialize-SenetechReporterStorage
    [void](Confirm-SenetechReporterConsent)
    Add-SenetechReporterUi
    Register-SenetechReporterUnhandledException
    if ($script:ReporterEnabled) {
        Flush-SenetechReporterQueue
        [void](Send-SenetechReporterEvent -Severity 'SUCCESS' -Stage 'Demarrage SENETECH' -Message ('SENETECH demarre correctement : ' + [string]$script:DisplayVersion))
    }
    try { Write-Log ('SENETECH Reporter charge. Actif={0} ID={1}' -f $script:ReporterEnabled,$script:ReporterInstallationId) 'OK' } catch { }
}
