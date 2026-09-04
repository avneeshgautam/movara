"""Tests that need no database.

Request validation fails before any handler runs, so these exercise the real
app without a live MongoDB. Full CRUD is verified against a real mongod.
"""

from datetime import date, datetime

import pytest
from fastapi.testclient import TestClient

from app import config, db
from app.main import app

client = TestClient(app)


class TestValidation:
    """The Java backend answered 400 for bad payloads; keep that contract."""

    @pytest.mark.parametrize(
        "payload",
        [
            pytest.param(
                {"exerciseName": "   ", "sets": 1, "reps": 5, "performedAt": "2026-09-02"},
                id="blank-name",
            ),
            pytest.param(
                {"exerciseName": "X", "sets": 0, "reps": 5, "performedAt": "2026-09-02"},
                id="zero-sets",
            ),
            pytest.param(
                {"exerciseName": "X", "sets": 1, "reps": 0, "performedAt": "2026-09-02"},
                id="zero-reps",
            ),
            pytest.param(
                {"exerciseName": "X", "sets": 1, "reps": 5},
                id="missing-date",
            ),
        ],
    )
    def test_invalid_payload_is_400(self, payload, auth_headers):
        response = client.post(
            "/api/workout-entries", json=payload, headers=auth_headers
        )
        assert response.status_code == 400

    def test_error_body_is_json_serialisable(self, auth_headers):
        """Regression: a custom validator puts the raw ValueError in "ctx",
        which used to break serialization and turn the 400 into a 500."""
        response = client.post(
            "/api/workout-entries",
            json={"exerciseName": "   ", "sets": 1, "reps": 5, "performedAt": "2026-09-02"},
            headers=auth_headers,
        )
        assert response.status_code == 400
        detail = response.json()["detail"]
        assert detail and all({"loc", "msg", "type"} <= set(e) for e in detail)


class TestDateStorage:
    """Dates must round-trip as BSON dates, matching Spring's LocalDate mapping."""

    def test_written_as_midnight_datetime(self):
        assert db.to_bson_date(date(2026, 9, 2)) == datetime(2026, 9, 2, 0, 0)

    def test_reads_datetime_date_and_string(self):
        assert db.from_bson_date(datetime(2026, 9, 2, 13, 45)) == date(2026, 9, 2)
        assert db.from_bson_date(date(2026, 9, 2)) == date(2026, 9, 2)
        assert db.from_bson_date("2026-09-02") == date(2026, 9, 2)

    def test_rejects_nonsense(self):
        with pytest.raises(ValueError):
            db.from_bson_date(12345)


class TestIndexSetup:
    """Index creation must never take the service down.

    Regression: the Java backend left a unique index named "name" on Atlas.
    PyMongo defaults to "name_1", so Mongo raised IndexOptionsConflict and the
    app crash-looped on startup.
    """

    def test_uses_the_same_index_name_spring_used(self, monkeypatch):
        captured: dict = {}

        def fake_create_index(keys, **kwargs):
            captured.update(kwargs)
            return "name"

        monkeypatch.setattr(db.exercises, "create_index", fake_create_index)
        db._ensure_name_index()

        assert captured["name"] == "name"
        assert captured["unique"] is True

    def test_conflicting_index_is_survivable(self, monkeypatch):
        from pymongo.errors import OperationFailure

        def conflict(*args, **kwargs):
            raise OperationFailure(
                "Index already exists with a different name: name_1", 85
            )

        monkeypatch.setattr(db.exercises, "create_index", conflict)
        # Must not raise — including from the logging call itself.
        db._ensure_name_index()


class TestCorsSettings:
    """ALLOWED_ORIGINS keeps Spring's allowedOriginPatterns semantics."""

    def _settings(self, monkeypatch, value):
        monkeypatch.setattr(config, "ALLOWED_ORIGINS", value)
        return config.cors_settings()

    def test_wildcard_allows_everything(self, monkeypatch):
        assert self._settings(monkeypatch, "*") == {"allow_origins": ["*"]}

    def test_exact_origins(self, monkeypatch):
        settings = self._settings(monkeypatch, "https://a.example, https://b.example")
        assert settings["allow_origins"] == ["https://a.example", "https://b.example"]
        assert "allow_origin_regex" not in settings

    def test_wildcard_pattern_becomes_regex(self, monkeypatch):
        import re

        settings = self._settings(
            monkeypatch, "http://localhost:*,https://*.movara-9ol-84z.pages.dev"
        )
        pattern = re.compile(settings["allow_origin_regex"])
        assert pattern.match("http://localhost:8099")
        assert pattern.match("https://abc123.movara-9ol-84z.pages.dev")
        assert not pattern.match("https://evil.example.com")
