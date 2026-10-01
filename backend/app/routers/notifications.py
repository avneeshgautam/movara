"""Messages sent from the local admin dashboard to one user or everyone.

The app registers its FCM device token here, which the admin backend reads
when sending a notification so the message can be pushed immediately to the
device (lock screen, popup) rather than waiting for the app to poll.
"""

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from .. import db
from ..auth import current_uid
from ..models import NotificationResponse

router = APIRouter()

# First fetch on a device (no `since`): show only recent broadcasts, not the
# entire history.
_FIRST_FETCH_WINDOW = timedelta(days=3)


class FcmTokenRequest(BaseModel):
    token: str


@router.patch("/api/notifications/fcm-token", status_code=204)
def register_fcm_token(
    body: FcmTokenRequest,
    uid: str = Depends(current_uid),
    session: Session = Depends(db.get_session),
) -> None:
    """Store (or refresh) the calling device's FCM token so the backend can
    push lock-screen / banner notifications without waiting for the app to
    poll."""
    profile = session.get(db.Profile, uid)
    if profile is None:
        # Profile arrives with the next upsert; create a stub so the token
        # isn't lost if the app sends it before the profile upsert completes.
        profile = db.Profile(user_id=uid, display_name="")
        session.add(profile)
    profile.fcm_token = body.token[:512]
    session.commit()


@router.get("/api/notifications", response_model=list[NotificationResponse])
def my_notifications(
    since: datetime | None = None,
    uid: str = Depends(current_uid),
    session: Session = Depends(db.get_session),
) -> list[NotificationResponse]:
    """Messages for this user or everyone, newer than `since`, oldest first."""
    if since is None:
        since = datetime.now(timezone.utc) - _FIRST_FETCH_WINDOW
    if since.tzinfo is not None:  # stored naive UTC
        since = since.astimezone(timezone.utc).replace(tzinfo=None)
    rows = session.scalars(
        select(db.Notification)
        .where(or_(db.Notification.user_id == uid, db.Notification.user_id.is_(None)))
        .where(db.Notification.created_at > since)
        .order_by(db.Notification.created_at)
        .limit(50)
    ).all()
    return [
        NotificationResponse(
            id=n.id, title=n.title, body=n.body, createdAt=n.created_at
        )
        for n in rows
    ]
