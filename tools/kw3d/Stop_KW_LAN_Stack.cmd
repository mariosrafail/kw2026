@echo off
cd /d "%~dp0\..\.."
docker compose -f docker-compose.kw3d-lan.yml down
pause
