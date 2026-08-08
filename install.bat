@echo off
REM Machine Party 8-Player Mod installer (Windows)
cd /d "%~dp0"
py -3 install.py %*
if errorlevel 9009 (
  echo.
  echo Python 3 is required but was not found.
  echo Install it from https://python.org and tick "Add Python to PATH".
)
pause
