SET DEFINE OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
SET ECHO OFF
SET TRIMOUT ON
SET LINESIZE 200
SET PAGESIZE 100
@@_formats.sql
PROMPT
PROMPT ################################################################
PROMPT #  TimeBank : building the database step by step
PROMPT #  Press ENTER at each step.
PROMPT ################################################################
PROMPT
PROMPT ================================================================
PROMPT  STEP 1/6 : Clear any previous build
PROMPT  > Drops old tables, sequences, views and the package so we start from nothing.
PROMPT  > Errors like 'does not exist' are harmless the very first time.
PROMPT ================================================================
PAUSE  [ Press ENTER to run it ]
@@00_drop_all.sql
PROMPT
PROMPT ================================================================
PROMPT  STEP 2/6 : DDL - create the 14 tables, constraints, sequences and 3 views
PROMPT  > 14 relations from the ER diagram: 4 composite primary keys, 18 foreign keys, many CHECK constraints.
PROMPT  > Weak entities: SLOT (owner TUTOR), FEEDBACK and DISPUTE (owner BOOKING).
PROMPT  > Subclasses TUTOR and TUTEE (mapping option 8A). TUTOR_SKILL = M:N 'offers'.
PROMPT  > BOOKING has two COMPOSITE foreign keys sharing tutor_id.
PROMPT  > Derived attributes (balance, age, hours taught, rating) are VIEWS, not columns.
PROMPT ================================================================
PAUSE  [ Press ENTER to run it ]
@@01_ddl.sql
PROMPT
PROMPT ================================================================
PROMPT  STEP 3/6 : Indexes (B+ trees) and the CREDIT_POLICY index-organised table
PROMPT  > CREATE INDEX builds a B+ tree. One composite index allows an index-only scan,
PROMPT  > one is a FUNCTION-BASED index that only stores open disputes.
PROMPT  > CREDIT_POLICY is ORGANIZATION INDEX = Oracle's equivalent of a clustered index.
PROMPT ================================================================
PAUSE  [ Press ENTER to run it ]
@@02_indexes.sql
PROMPT
PROMPT ================================================================
PROMPT  STEP 4/6 : 6 triggers - rules a CHECK constraint cannot express
PROMPT  > Append-only ledger, overdraft floor (-5), no confirming before the session ends,
PROMPT  > booking must fit the slot, feedback only on completed sessions,
PROMPT  > and a COMPOUND trigger for badge promotion (avoids the mutating-table error ORA-04091).
PROMPT ================================================================
PAUSE  [ Press ENTER to run it ]
@@03_triggers.sql
PROMPT
PROMPT ================================================================
PROMPT  STEP 5/6 : PL/SQL package PKG_TIMEBANK
PROMPT  > Every credit movement goes through this package: enrol, book (with row lock), check-in,
PROMPT  > dual confirmation, cancel, dispute, resolve, and the closed-economy audit.
PROMPT ================================================================
PAUSE  [ Press ENTER to run it ]
@@04_packages.sql
PROMPT
PROMPT ================================================================
PROMPT  STEP 6/6 : Seed data
PROMPT  > 5 departments, 12 students, 10 subjects, 6 tutors, 7 tutees, 12 slots, 2 admins.
PROMPT  > Bookings, ledger rows and the dispute are created ONLY through the package,
PROMPT  > so the data is correct by construction. Ends with the audit (BALANCED) and row counts.
PROMPT ================================================================
PAUSE  [ Press ENTER to run it ]
@@05_seed.sql
PROMPT
PROMPT ================================================================
PROMPT  CHECK : invalid objects (no rows = everything compiled)
PROMPT ================================================================
PAUSE  [ Press ENTER to run it ]
SELECT object_type, object_name, status FROM user_objects WHERE status <> 'VALID' ORDER BY 1,2;
PROMPT
PROMPT ===> Database built. Results stay above. Next: 2_MEMBER1_ONBOARDING.bat
PROMPT ===> Type EXIT and press Enter when you want to close this window.
