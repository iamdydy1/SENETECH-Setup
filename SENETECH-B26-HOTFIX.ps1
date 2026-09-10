param(
    [string]$InstallDir = ''
)

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

$repo = 'iamdydy1/SENETECH-Setup'
$patchPin = '7337f3c6543cb97e51b81014a7d8110f30caae1e'
$toolsPin = '25cd49eb53f3085c9eeafe032c6b40c7e0b6a95a'
$patchSha256 = 'f5607dec5ea1a02ce7f471da98ff92b90f28e407147f31a36df907e7a30c6701'
$logDir = Join-Path $env:ProgramData 'SENETECH\Logs'
$logPath = Join-Path $logDir 'SENETECH-B26-Hotfix.log'
$tempRoot = Join-Path $env:TEMP ('SENETECH-B26-' + [guid]::NewGuid().ToString('N'))
$stageDir = Join-Path $tempRoot 'stage'
$patchPath = Join-Path $tempRoot 'PATCH-v31.ps1'

function Log([string]$Text) {
    try {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        Add-Content -LiteralPath $logPath -Encoding UTF8 -Value ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$Text)
    } catch { }
}

function Sha256([string]$Path) {
    $s = [IO.File]::OpenRead($Path)
    try {
        $h = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($h.ComputeHash($s))).Replace('-','').ToLowerInvariant() }
        finally { $h.Dispose() }
    } finally { $s.Dispose() }
}

function Download([string]$Url,[string]$Destination) {
    $parent = Split-Path -Parent $Destination
    if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $nonce = [guid]::NewGuid().ToString('N')
    $sep = if ($Url.Contains('?')) { '&' } else { '?' }
    Invoke-WebRequest -UseBasicParsing -Uri ($Url + $sep + 'senetech=' + $nonce) -OutFile $Destination -TimeoutSec 60
    if (-not (Test-Path -LiteralPath $Destination) -or (Get-Item -LiteralPath $Destination).Length -lt 20) {
        throw "Telechargement incomplet : $Url"
    }
}

function Find-SenetechRoot {
    if (-not [string]::IsNullOrWhiteSpace($InstallDir)) {
        if (Test-Path -LiteralPath (Join-Path $InstallDir 'SENETECH-Setup.exe')) { return $InstallDir }
        throw "SENETECH-Setup.exe introuvable dans $InstallDir"
    }

    try {
        $running = Get-Process -Name 'SENETECH-Setup' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($running -and $running.Path) {
            $r = Split-Path -Parent $running.Path
            if (Test-Path -LiteralPath (Join-Path $r 'SENETECH-Setup.exe')) { return $r }
        }
    } catch { }

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
    throw 'Installation SENETECH introuvable.'
}

function Parse-Script([string]$Path) {
    $tokens=$null; $errors=$null
    [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
    if ($errors -and $errors.Count -gt 0) { throw ('Syntaxe PowerShell invalide dans ' + $Path + ' : ' + $errors[0].Message) }
}

try {
    $root = Find-SenetechRoot
    Log ('B26 hotfix start. Root=' + $root)

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

    $engine = Join-Path $root '_SENETECH\SENETECH-Setup.ps1'
    if (-not (Test-Path -LiteralPath $engine)) { throw 'Moteur SENETECH introuvable.' }
    $currentText = Get-Content -LiteralPath $engine -Raw
    if (-not $currentText.Contains("`$script:AppVersion = '1.6.0.25'")) {
        if ($currentText.Contains("`$script:AppVersion = '1.6.0.26'")) {
            Log 'Build 26 deja present; installation des outils diagnostic seulement.'
        } else {
            throw 'Ce hotfix exige SENETECH build 25 Recovery ou build 26 Diagnostic.'
        }
    }

    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $stageDir -Force | Out-Null

    New-Item -ItemType Directory -Path (Join-Path $stageDir '_SENETECH') -Force | Out-Null
    Copy-Item -LiteralPath $engine -Destination (Join-Path $stageDir '_SENETECH\SENETECH-Setup.ps1') -Force
    $manifest = Join-Path $root '_SENETECH\SENETECH-Setup.manifest'
    if (Test-Path -LiteralPath $manifest) { Copy-Item -LiteralPath $manifest -Destination (Join-Path $stageDir '_SENETECH\SENETECH-Setup.manifest') -Force }
    $version = Join-Path $root 'VERSION.txt'
    if (Test-Path -LiteralPath $version) { Copy-Item -LiteralPath $version -Destination (Join-Path $stageDir 'VERSION.txt') -Force }

    if ($currentText.Contains("`$script:AppVersion = '1.6.0.25'")) {
        Download "https://raw.githubusercontent.com/$repo/$patchPin/src/PATCH-SENETECH-1.6.0-v31.ps1" $patchPath
        $actualPatchHash = Sha256 $patchPath
        if ($actualPatchHash -ne $patchSha256) { throw "SHA-256 patch build 26 invalide : $actualPatchHash" }
        & $patchPath -StageDir $stageDir
        Log 'Patch 25 -> 26 applique.'
    }

    $diagPs1 = Join-Path $stageDir '_SENETECH\Tools\SENETECH-DEV-DIAGNOSTIC.ps1'
    $diagCmd = Join-Path $stageDir 'SENETECH-DEV-DIAGNOSTIC.cmd'
    Download "https://raw.githubusercontent.com/$repo/$toolsPin/src/Tools/SENETECH-DEV-DIAGNOSTIC.ps1" $diagPs1
    Download "https://raw.githubusercontent.com/$repo/$toolsPin/SENETECH-DEV-DIAGNOSTIC.cmd" $diagCmd

    Parse-Script (Join-Path $stageDir '_SENETECH\SENETECH-Setup.ps1')
    Parse-Script $diagPs1

    $stageText = Get-Content -LiteralPath (Join-Path $stageDir '_SENETECH\SENETECH-Setup.ps1') -Raw
    if (-not $stageText.Contains("`$script:AppVersion = '1.6.0.26'")) { throw 'Validation staging : build 26 non detectee.' }

    $backupRoot = Join-Path $env:ProgramData ('SENETECH\RecoveryBackups\B26-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    Copy-Item -LiteralPath $engine -Destination (Join-Path $backupRoot 'SENETECH-Setup.ps1') -Force
    if (Test-Path -LiteralPath $manifest) { Copy-Item -LiteralPath $manifest -Destination (Join-Path $backupRoot 'SENETECH-Setup.manifest') -Force }
    if (Test-Path -LiteralPath $version) { Copy-Item -LiteralPath $version -Destination (Join-Path $backupRoot 'VERSION.txt') -Force }
    Log ('Backup cree : ' + $backupRoot)

    Get-Process -Name 'SENETECH-Setup' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    Copy-Item -LiteralPath (Join-Path $stageDir '_SENETECH\SENETECH-Setup.ps1') -Destination $engine -Force
    if (Test-Path -LiteralPath (Join-Path $stageDir '_SENETECH\SENETECH-Setup.manifest')) {
        Copy-Item -LiteralPath (Join-Path $stageDir '_SENETECH\SENETECH-Setup.manifest') -Destination $manifest -Force
    }
    if (Test-Path -LiteralPath (Join-Path $stageDir 'VERSION.txt')) {
        Copy-Item -LiteralPath (Join-Path $stageDir 'VERSION.txt') -Destination $version -Force
    }
    $toolDest = Join-Path $root '_SENETECH\Tools\SENETECH-DEV-DIAGNOSTIC.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $toolDest) -Force | Out-Null
    Copy-Item -LiteralPath $diagPs1 -Destination $toolDest -Force
    Copy-Item -LiteralPath $diagCmd -Destination (Join-Path $root 'SENETECH-DEV-DIAGNOSTIC.cmd') -Force

    Log 'Build 26 hotfix installe sans lecture de version.json.'
    $exe = Join-Path $root 'SENETECH-Setup.exe'
    Start-Process -FilePath $exe -WorkingDirectory $root

    try {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            "SENETECH build 26 DIAGNOSTIC est installe.`r`n`r`nLe cache version.json a ete contourne.`r`n`r`nPour les prochains tests, lancez :`r`nSENETECH-DEV-DIAGNOSTIC.cmd",
            'SENETECH - Build 26 Hotfix',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        ) | Out-Null
    } catch { }
}
catch {
    Log ('HOTFIX ERROR: ' + $_.Exception.Message)
    try {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            "Hotfix build 26 impossible.`r`n`r`n$($_.Exception.Message)`r`n`r`nJournal :`r`n$logPath",
            'SENETECH - Build 26 Hotfix',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    } catch { }
    exit 1
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
