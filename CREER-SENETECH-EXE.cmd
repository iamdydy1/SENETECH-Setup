@echo off
setlocal
cd /d "%~dp0"
echo Creation de l'application officielle SENETECH Setup...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0_SENETECH\Construire-Application.ps1"
if errorlevel 1 (
    echo.
    echo La creation a echoue. Consultez le message affiche ci-dessus.
    pause
    exit /b 1
)
echo.
echo SENETECH-Setup.exe est pret a la racine de la cle.
pause

