"""Social features: profiles and the leaderboard.

The leaderboard is global for now (everyone who has signed in) and ranks by
sets logged this week. Friends-scoping comes later. Only names, photos and a
weekly count are exposed -- never another user's individual entries.
"""

from datetime import date, timedelta

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .. import db
from ..auth import current_uid
from ..models import LeaderboardEntry, ProfileRequest

router = APIRouter()


def _week_start(today: date | None = None) -> date:
    today = today or date.today()
    return today - timedelta(days=today.weekday())


@router.put("/api/profile", status_code=204)
def upsert_profile(
    body: ProfileRequest,
    uid: str = Depends(current_uid),
    session: Session = Depends(db.get_session),
) -> None:
    profile = session.get(db.Profile, uid)
    if profile is None:
        profile = db.Profile(user_id=uid)
        session.add(profile)
    profile.display_name = body.displayName.strip()[:120]
    profile.photo_url = body.photoUrl
    session.commit()


@router.get("/api/leaderboard", response_model=list[LeaderboardEntry])
def leaderboard(
    uid: str = Depends(current_uid),
    session: Session = Depends(db.get_session),
) -> list[LeaderboardEntry]:
    monday = _week_start()

    # Sets logged this week, per user.
    totals = dict(
        session.execute(
            select(
                db.WorkoutEntry.user_id,
                func.coalesce(func.sum(db.WorkoutEntry.sets), 0),
            )
            .where(db.WorkoutEntry.performed_at >= monday)
            .group_by(db.WorkoutEntry.user_id)
        ).all()
    )

    profiles = session.scalars(select(db.Profile)).all()

    rows = [
        (p.user_id, p.display_name, p.photo_url, int(totals.get(p.user_id, 0)))
        for p in profiles
    ]
    # Highest first; ties broken by name so the order is stable.
    rows.sort(key=lambda r: (-r[3], r[1].lower()))

    return [
        LeaderboardEntry(
            userId=user_id,
            displayName=name,
            photoUrl=photo,
            setsThisWeek=sets,
            rank=i + 1,
            isMe=user_id == uid,
        )
        for i, (user_id, name, photo, sets) in enumerate(rows)
    ]
