SET DEFINE OFF
PROMPT
PROMPT  Resetting the database to the correct starting point for the group file ...
PROMPT  (please wait about 10 seconds)
SET TERMOUT OFF
@@run_all.sql
@@06_member1_onboarding.sql
@@07_member2_skills.sql
@@08_member3_booking.sql
@@09_member4_credit.sql
@@10_member5_feedback_disputes.sql
SET TERMOUT ON
PROMPT  Ready.
@@present_11_group_tcl_plans.sql
