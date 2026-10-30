@echo off
title 0_CREATE_USER_NO_PASSWORD
cd /d "%~dp0sql"
set ORACLE_SID=FREE
echo Connecting with Windows login (no Oracle password needed)...
sqlplus / as sysdba @create_user_sysdba.sql
pause
