SET DEFINE OFF
PROMPT
PROMPT  Resetting the database to the correct starting point for Member 1 ...
PROMPT  (please wait about 10 seconds)
SET TERMOUT OFF
@@run_all.sql
SET TERMOUT ON
PROMPT  Ready.
@@present_06_member1_onboarding.sql
