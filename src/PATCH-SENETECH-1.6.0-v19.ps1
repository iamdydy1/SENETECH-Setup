param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'

# Apply the complete V1.6.0.16 safety build first.
$previousPatch = Join-Path $env:TEMP 'SENETECH-PATCH-1.6.0-v18.ps1'
$previousPatchUrl = 'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/develop/src/PATCH-SENETECH-1.6.0-v18.ps1'
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

# Named accent tokens such as {eacute} collide with PowerShell/.NET's -f format
# operator. Convert tokens already embedded in the engine to brace-free tokens.
$accentPairs = @(
    @('{agrave}','__agrave__'), @('{acirc}','__acirc__'), @('{cced}','__cced__'),
    @('{eacute}','__eacute__'), @('{egrave}','__egrave__'), @('{ecirc}','__ecirc__'), @('{euml}','__euml__'),
    @('{icirc}','__icirc__'), @('{iuml}','__iuml__'), @('{ocirc}','__ocirc__'),
    @('{ugrave}','__ugrave__'), @('{ucirc}','__ucirc__'), @('{uuml}','__uuml__'),
    @('{Agrave}','__A_GRAVE__'), @('{A_GRAVE}','__A_GRAVE__'),
    @('{Eacute}','__E_ACUTE__'), @('{E_ACUTE}','__E_ACUTE__')
)
foreach ($pair in $accentPairs) { $engineText = $engineText.Replace([string]$pair[0],[string]$pair[1]) }

# The updater applies patches before overlay files are downloaded. Therefore the
# final overlay modules must be normalized at application startup, immediately
# before they are dot-sourced. This makes the fix independent of file encoding
# and safe for Windows PowerShell 5.1.
$loaderNeedle = "$frenchUiModule = Join-Path $script:EngineDir 'Modules\Senetech.FrenchUi.ps1'"
# The strings above are evaluated by this patch process; use literal text instead.
$loaderNeedle = '$frenchUiModule = Join-Path $script:EngineDir ''Modules\Senetech.FrenchUi.ps1'''
if (-not $engineText.Contains($loaderNeedle)) {
    throw 'Patch V1.6.0.17 impossible : chargeur FrenchUi introuvable.'
}

$loaderBlock = @'
function Convert-SenetechAccentSourceFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $text = [IO.File]::ReadAllText($Path)
    $pairs = @(
        @('{agrave}','__agrave__'), @('{acirc}','__acirc__'), @('{cced}','__cced__'),
        @('{eacute}','__eacute__'), @('{egrave}','__egrave__'), @('{ecirc}','__ecirc__'), @('{euml}','__euml__'),
        @('{icirc}','__icirc__'), @('{iuml}','__iuml__'), @('{ocirc}','__ocirc__'),
        @('{ugrave}','__ugrave__'), @('{ucirc}','__ucirc__'), @('{uuml}','__uuml__'),
        @('{Agrave}','__A_GRAVE__'), @('{A_GRAVE}','__A_GRAVE__'),
        @('{Eacute}','__E_ACUTE__'), @('{E_ACUTE}','__E_ACUTE__')
    )
    $changed = $false
    foreach ($pair in $pairs) {
        $updated = $text.Replace([string]$pair[0],[string]$pair[1])
        if ($updated -ne $text) { $text = $updated; $changed = $true }
    }
    if ($changed) {
        [IO.File]::WriteAllText($Path,$text,(New-Object System.Text.UTF8Encoding($true)))
    }
}

$frenchUiModule = Join-Path $script:EngineDir 'Modules\Senetech.FrenchUi.ps1'
'@
$engineText = $engineText.Replace($loaderNeedle,$loaderBlock.TrimEnd("`r","`n"))

# Normalize every module that may contain localized tokens before loading it.
$loadTargets = @(
    @("if (-not (Test-Path -LiteralPath `$frenchUiModule)) { throw 'Module interface francaise SENETECH V1.6.0.13 introuvable.' }`r`n. `$frenchUiModule",
      "if (-not (Test-Path -LiteralPath `$frenchUiModule)) { throw 'Module interface francaise SENETECH V1.6.0.13 introuvable.' }`r`nConvert-SenetechAccentSourceFile `$frenchUiModule`r`n. `$frenchUiModule"),
    @("if (-not (Test-Path -LiteralPath `$validationModule)) { throw 'Module validation SENETECH V1.6.0.14 introuvable.' }`r`n. `$validationModule",
      "if (-not (Test-Path -LiteralPath `$validationModule)) { throw 'Module validation SENETECH V1.6.0.14 introuvable.' }`r`nConvert-SenetechAccentSourceFile `$validationModule`r`n. `$validationModule"),
    @("if (-not (Test-Path -LiteralPath `$releaseSafetyModule)) { throw 'Module securite release SENETECH V1.6.0.16 introuvable.' }`r`n. `$releaseSafetyModule",
      "if (-not (Test-Path -LiteralPath `$releaseSafetyModule)) { throw 'Module securite release SENETECH V1.6.0.16 introuvable.' }`r`nConvert-SenetechAccentSourceFile `$releaseSafetyModule`r`n. `$releaseSafetyModule"),
    @("if (-not (Test-Path -LiteralPath `$cacheSafetyModule)) { throw 'Module securite cache SENETECH V1.6.0.16 introuvable.' }`r`n. `$cacheSafetyModule",
      "if (-not (Test-Path -LiteralPath `$cacheSafetyModule)) { throw 'Module securite cache SENETECH V1.6.0.16 introuvable.' }`r`nConvert-SenetechAccentSourceFile `$cacheSafetyModule`r`n. `$cacheSafetyModule")
)
foreach ($target in $loadTargets) {
    if ($engineText.Contains([string]$target[0])) { $engineText = $engineText.Replace([string]$target[0],[string]$target[1]) }
    else {
        $oldLf = ([string]$target[0]).Replace("`r`n","`n")
        $newLf = ([string]$target[1]).Replace("`r`n","`n")
        if ($engineText.Contains($oldLf)) { $engineText = $engineText.Replace($oldLf,$newLf) }
    }
}

$engineText = $engineText.Replace("`$script:AppVersion = '1.6.0.16'", "`$script:AppVersion = '1.6.0.17'")
$engineText = $engineText.Replace("`$script:DisplayVersion = '1.6.0 DEV - build 16'", "`$script:DisplayVersion = '1.6.0 DEV - build 17'")
$engineText = $engineText.Replace('Title="SENETECH Setup V1.6.0 DEV - build 16"','Title="SENETECH Setup V1.6.0 DEV - build 17"')
$engineText = $engineText.Replace('VERSION 1.6.0 DEV - BUILD 16" Foreground','VERSION 1.6.0 DEV - BUILD 17" Foreground')
$engineText = $engineText.Replace('SENETECH Setup V1.6.0 DEV - build 16 demarre','SENETECH Setup V1.6.0 DEV - build 17 demarre')
[IO.File]::WriteAllText($enginePath,$engineText,$utf8Bom)

$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath,$utf8NoBom)
    $manifestText = $manifestText.Replace('version="1.6.0.16"','version="1.6.0.17"')
    [IO.File]::WriteAllText($manifestPath,$manifestText,$utf8NoBom)
}

Set-Content -LiteralPath (Join-Path $StageDir 'VERSION.txt') -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.17
Affichage : 1.6.0 DEV - build 17
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Mises a jour : GitHub + SHA-256 + rollback
Correctif critique : tokens d accents compatibles avec l operateur de format PowerShell
Audit build 16 conserve : validation, rollback, cache et livraison securises
'@

Write-Output 'SENETECH V1.6.0 DEV build 17 - correctif formatage chaines francaises applique.'