"""PostgreSQL access via SQLAlchemy.

Replaces the previous MongoDB layer. Column names are snake_case (idiomatic
SQL); the camelCase JSON contract the Flutter client speaks is handled by the
Pydantic response models, so the API is unchanged.
"""

import logging
import uuid
from datetime import date, datetime

from sqlalchemy import (
    Date,
    DateTime,
    Float,
    Index,
    Integer,
    String,
    create_engine,
    func,
    select,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, sessionmaker

from . import config

logger = logging.getLogger(__name__)


def _normalised_url(url: str) -> str:
    """Point SQLAlchemy at psycopg 3.

    Supabase hands out `postgresql://...` (and some tools still emit the
    legacy `postgres://`), both of which SQLAlchemy would route to psycopg2.
    """
    if url.startswith("postgres://"):
        url = "postgresql://" + url[len("postgres://"):]
    if url.startswith("postgresql://"):
        url = "postgresql+psycopg://" + url[len("postgresql://"):]
    return url


engine = create_engine(
    _normalised_url(config.DATABASE_URL),
    # Supabase (and Render's free tier) drop idle connections; check the
    # connection is alive before handing it out rather than failing a request.
    pool_pre_ping=True,
    pool_size=5,
    max_overflow=5,
)

SessionLocal = sessionmaker(bind=engine, expire_on_commit=False)


def _new_id() -> str:
    return str(uuid.uuid4())


class Base(DeclarativeBase):
    pass


class Exercise(Base):
    """Shared catalogue backing the exercise autocomplete."""

    __tablename__ = "exercises"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_new_id)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    category: Mapped[str | None] = mapped_column(String(100))

    # Case-insensitive uniqueness, matching the old findByNameIgnoreCase
    # behaviour: "squats" and "Squats" are the same exercise.
    __table_args__ = (
        Index("ix_exercises_name_lower", func.lower(name), unique=True),
    )


class WorkoutEntry(Base):
    """One logged set, owned by the user who recorded it."""

    __tablename__ = "workout_entries"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_new_id)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False)
    exercise_name: Mapped[str] = mapped_column(String(200), nullable=False)
    sets: Mapped[int] = mapped_column(Integer, nullable=False)
    reps: Mapped[int] = mapped_column(Integer, nullable=False)
    weight_kg: Mapped[float | None] = mapped_column(Float)
    performed_at: Mapped[date] = mapped_column(Date, nullable=False)
    notes: Mapped[str | None] = mapped_column(String(500))

    # Every query filters by owner, usually with a date.
    __table_args__ = (
        Index("ix_workout_entries_user_date", "user_id", "performed_at"),
    )


class Run(Base):
    """A recorded run, synced from the device so it can score on the
    leaderboard and (later) follow the user across devices. Route points are
    not stored here -- only what the leaderboard and history need."""

    __tablename__ = "runs"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(128), nullable=False)
    started_at: Mapped["datetime"] = mapped_column(DateTime, nullable=False)
    elapsed_seconds: Mapped[int] = mapped_column(Integer, nullable=False)
    distance_meters: Mapped[float] = mapped_column(Float, nullable=False)

    __table_args__ = (
        Index("ix_runs_user_started", "user_id", "started_at"),
    )


class Profile(Base):
    """Public-ish identity for the leaderboard: a name and photo per user.

    Upserted by the client on sign-in. Only what's needed to show someone on a
    board -- no private workout detail lives here.
    """

    __tablename__ = "profiles"

    user_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    display_name: Mapped[str] = mapped_column(String(120), nullable=False)
    photo_url: Mapped[str | None] = mapped_column(String(500))


SEED_EXERCISES = [
    ("Push-ups", "Chest"),
    ("Squats", "Legs"),
    ("Bench Press", "Chest"),
    ("Deadlift", "Back"),
    ("Pull-ups", "Back"),
    ("Plank", "Core"),
]


def get_session():
    """FastAPI dependency: a session per request, always closed."""
    with SessionLocal() as session:
        yield session


def init() -> None:
    """Create tables and seed starter exercises (idempotent)."""
    Base.metadata.create_all(engine)

    with SessionLocal() as session:
        existing = session.scalar(select(func.count()).select_from(Exercise))
        if existing:
            return
        session.add_all(
            [Exercise(name=name, category=category) for name, category in SEED_EXERCISES]
        )
        session.commit()
        logger.info("Seeded %s starter exercises.", len(SEED_EXERCISES))


def find_exercise_by_name(session: Session, name: str) -> Exercise | None:
    """Case-insensitive exact match."""
    return session.scalar(
        select(Exercise).where(func.lower(Exercise.name) == name.strip().lower())
    )
