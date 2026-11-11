@echo off
REM SYNOPSIS: Silently uninstall GTB Endpoint Agent - finds any GTB uninstall entry (64- and 32-bit) and runs msiexec /x, log C:\Temp\gtb_uninstall.log. 0/3010 = success; 1603 or hang = tamper protection on, Infosec token needed.
REM Type: standalone .cmd (run as admin). BeyondTrust twin: none. Ticket: 416113.
setlocal EnableDelayedExpansion
if not exist C:\Temp mkdir C:\Temp
set "FOUND=0"
for %%R in ("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall") do (
  for /f "delims=" %%K in ('reg query %%R /s /f GTB /d 2^>nul ^| findstr /b /i "HKEY_"') do (
    set "G=%%~nxK"
    if "!G:~0,1!"=="{" (
      set "FOUND=1"
      echo Uninstalling !G!
      start "" /wait msiexec /x !G! /qn /norestart /l*v C:\Temp\gtb_uninstall.log
      echo Exit code: !errorlevel!
    )
  )
)
if "%FOUND%"=="0" echo No GTB product found.
endlocal
pause
