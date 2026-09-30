"""Messages sent from the local admin dashboard to one user or everyone.

The app polls this on launch and resume (no push infrastructure yet), then
shows anything new as a notification and an in-app card.
"""

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from .. import db
from ..auth import current_uid
from ..models import NotificationResponse

router = APIRouter()

# First fetch on a device (no `since`): show only recent broadcasts, not the
# entire history.
_FIRST_FETCH_WINDOW = timedelta(days=3)


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
