param()

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

$reportEndpoint = 'https://senetech-reporter.senexantwendy.workers.dev/report'
$healthEndpoint = 'https://senetech-reporter.senexantwendy.workers.dev/health'
$configPath = Join-Path $env:ProgramData 'SENETECH\Reporter\consent.json'
$logDir = Join-Path $env:ProgramData 'SENETECH\Logs\Developer'
$logPath = Join-Path $logDir 'SENETECH-Reporter-Test.log'

function Write-TestLog([string]$Level,[string]$Message) {
    try {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        Add-Content -LiteralPath $logPath -Encoding UTF8 -Value ('[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'),$Level,$Message)
    } catch { }
}

function Get-OrCreateConsent {
    $existing = $null
    if (Test-Path -LiteralPath $configPath) {
        try { $existing = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { }
    }

    if ($existing -and $null -ne $existing.enabled -and [bool]$existing.enabled) {
        return $existing
    }

    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    $answer = [System.Windows.MessageBox]::Show(
        "Autoriser SENETECH Developer a envoyer des resumes techniques anonymises vers votre Reporter Cloudflare puis Discord ?`r`n`r`nLes fichiers complets de diagnostic restent sur ce PC.",
        'SENETECH - Reporter Developer',
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Information
    )
    if ($answer -ne [System.Windows.MessageBoxResult]::Yes) {
        throw 'Envoi Reporter non autorise par l utilisateur.'
    }

    $id = ''
    try { if ($existing.installationId) { $id = [string]$existing.installationId } } catch { }
    if ([string]::IsNullOrWhiteSpace($id)) {
        $id = 'SNTPC-' + ([guid]::NewGuid().ToString('N').Substring(0,10).ToUpperInvariant())
    }

    $cfg = [ordered]@{
        schemaVersion = 1
        enabled = $true
        installationId = $id
        updatedAt = (Get-Date).ToString('o')
        endpoint = $reportEndpoint
    }
    $dir = Split-Path -Parent $configPath
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $cfg | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $configPath -Encoding UTF8
    return [pscustomobject]$cfg
}

Write-TestLog 'INFO' 'Reporter test started.'
try {
    $cfg = Get-OrCreateConsent
    Write-TestLog 'OK' ('Consent enabled. InstallationId=' + [string]$cfg.installationId)

    $headers = @{ 'User-Agent'='SENETECH-Reporter-Test/1.0'; 'Cache-Control'='no-cache'; 'Pragma'='no-cache' }

    try {
        $health = Invoke-WebRequest -UseBasicParsing -Uri ($healthEndpoint + '?t=' + [guid]::NewGuid().ToString('N')) -Headers $headers -TimeoutSec 8 -ErrorAction Stop
        Write-TestLog 'OK' ('Health HTTP ' + [int]$health.StatusCode)
    } catch {
        Write-TestLog 'ERROR' ('Health failed: ' + $_.Exception.Message)
        throw ('Worker /health inaccessible : ' + $_.Exception.Message)
    }

    $payload = [ordered]@{
        incidentId = 'SNT-TEST-' + ([guid]::NewGuid().ToString('N').Substring(0,8).ToUpperInvariant())
        severity = 'SUCCESS'
        version = 'Developer Reporter Test'
        windows = [Environment]::OSVersion.VersionString
        model = 'Manual reporter test'
        stage = 'Test Reporter Developer'
        errorCode = 'REPORTER-TEST'
        error = 'Test manuel SENETECH vers Cloudflare puis Discord'
        log = 'Si ce message apparait sur Discord, la chaine Reporter fonctionne.'
    }
    $json = $payload | ConvertTo-Json -Depth 5 -Compress
    $response = Invoke-WebRequest -UseBasicParsing -Uri $reportEndpoint -Method Post -ContentType 'application/json' -Body $json -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    Write-TestLog 'OK' ('Report HTTP ' + [int]$response.StatusCode)

    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    [System.Windows.MessageBox]::Show(
        "Reporter SENETECH : OK`r`n`r`nLe Worker Cloudflare repond et le rapport test a ete accepte.`r`nVerifiez maintenant votre canal Discord.",
        'SENETECH - Reporter OK',
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    ) | Out-Null
    exit 0
} catch {
    $msg = [string]$_.Exception.Message
    Write-TestLog 'ERROR' $msg
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        [System.Windows.MessageBox]::Show(
            ("Reporter SENETECH : ECHEC`r`n`r`n" + $msg + "`r`n`r`nJournal : " + $logPath),
            'SENETECH - Reporter Erreur',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    } catch { }
    exit 1
}
