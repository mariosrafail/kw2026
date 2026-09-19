@echo off
python -I -S -u "%~dp0launch_online_demo.py" --clients 2
if errorlevel 1 pause
