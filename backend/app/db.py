"""MongoDB access.

Collections and field names match what the previous Spring Data backend
wrote, so existing Atlas documents are read and written unchanged.
"""

from datetime import date, datetime

from pymongo import ASCENDING, MongoClient

from . import config

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
    exercises.create_index([("name", ASCENDING)], unique=True)
    if exercises.count_documents({}, limit=1) == 0:
        exercises.insert_many([dict(e) for e in SEED_EXERCISES])


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
