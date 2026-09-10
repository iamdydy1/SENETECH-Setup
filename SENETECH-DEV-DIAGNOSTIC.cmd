@echo off
setlocal
title SENETECH - Diagnostic Developer
set "SCRIPT=%~dp0_SENETECH\Tools\SENETECH-DEV-DIAGNOSTIC.ps1"
if not exist "%SCRIPT%" set "SCRIPT=%~dp0dist\runtime\_SENETECH\Tools\SENETECH-DEV-DIAGNOSTIC.ps1"
if not exist "%SCRIPT%" set "SCRIPT=%~dp0src\Tools\SENETECH-DEV-DIAGNOSTIC.ps1"
if not exist "%SCRIPT%" (
  echo [SENETECH] Outil diagnostic introuvable.
  echo Recherches:
  echo   %~dp0_SENETECH\Tools\SENETECH-DEV-DIAGNOSTIC.ps1
  echo   %~dp0dist\runtime\_SENETECH\Tools\SENETECH-DEV-DIAGNOSTIC.ps1
  echo   %~dp0src\Tools\SENETECH-DEV-DIAGNOSTIC.ps1
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%SCRIPT%"
set "RC=%ERRORLEVEL%"
echo.
echo Code diagnostic: %RC%
echo Les bundles sont dans C:\ProgramData\SENETECH\Logs\Developer
pause
exit /b %RC%
