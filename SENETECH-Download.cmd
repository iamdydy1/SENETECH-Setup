@echo off
setlocal EnableExtensions
chcp 65001 >nul
color 0B
title SENETECH Setup - Installation Stable

:: SENETECH bootstrap for USB / fresh Windows machines.
:: The default deployment is the INSTALLED Stable version, never the portable copy.

net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo [INFO] Droits administrateur requis. Ouverture de la demande UAC...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "TARGET=%ProgramFiles%\SENETECH"
set "UPDATER=%TEMP%\SENETECH-UPDATE-BOOTSTRAP.ps1"
set "UPDATER_URL=https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/main/UPDATE-SENETECH.ps1"

echo.
echo ============================================================
echo   SENETECH SETUP - INSTALLATION STABLE
echo ============================================================
echo.
echo Destination : %TARGET%
echo Mode        : INSTALLE
echo Canal       : Stable
echo.
echo La copie USB reste uniquement un support d'installation/secours.
echo La copie utilisee sur ce PC sera installee dans Program Files.
echo.

echo [1/3] Recuperation du service de mise a jour Stable...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri '%UPDATER_URL%' -OutFile '%UPDATER%'; exit 0 } catch { Write-Host $_.Exception.Message; exit 1 }"
if errorlevel 1 goto :error_download

echo [2/3] Telechargement et verification de la derniere version Stable...
if not exist "%TARGET%" mkdir "%TARGET%" >nul 2>&1
if errorlevel 1 goto :error_folder

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%UPDATER%" -CurrentVersion "0.0.0.0" -InstallDir "%TARGET%" -UpdateChannel "stable"
set "RC=%ERRORLEVEL%"
del /f /q "%UPDATER%" >nul 2>&1

if "%RC%"=="10" goto :success
if "%RC%"=="0" goto :success

echo.
echo [ERREUR] SENETECH n'a pas pu etre installe correctement.
echo Journal : %%TEMP%%\SENETECH-Update.log
pause
exit /b 1

:success
echo [3/3] Installation terminee.
echo.
echo [OK] SENETECH Stable est installe dans :
echo      %TARGET%
echo.
echo SENETECH va demarrer en MODE INSTALLE et conservera les mises a jour GitHub.
timeout /t 4 /nobreak >nul
exit /b 0

:error_folder
echo [ERREUR] Impossible de creer : %TARGET%
echo Verifiez les droits administrateur.
pause
exit /b 1

:error_download
echo [ERREUR] Impossible de contacter GitHub.
echo Verifiez la connexion Internet puis recommencez.
pause
exit /b 1
