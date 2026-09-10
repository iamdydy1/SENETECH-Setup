param(
    [string]$CurrentVersion = '1.5.1.0',
    [string]$InstallDir = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [string]$UpdateChannel = 'stable',
    [int]$WaitForProcessId = 0,
    [switch]$NoRestart
)

$ErrorActionPreference = 'Stop'
$channel = if (([string]$UpdateChannel).ToLowerInvariant() -eq 'develop') { 'develop' } else { 'stable' }
$baseUpdater = Join-Path $InstallDir 'UPDATE-SENETECH.ps1'
if (-not (Test-Path -LiteralPath $baseUpdater)) {
    throw "Updater SENETECH introuvable : $baseUpdater"
}

# A move from a newer DEV build to the lower-numbered Stable release is an
# intentional channel switch, not a normal upgrade. The legacy updater only
# accepts remote versions greater than CurrentVersion, so force its comparison
# baseline to 0.0.0.0 for Stable. It still downloads the official main manifest,
# verifies package size/SHA-256, backs up the current runtime and then applies it.
$comparisonVersion = $CurrentVersion
if ($channel -eq 'stable') {
    $comparisonVersion = '0.0.0.0'
}

$args = @(
    '-NoProfile',
    '-ExecutionPolicy','Bypass',
    '-File',('"' + $baseUpdater + '"'),
    '-CurrentVersion',('"' + $comparisonVersion + '"'),
    '-InstallDir',('"' + $InstallDir + '"'),
    '-UpdateChannel',$channel,
    '-WaitForProcessId',[string]$WaitForProcessId
)
if ($NoRestart) { $args += '-NoRestart' }

$process = Start-Process -FilePath 'powershell.exe' -ArgumentList $args -PassThru -Wait -WindowStyle Hidden
exit $process.ExitCode
