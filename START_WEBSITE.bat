@echo off
title TimeBank SQL live log  (keep this window open beside the browser)
cd /d "%~dp0webapp"
set PY=python
if exist "%USERPROFILE%\anaconda3\python.exe" set PY="%USERPROFILE%\anaconda3\python.exe"
echo Installing the Oracle driver (first time only)...
%PY% -m pip install -q oracledb
echo.
echo Starting TimeBank web app on http://localhost:8765 ...
%PY% server.py
pause
