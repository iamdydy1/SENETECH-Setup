@echo off
setlocal
title SENETECH - Reporter Developer Test
set "SCRIPT=%~dp0_SENETECH\Tools\SENETECH-REPORTER-TEST.ps1"
if not exist "%SCRIPT%" set "SCRIPT=%~dp0dist\runtime\_SENETECH\Tools\SENETECH-REPORTER-TEST.ps1"
if not exist "%SCRIPT%" set "SCRIPT=%~dp0src\Tools\SENETECH-REPORTER-TEST.ps1"
if not exist "%SCRIPT%" (
  echo [SENETECH] Outil Reporter introuvable.
  echo Recherches:
  echo   %~dp0_SENETECH\Tools\SENETECH-REPORTER-TEST.ps1
  echo   %~dp0dist\runtime\_SENETECH\Tools\SENETECH-REPORTER-TEST.ps1
  echo   %~dp0src\Tools\SENETECH-REPORTER-TEST.ps1
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%SCRIPT%"
set "RC=%ERRORLEVEL%"
echo.
echo Code Reporter: %RC%
echo Journal: C:\ProgramData\SENETECH\Logs\Developer\SENETECH-Reporter-Test.log
pause
exit /b %RC%
