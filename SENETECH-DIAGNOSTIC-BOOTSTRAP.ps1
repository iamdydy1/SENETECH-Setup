param(
    [string]$InstallDir = ''
)

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

$repo = 'iamdydy1/SENETECH-Setup'
$pin = '25cd49eb53f3085c9eeafe032c6b40c7e0b6a95a'
$logDir = Join-Path $env:ProgramData 'SENETECH\Logs'
$logPath = Join-Path $logDir 'SENETECH-DiagnosticBootstrap.log'

function Log([string]$Text) {
    try {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        Add-Content -LiteralPath $logPath -Encoding UTF8 -Value ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$Text)
    } catch { }
}

function Find-SenetechRoot {
    if (-not [string]::IsNullOrWhiteSpace($InstallDir)) {
        if (Test-Path -LiteralPath (Join-Path $InstallDir 'SENETECH-Setup.exe')) { return $InstallDir }
        throw "SENETECH-Setup.exe introuvable dans $InstallDir"
    }

    $preferred = 'C:\Program Files\SENETECH'
    if (Test-Path -LiteralPath (Join-Path $preferred 'SENETECH-Setup.exe')) { return $preferred }

    foreach ($drive in @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
        try {
            $root = [string]$drive.Root
            if ($root -and (Test-Path -LiteralPath (Join-Path $root 'SENETECH-Setup.exe'))) { return $root.TrimEnd('\') }
            $candidate = Join-Path $root 'SENETECH'
            if (Test-Path -LiteralPath (Join-Path $candidate 'SENETECH-Setup.exe')) { return $candidate }
        } catch { }
    }
    throw 'Installation SENETECH introuvable. Utilisez -InstallDir pour indiquer son dossier.'
}

function Download-Pinned([string]$Relative,[string]$Destination) {
    $url = "https://raw.githubusercontent.com/$repo/$pin/$Relative"
    $parent = Split-Path -Parent $Destination
    if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $nonce = [guid]::NewGuid().ToString('N')
    Invoke-WebRequest -UseBasicParsing -Uri ($url + '?senetech=' + $nonce) -OutFile $Destination -TimeoutSec 60
    if (-not (Test-Path -LiteralPath $Destination) -or (Get-Item -LiteralPath $Destination).Length -lt 20) {
        throw "Telechargement incomplet : $Relative"
    }
}

try {
    $root = Find-SenetechRoot
    Log ('Diagnostic bootstrap start. Root=' + $root)

    $needsAdmin = $root.StartsWith($env:ProgramFiles,[StringComparison]::OrdinalIgnoreCase)
    if ($needsAdmin) {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            $args = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -InstallDir "' + $root + '"'
            Start-Process powershell.exe -ArgumentList $args -Verb RunAs
            exit 0
        }
    }

    $toolPath = Join-Path $root '_SENETECH\Tools\SENETECH-DEV-DIAGNOSTIC.ps1'
    $cmdPath = Join-Path $root 'SENETECH-DEV-DIAGNOSTIC.cmd'

    Download-Pinned 'src/Tools/SENETECH-DEV-DIAGNOSTIC.ps1' $toolPath
    Download-Pinned 'SENETECH-DEV-DIAGNOSTIC.cmd' $cmdPath

    $tokens=$null; $errors=$null
    [void][System.Management.Automation.Language.Parser]::ParseFile($toolPath,[ref]$tokens,[ref]$errors)
    if ($errors -and $errors.Count -gt 0) { throw ('Syntaxe diagnostic invalide : ' + $errors[0].Message) }

    Log ('Diagnostic installed: ' + $toolPath)
    try {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            "Le diagnostic Developer SENETECH est installe.`r`n`r`nLancez :`r`n$cmdPath`r`n`r`nLes bundles seront crees dans :`r`nC:\ProgramData\SENETECH\Logs\Developer",
            'SENETECH - Diagnostic Developer',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        ) | Out-Null
    } catch { }
}
catch {
    Log ('BOOTSTRAP ERROR: ' + $_.Exception.Message)
    try {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            "Installation du diagnostic impossible.`r`n`r`n$($_.Exception.Message)`r`n`r`nJournal :`r`n$logPath",
            'SENETECH - Diagnostic Developer',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    } catch { }
    exit 1
}
