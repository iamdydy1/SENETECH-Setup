param(
    [Parameter(Mandatory=$true)]
    [string]$StageDir
)

$ErrorActionPreference = 'Stop'
$ExpectedSourceSha256 = '15bdb389078e93467bbb2ed8abb4d4a8d7a0a099ec61a17551573983639d532c'
$BaseUrl = 'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/main/packages/v1.5.0'

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
$headers = @{ 'User-Agent' = 'SENETECH-Setup/1.5.0-patcher' }
$builder = New-Object System.Text.StringBuilder

for ($i = 1; $i -le 9; $i++) {
    $name = ('engine-part{0:D2}.txt' -f $i)
    $url = "$BaseUrl/$name"
    $text = (Invoke-WebRequest -Uri $url -Headers $headers -UseBasicParsing).Content
    [void]$builder.Append([string]$text)
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$engineBytes = $utf8.GetBytes($builder.ToString())
$sha = [System.Security.Cryptography.SHA256]::Create()
try {
    $actual = ([System.BitConverter]::ToString($sha.ComputeHash($engineBytes))).Replace('-', '').ToLowerInvariant()
} finally {
    $sha.Dispose()
}
if ($actual -ne $ExpectedSourceSha256) {
    throw "Le moteur V1.5.0 reconstruit depuis GitHub est invalide (SHA-256 $actual)."
}

$enginePath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.ps1'
if (-not (Test-Path -LiteralPath (Split-Path -Parent $enginePath))) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $enginePath) | Out-Null
}
[System.IO.File]::WriteAllBytes($enginePath, $engineBytes)

function Replace-BytePattern([byte[]]$Data, [byte[]]$Old, [byte[]]$New) {
    if ($Old.Length -ne $New.Length) { throw 'Le remplacement binaire doit conserver la meme longueur.' }
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

$exePath = Join-Path $StageDir 'SENETECH-Setup.exe'
if (-not (Test-Path -LiteralPath $exePath)) { throw 'SENETECH-Setup.exe est absent du package de base.' }
$exeBytes = [System.IO.File]::ReadAllBytes($exePath)
$ascii = [System.Text.Encoding]::ASCII
$unicode = [System.Text.Encoding]::Unicode
$null = Replace-BytePattern $exeBytes ($ascii.GetBytes('1.4.2.0')) ($ascii.GetBytes('1.5.0.0'))
$null = Replace-BytePattern $exeBytes ($unicode.GetBytes('1.4.2.0')) ($unicode.GetBytes('1.5.0.0'))
$null = Replace-BytePattern $exeBytes ($ascii.GetBytes('1.4.3.0')) ($ascii.GetBytes('1.5.0.0'))
$null = Replace-BytePattern $exeBytes ($unicode.GetBytes('1.4.3.0')) ($unicode.GetBytes('1.5.0.0'))
[System.IO.File]::WriteAllBytes($exePath, $exeBytes)

$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [System.IO.File]::ReadAllText($manifestPath)
    $manifestText = $manifestText.Replace('1.4.2.0', '1.5.0.0').Replace('1.4.3.0', '1.5.0.0')
    [System.IO.File]::WriteAllText($manifestPath, $manifestText, $utf8)
}

$versionText = @"
SENETECH Setup
Version 1.5.0.0
Canal : Test GitHub
Architecture : Windows 10 / 11
Mode : Portable + installation Windows integree
"@
[System.IO.File]::WriteAllText((Join-Path $StageDir 'VERSION.txt'), $versionText.TrimStart(), $utf8)

$engineVerify = [System.IO.File]::ReadAllText($enginePath)
if ($engineVerify -notmatch "AppVersion = '1\.5\.0\.0'") { throw 'La version du moteur V1.5.0 est introuvable.' }
if ($engineVerify -notmatch 'Install-SenetechOnThisPc') { throw 'Le mode installe V1.5.0 est absent.' }
if ($engineVerify -notmatch 'ModeHeaderText') { throw 'L indicateur Portable / Installe est absent.' }

exit 0
