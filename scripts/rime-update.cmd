@echo off
rem rime-update.cmd - launcher for rime-update.ps1 (typed '/git inside the IME).
rem Picks PowerShell 7 (pwsh) when installed, otherwise the built-in Windows
rem PowerShell 5.1, so the update works on a stock Windows machine.
rem -ExecutionPolicy Bypass: the default policy refuses to run .ps1 files.
rem Keep this file pure ASCII: cmd.exe reads batch files in the OEM code page.
where pwsh >nul 2>nul
if %errorlevel%==0 (set "NA_PS=pwsh") else (set "NA_PS=powershell")
%NA_PS% -NoProfile -ExecutionPolicy Bypass -File "%~dp0rime-update.ps1" %*
rem The IME launches this through `start`, which runs batch files with cmd /K
rem (window stays open). `exit` closes that window; on failure the .ps1 has
rem already paused for Enter, so nothing is lost.
exit %errorlevel%
