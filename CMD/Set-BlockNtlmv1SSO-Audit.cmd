@echo off
REM SYNOPSIS: Standalone .cmd - NTLMv1 SSO audit-mode workaround (KB5127648): sets HKLM\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0 BlockNtlmv1SSO = 0 (REG_DWORD). No reboot. Log in C:\Temp.
REM Type: standalone .cmd, self-elevates (UAC). OS: Windows.
REM BeyondTrust twin: Canned Script "Set BlockNtlmv1SSO = 0 (Audit)" (Command Shell, elevated only, no resource file; text in Canned Script\Set-BlockNtlmv1SSO-Audit.txt).
setlocal

net session >nul 2>&1
if errorlevel 1 (
    if /i "%~1"=="__SBN_ELEV__" (
        echo Still not running as administrator. Right-click and Run as administrator.
        pause
        exit /b 1
    )
    echo Requesting administrator rights...
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '__SBN_ELEV__' -Verb RunAs"
    exit /b 0
)

if not exist "C:\Temp" md "C:\Temp"
set "LOG=C:\Temp\Set-BlockNtlmv1SSO-Audit.log"
echo [%DATE% %TIME%] reg add BlockNtlmv1SSO = 0 >> "%LOG%"
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" /v BlockNtlmv1SSO /t REG_DWORD /d 0 /f /reg:64 >> "%LOG%" 2>&1
set "RC=%ERRORLEVEL%"
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" /v BlockNtlmv1SSO /reg:64 >> "%LOG%" 2>&1
echo [%DATE% %TIME%] exit code %RC% >> "%LOG%"
echo.
echo Set-BlockNtlmv1SSO-Audit finished with exit code %RC%. No reboot needed. Log: %LOG%
pause
exit /b %RC%
