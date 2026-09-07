"""Chat endpoint tests. The Anthropic call is mocked, so no key or network."""

import httpx
import pytest
from fastapi.testclient import TestClient

from app import config
from app.main import app
from app.routers import chat as chat_router

client = TestClient(app)


class TestChat:
    def test_requires_auth(self):
        r = client.post("/api/chat", json={"messages": [{"role": "user", "content": "hi"}]})
        assert r.status_code == 401

    def test_503_without_api_key(self, monkeypatch, auth_headers):
        monkeypatch.setattr(config, "ANTHROPIC_API_KEY", "")
        r = client.post(
            "/api/chat",
            json={"messages": [{"role": "user", "content": "hi"}]},
            headers=auth_headers,
        )
        assert r.status_code == 503

    def test_empty_message_is_400(self, monkeypatch, auth_headers):
        monkeypatch.setattr(config, "ANTHROPIC_API_KEY", "k")
        r = client.post(
            "/api/chat",
            json={"messages": [{"role": "user", "content": "   "}]},
            headers=auth_headers,
        )
        assert r.status_code == 400

    def test_returns_reply(self, monkeypatch, auth_headers):
        monkeypatch.setattr(config, "ANTHROPIC_API_KEY", "k")

        def fake_post(url, headers=None, json=None, timeout=None):
            assert json["model"]
            assert json["messages"][-1]["content"] == "How far should I run?"
            return httpx.Response(
                200,
                json={"content": [{"type": "text", "text": "Start with 3 km."}]},
            )

        monkeypatch.setattr(chat_router.httpx, "post", fake_post)
        r = client.post(
            "/api/chat",
            json={"messages": [{"role": "user", "content": "How far should I run?"}]},
            headers=auth_headers,
        )
        assert r.status_code == 200
        assert r.json()["reply"] == "Start with 3 km."

    def test_upstream_error_is_502(self, monkeypatch, auth_headers):
        monkeypatch.setattr(config, "ANTHROPIC_API_KEY", "k")

        def fake_post(*a, **k):
            return httpx.Response(429, json={"error": "rate_limit"})

        monkeypatch.setattr(chat_router.httpx, "post", fake_post)
        r = client.post(
            "/api/chat",
            json={"messages": [{"role": "user", "content": "hi"}]},
            headers=auth_headers,
        )
        assert r.status_code == 502
