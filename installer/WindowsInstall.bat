@echo off
REM Machine Party 8-Player Mod installer (Windows)
cd /d "%~dp0"
REM Prefer the Python runtime bundled in the release zip; fall back to a
REM system Python so this same file works in a repo checkout (see UPDATING.md).
if exist "%~dp0python\python.exe" (
  "%~dp0python\python.exe" install.py %*
) else (
  py -3 install.py %*
  if errorlevel 9009 (
    echo.
    echo Python 3 is required but was not found.
    echo Install it from https://python.org and tick "Add Python to PATH".
  )
)
pause
