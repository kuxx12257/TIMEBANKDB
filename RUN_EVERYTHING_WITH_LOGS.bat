@echo off
title RUN_EVERYTHING_WITH_LOGS
cd /d "%~dp0sql"
echo Building the database and running ALL queries. Output goes to the logs folder...
sqlplus -S timebank/timebank@//localhost:1521/FREEPDB1 @_run_everything_logged.sql
echo.
echo Finished. Logs are in the logs folder.
pause
