SET DEFINE OFF
PROMPT
PROMPT  Resetting the database to the correct starting point for Member 4 ...
PROMPT  (please wait about 10 seconds)
SET TERMOUT OFF
@@run_all.sql
@@06_member1_onboarding.sql
@@07_member2_skills.sql
@@08_member3_booking.sql
SET TERMOUT ON
PROMPT  Ready.
@@present_09_member4_credit.sql
