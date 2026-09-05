"""Tests that need no database.

Request validation fails before any handler runs, so these exercise the real
app without a live MongoDB. Full CRUD is verified against a real mongod.
"""

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


class TestDatabaseUrl:
    """Supabase hands out postgresql:// URIs; SQLAlchemy must route them to
    psycopg 3 rather than the (uninstalled) psycopg2."""

    def test_rewrites_supabase_style_url(self):
        assert db._normalised_url(
            "postgresql://u:p@db.abc.supabase.co:5432/postgres"
        ).startswith("postgresql+psycopg://")

    def test_rewrites_legacy_postgres_scheme(self):
        assert db._normalised_url("postgres://u:p@host/db").startswith(
            "postgresql+psycopg://"
        )

    def test_leaves_an_explicit_driver_alone(self):
        url = "postgresql+psycopg://u:p@host/db"
        assert db._normalised_url(url) == url


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
