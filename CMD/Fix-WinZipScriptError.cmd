@echo off
REM SYNOPSIS: Fix WinZip "script error" popups - blocks googletagmanager.com in the Restricted Sites zone and sets WinZip to IE11 emulation (FEATURE_BROWSER_EMULATION 11001), per user and machine-wide.
REM Type: standalone .cmd (run as admin). BeyondTrust twin: none. Ticket: 416083.
setlocal
set "Z=Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\googletagmanager.com"
set "F=Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_BROWSER_EMULATION"
echo --- Per-user (signed-in users) ---
for /f "delims=" %%K in ('reg query HKU ^| findstr /r "S-1-5-21-[0-9-]*$"') do (
  reg add "%%K\%Z%" /v http /t REG_DWORD /d 4 /f >nul
  reg add "%%K\%Z%" /v https /t REG_DWORD /d 4 /f >nul
  reg add "%%K\%F%" /v winzip64.exe /t REG_DWORD /d 11001 /f >nul
  reg add "%%K\%F%" /v winzip32.exe /t REG_DWORD /d 11001 /f >nul
  echo %%K
  reg query "%%K\%Z%"
)
echo --- Computer-wide ---
for %%V in (64 32) do (
  reg add "HKLM\%Z%" /v http /t REG_DWORD /d 4 /f /reg:%%V >nul
  reg add "HKLM\%Z%" /v https /t REG_DWORD /d 4 /f /reg:%%V >nul
)
reg add "HKLM\%F%" /v winzip64.exe /t REG_DWORD /d 11001 /f /reg:64 >nul
reg add "HKLM\%F%" /v winzip32.exe /t REG_DWORD /d 11001 /f /reg:32 >nul
reg query "HKLM\%Z%" /reg:64
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings" /v Security_HKLM_only 2>nul || echo HKLM_only=blank
endlocal
pause
