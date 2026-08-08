import datetime
import logging
import os
from typing import Optional

from sqlalchemy.orm import Session

from app.models import NotificationEvent, NotificationStatus, User

logger = logging.getLogger("jansetu.notifications")

_firebase_app = None
_firebase_init_attempted = False


def _get_firebase_app():
    """Lazily initialize the Firebase Admin app. Returns None (never raises)
    if credentials aren't configured or the firebase-admin package isn't installed."""
    global _firebase_app, _firebase_init_attempted
    if _firebase_init_attempted:
        return _firebase_app
    _firebase_init_attempted = True

    credentials_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
    if not credentials_path or not os.path.exists(credentials_path):
        logger.info("FIREBASE_CREDENTIALS_PATH not set or file missing; push notifications will be skipped.")
        return None

    try:
        import firebase_admin
        from firebase_admin import credentials

        cred = credentials.Certificate(credentials_path)
        _firebase_app = firebase_admin.initialize_app(cred)
    except ImportError:
        logger.info("firebase-admin package not installed; push notifications will be skipped.")
    except Exception as exc:
        logger.warning(f"Firebase initialization failed, push notifications will be skipped: {exc}")

    return _firebase_app


def notify_user(
    db: Session,
    user: Optional[User],
    title: str,
    message: str,
    report_id: Optional[int] = None,
) -> NotificationEvent:
    """Create a notification_events audit row and attempt an FCM push if configured.
    Never raises - always returns the (possibly skipped/failed) NotificationEvent."""
    event = NotificationEvent(
        user_id=user.id if user else None,
        report_id=report_id,
        title=title,
        message=message,
        status=NotificationStatus.PENDING,
    )
    db.add(event)
    db.commit()
    db.refresh(event)

    if not user or not user.fcm_token:
        event.status = NotificationStatus.SKIPPED
        event.error_message = "No FCM token registered for user"
        db.commit()
        db.refresh(event)
        return event

    app = _get_firebase_app()
    if app is None:
        event.status = NotificationStatus.SKIPPED
        event.error_message = "Firebase not configured"
        db.commit()
        db.refresh(event)
        return event

    try:
        from firebase_admin import messaging

        fcm_message = messaging.Message(
            notification=messaging.Notification(title=title, body=message),
            token=user.fcm_token,
            data={"report_id": str(report_id)} if report_id is not None else {},
        )
        messaging.send(fcm_message, app=app)
        event.status = NotificationStatus.SENT
        event.sent_at = datetime.datetime.utcnow()
    except Exception as exc:
        event.status = NotificationStatus.FAILED
        event.error_message = str(exc)[:500]
        logger.warning(f"FCM send failed for user {user.id}: {exc}")

    db.commit()
    db.refresh(event)
    return event
