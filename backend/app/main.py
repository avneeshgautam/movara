"""Movara backend — FastAPI + MongoDB.

Replaces the previous Spring Boot service. The HTTP contract is unchanged, so
the Flutter client needs no modification.
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from . import config, db
from .routers import exercises, workout_entries


@asynccontextmanager
async def lifespan(app: FastAPI):
    db.init()
    yield


app = FastAPI(
    title="Movara API",
    description="Workout logging backend (sets, reps, weight per exercise).",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    # No cookies/auth are used, so credentials stay off -- this also keeps
    # ALLOWED_ORIGINS="*" valid for browsers.
    allow_credentials=False,
    **config.cors_settings(),
)


@app.exception_handler(RequestValidationError)
async def validation_error_handler(request: Request, exc: RequestValidationError):
    """Return 400 for invalid payloads.

    FastAPI defaults to 422; the Java backend returned 400, and the client
    treats anything non-2xx as an error, so 400 keeps the contract identical.
    """
    # Build a JSON-safe payload: Pydantic puts the original exception object
    # in each error's "ctx" for custom validators, which would otherwise blow
    # up serialization and turn a 400 into a 500.
    detail = [
        {
            "loc": [str(part) for part in error.get("loc", ())],
            "msg": str(error.get("msg", "")),
            "type": str(error.get("type", "")),
        }
        for error in exc.errors()
    ]
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={"detail": detail},
    )


@app.get("/health", tags=["health"])
def health() -> dict:
    """Unauthenticated liveness probe.

    The API endpoints now require a bearer token, so the platform health check
    must target this instead of /api/exercises.
    """
    return {"status": "ok"}


app.include_router(exercises.router)
app.include_router(workout_entries.router)
