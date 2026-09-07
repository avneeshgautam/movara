"""Environment-driven configuration.

Mirrors what the previous Spring Boot `application.yml` read, so the Render
service keeps working with the same environment variables.
"""

import os
import re

# PostgreSQL connection string, e.g. the URI Supabase shows under
#   Project Settings -> Database -> Connection string
# It holds a password, so it is never committed -- set DATABASE_URL instead.
# The localhost fallback is only for a local Postgres during development.
DATABASE_URL = os.getenv(
    "DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/movara"
)

# Hosts like Render inject the port to bind. Falls back to 8080 locally.
PORT = int(os.getenv("PORT", "8080"))

# Origins allowed to call the API, comma separated. Supports "*" wildcards in
# the same way Spring's allowedOriginPatterns did, e.g.
#   http://localhost:*,https://*.movara-9ol-84z.pages.dev
ALLOWED_ORIGINS = os.getenv(
    "ALLOWED_ORIGINS", "http://localhost:*,http://127.0.0.1:*"
)


# Firebase project id used to validate ID tokens. Public (it appears in the
# client config too); auth is rejected outright when this is unset.
FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID", "")

# Movara chatbot. The key is a secret -- set it in the Render dashboard, never
# in git. Without it the /api/chat endpoint returns 503 so the app can say the
# assistant isn't set up yet. The model is configurable so it can be changed
# without a code change.
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
CHAT_MODEL = os.getenv("CHAT_MODEL", "claude-haiku-4-5-20251001")
CHAT_MAX_TOKENS = int(os.getenv("CHAT_MAX_TOKENS", "600"))


def cors_settings() -> dict:
    """Translate the ALLOWED_ORIGINS patterns into CORSMiddleware kwargs.

    Starlette matches exact origins or a single regex, so wildcard patterns
    are compiled into one anchored alternation.
    """
    patterns = [p.strip() for p in ALLOWED_ORIGINS.split(",") if p.strip()]

    if "*" in patterns:
        return {"allow_origins": ["*"]}

    exact = [p for p in patterns if "*" not in p]
    wild = [p for p in patterns if "*" in p]

    settings: dict = {"allow_origins": exact}
    if wild:
        settings["allow_origin_regex"] = "|".join(
            "^" + re.escape(p).replace(r"\*", ".*") + "$" for p in wild
        )
    return settings
