@echo off
title 3_MEMBER2_SKILLS
cd /d "%~dp0sql"
sqlplus timebank/timebank@//localhost:1521/FREEPDB1 @_start_07_member2_skills.sql
echo.
echo SQL*Plus closed. Press any key to close this window.
pause >nul
