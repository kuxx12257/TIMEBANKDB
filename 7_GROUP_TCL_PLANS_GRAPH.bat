@echo off
title 7_GROUP_TCL_PLANS_GRAPH
cd /d "%~dp0sql"
sqlplus timebank/timebank@//localhost:1521/FREEPDB1 @_start_11_group_tcl_plans.sql
echo.
echo SQL*Plus closed. Press any key to close this window.
pause >nul
