@echo off
title 5_MEMBER4_CREDIT_LEDGER
cd /d "%~dp0sql"
sqlplus timebank/timebank@//localhost:1521/FREEPDB1 @_start_09_member4_credit.sql
echo.
echo SQL*Plus closed. Press any key to close this window.
pause >nul
