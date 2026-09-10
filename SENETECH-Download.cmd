@echo off
setlocal EnableExtensions
chcp 65001 >nul
color 0B
title SENETECH Setup - Installation Stable

set "TARGET=%USERPROFILE%\Downloads\SENETECH-Setup"
set "UPDATER=%TEMP%\SENETECH-UPDATE-BOOTSTRAP.ps1"
set "UPDATER_URL=https://raw.githubusercontent.com/iamdydy1/SENETECH-Setup/main/UPDATE-SENETECH.ps1"

echo.
echo ============================================================
echo   SENETECH SETUP - DERNIERE VERSION STABLE
echo ============================================================
echo.
echo Destination : %TARGET%
echo Canal       : Stable

echo [1/2] Recuperation du service de mise a jour...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri '%UPDATER_URL%' -OutFile '%UPDATER%'; exit 0 } catch { Write-Host $_.Exception.Message; exit 1 }"
if errorlevel 1 goto :error_download

echo [2/2] Telechargement, verification SHA-256 et installation...
if not exist "%TARGET%" mkdir "%TARGET%" >nul 2>&1
if errorlevel 1 goto :error_folder

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%UPDATER%" -CurrentVersion "0.0.0.0" -InstallDir "%TARGET%" -UpdateChannel "stable"
set "RC=%ERRORLEVEL%"
del /f /q "%UPDATER%" >nul 2>&1

if "%RC%"=="10" goto :success
if "%RC%"=="0" goto :success

echo.
echo [ERREUR] SENETECH n'a pas pu etre prepare correctement.
echo Journal : %%TEMP%%\SENETECH-Update.log
pause
exit /b 1

:success
echo.
echo [OK] SENETECH Stable est pret.
echo L'application va se lancer automatiquement.
timeout /t 3 /nobreak >nul
exit /b 0

:error_folder
echo [ERREUR] Impossible de creer : %TARGET%
pause
exit /b 1

:error_download
echo [ERREUR] Impossible de contacter GitHub.
echo Verifiez votre connexion Internet puis recommencez.
pause
exit /b 1
