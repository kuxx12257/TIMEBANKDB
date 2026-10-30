SET DEFINE OFF

SET SERVEROUTPUT ON


@@_formats.sql
SET ECHO OFF
SET TRIMOUT ON
SET TAB OFF
PROMPT
PROMPT ################################################################
PROMPT #  MEMBER 2 : Skills and availability
PROMPT #  Each step: read the explanation, press ENTER to run it.
PROMPT ################################################################
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M2-INSERT : a student becomes a tutor
PROMPT  > Meera becomes a tutor: insert into TUTOR, then TUTOR_SKILL, then 2 SLOT rows.
PROMPT  > The order is forced by foreign keys (a TUTOR must exist before its skills and slots).
PROMPT  > Meera was already a tutee - now she is in BOTH subclasses (overlapping).
PROMPT  > Her slot_no starts again at 1: slot_no is the PARTIAL KEY of the WEAK entity SLOT.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  INSERT INTO tutor (student_id, badge_level, verification_doc_no)
PROMPT  |  VALUES (112, 'BRONZE', 'VIT-GRD-1007');
PROMPT  |  
PROMPT  |  INSERT INTO tutor_skill (tutor_id, subject_id, competency_level,
PROMPT  |                           grade_proof, certified_on)
PROMPT  |  VALUES (112, 107, 'EXPERT', 'S', TRUNC (SYSDATE));
PROMPT  |  
PROMPT  |  INSERT INTO slot (tutor_id, slot_no, day_of_week, start_time, end_time)
PROMPT  |  VALUES (112, 1, 'TUE', 16, 18);
PROMPT  |  
PROMPT  |  INSERT INTO slot (tutor_id, slot_no, day_of_week, start_time, end_time)
PROMPT  |  VALUES (112, 2, 'SAT', 9, 11);
PROMPT  |  
PROMPT  |  COMMIT;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
INSERT INTO tutor (student_id, badge_level, verification_doc_no)
VALUES (112, 'BRONZE', 'VIT-GRD-1007');

INSERT INTO tutor_skill (tutor_id, subject_id, competency_level,
                         grade_proof, certified_on)
VALUES (112, 107, 'EXPERT', 'S', TRUNC (SYSDATE));

INSERT INTO slot (tutor_id, slot_no, day_of_week, start_time, end_time)
VALUES (112, 1, 'TUE', 16, 18);

INSERT INTO slot (tutor_id, slot_no, day_of_week, start_time, end_time)
VALUES (112, 2, 'SAT', 9, 11);

COMMIT;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M2-UPDATE : promote proven tutors to EXPERT
PROMPT  > Promotes a tutor to EXPERT in a subject if they have >= 2 completed sessions in it
PROMPT  > AND an average rating >= 4.0. Uses two CORRELATED subqueries inside the WHERE clause.
PROMPT  > Only ratings written by the TUTEE are counted (a booking has two reviews, one from each side).
PROMPT  > '0 rows updated' is a correct result on this data: nobody has met the bar yet.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  UPDATE tutor_skill ts
PROMPT  |         ts.certified_on     = TRUNC (SYSDATE)
PROMPT  |  WHERE  ts.competency_level <> 'EXPERT'
PROMPT  |  AND    2 <= (SELECT COUNT (*)
PROMPT  |               FROM   booking b
PROMPT  |               WHERE  b.tutor_id   = ts.tutor_id
PROMPT  |               AND    b.subject_id = ts.subject_id
PROMPT  |               AND    b.status     = 'COMPLETED')
PROMPT  |  AND    4.0 <= (SELECT NVL (AVG (f.rating), 0)
PROMPT  |                 FROM   feedback f
PROMPT  |                        JOIN booking b2 ON b2.booking_id = f.booking_id
PROMPT  |                 WHERE  b2.tutor_id     = ts.tutor_id
PROMPT  |                 AND    b2.subject_id   = ts.subject_id
PROMPT  |                 AND    f.reviewer_role = 'TUTEE');
PROMPT  |  
PROMPT  |  COMMIT;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
UPDATE tutor_skill ts
SET    ts.competency_level = 'EXPERT',
       ts.certified_on     = TRUNC (SYSDATE)
WHERE  ts.competency_level <> 'EXPERT'
AND    2 <= (SELECT COUNT (*)
             FROM   booking b
             WHERE  b.tutor_id   = ts.tutor_id
             AND    b.subject_id = ts.subject_id
             AND    b.status     = 'COMPLETED')
AND    4.0 <= (SELECT NVL (AVG (f.rating), 0)
               FROM   feedback f
                      JOIN booking b2 ON b2.booking_id = f.booking_id
               WHERE  b2.tutor_id     = ts.tutor_id
               AND    b2.subject_id   = ts.subject_id
               AND    f.reviewer_role = 'TUTEE');

COMMIT;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M2-DELETE : withdraw an unused slot
PROMPT  > Removes a slot Neel no longer offers (his Saturday slot).
PROMPT  > The NOT EXISTS guard checks no booking uses it - otherwise the COMPOSITE foreign key
PROMPT  > (tutor_id, slot_no) from BOOKING would raise ORA-02292 'child record found'.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  DELETE FROM slot s
PROMPT  |  WHERE  s.tutor_id = 111
PROMPT  |  AND    s.slot_no  = 2
PROMPT  |  AND    NOT EXISTS (SELECT 1
PROMPT  |                     FROM   booking b
PROMPT  |                     WHERE  b.tutor_id = s.tutor_id
PROMPT  |                     AND    b.slot_no  = s.slot_no);
PROMPT  |  
PROMPT  |  COMMIT;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
DELETE FROM slot s
WHERE  s.tutor_id = 111
AND    s.slot_no  = 2
AND    NOT EXISTS (SELECT 1
                   FROM   booking b
                   WHERE  b.tutor_id = s.tutor_id
                   AND    b.slot_no  = s.slot_no);

COMMIT;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M2-Q1 : subject catalogue (SIMPLE)
PROMPT  > SIMPLE query: the subject catalogue with the department that owns each subject.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT sub.subject_id,
PROMPT  |         sub.subject_code,
PROMPT  |         sub.subject_name,
PROMPT  |         sub.category,
PROMPT  |         d.school   AS owned_by
PROMPT  |  FROM   subject sub
PROMPT  |         JOIN department d ON d.dept_id = sub.dept_id
PROMPT  |  ORDER  BY sub.category, sub.subject_code;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT sub.subject_id,
       sub.subject_code,
       sub.subject_name,
       sub.category,
       d.school   AS owned_by
FROM   subject sub
       JOIN department d ON d.dept_id = sub.dept_id
ORDER  BY sub.category, sub.subject_code;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M2-Q2 : skill matrix, incl. cross-department (JOIN)
PROMPT  > 5-table JOIN: the skill matrix - which tutor can teach which subject.
PROMPT  > TUTOR_SKILL is the table made from the M:N relationship 'offers' (it has its own attributes).
PROMPT  > DEPARTMENT is joined TWICE with different aliases (tutor's dept and subject's dept).
PROMPT  > Shows CROSS-DEPARTMENT tutoring: Rohan is Mechanical but teaches Database Systems.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT s.first_name || ' ' || s.last_name  AS tutor_name,
PROMPT  |         dt.school                           AS tutor_school,
PROMPT  |         sub.subject_code,
PROMPT  |         sub.subject_name,
PROMPT  |         ds.school                           AS subject_school,
PROMPT  |         ts.competency_level,
PROMPT  |         ts.grade_proof,
PROMPT  |         CASE WHEN dt.dept_id <> ds.dept_id
PROMPT  |              THEN 'CROSS-DEPARTMENT' ELSE 'own department' END AS note
PROMPT  |  FROM   tutor_skill ts
PROMPT  |         JOIN student    s   ON s.student_id   = ts.tutor_id
PROMPT  |         JOIN department dt  ON dt.dept_id     = s.dept_id
PROMPT  |         JOIN subject    sub ON sub.subject_id = ts.subject_id
PROMPT  |         JOIN department ds  ON ds.dept_id     = sub.dept_id
PROMPT  |  ORDER  BY note, tutor_name, sub.subject_code;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT s.first_name || ' ' || s.last_name  AS tutor_name,
       dt.school                           AS tutor_school,
       sub.subject_code,
       sub.subject_name,
       ds.school                           AS subject_school,
       ts.competency_level,
       ts.grade_proof,
       CASE WHEN dt.dept_id <> ds.dept_id
            THEN 'CROSS-DEPARTMENT' ELSE 'own department' END AS note
FROM   tutor_skill ts
       JOIN student    s   ON s.student_id   = ts.tutor_id
       JOIN department dt  ON dt.dept_id     = s.dept_id
       JOIN subject    sub ON sub.subject_id = ts.subject_id
       JOIN department ds  ON ds.dept_id     = sub.dept_id
ORDER  BY note, tutor_name, sub.subject_code;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M2-Q3 : subjects with no tutor (NESTED)
PROMPT  > NESTED subquery with NOT IN: subjects that nobody teaches (coverage gaps).
PROMPT  > This is the PARTIAL participation of SUBJECT in 'offers'.
PROMPT  > NOT IN is safe only because tutor_skill.subject_id is NOT NULL (one NULL would return no rows).
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT sub.subject_code,
PROMPT  |         sub.subject_name,
PROMPT  |         sub.category,
PROMPT  |         d.school                              AS owning_school,
PROMPT  |         (SELECT COUNT (*)
PROMPT  |          FROM   booking b
PROMPT  |          WHERE  b.subject_id = sub.subject_id) AS times_requested
PROMPT  |  FROM   subject sub
PROMPT  |         JOIN department d ON d.dept_id = sub.dept_id
PROMPT  |  WHERE  sub.subject_id NOT IN (SELECT subject_id FROM tutor_skill)
PROMPT  |  ORDER  BY sub.subject_code;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT sub.subject_code,
       sub.subject_name,
       sub.category,
       d.school                              AS owning_school,
       (SELECT COUNT (*)
        FROM   booking b
        WHERE  b.subject_id = sub.subject_id) AS times_requested
FROM   subject sub
       JOIN department d ON d.dept_id = sub.dept_id
WHERE  sub.subject_id NOT IN (SELECT subject_id FROM tutor_skill)
ORDER  BY sub.subject_code;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M2-Q4 : unbooked slots next week (CORRELATED)
PROMPT  > CORRELATED subquery: published slots that nobody has booked for next week.
PROMPT  > The NOT EXISTS correlates on THREE things: tutor_id, slot_no and the computed date.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT s.first_name || ' ' || s.last_name       AS tutor_name,
PROMPT  |         sl.slot_no,
PROMPT  |         sl.day_of_week,
PROMPT  |         sl.start_time,
PROMPT  |         sl.end_time,
PROMPT  |         sl.end_time - sl.start_time              AS hours_free,
PROMPT  |         TRUNC (SYSDATE, 'IW') + 7
PROMPT  |           + CASE sl.day_of_week
PROMPT  |               WHEN 'MON' THEN 0 WHEN 'TUE' THEN 1 WHEN 'WED' THEN 2
PROMPT  |               WHEN 'THU' THEN 3 WHEN 'FRI' THEN 4 WHEN 'SAT' THEN 5
PROMPT  |               ELSE 6 END                         AS next_occurrence
PROMPT  |  FROM   slot sl
PROMPT  |         JOIN student s ON s.student_id = sl.tutor_id
PROMPT  |  WHERE  NOT EXISTS (
PROMPT  |           SELECT 1
PROMPT  |           FROM   booking b
PROMPT  |           WHERE  b.tutor_id   = sl.tutor_id          -- correlation 1
PROMPT  |           AND    b.slot_no    = sl.slot_no           -- correlation 2
PROMPT  |           AND    b.status IN ('REQUESTED','CONFIRMED')
PROMPT  |           AND    b.sched_date = TRUNC (SYSDATE,'IW') + 7
PROMPT  |                               + CASE sl.day_of_week  -- correlation 3
PROMPT  |                                   WHEN 'MON' THEN 0 WHEN 'TUE' THEN 1
PROMPT  |                                   WHEN 'WED' THEN 2 WHEN 'THU' THEN 3
PROMPT  |                                   WHEN 'FRI' THEN 4 WHEN 'SAT' THEN 5
PROMPT  |                                   ELSE 6 END)
PROMPT  |  ORDER  BY next_occurrence, sl.start_time;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT s.first_name || ' ' || s.last_name       AS tutor_name,
       sl.slot_no,
       sl.day_of_week,
       sl.start_time,
       sl.end_time,
       sl.end_time - sl.start_time              AS hours_free,
       TRUNC (SYSDATE, 'IW') + 7
         + CASE sl.day_of_week
             WHEN 'MON' THEN 0 WHEN 'TUE' THEN 1 WHEN 'WED' THEN 2
             WHEN 'THU' THEN 3 WHEN 'FRI' THEN 4 WHEN 'SAT' THEN 5
             ELSE 6 END                         AS next_occurrence
FROM   slot sl
       JOIN student s ON s.student_id = sl.tutor_id
WHERE  NOT EXISTS (
         SELECT 1
         FROM   booking b
         WHERE  b.tutor_id   = sl.tutor_id          -- correlation 1
         AND    b.slot_no    = sl.slot_no           -- correlation 2
         AND    b.status IN ('REQUESTED','CONFIRMED')
         AND    b.sched_date = TRUNC (SYSDATE,'IW') + 7
                             + CASE sl.day_of_week  -- correlation 3
                                 WHEN 'MON' THEN 0 WHEN 'TUE' THEN 1
                                 WHEN 'WED' THEN 2 WHEN 'THU' THEN 3
                                 WHEN 'FRI' THEN 4 WHEN 'SAT' THEN 5
                                 ELSE 6 END)
ORDER  BY next_occurrence, sl.start_time;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M2-Q5 : capacity versus demand (AGGREGATE)
PROMPT  > AGGREGATE with GROUP BY / HAVING: teaching capacity vs demand per subject.
PROMPT  > COUNT(DISTINCT tutor_id) avoids counting the same tutor twice.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT sub.subject_code,
PROMPT  |         sub.subject_name,
PROMPT  |         COUNT (DISTINCT ts.tutor_id)                       AS tutors_available,
PROMPT  |         SUM (CASE WHEN ts.competency_level = 'EXPERT'
PROMPT  |                   THEN 1 ELSE 0 END)                       AS experts,
PROMPT  |         MIN (ts.certified_on)                              AS first_certified,
PROMPT  |         (SELECT COUNT (*)
PROMPT  |          FROM   booking b
PROMPT  |          WHERE  b.subject_id = sub.subject_id)             AS total_bookings,
PROMPT  |         ROUND ((SELECT COUNT (*)
PROMPT  |                 FROM   booking b2
PROMPT  |                 WHERE  b2.subject_id = sub.subject_id)
PROMPT  |                / COUNT (DISTINCT ts.tutor_id), 2)          AS load_per_tutor
PROMPT  |  FROM   subject sub
PROMPT  |         JOIN tutor_skill ts ON ts.subject_id = sub.subject_id
PROMPT  |  GROUP  BY sub.subject_id, sub.subject_code, sub.subject_name
PROMPT  |  HAVING COUNT (DISTINCT ts.tutor_id) >= 1
PROMPT  |  ORDER  BY load_per_tutor DESC, tutors_available DESC;
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT sub.subject_code,
       sub.subject_name,
       COUNT (DISTINCT ts.tutor_id)                       AS tutors_available,
       SUM (CASE WHEN ts.competency_level = 'EXPERT'
                 THEN 1 ELSE 0 END)                       AS experts,
       MIN (ts.certified_on)                              AS first_certified,
       (SELECT COUNT (*)
        FROM   booking b
        WHERE  b.subject_id = sub.subject_id)             AS total_bookings,
       ROUND ((SELECT COUNT (*)
               FROM   booking b2
               WHERE  b2.subject_id = sub.subject_id)
              / COUNT (DISTINCT ts.tutor_id), 2)          AS load_per_tutor
FROM   subject sub
       JOIN tutor_skill ts ON ts.subject_id = sub.subject_id
GROUP  BY sub.subject_id, sub.subject_code, sub.subject_name
HAVING COUNT (DISTINCT ts.tutor_id) >= 1
ORDER  BY load_per_tutor DESC, tutors_available DESC;
SET ECHO OFF
PROMPT
PROMPT
PROMPT ================================================================
PROMPT  M2-Q6 : tutor ranking within each subject (ANALYTIC)
PROMPT  > ANALYTIC functions: rank tutors inside each subject (best first).
PROMPT  > RANK, COUNT() OVER, LAG and FIRST_VALUE with PARTITION BY subject.
PROMPT ================================================================
PAUSE  [ Press ENTER to show the query ]
PROMPT
PROMPT  ======================== THE QUERY ========================
PROMPT  |  SELECT sub.subject_code,
PROMPT  |         s.first_name || ' ' || s.last_name           AS tutor_name,
PROMPT  |         ts.competency_level,
PROMPT  |         ts.grade_proof,
PROMPT  |         RANK () OVER (PARTITION BY sub.subject_id
PROMPT  |                       ORDER BY CASE ts.competency_level
PROMPT  |                                  WHEN 'EXPERT'     THEN 1
PROMPT  |                                  WHEN 'PROFICIENT' THEN 2
PROMPT  |                                  ELSE                   3 END,
PROMPT  |                                ts.grade_proof)       AS rank_in_subject,
PROMPT  |         COUNT (*) OVER (PARTITION BY sub.subject_id) AS tutors_in_subject,
PROMPT  |         LAG (ts.competency_level) OVER (
PROMPT  |              PARTITION BY sub.subject_id
PROMPT  |              ORDER BY ts.grade_proof)                AS level_above,
PROMPT  |         FIRST_VALUE (s.first_name) OVER (
PROMPT  |              PARTITION BY sub.subject_id
PROMPT  |              ORDER BY CASE ts.competency_level
PROMPT  |                         WHEN 'EXPERT'     THEN 1
PROMPT  |                         WHEN 'PROFICIENT' THEN 2
PROMPT  |                         ELSE                   3 END)
PROMPT  |                                                      AS top_tutor
PROMPT  |  FROM   tutor_skill ts
PROMPT  |         JOIN subject sub ON sub.subject_id = ts.subject_id
PROMPT  |         JOIN student s   ON s.student_id   = ts.tutor_id
PROMPT  |  ORDER  BY sub.subject_code, rank_in_subject;
PROMPT  |  
PROMPT  |  
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it and see the RESULT ]
PROMPT
PROMPT  ======================== RESULT ===========================
SELECT sub.subject_code,
       s.first_name || ' ' || s.last_name           AS tutor_name,
       ts.competency_level,
       ts.grade_proof,
       RANK () OVER (PARTITION BY sub.subject_id
                     ORDER BY CASE ts.competency_level
                                WHEN 'EXPERT'     THEN 1
                                WHEN 'PROFICIENT' THEN 2
                                ELSE                   3 END,
                              ts.grade_proof)       AS rank_in_subject,
       COUNT (*) OVER (PARTITION BY sub.subject_id) AS tutors_in_subject,
       LAG (ts.competency_level) OVER (
            PARTITION BY sub.subject_id
            ORDER BY ts.grade_proof)                AS level_above,
       FIRST_VALUE (s.first_name) OVER (
            PARTITION BY sub.subject_id
            ORDER BY CASE ts.competency_level
                       WHEN 'EXPERT'     THEN 1
                       WHEN 'PROFICIENT' THEN 2
                       ELSE                   3 END)
                                                    AS top_tutor
FROM   tutor_skill ts
       JOIN subject sub ON sub.subject_id = ts.subject_id
       JOIN student s   ON s.student_id   = ts.tutor_id
ORDER  BY sub.subject_code, rank_in_subject;


PROMPT
PROMPT ===== MEMBER 2 COMPLETE : 3 DML + 6 SELECT = 9 queries =====
SET ECHO OFF
PROMPT
PROMPT ===> All steps of this file are done. Results stay above - scroll up.
PROMPT ===> Type EXIT and press Enter when you want to close this window.
