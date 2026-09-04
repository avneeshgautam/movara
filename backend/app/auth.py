"""Firebase ID token verification.

Tokens are validated directly against Google's public signing certificates,
so the service needs only the (public) Firebase project id -- there is no
service-account JSON to store or rotate.
"""

import time
from dataclasses import dataclass

import httpx
import jwt
from cryptography.x509 import load_pem_x509_certificate
from fastapi import Depends, HTTPException, Request, status

from . import config

# Google publishes the certificates that sign Firebase ID tokens here.
_CERT_URL = (
    'https://www.googleapis.com/robot/v1/metadata/x509/'
    'securetoken@system.gserviceaccount.com'
)
_CERT_TTL_SECONDS = 3600

_certs: dict[str, str] = {}
_certs_fetched_at: float = 0.0


@dataclass(frozen=True)
class AuthUser:
    uid: str
    email: str | None
    name: str | None


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={'WWW-Authenticate': 'Bearer'},
    )


def _signing_certs(force_refresh: bool = False) -> dict[str, str]:
    """Google's current signing certificates, cached for an hour."""
    global _certs, _certs_fetched_at

    fresh = (time.time() - _certs_fetched_at) < _CERT_TTL_SECONDS
    if _certs and fresh and not force_refresh:
        return _certs

    response = httpx.get(_CERT_URL, timeout=10)
    response.raise_for_status()
    _certs = response.json()
    _certs_fetched_at = time.time()
    return _certs


def _public_key_for(kid: str):
    certs = _signing_certs()
    pem = certs.get(kid)
    if pem is None:
        # Google rotates keys; a miss may just mean our cache is stale.
        pem = _signing_certs(force_refresh=True).get(kid)
    if pem is None:
        raise _unauthorized('Token signing key is not recognised')
    return load_pem_x509_certificate(pem.encode()).public_key()


def verify_id_token(token: str) -> AuthUser:
    """Validate a Firebase ID token and return who it belongs to.

    PyJWT checks the RS256 signature plus expiry; audience and issuer are
    pinned to this Firebase project so a token minted for another project
    cannot be replayed here.
    """
    project_id = config.FIREBASE_PROJECT_ID
    if not project_id:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail='Authentication is not configured on this server',
        )

    try:
        kid = jwt.get_unverified_header(token).get('kid')
    except jwt.PyJWTError:
        raise _unauthorized('Malformed token') from None
    if not kid:
        raise _unauthorized('Token is missing a key id')

    try:
        claims = jwt.decode(
            token,
            _public_key_for(kid),
            algorithms=['RS256'],
            audience=project_id,
            issuer=f'https://securetoken.google.com/{project_id}',
        )
    except jwt.ExpiredSignatureError:
        raise _unauthorized('Token has expired') from None
    except jwt.PyJWTError:
        raise _unauthorized('Token is not valid') from None

    uid = claims.get('sub')
    if not uid:
        raise _unauthorized('Token has no subject')

    return AuthUser(
        uid=uid,
        email=claims.get('email'),
        name=claims.get('name'),
    )


def current_user(request: Request) -> AuthUser:
    """FastAPI dependency: the caller, or 401."""
    header = request.headers.get('Authorization', '')
    scheme, _, token = header.partition(' ')
    if scheme.lower() != 'bearer' or not token.strip():
        raise _unauthorized('Missing bearer token')
    return verify_id_token(token.strip())


def current_uid(user: AuthUser = Depends(current_user)) -> str:
    return user.uid
