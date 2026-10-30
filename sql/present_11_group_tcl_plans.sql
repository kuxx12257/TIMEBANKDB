SET DEFINE OFF

SET SERVEROUTPUT ON


PROMPT ========== PART A : TCL ==========
@@_formats.sql
SET ECHO OFF
SET TRIMOUT ON
SET TAB OFF
PROMPT
PROMPT ################################################################
PROMPT #  GROUP : TCL, query plans, audit, graph queries
PROMPT #  Each step: read the explanation, press ENTER to run it.
PROMPT ################################################################
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  A1. SAVEPOINT and partial rollback
PROMPT  > TCL demo: SAVEPOINT, ROLLBACK TO SAVEPOINT, and full ROLLBACK on Ishita's balance.
PROMPT  > Add +2 goodwill, set a savepoint, add a wrong -2 penalty, ROLLBACK TO the savepoint:
PROMPT  > only the penalty is undone. Then a full ROLLBACK undoes everything.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  DECLARE
PROMPT  |    v_before  NUMBER;
PROMPT  |    v_mid     NUMBER;
PROMPT  |    v_after   NUMBER;
PROMPT  |  BEGIN
PROMPT  |    v_before := pkg_timebank.fn_balance (104);
PROMPT  |    DBMS_OUTPUT.PUT_LINE ('Balance at the start      : ' || v_before);
PROMPT  |  
PROMPT  |    SAVEPOINT before_adjustments;
PROMPT  |  
PROMPT  |    INSERT INTO credit_txn (txn_id, txn_type, amount, balance_snapshot,
PROMPT  |                            remarks, student_id, booking_id)
PROMPT  |    VALUES (seq_txn.NEXTVAL, 'GRANT', 2.0,
PROMPT  |            (SELECT NVL (SUM (amount),0) + 2.0 FROM credit_txn
PROMPT  |             WHERE student_id = 104),
PROMPT  |            'Goodwill credit', 104, NULL);
PROMPT  |  
PROMPT  |    v_mid := pkg_timebank.fn_balance (104);
PROMPT  |    DBMS_OUTPUT.PUT_LINE ('After the goodwill credit : ' || v_mid);
PROMPT  |  
PROMPT  |    SAVEPOINT after_goodwill;
PROMPT  |  
PROMPT  |    INSERT INTO credit_txn (txn_id, txn_type, amount, balance_snapshot,
PROMPT  |                            remarks, student_id, booking_id)
PROMPT  |    VALUES (seq_txn.NEXTVAL, 'PENALTY', -2.0,
PROMPT  |            (SELECT NVL (SUM (amount),0) - 2.0 FROM credit_txn
PROMPT  |             WHERE student_id = 104),
PROMPT  |            'Penalty applied in error', 104, NULL);
PROMPT  |  
PROMPT  |    DBMS_OUTPUT.PUT_LINE ('After the penalty         : ' ||
PROMPT  |                          pkg_timebank.fn_balance (104));
PROMPT  |  
PROMPT  |    ROLLBACK TO after_goodwill;
PROMPT  |  
PROMPT  |    v_after := pkg_timebank.fn_balance (104);
PROMPT  |    DBMS_OUTPUT.PUT_LINE ('After ROLLBACK TO savepoint: ' || v_after);
PROMPT  |  
PROMPT  |    IF v_after = v_mid THEN
PROMPT  |      DBMS_OUTPUT.PUT_LINE ('=> Correct: the penalty was undone, the credit kept.');
PROMPT  |    END IF;
PROMPT  |  
PROMPT  |    ROLLBACK;
PROMPT  |    DBMS_OUTPUT.PUT_LINE ('After full ROLLBACK        : ' ||
PROMPT  |                          pkg_timebank.fn_balance (104));
PROMPT  |  END;
PROMPT  |  /
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
DECLARE
  v_before  NUMBER;
  v_mid     NUMBER;
  v_after   NUMBER;
BEGIN
  v_before := pkg_timebank.fn_balance (104);
  DBMS_OUTPUT.PUT_LINE ('Balance at the start      : ' || v_before);

  SAVEPOINT before_adjustments;

  INSERT INTO credit_txn (txn_id, txn_type, amount, balance_snapshot,
                          remarks, student_id, booking_id)
  VALUES (seq_txn.NEXTVAL, 'GRANT', 2.0,
          (SELECT NVL (SUM (amount),0) + 2.0 FROM credit_txn
           WHERE student_id = 104),
          'Goodwill credit', 104, NULL);

  v_mid := pkg_timebank.fn_balance (104);
  DBMS_OUTPUT.PUT_LINE ('After the goodwill credit : ' || v_mid);

  SAVEPOINT after_goodwill;

  INSERT INTO credit_txn (txn_id, txn_type, amount, balance_snapshot,
                          remarks, student_id, booking_id)
  VALUES (seq_txn.NEXTVAL, 'PENALTY', -2.0,
          (SELECT NVL (SUM (amount),0) - 2.0 FROM credit_txn
           WHERE student_id = 104),
          'Penalty applied in error', 104, NULL);

  DBMS_OUTPUT.PUT_LINE ('After the penalty         : ' ||
                        pkg_timebank.fn_balance (104));

  ROLLBACK TO after_goodwill;

  v_after := pkg_timebank.fn_balance (104);
  DBMS_OUTPUT.PUT_LINE ('After ROLLBACK TO savepoint: ' || v_after);

  IF v_after = v_mid THEN
    DBMS_OUTPUT.PUT_LINE ('=> Correct: the penalty was undone, the credit kept.');
  END IF;

  ROLLBACK;
  DBMS_OUTPUT.PUT_LINE ('After full ROLLBACK        : ' ||
                        pkg_timebank.fn_balance (104));
END;
/
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  A2. Atomicity: a failed booking leaves no trace
PROMPT  > ATOMICITY (the A in ACID): a booking that fails (tutor 101 has no slot 9)
PROMPT  > leaves NO trace - the ledger row count is the same before and after.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  DECLARE
PROMPT  |    v_bk     NUMBER;
PROMPT  |    v_code   VARCHAR2(8);
PROMPT  |    v_rows   NUMBER;
PROMPT  |  BEGIN
PROMPT  |    SELECT COUNT (*) INTO v_rows FROM credit_txn;
PROMPT  |    DBMS_OUTPUT.PUT_LINE ('Ledger rows before : ' || v_rows);
PROMPT  |  
PROMPT  |    BEGIN
PROMPT  |      pkg_timebank.book_session (
PROMPT  |          p_tutee_id => 102, p_tutor_id => 101, p_subject_id => 101,
PROMPT  |          p_slot_no  => 9,                      -- tutor 101 has no slot 9
PROMPT  |          p_sched_date => TRUNC (SYSDATE,'IW') + 14,
PROMPT  |          p_start_time => 16, p_duration => 1.0,
PROMPT  |          p_mode => 'OFFLINE', p_venue => 'SJT 512',
PROMPT  |          p_booking_id => v_bk, p_session_code => v_code);
PROMPT  |    EXCEPTION
PROMPT  |      WHEN OTHERS THEN
PROMPT  |        DBMS_OUTPUT.PUT_LINE ('Rejected as expected -> ' ||
PROMPT  |                              SUBSTR (SQLERRM, 1, 90));
PROMPT  |        ROLLBACK;
PROMPT  |    END;
PROMPT  |  
PROMPT  |    SELECT COUNT (*) INTO v_rows FROM credit_txn;
PROMPT  |    DBMS_OUTPUT.PUT_LINE ('Ledger rows after  : ' || v_rows ||
PROMPT  |                          '   (unchanged = atomic)');
PROMPT  |  END;
PROMPT  |  /
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
DECLARE
  v_bk     NUMBER;
  v_code   VARCHAR2(8);
  v_rows   NUMBER;
BEGIN
  SELECT COUNT (*) INTO v_rows FROM credit_txn;
  DBMS_OUTPUT.PUT_LINE ('Ledger rows before : ' || v_rows);

  BEGIN
    pkg_timebank.book_session (
        p_tutee_id => 102, p_tutor_id => 101, p_subject_id => 101,
        p_slot_no  => 9,                      -- tutor 101 has no slot 9
        p_sched_date => TRUNC (SYSDATE,'IW') + 14,
        p_start_time => 16, p_duration => 1.0,
        p_mode => 'OFFLINE', p_venue => 'SJT 512',
        p_booking_id => v_bk, p_session_code => v_code);
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE ('Rejected as expected -> ' ||
                            SUBSTR (SQLERRM, 1, 90));
      ROLLBACK;
  END;

  SELECT COUNT (*) INTO v_rows FROM credit_txn;
  DBMS_OUTPUT.PUT_LINE ('Ledger rows after  : ' || v_rows ||
                        '   (unchanged = atomic)');
END;
/
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  PART B : see the comments for the two-session demo
PROMPT  > CONCURRENCY demo is done separately with two windows:
PROMPT  > run 8_CONCURRENCY_SESSION1.bat, then 9_CONCURRENCY_SESSION2.bat (it hangs),
PROMPT  > then type COMMIT; in window 1 - window 2 fails with ORA-20005. Only one booking exists.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
PROMPT
PROMPT ========== PART C : query plans ==========
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  C1. Tutor search WITH the index (expect INDEX RANGE SCAN)
PROMPT  > EXPLAIN PLAN for 'find tutors of subject 101' - WITH the index.
PROMPT  > Look for INDEX RANGE SCAN and note the COST.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  EXPLAIN PLAN SET STATEMENT_ID = 'with_index' FOR
PROMPT  |  SELECT ts.tutor_id, ts.competency_level
PROMPT  |  FROM   tutor_skill ts
PROMPT  |  WHERE  ts.subject_id = 101;
PROMPT  |  
PROMPT  |  SELECT * FROM TABLE (DBMS_XPLAN.DISPLAY (NULL, 'with_index', 'BASIC +COST'));
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
EXPLAIN PLAN SET STATEMENT_ID = 'with_index' FOR
SELECT ts.tutor_id, ts.competency_level
FROM   tutor_skill ts
WHERE  ts.subject_id = 101;

SELECT * FROM TABLE (DBMS_XPLAN.DISPLAY (NULL, 'with_index', 'BASIC +COST'));
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  C2. The same question WITHOUT the index (expect FULL scan)
PROMPT  > The same query with the /*+ FULL */ hint, which forces Oracle to ignore the index.
PROMPT  > Look for TABLE ACCESS FULL and compare the COST with C1.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  
PROMPT  |  EXPLAIN PLAN SET STATEMENT_ID = 'no_index' FOR
PROMPT  |  SELECT /*+ FULL(ts) */ ts.tutor_id, ts.competency_level
PROMPT  |  FROM   tutor_skill ts
PROMPT  |  WHERE  ts.subject_id = 101;
PROMPT  |  
PROMPT  |  SELECT * FROM TABLE (DBMS_XPLAN.DISPLAY (NULL, 'no_index', 'BASIC +COST'));
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
PROMPT --- /*+ FULL */ forces the optimiser to ignore it, so the two
PROMPT --- costs can be compared directly.

EXPLAIN PLAN SET STATEMENT_ID = 'no_index' FOR
SELECT /*+ FULL(ts) */ ts.tutor_id, ts.competency_level
FROM   tutor_skill ts
WHERE  ts.subject_id = 101;

SELECT * FROM TABLE (DBMS_XPLAN.DISPLAY (NULL, 'no_index', 'BASIC +COST'));
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  C3. Heuristic optimisation: pushing selection down the tree
PROMPT  > Heuristic optimisation: selection is pushed down - FEEDBACK is filtered BEFORE the joins,
PROMPT  > so fewer rows are joined. (Relational algebra is written in the file comments.)
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  
PROMPT  |  
PROMPT  |  EXPLAIN PLAN SET STATEMENT_ID = 'pushed' FOR
PROMPT  |  SELECT s.first_name, f.rating
PROMPT  |  FROM   feedback f
PROMPT  |         JOIN booking b ON b.booking_id = f.booking_id
PROMPT  |         JOIN student s ON s.student_id = b.tutor_id
PROMPT  |  WHERE  f.reviewer_role = 'TUTEE'
PROMPT  |  AND    f.rating       >= 4.5;
PROMPT  |  
PROMPT  |  SELECT * FROM TABLE (DBMS_XPLAN.DISPLAY (NULL, 'pushed', 'BASIC +COST'));
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
PROMPT --- Both queries below return the same rows. The first filters
PROMPT --- early (good), the second joins everything then filters.


EXPLAIN PLAN SET STATEMENT_ID = 'pushed' FOR
SELECT s.first_name, f.rating
FROM   feedback f
       JOIN booking b ON b.booking_id = f.booking_id
       JOIN student s ON s.student_id = b.tutor_id
WHERE  f.reviewer_role = 'TUTEE'
AND    f.rating       >= 4.5;

SELECT * FROM TABLE (DBMS_XPLAN.DISPLAY (NULL, 'pushed', 'BASIC +COST'));
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  C4. Index-only scan: the answer comes from the index alone
PROMPT  > INDEX-ONLY scan: the answer comes from the index alone.
PROMPT  > There is no TABLE ACCESS step - the table itself is never read.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  
PROMPT  |  EXPLAIN PLAN SET STATEMENT_ID = 'index_only' FOR
PROMPT  |  SELECT subject_id, COUNT (*)
PROMPT  |  FROM   tutor_skill
PROMPT  |  GROUP  BY subject_id;
PROMPT  |  
PROMPT  |  SELECT * FROM TABLE (DBMS_XPLAN.DISPLAY (NULL, 'index_only', 'BASIC +COST'));
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
PROMPT --- Look for "INDEX FAST FULL SCAN" and the absence of any
PROMPT --- TABLE ACCESS step -- the table is never touched.

EXPLAIN PLAN SET STATEMENT_ID = 'index_only' FOR
SELECT subject_id, COUNT (*)
FROM   tutor_skill
GROUP  BY subject_id;

SELECT * FROM TABLE (DBMS_XPLAN.DISPLAY (NULL, 'index_only', 'BASIC +COST'));
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  PART D : final audit
PROMPT  > Final closed-economy audit with pkg_timebank.audit_economy - must print BALANCED.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  EXEC pkg_timebank.audit_economy;
PROMPT  |  
PROMPT  |  
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
EXEC pkg_timebank.audit_economy;


PROMPT
PROMPT ========== PART E : Module 6, graph analytics ==========
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  E1. Tutor leaderboard (CTE + four analytic functions)
PROMPT  > Module 6: tutor leaderboard using a CTE (WITH clause) + DENSE_RANK, PERCENT_RANK, NTILE, LEAD.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  WITH tutor_stats AS (
PROMPT  |      SELECT b.tutor_id,
PROMPT  |             COUNT (*)                      AS sessions,
PROMPT  |             SUM (b.duration_hours)         AS hours,
PROMPT  |             (SELECT ROUND (AVG (f.rating), 2)
PROMPT  |              FROM   feedback f
PROMPT  |                     JOIN booking b2 ON b2.booking_id = f.booking_id
PROMPT  |              WHERE  b2.tutor_id     = b.tutor_id
PROMPT  |              AND    f.reviewer_role = 'TUTEE')  AS avg_rating
PROMPT  |      FROM   booking b
PROMPT  |      WHERE  b.status = 'COMPLETED'
PROMPT  |      GROUP  BY b.tutor_id)
PROMPT  |  SELECT DENSE_RANK () OVER (ORDER BY ts.hours DESC)         AS rnk,
PROMPT  |         s.first_name || ' ' || s.last_name                  AS tutor_name,
PROMPT  |         d.school,
PROMPT  |         t.badge_level,
PROMPT  |         ts.sessions,
PROMPT  |         ts.hours,
PROMPT  |         NVL (ts.avg_rating, 0)                              AS rating,
PROMPT  |         ROUND (ts.hours * NVL (ts.avg_rating, 0), 2)        AS impact_score,
PROMPT  |         ROUND (PERCENT_RANK () OVER (ORDER BY ts.hours), 2) AS percentile,
PROMPT  |         NTILE (4) OVER (ORDER BY ts.hours DESC)             AS quartile,
PROMPT  |         LEAD (ts.hours) OVER (ORDER BY ts.hours DESC)       AS next_tutor_hours
PROMPT  |  FROM   tutor_stats ts
PROMPT  |         JOIN tutor      t ON t.student_id = ts.tutor_id
PROMPT  |         JOIN student    s ON s.student_id = ts.tutor_id
PROMPT  |         JOIN department d ON d.dept_id    = s.dept_id
PROMPT  |  ORDER  BY ts.hours DESC;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
WITH tutor_stats AS (
    SELECT b.tutor_id,
           COUNT (*)                      AS sessions,
           SUM (b.duration_hours)         AS hours,
           (SELECT ROUND (AVG (f.rating), 2)
            FROM   feedback f
                   JOIN booking b2 ON b2.booking_id = f.booking_id
            WHERE  b2.tutor_id     = b.tutor_id
            AND    f.reviewer_role = 'TUTEE')  AS avg_rating
    FROM   booking b
    WHERE  b.status = 'COMPLETED'
    GROUP  BY b.tutor_id)
SELECT DENSE_RANK () OVER (ORDER BY ts.hours DESC)         AS rnk,
       s.first_name || ' ' || s.last_name                  AS tutor_name,
       d.school,
       t.badge_level,
       ts.sessions,
       ts.hours,
       NVL (ts.avg_rating, 0)                              AS rating,
       ROUND (ts.hours * NVL (ts.avg_rating, 0), 2)        AS impact_score,
       ROUND (PERCENT_RANK () OVER (ORDER BY ts.hours), 2) AS percentile,
       NTILE (4) OVER (ORDER BY ts.hours DESC)             AS quartile,
       LEAD (ts.hours) OVER (ORDER BY ts.hours DESC)       AS next_tutor_hours
FROM   tutor_stats ts
       JOIN tutor      t ON t.student_id = ts.tutor_id
       JOIN student    s ON s.student_id = ts.tutor_id
       JOIN department d ON d.dept_id    = s.dept_id
ORDER  BY ts.hours DESC;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  E2. Knowledge-flow chains (HIERARCHICAL query)
PROMPT  > Module 6, GRAPH query without a graph database: CONNECT BY walks 'who learned from whom'.
PROMPT  > Starts at Diya: she learned from Aarav (Aarav never booked anyone, so the chain ends there).
PROMPT  > NOCYCLE stops infinite loops if two students taught each other (otherwise ORA-01436).
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  WITH learning_edge AS (
PROMPT  |      SELECT DISTINCT
PROMPT  |             b.tutee_id                AS learner_id,
PROMPT  |             b.tutor_id                AS teacher_id,
PROMPT  |             le.first_name             AS learner_name,
PROMPT  |             te.first_name             AS teacher_name
PROMPT  |      FROM   booking b
PROMPT  |             JOIN student le ON le.student_id = b.tutee_id
PROMPT  |             JOIN student te ON te.student_id = b.tutor_id
PROMPT  |      WHERE  b.status = 'COMPLETED')
PROMPT  |  SELECT LEVEL                                                AS hop,
PROMPT  |         LPAD (' ', (LEVEL - 1) * 3) || learner_name          AS learner_chain,
PROMPT  |         teacher_name                                         AS learned_from,
PROMPT  |         SYS_CONNECT_BY_PATH (teacher_name, ' <- ')           AS knowledge_path,
PROMPT  |         CONNECT_BY_ISLEAF                                    AS end_of_chain
PROMPT  |  FROM   learning_edge
PROMPT  |  START WITH learner_id = 102
PROMPT  |  CONNECT BY NOCYCLE PRIOR teacher_id = learner_id
PROMPT  |  ORDER  SIBLINGS BY learner_name;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
WITH learning_edge AS (
    SELECT DISTINCT
           b.tutee_id                AS learner_id,
           b.tutor_id                AS teacher_id,
           le.first_name             AS learner_name,
           te.first_name             AS teacher_name
    FROM   booking b
           JOIN student le ON le.student_id = b.tutee_id
           JOIN student te ON te.student_id = b.tutor_id
    WHERE  b.status = 'COMPLETED')
SELECT LEVEL                                                AS hop,
       LPAD (' ', (LEVEL - 1) * 3) || learner_name          AS learner_chain,
       teacher_name                                         AS learned_from,
       SYS_CONNECT_BY_PATH (teacher_name, ' <- ')           AS knowledge_path,
       CONNECT_BY_ISLEAF                                    AS end_of_chain
FROM   learning_edge
START WITH learner_id = 102
CONNECT BY NOCYCLE PRIOR teacher_id = learner_id
ORDER  SIBLINGS BY learner_name;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  E3. Cross-department knowledge flow (ROLLUP)
PROMPT  > ROLLUP: how much tutoring crosses department boundaries (with subtotals and grand total).
PROMPT  > This is why DEPARTMENT is in the model at all.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT CASE WHEN GROUPING (sd.school) = 1 THEN '** ALL SCHOOLS **'
PROMPT  |              ELSE sd.school END                      AS tutor_school,
PROMPT  |         CASE WHEN GROUPING (subd.school) = 1 THEN '** all subjects **'
PROMPT  |              ELSE subd.school END                    AS subject_school,
PROMPT  |         COUNT (*)                                    AS sessions,
PROMPT  |         SUM (b.duration_hours)                       AS hours,
PROMPT  |         COUNT (DISTINCT b.tutor_id)                  AS tutors
PROMPT  |  FROM   booking b
PROMPT  |         JOIN student    s    ON s.student_id    = b.tutor_id
PROMPT  |         JOIN department sd   ON sd.dept_id      = s.dept_id
PROMPT  |         JOIN subject    sub  ON sub.subject_id  = b.subject_id
PROMPT  |         JOIN department subd ON subd.dept_id    = sub.dept_id
PROMPT  |  WHERE  b.status = 'COMPLETED'
PROMPT  |  GROUP  BY ROLLUP (sd.school, subd.school)
PROMPT  |  ORDER  BY GROUPING (sd.school), tutor_school,
PROMPT  |            GROUPING (subd.school), subject_school;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT CASE WHEN GROUPING (sd.school) = 1 THEN '** ALL SCHOOLS **'
            ELSE sd.school END                      AS tutor_school,
       CASE WHEN GROUPING (subd.school) = 1 THEN '** all subjects **'
            ELSE subd.school END                    AS subject_school,
       COUNT (*)                                    AS sessions,
       SUM (b.duration_hours)                       AS hours,
       COUNT (DISTINCT b.tutor_id)                  AS tutors
FROM   booking b
       JOIN student    s    ON s.student_id    = b.tutor_id
       JOIN department sd   ON sd.dept_id      = s.dept_id
       JOIN subject    sub  ON sub.subject_id  = b.subject_id
       JOIN department subd ON subd.dept_id    = sub.dept_id
WHERE  b.status = 'COMPLETED'
GROUP  BY ROLLUP (sd.school, subd.school)
ORDER  BY GROUPING (sd.school), tutor_school,
          GROUPING (subd.school), subject_school;
SET ECHO OFF
PROMPT
PROMPT ===> All steps of this file are done. Results stay above - scroll up.
PROMPT ===> Type EXIT and press Enter when you want to close this window.
