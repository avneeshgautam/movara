"""Social features: profiles and the leaderboard.

The leaderboard is global for now (everyone who has signed in) and ranks by
sets logged this week. Friends-scoping comes later. Only names, photos and a
weekly count are exposed -- never another user's individual entries.
"""

import time
from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .. import db
from ..auth import current_uid
from ..models import LeaderboardEntry, MyProfile, PhotoResponse, ProfileRequest

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
    # Clients send their Google photo on every sign-in; an uploaded photo wins.
    if not profile.photo_custom:
        profile.photo_url = body.photoUrl
    if body.username is not None:
        wanted = body.username[:40].strip() or None
        if wanted is not None:
            # Usernames are unique, case-insensitively, across all profiles.
            clash = session.execute(
                select(db.Profile.user_id)
                .where(func.lower(db.Profile.username) == wanted.lower())
                .where(db.Profile.user_id != uid)
            ).first()
            if clash is not None:
                raise HTTPException(
                    status_code=409, detail="That username is already taken."
                )
        profile.username = wanted
    if body.status is not None:
        profile.status = body.status[:100] or None
    session.commit()


@router.get("/api/profile/username-available", status_code=200)
def username_available(
    u: str,
    uid: str = Depends(current_uid),
    session: Session = Depends(db.get_session),
) -> dict:
    """Whether a username is free (case-insensitive), ignoring the caller's own."""
    wanted = u.strip()
    if not wanted:
        return {"available": True}
    clash = session.execute(
        select(db.Profile.user_id)
        .where(func.lower(db.Profile.username) == wanted.lower())
        .where(db.Profile.user_id != uid)
    ).first()
    return {"available": clash is None}


@router.get("/api/profile/me", response_model=MyProfile)
def my_profile(
    uid: str = Depends(current_uid),
    session: Session = Depends(db.get_session),
) -> MyProfile:
    profile = session.get(db.Profile, uid)
    if profile is None:
        return MyProfile(displayName="", username=None)
    return MyProfile(
        displayName=profile.display_name,
        username=profile.username,
        status=profile.status,
        photoUrl=profile.photo_url,
        photoCustom=profile.photo_custom,
    )


# The client resizes to ~512px JPEG before upload (~50-150 KB); this is a
# generous ceiling that still keeps rows small.
_MAX_PHOTO_BYTES = 2_000_000
_IMAGE_SIGNATURES = {
    b"\xff\xd8\xff": "image/jpeg",
    b"\x89PNG\r\n\x1a\n": "image/png",
}


def _sniff_image(data: bytes) -> str | None:
    """Content type from the file's magic bytes, never the client's claim."""
    for signature, content_type in _IMAGE_SIGNATURES.items():
        if data.startswith(signature):
            return content_type
    return None


def _public_base(request: Request) -> str:
    """This API's public origin. Behind Render's proxy the request itself is
    plain http, so honour the forwarded scheme/host."""
    scheme = request.headers.get("x-forwarded-proto") or request.url.scheme
    host = request.headers.get("x-forwarded-host") or request.headers.get("host")
    return f"{scheme}://{host}"


@router.put("/api/profile/photo", response_model=PhotoResponse)
async def upload_photo(
    request: Request,
    uid: str = Depends(current_uid),
    session: Session = Depends(db.get_session),
) -> PhotoResponse:
    """Store the caller's photo (raw JPEG/PNG body) and point their profile
    at it. The URL carries a version so image caches pick up a new photo."""
    data = await request.body()
    if not data:
        raise HTTPException(status_code=400, detail="No image uploaded.")
    if len(data) > _MAX_PHOTO_BYTES:
        raise HTTPException(status_code=413, detail="Photo is too large (max 2 MB).")
    content_type = _sniff_image(data)
    if content_type is None:
        raise HTTPException(status_code=415, detail="Upload a JPEG or PNG image.")

    photo = session.get(db.ProfilePhoto, uid)
    if photo is None:
        photo = db.ProfilePhoto(user_id=uid)
        session.add(photo)
    photo.data = data
    photo.content_type = content_type
    photo.updated_at = datetime.now(timezone.utc).replace(tzinfo=None)

    profile = session.get(db.Profile, uid)
    if profile is None:
        # The name arrives with the client's next profile upsert.
        profile = db.Profile(user_id=uid, display_name="Athlete")
        session.add(profile)
    profile.photo_url = (
        f"{_public_base(request)}/api/profile/photo/{uid}?v={int(time.time())}"
    )
    profile.photo_custom = True
    session.commit()
    return PhotoResponse(photoUrl=profile.photo_url)


@router.delete("/api/profile/photo", status_code=204)
def remove_photo(
    uid: str = Depends(current_uid),
    session: Session = Depends(db.get_session),
) -> None:
    """Drop the uploaded photo; the client's next upsert restores Google's."""
    photo = session.get(db.ProfilePhoto, uid)
    if photo is not None:
        session.delete(photo)
    profile = session.get(db.Profile, uid)
    if profile is not None and profile.photo_custom:
        profile.photo_custom = False
        profile.photo_url = None
    session.commit()


@router.get("/api/profile/photo/{user_id}")
def get_photo(user_id: str, session: Session = Depends(db.get_session)) -> Response:
    """Public: leaderboard/feed images load without an auth header. Only the
    photo a user chose to upload is served here."""
    photo = session.get(db.ProfilePhoto, user_id)
    if photo is None:
        raise HTTPException(status_code=404, detail="No photo.")
    return Response(
        content=photo.data,
        media_type=photo.content_type,
        # URLs are versioned (?v=), so a new upload is a new URL.
        headers={"Cache-Control": "public, max-age=31536000, immutable"},
    )


def _public_name(profile: "db.Profile", uid: str) -> str:
    """What to show for this profile. A chosen username wins for everyone,
    including the owner, so it shows up on their own feed too. Without one the
    caller sees their full name and others see just a first name."""
    if profile.username:
        return profile.username
    if profile.user_id == uid:
        return profile.display_name
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
        rows.append(
            (p.user_id, _public_name(p, uid), p.photo_url, sets, km, points, p.status)
        )

    # Highest points first; ties broken by name so the order is stable.
    rows.sort(key=lambda r: (-r[5], r[1].lower()))

    return [
        LeaderboardEntry(
            userId=user_id,
            displayName=name,
            photoUrl=photo,
            status=status,
            points=points,
            setsThisWeek=sets,
            kmThisWeek=round(km, 2),
            rank=i + 1,
            isMe=user_id == uid,
        )
        for i, (user_id, name, photo, sets, km, points, status) in enumerate(rows)
    ]
