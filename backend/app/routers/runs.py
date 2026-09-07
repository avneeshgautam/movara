"""Run sync. The device uploads run summaries so they can score on the
leaderboard (and, later, follow the user across devices)."""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from .. import db
from ..auth import current_uid
from ..models import RunUpload

router = APIRouter()


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
