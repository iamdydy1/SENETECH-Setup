param(
    [string]$InstallDir = 'C:\Program Files\SENETECH'
)

$ErrorActionPreference = 'Stop'
$repo = 'iamdydy1/SENETECH-Setup'
$recoveryCommit = '572032e0cade1194210b151f3fba120b31a3b9a2'
$knownGoodCommit = '7dc64fd1216068f3353f5ff4d65d750c26c75009'
$updaterCommit = '04beb60182b49cd0b20ae1cfcb082d3aa3351b4a'
$stableUrl = 'https://github.com/iamdydy1/SENETECH-Setup/releases/download/1.5.1/SENETECH-Setup-V1.5.1-FULL-STABLE.zip'
$stableSha = '81ab6caf1359ff9617bed74dffaad8a9e6e51c5c7043131ca51ee2e1f4c7332a'
$stableSize = 109004
$patchUrl = "https://raw.githubusercontent.com/$repo/$recoveryCommit/src/PATCH-SENETECH-1.6.0-v30.ps1"
$patchSha = '5586a3362b6745b54197400f2d13a490dce050ba2ed9303b7767b841f2fbb8ae'
$logDir = Join-Path $env:ProgramData 'SENETECH\Logs'
$logPath = Join-Path $logDir 'SENETECH-Recovery.log'
$tempRoot = Join-Path $env:TEMP ('SENETECH-Recovery-' + [guid]::NewGuid().ToString('N'))
$zipPath = Join-Path $tempRoot 'stable.zip'
$stageDir = Join-Path $tempRoot 'stage'
$patchPath = Join-Path $tempRoot 'recovery-patch.ps1'

function Log([string]$Text) {
    try {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        Add-Content -LiteralPath $logPath -Encoding UTF8 -Value ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$Text)
    } catch { }
}
function Sha256([string]$Path) {
    $s=[IO.File]::OpenRead($Path)
    try { $h=[Security.Cryptography.SHA256]::Create(); try { return ([BitConverter]::ToString($h.ComputeHash($s))).Replace('-','').ToLowerInvariant() } finally { $h.Dispose() } } finally { $s.Dispose() }
}
function Download([string]$Url,[string]$Path) {
    $parent=Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Invoke-WebRequest -UseBasicParsing -Uri ($Url + $(if($Url.Contains('?')){'&'}else{'?'}) + 'senetech=' + [guid]::NewGuid().ToString('N')) -OutFile $Path -TimeoutSec 120
}
function Stop-SenetechRuntime {
    Get-Process -Name 'SENETECH-Setup' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    try {
        Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -and ($_.CommandLine -like '*SENETECH-Setup.ps1*' -or $_.CommandLine -like '*SENETECH\\*') } |
            ForEach-Object { Invoke-CimMethod -InputObject $_ -MethodName Terminate -ErrorAction SilentlyContinue | Out-Null }
    } catch { }
    Start-Sleep -Seconds 2
}
function Parse-AllScripts([string]$Root) {
    foreach($f in @(Get-ChildItem -LiteralPath $Root -Filter '*.ps1' -File -Recurse)) {
        $tokens=$null; $errors=$null
        [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName,[ref]$tokens,[ref]$errors)
        if($errors -and $errors.Count -gt 0){ throw ('Syntaxe PowerShell invalide dans ' + $f.FullName + ' : ' + $errors[0].Message) }
    }
}

try {
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    $principal=New-Object Security.Principal.WindowsPrincipal($identity)
    if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
        $args='-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -InstallDir "' + $InstallDir + '"'
        Start-Process powershell.exe -ArgumentList $args -Verb RunAs
        exit 0
    }

    Log 'RECOVERY build 25 start.'
    try { [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12 } catch { }
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $stageDir -Force | Out-Null

    Log 'Telechargement base Stable 1.5.1.'
    Download $stableUrl $zipPath
    $size=(Get-Item -LiteralPath $zipPath).Length
    if($size -ne $stableSize){ throw "Taille package Stable invalide : $size" }
    if((Sha256 $zipPath) -ne $stableSha){ throw 'SHA-256 package Stable invalide.' }
    Expand-Archive -LiteralPath $zipPath -DestinationPath $stageDir -Force

    Log 'Application patch recovery build 25.'
    Download $patchUrl $patchPath
    if((Sha256 $patchPath) -ne $patchSha){ throw 'SHA-256 patch recovery invalide.' }
    & $patchPath -StageDir $stageDir

    $runtimeFiles = @(
      'src/Modules/Senetech.Catalog.ps1|_SENETECH/Modules/Senetech.Catalog.ps1',
      'src/Modules/Senetech.Technician.ps1|_SENETECH/Modules/Senetech.Technician.ps1',
      'src/Modules/Senetech.StartupFix.ps1|_SENETECH/Modules/Senetech.StartupFix.ps1',
      'src/Modules/Senetech.Delivery.ps1|_SENETECH/Modules/Senetech.Delivery.ps1',
      'src/Modules/Senetech.WinGet.ps1|_SENETECH/Modules/Senetech.WinGet.ps1',
      'src/Modules/Senetech.Display.ps1|_SENETECH/Modules/Senetech.Display.ps1',
      'src/Modules/Senetech.DeliveryDisplayFix.ps1|_SENETECH/Modules/Senetech.DeliveryDisplayFix.ps1',
      'src/Modules/Senetech.DeliveryInventoryFix.ps1|_SENETECH/Modules/Senetech.DeliveryInventoryFix.ps1',
      'src/Modules/Senetech.DeliveryRegistryFix.ps1|_SENETECH/Modules/Senetech.DeliveryRegistryFix.ps1',
      'src/Modules/Senetech.FrenchUi.ps1|_SENETECH/Modules/Senetech.FrenchUi.ps1',
      'src/Modules/Senetech.Validation.ps1|_SENETECH/Modules/Senetech.Validation.ps1',
      'src/Modules/Senetech.ReleaseSafety.ps1|_SENETECH/Modules/Senetech.ReleaseSafety.ps1',
      'src/Modules/Senetech.CacheSafety.ps1|_SENETECH/Modules/Senetech.CacheSafety.ps1',
      'src/Client/SENETECH-Welcome.ps1|_SENETECH/Client/SENETECH-Welcome.ps1',
      'src/Moteur-WindowsUpdate.ps1|_SENETECH/Moteur-WindowsUpdate.ps1',
      'catalog/apps.json|_SENETECH/Catalog/apps.json',
      'catalog/profiles.json|_SENETECH/Catalog/profiles.json'
    )
    foreach($entry in $runtimeFiles){
        $parts=$entry.Split('|'); $src=$parts[0]; $dst=$parts[1]
        $url="https://raw.githubusercontent.com/$repo/$knownGoodCommit/$src"
        Download $url (Join-Path $stageDir $dst)
    }
    Download "https://raw.githubusercontent.com/$repo/$updaterCommit/src/UPDATE-SENETECH-V23.ps1" (Join-Path $stageDir 'UPDATE-SENETECH.ps1')
    Download "https://raw.githubusercontent.com/$repo/$updaterCommit/src/UPDATE-SENETECH-CHANNEL.ps1" (Join-Path $stageDir 'UPDATE-SENETECH-CHANNEL.ps1')

    $engine=Join-Path $stageDir '_SENETECH\SENETECH-Setup.ps1'
    if(-not (Test-Path -LiteralPath $engine)){ throw 'Moteur recovery absent.' }
    $engineText=Get-Content -LiteralPath $engine -Raw
    if(-not $engineText.Contains("`$script:AppVersion = '1.6.0.25'")){ throw 'Version moteur recovery invalide.' }
    if($engineText.Contains('Senetech.Reporter.ps1') -or $engineText.Contains('Initialize-SenetechReporter')){ throw 'Reporter detecte dans recovery.' }
    Parse-AllScripts $stageDir
    Log 'Validation staging OK.'

    Stop-SenetechRuntime
    $backupRoot=Join-Path $env:ProgramData ('SENETECH\RecoveryBackups\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    if(Test-Path -LiteralPath $InstallDir){
        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
        Copy-Item -Path (Join-Path $InstallDir '*') -Destination $backupRoot -Recurse -Force -ErrorAction SilentlyContinue
        Log ('Sauvegarde runtime precedent : ' + $backupRoot)
    }

    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    foreach($name in @('SENETECH-Setup.exe','VERSION.txt','LISEZ-MOI.txt','CHANGELOG.txt','UPDATE-SENETECH.ps1','UPDATE-SENETECH-CHANNEL.ps1')){ Remove-Item -LiteralPath (Join-Path $InstallDir $name) -Force -ErrorAction SilentlyContinue }
    $oldEngine=Join-Path $InstallDir '_SENETECH'
    if(Test-Path -LiteralPath $oldEngine){ Remove-Item -LiteralPath $oldEngine -Recurse -Force }
    Copy-Item -Path (Join-Path $stageDir '*') -Destination $InstallDir -Recurse -Force

    $installedEngine=Join-Path $InstallDir '_SENETECH\SENETECH-Setup.ps1'
    if(-not (Test-Path -LiteralPath $installedEngine)){ throw 'Copie finale incomplete : moteur absent.' }
    if(-not ((Get-Content -LiteralPath $installedEngine -Raw).Contains("`$script:AppVersion = '1.6.0.25'"))){ throw 'Copie finale incomplete : build 25 non detectee.' }
    Log 'Installation recovery build 25 terminee.'

    $exe=Join-Path $InstallDir 'SENETECH-Setup.exe'
    if(-not (Test-Path -LiteralPath $exe)){ throw 'SENETECH-Setup.exe absent apres recovery.' }
    Start-Process -FilePath $exe -WorkingDirectory $InstallDir
    Log 'Relance SENETECH demandee.'
    [System.Windows.Forms.MessageBox]::Show('Recovery SENETECH build 25 installee. SENETECH vient d etre relance.','SENETECH Recovery') | Out-Null
}
catch{
    Log ('RECOVERY ERROR: ' + $_.Exception.Message)
    try { Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show("La recuperation SENETECH a echoue.`r`n`r`n$($_.Exception.Message)`r`n`r`nJournal : $logPath",'SENETECH Recovery') | Out-Null } catch { }
    exit 1
}
finally{
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
