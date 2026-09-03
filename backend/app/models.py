"""Request/response models.

Field names are deliberately camelCase to match the JSON contract the Flutter
client already speaks -- they mirror the old Java DTOs one-for-one.
"""

from datetime import date

from pydantic import BaseModel, Field, field_validator


def _require_non_blank(value: str) -> str:
    """Equivalent of Java's @NotBlank: reject whitespace-only input."""
    stripped = value.strip()
    if not stripped:
        raise ValueError("must not be blank")
    return stripped


class NewExerciseRequest(BaseModel):
    name: str
    category: str | None = None

    @field_validator("name")
    @classmethod
    def _name_non_blank(cls, v: str) -> str:
        return _require_non_blank(v)


class ExerciseResponse(BaseModel):
    id: str
    name: str
    category: str | None = None


class WorkoutEntryRequest(BaseModel):
    exerciseName: str
    sets: int = Field(ge=1)
    reps: int = Field(ge=1)
    weightKg: float | None = None
    performedAt: date
    notes: str | None = None

    @field_validator("exerciseName")
    @classmethod
    def _exercise_non_blank(cls, v: str) -> str:
        return _require_non_blank(v)


class WorkoutEntryResponse(BaseModel):
    id: str
    exerciseName: str
    sets: int
    reps: int
    weightKg: float | None = None
    performedAt: date
    notes: str | None = None
