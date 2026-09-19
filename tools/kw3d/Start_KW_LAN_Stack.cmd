@echo off
cd /d "%~dp0\..\.."
docker compose -f docker-compose.kw3d-lan.yml up -d --build
echo.
echo KW LAN stack ready:
echo Portal: http://192.168.1.154:8082/
echo Game:   192.168.1.154:18886
pause
