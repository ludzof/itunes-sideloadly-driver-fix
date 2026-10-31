@echo off
setlocal EnableDelayedExpansion

:: Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Requesting Administrator privileges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: Run the PowerShell fixer script in the same directory
echo ========================================================
echo       Apple USB Driver Fixer for iTunes and Sideloadly
echo ========================================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Fix-Apple-Driver.ps1"

echo.
echo Press any key to exit...
pause >nul
