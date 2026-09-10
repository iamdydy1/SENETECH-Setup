param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'

# Apply previous V1.6.0.5 patch first.
$previousPatch = Join-Path $env:TEMP 'SENETECH-PATCH-1.6.0-v7.ps1'
$previousPatchUrl = 'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/develop/src/PATCH-SENETECH-1.6.0-v7.ps1'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri $previousPatchUrl -OutFile $previousPatch
    & $previousPatch -StageDir $StageDir
} finally {
    Remove-Item -LiteralPath $previousPatch -Force -ErrorAction SilentlyContinue
}

$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$enginePath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.ps1'
$engineText = [IO.File]::ReadAllText($enginePath,$utf8Bom)

# Load WinGet bootstrap module before the V1.6 features initialize.
$needle = ". `$deliveryModule`r`nInitialize-SenetechV16Features"
if (-not $engineText.Contains($needle)) {
    $needle = ". `$deliveryModule`nInitialize-SenetechV16Features"
}
if (-not $engineText.Contains($needle)) {
    throw 'Patch V1.6.0.6 impossible : point de chargement WinGet introuvable.'
}
$replacement = ". `$deliveryModule`r`n`$wingetModule = Join-Path `$script:EngineDir 'Modules\Senetech.WinGet.ps1'`r`nif (-not (Test-Path -LiteralPath `$wingetModule)) { throw 'Module WinGet SENETECH V1.6.0.6 introuvable.' }`r`n. `$wingetModule`r`nInitialize-SenetechV16Features"
$engineText = $engineText.Replace($needle,$replacement)

# Replace legacy direct WinGet lookups in the base engine. On a fresh Windows
# installation, SENETECH now attempts the official Microsoft bootstrap first.
$oldLookup = '$winget = Get-Command winget.exe -ErrorAction SilentlyContinue'
$lookupCount = ([regex]::Matches($engineText,[regex]::Escape($oldLookup))).Count
if ($lookupCount -lt 2) {
    throw "Patch V1.6.0.6 impossible : recherches WinGet attendues absentes ($lookupCount trouvee(s))."
}
$engineText = $engineText.Replace($oldLookup,'$winget = Get-SenetechWingetCommand -BootstrapIfMissing')

$engineText = $engineText.Replace("`$script:AppVersion = '1.6.0.5'", "`$script:AppVersion = '1.6.0.6'")
[IO.File]::WriteAllText($enginePath,$engineText,$utf8Bom)

$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath,$utf8NoBom)
    $manifestText = $manifestText.Replace('version="1.6.0.5"','version="1.6.0.6"')
    [IO.File]::WriteAllText($manifestPath,$manifestText,$utf8NoBom)
}

Set-Content -LiteralPath (Join-Path $StageDir 'VERSION.txt') -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.6
Affichage : 1.6.0 DEV
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Mises a jour : GitHub + SHA-256 + rollback
Correctif : installation / reparation automatique de WinGet sur Windows neuf
'@

Write-Output 'SENETECH V1.6.0 DEV build 6 - bootstrap WinGet ajoute.'
