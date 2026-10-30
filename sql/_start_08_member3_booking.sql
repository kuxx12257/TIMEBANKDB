SET DEFINE OFF
PROMPT
PROMPT  Resetting the database to the correct starting point for Member 3 ...
PROMPT  (please wait about 10 seconds)
SET TERMOUT OFF
@@run_all.sql
@@06_member1_onboarding.sql
@@07_member2_skills.sql
SET TERMOUT ON
PROMPT  Ready.
@@present_08_member3_booking.sql
