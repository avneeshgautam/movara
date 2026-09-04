from datetime import date

from bson import ObjectId
from bson.errors import InvalidId
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from pymongo import DESCENDING

from .. import db
from ..auth import current_uid
from ..models import WorkoutEntryRequest, WorkoutEntryResponse
from .exercises import find_by_name_ignore_case

router = APIRouter()

# Newest first: same ordering the Java repository used.
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
    uid: str = Depends(current_uid),
    date_filter: date | None = Query(default=None, alias="date"),
) -> list[WorkoutEntryResponse]:
    """The caller's own entries, newest first. Optional ?date=2026-09-01."""
    query: dict = {"userId": uid}
    if date_filter is not None:
        query["performedAt"] = db.to_bson_date(date_filter)

    return [_to_response(d) for d in db.workout_entries.find(query).sort(_SORT)]


@router.post(
    "/api/workout-entries",
    response_model=WorkoutEntryResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_entry(
    request: WorkoutEntryRequest,
    uid: str = Depends(current_uid),
) -> WorkoutEntryResponse:
    # The exercises collection is a shared catalogue backing autocomplete; the
    # entry itself is owned by the caller.
    existing = find_by_name_ignore_case(request.exerciseName)
    if existing:
        exercise_name = existing["name"]
    else:
        exercise_name = request.exerciseName
        db.exercises.insert_one({"name": exercise_name, "category": None})

    doc = {
        "userId": uid,
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
def delete_entry(entry_id: str, uid: str = Depends(current_uid)) -> Response:
    try:
        object_id = ObjectId(entry_id)
    except (InvalidId, TypeError):
        raise HTTPException(status_code=404, detail="Not found") from None

    # Scoped by userId so one account cannot delete another's entry.
    db.workout_entries.delete_one({"_id": object_id, "userId": uid})
    return Response(status_code=status.HTTP_204_NO_CONTENT)
