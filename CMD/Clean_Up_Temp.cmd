@echo off
REM SYNOPSIS: Standalone launcher for Clean_Up_Temp.ps1 - cleans C:\Windows\Temp and every user's AppData\Local\Temp (files older than 1 day). Log in C:\Temp.
REM Type: standalone .cmd, self-elevates (UAC). OS: Windows. Finds Clean_Up_Temp.ps1 beside it, else ..\PS1\. Optional arg: days, e.g. Clean_Up_Temp.cmd 7
REM BeyondTrust twin: Canned Script "Clean Up Temp" (resource Clean_Up_Temp.ps1, elevated only). Replaces Old Scripts\Clean_Up_Temp.bat.
setlocal
set "PS1=%~dp0Clean_Up_Temp.ps1"
if not exist "%PS1%" set "PS1=%~dp0..\PS1\Clean_Up_Temp.ps1"
if not exist "%PS1%" (
    echo Clean_Up_Temp.ps1 not found beside this file or in "%~dp0..\PS1\"
    pause
    exit /b 2
)

set "DAYS=%~1"
if /i "%~1"=="__CUT_ELEV__" set "DAYS=%~2"
if "%DAYS%"=="" set "DAYS=1"

net session >nul 2>&1
if errorlevel 1 (
    if /i "%~1"=="__CUT_ELEV__" (
        echo Still not running as administrator. Right-click and Run as administrator.
        pause
        exit /b 1
    )
    echo Requesting administrator rights...
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '__CUT_ELEV__','%DAYS%' -Verb RunAs"
    exit /b 0
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -OlderThanDays %DAYS%
set "RC=%ERRORLEVEL%"
echo.
echo Clean_Up_Temp finished with exit code %RC%.
pause
exit /b %RC%
