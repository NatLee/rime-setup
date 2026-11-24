@echo off
rem rime-setup.cmd - re-run the installer locally to re-pick options
rem (theme / emoji / languages ...). Double-click it, or run it from a terminal;
rem extra arguments are passed through, e.g.  rime-setup.cmd -Theme dark -Yes
rem
rem Why not just "powershell -File install.ps1": install.ps1 has no BOM (required
rem for `irm | iex`), and Windows PowerShell 5.1 reads BOM-less files as ANSI.
rem So read it explicitly as UTF-8 and run it as a script block.
rem Keep this file pure ASCII.
rem Launch timing: install.ps1 prints how long it took to get from the keypress
rem in the IME to its menu (see rime\lua\p_components\p_generic_open.lua).
rem NA_T_CMD is the moment this batch file started running.
set "NA_T_CMD=%time%"
title Na+ setup
rem Look pwsh up on PATH without spawning anything. `where pwsh` did the same
rem job but costs a process (about 60 ms) on every launch.
set "NA_PS=powershell"
for %%I in (pwsh.exe) do if not "%%~$PATH:I"=="" set "NA_PS=pwsh"
rem Use this checkout as the source and skip the network (NA_LOCAL).
set "NA_HOME=%~dp0.."
set "NA_LOCAL=1"
set "NA_INSTALL=%~dp0..\install.ps1"
rem NA_AUTOCLOSE: on success install.ps1 counts down a few seconds and returns,
rem so this window closes by itself. It sets $global:NaSetupOk only when it got
rem to the end; anything else exits 1 and we pause so the message can be read.
set "NA_AUTOCLOSE=1"
%NA_PS% -NoProfile -ExecutionPolicy Bypass -Command "$global:NaSetupOk = $false; & ([scriptblock]::Create([IO.File]::ReadAllText($env:NA_INSTALL, [Text.Encoding]::UTF8))) %*; if (-not $global:NaSetupOk) { exit 1 }"
if errorlevel 1 pause
rem The IME runs this with cmd /c (window closes when we return); double-click
rem or `start` runs it with cmd /K, where only `exit` closes the window.
exit
