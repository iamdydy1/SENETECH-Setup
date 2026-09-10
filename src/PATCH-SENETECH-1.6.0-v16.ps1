param(
    [Parameter(Mandatory=$true)][string]$StageDir
)

$ErrorActionPreference = 'Stop'

# Apply previous V1.6.0.13 patch first.
$previousPatch = Join-Path $env:TEMP 'SENETECH-PATCH-1.6.0-v15.ps1'
$previousPatchUrl = 'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/develop/src/PATCH-SENETECH-1.6.0-v15.ps1'
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

function Replace-Once([string]$Text,[string]$Old,[string]$New,[string]$Label) {
    $index = $Text.IndexOf($Old,[StringComparison]::Ordinal)
    if ($index -lt 0) { throw ('Patch V1.6.0.14 impossible : marqueur absent - ' + $Label) }
    return $Text.Substring(0,$index) + $New + $Text.Substring($index + $Old.Length)
}

# Load validation overrides after the French UI layer, before initialization.
$needle = ". `$frenchUiModule`r`nInitialize-SenetechV16Features"
if (-not $engineText.Contains($needle)) { $needle = ". `$frenchUiModule`nInitialize-SenetechV16Features" }
if (-not $engineText.Contains($needle)) { throw 'Patch V1.6.0.14 impossible : point de chargement validation introuvable.' }
$replacement = ". `$frenchUiModule`r`n`$validationModule = Join-Path `$script:EngineDir 'Modules\Senetech.Validation.ps1'`r`nif (-not (Test-Path -LiteralPath `$validationModule)) { throw 'Module validation SENETECH V1.6.0.14 introuvable.' }`r`n. `$validationModule`r`nInitialize-SenetechV16Features"
$engineText = $engineText.Replace($needle,$replacement)

# Every preparation now creates a verified state snapshot before modifications.
$old = @'
        Set-Progress 3 'Preparation'
        if ($script:CreateRestoreCheck.IsChecked -eq $true) {
            Set-Progress 6 'Point de restauration'
            [void](New-SenetechRestorePoint ('Avant preparation SENETECH ' + $script:DisplayVersion))
        }
        if (-not $script:Hardware) {
'@
$new = @'
        Set-Progress 3 (Get-SenetechValidationText 'Sauvegarde d''{eacute}tat avant pr{eacute}paration')
        $script:PreparationBackupPath = New-SenetechPreparationBackup -SelectedApps $selectedApps
        $script:RestorePointCreated = $false
        if ($script:CreateRestoreCheck.IsChecked -eq $true) {
            Set-Progress 6 'Point de restauration'
            $script:RestorePointCreated = [bool](New-SenetechRestorePoint ('Avant preparation SENETECH ' + $script:DisplayVersion))
        }
        Set-Progress 8 (Get-SenetechValidationText 'V{eacute}rification des pr{eacute}requis')
        $preflight = Invoke-SenetechPreparationPreflight -SelectedApps $selectedApps
        if (-not $preflight.Passed) {
            $failureText = @($preflight.Failures) -join "`n - "
            throw (Get-SenetechValidationText ("V{eacute}rification initiale bloquante :`n - " + $failureText))
        }
        if (-not $script:Hardware) {
'@
$engineText = Replace-Once $engineText $old.TrimEnd("`r","`n") $new.TrimEnd("`r","`n") 'backup et preflight'

# Final validation is performed after all requested preparation actions and before
# the report is generated, so failures are visible in the report notes.
$old = @'
        Set-Progress 85 'Controle final'
        $script:Hardware = Get-HardwareSnapshot
        Update-HardwareUi $script:Hardware
        if ($DiagnosticCheck.IsChecked -eq $true) {
'@
$new = @'
        Set-Progress 85 (Get-SenetechValidationText 'Contr{ocirc}le final')
        $script:Hardware = Get-HardwareSnapshot
        Update-HardwareUi $script:Hardware
        $script:LastValidation = Invoke-SenetechPreparationValidation -SelectedApps $selectedApps -AppResults $script:AppResults -Hardware $script:Hardware
        foreach ($validationWarning in @($script:LastValidation.Warnings)) {
            $script:OperationNotes += (Get-SenetechValidationText ('CHECK FINAL - Attention : {0}' -f $validationWarning))
        }
        foreach ($validationFailure in @($script:LastValidation.Failures)) {
            $script:OperationNotes += (Get-SenetechValidationText ('CHECK FINAL - Echec : {0}' -f $validationFailure))
        }
        if ($DiagnosticCheck.IsChecked -eq $true) {
'@
$engineText = Replace-Once $engineText $old.TrimEnd("`r","`n") $new.TrimEnd("`r","`n") 'controle final'

# Never announce a fully successful preparation when the final verification found
# a missing application or another blocking problem.
$old = @'
        Set-Progress 100 'Preparation terminee'
        Write-Log 'Preparation SENETECH terminee. Verifiez le rapport et redemarrez manuellement le PC.' 'OK'
        Add-SenetechHistory 'Preparation PC terminee' 'OK' $script:CurrentProfileName
        $endMessage = if ($script:RebootRequired) { 'Preparation terminee. Un redemarrage est recommande.' } elseif (-not $online) { 'Preparation hors ligne terminee. Consultez le rapport : certaines mises a jour peuvent rester a faire avec Internet.' } else { 'Preparation terminee. Aucun redemarrage impose par Windows Update.' }
        [System.Windows.MessageBox]::Show($endMessage, 'SENETECH Setup') | Out-Null
'@
$new = @'
        if ($script:LastValidation -and -not $script:LastValidation.Passed) {
            Set-Progress 100 (Get-SenetechValidationText 'CHECK FINAL : {agrave} corriger')
            Write-Log (Get-SenetechValidationText ('Pr{eacute}paration termin{eacute}e avec {0} erreur(s) de validation. Le PC n''est pas encore valid{eacute} pour livraison.' -f $script:LastValidation.Failures.Count)) 'ERREUR'
            Add-SenetechHistory 'Preparation PC terminee' 'ERREUR' ("validationFailures=$($script:LastValidation.Failures.Count)")
            $failureText = @($script:LastValidation.Failures | Select-Object -First 10) -join "`n - "
            [System.Windows.MessageBox]::Show((Get-SenetechValidationText ("La pr{eacute}paration est termin{eacute}e, mais le contr{ocirc}le final a trouv{eacute} des points bloquants :`n`n - " + $failureText + "`n`nCorrigez-les avant la livraison.")), 'SENETECH - Controle final', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        } else {
            Set-Progress 100 (Get-SenetechValidationText 'Pr{eacute}paration valid{eacute}e')
            $warningCount = if ($script:LastValidation) { @($script:LastValidation.Warnings).Count } else { 0 }
            Write-Log (Get-SenetechValidationText ('Pr{eacute}paration SENETECH valid{eacute}e. Contr{ocirc}le final termin{eacute} avec {0} avertissement(s).' -f $warningCount)) 'OK'
            Add-SenetechHistory 'Preparation PC terminee' 'OK' ("profil=$($script:CurrentProfileName) warnings=$warningCount")
            $endMessage = if ($script:RebootRequired) { (Get-SenetechValidationText 'Pr{eacute}paration valid{eacute}e. Un red{eacute}marrage est recommand{eacute}.') } elseif (-not $online) { (Get-SenetechValidationText 'Pr{eacute}paration hors ligne valid{eacute}e avec avertissements. Consultez le rapport avant livraison.') } elseif ($warningCount -gt 0) { (Get-SenetechValidationText ("Pr{eacute}paration valid{eacute}e avec $warningCount avertissement(s). Consultez le rapport.")) } else { (Get-SenetechValidationText 'Pr{eacute}paration valid{eacute}e. Tous les contr{ocirc}les bloquants sont OK.') }
            [System.Windows.MessageBox]::Show($endMessage, 'SENETECH Setup') | Out-Null
        }
'@
$engineText = Replace-Once $engineText $old.TrimEnd("`r","`n") $new.TrimEnd("`r","`n") 'message final valide'

$engineText = $engineText.Replace("`$script:AppVersion = '1.6.0.13'", "`$script:AppVersion = '1.6.0.14'")
$engineText = $engineText.Replace("`$script:DisplayVersion = '1.6.0 DEV - build 13'", "`$script:DisplayVersion = '1.6.0 DEV - build 14'")
$engineText = $engineText.Replace('Title="SENETECH Setup V1.6.0 DEV - build 13"','Title="SENETECH Setup V1.6.0 DEV - build 14"')
$engineText = $engineText.Replace('VERSION 1.6.0 DEV - BUILD 13" Foreground','VERSION 1.6.0 DEV - BUILD 14" Foreground')
$engineText = $engineText.Replace('SENETECH Setup V1.6.0 DEV - build 13 demarre','SENETECH Setup V1.6.0 DEV - build 14 demarre')
[IO.File]::WriteAllText($enginePath,$engineText,$utf8Bom)

$manifestPath = Join-Path $StageDir '_SENETECH\SENETECH-Setup.manifest'
if (Test-Path -LiteralPath $manifestPath) {
    $manifestText = [IO.File]::ReadAllText($manifestPath,$utf8NoBom)
    $manifestText = $manifestText.Replace('version="1.6.0.13"','version="1.6.0.14"')
    [IO.File]::WriteAllText($manifestPath,$manifestText,$utf8NoBom)
}

Set-Content -LiteralPath (Join-Path $StageDir 'VERSION.txt') -Encoding UTF8 -Value @'
SENETECH Setup
Version 1.6.0.14
Affichage : 1.6.0 DEV - build 14
Canal : Developpeur
Branche : develop
Windows : 10 / 11
Mode : Portable + Installe
Mises a jour : GitHub + SHA-256 + rollback
Nouveau : sauvegarde d etat obligatoire + preflight + verification installation + controle final global
'@

Write-Output 'SENETECH V1.6.0 DEV build 14 - validation complete du workflow appliquee.'
