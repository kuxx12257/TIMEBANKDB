@echo off
title 2_MEMBER1_ONBOARDING
cd /d "%~dp0sql"
sqlplus timebank/timebank@//localhost:1521/FREEPDB1 @_start_06_member1_onboarding.sql
echo.
echo SQL*Plus closed. Press any key to close this window.
pause >nul
