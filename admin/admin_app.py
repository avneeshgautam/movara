"""Movara admin dashboard — LOCAL ONLY.

Runs on your Mac (see run-admin.sh), talks straight to the production
database, and is never deployed. Shows user growth and activity, per-user
detail, and sends notifications to one user or everyone (delivered by the
app's /api/notifications poll on launch/resume).

Safety:
- run-admin.sh binds to 127.0.0.1, and every request from a non-loopback
  address is refused anyway.
- Writes require an `X-Movara-Admin: 1` header, which a web page on another
  origin can't send without a CORS preflight this app never grants — so a
  malicious site open in your browser can't post notifications through it.
"""

from __future__ import annotations

import sys
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT.parent / "backend"))  # reuse the backend's models

from fastapi import FastAPI, HTTPException, Request  # noqa: E402
from fastapi.responses import HTMLResponse, JSONResponse  # noqa: E402
from pydantic import BaseModel, field_validator  # noqa: E402
from sqlalchemy import func, select  # noqa: E402

from app import db  # noqa: E402

app = FastAPI(title="Movara admin", docs_url=None, redoc_url=None, openapi_url=None)

_LOOPBACK = {"127.0.0.1", "::1", "localhost", "testclient"}


@app.middleware("http")
async def local_only(request: Request, call_next):
    host = request.client.host if request.client else ""
    if host not in _LOOPBACK:
        return JSONResponse({"detail": "Admin is local-only."}, status_code=403)
    if request.method not in ("GET", "HEAD") and request.headers.get(
        "x-movara-admin"
    ) != "1":
        return JSONResponse({"detail": "Missing admin header."}, status_code=403)
    return await call_next(request)


# ── Optional: Firebase accounts (emails, sign-up / last sign-in times) ──────
# Put a service-account key at admin/service-account.json (gitignored) and
# `pip install firebase-admin` to enable. Without it, everything still works
# from the database alone.
_SERVICE_ACCOUNT = ROOT / "service-account.json"


def _firebase_users() -> dict[str, dict]:
    if not _SERVICE_ACCOUNT.exists():
        return {}
    try:
        import firebase_admin
        from firebase_admin import auth, credentials
    except ImportError:
        return {}
    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.Certificate(str(_SERVICE_ACCOUNT)))
    out: dict[str, dict] = {}
    page = auth.list_users()
    while page:
        for u in page.users:
            meta = u.user_metadata
            out[u.uid] = {
                "email": u.email,
                "signedUpAt": _ms(meta.creation_timestamp),
                "lastSignInAt": _ms(meta.last_sign_in_timestamp),
                "disabled": u.disabled,
            }
        page = page.get_next_page()
    return out


def _fcm_send(tokens: list[str], title: str, body: str) -> None:
    """Send a Firebase Cloud Messaging push to every token in the list.

    Uses the FCM HTTP v1 API with an OAuth2 bearer token derived from the
    service account. Silently skips when firebase-admin isn't installed or
    the service-account file is missing (falls back to polling only).
    """
    if not tokens or not _SERVICE_ACCOUNT.exists():
        return
    try:
        import firebase_admin
        from firebase_admin import credentials, messaging
    except ImportError:
        return

    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.Certificate(str(_SERVICE_ACCOUNT)))

    # FCM caps at 500 tokens per call.
    for i in range(0, len(tokens), 500):
        batch = tokens[i : i + 500]
        message = messaging.MulticastMessage(
            notification=messaging.Notification(title=title, body=body),
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    sound="default",
                    priority="high",
                    default_vibrate_timings=True,
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound="default",
                        badge=1,
                    )
                )
            ),
            tokens=batch,
        )
        try:
            messaging.send_each_for_multicast(message)
        except Exception as exc:  # pragma: no cover
            import logging
            logging.getLogger(__name__).warning("FCM send failed: %s", exc)


def _ms(ms: int | None) -> datetime | None:
    return datetime.fromtimestamp(ms / 1000, tz=timezone.utc).replace(tzinfo=None) if ms else None


# ── Aggregation ──────────────────────────────────────────────────────────────


def _as_dt(v) -> datetime | None:
    if v is None:
        return None
    if isinstance(v, datetime):
        return v
    return datetime(v.year, v.month, v.day)


def _user_rows() -> list[dict]:
    """Every user with first-seen, last-active and activity totals."""
    fb = _firebase_users()
    week_start = date.today() - timedelta(days=date.today().weekday())
    with db.SessionLocal() as s:
        profiles = s.scalars(select(db.Profile)).all()
        entries = s.execute(
            select(
                db.WorkoutEntry.user_id,
                func.min(db.WorkoutEntry.performed_at),
                func.max(db.WorkoutEntry.performed_at),
                func.coalesce(func.sum(db.WorkoutEntry.sets), 0),
            ).group_by(db.WorkoutEntry.user_id)
        ).all()
        week_sets = dict(
            s.execute(
                select(db.WorkoutEntry.user_id, func.sum(db.WorkoutEntry.sets))
                .where(db.WorkoutEntry.performed_at >= week_start)
                .group_by(db.WorkoutEntry.user_id)
            ).all()
        )
        runs = s.execute(
            select(
                db.Run.user_id,
                func.min(db.Run.started_at),
                func.max(db.Run.started_at),
                func.count(),
                func.coalesce(func.sum(db.Run.distance_meters), 0.0),
            ).group_by(db.Run.user_id)
        ).all()

    e_by = {u: (lo, hi, n) for u, lo, hi, n in entries}
    r_by = {u: (lo, hi, n, m) for u, lo, hi, n, m in runs}
    rows = []
    for p in profiles:
        e = e_by.get(p.user_id, (None, None, 0))
        r = r_by.get(p.user_id, (None, None, 0, 0.0))
        f = fb.get(p.user_id, {})
        firsts = [x for x in (f.get("signedUpAt"), p.created_at, _as_dt(e[0]), r[0]) if x]
        lasts = [x for x in (f.get("lastSignInAt"), p.last_seen_at, _as_dt(e[1]), r[1]) if x]
        rows.append(
            {
                "userId": p.user_id,
                "name": p.username or p.display_name,
                "signInName": p.display_name,
                "username": p.username,
                "status": p.status,
                "photoUrl": p.photo_url,
                "email": f.get("email"),
                "firstSeen": min(firsts).isoformat() if firsts else None,
                "lastActive": max(lasts).isoformat() if lasts else None,
                "setsTotal": int(e[2]),
                "setsThisWeek": int(week_sets.get(p.user_id, 0) or 0),
                "runs": int(r[2]),
                "km": round(float(r[3]) / 1000, 1),
            }
        )
    rows.sort(key=lambda u: u["lastActive"] or "", reverse=True)
    return rows


@app.get("/api/overview")
def overview() -> dict:
    users = _user_rows()
    today = date.today()
    week_start = today - timedelta(days=today.weekday())

    def day(iso: str | None) -> date | None:
        return datetime.fromisoformat(iso).date() if iso else None

    new_by_day: dict[date, int] = defaultdict(int)
    for u in users:
        d = day(u["firstSeen"])
        if d:
            new_by_day[d] += 1

    # Last 60 days: new users per day and the running total.
    start = today - timedelta(days=59)
    before = sum(n for d, n in new_by_day.items() if d < start)
    series, total = [], before
    for i in range(60):
        d = start + timedelta(days=i)
        total += new_by_day.get(d, 0)
        series.append({"date": d.isoformat(), "new": new_by_day.get(d, 0), "total": total})

    with db.SessionLocal() as s:
        sent = s.scalar(select(func.count()).select_from(db.Notification)) or 0

    return {
        "users": len(users),
        "newThisWeek": sum(1 for u in users if (d := day(u["firstSeen"])) and d >= week_start),
        "activeToday": sum(1 for u in users if day(u["lastActive"]) == today),
        "active7d": sum(
            1 for u in users if (d := day(u["lastActive"])) and d >= today - timedelta(days=6)
        ),
        "setsTotal": sum(u["setsTotal"] for u in users),
        "runsTotal": sum(u["runs"] for u in users),
        "kmTotal": round(sum(u["km"] for u in users), 1),
        "notificationsSent": sent,
        "firebaseLinked": _SERVICE_ACCOUNT.exists(),
        "growth": series,
    }


@app.get("/api/users")
def users() -> list[dict]:
    return _user_rows()


@app.get("/api/users/{user_id}")
def user_detail(user_id: str) -> dict:
    row = next((u for u in _user_rows() if u["userId"] == user_id), None)
    if row is None:
        raise HTTPException(status_code=404, detail="No such user.")
    with db.SessionLocal() as s:
        entries = s.scalars(
            select(db.WorkoutEntry)
            .where(db.WorkoutEntry.user_id == user_id)
            .order_by(db.WorkoutEntry.performed_at.desc())
            .limit(30)
        ).all()
        runs = s.scalars(
            select(db.Run)
            .where(db.Run.user_id == user_id)
            .order_by(db.Run.started_at.desc())
            .limit(15)
        ).all()
        notes = s.scalars(
            select(db.Notification)
            .where(db.Notification.user_id == user_id)
            .order_by(db.Notification.created_at.desc())
            .limit(20)
        ).all()
    return {
        **row,
        "recentWorkouts": [
            {
                "exercise": e.exercise_name,
                "sets": e.sets,
                "reps": e.reps,
                "weightKg": e.weight_kg,
                "date": e.performed_at.isoformat(),
            }
            for e in entries
        ],
        "recentRuns": [
            {
                "startedAt": r.started_at.isoformat(),
                "km": round(r.distance_meters / 1000, 2),
                "minutes": round(r.elapsed_seconds / 60),
            }
            for r in runs
        ],
        "notifications": [
            {"title": n.title, "body": n.body, "sentAt": n.created_at.isoformat()}
            for n in notes
        ],
    }


class NotifyRequest(BaseModel):
    userId: str | None = None  # None = everyone
    title: str
    body: str

    @field_validator("title", "body")
    @classmethod
    def _required(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("required")
        return v


@app.post("/api/notify")
def notify(req: NotifyRequest) -> dict:
    with db.SessionLocal() as s:
        if req.userId and s.get(db.Profile, req.userId) is None:
            raise HTTPException(status_code=404, detail="No such user.")
        n = db.Notification(
            user_id=req.userId or None,
            title=req.title[:120],
            body=req.body[:500],
            created_at=datetime.now(timezone.utc).replace(tzinfo=None),
        )
        s.add(n)
        s.commit()

        # ── FCM push ────────────────────────────────────────────────────────
        # Collect device tokens: one specific user or every registered device.
        if req.userId:
            profile = s.get(db.Profile, req.userId)
            tokens = [profile.fcm_token] if profile and profile.fcm_token else []
        else:
            profiles = s.scalars(select(db.Profile)).all()
            tokens = [p.fcm_token for p in profiles if p.fcm_token]

        _fcm_send(tokens, n.title, n.body)
        return {"id": n.id, "sentAt": n.created_at.isoformat()}


@app.get("/api/notifications")
def sent_notifications() -> list[dict]:
    with db.SessionLocal() as s:
        names = {
            p.user_id: p.username or p.display_name
            for p in s.scalars(select(db.Profile)).all()
        }
        rows = s.scalars(
            select(db.Notification).order_by(db.Notification.created_at.desc()).limit(50)
        ).all()
    return [
        {
            "title": n.title,
            "body": n.body,
            "to": "Everyone" if n.user_id is None else names.get(n.user_id, n.user_id),
            "sentAt": n.created_at.isoformat(),
        }
        for n in rows
    ]


@app.get("/", response_class=HTMLResponse)
def page() -> str:
    return (ROOT / "dashboard.html").read_text()
