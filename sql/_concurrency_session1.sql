SET DEFINE OFF
SET SERVEROUTPUT ON
SET ECHO OFF
PROMPT
PROMPT ================================================================
PROMPT  SESSION 1 : Diya books Aarav's Monday 16:00 slot - and does NOT commit
PROMPT ================================================================
PROMPT  ======================== THE QUERY ========================
PROMPT  |  DECLARE v_bk NUMBER; v_c VARCHAR2(8); BEGIN
PROMPT  |    pkg_timebank.book_session (102, 101, 101, 1,
PROMPT  |      TRUNC(SYSDATE,'IW')+21, 16, 1.0, 'OFFLINE', 'SJT 512', v_bk, v_c);
PROMPT  |    DBMS_OUTPUT.PUT_LINE ('Session 1 got booking ' || v_bk);
PROMPT  |  END;
PROMPT  |  /
PROMPT  ============================================================
PAUSE  [ Press ENTER to run it ]
PROMPT  ======================== RESULT ===========================
DECLARE v_bk NUMBER; v_c VARCHAR2(8); BEGIN
  pkg_timebank.book_session (102, 101, 101, 1,
    TRUNC(SYSDATE,'IW')+21, 16, 1.0, 'OFFLINE', 'SJT 512', v_bk, v_c);
  DBMS_OUTPUT.PUT_LINE ('Session 1 got booking ' || v_bk);
END;
/
PROMPT
PROMPT  > The slot row is now LOCKED by SELECT ... FOR UPDATE inside book_session.
PROMPT  > NOW: double-click 9_CONCURRENCY_SESSION2.bat. It will HANG (waiting for this lock).
PROMPT  > Then come back to THIS window, type   COMMIT;   and press Enter.
