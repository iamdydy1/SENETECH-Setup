param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

# Fallback for a machine entering Develop from Stable:
# 1) build the existing complete V1.6.0.22 runtime,
# 2) apply the hardened V1.6.0.23 normalizer.
$steps = @(
    'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/develop/src/PATCH-SENETECH-1.6.0-v25.ps1',
    'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/develop/src/PATCH-SENETECH-1.6.0-v27.ps1'
)
$index = 0
foreach ($url in $steps) {
    $index++
    $path = Join-Path $env:TEMP ("SENETECH-PATCH-V23-STEP-$index.ps1")
    try {
        Invoke-WebRequest -UseBasicParsing -Uri ($url + '?senetech=' + [guid]::NewGuid().ToString('N')) -OutFile $path -TimeoutSec 45
        & $path -StageDir $StageDir
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "Etape $index du patch V23 en echec : code $LASTEXITCODE" }
    } finally {
        Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    }
}

Write-Output 'SENETECH V1.6.0 DEV build 23 - fallback Stable vers Develop applique.'
