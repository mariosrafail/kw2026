@echo off
python -I -S -u "%~dp0launch_overdrive_duel.py"
if errorlevel 1 pause
