"""MongoDB access.

Collections and field names match what the previous Spring Data backend
wrote, so existing Atlas documents are read and written unchanged.
"""

import logging
from datetime import date, datetime

from pymongo import ASCENDING, MongoClient
from pymongo.errors import OperationFailure

from . import config

logger = logging.getLogger(__name__)

_client = MongoClient(config.MONGODB_URI)
database = _client.get_default_database(default=config.DEFAULT_DB_NAME)

exercises = database["exercises"]
workout_entries = database["workout_entries"]

SEED_EXERCISES = [
    {"name": "Push-ups", "category": "Chest"},
    {"name": "Squats", "category": "Legs"},
    {"name": "Bench Press", "category": "Chest"},
    {"name": "Deadlift", "category": "Back"},
    {"name": "Pull-ups", "category": "Back"},
    {"name": "Plank", "category": "Core"},
]


def init() -> None:
    """Create indexes and seed starter exercises (idempotent)."""
    _ensure_name_index()
    if exercises.count_documents({}, limit=1) == 0:
        exercises.insert_many([dict(e) for e in SEED_EXERCISES])


def _ensure_name_index() -> None:
    """Ensure exercises.name is uniquely indexed.

    Named "name" explicitly to match the index Spring Data created on the
    existing Atlas database -- PyMongo would otherwise default to "name_1"
    and Mongo rejects the same key under a different name (IndexOptionsConflict).

    Index setup is never fatal: uniqueness is also enforced in application code
    (an existing exercise is looked up before inserting), so a conflicting or
    unavailable index must not take the whole API down at startup.
    """
    try:
        exercises.create_index([("name", ASCENDING)], unique=True, name="name")
    except OperationFailure as exc:
        # Keep this logging defensive: attribute access on the exception must
        # never itself raise, or a benign index conflict becomes a crash loop.
        logger.warning(
            "Could not create the exercises.name index (code=%s): %s; "
            "continuing, uniqueness is still enforced in code.",
            getattr(exc, "code", None),
            exc,
        )


def to_bson_date(value: date) -> datetime:
    """Store dates the way Spring Data stored LocalDate: a BSON date at midnight.

    Keeps documents written by the old Java backend and this one identical in
    shape, so queries and sorting behave the same across both.
    """
    return datetime(value.year, value.month, value.day)


def from_bson_date(value) -> date:
    """Read a stored date, tolerating datetime, date or ISO string."""
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    if isinstance(value, str):
        return date.fromisoformat(value[:10])
    raise ValueError(f"Unsupported performedAt value: {value!r}")
