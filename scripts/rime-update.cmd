@echo off
rem rime-update.cmd - launcher for rime-update.ps1 (typed '/git inside the IME).
rem Picks PowerShell 7 (pwsh) when installed, otherwise the built-in Windows
rem PowerShell 5.1, so the update works on a stock Windows machine.
rem -ExecutionPolicy Bypass: the default policy refuses to run .ps1 files.
rem Keep this file pure ASCII: cmd.exe reads batch files in the OEM code page.
title Na+ update
rem Look pwsh up on PATH without spawning anything. `where pwsh` did the same
rem job but costs a process (about 60 ms) on every launch.
set "NA_PS=powershell"
for %%I in (pwsh.exe) do if not "%%~$PATH:I"=="" set "NA_PS=pwsh"
%NA_PS% -NoProfile -ExecutionPolicy Bypass -File "%~dp0rime-update.ps1" %*
rem The IME runs this with cmd /c in the console Windows gave it, so the window
rem closes when we return. Double-clicking or `start` runs it with cmd /K, where
rem only `exit` closes the window; on failure the .ps1 has already paused for
rem Enter, so nothing is lost either way.
exit %errorlevel%
