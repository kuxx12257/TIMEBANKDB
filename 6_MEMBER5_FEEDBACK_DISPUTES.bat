@echo off
title 6_MEMBER5_FEEDBACK_DISPUTES
cd /d "%~dp0sql"
sqlplus timebank/timebank@//localhost:1521/FREEPDB1 @_start_10_member5_feedback_disputes.sql
echo.
echo SQL*Plus closed. Press any key to close this window.
pause >nul
