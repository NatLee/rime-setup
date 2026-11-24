@echo off
rem rime-setup.cmd - re-run the installer locally to re-pick options
rem (theme / emoji / languages ...). Double-click it, or run it from a terminal;
rem extra arguments are passed through, e.g.  rime-setup.cmd -Theme dark -Yes
rem
rem Why not just "powershell -File install.ps1": install.ps1 has no BOM (required
rem for `irm | iex`), and Windows PowerShell 5.1 reads BOM-less files as ANSI.
rem So read it explicitly as UTF-8 and run it as a script block.
rem Keep this file pure ASCII.
where pwsh >nul 2>nul
if %errorlevel%==0 (set "NA_PS=pwsh") else (set "NA_PS=powershell")
rem Use this checkout as the source and skip the network (NA_LOCAL).
set "NA_HOME=%~dp0.."
set "NA_LOCAL=1"
set "NA_INSTALL=%~dp0..\install.ps1"
%NA_PS% -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create([IO.File]::ReadAllText($env:NA_INSTALL, [Text.Encoding]::UTF8))) %*"
pause