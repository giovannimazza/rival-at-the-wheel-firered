@echo off
setlocal
title Rival at the Wheel - internet tunnel
set PORT=8888

echo ==================================================
echo    RIVAL AT THE WHEEL - internet tunnel
echo ==================================================
echo.

set "CF="
where cloudflared >nul 2>nul && set "CF=cloudflared"
if not defined CF if exist "%~dp0cloudflared.exe" set "CF=%~dp0cloudflared.exe"
if not defined CF goto install
goto run

:install
echo cloudflared is not installed yet. Trying to install it with winget...
echo.
winget install --id Cloudflare.cloudflared -e --accept-source-agreements --accept-package-agreements
if errorlevel 1 goto manual
echo.
echo Installed! Close this window and run start_tunnel.bat again.
pause
exit /b

:manual
echo.
echo Automatic install failed. Do this instead:
echo  1. Download "cloudflared-windows-amd64.exe" from
echo     https://github.com/cloudflare/cloudflared/releases/latest
echo  2. Rename it to cloudflared.exe and put it in this folder
echo  3. Run start_tunnel.bat again
pause
exit /b

:run
echo Connecting the internet to mGBA (port %PORT%)...
echo.
echo  - In a few seconds an address like
echo        https://random-words.trycloudflare.com
echo    appears below.
echo  - Send it to player 2 together with the CODE shown in the mGBA console.
echo  - Keep this window open while you play. The address changes every time.
echo.
"%CF%" tunnel --url http://localhost:%PORT%
echo.
echo The tunnel has closed.
pause
