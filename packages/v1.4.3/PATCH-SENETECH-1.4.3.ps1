param(
    [Parameter(Mandatory=$true)]
    [string]$StageDir
)

$ErrorActionPreference = 'Stop'
$Utf8Bom = New-Object System.Text.UTF8Encoding -ArgumentList $true

function Write-Utf8Bom([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, $Utf8Bom)
}

function Replace-VersionText([string]$Path) {
    if (-not (Test-Path $Path)) { throw "Missing file: $Path" }
    $text = [System.IO.File]::ReadAllText($Path)
    $text = $text.Replace('1.4.2.0', '1.4.3.0')
    $text = $text.Replace('1.4.2', '1.4.3')
    Write-Utf8Bom $Path $text
}

function Replace-BytePattern([byte[]]$Data, [byte[]]$Old, [byte[]]$New) {
    if ($Old.Length -ne $New.Length) { throw 'Binary replacement must keep the same length.' }
    $count = 0
    for ($i = 0; $i -le ($Data.Length - $Old.Length); $i++) {
        $match = $true
        for ($j = 0; $j -lt $Old.Length; $j++) {
            if ($Data[$i + $j] -ne $Old[$j]) { $match = $false; break }
        }
        if ($match) {
            [System.Array]::Copy($New, 0, $Data, $i, $New.Length)
            $count++
            $i += ($Old.Length - 1)
        }
    }
    return $count
}

$enginePath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.ps1'
$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
$exePath = Join-Path $StageDir 'SENETECH-Setup.exe'
$versionPath = Join-Path $StageDir 'VERSION.txt'
$readmePath = Join-Path $StageDir 'LISEZ-MOI.txt'
$changelogPath = Join-Path $StageDir 'CHANGELOG.txt'

Replace-VersionText $enginePath
Replace-VersionText $manifestPath
if (Test-Path $readmePath) { Replace-VersionText $readmePath }

$versionText = @"
SENETECH Setup
Version 1.4.3.0
Canal : Test GitHub Update
Architecture : Windows 10 / 11
Mode : Application portable
"@
Write-Utf8Bom $versionPath $versionText.TrimStart()

if (Test-Path $changelogPath) {
    $changelog = [System.IO.File]::ReadAllText($changelogPath)
    if ($changelog -notmatch '(?m)^Version 1\.4\.3\s*$') {
        $entry = @"
SENETECH SETUP - TEST DE MISE A JOUR
=====================================

Version 1.4.3
-------------
- Test reel de mise a jour V1.4.2 vers V1.4.3 depuis GitHub.
- Validation du telechargement, du SHA-256, du remplacement et du redemarrage.
- Conservation du nettoyage automatique des fichiers temporaires.
- Conservation du cache hors ligne optimise : une seule version par application.

"@
        Write-Utf8Bom $changelogPath ($entry + $changelog)
    }
}

if (Test-Path $exePath) {
    $bytes = [System.IO.File]::ReadAllBytes($exePath)
    $ascii = [System.Text.Encoding]::ASCII
    $unicode = [System.Text.Encoding]::Unicode
    $count = 0
    $count += Replace-BytePattern $bytes ($ascii.GetBytes('1.4.2.0')) ($ascii.GetBytes('1.4.3.0'))
    $count += Replace-BytePattern $bytes ($unicode.GetBytes('1.4.2.0')) ($unicode.GetBytes('1.4.3.0'))
    if ($count -gt 0) {
        [System.IO.File]::WriteAllBytes($exePath, $bytes)
    }
}

$verify = [System.IO.File]::ReadAllText($enginePath)
if ($verify -notmatch "AppVersion = '1\.4\.3\.0'") {
    throw 'SENETECH engine version verification failed.'
}

exit 0
