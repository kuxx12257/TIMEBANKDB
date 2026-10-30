SET DEFINE OFF
PROMPT  Resetting the database first (about 10 seconds) ...
SET TERMOUT OFF
@@run_all.sql
SET TERMOUT ON
@@_concurrency_session1.sql
