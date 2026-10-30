SET DEFINE OFF

SET SERVEROUTPUT ON


@@_formats.sql
SET ECHO OFF
SET TRIMOUT ON
SET TAB OFF
PROMPT
PROMPT ################################################################
PROMPT #  MEMBER 5 : Feedback, disputes and fraud
PROMPT #  Each step: read the explanation, press ENTER to run it.
PROMPT ################################################################
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M5-INSERT : leave a review, raise a dispute
PROMPT  > (a) Adds the tutor review that one completed booking never got.
PROMPT  >     The trigger allows feedback only on COMPLETED sessions; the PK (booking_id, reviewer_role)
PROMPT  >     stops anyone reviewing the same session twice.
PROMPT  > (b) Raises a dispute on the first CONFIRMED booking -> booking becomes DISPUTED, escrow is frozen.
PROMPT  >     dispute_no is a PARTIAL KEY (restarts at 1 for every booking) - DISPUTE is a weak entity.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  INSERT INTO feedback (
PROMPT  |      booking_id, reviewer_role, rating, comments, feedback_date)
PROMPT  |  SELECT booking_id,
PROMPT  |         'TUTOR',
PROMPT  |         4.0,
PROMPT  |         'Good session. Bring the lab sheet printed next time.',
PROMPT  |         SYSDATE
PROMPT  |  FROM   booking
PROMPT  |  WHERE  status = 'COMPLETED'
PROMPT  |  AND    booking_id NOT IN (SELECT booking_id FROM feedback
PROMPT  |                            WHERE  reviewer_role = 'TUTOR')
PROMPT  |  AND    ROWNUM = 1;
PROMPT  |  
PROMPT  |  DECLARE
PROMPT  |    v_bk   NUMBER;
PROMPT  |    v_dno  NUMBER;
PROMPT  |  BEGIN
PROMPT  |    SELECT MIN (booking_id) INTO v_bk
PROMPT  |    FROM   booking WHERE status = 'CONFIRMED';
PROMPT  |  
PROMPT  |    IF v_bk IS NULL THEN
PROMPT  |      DBMS_OUTPUT.PUT_LINE ('No confirmed booking available to dispute.');
PROMPT  |    ELSE
PROMPT  |      pkg_timebank.raise_dispute (
PROMPT  |          p_booking_id => v_bk,
PROMPT  |          p_by_role    => 'TUTEE',
PROMPT  |          p_reason     => 'Tutor changed the venue twice without telling me.',
PROMPT  |          p_dispute_no => v_dno);
PROMPT  |      DBMS_OUTPUT.PUT_LINE ('Dispute ' || v_dno || ' raised on booking ' || v_bk);
PROMPT  |    END IF;
PROMPT  |    COMMIT;
PROMPT  |  END;
PROMPT  |  /
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
INSERT INTO feedback (
    booking_id, reviewer_role, rating, comments, feedback_date)
SELECT booking_id,
       'TUTOR',
       4.0,
       'Good session. Bring the lab sheet printed next time.',
       SYSDATE
FROM   booking
WHERE  status = 'COMPLETED'
AND    booking_id NOT IN (SELECT booking_id FROM feedback
                          WHERE  reviewer_role = 'TUTOR')
AND    ROWNUM = 1;

DECLARE
  v_bk   NUMBER;
  v_dno  NUMBER;
BEGIN
  SELECT MIN (booking_id) INTO v_bk
  FROM   booking WHERE status = 'CONFIRMED';

  IF v_bk IS NULL THEN
    DBMS_OUTPUT.PUT_LINE ('No confirmed booking available to dispute.');
  ELSE
    pkg_timebank.raise_dispute (
        p_booking_id => v_bk,
        p_by_role    => 'TUTEE',
        p_reason     => 'Tutor changed the venue twice without telling me.',
        p_dispute_no => v_dno);
    DBMS_OUTPUT.PUT_LINE ('Dispute ' || v_dno || ' raised on booking ' || v_bk);
  END IF;
  COMMIT;
END;
/
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M5-UPDATE : triage the dispute queue
PROMPT  > Triages disputes older than 2 days: status UNDER_REVIEW, assigned to the least-busy admin.
PROMPT  > '0 rows updated' is correct now - the dispute was raised just a moment ago.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  UPDATE dispute d
PROMPT  |         d.resolved_by = (SELECT a.admin_id
PROMPT  |                          FROM  (SELECT a2.admin_id,
PROMPT  |                                        COUNT (d2.booking_id) AS caseload
PROMPT  |                                 FROM   admin a2
PROMPT  |                                        LEFT JOIN dispute d2
PROMPT  |                                               ON d2.resolved_by = a2.admin_id
PROMPT  |                                              AND d2.status <> 'RESOLVED'
PROMPT  |                                 GROUP  BY a2.admin_id
PROMPT  |                                 ORDER  BY caseload, a2.admin_id) a
PROMPT  |                          WHERE  ROWNUM = 1)
PROMPT  |  WHERE  d.status    = 'OPEN'
PROMPT  |  AND    d.raised_on < SYSDATE - 2;
PROMPT  |  
PROMPT  |  COMMIT;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
UPDATE dispute d
SET    d.status      = 'UNDER_REVIEW',
       d.resolved_by = (SELECT a.admin_id
                        FROM  (SELECT a2.admin_id,
                                      COUNT (d2.booking_id) AS caseload
                               FROM   admin a2
                                      LEFT JOIN dispute d2
                                             ON d2.resolved_by = a2.admin_id
                                            AND d2.status <> 'RESOLVED'
                               GROUP  BY a2.admin_id
                               ORDER  BY caseload, a2.admin_id) a
                        WHERE  ROWNUM = 1)
WHERE  d.status    = 'OPEN'
AND    d.raised_on < SYSDATE - 2;

COMMIT;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M5-DELETE : retract a review, drop colluded ratings
PROMPT  > (a) Tutors retract their recent 4.0 reviews (written in the last 7 days, no dispute) - 3 rows.
PROMPT  >     Naming (booking_id, reviewer_role) identifies exactly one review - no extra review id needed.
PROMPT  > (b) Deletes ratings from pairs who tutor each other (possible collusion).
PROMPT  >     0 rows in (b) is correct: our data has no colluding pairs.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  DELETE FROM feedback f
PROMPT  |  WHERE  f.reviewer_role = 'TUTOR'
PROMPT  |  AND    f.feedback_date > SYSDATE - 7
PROMPT  |  AND    f.rating        = 4.0
PROMPT  |  AND    NOT EXISTS (SELECT 1 FROM dispute d
PROMPT  |                     WHERE  d.booking_id = f.booking_id);
PROMPT  |  
PROMPT  |  DELETE FROM feedback f
PROMPT  |  WHERE  f.booking_id IN (
PROMPT  |           SELECT b1.booking_id
PROMPT  |           FROM   booking b1
PROMPT  |           WHERE  b1.status = 'COMPLETED'
PROMPT  |           AND    EXISTS (SELECT 1
PROMPT  |                          FROM   booking b2
PROMPT  |                          WHERE  b2.tutor_id = b1.tutee_id
PROMPT  |                          AND    b2.tutee_id = b1.tutor_id
PROMPT  |                          AND    b2.status   = 'COMPLETED'));
PROMPT  |  
PROMPT  |  COMMIT;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
DELETE FROM feedback f
WHERE  f.reviewer_role = 'TUTOR'
AND    f.feedback_date > SYSDATE - 7
AND    f.rating        = 4.0
AND    NOT EXISTS (SELECT 1 FROM dispute d
                   WHERE  d.booking_id = f.booking_id);

DELETE FROM feedback f
WHERE  f.booking_id IN (
         SELECT b1.booking_id
         FROM   booking b1
         WHERE  b1.status = 'COMPLETED'
         AND    EXISTS (SELECT 1
                        FROM   booking b2
                        WHERE  b2.tutor_id = b1.tutee_id
                        AND    b2.tutee_id = b1.tutor_id
                        AND    b2.status   = 'COMPLETED'));

COMMIT;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M5-Q1 : reviews and disputes (SIMPLE)
PROMPT  > SIMPLE query with UNION ALL: reviews and disputes listed together.
PROMPT  > UNION ALL (not UNION) because no duplicates are possible and it avoids a sort.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT 'REVIEW'                               AS record_type,
PROMPT  |         booking_id,
PROMPT  |         reviewer_role                          AS written_by,
PROMPT  |         TO_CHAR (rating)                       AS detail,
PROMPT  |         TO_CHAR (feedback_date, 'DD-MON-YYYY') AS on_date,
PROMPT  |         SUBSTR (comments, 1, 45) || '...'      AS note
PROMPT  |  FROM   feedback
PROMPT  |  UNION ALL
PROMPT  |  SELECT 'DISPUTE',
PROMPT  |         booking_id,
PROMPT  |         raised_by_role,
PROMPT  |         status,
PROMPT  |         TO_CHAR (raised_on, 'DD-MON-YYYY'),
PROMPT  |         SUBSTR (reason, 1, 45) || '...'
PROMPT  |  FROM   dispute
PROMPT  |  ORDER  BY record_type, booking_id;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT 'REVIEW'                               AS record_type,
       booking_id,
       reviewer_role                          AS written_by,
       TO_CHAR (rating)                       AS detail,
       TO_CHAR (feedback_date, 'DD-MON-YYYY') AS on_date,
       SUBSTR (comments, 1, 45) || '...'      AS note
FROM   feedback
UNION ALL
SELECT 'DISPUTE',
       booking_id,
       raised_by_role,
       status,
       TO_CHAR (raised_on, 'DD-MON-YYYY'),
       SUBSTR (reason, 1, 45) || '...'
FROM   dispute
ORDER  BY record_type, booking_id;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M5-Q2 : both sides of each session (SELF JOIN)
PROMPT  > SELF JOIN: FEEDBACK is joined to itself twice - once for the tutee's review, once for the tutor's.
PROMPT  > Possible only because reviewer_role is part of the primary key.
PROMPT  > OUTER joins, because many sessions have only one review or none.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT b.booking_id,
PROMPT  |         sub.subject_code,
PROMPT  |         tr.first_name                   AS tutor,
PROMPT  |         te.first_name                   AS tutee,
PROMPT  |         ft.rating                       AS tutee_rated_tutor,
PROMPT  |         fe.rating                       AS tutor_rated_tutee,
PROMPT  |         NVL (d.status, '-')             AS dispute_status,
PROMPT  |         CASE
PROMPT  |           WHEN ft.rating IS NULL AND fe.rating IS NULL THEN 'no reviews'
PROMPT  |           WHEN ft.rating IS NULL OR  fe.rating IS NULL THEN 'one-sided'
PROMPT  |           WHEN ABS (ft.rating - fe.rating) >= 1.5      THEN 'DISAGREEMENT'
PROMPT  |           ELSE                                              'both agree'
PROMPT  |         END                             AS review_state
PROMPT  |  FROM   booking b
PROMPT  |         JOIN      subject  sub ON sub.subject_id   = b.subject_id
PROMPT  |         JOIN      student  tr  ON tr.student_id    = b.tutor_id
PROMPT  |         JOIN      student  te  ON te.student_id    = b.tutee_id
PROMPT  |         LEFT JOIN feedback ft  ON ft.booking_id    = b.booking_id
PROMPT  |                               AND ft.reviewer_role = 'TUTEE'
PROMPT  |         LEFT JOIN feedback fe  ON fe.booking_id    = b.booking_id
PROMPT  |                               AND fe.reviewer_role = 'TUTOR'
PROMPT  |         LEFT JOIN dispute  d   ON d.booking_id     = b.booking_id
PROMPT  |  ORDER  BY b.booking_id;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT b.booking_id,
       sub.subject_code,
       tr.first_name                   AS tutor,
       te.first_name                   AS tutee,
       ft.rating                       AS tutee_rated_tutor,
       fe.rating                       AS tutor_rated_tutee,
       NVL (d.status, '-')             AS dispute_status,
       CASE
         WHEN ft.rating IS NULL AND fe.rating IS NULL THEN 'no reviews'
         WHEN ft.rating IS NULL OR  fe.rating IS NULL THEN 'one-sided'
         WHEN ABS (ft.rating - fe.rating) >= 1.5      THEN 'DISAGREEMENT'
         ELSE                                              'both agree'
       END                             AS review_state
FROM   booking b
       JOIN      subject  sub ON sub.subject_id   = b.subject_id
       JOIN      student  tr  ON tr.student_id    = b.tutor_id
       JOIN      student  te  ON te.student_id    = b.tutee_id
       LEFT JOIN feedback ft  ON ft.booking_id    = b.booking_id
                             AND ft.reviewer_role = 'TUTEE'
       LEFT JOIN feedback fe  ON fe.booking_id    = b.booking_id
                             AND fe.reviewer_role = 'TUTOR'
       LEFT JOIN dispute  d   ON d.booking_id     = b.booking_id
ORDER  BY b.booking_id;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M5-Q3 : above-average tutors (NESTED)
PROMPT  > NESTED subquery, 3 levels: tutors rated above the campus average.
PROMPT  > Campus average = average of each tutor's average (so busy tutors do not dominate).
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT s.first_name || ' ' || s.last_name            AS tutor_name,
PROMPT  |         t.badge_level,
PROMPT  |         ROUND (AVG (f.rating), 2)                     AS their_average,
PROMPT  |         COUNT (f.booking_id)                          AS reviews,
PROMPT  |         (SELECT ROUND (AVG (per_tutor), 2)
PROMPT  |          FROM  (SELECT AVG (f2.rating) AS per_tutor
PROMPT  |                 FROM   feedback f2
PROMPT  |                        JOIN booking b2 ON b2.booking_id = f2.booking_id
PROMPT  |                 WHERE  f2.reviewer_role = 'TUTEE'
PROMPT  |                 GROUP  BY b2.tutor_id))               AS campus_average
PROMPT  |  FROM   feedback f
PROMPT  |         JOIN booking b ON b.booking_id = f.booking_id
PROMPT  |         JOIN tutor   t ON t.student_id = b.tutor_id
PROMPT  |         JOIN student s ON s.student_id = t.student_id
PROMPT  |  WHERE  f.reviewer_role = 'TUTEE'          -- only reviews OF the tutor
PROMPT  |  GROUP  BY s.first_name, s.last_name, t.badge_level
PROMPT  |  HAVING AVG (f.rating) > (SELECT AVG (per_tutor)
PROMPT  |                           FROM  (SELECT AVG (f3.rating) AS per_tutor
PROMPT  |                                  FROM   feedback f3
PROMPT  |                                         JOIN booking b3
PROMPT  |                                           ON b3.booking_id = f3.booking_id
PROMPT  |                                  WHERE  f3.reviewer_role = 'TUTEE'
PROMPT  |                                  GROUP  BY b3.tutor_id))
PROMPT  |  ORDER  BY their_average DESC;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT s.first_name || ' ' || s.last_name            AS tutor_name,
       t.badge_level,
       ROUND (AVG (f.rating), 2)                     AS their_average,
       COUNT (f.booking_id)                          AS reviews,
       (SELECT ROUND (AVG (per_tutor), 2)
        FROM  (SELECT AVG (f2.rating) AS per_tutor
               FROM   feedback f2
                      JOIN booking b2 ON b2.booking_id = f2.booking_id
               WHERE  f2.reviewer_role = 'TUTEE'
               GROUP  BY b2.tutor_id))               AS campus_average
FROM   feedback f
       JOIN booking b ON b.booking_id = f.booking_id
       JOIN tutor   t ON t.student_id = b.tutor_id
       JOIN student s ON s.student_id = t.student_id
WHERE  f.reviewer_role = 'TUTEE'          -- only reviews OF the tutor
GROUP  BY s.first_name, s.last_name, t.badge_level
HAVING AVG (f.rating) > (SELECT AVG (per_tutor)
                         FROM  (SELECT AVG (f3.rating) AS per_tutor
                                FROM   feedback f3
                                       JOIN booking b3
                                         ON b3.booking_id = f3.booking_id
                                WHERE  f3.reviewer_role = 'TUTEE'
                                GROUP  BY b3.tutor_id))
ORDER  BY their_average DESC;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M5-Q4 : credit-loop collusion detector (CORRELATED)
PROMPT  > CORRELATED subquery: CREDIT-LOOP COLLUSION detector - two students who keep tutoring each other.
PROMPT  > 'no rows selected' = no suspicious pairs in our data (that is the good result).
PROMPT  > A database cannot stop two people who agree to lie, but it can make the pattern visible.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT a.first_name || ' ' || a.last_name     AS student_a,
PROMPT  |         c.first_name || ' ' || c.last_name     AS student_b,
PROMPT  |         COUNT (*)                              AS sessions_a_taught_b,
PROMPT  |         (SELECT COUNT (*)                       -- correlated, other way
PROMPT  |          FROM   booking b2
PROMPT  |          WHERE  b2.tutor_id = b1.tutee_id
PROMPT  |          AND    b2.tutee_id = b1.tutor_id
PROMPT  |          AND    b2.status   = 'COMPLETED')     AS sessions_b_taught_a,
PROMPT  |         (SELECT ROUND (AVG (f.rating), 2)
PROMPT  |          FROM   feedback f
PROMPT  |                 JOIN booking b3 ON b3.booking_id = f.booking_id
PROMPT  |          WHERE  ((b3.tutor_id = b1.tutor_id AND b3.tutee_id = b1.tutee_id)
PROMPT  |               OR (b3.tutor_id = b1.tutee_id AND b3.tutee_id = b1.tutor_id)))
PROMPT  |                                                AS avg_rating_between_them,
PROMPT  |         'REVIEW MANUALLY'                      AS recommended_action
PROMPT  |  FROM   booking b1
PROMPT  |         JOIN student a ON a.student_id = b1.tutor_id
PROMPT  |         JOIN student c ON c.student_id = b1.tutee_id
PROMPT  |  WHERE  b1.status = 'COMPLETED'
PROMPT  |  AND    b1.tutor_id < b1.tutee_id          -- report each pair only once
PROMPT  |  AND    EXISTS (SELECT 1
PROMPT  |                 FROM   booking b4
PROMPT  |                 WHERE  b4.tutor_id = b1.tutee_id
PROMPT  |                 AND    b4.tutee_id = b1.tutor_id
PROMPT  |                 AND    b4.status   = 'COMPLETED')
PROMPT  |  GROUP  BY b1.tutor_id, b1.tutee_id,
PROMPT  |            a.first_name, a.last_name, c.first_name, c.last_name
PROMPT  |  HAVING COUNT (*) >= 1
PROMPT  |  ORDER  BY sessions_a_taught_b DESC;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT a.first_name || ' ' || a.last_name     AS student_a,
       c.first_name || ' ' || c.last_name     AS student_b,
       COUNT (*)                              AS sessions_a_taught_b,
       (SELECT COUNT (*)                       -- correlated, other way
        FROM   booking b2
        WHERE  b2.tutor_id = b1.tutee_id
        AND    b2.tutee_id = b1.tutor_id
        AND    b2.status   = 'COMPLETED')     AS sessions_b_taught_a,
       (SELECT ROUND (AVG (f.rating), 2)
        FROM   feedback f
               JOIN booking b3 ON b3.booking_id = f.booking_id
        WHERE  ((b3.tutor_id = b1.tutor_id AND b3.tutee_id = b1.tutee_id)
             OR (b3.tutor_id = b1.tutee_id AND b3.tutee_id = b1.tutor_id)))
                                              AS avg_rating_between_them,
       'REVIEW MANUALLY'                      AS recommended_action
FROM   booking b1
       JOIN student a ON a.student_id = b1.tutor_id
       JOIN student c ON c.student_id = b1.tutee_id
WHERE  b1.status = 'COMPLETED'
AND    b1.tutor_id < b1.tutee_id          -- report each pair only once
AND    EXISTS (SELECT 1
               FROM   booking b4
               WHERE  b4.tutor_id = b1.tutee_id
               AND    b4.tutee_id = b1.tutor_id
               AND    b4.status   = 'COMPLETED')
GROUP  BY b1.tutor_id, b1.tutee_id,
          a.first_name, a.last_name, c.first_name, c.last_name
HAVING COUNT (*) >= 1
ORDER  BY sessions_a_taught_b DESC;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M5-Q5 : rating distribution by subject (AGGREGATE)
PROMPT  > AGGREGATE with ROLLUP: rating distribution per subject plus an ALL SUBJECTS total row.
PROMPT  > STDDEV shows the spread; GROUPING() detects the total row.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT CASE WHEN GROUPING (sub.subject_code) = 1
PROMPT  |              THEN '** ALL SUBJECTS **'
PROMPT  |              ELSE sub.subject_code END                         AS subject,
PROMPT  |         COUNT (*)                                              AS reviews,
PROMPT  |         ROUND (AVG (f.rating), 2)                              AS avg_rating,
PROMPT  |         ROUND (NVL (STDDEV (f.rating), 0), 2)                  AS spread,
PROMPT  |         MIN (f.rating)                                         AS worst,
PROMPT  |         MAX (f.rating)                                         AS best,
PROMPT  |         SUM (CASE WHEN f.rating >= 4.5 THEN 1 ELSE 0 END)      AS excellent,
PROMPT  |         SUM (CASE WHEN f.rating >= 3.5
PROMPT  |                    AND f.rating <  4.5 THEN 1 ELSE 0 END)      AS good,
PROMPT  |         SUM (CASE WHEN f.rating <  3.5 THEN 1 ELSE 0 END)      AS poor
PROMPT  |  FROM   feedback f
PROMPT  |         JOIN booking b   ON b.booking_id  = f.booking_id
PROMPT  |         JOIN subject sub ON sub.subject_id = b.subject_id
PROMPT  |  WHERE  f.reviewer_role = 'TUTEE'
PROMPT  |  GROUP  BY ROLLUP (sub.subject_code)
PROMPT  |  HAVING COUNT (*) >= 1
PROMPT  |  ORDER  BY GROUPING (sub.subject_code), avg_rating DESC;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT CASE WHEN GROUPING (sub.subject_code) = 1
            THEN '** ALL SUBJECTS **'
            ELSE sub.subject_code END                         AS subject,
       COUNT (*)                                              AS reviews,
       ROUND (AVG (f.rating), 2)                              AS avg_rating,
       ROUND (NVL (STDDEV (f.rating), 0), 2)                  AS spread,
       MIN (f.rating)                                         AS worst,
       MAX (f.rating)                                         AS best,
       SUM (CASE WHEN f.rating >= 4.5 THEN 1 ELSE 0 END)      AS excellent,
       SUM (CASE WHEN f.rating >= 3.5
                  AND f.rating <  4.5 THEN 1 ELSE 0 END)      AS good,
       SUM (CASE WHEN f.rating <  3.5 THEN 1 ELSE 0 END)      AS poor
FROM   feedback f
       JOIN booking b   ON b.booking_id  = f.booking_id
       JOIN subject sub ON sub.subject_id = b.subject_id
WHERE  f.reviewer_role = 'TUTEE'
GROUP  BY ROLLUP (sub.subject_code)
HAVING COUNT (*) >= 1
ORDER  BY GROUPING (sub.subject_code), avg_rating DESC;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M5-Q6 : rating trend per tutor (ANALYTIC)
PROMPT  > ANALYTIC functions: is each tutor improving or slipping?
PROMPT  > LAG (previous rating), moving average of last 3, DENSE_RANK and NTILE across campus.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT s.first_name                                     AS tutor,
PROMPT  |         b.booking_id,
PROMPT  |         TO_CHAR (b.sched_date, 'DD-MON')                 AS session_date,
PROMPT  |         f.rating,
PROMPT  |         LAG (f.rating) OVER (PARTITION BY b.tutor_id
PROMPT  |                              ORDER BY b.sched_date)      AS previous_rating,
PROMPT  |         ROUND (AVG (f.rating) OVER (
PROMPT  |                  PARTITION BY b.tutor_id
PROMPT  |                  ORDER BY b.sched_date
PROMPT  |                  ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2)
PROMPT  |                                                          AS moving_avg_3,
PROMPT  |         CASE
PROMPT  |           WHEN LAG (f.rating) OVER (PARTITION BY b.tutor_id
PROMPT  |                                     ORDER BY b.sched_date) IS NULL
PROMPT  |                THEN 'first review'
PROMPT  |           WHEN f.rating > LAG (f.rating) OVER (PARTITION BY b.tutor_id
PROMPT  |                                                ORDER BY b.sched_date)
PROMPT  |                THEN 'improving'
PROMPT  |           WHEN f.rating < LAG (f.rating) OVER (PARTITION BY b.tutor_id
PROMPT  |                                                ORDER BY b.sched_date)
PROMPT  |                THEN 'slipping'
PROMPT  |           ELSE 'steady'
PROMPT  |         END                                              AS trend,
PROMPT  |         DENSE_RANK () OVER (ORDER BY f.rating DESC)      AS campus_rank,
PROMPT  |         NTILE (3) OVER (ORDER BY f.rating DESC)          AS performance_third
PROMPT  |  FROM   feedback f
PROMPT  |         JOIN booking b ON b.booking_id = f.booking_id
PROMPT  |         JOIN student s ON s.student_id = b.tutor_id
PROMPT  |  WHERE  f.reviewer_role = 'TUTEE'
PROMPT  |  ORDER  BY tutor, b.sched_date;
PROMPT  |  
PROMPT  |  
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT s.first_name                                     AS tutor,
       b.booking_id,
       TO_CHAR (b.sched_date, 'DD-MON')                 AS session_date,
       f.rating,
       LAG (f.rating) OVER (PARTITION BY b.tutor_id
                            ORDER BY b.sched_date)      AS previous_rating,
       ROUND (AVG (f.rating) OVER (
                PARTITION BY b.tutor_id
                ORDER BY b.sched_date
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2)
                                                        AS moving_avg_3,
       CASE
         WHEN LAG (f.rating) OVER (PARTITION BY b.tutor_id
                                   ORDER BY b.sched_date) IS NULL
              THEN 'first review'
         WHEN f.rating > LAG (f.rating) OVER (PARTITION BY b.tutor_id
                                              ORDER BY b.sched_date)
              THEN 'improving'
         WHEN f.rating < LAG (f.rating) OVER (PARTITION BY b.tutor_id
                                              ORDER BY b.sched_date)
              THEN 'slipping'
         ELSE 'steady'
       END                                              AS trend,
       DENSE_RANK () OVER (ORDER BY f.rating DESC)      AS campus_rank,
       NTILE (3) OVER (ORDER BY f.rating DESC)          AS performance_third
FROM   feedback f
       JOIN booking b ON b.booking_id = f.booking_id
       JOIN student s ON s.student_id = b.tutor_id
WHERE  f.reviewer_role = 'TUTEE'
ORDER  BY tutor, b.sched_date;


PROMPT
PROMPT ===== MEMBER 5 COMPLETE : 3 DML + 6 SELECT = 9 queries =====
SET ECHO OFF
PROMPT
PROMPT ===> All steps of this file are done. Results stay above - scroll up.
PROMPT ===> Type EXIT and press Enter when you want to close this window.
