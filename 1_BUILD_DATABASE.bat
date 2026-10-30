@echo off
title 1_BUILD_DATABASE
cd /d "%~dp0sql"
sqlplus timebank/timebank@//localhost:1521/FREEPDB1 @present_run_all.sql
echo.
echo SQL*Plus closed. Press any key to close this window.
pause >nul
