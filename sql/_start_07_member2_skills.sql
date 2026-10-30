SET DEFINE OFF
PROMPT
PROMPT  Resetting the database to the correct starting point for Member 2 ...
PROMPT  (please wait about 10 seconds)
SET TERMOUT OFF
@@run_all.sql
@@06_member1_onboarding.sql
SET TERMOUT ON
PROMPT  Ready.
@@present_07_member2_skills.sql
