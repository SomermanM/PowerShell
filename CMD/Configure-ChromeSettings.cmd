@echo off
REM SYNOPSIS: Standalone .cmd - imports Configure-ChromeSettings.reg (Chrome policies in HKLM\SOFTWARE\Policies\Google\Chrome: home page, new tab page and startup URL = mymetro2, Home button on, Google default search). Log in C:\Temp.
REM Type: standalone .cmd, self-elevates (UAC). OS: Windows. Finds Configure-ChromeSettings.reg beside it, else ..\Canned Script\. Restart Chrome after it runs.
REM BeyondTrust twin: Canned Script "Configure-ChromeSettings" (resource Canned Script\Configure-ChromeSettings.reg, command sequence Command Sequence\Configure-ChromeSettings.txt, elevated only).
setlocal
set "REGFILE=%~dp0Configure-ChromeSettings.reg"
if not exist "%REGFILE%" set "REGFILE=%~dp0..\Canned Script\Configure-ChromeSettings.reg"
if not exist "%REGFILE%" (
    echo Configure-ChromeSettings.reg not found beside this file or in "%~dp0..\Canned Script\"
    pause
    exit /b 2
)

net session >nul 2>&1
if errorlevel 1 (
    if /i "%~1"=="__CCS_ELEV__" (
        echo Still not running as administrator. Right-click and Run as administrator.
        pause
        exit /b 1
    )
    echo Requesting administrator rights...
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '__CCS_ELEV__' -Verb RunAs"
    exit /b 0
)

if not exist "C:\Temp" md "C:\Temp"
set "LOG=C:\Temp\Configure-ChromeSettings.log"
echo [%DATE% %TIME%] reg import "%REGFILE%" >> "%LOG%"
reg import "%REGFILE%" /reg:64 >> "%LOG%" 2>&1
set "RC=%ERRORLEVEL%"
echo [%DATE% %TIME%] exit code %RC% >> "%LOG%"
echo.
echo Configure-ChromeSettings finished with exit code %RC%. Restart Chrome to apply. Log: %LOG%
pause
exit /b %RC%
