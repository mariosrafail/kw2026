@echo off
setlocal
set "APPDIR=%~dp0"
if exist "%APPDIR%dist\KW Character Builder.exe" (
    start "" "%APPDIR%dist\KW Character Builder.exe"
) else (
    start "" pythonw "%APPDIR%app.py"
)
