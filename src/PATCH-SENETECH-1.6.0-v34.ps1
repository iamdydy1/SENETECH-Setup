param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

$steps = @(
    @{
        Url = 'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/7337f3c6543cb97e51b81014a7d8110f30caae1e/src/PATCH-SENETECH-1.6.0-v32.ps1'
        Label = 'Stable vers Diagnostic build 26'
    },
    @{
        Url = 'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/a98c481496021b2c9f14a1f18511d5209df838d2/src/PATCH-SENETECH-1.6.0-v33.ps1'
        Label = 'Firefox Safety build 27'
    }
)

foreach ($step in $steps) {
    $tmp = Join-Path $env:TEMP ('SENETECH-B27-' + [guid]::NewGuid().ToString('N') + '.ps1')
    try {
        Invoke-WebRequest -UseBasicParsing -Uri ($step.Url + '?senetech=' + [guid]::NewGuid().ToString('N')) -OutFile $tmp -TimeoutSec 60
        & $tmp -StageDir $StageDir
    } catch {
        throw ($step.Label + ' en echec : ' + $_.Exception.Message)
    } finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}

Write-Output 'SENETECH V1.6.0 DEV build 27 FIREFOX SAFETY - fallback complet applique.'
