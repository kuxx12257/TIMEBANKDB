@echo off
title 4_MEMBER3_BOOKING
cd /d "%~dp0sql"
sqlplus timebank/timebank@//localhost:1521/FREEPDB1 @_start_08_member3_booking.sql
echo.
echo SQL*Plus closed. Press any key to close this window.
pause >nul
