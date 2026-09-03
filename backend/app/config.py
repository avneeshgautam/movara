"""Environment-driven configuration.

Mirrors what the previous Spring Boot `application.yml` read, so the Render
service keeps working with the same environment variables.
"""

import os
import re

# Full MongoDB connection string, INCLUDING the database name, e.g.
#   mongodb+srv://user:pass@cluster0.xxxx.mongodb.net/movara
# It holds a password, so it is never committed -- set MONGODB_URI instead.
# The localhost fallback is only for a local mongod during development.
MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017/movara")

# Used when the URI carries no database name.
DEFAULT_DB_NAME = "movara"

# Hosts like Render inject the port to bind. Falls back to 8080 locally.
PORT = int(os.getenv("PORT", "8080"))

# Origins allowed to call the API, comma separated. Supports "*" wildcards in
# the same way Spring's allowedOriginPatterns did, e.g.
#   http://localhost:*,https://*.movara-9ol-84z.pages.dev
ALLOWED_ORIGINS = os.getenv(
    "ALLOWED_ORIGINS", "http://localhost:*,http://127.0.0.1:*"
)


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
