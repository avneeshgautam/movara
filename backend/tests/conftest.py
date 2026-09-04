"""Shared test fixtures.

Auth is exercised against a locally generated RSA key standing in for Google's
signing certificate, so tests never touch the network.
"""

import datetime as dt

import jwt
import pytest
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID

from app import auth, config

PROJECT = 'movara-test'
KID = 'test-key'


@pytest.fixture(autouse=True)
def local_signing_key(monkeypatch):
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    subject = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'movara-test')])
    cert = (
        x509.CertificateBuilder()
        .subject_name(subject)
        .issuer_name(subject)
        .public_key(key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=1))
        .not_valid_after(dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=1))
        .sign(key, hashes.SHA256())
    )
    pem = cert.public_bytes(serialization.Encoding.PEM).decode()

    monkeypatch.setattr(auth, '_signing_certs', lambda force_refresh=False: {KID: pem})
    monkeypatch.setattr(config, 'FIREBASE_PROJECT_ID', PROJECT)
    return key


def make_token(key, *, project=PROJECT, sub='user-1', expired=False, kid=KID):
    now = dt.datetime.now(dt.timezone.utc)
    claims = {
        'sub': sub,
        'aud': project,
        'iss': f'https://securetoken.google.com/{project}',
        'iat': now - dt.timedelta(minutes=5),
        'exp': now - dt.timedelta(minutes=1) if expired else now + dt.timedelta(hours=1),
        'email': 'a@example.com',
        'name': 'Test User',
    }
    private_pem = key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    return jwt.encode(claims, private_pem, algorithm='RS256', headers={'kid': kid})


@pytest.fixture
def auth_headers(local_signing_key):
    return {'Authorization': f'Bearer {make_token(local_signing_key)}'}
