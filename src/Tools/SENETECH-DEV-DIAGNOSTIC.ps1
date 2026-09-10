param(
    [switch]$CollectOnly,
    [switch]$NoRemote
)

$ErrorActionPreference = 'Stop'
$script:StartedAt = Get-Date
$script:SessionId = 'DEV-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + ([guid]::NewGuid().ToString('N').Substring(0,6).ToUpperInvariant())
$script:Root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$script:EnginePath = Join-Path $script:Root '_SENETECH\SENETECH-Setup.ps1'
$script:LogRoot = Join-Path $env:ProgramData 'SENETECH\Logs\Developer'
$script:SessionRoot = Join-Path $script:LogRoot $script:SessionId
$script:TracePath = Join-Path $script:SessionRoot 'developer-trace.log'
$script:ErrorPath = Join-Path $script:SessionRoot 'errors.json'
$script:SystemPath = Join-Path $script:SessionRoot 'system.json'
$script:EventsPath = Join-Path $script:SessionRoot 'windows-events.txt'
$script:FilesPath = Join-Path $script:SessionRoot 'runtime-files.txt'
$script:BundlePath = Join-Path $script:LogRoot ($script:SessionId + '.zip')
$script:ReporterEndpoint = 'https://senetech-reporter.senexantwendy.workers.dev/report'
$script:ReporterConfig = Join-Path $env:ProgramData 'SENETECH\Reporter\consent.json'

function Write-DevTrace([string]$Level,[string]$Message) {
    try {
        New-Item -ItemType Directory -Path $script:SessionRoot -Force | Out-Null
        $line = '[{0}] [{1}] [{2}] {3}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'),$script:SessionId,$Level.ToUpperInvariant(),$Message
        Add-Content -LiteralPath $script:TracePath -Value $line -Encoding UTF8
    } catch { }
}

function Protect-DevText([AllowNull()][string]$Text,[int]$MaxLength=1000) {
    if ($null -eq $Text) { return '' }
    $v = [string]$Text
    try {
        $profile = [Environment]::GetFolderPath('UserProfile')
        if ($profile) { $v = $v.Replace($profile,'[PROFILE]') }
        $user = [Environment]::UserName
        if ($user) { $v = $v.Replace($user,'[USER]') }
    } catch { }
    $v = [regex]::Replace($v,'(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b','[EMAIL]')
    $v = [regex]::Replace($v,'\b(?:\d{1,3}\.){3}\d{1,3}\b','[IP]')
    $v = [regex]::Replace($v,'(?i)https://(?:discord(?:app)?\.com)/api/webhooks/[^\s"'']+','[REDACTED_WEBHOOK]')
    $v = $v.Replace('```','')
    if ($v.Length -gt $MaxLength) { $v = $v.Substring(0,$MaxLength) }
    return $v
}

function Get-ErrorDetail($Record) {
    if ($null -eq $Record) { return $null }
    $inv = $Record.InvocationInfo
    $ex = $Record.Exception
    $inner = ''
    try { if ($ex.InnerException) { $inner = [string]$ex.InnerException.Message } } catch { }
    return [ordered]@{
        time = (Get-Date).ToString('o')
        sessionId = $script:SessionId
        message = [string]$ex.Message
        exceptionType = if ($ex) { [string]$ex.GetType().FullName } else { '' }
        hresult = if ($ex) { [string]$ex.HResult } else { '' }
        innerException = $inner
        fullyQualifiedErrorId = [string]$Record.FullyQualifiedErrorId
        category = [string]$Record.CategoryInfo
        command = if ($inv -and $inv.MyCommand) { [string]$inv.MyCommand.Name } else { '' }
        scriptName = if ($inv) { [string]$inv.ScriptName } else { '' }
        scriptLineNumber = if ($inv) { [int]$inv.ScriptLineNumber } else { 0 }
        offsetInLine = if ($inv) { [int]$inv.OffsetInLine } else { 0 }
        line = if ($inv) { [string]$inv.Line } else { '' }
        positionMessage = if ($inv) { [string]$inv.PositionMessage } else { '' }
        scriptStackTrace = [string]$Record.ScriptStackTrace
    }
}

function Save-ErrorSnapshot {
    try {
        $records = @()
        foreach ($e in @($global:Error | Select-Object -First 50)) {
            $d = Get-ErrorDetail $e
            if ($d) { $records += [pscustomobject]$d }
        }
        $records | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $script:ErrorPath -Encoding UTF8
        Write-DevTrace 'INFO' ('Error snapshot saved: ' + $records.Count)
    } catch {
        Write-DevTrace 'WARNING' ('Unable to save Error snapshot: ' + $_.Exception.Message)
    }
}

function Save-SystemSnapshot {
    try {
        $os = $null; $cs = $null; $cpu = $null
        try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop | Select-Object -First 1 } catch { }
        try { $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop | Select-Object -First 1 } catch { }
        try { $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1 } catch { }
        $data = [ordered]@{
            sessionId = $script:SessionId
            startedAt = $script:StartedAt.ToString('o')
            powershell = $PSVersionTable.PSVersion.ToString()
            edition = [string]$PSVersionTable.PSEdition
            processArchitecture = [string][Environment]::Is64BitProcess
            osArchitecture = [string][Environment]::Is64BitOperatingSystem
            windows = if ($os) { [string]$os.Caption } else { '' }
            windowsBuild = if ($os) { [string]$os.BuildNumber } else { '' }
            manufacturer = if ($cs) { [string]$cs.Manufacturer } else { '' }
            model = if ($cs) { [string]$cs.Model } else { '' }
            cpu = if ($cpu) { [string]$cpu.Name } else { '' }
            workingDirectory = (Get-Location).Path
            installRoot = $script:Root
        }
        $data | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $script:SystemPath -Encoding UTF8
    } catch {
        Write-DevTrace 'WARNING' ('Unable to save system snapshot: ' + $_.Exception.Message)
    }
}

function Save-RuntimeInventory {
    try {
        $lines = New-Object System.Collections.Generic.List[string]
        foreach ($relative in @('VERSION.txt','SENETECH-Setup.exe','UPDATE-SENETECH.ps1','UPDATE-SENETECH-CHANNEL.ps1','_SENETECH\SENETECH-Setup.ps1','_SENETECH\SENETECH-Setup.manifest')) {
            $p = Join-Path $script:Root $relative
            if (Test-Path -LiteralPath $p) {
                $item = Get-Item -LiteralPath $p
                $hash = ''
                try { $hash = (Get-FileHash -LiteralPath $p -Algorithm SHA256 -ErrorAction Stop).Hash } catch { }
                $lines.Add(('{0} | {1} bytes | {2:O} | SHA256={3}' -f $relative,$item.Length,$item.LastWriteTime,$hash))
            } else {
                $lines.Add(($relative + ' | MISSING'))
            }
        }
        $modules = Join-Path $script:Root '_SENETECH\Modules'
        if (Test-Path -LiteralPath $modules) {
            foreach ($f in @(Get-ChildItem -LiteralPath $modules -Filter '*.ps1' -File | Sort-Object Name)) {
                $syntax = 'OK'
                try {
                    $tokens=$null; $errs=$null
                    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName,[ref]$tokens,[ref]$errs)
                    if ($errs -and $errs.Count -gt 0) { $syntax = 'ERROR: ' + $errs[0].Message }
                } catch { $syntax = 'ERROR: ' + $_.Exception.Message }
                $lines.Add(('MODULE {0} | {1} bytes | syntax={2}' -f $f.Name,$f.Length,$syntax))
            }
        }
        $lines | Set-Content -LiteralPath $script:FilesPath -Encoding UTF8
    } catch {
        Write-DevTrace 'WARNING' ('Unable to inventory runtime: ' + $_.Exception.Message)
    }
}

function Save-ExistingSenetechLogs {
    try {
        $sourceRoot = Join-Path $env:ProgramData 'SENETECH\Logs'
        $destRoot = Join-Path $script:SessionRoot 'existing-logs'
        New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
        if (-not (Test-Path -LiteralPath $sourceRoot)) { return }
        $files = @(Get-ChildItem -LiteralPath $sourceRoot -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notlike ($script:LogRoot + '*') } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 20)
        foreach ($f in $files) {
            try {
                if ($f.Length -gt 3MB) { continue }
                $dest = Join-Path $destRoot $f.Name
                $lines = @(Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue)
                $safe = foreach ($line in $lines) { Protect-DevText ([string]$line) 5000 }
                $safe | Set-Content -LiteralPath $dest -Encoding UTF8
            } catch { }
        }
        Write-DevTrace 'INFO' ('Existing SENETECH logs copied: ' + $files.Count)
    } catch {
        Write-DevTrace 'WARNING' ('Unable to copy existing SENETECH logs: ' + $_.Exception.Message)
    }
}

function Save-WindowsEvents {
    try {
        $from = $script:StartedAt.AddMinutes(-2)
        $events = @(Get-WinEvent -FilterHashtable @{LogName='Application';StartTime=$from} -ErrorAction SilentlyContinue |
            Where-Object {
                $_.ProviderName -in @('Application Error','.NET Runtime','Windows Error Reporting','PowerShell') -or
                ([string]$_.Message -match '(?i)SENETECH|powershell\.exe|SENETECH-Setup\.exe')
            } |
            Select-Object -First 80 TimeCreated,Id,LevelDisplayName,ProviderName,Message)
        $text = foreach ($e in $events) {
            '----'
            ('Time: ' + $e.TimeCreated)
            ('Provider: ' + $e.ProviderName)
            ('Id: ' + $e.Id)
            ('Level: ' + $e.LevelDisplayName)
            ('Message: ' + (Protect-DevText ([string]$e.Message) 5000))
        }
        $text | Set-Content -LiteralPath $script:EventsPath -Encoding UTF8
        Write-DevTrace 'INFO' ('Windows events saved: ' + $events.Count)
    } catch {
        Write-DevTrace 'WARNING' ('Unable to read Windows events: ' + $_.Exception.Message)
    }
}

function Ensure-ReporterConsent {
    if ($NoRemote) { return $false }
    try {
        if (Test-Path -LiteralPath $script:ReporterConfig) {
            $cfg = Get-Content -LiteralPath $script:ReporterConfig -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($null -ne $cfg.enabled) { return [bool]$cfg.enabled }
        }

        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        $answer = [System.Windows.MessageBox]::Show(
            "Activer l envoi des resumes techniques du mode Developer vers SENETECH ?`r`n`r`nLes bundles complets restent uniquement sur ce PC. Les resumes distants sont anonymises et servent au diagnostic des builds Developer.",
            'SENETECH - Diagnostic Developer',
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Information
        )
        $enabled = ($answer -eq [System.Windows.MessageBoxResult]::Yes)
        $dir = Split-Path -Parent $script:ReporterConfig
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $installationId = 'SNTPC-' + ([guid]::NewGuid().ToString('N').Substring(0,10).ToUpperInvariant())
        $data = [ordered]@{
            schemaVersion = 1
            enabled = $enabled
            installationId = $installationId
            updatedAt = (Get-Date).ToString('o')
            endpoint = $script:ReporterEndpoint
        }
        $data | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:ReporterConfig -Encoding UTF8
        return $enabled
    } catch {
        Write-DevTrace 'WARNING' ('Reporter consent unavailable: ' + $_.Exception.Message)
        return $false
    }
}

function Get-ReporterAllowed {
    if ($NoRemote) { return $false }
    try {
        if (-not (Test-Path -LiteralPath $script:ReporterConfig)) { return (Ensure-ReporterConsent) }
        $cfg = Get-Content -LiteralPath $script:ReporterConfig -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($null -eq $cfg.enabled) { return (Ensure-ReporterConsent) }
        return [bool]$cfg.enabled
    } catch { return $false }
}

function Send-DevReporter([string]$Severity,[string]$Stage,[string]$Message,[string]$Log='') {
    if (-not (Get-ReporterAllowed)) { return }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $version = ''
        try {
            $vf = Join-Path $script:Root 'VERSION.txt'
            if (Test-Path -LiteralPath $vf) { $version = ((Get-Content -LiteralPath $vf -TotalCount 4) -join ' ') }
        } catch { }
        $payload = [ordered]@{
            incidentId = 'SNT-' + $script:SessionId
            severity = $Severity.ToUpperInvariant()
            version = Protect-DevText $version 220
            windows = [Environment]::OSVersion.VersionString
            model = 'Developer diagnostic'
            stage = Protect-DevText $Stage 300
            errorCode = $script:SessionId
            error = Protect-DevText $Message 1000
            log = Protect-DevText $Log 850
        }
        $json = $payload | ConvertTo-Json -Depth 6 -Compress
        [void](Invoke-WebRequest -UseBasicParsing -Uri $script:ReporterEndpoint -Method Post -ContentType 'application/json' -Body $json -TimeoutSec 6 -ErrorAction Stop)
        Write-DevTrace 'INFO' ('Reporter sent: ' + $Stage)
    } catch {
        Write-DevTrace 'WARNING' ('Reporter send failed: ' + $_.Exception.Message)
    }
}

function Make-Bundle {
    try {
        if (Test-Path -LiteralPath $script:BundlePath) { Remove-Item -LiteralPath $script:BundlePath -Force -ErrorAction SilentlyContinue }
        if (Get-Command Compress-Archive -ErrorAction SilentlyContinue) {
            Compress-Archive -Path (Join-Path $script:SessionRoot '*') -DestinationPath $script:BundlePath -Force
        } else {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [IO.Compression.ZipFile]::CreateFromDirectory($script:SessionRoot,$script:BundlePath)
        }
        Write-DevTrace 'INFO' ('Bundle created: ' + $script:BundlePath)
    } catch {
        Write-DevTrace 'WARNING' ('Unable to create bundle: ' + $_.Exception.Message)
    }
}

New-Item -ItemType Directory -Path $script:SessionRoot -Force | Out-Null
Write-DevTrace 'INFO' 'SENETECH Developer diagnostic session started.'
Save-SystemSnapshot
Save-RuntimeInventory
Save-ExistingSenetechLogs
Send-DevReporter 'INFO' 'Developer diagnostic start' ('Session ' + $script:SessionId)

$failed = $false
$topError = $null
try { $global:Error.Clear() } catch { }

if (-not $CollectOnly) {
    if (-not (Test-Path -LiteralPath $script:EnginePath)) {
        $failed = $true
        Write-DevTrace 'ERROR' ('Engine missing: ' + $script:EnginePath)
    } else {
        try {
            Write-DevTrace 'INFO' ('Launching engine directly: ' + $script:EnginePath)
            Set-Location -LiteralPath $script:Root
            $oldPreference = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            & $script:EnginePath
            $ErrorActionPreference = $oldPreference
            Write-DevTrace 'INFO' 'Engine returned to diagnostic launcher.'
        } catch {
            $failed = $true
            $topError = $_
            $d = Get-ErrorDetail $_
            Write-DevTrace 'ERROR' ('TERMINATING ERROR: ' + ($d | ConvertTo-Json -Depth 5 -Compress))
        }
    }
}

Save-ErrorSnapshot
Save-WindowsEvents

if ($topError) {
    $d = Get-ErrorDetail $topError
    $detail = ($d | ConvertTo-Json -Depth 5 -Compress)
    Send-DevReporter 'ERROR' 'Developer terminating error' $d.message $detail
} elseif ($global:Error.Count -gt 0) {
    $first = Get-ErrorDetail $global:Error[0]
    if ($first) { Send-DevReporter 'WARNING' 'Developer PowerShell errors captured' $first.message ($first | ConvertTo-Json -Depth 5 -Compress) }
} else {
    Send-DevReporter 'SUCCESS' 'Developer diagnostic end' ('Session ' + $script:SessionId + ' completed without PowerShell error.')
}

Make-Bundle

Write-Host ''
Write-Host 'SENETECH Developer diagnostic termine.'
Write-Host ('Session : ' + $script:SessionId)
Write-Host ('Journal : ' + $script:TracePath)
Write-Host ('Bundle  : ' + $script:BundlePath)
Write-Host ''
if ($failed) { exit 1 }
exit 0
