"""Leaderboard + profile, against a real PostgreSQL (skips without one)."""

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
        session.execute(delete(db.WorkoutEntry))
        session.execute(delete(db.Profile))
        session.execute(delete(db.Run))
        session.commit()


def headers_for(key, uid):
    return {"Authorization": f"Bearer {make_token(key, sub=uid)}"}


def set_profile(key, uid, name):
    return client.put("/api/profile", json={"displayName": name}, headers=headers_for(key, uid))


def log_sets(key, uid, sets, when="2026-09-07"):
    return client.post(
        "/api/workout-entries",
        json={"exerciseName": "Squats", "sets": sets, "reps": 10, "performedAt": when},
        headers=headers_for(key, uid),
    )


def upload_run(key, uid, run_id, metres, when="2026-09-07T07:00:00"):
    return client.post(
        "/api/runs",
        json={
            "id": run_id,
            "startedAt": when,
            "elapsedSeconds": 600,
            "distanceMeters": metres,
        },
        headers=headers_for(key, uid),
    )


class TestLeaderboard:
    def test_profile_upsert_puts_you_on_the_board(self, local_signing_key):
        assert set_profile(local_signing_key, "alice", "Alice").status_code == 204
        r = client.get("/api/leaderboard", headers=headers_for(local_signing_key, "alice"))
        assert r.status_code == 200
        board = r.json()
        assert len(board) == 1
        assert board[0]["displayName"] == "Alice"
        assert board[0]["isMe"] is True
        assert board[0]["rank"] == 1
        assert board[0]["setsThisWeek"] == 0
        assert board[0]["points"] == 0

    def test_points_combine_sets_and_running(self, local_signing_key):
        set_profile(local_signing_key, "alice", "Alice")
        set_profile(local_signing_key, "bob", "Bob")
        # Alice: 3 sets = 30 pts. Bob: 1 set (10) + 2 km (40) = 50 pts.
        log_sets(local_signing_key, "alice", 3)
        log_sets(local_signing_key, "bob", 1)
        assert upload_run(local_signing_key, "bob", "r1", 2000).status_code == 204

        board = client.get(
            "/api/leaderboard", headers=headers_for(local_signing_key, "alice")
        ).json()
        assert [e["displayName"] for e in board] == ["Bob", "Alice"]
        assert board[0]["points"] == 50
        assert board[0]["kmThisWeek"] == 2.0
        assert board[1]["points"] == 30
        assert board[1]["isMe"] is True

    def test_run_upload_is_idempotent(self, local_signing_key):
        set_profile(local_signing_key, "alice", "Alice")
        upload_run(local_signing_key, "alice", "same-id", 1000)
        upload_run(local_signing_key, "alice", "same-id", 1000)
        board = client.get(
            "/api/leaderboard", headers=headers_for(local_signing_key, "alice")
        ).json()
        # 1 km counted once = 20 pts, not 40.
        assert board[0]["points"] == 20

    def test_last_weeks_activity_does_not_count(self, local_signing_key):
        set_profile(local_signing_key, "alice", "Alice")
        log_sets(local_signing_key, "alice", 4, when="2026-08-01")
        upload_run(local_signing_key, "alice", "old", 5000, when="2026-08-01T07:00:00")
        r = client.get("/api/leaderboard", headers=headers_for(local_signing_key, "alice"))
        assert r.json()[0]["points"] == 0

    def test_leaderboard_requires_auth(self):
        assert client.get("/api/leaderboard").status_code == 401
