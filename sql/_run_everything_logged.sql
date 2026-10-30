SET ECHO ON
SET TRIMSPOOL ON
SPOOL ..\logs\01_build.log
@run_all.sql
SPOOL OFF
SET ECHO ON
SPOOL ..\logs\06_member1.log
@06_member1_onboarding.sql
SPOOL OFF
SET ECHO ON
SPOOL ..\logs\07_member2.log
@07_member2_skills.sql
SPOOL OFF
SET ECHO ON
SPOOL ..\logs\08_member3.log
@08_member3_booking.sql
SPOOL OFF
SET ECHO ON
SPOOL ..\logs\09_member4.log
@09_member4_credit.sql
SPOOL OFF
SET ECHO ON
SPOOL ..\logs\10_member5.log
@10_member5_feedback_disputes.sql
SPOOL OFF
SET ECHO ON
SPOOL ..\logs\11_group.log
@11_group_tcl_plans.sql
SPOOL OFF
EXIT
