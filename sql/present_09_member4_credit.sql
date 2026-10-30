SET DEFINE OFF

SET SERVEROUTPUT ON


@@_formats.sql
SET ECHO OFF
SET TRIMOUT ON
SET TAB OFF
PROMPT
PROMPT ################################################################
PROMPT #  MEMBER 4 : Escrow and the credit ledger
PROMPT #  Each step: read the explanation, press ENTER to run it.
PROMPT ################################################################
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M4-INSERT : goodwill credit after an outage
PROMPT  > Inserts a goodwill GRANT of +1 credit for Ananya directly into the ledger.
PROMPT  > balance_snapshot is computed inside the same statement (balance before + amount).
PROMPT  > booking_id is NULL - it is the ONLY nullable foreign key in the schema
PROMPT  > (partial participation of CREDIT_TXN in 'generates': grants have no session).
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  INSERT INTO credit_txn (
PROMPT  |      txn_id, txn_type, amount, balance_snapshot,
PROMPT  |      remarks, student_id, booking_id)
PROMPT  |  VALUES (
PROMPT  |      seq_txn.NEXTVAL,
PROMPT  |      'GRANT',
PROMPT  |      1.0,
PROMPT  |      (SELECT NVL (SUM (amount), 0) + 1.0
PROMPT  |       FROM   credit_txn
PROMPT  |       WHERE  student_id = 106),
PROMPT  |      'Goodwill credit: scheduling outage on the platform',
PROMPT  |      106,
PROMPT  |      NULL);
PROMPT  |  
PROMPT  |  COMMIT;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
INSERT INTO credit_txn (
    txn_id, txn_type, amount, balance_snapshot,
    remarks, student_id, booking_id)
VALUES (
    seq_txn.NEXTVAL,
    'GRANT',
    1.0,
    (SELECT NVL (SUM (amount), 0) + 1.0
     FROM   credit_txn
     WHERE  student_id = 106),
    'Goodwill credit: scheduling outage on the platform',
    106,
    NULL);

COMMIT;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M4-UPDATE : tighten the overdraft policy
PROMPT  > Tightens the overdraft rule from -5 to -4 credits in CREDIT_POLICY, then restores it.
PROMPT  > Rules live in a table (an index-organised table), so changing a rule needs no code change.
PROMPT  > The trigger trg_credit_floor reads this value on every booking.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  UPDATE credit_policy
PROMPT  |         description  = description || ' (tightened after review)'
PROMPT  |  WHERE  policy_key   = 'OVERDRAFT_FLOOR';
PROMPT  |  
PROMPT  |  COMMIT;
PROMPT  |  
PROMPT  |  UPDATE credit_policy
PROMPT  |         description  = 'A balance may never fall below this value'
PROMPT  |  WHERE  policy_key   = 'OVERDRAFT_FLOOR';
PROMPT  |  
PROMPT  |  COMMIT;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
UPDATE credit_policy
SET    policy_value = -4.0,
       description  = description || ' (tightened after review)'
WHERE  policy_key   = 'OVERDRAFT_FLOOR';

COMMIT;

UPDATE credit_policy
SET    policy_value = -5.0,
       description  = 'A balance may never fall below this value'
WHERE  policy_key   = 'OVERDRAFT_FLOOR';

COMMIT;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M4-DELETE : clear escrow, then a true delete
PROMPT  > Clears stale escrow values on finished bookings (kept with COMMIT),
PROMPT  > then DELETEs a policy row and immediately ROLLBACKs - showing a delete can be undone
PROMPT  > before COMMIT.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  UPDATE booking
PROMPT  |  WHERE  status IN ('COMPLETED','CANCELLED')
PROMPT  |  AND    credits_held > 0;
PROMPT  |  
PROMPT  |  COMMIT;
PROMPT  |  
PROMPT  |  DELETE FROM credit_policy
PROMPT  |  WHERE  policy_key = 'LATE_CANCEL_SHARE'
PROMPT  |  AND    NOT EXISTS (SELECT 1 FROM booking WHERE status = 'DISPUTED');
PROMPT  |  
PROMPT  |  ROLLBACK;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
UPDATE booking
SET    credits_held = 0
WHERE  status IN ('COMPLETED','CANCELLED')
AND    credits_held > 0;

COMMIT;

DELETE FROM credit_policy
WHERE  policy_key = 'LATE_CANCEL_SHARE'
AND    NOT EXISTS (SELECT 1 FROM booking WHERE status = 'DISPUTED');

ROLLBACK;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M4-PROOF : attempts to tamper with the ledger
PROMPT  > *** SCREENSHOT THIS *** Two attempts to tamper with the ledger:
PROMPT  > an UPDATE and a DELETE on CREDIT_TXN. Both MUST fail with ORA-20001.
PROMPT  > The trigger trg_txn_immutable makes the ledger APPEND-ONLY (like real accounting).
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  BEGIN
PROMPT  |    UPDATE credit_txn SET amount = 999 WHERE txn_id = 1;
PROMPT  |    DBMS_OUTPUT.PUT_LINE ('!! UPDATE succeeded -- the ledger is NOT protected');
PROMPT  |  EXCEPTION
PROMPT  |    WHEN OTHERS THEN
PROMPT  |      DBMS_OUTPUT.PUT_LINE ('Blocked as designed -> ' || SQLERRM);
PROMPT  |  END;
PROMPT  |  /
PROMPT  |  
PROMPT  |  BEGIN
PROMPT  |    DELETE FROM credit_txn WHERE txn_id = 1;
PROMPT  |    DBMS_OUTPUT.PUT_LINE ('!! DELETE succeeded -- the ledger is NOT protected');
PROMPT  |  EXCEPTION
PROMPT  |    WHEN OTHERS THEN
PROMPT  |      DBMS_OUTPUT.PUT_LINE ('Blocked as designed -> ' || SQLERRM);
PROMPT  |  END;
PROMPT  |  /
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
BEGIN
  UPDATE credit_txn SET amount = 999 WHERE txn_id = 1;
  DBMS_OUTPUT.PUT_LINE ('!! UPDATE succeeded -- the ledger is NOT protected');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE ('Blocked as designed -> ' || SQLERRM);
END;
/

BEGIN
  DELETE FROM credit_txn WHERE txn_id = 1;
  DBMS_OUTPUT.PUT_LINE ('!! DELETE succeeded -- the ledger is NOT protected');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE ('Blocked as designed -> ' || SQLERRM);
END;
/
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M4-Q1 : passbook for student 102 (SIMPLE)
PROMPT  > SIMPLE query: the passbook of student 102 (Diya), newest first.
PROMPT  > GRANT +3, then HOLDs (negative) when she booked, RELEASE when a booking was cancelled.
PROMPT  > Uses the index idx_txn_student_time (student_id, txn_timestamp).
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT t.txn_id,
PROMPT  |         TO_CHAR (t.txn_timestamp, 'DD-MON HH24:MI') AS posted_at,
PROMPT  |         t.txn_type,
PROMPT  |         t.amount,
PROMPT  |         t.balance_snapshot                          AS balance_after,
PROMPT  |         NVL (TO_CHAR (t.booking_id), '-')           AS booking,
PROMPT  |         t.remarks
PROMPT  |  FROM   credit_txn t
PROMPT  |  WHERE  t.student_id = 102
PROMPT  |  ORDER  BY t.txn_id DESC;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT t.txn_id,
       TO_CHAR (t.txn_timestamp, 'DD-MON HH24:MI') AS posted_at,
       t.txn_type,
       t.amount,
       t.balance_snapshot                          AS balance_after,
       NVL (TO_CHAR (t.booking_id), '-')           AS booking,
       t.remarks
FROM   credit_txn t
WHERE  t.student_id = 102
ORDER  BY t.txn_id DESC;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M4-Q2 : ledger with session context (OUTER JOIN)
PROMPT  > JOIN with LEFT OUTER JOIN: each ledger row with the session that caused it.
PROMPT  > Must be OUTER: booking_id is NULL for GRANT/PENALTY rows, an INNER join would drop them.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT t.txn_id,
PROMPT  |         s.first_name || ' ' || s.last_name       AS student_name,
PROMPT  |         t.txn_type,
PROMPT  |         t.amount,
PROMPT  |         NVL (sub.subject_code, 'n/a')            AS subject,
PROMPT  |         NVL (TO_CHAR (b.sched_date, 'DD-MON'), 'no session')
PROMPT  |                                                  AS session_date,
PROMPT  |         CASE WHEN t.booking_id IS NULL
PROMPT  |              THEN 'system credit'
PROMPT  |              ELSE 'session driven' END            AS origin
PROMPT  |  FROM   credit_txn t
PROMPT  |         JOIN      student s   ON s.student_id   = t.student_id
PROMPT  |         LEFT JOIN booking b   ON b.booking_id   = t.booking_id
PROMPT  |         LEFT JOIN subject sub ON sub.subject_id = b.subject_id
PROMPT  |  ORDER  BY t.txn_id;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT t.txn_id,
       s.first_name || ' ' || s.last_name       AS student_name,
       t.txn_type,
       t.amount,
       NVL (sub.subject_code, 'n/a')            AS subject,
       NVL (TO_CHAR (b.sched_date, 'DD-MON'), 'no session')
                                                AS session_date,
       CASE WHEN t.booking_id IS NULL
            THEN 'system credit'
            ELSE 'session driven' END            AS origin
FROM   credit_txn t
       JOIN      student s   ON s.student_id   = t.student_id
       LEFT JOIN booking b   ON b.booking_id   = t.booking_id
       LEFT JOIN subject sub ON sub.subject_id = b.subject_id
ORDER  BY t.txn_id;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M4-Q3 : who gives and who takes (NESTED)
PROMPT  > NESTED subquery in the FROM clause (inline view): net givers vs net takers.
PROMPT  > The inner query totals the ledger per student; the outer query classifies them.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT s.first_name || ' ' || s.last_name   AS student_name,
PROMPT  |         led.total_in                         AS credits_in,
PROMPT  |         led.total_out                        AS credits_out,
PROMPT  |         led.balance,
PROMPT  |         CASE
PROMPT  |           WHEN led.balance > 3.0  THEN 'NET GIVER'
PROMPT  |           WHEN led.balance < 1.0  THEN 'NET TAKER'
PROMPT  |           ELSE                         'balanced'
PROMPT  |         END                                  AS standing
PROMPT  |  FROM   student s
PROMPT  |         JOIN (SELECT student_id,
PROMPT  |                      SUM (CASE WHEN amount > 0 THEN amount ELSE 0 END) AS total_in,
PROMPT  |                      SUM (CASE WHEN amount < 0 THEN amount ELSE 0 END) AS total_out,
PROMPT  |                      SUM (amount)                                      AS balance
PROMPT  |               FROM   credit_txn
PROMPT  |               GROUP  BY student_id) led
PROMPT  |           ON led.student_id = s.student_id
PROMPT  |  ORDER  BY led.balance DESC;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT s.first_name || ' ' || s.last_name   AS student_name,
       led.total_in                         AS credits_in,
       led.total_out                        AS credits_out,
       led.balance,
       CASE
         WHEN led.balance > 3.0  THEN 'NET GIVER'
         WHEN led.balance < 1.0  THEN 'NET TAKER'
         ELSE                         'balanced'
       END                                  AS standing
FROM   student s
       JOIN (SELECT student_id,
                    SUM (CASE WHEN amount > 0 THEN amount ELSE 0 END) AS total_in,
                    SUM (CASE WHEN amount < 0 THEN amount ELSE 0 END) AS total_out,
                    SUM (amount)                                      AS balance
             FROM   credit_txn
             GROUP  BY student_id) led
         ON led.student_id = s.student_id
ORDER  BY led.balance DESC;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M4-Q4 : ledger tamper check (CORRELATED) -- expect 0 rows
PROMPT  > CORRELATED subquery = TAMPER CHECK. Every snapshot must equal previous snapshot + amount.
PROMPT  > EXPECTED RESULT: 'no rows selected'. No rows = the ledger has never been edited = PASS.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT t.txn_id,
PROMPT  |         t.student_id,
PROMPT  |         t.amount,
PROMPT  |         t.balance_snapshot                       AS recorded,
PROMPT  |         NVL ((SELECT t2.balance_snapshot
PROMPT  |               FROM   credit_txn t2
PROMPT  |               WHERE  t2.student_id = t.student_id
PROMPT  |               AND    t2.txn_id     = (SELECT MAX (t3.txn_id)
PROMPT  |                                       FROM   credit_txn t3
PROMPT  |                                       WHERE  t3.student_id = t.student_id
PROMPT  |                                       AND    t3.txn_id     < t.txn_id)), 0)
PROMPT  |           + t.amount                             AS expected
PROMPT  |  FROM   credit_txn t
PROMPT  |  WHERE  t.balance_snapshot <>
PROMPT  |         NVL ((SELECT t2.balance_snapshot
PROMPT  |               FROM   credit_txn t2
PROMPT  |               WHERE  t2.student_id = t.student_id
PROMPT  |               AND    t2.txn_id     = (SELECT MAX (t3.txn_id)
PROMPT  |                                       FROM   credit_txn t3
PROMPT  |                                       WHERE  t3.student_id = t.student_id
PROMPT  |                                       AND    t3.txn_id     < t.txn_id)), 0)
PROMPT  |           + t.amount
PROMPT  |  ORDER  BY t.txn_id;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT t.txn_id,
       t.student_id,
       t.amount,
       t.balance_snapshot                       AS recorded,
       NVL ((SELECT t2.balance_snapshot
             FROM   credit_txn t2
             WHERE  t2.student_id = t.student_id
             AND    t2.txn_id     = (SELECT MAX (t3.txn_id)
                                     FROM   credit_txn t3
                                     WHERE  t3.student_id = t.student_id
                                     AND    t3.txn_id     < t.txn_id)), 0)
         + t.amount                             AS expected
FROM   credit_txn t
WHERE  t.balance_snapshot <>
       NVL ((SELECT t2.balance_snapshot
             FROM   credit_txn t2
             WHERE  t2.student_id = t.student_id
             AND    t2.txn_id     = (SELECT MAX (t3.txn_id)
                                     FROM   credit_txn t3
                                     WHERE  t3.student_id = t.student_id
                                     AND    t3.txn_id     < t.txn_id)), 0)
         + t.amount
ORDER  BY t.txn_id;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M4-Q5 : closed-economy audit (AGGREGATE)
PROMPT  > *** THE CLOSED-ECONOMY AUDIT *** (most important query of the project)
PROMPT  > First a GROUPING SETS summary per transaction type with a grand total,
PROMPT  > then the equation:  all balances + escrow  =  grants - penalties.
PROMPT  > VERDICT must say BALANCED (drift 0): no credits were created or lost.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT NVL (txn_type, '** ALL TYPES **')   AS txn_kind,
PROMPT  |         COUNT (*)                           AS rows_posted,
PROMPT  |         SUM (amount)                        AS net_credits,
PROMPT  |         MIN (amount)                        AS smallest,
PROMPT  |         MAX (amount)                        AS largest
PROMPT  |  FROM   credit_txn
PROMPT  |  GROUP  BY GROUPING SETS ((txn_type), ())
PROMPT  |  HAVING COUNT (*) >= 1
PROMPT  |  ORDER  BY GROUPING (txn_type), txn_kind;
PROMPT  |  
PROMPT  |  
PROMPT  |  SELECT (SELECT NVL (SUM (amount), 0) FROM credit_txn)          AS all_balances,
PROMPT  |         (SELECT NVL (SUM (credits_held), 0) FROM booking
PROMPT  |          WHERE  status IN ('REQUESTED','CONFIRMED','DISPUTED')) AS in_escrow,
PROMPT  |         (SELECT NVL (SUM (amount), 0) FROM credit_txn
PROMPT  |          WHERE  txn_type IN ('GRANT','PENALTY'))                AS grants_less_penalties,
PROMPT  |         (SELECT NVL (SUM (amount), 0) FROM credit_txn)
PROMPT  |         + (SELECT NVL (SUM (credits_held), 0) FROM booking
PROMPT  |            WHERE  status IN ('REQUESTED','CONFIRMED','DISPUTED'))
PROMPT  |         - (SELECT NVL (SUM (amount), 0) FROM credit_txn
PROMPT  |            WHERE  txn_type IN ('GRANT','PENALTY'))              AS drift,
PROMPT  |         CASE WHEN (SELECT NVL (SUM (amount), 0) FROM credit_txn)
PROMPT  |                   + (SELECT NVL (SUM (credits_held), 0) FROM booking
PROMPT  |                      WHERE status IN ('REQUESTED','CONFIRMED','DISPUTED'))
PROMPT  |                   - (SELECT NVL (SUM (amount), 0) FROM credit_txn
PROMPT  |                      WHERE txn_type IN ('GRANT','PENALTY')) = 0
PROMPT  |              THEN 'BALANCED'
PROMPT  |              ELSE '*** BROKEN ***' END                          AS verdict
PROMPT  |  FROM   dual;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT NVL (txn_type, '** ALL TYPES **')   AS txn_kind,
       COUNT (*)                           AS rows_posted,
       SUM (amount)                        AS net_credits,
       MIN (amount)                        AS smallest,
       MAX (amount)                        AS largest
FROM   credit_txn
GROUP  BY GROUPING SETS ((txn_type), ())
HAVING COUNT (*) >= 1
ORDER  BY GROUPING (txn_type), txn_kind;

PROMPT
PROMPT --- the balance equation itself

SELECT (SELECT NVL (SUM (amount), 0) FROM credit_txn)          AS all_balances,
       (SELECT NVL (SUM (credits_held), 0) FROM booking
        WHERE  status IN ('REQUESTED','CONFIRMED','DISPUTED')) AS in_escrow,
       (SELECT NVL (SUM (amount), 0) FROM credit_txn
        WHERE  txn_type IN ('GRANT','PENALTY'))                AS grants_less_penalties,
       (SELECT NVL (SUM (amount), 0) FROM credit_txn)
       + (SELECT NVL (SUM (credits_held), 0) FROM booking
          WHERE  status IN ('REQUESTED','CONFIRMED','DISPUTED'))
       - (SELECT NVL (SUM (amount), 0) FROM credit_txn
          WHERE  txn_type IN ('GRANT','PENALTY'))              AS drift,
       CASE WHEN (SELECT NVL (SUM (amount), 0) FROM credit_txn)
                 + (SELECT NVL (SUM (credits_held), 0) FROM booking
                    WHERE status IN ('REQUESTED','CONFIRMED','DISPUTED'))
                 - (SELECT NVL (SUM (amount), 0) FROM credit_txn
                    WHERE txn_type IN ('GRANT','PENALTY')) = 0
            THEN 'BALANCED'
            ELSE '*** BROKEN ***' END                          AS verdict
FROM   dual;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M4-Q6 : recomputed running balance (ANALYTIC)
PROMPT  > ANALYTIC functions: rebuild each student's running balance with SUM() OVER
PROMPT  > and compare it with the stored balance_snapshot. Every row should say 'ok'.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT s.first_name                                  AS student,
PROMPT  |         t.txn_id,
PROMPT  |         t.txn_type,
PROMPT  |         t.amount,
PROMPT  |         SUM (t.amount) OVER (PARTITION BY t.student_id
PROMPT  |                              ORDER BY t.txn_id
PROMPT  |                              ROWS BETWEEN UNBOUNDED PRECEDING
PROMPT  |                                       AND CURRENT ROW) AS recomputed,
PROMPT  |         t.balance_snapshot                             AS stored,
PROMPT  |         CASE WHEN SUM (t.amount) OVER (PARTITION BY t.student_id
PROMPT  |                                        ORDER BY t.txn_id
PROMPT  |                                        ROWS BETWEEN UNBOUNDED PRECEDING
PROMPT  |                                                 AND CURRENT ROW)
PROMPT  |                   = t.balance_snapshot
PROMPT  |              THEN 'ok' ELSE 'MISMATCH' END             AS check_result,
PROMPT  |         LAG (t.txn_type) OVER (PARTITION BY t.student_id
PROMPT  |                                ORDER BY t.txn_id)      AS previous_type,
PROMPT  |         FIRST_VALUE (t.amount) OVER (PARTITION BY t.student_id
PROMPT  |                                      ORDER BY t.txn_id) AS opening_grant
PROMPT  |  FROM   credit_txn t
PROMPT  |         JOIN student s ON s.student_id = t.student_id
PROMPT  |  ORDER  BY t.student_id, t.txn_id;
PROMPT  |  
PROMPT  |  
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT s.first_name                                  AS student,
       t.txn_id,
       t.txn_type,
       t.amount,
       SUM (t.amount) OVER (PARTITION BY t.student_id
                            ORDER BY t.txn_id
                            ROWS BETWEEN UNBOUNDED PRECEDING
                                     AND CURRENT ROW) AS recomputed,
       t.balance_snapshot                             AS stored,
       CASE WHEN SUM (t.amount) OVER (PARTITION BY t.student_id
                                      ORDER BY t.txn_id
                                      ROWS BETWEEN UNBOUNDED PRECEDING
                                               AND CURRENT ROW)
                 = t.balance_snapshot
            THEN 'ok' ELSE 'MISMATCH' END             AS check_result,
       LAG (t.txn_type) OVER (PARTITION BY t.student_id
                              ORDER BY t.txn_id)      AS previous_type,
       FIRST_VALUE (t.amount) OVER (PARTITION BY t.student_id
                                    ORDER BY t.txn_id) AS opening_grant
FROM   credit_txn t
       JOIN student s ON s.student_id = t.student_id
ORDER  BY t.student_id, t.txn_id;


PROMPT
PROMPT ===== MEMBER 4 COMPLETE : 3 DML + 6 SELECT = 9 queries =====
SET ECHO OFF
PROMPT
PROMPT ===> All steps of this file are done. Results stay above - scroll up.
PROMPT ===> Type EXIT and press Enter when you want to close this window.
