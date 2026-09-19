@echo off
python -I -S -u "%~dp0launch_online_demo.py" --clients 1
if errorlevel 1 pause
