param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

$recoveryCommit = '572032e0cade1194210b151f3fba120b31a3b9a2'
$diagnosticCommit = 'f0d66a68c59f14b252207a142db56df30bfabbe4'
$steps = @(
    @{ url = "https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/$recoveryCommit/src/PATCH-SENETECH-1.6.0-v30.ps1"; label = 'Recovery build 25' },
    @{ url = "https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/$diagnosticCommit/src/PATCH-SENETECH-1.6.0-v31.ps1"; label = 'Diagnostic build 26' }
)

foreach ($step in $steps) {
    $tmp = Join-Path $env:TEMP ('SENETECH-B26-' + [guid]::NewGuid().ToString('N') + '.ps1')
    try {
        Invoke-WebRequest -UseBasicParsing -Uri ($step.url + '?senetech=' + [guid]::NewGuid().ToString('N')) -OutFile $tmp -TimeoutSec 60
        & $tmp -StageDir $StageDir
    } catch {
        throw ($step.label + ' en echec : ' + $_.Exception.Message)
    } finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}

Write-Output 'SENETECH V1.6.0 DEV build 26 DIAGNOSTIC - fallback Stable vers Recovery puis Diagnostic applique.'
