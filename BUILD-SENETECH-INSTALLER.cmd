@echo off
setlocal
cd /d "%~dp0"
title SENETECH - Build installateur Inno Setup

echo.
echo ============================================================
echo  SENETECH - CONSTRUCTION INSTALLATEUR COMPLET
echo ============================================================
echo.
echo Source : GitHub / version.json local
echo Sortie : dist\installer
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Build-SenetechInstallerFromManifest.ps1"
set "RC=%ERRORLEVEL%"

echo.
if not "%RC%"=="0" (
  echo [ERREUR] Le build SENETECH a echoue. Code: %RC%
  echo.
  pause
  exit /b %RC%
)

echo [OK] L installateur SENETECH a ete genere.
echo.
pause
exit /b 0
