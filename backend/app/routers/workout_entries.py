from datetime import date

from bson import ObjectId
from bson.errors import InvalidId
from fastapi import APIRouter, HTTPException, Query, Response, status
from pymongo import DESCENDING

from .. import db
from ..models import WorkoutEntryRequest, WorkoutEntryResponse
from .exercises import find_by_name_ignore_case

router = APIRouter()

# Newest first: same ordering as the Java repository's
# findAllByOrderByPerformedAtDescIdDesc.
_SORT = [("performedAt", DESCENDING), ("_id", DESCENDING)]


def _to_response(doc: dict) -> WorkoutEntryResponse:
    return WorkoutEntryResponse(
        id=str(doc["_id"]),
        exerciseName=doc["exerciseName"],
        sets=doc["sets"],
        reps=doc["reps"],
        weightKg=doc.get("weightKg"),
        performedAt=db.from_bson_date(doc["performedAt"]),
        notes=doc.get("notes"),
    )


@router.get("/api/workout-entries", response_model=list[WorkoutEntryResponse])
def list_entries(
    date_filter: date | None = Query(default=None, alias="date"),
) -> list[WorkoutEntryResponse]:
    """Optionally filter with ?date=2026-09-01, otherwise everything, newest first."""
    query: dict = {}
    if date_filter is not None:
        query["performedAt"] = db.to_bson_date(date_filter)

    return [_to_response(d) for d in db.workout_entries.find(query).sort(_SORT)]


@router.post(
    "/api/workout-entries",
    response_model=WorkoutEntryResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_entry(request: WorkoutEntryRequest) -> WorkoutEntryResponse:
    # Keep the exercises collection populated for the autocomplete list, but
    # store the name directly on the entry (denormalized) -- MongoDB has no
    # SQL-style joins, and this matches the existing documents.
    existing = find_by_name_ignore_case(request.exerciseName)
    if existing:
        exercise_name = existing["name"]
    else:
        exercise_name = request.exerciseName
        db.exercises.insert_one({"name": exercise_name, "category": None})

    doc = {
        "exerciseName": exercise_name,
        "sets": request.sets,
        "reps": request.reps,
        "weightKg": request.weightKg,
        "performedAt": db.to_bson_date(request.performedAt),
        "notes": request.notes,
    }
    result = db.workout_entries.insert_one(doc)
    return _to_response({**doc, "_id": result.inserted_id})


@router.delete("/api/workout-entries/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_entry(entry_id: str) -> Response:
    try:
        object_id = ObjectId(entry_id)
    except (InvalidId, TypeError):
        raise HTTPException(status_code=404, detail="Not found") from None

    # Deleting a missing id is a no-op, as it was in the Java version.
    db.workout_entries.delete_one({"_id": object_id})
    return Response(status_code=status.HTTP_204_NO_CONTENT)
