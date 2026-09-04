"""Auth tests.

Token verification is exercised without contacting Google: conftest injects a
locally generated RSA key as the "signing certificate".
"""

import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi import HTTPException
from fastapi.testclient import TestClient

from app import auth
from app.main import app

from conftest import make_token

client = TestClient(app)


class TestTokenVerification:
    def test_accepts_a_valid_token(self, local_signing_key):
        user = auth.verify_id_token(make_token(local_signing_key))
        assert user.uid == 'user-1'
        assert user.email == 'a@example.com'

    def test_rejects_an_expired_token(self, local_signing_key):
        with pytest.raises(HTTPException) as e:
            auth.verify_id_token(make_token(local_signing_key, expired=True))
        assert e.value.status_code == 401

    def test_rejects_a_token_minted_for_another_project(self, local_signing_key):
        """Guards against replaying a token from someone else's Firebase app."""
        with pytest.raises(HTTPException) as e:
            auth.verify_id_token(make_token(local_signing_key, project='other-app'))
        assert e.value.status_code == 401

    def test_rejects_an_unknown_signing_key(self, local_signing_key):
        with pytest.raises(HTTPException) as e:
            auth.verify_id_token(make_token(local_signing_key, kid='not-our-key'))
        assert e.value.status_code == 401

    def test_rejects_garbage(self, local_signing_key):
        with pytest.raises(HTTPException) as e:
            auth.verify_id_token('not-a-jwt')
        assert e.value.status_code == 401

    def test_rejects_a_token_signed_by_a_different_key(self, local_signing_key):
        """A correctly shaped token signed by an attacker must not pass."""
        attacker = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        with pytest.raises(HTTPException) as e:
            auth.verify_id_token(make_token(attacker))
        assert e.value.status_code == 401


class TestProtectedEndpoints:
    """Every /api route requires a bearer token; /health does not."""

    @pytest.mark.parametrize(
        'method,path',
        [
            ('get', '/api/exercises'),
            ('post', '/api/exercises'),
            ('get', '/api/workout-entries'),
            ('post', '/api/workout-entries'),
            ('delete', '/api/workout-entries/abc'),
        ],
    )
    def test_requires_a_token(self, method, path):
        # GET/DELETE take no body, so only send one where it is allowed.
        kwargs = {'json': {}} if method == 'post' else {}
        response = getattr(client, method)(path, **kwargs)
        assert response.status_code == 401

    def test_rejects_a_non_bearer_scheme(self):
        response = client.get(
            '/api/workout-entries', headers={'Authorization': 'Basic abc'}
        )
        assert response.status_code == 401

    def test_health_stays_public(self):
        """Render's health check must work without credentials."""
        response = client.get('/health')
        assert response.status_code == 200
        assert response.json()['status'] == 'ok'
