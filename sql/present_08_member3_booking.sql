SET DEFINE OFF

SET SERVEROUTPUT ON


@@_formats.sql
SET ECHO OFF
SET TRIMOUT ON
SET TAB OFF
PROMPT
PROMPT ################################################################
PROMPT #  MEMBER 3 : Booking engine
PROMPT #  Each step: read the explanation, press ENTER to run it.
PROMPT ################################################################
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M3-INSERT : book a session
PROMPT  > Sara (who was in NEITHER subclass) becomes a TUTEE, then books Kabir's Friday slot.
PROMPT  > pkg_timebank.book_session does 5 steps atomically:
PROMPT  >   1 lock the slot row (SELECT ... FOR UPDATE)  2 check it is free  3 check the pair weekly cap
PROMPT  >   4 INSERT the booking  5 move credits to escrow (HOLD -1.5 in the ledger).
PROMPT  > Triggers check the overdraft floor and the slot time; the composite FKs check slot+subject belong to the tutor.
PROMPT  > Note the SESSION CODE printed - only the tutee gets it.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  INSERT INTO tutee (student_id, academic_need_tier) VALUES (108, 'BASIC');
PROMPT  |  INSERT INTO tutee_preftime VALUES (108, 'EVENING');
PROMPT  |  
PROMPT  |  DECLARE
PROMPT  |    v_bk    NUMBER;
PROMPT  |    v_code  VARCHAR2(8);
PROMPT  |  BEGIN
PROMPT  |    pkg_timebank.book_session (
PROMPT  |        p_tutee_id     => 108,                       -- Sara
PROMPT  |        p_tutor_id     => 105,                       -- Kabir
PROMPT  |        p_subject_id   => 110,                       -- Operating Systems
PROMPT  |        p_slot_no      => 2,                         -- Kabir's FRI 14-16
PROMPT  |        p_sched_date   => TRUNC (SYSDATE,'IW') + 11, -- Friday next week
PROMPT  |        p_start_time   => 14,
PROMPT  |        p_duration     => 1.5,
PROMPT  |        p_mode         => 'ONLINE',
PROMPT  |        p_venue        => 'MS Teams',
PROMPT  |        p_booking_id   => v_bk,
PROMPT  |        p_session_code => v_code);
PROMPT  |  
PROMPT  |    DBMS_OUTPUT.PUT_LINE ('Booking ' || v_bk || ' created.');
PROMPT  |    DBMS_OUTPUT.PUT_LINE ('Session code for the TUTEE only: ' || v_code);
PROMPT  |    DBMS_OUTPUT.PUT_LINE ('Sara''s balance is now ' ||
PROMPT  |                          pkg_timebank.fn_balance (108));
PROMPT  |    COMMIT;
PROMPT  |  END;
PROMPT  |  /
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
INSERT INTO tutee (student_id, academic_need_tier) VALUES (108, 'BASIC');
INSERT INTO tutee_preftime VALUES (108, 'EVENING');

DECLARE
  v_bk    NUMBER;
  v_code  VARCHAR2(8);
BEGIN
  pkg_timebank.book_session (
      p_tutee_id     => 108,                       -- Sara
      p_tutor_id     => 105,                       -- Kabir
      p_subject_id   => 110,                       -- Operating Systems
      p_slot_no      => 2,                         -- Kabir's FRI 14-16
      p_sched_date   => TRUNC (SYSDATE,'IW') + 11, -- Friday next week
      p_start_time   => 14,
      p_duration     => 1.5,
      p_mode         => 'ONLINE',
      p_venue        => 'MS Teams',
      p_booking_id   => v_bk,
      p_session_code => v_code);

  DBMS_OUTPUT.PUT_LINE ('Booking ' || v_bk || ' created.');
  DBMS_OUTPUT.PUT_LINE ('Session code for the TUTEE only: ' || v_code);
  DBMS_OUTPUT.PUT_LINE ('Sara''s balance is now ' ||
                        pkg_timebank.fn_balance (108));
  COMMIT;
END;
/
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M3-UPDATE : reschedule by one week
PROMPT  > Reschedules the earliest upcoming booking by one week.
PROMPT  > A correlated NOT EXISTS makes sure the new date is free, so rescheduling cannot double-book.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  UPDATE booking b
PROMPT  |         b.venue      = b.venue || ' (rescheduled)'
PROMPT  |  WHERE  b.status IN ('REQUESTED','CONFIRMED')
PROMPT  |  AND    b.sched_date > SYSDATE
PROMPT  |  AND    b.booking_id = (SELECT MIN (booking_id)
PROMPT  |                         FROM   booking
PROMPT  |                         WHERE  status     IN ('REQUESTED','CONFIRMED')
PROMPT  |                         AND    sched_date > SYSDATE)
PROMPT  |  AND    NOT EXISTS (SELECT 1
PROMPT  |                     FROM   booking x
PROMPT  |                     WHERE  x.tutor_id    = b.tutor_id
PROMPT  |                     AND    x.slot_no     = b.slot_no
PROMPT  |                     AND    x.sched_date  = b.sched_date + 7
PROMPT  |                     AND    x.booking_id <> b.booking_id
PROMPT  |                     AND    x.status IN ('REQUESTED','CONFIRMED'));
PROMPT  |  
PROMPT  |  COMMIT;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
UPDATE booking b
SET    b.sched_date = b.sched_date + 7,
       b.venue      = b.venue || ' (rescheduled)'
WHERE  b.status IN ('REQUESTED','CONFIRMED')
AND    b.sched_date > SYSDATE
AND    b.booking_id = (SELECT MIN (booking_id)
                       FROM   booking
                       WHERE  status     IN ('REQUESTED','CONFIRMED')
                       AND    sched_date > SYSDATE)
AND    NOT EXISTS (SELECT 1
                   FROM   booking x
                   WHERE  x.tutor_id    = b.tutor_id
                   AND    x.slot_no     = b.slot_no
                   AND    x.sched_date  = b.sched_date + 7
                   AND    x.booking_id <> b.booking_id
                   AND    x.status IN ('REQUESTED','CONFIRMED'));

COMMIT;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M3-DELETE : purge abandoned requests
PROMPT  > Purges old REQUESTED bookings that have no ledger rows.
PROMPT  > '0 rows deleted' is correct here. CONFIRMED/COMPLETED bookings can NEVER be deleted
PROMPT  > because CREDIT_TXN references them - deleting would orphan money.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  DELETE FROM booking b
PROMPT  |  WHERE  b.status     = 'REQUESTED'
PROMPT  |  AND    b.sched_date < TRUNC (SYSDATE)
PROMPT  |  AND    NOT EXISTS (SELECT 1 FROM credit_txn t
PROMPT  |                     WHERE  t.booking_id = b.booking_id);
PROMPT  |  
PROMPT  |  COMMIT;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
DELETE FROM booking b
WHERE  b.status     = 'REQUESTED'
AND    b.sched_date < TRUNC (SYSDATE)
AND    NOT EXISTS (SELECT 1 FROM credit_txn t
                   WHERE  t.booking_id = b.booking_id);

COMMIT;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M3-Q1 : upcoming sessions (SIMPLE)
PROMPT  > SIMPLE query: upcoming sessions.
PROMPT  > Start time is stored as decimal hours (16.5 = 16:30); dividing by 24 turns it into a clock time.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT b.booking_id,
PROMPT  |         TO_CHAR (b.sched_date, 'DY DD-MON-YYYY')                  AS on_date,
PROMPT  |         TO_CHAR (b.sched_date + b.sched_start_time/24, 'HH24:MI') AS starts,
PROMPT  |         TO_CHAR (b.sched_date
PROMPT  |                  + (b.sched_start_time + b.duration_hours)/24,
PROMPT  |                  'HH24:MI')                                       AS ends,
PROMPT  |         b.duration_hours,
PROMPT  |         b.session_mode,
PROMPT  |         b.venue,
PROMPT  |         b.status,
PROMPT  |         b.credits_held
PROMPT  |  FROM   booking b
PROMPT  |  WHERE  b.sched_date >= TRUNC (SYSDATE)
PROMPT  |  ORDER  BY b.sched_date, b.sched_start_time;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT b.booking_id,
       TO_CHAR (b.sched_date, 'DY DD-MON-YYYY')                  AS on_date,
       TO_CHAR (b.sched_date + b.sched_start_time/24, 'HH24:MI') AS starts,
       TO_CHAR (b.sched_date
                + (b.sched_start_time + b.duration_hours)/24,
                'HH24:MI')                                       AS ends,
       b.duration_hours,
       b.session_mode,
       b.venue,
       b.status,
       b.credits_held
FROM   booking b
WHERE  b.sched_date >= TRUNC (SYSDATE)
ORDER  BY b.sched_date, b.sched_start_time;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M3-Q2 : complete session sheet (SIX-TABLE JOIN)
PROMPT  > 6-table JOIN: the complete session sheet (tutee, tutor, subject, slot, status).
PROMPT  > Every join rebuilds one ER relationship from its foreign key.
PROMPT  > The SLOT join uses BOTH tutor_id AND slot_no because SLOT is a weak entity (composite key).
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT b.booking_id,
PROMPT  |         te.first_name || ' ' || te.last_name     AS tutee_name,
PROMPT  |         tr.first_name || ' ' || tr.last_name     AS tutor_name,
PROMPT  |         sub.subject_code,
PROMPT  |         sl.day_of_week || ' ' || sl.start_time || '-' || sl.end_time
PROMPT  |                                                  AS tutor_slot,
PROMPT  |         TO_CHAR (b.sched_date, 'DD-MON')         AS session_date,
PROMPT  |         b.duration_hours                         AS hrs,
PROMPT  |         b.status,
PROMPT  |         NVL (TO_CHAR (b.check_in_at, 'DD-MON HH24:MI'), 'not checked in')
PROMPT  |                                                  AS check_in,
PROMPT  |         b.confirm_by_tutor || '/' || b.confirm_by_tutee
PROMPT  |                                                  AS confirms
PROMPT  |  FROM   booking b
PROMPT  |         JOIN tutee   e   ON e.student_id   = b.tutee_id
PROMPT  |         JOIN student te  ON te.student_id  = e.student_id
PROMPT  |         JOIN tutor   t   ON t.student_id   = b.tutor_id
PROMPT  |         JOIN student tr  ON tr.student_id  = t.student_id
PROMPT  |         JOIN subject sub ON sub.subject_id = b.subject_id
PROMPT  |         JOIN slot    sl  ON sl.tutor_id    = b.tutor_id    -- composite FK
PROMPT  |                         AND sl.slot_no     = b.slot_no     -- both columns
PROMPT  |  ORDER  BY b.booking_id;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT b.booking_id,
       te.first_name || ' ' || te.last_name     AS tutee_name,
       tr.first_name || ' ' || tr.last_name     AS tutor_name,
       sub.subject_code,
       sl.day_of_week || ' ' || sl.start_time || '-' || sl.end_time
                                                AS tutor_slot,
       TO_CHAR (b.sched_date, 'DD-MON')         AS session_date,
       b.duration_hours                         AS hrs,
       b.status,
       NVL (TO_CHAR (b.check_in_at, 'DD-MON HH24:MI'), 'not checked in')
                                                AS check_in,
       b.confirm_by_tutor || '/' || b.confirm_by_tutee
                                                AS confirms
FROM   booking b
       JOIN tutee   e   ON e.student_id   = b.tutee_id
       JOIN student te  ON te.student_id  = e.student_id
       JOIN tutor   t   ON t.student_id   = b.tutor_id
       JOIN student tr  ON tr.student_id  = t.student_id
       JOIN subject sub ON sub.subject_id = b.subject_id
       JOIN slot    sl  ON sl.tutor_id    = b.tutor_id    -- composite FK
                       AND sl.slot_no     = b.slot_no     -- both columns
ORDER  BY b.booking_id;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M3-Q3 : tutors free all next week (NESTED)
PROMPT  > NESTED subquery with NOT IN: tutors with a completely free diary next week.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT s.first_name || ' ' || s.last_name      AS tutor_name,
PROMPT  |         t.badge_level,
PROMPT  |         (SELECT COUNT (*) FROM slot sl
PROMPT  |          WHERE  sl.tutor_id = t.student_id)     AS slots_published,
PROMPT  |         (SELECT COUNT (*) FROM tutor_skill ts
PROMPT  |          WHERE  ts.tutor_id = t.student_id)     AS subjects_offered
PROMPT  |  FROM   tutor t
PROMPT  |         JOIN student s ON s.student_id = t.student_id
PROMPT  |  WHERE  t.student_id NOT IN (
PROMPT  |           SELECT b.tutor_id
PROMPT  |           FROM   booking b
PROMPT  |           WHERE  b.sched_date BETWEEN TRUNC (SYSDATE,'IW') + 7
PROMPT  |                                   AND TRUNC (SYSDATE,'IW') + 13
PROMPT  |           AND    b.status IN ('REQUESTED','CONFIRMED'))
PROMPT  |  ORDER  BY slots_published DESC;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT s.first_name || ' ' || s.last_name      AS tutor_name,
       t.badge_level,
       (SELECT COUNT (*) FROM slot sl
        WHERE  sl.tutor_id = t.student_id)     AS slots_published,
       (SELECT COUNT (*) FROM tutor_skill ts
        WHERE  ts.tutor_id = t.student_id)     AS subjects_offered
FROM   tutor t
       JOIN student s ON s.student_id = t.student_id
WHERE  t.student_id NOT IN (
         SELECT b.tutor_id
         FROM   booking b
         WHERE  b.sched_date BETWEEN TRUNC (SYSDATE,'IW') + 7
                                 AND TRUNC (SYSDATE,'IW') + 13
         AND    b.status IN ('REQUESTED','CONFIRMED'))
ORDER  BY slots_published DESC;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M3-Q4 : tutors busier than average (CORRELATED)
PROMPT  > CORRELATED subquery: tutors busier than the average tutor.
PROMPT  > This one statement contains BOTH kinds: the correlated one (uses t.student_id, runs per tutor)
PROMPT  > and a non-correlated one (campus average, runs once).
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT s.first_name || ' ' || s.last_name          AS tutor_name,
PROMPT  |         (SELECT COUNT (*)                            -- CORRELATED
PROMPT  |          FROM   booking b
PROMPT  |          WHERE  b.tutor_id = t.student_id
PROMPT  |          AND    b.status IN ('REQUESTED','CONFIRMED','COMPLETED'))
PROMPT  |                                                     AS sessions_total,
PROMPT  |         ROUND ((SELECT AVG (c)                       -- NON-correlated
PROMPT  |                 FROM  (SELECT COUNT (*) AS c
PROMPT  |                        FROM   booking
PROMPT  |                        GROUP  BY tutor_id)), 2)     AS campus_average
PROMPT  |  FROM   tutor t
PROMPT  |         JOIN student s ON s.student_id = t.student_id
PROMPT  |  WHERE  (SELECT COUNT (*)
PROMPT  |          FROM   booking b
PROMPT  |          WHERE  b.tutor_id = t.student_id
PROMPT  |          AND    b.status IN ('REQUESTED','CONFIRMED','COMPLETED'))
PROMPT  |         >
PROMPT  |         (SELECT AVG (c)
PROMPT  |          FROM  (SELECT COUNT (*) AS c FROM booking GROUP BY tutor_id))
PROMPT  |  ORDER  BY sessions_total DESC;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT s.first_name || ' ' || s.last_name          AS tutor_name,
       (SELECT COUNT (*)                            -- CORRELATED
        FROM   booking b
        WHERE  b.tutor_id = t.student_id
        AND    b.status IN ('REQUESTED','CONFIRMED','COMPLETED'))
                                                   AS sessions_total,
       ROUND ((SELECT AVG (c)                       -- NON-correlated
               FROM  (SELECT COUNT (*) AS c
                      FROM   booking
                      GROUP  BY tutor_id)), 2)     AS campus_average
FROM   tutor t
       JOIN student s ON s.student_id = t.student_id
WHERE  (SELECT COUNT (*)
        FROM   booking b
        WHERE  b.tutor_id = t.student_id
        AND    b.status IN ('REQUESTED','CONFIRMED','COMPLETED'))
       >
       (SELECT AVG (c)
        FROM  (SELECT COUNT (*) AS c FROM booking GROUP BY tutor_id))
ORDER  BY sessions_total DESC;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M3-Q5 : booking funnel by subject (AGGREGATE)
PROMPT  > AGGREGATE with GROUP BY / HAVING: booking funnel per subject.
PROMPT  > SUM(CASE WHEN ... THEN 1 ELSE 0 END) = conditional aggregation (pivots status into columns).
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT sub.subject_code,
PROMPT  |         sub.subject_name,
PROMPT  |         COUNT (*)                                                AS total,
PROMPT  |         SUM (CASE WHEN b.status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed,
PROMPT  |         SUM (CASE WHEN b.status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancelled,
PROMPT  |         SUM (CASE WHEN b.status IN ('REQUESTED','CONFIRMED')
PROMPT  |                   THEN 1 ELSE 0 END)                             AS upcoming,
PROMPT  |         SUM (b.duration_hours)                                   AS total_hours,
PROMPT  |         ROUND (100 * SUM (CASE WHEN b.status = 'COMPLETED'
PROMPT  |                                THEN 1 ELSE 0 END) / COUNT (*), 1)
PROMPT  |                                                                  AS pct_done
PROMPT  |  FROM   booking b
PROMPT  |         JOIN subject sub ON sub.subject_id = b.subject_id
PROMPT  |  GROUP  BY sub.subject_id, sub.subject_code, sub.subject_name
PROMPT  |  HAVING COUNT (*) >= 1
PROMPT  |  ORDER  BY total DESC, sub.subject_code;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT sub.subject_code,
       sub.subject_name,
       COUNT (*)                                                AS total,
       SUM (CASE WHEN b.status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed,
       SUM (CASE WHEN b.status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancelled,
       SUM (CASE WHEN b.status IN ('REQUESTED','CONFIRMED')
                 THEN 1 ELSE 0 END)                             AS upcoming,
       SUM (b.duration_hours)                                   AS total_hours,
       ROUND (100 * SUM (CASE WHEN b.status = 'COMPLETED'
                              THEN 1 ELSE 0 END) / COUNT (*), 1)
                                                                AS pct_done
FROM   booking b
       JOIN subject sub ON sub.subject_id = b.subject_id
GROUP  BY sub.subject_id, sub.subject_code, sub.subject_name
HAVING COUNT (*) >= 1
ORDER  BY total DESC, sub.subject_code;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M3-Q6 : running teaching load per tutor (ANALYTIC)
PROMPT  > ANALYTIC functions: each tutor's sessions with a RUNNING TOTAL of hours.
PROMPT  > SUM() OVER (... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), ROW_NUMBER, RATIO_TO_REPORT.
PROMPT  > GROUP BY would give only the total; window functions show total AND each session.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT s.first_name || ' ' || s.last_name          AS tutor_name,
PROMPT  |         b.booking_id,
PROMPT  |         TO_CHAR (b.sched_date, 'DD-MON')            AS session_date,
PROMPT  |         b.duration_hours                            AS hrs,
PROMPT  |         ROW_NUMBER () OVER (PARTITION BY b.tutor_id
PROMPT  |                             ORDER BY b.sched_date)  AS session_seq,
PROMPT  |         SUM (b.duration_hours) OVER (
PROMPT  |              PARTITION BY b.tutor_id
PROMPT  |              ORDER BY b.sched_date
PROMPT  |              ROWS BETWEEN UNBOUNDED PRECEDING
PROMPT  |                       AND CURRENT ROW)              AS running_hours,
PROMPT  |         SUM (b.duration_hours) OVER (
PROMPT  |              PARTITION BY b.tutor_id)               AS their_total,
PROMPT  |         ROUND (100 * RATIO_TO_REPORT (b.duration_hours)
PROMPT  |                        OVER (PARTITION BY b.tutor_id), 1)
PROMPT  |                                                     AS pct_of_their_load
PROMPT  |  FROM   booking b
PROMPT  |         JOIN student s ON s.student_id = b.tutor_id
PROMPT  |  WHERE  b.status = 'COMPLETED'
PROMPT  |  ORDER  BY tutor_name, b.sched_date;
PROMPT  |  
PROMPT  |  
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT s.first_name || ' ' || s.last_name          AS tutor_name,
       b.booking_id,
       TO_CHAR (b.sched_date, 'DD-MON')            AS session_date,
       b.duration_hours                            AS hrs,
       ROW_NUMBER () OVER (PARTITION BY b.tutor_id
                           ORDER BY b.sched_date)  AS session_seq,
       SUM (b.duration_hours) OVER (
            PARTITION BY b.tutor_id
            ORDER BY b.sched_date
            ROWS BETWEEN UNBOUNDED PRECEDING
                     AND CURRENT ROW)              AS running_hours,
       SUM (b.duration_hours) OVER (
            PARTITION BY b.tutor_id)               AS their_total,
       ROUND (100 * RATIO_TO_REPORT (b.duration_hours)
                      OVER (PARTITION BY b.tutor_id), 1)
                                                   AS pct_of_their_load
FROM   booking b
       JOIN student s ON s.student_id = b.tutor_id
WHERE  b.status = 'COMPLETED'
ORDER  BY tutor_name, b.sched_date;


PROMPT
PROMPT ===== MEMBER 3 COMPLETE : 3 DML + 6 SELECT = 9 queries =====
SET ECHO OFF
PROMPT
PROMPT ===> All steps of this file are done. Results stay above - scroll up.
PROMPT ===> Type EXIT and press Enter when you want to close this window.
