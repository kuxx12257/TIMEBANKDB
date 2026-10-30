SET DEFINE OFF

SET SERVEROUTPUT ON


@@_formats.sql
SET ECHO OFF
SET TRIMOUT ON
SET TAB OFF
PROMPT
PROMPT ################################################################
PROMPT #  MEMBER 1 : Onboarding and student profiles
PROMPT #  Each step: read the explanation, press ENTER to run it.
PROMPT ################################################################
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M1-INSERT : register a student
PROMPT  > Registers a new student (Tanvi) using the procedure pkg_timebank.enrol_student.
PROMPT  > One transaction does 2 writes: the STUDENT row + a starter GRANT of 3 credits in CREDIT_TXN.
PROMPT  > So a student can never exist without credits (TOTAL participation in 'posts').
PROMPT  > Her 2 phone numbers go into STUDENT_PHONE: PhoneNo is a MULTIVALUED attribute -> own table.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  DECLARE
PROMPT  |    v_new_id  NUMBER;
PROMPT  |  BEGIN
PROMPT  |    pkg_timebank.enrol_student (
PROMPT  |        p_reg_no     => '25BCE1099',
PROMPT  |        p_first_name => 'Tanvi',
PROMPT  |        p_last_name  => 'Krishnan',
PROMPT  |        p_email      => 'tanvi.krishnan@vit.ac.in',
PROMPT  |        p_dob        => DATE '2005-06-12',
PROMPT  |        p_dept_id    => 1,
PROMPT  |        p_block      => 'B Block',
PROMPT  |        p_room_no    => '140',
PROMPT  |        p_city       => 'Madurai',
PROMPT  |        p_student_id => v_new_id);
PROMPT  |  
PROMPT  |    INSERT INTO student_phone VALUES (v_new_id, '9500011223');
PROMPT  |    INSERT INTO student_phone VALUES (v_new_id, '9500099887');
PROMPT  |  
PROMPT  |    DBMS_OUTPUT.PUT_LINE ('Registered student ' || v_new_id ||
PROMPT  |                          ', opening balance ' ||
PROMPT  |                          pkg_timebank.fn_balance (v_new_id));
PROMPT  |    COMMIT;
PROMPT  |  END;
PROMPT  |  /
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
DECLARE
  v_new_id  NUMBER;
BEGIN
  pkg_timebank.enrol_student (
      p_reg_no     => '25BCE1099',
      p_first_name => 'Tanvi',
      p_last_name  => 'Krishnan',
      p_email      => 'tanvi.krishnan@vit.ac.in',
      p_dob        => DATE '2005-06-12',
      p_dept_id    => 1,
      p_block      => 'B Block',
      p_room_no    => '140',
      p_city       => 'Madurai',
      p_student_id => v_new_id);

  INSERT INTO student_phone VALUES (v_new_id, '9500011223');
  INSERT INTO student_phone VALUES (v_new_id, '9500099887');

  DBMS_OUTPUT.PUT_LINE ('Registered student ' || v_new_id ||
                        ', opening balance ' ||
                        pkg_timebank.fn_balance (v_new_id));
  COMMIT;
END;
/
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M1-UPDATE : close an account (soft delete)
PROMPT  > Closes Sara's account by setting account_status = 'INACTIVE' (a SOFT delete), then restores it.
PROMPT  > Why not DELETE? BOOKING and CREDIT_TXN reference STUDENT with no ON DELETE clause,
PROMPT  > so Oracle would block the delete to protect session history and the ledger.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  UPDATE student
PROMPT  |  WHERE  student_id     = 108
PROMPT  |  AND    account_status = 'ACTIVE';
PROMPT  |  
PROMPT  |  COMMIT;
PROMPT  |  
PROMPT  |  UPDATE student SET account_status = 'ACTIVE' WHERE student_id = 108;
PROMPT  |  COMMIT;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
UPDATE student
SET    account_status = 'INACTIVE'
WHERE  student_id     = 108
AND    account_status = 'ACTIVE';

COMMIT;

UPDATE student SET account_status = 'ACTIVE' WHERE student_id = 108;
COMMIT;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M1-DELETE : remove an unused phone number
PROMPT  > Deletes one of Aarav's two phone numbers.
PROMPT  > This is a safe, real DELETE: STUDENT_PHONE came from a multivalued attribute and no table references it.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  DELETE FROM student_phone
PROMPT  |  WHERE  student_id = 101
PROMPT  |  AND    phone_no   = '9003344556';
PROMPT  |  
PROMPT  |  COMMIT;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
DELETE FROM student_phone
WHERE  student_id = 101
AND    phone_no   = '9003344556';

COMMIT;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M1-Q1 : student directory (SIMPLE)
PROMPT  > SIMPLE query: the student directory.
PROMPT  > AGE is a DERIVED attribute - it is NOT stored. It is calculated from DOB:
PROMPT  > FLOOR(MONTHS_BETWEEN(SYSDATE, dob)/12).
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT s.student_id,
PROMPT  |         s.reg_no,
PROMPT  |         s.first_name || ' ' || s.last_name          AS full_name,
PROMPT  |         FLOOR (MONTHS_BETWEEN (SYSDATE, s.dob)/12)  AS age,
PROMPT  |         s.city,
PROMPT  |         TO_CHAR (s.join_date, 'DD-MON-YYYY')        AS joined,
PROMPT  |         s.account_status
PROMPT  |  FROM   student s
PROMPT  |  WHERE  s.account_status = 'ACTIVE'
PROMPT  |  ORDER  BY s.student_id;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT s.student_id,
       s.reg_no,
       s.first_name || ' ' || s.last_name          AS full_name,
       FLOOR (MONTHS_BETWEEN (SYSDATE, s.dob)/12)  AS age,
       s.city,
       TO_CHAR (s.join_date, 'DD-MON-YYYY')        AS joined,
       s.account_status
FROM   student s
WHERE  s.account_status = 'ACTIVE'
ORDER  BY s.student_id;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M1-Q2 : tutor / tutee / both / neither (JOIN)
PROMPT  > *** MOST IMPORTANT QUERY OF MEMBER 1 *** - a 4-table JOIN with two LEFT JOINs.
PROMPT  > It labels every student: TUTOR ONLY / TUTEE ONLY / BOTH / NEITHER YET.
PROMPT  > BOTH (Kabir, Arjun) proves the specialization is OVERLAPPING.
PROMPT  > NEITHER YET (Sara) proves it is PARTIAL. So we used mapping option 8A (superclass + subclass tables).
PROMPT  > LEFT JOIN is required - an INNER JOIN would hide students missing from a subclass.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT s.student_id,
PROMPT  |         s.first_name || ' ' || s.last_name  AS full_name,
PROMPT  |         d.school,
PROMPT  |         CASE
PROMPT  |           WHEN t.student_id IS NOT NULL
PROMPT  |            AND e.student_id IS NOT NULL THEN 'BOTH'
PROMPT  |           WHEN t.student_id IS NOT NULL THEN 'TUTOR ONLY'
PROMPT  |           WHEN e.student_id IS NOT NULL THEN 'TUTEE ONLY'
PROMPT  |           ELSE                               'NEITHER YET'
PROMPT  |         END                                 AS role_in_system,
PROMPT  |         NVL (t.badge_level, '-')            AS badge,
PROMPT  |         NVL (e.academic_need_tier, '-')     AS need_tier
PROMPT  |  FROM   student s
PROMPT  |         JOIN      department d ON d.dept_id    = s.dept_id
PROMPT  |         LEFT JOIN tutor      t ON t.student_id = s.student_id
PROMPT  |         LEFT JOIN tutee      e ON e.student_id = s.student_id
PROMPT  |  ORDER  BY role_in_system, s.student_id;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT s.student_id,
       s.first_name || ' ' || s.last_name  AS full_name,
       d.school,
       CASE
         WHEN t.student_id IS NOT NULL
          AND e.student_id IS NOT NULL THEN 'BOTH'
         WHEN t.student_id IS NOT NULL THEN 'TUTOR ONLY'
         WHEN e.student_id IS NOT NULL THEN 'TUTEE ONLY'
         ELSE                               'NEITHER YET'
       END                                 AS role_in_system,
       NVL (t.badge_level, '-')            AS badge,
       NVL (e.academic_need_tier, '-')     AS need_tier
FROM   student s
       JOIN      department d ON d.dept_id    = s.dept_id
       LEFT JOIN tutor      t ON t.student_id = s.student_id
       LEFT JOIN tutee      e ON e.student_id = s.student_id
ORDER  BY role_in_system, s.student_id;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M1-Q3 : balance below campus average (NESTED)
PROMPT  > NESTED (non-correlated) subquery: students whose balance is below the campus average.
PROMPT  > The inner subquery does not use the outer row, so Oracle runs it only ONCE.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT s.student_id,
PROMPT  |         s.first_name || ' ' || s.last_name       AS full_name,
PROMPT  |         pkg_timebank.fn_balance (s.student_id)   AS credit_balance,
PROMPT  |         (SELECT policy_value
PROMPT  |          FROM   credit_policy
PROMPT  |          WHERE  policy_key = 'OVERDRAFT_FLOOR')  AS floor_is,
PROMPT  |         CASE WHEN pkg_timebank.fn_balance (s.student_id) <= 0.5
PROMPT  |              THEN 'NUDGE TO TUTOR' ELSE 'ok' END AS action
PROMPT  |  FROM   student s
PROMPT  |  WHERE  pkg_timebank.fn_balance (s.student_id) <
PROMPT  |         (SELECT AVG (total)                      -- evaluated once
PROMPT  |          FROM  (SELECT SUM (amount) AS total     -- inner-inner query
PROMPT  |                 FROM   credit_txn
PROMPT  |                 GROUP  BY student_id))
PROMPT  |  ORDER  BY credit_balance, s.student_id;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT s.student_id,
       s.first_name || ' ' || s.last_name       AS full_name,
       pkg_timebank.fn_balance (s.student_id)   AS credit_balance,
       (SELECT policy_value
        FROM   credit_policy
        WHERE  policy_key = 'OVERDRAFT_FLOOR')  AS floor_is,
       CASE WHEN pkg_timebank.fn_balance (s.student_id) <= 0.5
            THEN 'NUDGE TO TUTOR' ELSE 'ok' END AS action
FROM   student s
WHERE  pkg_timebank.fn_balance (s.student_id) <
       (SELECT AVG (total)                      -- evaluated once
        FROM  (SELECT SUM (amount) AS total     -- inner-inner query
               FROM   credit_txn
               GROUP  BY student_id))
ORDER  BY credit_balance, s.student_id;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M1-Q4 : registered but never booked (CORRELATED)
PROMPT  > CORRELATED subquery: joined more than 30 days ago but never booked a session.
PROMPT  > NOT EXISTS uses s.student_id from the outer query, so it is re-run for EVERY outer row.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT s.student_id,
PROMPT  |         s.first_name || ' ' || s.last_name      AS full_name,
PROMPT  |         TRUNC (SYSDATE - s.join_date)           AS days_since_joining,
PROMPT  |         pkg_timebank.fn_balance (s.student_id)  AS unused_credits
PROMPT  |  FROM   student s
PROMPT  |  WHERE  SYSDATE - s.join_date > 30
PROMPT  |  AND    NOT EXISTS (SELECT 1
PROMPT  |                     FROM   booking b
PROMPT  |                     WHERE  b.tutee_id = s.student_id)   -- correlation
PROMPT  |  ORDER  BY days_since_joining DESC;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT s.student_id,
       s.first_name || ' ' || s.last_name      AS full_name,
       TRUNC (SYSDATE - s.join_date)           AS days_since_joining,
       pkg_timebank.fn_balance (s.student_id)  AS unused_credits
FROM   student s
WHERE  SYSDATE - s.join_date > 30
AND    NOT EXISTS (SELECT 1
                   FROM   booking b
                   WHERE  b.tutee_id = s.student_id)   -- correlation
ORDER  BY days_since_joining DESC;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M1-Q5 : department scoreboard (AGGREGATE)
PROMPT  > AGGREGATE with GROUP BY and HAVING: a department scoreboard.
PROMPT  > WHERE filters ROWS before grouping; HAVING filters GROUPS after grouping (it can use COUNT).
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT d.school,
PROMPT  |         d.dept_name,
PROMPT  |         COUNT (s.student_id)                                AS students,
PROMPT  |         SUM (CASE WHEN t.student_id IS NOT NULL
PROMPT  |                   THEN 1 ELSE 0 END)                        AS tutors,
PROMPT  |         SUM (CASE WHEN e.student_id IS NOT NULL
PROMPT  |                   THEN 1 ELSE 0 END)                        AS tutees,
PROMPT  |         ROUND (AVG (FLOOR (MONTHS_BETWEEN (SYSDATE, s.dob)/12)), 1)
PROMPT  |                                                             AS avg_age,
PROMPT  |         RPAD ('*', GREATEST (COUNT (s.student_id), 1), '*') AS size_bar
PROMPT  |  FROM   department d
PROMPT  |         JOIN      student s ON s.dept_id    = d.dept_id
PROMPT  |         LEFT JOIN tutor   t ON t.student_id = s.student_id
PROMPT  |         LEFT JOIN tutee   e ON e.student_id = s.student_id
PROMPT  |  WHERE  s.account_status = 'ACTIVE'          -- filters ROWS
PROMPT  |  GROUP  BY d.school, d.dept_name
PROMPT  |  HAVING COUNT (s.student_id) >= 1            -- filters GROUPS
PROMPT  |  ORDER  BY students DESC;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT d.school,
       d.dept_name,
       COUNT (s.student_id)                                AS students,
       SUM (CASE WHEN t.student_id IS NOT NULL
                 THEN 1 ELSE 0 END)                        AS tutors,
       SUM (CASE WHEN e.student_id IS NOT NULL
                 THEN 1 ELSE 0 END)                        AS tutees,
       ROUND (AVG (FLOOR (MONTHS_BETWEEN (SYSDATE, s.dob)/12)), 1)
                                                           AS avg_age,
       RPAD ('*', GREATEST (COUNT (s.student_id), 1), '*') AS size_bar
FROM   department d
       JOIN      student s ON s.dept_id    = d.dept_id
       LEFT JOIN tutor   t ON t.student_id = s.student_id
       LEFT JOIN tutee   e ON e.student_id = s.student_id
WHERE  s.account_status = 'ACTIVE'          -- filters ROWS
GROUP  BY d.school, d.dept_name
HAVING COUNT (s.student_id) >= 1            -- filters GROUPS
ORDER  BY students DESC;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M1-Q6 : balance ranking within department (ANALYTIC)
PROMPT  > ANALYTIC (window) functions: rank students by credit balance inside their department.
PROMPT  > RANK, DENSE_RANK, PERCENT_RANK, NTILE, LAG with PARTITION BY department.
PROMPT  > Unlike GROUP BY, window functions keep EVERY row and add the rank beside it.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT d.school,
PROMPT  |         s.first_name || ' ' || s.last_name                  AS full_name,
PROMPT  |         v.credit_balance,
PROMPT  |         RANK () OVER (PARTITION BY s.dept_id
PROMPT  |                       ORDER BY v.credit_balance DESC)       AS rank_in_dept,
PROMPT  |         DENSE_RANK () OVER (PARTITION BY s.dept_id
PROMPT  |                             ORDER BY v.credit_balance DESC) AS dense_rank,
PROMPT  |         ROUND (PERCENT_RANK () OVER (PARTITION BY s.dept_id
PROMPT  |                                      ORDER BY v.credit_balance), 2)
PROMPT  |                                                             AS percentile,
PROMPT  |         NTILE (3) OVER (PARTITION BY s.dept_id
PROMPT  |                         ORDER BY v.credit_balance DESC)     AS third,
PROMPT  |         LAG (v.credit_balance) OVER (PARTITION BY s.dept_id
PROMPT  |                                      ORDER BY v.credit_balance DESC)
PROMPT  |                                                             AS person_above,
PROMPT  |         COUNT (*) OVER (PARTITION BY s.dept_id)             AS dept_size
PROMPT  |  FROM   student s
PROMPT  |         JOIN department        d ON d.dept_id    = s.dept_id
PROMPT  |         JOIN v_student_balance v ON v.student_id = s.student_id
PROMPT  |  ORDER  BY d.school, rank_in_dept;
PROMPT  |  
PROMPT  |  
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT d.school,
       s.first_name || ' ' || s.last_name                  AS full_name,
       v.credit_balance,
       RANK () OVER (PARTITION BY s.dept_id
                     ORDER BY v.credit_balance DESC)       AS rank_in_dept,
       DENSE_RANK () OVER (PARTITION BY s.dept_id
                           ORDER BY v.credit_balance DESC) AS dense_rank,
       ROUND (PERCENT_RANK () OVER (PARTITION BY s.dept_id
                                    ORDER BY v.credit_balance), 2)
                                                           AS percentile,
       NTILE (3) OVER (PARTITION BY s.dept_id
                       ORDER BY v.credit_balance DESC)     AS third,
       LAG (v.credit_balance) OVER (PARTITION BY s.dept_id
                                    ORDER BY v.credit_balance DESC)
                                                           AS person_above,
       COUNT (*) OVER (PARTITION BY s.dept_id)             AS dept_size
FROM   student s
       JOIN department        d ON d.dept_id    = s.dept_id
       JOIN v_student_balance v ON v.student_id = s.student_id
ORDER  BY d.school, rank_in_dept;


PROMPT
PROMPT ===== MEMBER 1 COMPLETE : 3 DML + 6 SELECT = 9 queries =====
SET ECHO OFF
PROMPT
PROMPT ===> All steps of this file are done. Results stay above - scroll up.
PROMPT ===> Type EXIT and press Enter when you want to close this window.
