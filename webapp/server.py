# =====================================================================
#  TimeBank web app  --  Python (stdlib http.server) + python-oracledb
#
#  Browser (index.html)  --HTTP/JSON-->  server.py  --oracledb-->  Oracle
#
#  Every SQL statement the server runs is:
#    1. printed in THIS console window (like SQL*Plus), and
#    2. sent back to the browser, which shows it in the live SQL panel.
# =====================================================================
import json, os, re, sys, time, subprocess, threading, webbrowser, datetime, decimal
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import oracledb

DB_USER, DB_PASS, DB_DSN = "timebank", "timebank", "localhost:1521/FREEPDB1"
PORT = 8765
HERE = os.path.dirname(os.path.abspath(__file__))
SQL_DIR = os.path.join(HERE, "..", "sql")

pool = oracledb.create_pool(user=DB_USER, password=DB_PASS, dsn=DB_DSN, min=1, max=4, increment=1)

if os.name == "nt":
    os.system("")  # enable ANSI colours in the Windows console
C = dict(g="\033[92m", y="\033[93m", c="\033[96m", r="\033[91m", m="\033[95m", d="\033[90m", x="\033[0m")


def jsonable(v):
    if isinstance(v, (datetime.datetime, datetime.date)):
        return v.strftime("%Y-%m-%d %H:%M") if isinstance(v, datetime.datetime) and (v.hour or v.minute) else v.strftime("%Y-%m-%d")
    if isinstance(v, decimal.Decimal):
        return float(v)
    if isinstance(v, oracledb.LOB):
        return v.read()
    return v


class Session:
    """One HTTP request = one DB connection + a log of every statement run."""

    def __init__(self, source):
        self.source, self.log = source, []
        self.conn = pool.acquire()
        self.cur = self.conn.cursor()
        self.cur.callproc("dbms_output.enable", [None])

    def _output(self):
        lines, line, status = [], self.cur.var(str), self.cur.var(int)
        while True:
            self.cur.callproc("dbms_output.get_line", (line, status))
            if status.getvalue() != 0:
                break
            lines.append(line.getvalue() or "")
        return lines

    def run(self, sql, binds=None, fetch=True):
        sql = sql.strip().rstrip(";") if not sql.strip().upper().startswith(("BEGIN", "DECLARE")) else sql.strip()
        binds = binds or {}
        entry = {"sql": sql, "binds": {k: (v.getvalue() if hasattr(v, "getvalue") else v) for k, v in binds.items()},
                 "source": self.source, "t": time.strftime("%H:%M:%S")}
        print(f"\n{C['d']}[{entry['t']}] {self.source}{C['x']}")
        print(f"{C['c']}SQL> {C['x']}" + sql.replace("\n", "\n     "))
        if binds:
            print(f"{C['y']}     binds: {entry['binds']}{C['x']}")
        t0 = time.time()
        try:
            self.cur.execute(sql, binds)
            cols, rows = [], []
            if self.cur.description:
                cols = [d[0] for d in self.cur.description]
                rows = [[jsonable(v) for v in r] for r in self.cur.fetchall()]
                entry["result"] = f"{len(rows)} row(s) selected"
            else:
                rc = self.cur.rowcount
                entry["result"] = "PL/SQL procedure successfully completed." if sql.upper().startswith(("BEGIN", "DECLARE")) \
                    else f"{rc} row(s) affected"
            out = self._output()
            if out:
                entry["output"] = out
            entry["ms"] = round((time.time() - t0) * 1000, 1)
            entry["binds_out"] = {k: jsonable(v.getvalue()) for k, v in binds.items() if hasattr(v, "getvalue")}
            if entry["binds_out"]:
                entry["binds"].update(entry["binds_out"])
            print(f"{C['g']}     {entry['result']}  ({entry['ms']} ms){C['x']}")
            for o in out:
                print(f"{C['m']}     {o}{C['x']}")
            self.log.append(entry)
            return cols, rows
        except oracledb.DatabaseError as e:
            msg = str(e).split("\nHelp:")[0]
            entry["error"], entry["ms"] = msg, round((time.time() - t0) * 1000, 1)
            print(f"{C['r']}     {msg}{C['x']}")
            self.log.append(entry)
            raise

    def rows(self, sql, binds=None):
        cols, rows = self.run(sql, binds)
        return {"cols": cols, "rows": rows}

    def commit(self):
        self.conn.commit()
        self.log.append({"sql": "COMMIT", "source": self.source, "t": time.strftime("%H:%M:%S"), "result": "Commit complete.", "ms": 0})
        print(f"{C['c']}SQL> {C['x']}COMMIT;\n{C['g']}     Commit complete.{C['x']}")

    def rollback(self, why=""):
        self.conn.rollback()
        self.log.append({"sql": "ROLLBACK", "source": self.source, "t": time.strftime("%H:%M:%S"), "result": "Rollback complete. " + why, "ms": 0})
        print(f"{C['c']}SQL> {C['x']}ROLLBACK;  {C['d']}{why}{C['x']}")

    def close(self):
        try:
            self.conn.rollback()
        finally:
            pool.release(self.conn)


# ---------------------------------------------------------------------
#  Query Lab: read the members' query files straight from ../sql
# ---------------------------------------------------------------------
EXPL = json.load(open(os.path.join(HERE, "explanations.json")))
HDR = re.compile(r"^PROMPT\s+(=+|-+)\s+(M\d-[A-Z0-9]+|[A-E]\d\.?)\s*:?\s*(.*)$")


def load_lab():
    lab = []
    for fn, member in [("06_member1_onboarding.sql", "Member 1 - Onboarding"), ("07_member2_skills.sql", "Member 2 - Skills"),
                       ("08_member3_booking.sql", "Member 3 - Booking"), ("09_member4_credit.sql", "Member 4 - Ledger"),
                       ("10_member5_feedback_disputes.sql", "Member 5 - Feedback"), ("11_group_tcl_plans.sql", "Group - Plans & Graph")]:
        cur = None
        for ln in open(os.path.join(SQL_DIR, fn), encoding="utf-8", errors="ignore").read().splitlines():
            s = ln.strip()
            if s.startswith("--"):
                continue
            m = HDR.match(s)
            if m:
                key = m.group(2).rstrip(".")
                cur = {"id": key, "title": m.group(3).strip("=- ") or key, "member": member, "body": [],
                       "explain": EXPL.get(key, [])}
                lab.append(cur)
                continue
            if cur is not None:
                cur["body"].append(ln)
    out = []
    for q in lab:
        body = [l for l in q["body"] if not l.strip().upper().startswith(("PROMPT", "SET ", "EXEC"))]
        text = "\n".join(body).strip()
        # only SELECT-type items (Qn, C, E) are re-runnable from the web
        if not (re.match(r"M\d-Q\d", q["id"]) or q["id"][0] in "CE"):
            continue
        stmts = [s.strip() for s in re.split(r";\s*\n", text + "\n") if s.strip()]
        q["statements"], q["sql"] = stmts, text
        del q["body"]
        out.append(q)
    return out


LAB = load_lab()


# ---------------------------------------------------------------------
#  API  -- each function = one button / form in the frontend
# ---------------------------------------------------------------------
def api_dashboard(s, p):
    counts = s.rows("""SELECT 'Students' k, COUNT(*) v FROM student UNION ALL
SELECT 'Tutors', COUNT(*) FROM tutor UNION ALL SELECT 'Tutees', COUNT(*) FROM tutee UNION ALL
SELECT 'Subjects', COUNT(*) FROM subject UNION ALL SELECT 'Bookings', COUNT(*) FROM booking UNION ALL
SELECT 'Ledger rows', COUNT(*) FROM credit_txn UNION ALL SELECT 'Open disputes', COUNT(*) FROM dispute WHERE status <> 'RESOLVED'""")
    audit = s.rows("""SELECT (SELECT NVL(SUM(amount),0) FROM credit_txn) AS all_balances,
       (SELECT NVL(SUM(credits_held),0) FROM booking WHERE status IN ('REQUESTED','CONFIRMED','DISPUTED')) AS in_escrow,
       (SELECT NVL(SUM(amount),0) FROM credit_txn WHERE txn_type IN ('GRANT','PENALTY')) AS grants_less_penalties
FROM dual""")
    status = s.rows("SELECT status, COUNT(*) AS n FROM booking GROUP BY status ORDER BY status")
    return {"counts": counts, "audit": audit, "status": status}


def api_students(s, p):
    return s.rows("""SELECT s.student_id, s.first_name || ' ' || s.last_name AS full_name, s.reg_no, s.email, d.school,
       CASE WHEN t.student_id IS NOT NULL AND e.student_id IS NOT NULL THEN 'BOTH'
            WHEN t.student_id IS NOT NULL THEN 'TUTOR ONLY'
            WHEN e.student_id IS NOT NULL THEN 'TUTEE ONLY' ELSE 'NEITHER YET' END AS role_in_system,
       FLOOR(MONTHS_BETWEEN(SYSDATE, s.dob)/12) AS age, v.credit_balance, s.account_status,
       (SELECT LISTAGG(phone_no, ', ') WITHIN GROUP (ORDER BY phone_no) FROM student_phone ph WHERE ph.student_id = s.student_id) AS phones
FROM   student s
       JOIN department d ON d.dept_id = s.dept_id
       JOIN v_student_balance v ON v.student_id = s.student_id
       LEFT JOIN tutor t ON t.student_id = s.student_id
       LEFT JOIN tutee e ON e.student_id = s.student_id
ORDER  BY s.student_id""")


def api_lookups(s, p):
    return {"depts": s.rows("SELECT dept_id, school || ' - ' || dept_name AS name FROM department ORDER BY dept_id"),
            "subjects": s.rows("SELECT subject_id, subject_code || ' ' || subject_name AS name FROM subject ORDER BY subject_code"),
            "tutees": s.rows("SELECT e.student_id, s.first_name || ' ' || s.last_name AS name FROM tutee e JOIN student s ON s.student_id = e.student_id ORDER BY 1"),
            "tutors": s.rows("SELECT t.student_id, s.first_name || ' ' || s.last_name AS name FROM tutor t JOIN student s ON s.student_id = t.student_id ORDER BY 1"),
            "students": s.rows("SELECT student_id, first_name || ' ' || last_name AS name FROM student ORDER BY 1"),
            "skills": s.rows("SELECT tutor_id, subject_id FROM tutor_skill"),
            "slots": s.rows("SELECT tutor_id, slot_no, day_of_week, start_time, end_time FROM slot ORDER BY tutor_id, slot_no"),
            "admins": s.rows("SELECT admin_id, admin_name FROM admin ORDER BY 1")}


def api_student_add(s, p):
    sid = s.cur.var(int)
    s.run("""BEGIN
  pkg_timebank.enrol_student (
      p_reg_no => :reg, p_first_name => :fn, p_last_name => :ln, p_email => :em,
      p_dob => TO_DATE(:dob, 'YYYY-MM-DD'), p_dept_id => :dept,
      p_block => :blk, p_room_no => :room, p_city => :city, p_student_id => :sid);
END;""", dict(reg=p["reg"], fn=p["fn"], ln=p["ln"], em=p["email"], dob=p["dob"], dept=int(p["dept"]),
               blk=p.get("block"), room=p.get("room"), city=p.get("city"), sid=sid))
    for ph in [x.strip() for x in (p.get("phones") or "").split(",") if x.strip()]:
        s.run("INSERT INTO student_phone (student_id, phone_no) VALUES (:id, :ph)", dict(id=sid.getvalue(), ph=ph))
    s.commit()
    return {"msg": f"Student {sid.getvalue()} registered with a 3.0 credit starter grant."}


def api_student_status(s, p):
    s.run("UPDATE student SET account_status = :st WHERE student_id = :id", dict(st=p["status"], id=int(p["id"])))
    s.commit()
    return {"msg": "Status updated (soft delete - history is kept)."}


def api_student_delete(s, p):
    s.run("DELETE FROM student WHERE student_id = :id", dict(id=int(p["id"])))
    s.commit()
    return {"msg": "Deleted."}


def api_phone_delete(s, p):
    s.run("DELETE FROM student_phone WHERE student_id = :id AND phone_no = :ph", dict(id=int(p["id"]), ph=p["phone"]))
    s.commit()
    return {"msg": "Phone removed."}


def api_make_role(s, p):
    if p["role"] == "TUTOR":
        s.run("INSERT INTO tutor (student_id, badge_level, verification_doc_no) VALUES (:id, 'BRONZE', :doc)",
              dict(id=int(p["id"]), doc="VIT-GRD-" + str(p["id"])))
    else:
        s.run("INSERT INTO tutee (student_id, academic_need_tier) VALUES (:id, :tier)", dict(id=int(p["id"]), tier=p.get("tier", "BASIC")))
    s.commit()
    return {"msg": f"Student {p['id']} is now also a {p['role']} (overlapping specialization)."}


def api_skills(s, p):
    return {"skills": s.rows("""SELECT ts.tutor_id, s.first_name || ' ' || s.last_name AS tutor_name, dt.school AS tutor_school,
       sub.subject_code, sub.subject_name, ds.school AS subject_school, ts.competency_level, ts.grade_proof,
       CASE WHEN dt.dept_id <> ds.dept_id THEN 'CROSS-DEPARTMENT' ELSE 'own department' END AS note
FROM   tutor_skill ts
       JOIN student    s   ON s.student_id   = ts.tutor_id
       JOIN department dt  ON dt.dept_id     = s.dept_id
       JOIN subject    sub ON sub.subject_id = ts.subject_id
       JOIN department ds  ON ds.dept_id     = sub.dept_id
ORDER  BY tutor_name, sub.subject_code"""),
            "slots": s.rows("""SELECT v.tutor_id, s.first_name AS tutor, v.slot_no, v.day_of_week, v.start_time, v.end_time,
       v.duration, v.active_bookings
FROM   v_slot_detail v JOIN student s ON s.student_id = v.tutor_id
ORDER  BY v.tutor_id, v.slot_no"""),
            "gaps": s.rows("""SELECT sub.subject_code, sub.subject_name FROM subject sub
WHERE  sub.subject_id NOT IN (SELECT subject_id FROM tutor_skill)""")}


def api_skill_add(s, p):
    s.run("""INSERT INTO tutor_skill (tutor_id, subject_id, competency_level, grade_proof, certified_on)
VALUES (:t, :sub, :lvl, :g, TRUNC(SYSDATE))""", dict(t=int(p["tutor"]), sub=int(p["subject"]), lvl=p["level"], g=p["grade"]))
    s.commit()
    return {"msg": "Skill added (row in the M:N table TUTOR_SKILL)."}


def api_slot_add(s, p):
    s.run("""INSERT INTO slot (tutor_id, slot_no, day_of_week, start_time, end_time)
VALUES (:t, (SELECT NVL(MAX(slot_no), 0) + 1 FROM slot WHERE tutor_id = :t), :d, :st, :en)""",
          dict(t=int(p["tutor"]), d=p["day"], st=float(p["start"]), en=float(p["end"])))
    s.commit()
    return {"msg": "Slot added. slot_no is the PARTIAL KEY - numbered per tutor."}


def api_slot_delete(s, p):
    s.run("DELETE FROM slot WHERE tutor_id = :t AND slot_no = :n", dict(t=int(p["tutor"]), n=int(p["slot"])))
    s.commit()
    return {"msg": "Slot deleted."}


def api_bookings(s, p):
    return s.rows("""SELECT b.booking_id, te.first_name AS tutee, tr.first_name AS tutor, sub.subject_code,
       sl.day_of_week || ' ' || sl.start_time || '-' || sl.end_time AS tutor_slot,
       TO_CHAR(b.sched_date, 'DY DD-MON-YYYY') AS on_date, b.sched_start_time AS start_hr, b.duration_hours AS hrs,
       b.session_mode, b.venue, b.status, b.credits_held, b.session_code,
       NVL(TO_CHAR(b.check_in_at, 'DD-MON HH24:MI'), '-') AS check_in,
       b.confirm_by_tutor || '/' || b.confirm_by_tutee AS confirms
FROM   booking b
       JOIN tutee   e   ON e.student_id   = b.tutee_id
       JOIN student te  ON te.student_id  = e.student_id
       JOIN tutor   t   ON t.student_id   = b.tutor_id
       JOIN student tr  ON tr.student_id  = t.student_id
       JOIN subject sub ON sub.subject_id = b.subject_id
       JOIN slot    sl  ON sl.tutor_id    = b.tutor_id
                       AND sl.slot_no     = b.slot_no
ORDER  BY b.booking_id DESC""")


def api_book(s, p):
    bk, code = s.cur.var(int), s.cur.var(str)
    s.run("""BEGIN
  pkg_timebank.book_session (
      p_tutee_id => :tutee, p_tutor_id => :tutor, p_subject_id => :subject, p_slot_no => :slot,
      p_sched_date => TO_DATE(:sdate, 'YYYY-MM-DD'), p_start_time => :start, p_duration => :dur,
      p_mode => :smode, p_venue => :venue, p_booking_id => :bk, p_session_code => :code);
END;""", dict(tutee=int(p["tutee"]), tutor=int(p["tutor"]), subject=int(p["subject"]), slot=int(p["slot"]),
               sdate=p["date"], start=float(p["start"]), dur=float(p["dur"]), smode=p["mode"], venue=p.get("venue"), bk=bk, code=code))
    s.commit()
    return {"msg": f"Booking {bk.getvalue()} created. Session code (tutee only): {code.getvalue()}"}


def _plsql(s, block, binds, msg):
    s.run(block, binds)
    s.commit()
    return {"msg": msg}


def api_checkin(s, p):
    return _plsql(s, "BEGIN pkg_timebank.check_in (p_booking_id => :bk, p_session_code => :code); END;",
                  dict(bk=int(p["id"]), code=p["code"]), "Checked in - the code proves the tutee attended.")


def api_confirm(s, p):
    return _plsql(s, "BEGIN pkg_timebank.confirm_session (p_booking_id => :bk, p_role => :role); END;",
                  dict(bk=int(p["id"]), role=p["role"]), f"Confirmed by {p['role']}.")


def api_cancel(s, p):
    return _plsql(s, "BEGIN pkg_timebank.cancel_booking (p_booking_id => :bk, p_by_role => :role); END;",
                  dict(bk=int(p["id"]), role=p["role"]), "Booking cancelled - escrow released.")


def api_reschedule(s, p):
    s.run("""UPDATE booking b
SET    b.sched_date = b.sched_date + 7, b.venue = b.venue || ' (rescheduled)'
WHERE  b.booking_id = :bk AND b.status IN ('REQUESTED','CONFIRMED')
AND    NOT EXISTS (SELECT 1 FROM booking x
                   WHERE  x.tutor_id = b.tutor_id AND x.slot_no = b.slot_no
                   AND    x.sched_date = b.sched_date + 7 AND x.booking_id <> b.booking_id
                   AND    x.status IN ('REQUESTED','CONFIRMED'))""", dict(bk=int(p["id"])))
    s.commit()
    return {"msg": "Reschedule statement executed (see rows affected in the SQL panel)."}


def api_dispute_raise(s, p):
    dno = s.cur.var(int)
    s.run("BEGIN pkg_timebank.raise_dispute (p_booking_id => :bk, p_by_role => :role, p_reason => :reason, p_dispute_no => :dno); END;",
          dict(bk=int(p["id"]), role=p["role"], reason=p["reason"], dno=dno))
    s.commit()
    return {"msg": f"Dispute {dno.getvalue()} raised - escrow frozen."}


def api_disputes(s, p):
    return s.rows("""SELECT d.booking_id, d.dispute_no, d.raised_by_role, d.reason, TO_CHAR(d.raised_on, 'DD-MON-YYYY') AS raised_on,
       d.status, d.resolution_note, a.admin_name AS resolved_by
FROM   dispute d LEFT JOIN admin a ON a.admin_id = d.resolved_by
ORDER  BY d.booking_id, d.dispute_no""")


def api_dispute_resolve(s, p):
    return _plsql(s, """BEGIN
  pkg_timebank.resolve_dispute (p_booking_id => :bk, p_dispute_no => :dno, p_admin_id => :adm,
                                p_in_favour => :fav, p_note => :note);
END;""", dict(bk=int(p["id"]), dno=int(p["dno"]), adm=int(p["admin"]), fav=p["favour"], note=p["note"]),
                  f"Resolved in favour of the {p['favour']}.")


def api_feedback(s, p):
    return s.rows("""SELECT b.booking_id, sub.subject_code, tr.first_name AS tutor, te.first_name AS tutee,
       ft.rating AS tutee_rated_tutor, fe.rating AS tutor_rated_tutee,
       CASE WHEN ft.rating IS NULL AND fe.rating IS NULL THEN 'no reviews'
            WHEN ft.rating IS NULL OR  fe.rating IS NULL THEN 'one-sided'
            ELSE 'both reviewed' END AS review_state,
       ft.comments AS tutee_comment
FROM   booking b
       JOIN      subject  sub ON sub.subject_id   = b.subject_id
       JOIN      student  tr  ON tr.student_id    = b.tutor_id
       JOIN      student  te  ON te.student_id    = b.tutee_id
       LEFT JOIN feedback ft  ON ft.booking_id    = b.booking_id AND ft.reviewer_role = 'TUTEE'
       LEFT JOIN feedback fe  ON fe.booking_id    = b.booking_id AND fe.reviewer_role = 'TUTOR'
WHERE  b.status = 'COMPLETED'
ORDER  BY b.booking_id""")


def api_feedback_add(s, p):
    s.run("""INSERT INTO feedback (booking_id, reviewer_role, rating, comments, feedback_date)
VALUES (:bk, :role, :rating, :cmt, SYSDATE)""", dict(bk=int(p["id"]), role=p["role"], rating=float(p["rating"]), cmt=p.get("comment")))
    s.commit()
    return {"msg": "Review saved."}


def api_tutors(s, p):
    return s.rows("""SELECT tutor_id, tutor_name, badge_level, age, total_hours_taught, avg_rating_as_tutor, subjects_offered
FROM   v_tutor_profile ORDER BY total_hours_taught DESC, tutor_id""")


def api_ledger(s, p):
    if p.get("student"):
        return s.rows("""SELECT t.txn_id, TO_CHAR(t.txn_timestamp, 'DD-MON HH24:MI:SS') AS posted_at, t.txn_type, t.amount,
       t.balance_snapshot AS balance_after, NVL(TO_CHAR(t.booking_id), '-') AS booking, t.remarks
FROM   credit_txn t
WHERE  t.student_id = :sid
ORDER  BY t.txn_id DESC""", dict(sid=int(p["student"])))
    return s.rows("""SELECT t.txn_id, s.first_name || ' ' || s.last_name AS student_name, t.txn_type, t.amount,
       t.balance_snapshot AS balance_after, NVL(sub.subject_code, 'n/a') AS subject,
       CASE WHEN t.booking_id IS NULL THEN 'system credit' ELSE 'session driven' END AS origin, t.remarks
FROM   credit_txn t
       JOIN      student s   ON s.student_id   = t.student_id
       LEFT JOIN booking b   ON b.booking_id   = t.booking_id
       LEFT JOIN subject sub ON sub.subject_id = b.subject_id
ORDER  BY t.txn_id DESC""")


def api_tamper(s, p):
    sql = "UPDATE credit_txn SET amount = 999 WHERE txn_id = 1" if p["kind"] == "update" else "DELETE FROM credit_txn WHERE txn_id = 1"
    s.run(sql)
    return {"msg": "!! the ledger was NOT protected"}


def api_audit(s, p):
    s.run("BEGIN pkg_timebank.audit_economy; END;")
    eq = s.rows("""SELECT (SELECT NVL(SUM(amount),0) FROM credit_txn) AS all_balances,
       (SELECT NVL(SUM(credits_held),0) FROM booking WHERE status IN ('REQUESTED','CONFIRMED','DISPUTED')) AS in_escrow,
       (SELECT NVL(SUM(amount),0) FROM credit_txn WHERE txn_type IN ('GRANT','PENALTY')) AS grants_less_penalties
FROM dual""")
    by_type = s.rows("""SELECT NVL(txn_type, '** ALL TYPES **') AS txn_kind, COUNT(*) AS rows_posted, SUM(amount) AS net_credits
FROM   credit_txn
GROUP  BY GROUPING SETS ((txn_type), ())
ORDER  BY GROUPING(txn_type), txn_kind""")
    tamper = s.rows("""SELECT t.txn_id, t.student_id, t.balance_snapshot AS recorded
FROM   credit_txn t
WHERE  t.balance_snapshot <> NVL((SELECT t2.balance_snapshot FROM credit_txn t2
                                  WHERE t2.student_id = t.student_id
                                  AND   t2.txn_id = (SELECT MAX(t3.txn_id) FROM credit_txn t3
                                                     WHERE t3.student_id = t.student_id AND t3.txn_id < t.txn_id)), 0) + t.amount""")
    return {"eq": eq, "by_type": by_type, "tamper": tamper, "output": s.log[0].get("output", [])}


def api_policy(s, p):
    return s.rows("SELECT policy_key, policy_value, description FROM credit_policy ORDER BY policy_key")


def api_policy_set(s, p):
    s.run("UPDATE credit_policy SET policy_value = :v WHERE policy_key = :k", dict(v=float(p["value"]), k=p["key"]))
    s.commit()
    return {"msg": "Policy updated - triggers read it on the next booking."}


def api_lab_list(s, p):
    return {"lab": [{k: q[k] for k in ("id", "title", "member", "explain", "sql")} for q in LAB]}


def api_lab_run(s, p):
    q = next(x for x in LAB if x["id"] == p["id"])
    results = []
    for st in q["statements"]:
        results.append(s.rows(st))
    return {"results": results}


def api_console(s, p):
    sql = p["sql"].strip()
    if sql.upper().startswith(("BEGIN", "DECLARE")):
        s.run(sql)
        return {"results": []}
    results = []
    for st in [x for x in re.split(r";\s*(?:\n|$)", sql) if x.strip()]:
        up = st.strip().upper()
        if up in ("COMMIT", "ROLLBACK"):
            s.commit() if up == "COMMIT" else s.rollback()
            continue
        cols, rows = s.run(st)
        results.append({"cols": cols, "rows": rows})
    if p.get("autocommit"):
        s.commit()
    return {"results": results}


def api_reset(s, p):
    s.close()
    cmd = ["sqlplus", "-S", f"{DB_USER}/{DB_PASS}@//{DB_DSN}", "@run_all.sql"]
    print(f"\n{C['y']}>>> Rebuilding the database: {' '.join(cmd)}{C['x']}")
    r = subprocess.run(cmd, cwd=SQL_DIR, input="EXIT\n", capture_output=True, text=True, timeout=300)
    tail = "\n".join([l for l in r.stdout.splitlines() if l.strip()][-25:])
    print(tail)
    s.log.append({"sql": "@run_all.sql   -- sqlplus: drop, DDL, indexes, triggers, package, seed", "source": s.source,
                  "t": time.strftime("%H:%M:%S"), "result": "Database rebuilt", "output": tail.splitlines(), "ms": 0})
    s.conn = None
    return {"msg": "Database rebuilt from scratch with the seed data."}


ROUTES = {k[4:]: v for k, v in globals().items() if k.startswith("api_")}


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, code, body, ctype="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body, default=str).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            return self._send(200, open(os.path.join(HERE, "index.html"), "rb").read(), "text/html; charset=utf-8")
        self._send(404, {"error": "not found"})

    def do_POST(self):
        name = self.path.split("/api/")[-1]
        p = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
        fn = ROUTES.get(name)
        if not fn:
            return self._send(404, {"error": "no route " + name})
        src = f"POST /api/{name}  ->  server.py api_{name}()" + (f"   [{p.get('_ui')}]" if p.get("_ui") else "")
        s = Session(src)
        try:
            data = fn(s, p)
            self._send(200, {"ok": True, "data": data, "log": s.log})
        except Exception as e:
            msg = str(e).split("\nHelp:")[0]
            self._send(200, {"ok": False, "error": msg, "log": s.log})
        finally:
            if s.conn is not None:
                s.close()


if __name__ == "__main__":
    print(f"{C['g']}TimeBank web app connected to Oracle as {DB_USER}@{DB_DSN}{C['x']}")
    print(f"{C['g']}Open http://localhost:{PORT}  -- every SQL statement will be printed below.{C['x']}")
    threading.Timer(1.0, lambda: webbrowser.open(f"http://localhost:{PORT}")).start()
    ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
