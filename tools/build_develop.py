from __future__ import annotations
import argparse, hashlib, json, shutil, tempfile, urllib.request, zipfile
from pathlib import Path

VERSION = '1.6.0.0'
DISPLAY = '1.6.0 DEV'
PACKAGE = 'SENETECH-Setup-V1.6.0-DEV.zip'
BASE_URL = 'https://github.com/iamdydy1/SENETECH-Setup/releases/download/1.5.1/SENETECH-Setup-V1.5.1-FULL-STABLE.zip'


def replace_once(text: str, old: str, new: str) -> str:
    if old not in text:
        raise RuntimeError(f'Build patch target not found: {old[:100]!r}')
    return text.replace(old, new, 1)


def patch_engine(path: Path) -> None:
    s = path.read_text(encoding='utf-8-sig')
    s = s.replace('# SENETECH Setup V1.5.1 - Windows 10 and 11 preparation assistant', '# SENETECH Setup V1.6.0 DEV - Windows 10 and 11 preparation assistant')
    s = s.replace("$script:AppVersion = '1.5.1.0'", "$script:AppVersion = '1.6.0.0'")
    s = s.replace("$script:DisplayVersion = '1.5.1'", "$script:DisplayVersion = '1.6.0 DEV'")
    s = s.replace('Title="SENETECH Setup V1.5.1"', 'Title="SENETECH Setup V1.6.0 DEV"')
    s = s.replace('VERSION 1.5.1" Foreground', 'VERSION 1.6.0 DEV" Foreground')
    s = s.replace('SENETECH Setup V1.5.1 demarre', 'SENETECH Setup V1.6.0 DEV demarre')
    s = replace_once(s, '<ScrollViewer Grid.Column="0" VerticalScrollBarVisibility="Auto" Margin="0,0,10,0">\n        <StackPanel>', '<ScrollViewer Grid.Column="0" VerticalScrollBarVisibility="Auto" Margin="0,0,10,0">\n        <StackPanel x:Name="LeftPanel">')
    s = replace_once(s, '</ComboBox>\n              <WrapPanel>', '</ComboBox>\n              <WrapPanel x:Name="AppsPanel">')
    s = replace_once(s, "$names = @('BrandLogo','StatusBadge','PcText','CpuText','RamText','GpuText','WindowsText','InternetText','ProfileCombo',", "$names = @('BrandLogo','StatusBadge','PcText','CpuText','RamText','GpuText','WindowsText','InternetText','ProfileCombo','LeftPanel','AppsPanel',")
    s = s.replace('x:Name="StartButton" Content="COMMENCER"', 'x:Name="StartButton" Content="PR&#201;PARER CE PC"')

    module_block = """
# V1.6 features are modular so the catalog and technician tools can evolve independently.
$catalogModule = Join-Path $script:EngineDir 'Modules\\Senetech.Catalog.ps1'
$technicianModule = Join-Path $script:EngineDir 'Modules\\Senetech.Technician.ps1'
if (-not (Test-Path -LiteralPath $catalogModule)) { throw 'Module catalogue SENETECH V1.6 introuvable.' }
if (-not (Test-Path -LiteralPath $technicianModule)) { throw 'Module technicien SENETECH V1.6 introuvable.' }
. $catalogModule
. $technicianModule
Initialize-SenetechV16Features

"""
    s = replace_once(s, '$SettingsButton.Add_Click({', module_block + '$SettingsButton.Add_Click({')
    s = replace_once(s, "    if ($DiagnosticCheck.IsChecked -eq $true) { $summary += 'Diagnostic et rapport' }\n", "    if ($DiagnosticCheck.IsChecked -eq $true) { $summary += 'Diagnostic et rapport' }\n    if ($script:CreateRestoreCheck.IsChecked -eq $true) { $summary += 'Point de restauration Windows avant modifications' }\n    if ($script:UpdateInstalledAppsCheck.IsChecked -eq $true) { $summary += 'Mise a jour des applications deja installees' }\n    if ($script:ApplyTweaksCheck.IsChecked -eq $true) { $summary += ('Optimisations reversibles du profil ' + $script:CurrentProfileName) }\n    if ($script:CleanupAfterCheck.IsChecked -eq $true) { $summary += 'Nettoyage des fichiers temporaires' }\n")
    s = replace_once(s, "        Set-Progress 3 'Preparation'\n        if (-not $script:Hardware) {", "        Set-Progress 3 'Preparation'\n        if ($script:CreateRestoreCheck.IsChecked -eq $true) {\n            Set-Progress 6 'Point de restauration'\n            [void](New-SenetechRestorePoint ('Avant preparation SENETECH ' + $script:DisplayVersion))\n        }\n        if (-not $script:Hardware) {")
    s = replace_once(s, "        if ($online -and ($UpdatesCheck.IsChecked -eq $true -or $DriversCheck.IsChecked -eq $true)) {\n", "        if ($online -and $script:UpdateInstalledAppsCheck.IsChecked -eq $true) {\n            Set-Progress 45 'Mise a jour des applications installees'\n            $script:AppResults += @(Invoke-SenetechAppUpdates)\n        } elseif (-not $online -and $script:UpdateInstalledAppsCheck.IsChecked -eq $true) {\n            $script:OperationNotes += 'Mise a jour des applications ignoree : Internet indisponible.'\n        }\n        if ($online -and ($UpdatesCheck.IsChecked -eq $true -or $DriversCheck.IsChecked -eq $true)) {\n")
    s = replace_once(s, "        Set-Progress 85 'Controle final'\n        $script:Hardware = Get-HardwareSnapshot", "        if ($script:ApplyTweaksCheck.IsChecked -eq $true) {\n            Set-Progress 80 'Optimisations du profil'\n            Apply-SenetechProfileOptimizations $script:CurrentProfileName\n        }\n        if ($script:CleanupAfterCheck.IsChecked -eq $true) {\n            Set-Progress 83 'Nettoyage Windows'\n            [void](Invoke-SenetechCleanup)\n        }\n        Set-Progress 85 'Controle final'\n        $script:Hardware = Get-HardwareSnapshot")
    s = replace_once(s, "        Write-Log 'Preparation SENETECH terminee. Verifiez le rapport et redemarrez manuellement le PC.' 'OK'\n", "        Write-Log 'Preparation SENETECH terminee. Verifiez le rapport et redemarrez manuellement le PC.' 'OK'\n        Add-SenetechHistory 'Preparation PC terminee' 'OK' $script:CurrentProfileName\n")
    s = replace_once(s, "    $designed = $null\n    $full = $null\n    try {\n        $designed = @(Get-CimInstance -Namespace root/WMI -ClassName BatteryStaticData -ErrorAction Stop | Select-Object -First 1).DesignedCapacity\n        $full = @(Get-CimInstance -Namespace root/WMI -ClassName BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1).FullChargedCapacity\n    } catch { }", "    $designed = $null\n    $full = $null\n    $cycles = $null\n    try {\n        $designed = @(Get-CimInstance -Namespace root/WMI -ClassName BatteryStaticData -ErrorAction Stop | Select-Object -First 1).DesignedCapacity\n        $full = @(Get-CimInstance -Namespace root/WMI -ClassName BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1).FullChargedCapacity\n    } catch { }\n    try {\n        $cycles = @(Get-CimInstance -Namespace root/WMI -ClassName BatteryCycleCount -ErrorAction Stop | Select-Object -First 1).CycleCount\n    } catch { }")
    s = replace_once(s, "        FullChargeCapacity = $full\n        HealthPercent = $health", "        FullChargeCapacity = $full\n        HealthPercent = $health\n        CycleCount = $cycles")
    s = replace_once(s, "        DeviceErrors = $errors\n    }", "        DeviceErrors = $errors\n        Security = Get-SenetechSecuritySnapshot\n    }")
    s = replace_once(s, '        $healthText = if ($null -ne $info.Battery.HealthPercent) { " - sante estimee : $($info.Battery.HealthPercent)%" } else { \'\' }\n        "Detectee - charge : $($info.Battery.Charge)%$healthText"', '        $healthText = if ($null -ne $info.Battery.HealthPercent) { " - sante estimee : $($info.Battery.HealthPercent)%" } else { \'\' }\n        $cycleText = if ($null -ne $info.Battery.CycleCount) { " - cycles : $($info.Battery.CycleCount)" } else { \'\' }\n        "Detectee - charge : $($info.Battery.Charge)%$healthText$cycleText"')
    s = replace_once(s, '<tr><th>Batterie</th><td>$(Convert-Html $batteryText)</td></tr></table>', '<tr><th>Batterie</th><td>$(Convert-Html $batteryText)</td></tr>\n<tr><th>TPM</th><td>$(Convert-Html $info.Security.TPM)</td></tr><tr><th>Secure Boot</th><td>$(Convert-Html $info.Security.SecureBoot)</td></tr>\n<tr><th>Disque systeme</th><td>$(Convert-Html $info.Security.SystemDrive)</td></tr><tr><th>Elements au demarrage</th><td>$($info.Security.StartupCount)</td></tr></table>')
    s = replace_once(s, "    $script:DiagnosticCheck.IsEnabled = $Enabled\n    if (-not $script:IsInstalledMode) {", "    $script:DiagnosticCheck.IsEnabled = $Enabled\n    foreach ($controlName in @('UpdateAppsButton','CleanupButton','StartupButton','RefreshCatalogButton','UndoTweaksButton','RollbackButton','CreateRestoreCheck','ApplyTweaksCheck','UpdateInstalledAppsCheck','CleanupAfterCheck','OptionalUpdatesCheck')) {\n        $v = Get-Variable -Name $controlName -Scope Script -ErrorAction SilentlyContinue\n        if ($v -and $null -ne $v.Value) { $v.Value.IsEnabled = $Enabled }\n    }\n    if (-not $script:IsInstalledMode) {")
    path.write_text(s, encoding='utf-8-sig')


def build(repo: Path, base_zip: Path | None) -> tuple[Path, int, str]:
    dist = repo / 'dist'; dist.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix='senetech-build-'))
    try:
        base = base_zip or work / 'base.zip'
        if base_zip is None: urllib.request.urlretrieve(BASE_URL, base)
        runtime = work / 'runtime'; runtime.mkdir()
        with zipfile.ZipFile(base) as z: z.extractall(runtime)
        patch_engine(runtime / '_SENETECH' / 'SENETECH-Setup.ps1')
        modules = runtime / '_SENETECH' / 'Modules'; modules.mkdir(parents=True, exist_ok=True)
        shutil.copy2(repo/'src'/'Modules'/'Senetech.Catalog.ps1', modules/'Senetech.Catalog.ps1')
        shutil.copy2(repo/'src'/'Modules'/'Senetech.Technician.ps1', modules/'Senetech.Technician.ps1')
        shutil.copy2(repo/'src'/'Moteur-WindowsUpdate.ps1', runtime/'_SENETECH'/'Moteur-WindowsUpdate.ps1')
        catalog = runtime/'_SENETECH'/'Catalog'; catalog.mkdir(parents=True, exist_ok=True)
        shutil.copy2(repo/'catalog'/'apps.json', catalog/'apps.json'); shutil.copy2(repo/'catalog'/'profiles.json', catalog/'profiles.json')
        manifest = runtime/'_SENETECH'/'SENETECH-Setup.manifest'; manifest.write_text(manifest.read_text(encoding='utf-8').replace('version="1.5.1.0"','version="1.6.0.0"'), encoding='utf-8')
        (runtime/'VERSION.txt').write_text('SENETECH Setup\nVersion 1.6.0.0\nAffichage : 1.6.0 DEV\nCanal : Developpeur\nBranche : develop\nWindows : 10 / 11\nMode : Portable + Installe\nMises a jour : GitHub + SHA-256 + rollback\n', encoding='utf-8')
        (runtime/'LISEZ-MOI.txt').write_text('SENETECH Setup V1.6.0 DEV\n\nVersion de test du canal Developpeur. Ne pas distribuer aux clients avant validation.\n', encoding='utf-8')
        (runtime/'CHANGELOG.txt').write_text('SENETECH Setup V1.6.0 DEV\n\nCatalogue dynamique, nouveaux profils, mise a jour applications, restauration, optimisations reversibles, nettoyage, demarrage Windows, Windows Update avance, diagnostics enrichis, historique et rollback.\n', encoding='utf-8')
        out = dist / PACKAGE
        if out.exists(): out.unlink()
        with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
            for file in sorted(runtime.rglob('*')):
                if file.is_file(): z.write(file, file.relative_to(runtime))
        data = out.read_bytes(); sha = hashlib.sha256(data).hexdigest(); size = len(data)
        manifest_data = {'product':'SENETECH Setup','channel':'develop','version':VERSION,'displayVersion':DISPLAY,'enabled':True,'mandatory':False,'downloadUrl':f'https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/develop/dist/{PACKAGE}','packageSize':size,'sha256':sha,'releaseNotes':['SENETECH V1.6.0 DEV','Mode Technicien et PREPARER CE PC','Catalogue applications/profils dynamique','Mise a jour applications via WinGet','Point de restauration et optimisations reversibles','Nettoyage et gestion du demarrage Windows','Windows Update avance','Diagnostics et rapports enrichis','Rollback automatique de SENETECH']}
        (repo/'version.json').write_text(json.dumps(manifest_data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
        (dist/'SENETECH-Setup-V1.6.0-DEV.sha256').write_text(f'{sha}  {PACKAGE}\n', encoding='ascii')
        return out, size, sha
    finally: shutil.rmtree(work, ignore_errors=True)

if __name__ == '__main__':
    ap=argparse.ArgumentParser(); ap.add_argument('--repo',type=Path,default=Path.cwd()); ap.add_argument('--base-zip',type=Path)
    a=ap.parse_args(); out,size,sha=build(a.repo.resolve(), a.base_zip.resolve() if a.base_zip else None)
    print(f'Built {out} size={size} sha256={sha}')
