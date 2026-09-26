@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start_KW_Online_QuickTunnel.ps1"
if errorlevel 1 pause
