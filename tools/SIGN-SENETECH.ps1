param(
    [Parameter(Mandatory=$true)][string]$CertificateThumbprint,
    [string]$ExePath = '.\dist\SENETECH-Setup.exe',
    [string]$TimestampUrl = 'http://timestamp.digicert.com'
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $ExePath)) { throw "Fichier introuvable : $ExePath" }
$cert = Get-ChildItem Cert:\CurrentUser\My, Cert:\LocalMachine\My -CodeSigningCert -ErrorAction SilentlyContinue |
    Where-Object { $_.Thumbprint -eq $CertificateThumbprint } | Select-Object -First 1
if (-not $cert) { throw 'Certificat de signature de code introuvable.' }
$result = Set-AuthenticodeSignature -FilePath $ExePath -Certificate $cert -TimestampServer $TimestampUrl -HashAlgorithm SHA256
if ($result.Status -ne 'Valid') { throw "Signature non valide : $($result.Status) $($result.StatusMessage)" }
Write-Host "SENETECH signe : $ExePath" -ForegroundColor Green
