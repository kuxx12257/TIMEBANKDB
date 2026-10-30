@echo off
title 9_CONCURRENCY_SESSION2
cd /d "%~dp0sql"
sqlplus timebank/timebank@//localhost:1521/FREEPDB1 @_concurrency_session2.sql
echo.
echo SQL*Plus closed. Press any key to close this window.
pause >nul
