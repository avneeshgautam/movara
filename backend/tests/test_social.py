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
        session.execute(delete(db.ProfilePhoto))
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


class TestUsernamePrivacy:
    def test_others_see_username_not_real_name(self, local_signing_key):
        # Bob sets a username; Alice should see that, not "Bob Smith".
        client.put(
            "/api/profile",
            json={"displayName": "Bob Smith", "username": "IronBob"},
            headers=headers_for(local_signing_key, "bob"),
        )
        set_profile(local_signing_key, "alice", "Alice Jones")

        board = client.get(
            "/api/leaderboard", headers=headers_for(local_signing_key, "alice")
        ).json()
        names = {e["userId"]: e["displayName"] for e in board}
        assert names["bob"] == "IronBob"
        # Alice sees her own real name on her row.
        assert names["alice"] == "Alice Jones"

    def test_without_username_others_see_first_name_only(self, local_signing_key):
        set_profile(local_signing_key, "bob", "Bob Smith")
        set_profile(local_signing_key, "alice", "Alice Jones")

        board = client.get(
            "/api/leaderboard", headers=headers_for(local_signing_key, "alice")
        ).json()
        names = {e["userId"]: e["displayName"] for e in board}
        assert names["bob"] == "Bob"  # first name only, surname hidden
        assert names["alice"] == "Alice Jones"  # own row, full name

    def test_profile_me_returns_username(self, local_signing_key):
        client.put(
            "/api/profile",
            json={"displayName": "Bob Smith", "username": "IronBob"},
            headers=headers_for(local_signing_key, "bob"),
        )
        me = client.get(
            "/api/profile/me", headers=headers_for(local_signing_key, "bob")
        ).json()
        assert me["displayName"] == "Bob Smith"
        assert me["username"] == "IronBob"

    def test_username_must_be_unique(self, local_signing_key):
        client.put(
            "/api/profile",
            json={"displayName": "Bob", "username": "IronBob"},
            headers=headers_for(local_signing_key, "bob"),
        )
        # Alice cannot take the same name (case-insensitively).
        clash = client.put(
            "/api/profile",
            json={"displayName": "Alice", "username": "ironbob"},
            headers=headers_for(local_signing_key, "alice"),
        )
        assert clash.status_code == 409
        # Availability endpoint agrees.
        avail = client.get(
            "/api/profile/username-available",
            params={"u": "IronBob"},
            headers=headers_for(local_signing_key, "alice"),
        ).json()
        assert avail["available"] is False
        # But the owner can re-save their own name.
        again = client.put(
            "/api/profile",
            json={"displayName": "Bob", "username": "IronBob"},
            headers=headers_for(local_signing_key, "bob"),
        )
        assert again.status_code == 204


# Smallest valid-looking images: only the magic bytes are checked.
JPEG = b"\xff\xd8\xff\xe0" + b"\x00" * 64
PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64


def upload_photo(key, uid, data, content_type="image/jpeg"):
    return client.put(
        "/api/profile/photo",
        content=data,
        headers={**headers_for(key, uid), "Content-Type": content_type},
    )


class TestProfilePhoto:
    def test_upload_serves_the_photo_and_sets_the_profile_url(self, local_signing_key):
        set_profile(local_signing_key, "alice", "Alice")
        r = upload_photo(local_signing_key, "alice", JPEG)
        assert r.status_code == 200
        url = r.json()["photoUrl"]
        assert "/api/profile/photo/alice?v=" in url

        # Public: fetched without an auth header, like an image widget does.
        img = client.get("/api/profile/photo/alice")
        assert img.status_code == 200
        assert img.content == JPEG
        assert img.headers["content-type"] == "image/jpeg"

        me = client.get("/api/profile/me", headers=headers_for(local_signing_key, "alice"))
        assert me.json()["photoUrl"] == url
        assert me.json()["photoCustom"] is True

    def test_uploaded_photo_survives_the_sign_in_upsert(self, local_signing_key):
        upload_photo(local_signing_key, "alice", PNG)
        # The client sends its Google photo on every launch.
        client.put(
            "/api/profile",
            json={"displayName": "Alice", "photoUrl": "https://google/photo.jpg"},
            headers=headers_for(local_signing_key, "alice"),
        )
        board = client.get(
            "/api/leaderboard", headers=headers_for(local_signing_key, "alice")
        ).json()
        assert "/api/profile/photo/alice" in board[0]["photoUrl"]

    def test_remove_restores_the_sign_in_photo(self, local_signing_key):
        upload_photo(local_signing_key, "alice", JPEG)
        r = client.delete("/api/profile/photo", headers=headers_for(local_signing_key, "alice"))
        assert r.status_code == 204
        assert client.get("/api/profile/photo/alice").status_code == 404

        client.put(
            "/api/profile",
            json={"displayName": "Alice", "photoUrl": "https://google/photo.jpg"},
            headers=headers_for(local_signing_key, "alice"),
        )
        me = client.get("/api/profile/me", headers=headers_for(local_signing_key, "alice"))
        assert me.json()["photoUrl"] == "https://google/photo.jpg"
        assert me.json()["photoCustom"] is False

    def test_rejects_non_images_and_oversized_uploads(self, local_signing_key):
        assert upload_photo(local_signing_key, "alice", b"<svg>x</svg>").status_code == 415
        assert upload_photo(local_signing_key, "alice", b"").status_code == 400
        big = JPEG + b"\x00" * 2_100_000
        assert upload_photo(local_signing_key, "alice", big).status_code == 413

    def test_upload_requires_sign_in(self):
        r = client.put("/api/profile/photo", content=JPEG)
        assert r.status_code == 401


class TestProfileStatus:
    def test_status_saves_shows_on_board_and_clears(self, local_signing_key):
        h = headers_for(local_signing_key, "alice")
        client.put(
            "/api/profile",
            json={"displayName": "Alice", "username": "devil", "status": "Training for a 10K"},
            headers=h,
        )
        me = client.get("/api/profile/me", headers=h).json()
        assert me["username"] == "devil"
        assert me["status"] == "Training for a 10K"
        board = client.get("/api/leaderboard", headers=h).json()
        assert board[0]["displayName"] == "devil"
        assert board[0]["status"] == "Training for a 10K"

        # The sign-in upsert omits status; it must not wipe it.
        client.put("/api/profile", json={"displayName": "Alice"}, headers=h)
        assert client.get("/api/profile/me", headers=h).json()["status"] == "Training for a 10K"

        # An empty string clears it.
        client.put("/api/profile", json={"displayName": "Alice", "status": "  "}, headers=h)
        assert client.get("/api/profile/me", headers=h).json()["status"] is None

    def test_status_is_capped_at_100_chars(self, local_signing_key):
        h = headers_for(local_signing_key, "alice")
        client.put("/api/profile", json={"displayName": "A", "status": "x" * 300}, headers=h)
        assert len(client.get("/api/profile/me", headers=h).json()["status"]) == 100
