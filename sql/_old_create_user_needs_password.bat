@echo off
title 0_CREATE_USER
cd /d "%~dp0sql"
echo Log in as SYSTEM - type the password you chose when you installed Oracle.
sqlplus system@//localhost:1521/FREEPDB1 @create_user.sql
pause
