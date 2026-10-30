SET DEFINE OFF
SET SERVEROUTPUT ON
SET ECHO OFF
PROMPT
PROMPT ================================================================
PROMPT  SESSION 2 : Meera tries to book the SAME slot at the same time
PROMPT ================================================================
PROMPT  ======================== THE QUERY ========================
PROMPT  |  DECLARE v_bk NUMBER; v_c VARCHAR2(8); BEGIN
PROMPT  |    pkg_timebank.book_session (112, 101, 101, 1,
PROMPT  |      TRUNC(SYSDATE,'IW')+21, 16, 1.0, 'OFFLINE', 'SJT 512', v_bk, v_c);
PROMPT  |    DBMS_OUTPUT.PUT_LINE ('Session 2 got booking ' || v_bk);
PROMPT  |  END;
PROMPT  |  /
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it ]
PROMPT  ======================== RESULT ===========================
DECLARE v_bk NUMBER; v_c VARCHAR2(8); BEGIN
  pkg_timebank.book_session (112, 101, 101, 1,
    TRUNC(SYSDATE,'IW')+21, 16, 1.0, 'OFFLINE', 'SJT 512', v_bk, v_c);
  DBMS_OUTPUT.PUT_LINE ('Session 2 got booking ' || v_bk);
END;
/
PROMPT
PROMPT  > Expected: ORA-20005 That slot is already booked.
PROMPT  > Session 2 waited for Session 1, then saw the committed booking. Exactly ONE booking exists.
PROMPT  > Oracle normal SELECT never blocks (multiversion read consistency), so the explicit
PROMPT  > FOR UPDATE row lock is what prevents the double booking.
