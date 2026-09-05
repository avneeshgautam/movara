from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import db
from ..auth import current_uid
from ..models import ExerciseResponse, NewExerciseRequest

router = APIRouter()


def _to_response(row: db.Exercise) -> ExerciseResponse:
    return ExerciseResponse(id=row.id, name=row.name, category=row.category)


@router.get("/api/exercises", response_model=list[ExerciseResponse])
def list_exercises(
    uid: str = Depends(current_uid),
    session: Session = Depends(db.get_session),
) -> list[ExerciseResponse]:
    rows = session.scalars(select(db.Exercise).order_by(db.Exercise.name)).all()
    return [_to_response(r) for r in rows]


@router.post(
    "/api/exercises",
    response_model=ExerciseResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_exercise(
    request: NewExerciseRequest,
    uid: str = Depends(current_uid),
    session: Session = Depends(db.get_session),
) -> ExerciseResponse:
    # An existing name is returned rather than duplicated, and the status is
    # still 201 -- unchanged behaviour from the Mongo version.
    existing = db.find_exercise_by_name(session, request.name)
    if existing:
        return _to_response(existing)

    row = db.Exercise(name=request.name, category=request.category)
    session.add(row)
    session.commit()
    return _to_response(row)
