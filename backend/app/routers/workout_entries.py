from datetime import date

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from .. import db
from ..auth import current_uid
from ..models import WorkoutEntryRequest, WorkoutEntryResponse

router = APIRouter()


def _to_response(row: db.WorkoutEntry) -> WorkoutEntryResponse:
    return WorkoutEntryResponse(
        id=row.id,
        exerciseName=row.exercise_name,
        sets=row.sets,
        reps=row.reps,
        weightKg=row.weight_kg,
        performedAt=row.performed_at,
        notes=row.notes,
    )


@router.get("/api/workout-entries", response_model=list[WorkoutEntryResponse])
def list_entries(
    uid: str = Depends(current_uid),
    date_filter: date | None = Query(default=None, alias="date"),
    session: Session = Depends(db.get_session),
) -> list[WorkoutEntryResponse]:
    """The caller's own entries, newest first. Optional ?date=2026-09-01."""
    statement = select(db.WorkoutEntry).where(db.WorkoutEntry.user_id == uid)
    if date_filter is not None:
        statement = statement.where(db.WorkoutEntry.performed_at == date_filter)

    statement = statement.order_by(
        db.WorkoutEntry.performed_at.desc(), db.WorkoutEntry.id.desc()
    )
    return [_to_response(r) for r in session.scalars(statement).all()]


@router.post(
    "/api/workout-entries",
    response_model=WorkoutEntryResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_entry(
    request: WorkoutEntryRequest,
    uid: str = Depends(current_uid),
    session: Session = Depends(db.get_session),
) -> WorkoutEntryResponse:
    # Keep the shared catalogue populated for autocomplete, and store the
    # canonical name on the entry.
    existing = db.find_exercise_by_name(session, request.exerciseName)
    if existing:
        exercise_name = existing.name
    else:
        exercise_name = request.exerciseName
        session.add(db.Exercise(name=exercise_name, category=None))

    row = db.WorkoutEntry(
        user_id=uid,
        exercise_name=exercise_name,
        sets=request.sets,
        reps=request.reps,
        weight_kg=request.weightKg,
        performed_at=request.performedAt,
        notes=request.notes,
    )
    session.add(row)
    session.commit()
    return _to_response(row)


@router.delete("/api/workout-entries/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_entry(
    entry_id: str,
    uid: str = Depends(current_uid),
    session: Session = Depends(db.get_session),
) -> Response:
    # Scoped by user_id so one account cannot delete another's entry.
    # Deleting a missing id stays a silent no-op, as before.
    session.execute(
        delete(db.WorkoutEntry).where(
            db.WorkoutEntry.id == entry_id,
            db.WorkoutEntry.user_id == uid,
        )
    )
    session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
