param(
    [Parameter(Mandatory=$true)]
    [string]$StageDir
)

$ErrorActionPreference = 'Stop'
$ExpectedEngineSha256 = '6966f9b09fe9730cc925cb354b159a198da3e30ca1768c506346a02dbaf6b315'
$CompressedEngineBase64 = @'
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
ewAfIwAA
'@

function Get-Sha256Bytes([byte[]]$Data) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($Data)
        return ([System.BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant()
    } finally { $sha.Dispose() }
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

function Write-Utf8Bom([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($true)))
}

$compressed = [System.Convert]::FromBase64String(($CompressedEngineBase64 -replace '\s',''))
$input = New-Object System.IO.MemoryStream(,$compressed)
$gzip = New-Object System.IO.Compression.GZipStream($input, [System.IO.Compression.CompressionMode]::Decompress)
$output = New-Object System.IO.MemoryStream
try {
    $gzip.CopyTo($output)
    $engineBytes = $output.ToArray()
} finally {
    $gzip.Dispose(); $input.Dispose(); $output.Dispose()
}
if ((Get-Sha256Bytes $engineBytes) -ne $ExpectedEngineSha256) { throw 'Engine V1.5.0 SHA-256 mismatch.' }
$enginePath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.ps1'
[System.IO.File]::WriteAllBytes($enginePath, $engineBytes)

$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
if (Test-Path $manifestPath) {
    $manifest = [System.IO.File]::ReadAllText($manifestPath)
    $manifest = $manifest.Replace('1.4.2.0','1.5.0.0').Replace('1.4.3.0','1.5.0.0')
    [System.IO.File]::WriteAllText($manifestPath, $manifest, (New-Object System.Text.UTF8Encoding($false)))
}

$exePath = Join-Path $StageDir 'SENETECH-Setup.exe'
if (-not (Test-Path $exePath)) { throw 'SENETECH-Setup.exe absent du package.' }
$exeBytes = [System.IO.File]::ReadAllBytes($exePath)
$ascii = [System.Text.Encoding]::ASCII
$unicode = [System.Text.Encoding]::Unicode
$count = 0
$count += Replace-BytePattern $exeBytes ($ascii.GetBytes('1.4.2.0')) ($ascii.GetBytes('1.5.0.0'))
$count += Replace-BytePattern $exeBytes ($unicode.GetBytes('1.4.2.0')) ($unicode.GetBytes('1.5.0.0'))
$count += Replace-BytePattern $exeBytes ($ascii.GetBytes('1.4.3.0')) ($ascii.GetBytes('1.5.0.0'))
$count += Replace-BytePattern $exeBytes ($unicode.GetBytes('1.4.3.0')) ($unicode.GetBytes('1.5.0.0'))
[System.IO.File]::WriteAllBytes($exePath, $exeBytes)

$versionPath = Join-Path $StageDir 'VERSION.txt'
$versionText = @"
SENETECH Setup
Version 1.5.0.0
Canal : Stable GitHub
Architecture : Windows 10 / 11
Mode : Portable + installation Windows integree
"@
Write-Utf8Bom $versionPath $versionText.TrimStart()

$readmePath = Join-Path $StageDir 'LISEZ-MOI.txt'
if (Test-Path $readmePath) {
    $readme = [System.IO.File]::ReadAllText($readmePath)
    $intro = @"
SENETECH SETUP V1.5.0 - PORTABLE + INSTALLE
================================================

Une seule application SENETECH, deux modes :
- Mode PORTABLE : depuis une cle USB ou un dossier, sans installation.
- Mode INSTALLE : C:\Program Files\SENETECH, raccourcis Windows et desinstallation integree.
- Les deux modes utilisent le meme depot GitHub et le meme systeme de mise a jour.

"@
    Write-Utf8Bom $readmePath ($intro + $readme)
}

$changelogPath = Join-Path $StageDir 'CHANGELOG.txt'
if (Test-Path $changelogPath) {
    $changelog = [System.IO.File]::ReadAllText($changelogPath)
    $entry = @"
SENETECH SETUP - PORTABLE + INSTALLE
======================================

Version 1.5.0
-------------
- Une seule application SENETECH avec deux modes : Portable et Installe.
- Detection et affichage du mode dans l interface.
- Bouton Installer SENETECH sur ce PC.
- Installation dans C:\Program Files\SENETECH.
- Raccourcis Bureau et Menu Demarrer.
- Entree Windows Applications installees et desinstallation integree.
- Option d installation automatique de SENETECH en fin de preparation.
- Les caches lourds de la cle ne sont pas recopies dans Program Files.
- Portable et Installe utilisent le meme version.json et le meme GitHub.
- En mode Installe, verification automatique des mises a jour au lancement.

"@
    Write-Utf8Bom $changelogPath ($entry + $changelog)
}

$verify = [System.IO.File]::ReadAllText($enginePath)
if ($verify -notmatch "AppVersion = '1\.5\.0\.0'") { throw 'Verification de la version V1.5.0 impossible.' }
if ($verify -notmatch 'Install-SenetechOnThisPc') { throw 'Fonction installation SENETECH absente.' }
exit 0
