@echo off
rem Explicit LAN mode. No automatic firewall or router changes.
python -I -S -u "%~dp0launch_online_demo.py" --clients 0 --lan
pause
