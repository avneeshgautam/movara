"""Admin notifications, fetched by the app — against a real PostgreSQL
(skips without one)."""

from datetime import datetime, timedelta

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import delete
from sqlalchemy.exc import SQLAlchemyError

from app import db
from app.main import app

from conftest import make_token

client = TestClient(app)


@pytest.fixture(autouse=True)
def require_database():
    try:
        db.init()
    except SQLAlchemyError:
        pytest.skip("no PostgreSQL reachable")
    with db.SessionLocal() as session:
        session.execute(delete(db.Notification))
        session.execute(delete(db.Profile))
        session.commit()


def headers_for(key, uid):
    return {"Authorization": f"Bearer {make_token(key, sub=uid)}"}


def send(user_id, title, when=None):
    with db.SessionLocal() as session:
        session.add(
            db.Notification(
                user_id=user_id,
                title=title,
                body=f"{title} body",
                created_at=when or datetime.utcnow(),
            )
        )
        session.commit()


def titles(key, uid, since=None):
    params = {"since": since} if since else None
    r = client.get("/api/notifications", params=params, headers=headers_for(key, uid))
    assert r.status_code == 200
    return [n["title"] for n in r.json()]


class TestNotifications:
    def test_personal_goes_only_to_that_user_broadcast_to_all(self, local_signing_key):
        send("alice", "For Alice")
        send(None, "For everyone")
        assert titles(local_signing_key, "alice") == ["For Alice", "For everyone"]
        assert titles(local_signing_key, "bob") == ["For everyone"]

    def test_since_returns_only_newer(self, local_signing_key):
        send(None, "old", datetime.utcnow() - timedelta(hours=2))
        send(None, "new")
        since = (datetime.utcnow() - timedelta(hours=1)).isoformat()
        assert titles(local_signing_key, "alice", since=since) == ["new"]

    def test_first_fetch_skips_old_history(self, local_signing_key):
        send(None, "ancient", datetime.utcnow() - timedelta(days=30))
        send(None, "recent")
        assert titles(local_signing_key, "alice") == ["recent"]

    def test_requires_sign_in(self):
        assert client.get("/api/notifications").status_code == 401


class TestProfileActivityTimestamps:
    def test_first_seen_is_kept_last_seen_moves(self, local_signing_key):
        h = headers_for(local_signing_key, "alice")
        client.put("/api/profile", json={"displayName": "Alice"}, headers=h)
        with db.SessionLocal() as session:
            first = session.get(db.Profile, "alice")
            created, seen = first.created_at, first.last_seen_at
        assert created is not None and seen is not None

        client.put("/api/profile", json={"displayName": "Alice"}, headers=h)
        with db.SessionLocal() as session:
            again = session.get(db.Profile, "alice")
            assert again.created_at == created
            assert again.last_seen_at >= seen
