@echo off
rem Drag your Turok: Evolution ISO (or default.xbe, game folder, GOD 41430004 folder) onto this file.
setlocal
set "IN=%~1"
if "%IN%"=="" set /p "IN=Drag your Turok Evolution ISO here (or default.xbe / GOD 41430004 folder) and press Enter: "
set "IN=%IN:"=%"
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Patch-TurokCoop.ps1" -InputPath "%IN%"
echo.
pause
