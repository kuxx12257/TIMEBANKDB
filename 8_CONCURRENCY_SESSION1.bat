@echo off
title 8_CONCURRENCY_SESSION1
cd /d "%~dp0sql"
sqlplus timebank/timebank@//localhost:1521/FREEPDB1 @_start_concurrency_session1.sql
echo.
echo SQL*Plus closed. Press any key to close this window.
pause >nul
