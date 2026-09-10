@echo off
setlocal
set "SCRIPT=%~dp0_SENETECH\Tools\SENETECH-DEV-DIAGNOSTIC.ps1"
if not exist "%SCRIPT%" (
  echo [SENETECH] Outil diagnostic introuvable:
  echo %SCRIPT%
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
