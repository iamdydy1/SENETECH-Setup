param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

# Fallback for a machine entering Develop from Stable.
# Dependencies are pinned to an immutable commit so this build cannot drift.
$pin = '0c5fe9628e8b6eea49d1e3a6754fdcf3cdfb12aa'
$steps = @(
    "https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/$pin/src/PATCH-SENETECH-1.6.0-v25.ps1",
    "https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/$pin/src/PATCH-SENETECH-1.6.0-v27.ps1"
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
