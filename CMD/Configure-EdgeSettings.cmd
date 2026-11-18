@echo off
REM SYNOPSIS: Standalone .cmd - imports Configure-EdgeSettings.reg (Edge policies in HKLM\SOFTWARE\Policies\Microsoft\Edge: home page, new tab page and startup URL = mymetro2, Home button on, Google default search). Log in C:\Temp.
REM Type: standalone .cmd, self-elevates (UAC). OS: Windows. Finds Configure-EdgeSettings.reg beside it, else ..\Canned Script\. Restart Edge after it runs.
REM BeyondTrust twin: Canned Script "Configure-EdgeSettings" (resource Canned Script\Configure-EdgeSettings.reg, command sequence Command Sequence\Configure-EdgeSettings.txt, elevated only).
setlocal
set "REGFILE=%~dp0Configure-EdgeSettings.reg"
if not exist "%REGFILE%" set "REGFILE=%~dp0..\Canned Script\Configure-EdgeSettings.reg"
if not exist "%REGFILE%" (
    echo Configure-EdgeSettings.reg not found beside this file or in "%~dp0..\Canned Script\"
    pause
    exit /b 2
)

net session >nul 2>&1
if errorlevel 1 (
    if /i "%~1"=="__CES_ELEV__" (
        echo Still not running as administrator. Right-click and Run as administrator.
        pause
        exit /b 1
    )
    echo Requesting administrator rights...
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '__CES_ELEV__' -Verb RunAs"
    exit /b 0
)

if not exist "C:\Temp" md "C:\Temp"
set "LOG=C:\Temp\Configure-EdgeSettings.log"
echo [%DATE% %TIME%] reg import "%REGFILE%" >> "%LOG%"
reg import "%REGFILE%" /reg:64 >> "%LOG%" 2>&1
set "RC=%ERRORLEVEL%"
echo [%DATE% %TIME%] exit code %RC% >> "%LOG%"
echo.
echo Configure-EdgeSettings finished with exit code %RC%. Restart Edge to apply. Log: %LOG%
pause
exit /b %RC%
