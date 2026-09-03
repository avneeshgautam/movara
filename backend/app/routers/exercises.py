import re

from fastapi import APIRouter, status

from .. import db
from ..models import ExerciseResponse, NewExerciseRequest

router = APIRouter()


def _to_response(doc: dict) -> ExerciseResponse:
    return ExerciseResponse(
        id=str(doc["_id"]),
        name=doc["name"],
        category=doc.get("category"),
    )


def find_by_name_ignore_case(name: str) -> dict | None:
    """Case-insensitive exact match, as Spring's findByNameIgnoreCase did."""
    return db.exercises.find_one(
        {"name": {"$regex": f"^{re.escape(name)}$", "$options": "i"}}
    )


@router.get("/api/exercises", response_model=list[ExerciseResponse])
def list_exercises() -> list[ExerciseResponse]:
    return [_to_response(d) for d in db.exercises.find()]


@router.post(
    "/api/exercises",
    response_model=ExerciseResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_exercise(request: NewExerciseRequest) -> ExerciseResponse:
    # Matches the Java behaviour: an existing name is returned rather than
    # duplicated, and the status is still 201.
    existing = find_by_name_ignore_case(request.name)
    if existing:
        return _to_response(existing)

    doc = {"name": request.name, "category": request.category}
    result = db.exercises.insert_one(doc)
    return _to_response({**doc, "_id": result.inserted_id})
