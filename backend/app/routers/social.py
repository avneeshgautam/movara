"""Social features: profiles and the leaderboard.

The leaderboard is global for now (everyone who has signed in) and ranks by
sets logged this week. Friends-scoping comes later. Only names, photos and a
weekly count are exposed -- never another user's individual entries.
"""

from datetime import date, datetime, timedelta

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .. import db
from ..auth import current_uid
from ..models import LeaderboardEntry, MyProfile, ProfileRequest

# Points: reward a set and a kilometre. Tuned so a typical workout and a short
# run land in a similar range.
_POINTS_PER_SET = 10
_POINTS_PER_KM = 20

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
    if body.username is not None:
        profile.username = body.username[:40] or None
    session.commit()


@router.get("/api/profile/me", response_model=MyProfile)
def my_profile(
    uid: str = Depends(current_uid),
    session: Session = Depends(db.get_session),
) -> MyProfile:
    profile = session.get(db.Profile, uid)
    if profile is None:
        return MyProfile(displayName="", username=None)
    return MyProfile(displayName=profile.display_name, username=profile.username)


def _public_name(profile: "db.Profile", uid: str) -> str:
    """What to show for this profile: the caller sees their own real name;
    everyone else sees the chosen username, or just a first name as a
    privacy-preserving fallback."""
    if profile.user_id == uid:
        return profile.display_name
    if profile.username:
        return profile.username
    return profile.display_name.split(" ")[0] if profile.display_name else "Athlete"


@router.get("/api/leaderboard", response_model=list[LeaderboardEntry])
def leaderboard(
    uid: str = Depends(current_uid),
    session: Session = Depends(db.get_session),
) -> list[LeaderboardEntry]:
    monday = _week_start()
    monday_dt = datetime(monday.year, monday.month, monday.day)

    # Sets logged this week, per user.
    sets_by_user = dict(
        session.execute(
            select(
                db.WorkoutEntry.user_id,
                func.coalesce(func.sum(db.WorkoutEntry.sets), 0),
            )
            .where(db.WorkoutEntry.performed_at >= monday)
            .group_by(db.WorkoutEntry.user_id)
        ).all()
    )

    # Metres run this week, per user.
    metres_by_user = dict(
        session.execute(
            select(
                db.Run.user_id,
                func.coalesce(func.sum(db.Run.distance_meters), 0.0),
            )
            .where(db.Run.started_at >= monday_dt)
            .group_by(db.Run.user_id)
        ).all()
    )

    profiles = session.scalars(select(db.Profile)).all()

    rows = []
    for p in profiles:
        sets = int(sets_by_user.get(p.user_id, 0))
        km = float(metres_by_user.get(p.user_id, 0.0)) / 1000
        points = round(sets * _POINTS_PER_SET + km * _POINTS_PER_KM)
        rows.append((p.user_id, _public_name(p, uid), p.photo_url, sets, km, points))

    # Highest points first; ties broken by name so the order is stable.
    rows.sort(key=lambda r: (-r[5], r[1].lower()))

    return [
        LeaderboardEntry(
            userId=user_id,
            displayName=name,
            photoUrl=photo,
            points=points,
            setsThisWeek=sets,
            kmThisWeek=round(km, 2),
            rank=i + 1,
            isMe=user_id == uid,
        )
        for i, (user_id, name, photo, sets, km, points) in enumerate(rows)
    ]
