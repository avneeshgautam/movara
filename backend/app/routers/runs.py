"""Run sync. The device uploads run summaries so they can score on the
leaderboard (and, later, follow the user across devices)."""

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import db
from ..auth import current_uid
from ..models import RunUpload

router = APIRouter()


@router.get("/api/runs")
def list_runs(
    uid: str = Depends(current_uid),
    session: Session = Depends(db.get_session),
) -> list[dict]:
    """The signed-in user's synced runs (newest first) so history can be
    restored on a fresh install. Route points are not stored server-side."""
    rows = (
        session.execute(
            select(db.Run)
            .where(db.Run.user_id == uid)
            .order_by(db.Run.started_at.desc())
        )
        .scalars()
        .all()
    )
    return [
        {
            "id": r.id,
            "startedAt": r.started_at.isoformat(),
            "elapsedSeconds": r.elapsed_seconds,
            "distanceMeters": r.distance_meters,
        }
        for r in rows
    ]


@router.post("/api/runs", status_code=204)
def upload_run(
    body: RunUpload,
    uid: str = Depends(current_uid),
    session: Session = Depends(db.get_session),
) -> None:
    # Upsert by the client-generated id, so re-syncing the same run is safe.
    run = session.get(db.Run, body.id)
    if run is None:
        run = db.Run(id=body.id, user_id=uid)
        session.add(run)
    elif run.user_id != uid:
        # Never let one user overwrite another's run.
        return
    run.started_at = body.startedAt.replace(tzinfo=None)
    run.elapsed_seconds = body.elapsedSeconds
    run.distance_meters = body.distanceMeters
    session.commit()
