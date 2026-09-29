"""Dev-only cleanup: wipes transactional/demo data so the citizen -> admin ->
worker -> notification flow can be tested from a clean slate.

Deletes (in FK-safe order): resolution records, escalation logs, notification
events, reports, door-to-door collection logs, and officers. By default only officers whose emp_id starts
with "TEST" are removed (case insensitive - leftovers from automated/manual
test runs). Pass --all-officers to wipe every officer/admin/worker AND every
citizen user (phone numbers, FCM tokens) for a completely fresh start
(0 tickets, 0 workers, 0 admins, 0 citizens).

Also resets the reports/resolution_records/escalation_logs/notification_events
ID sequences back to 1, so the next ticket created after a reset is JAN-000001
instead of continuing from wherever the counter was left off.

Never touches departments and never drops any table.

Usage (from the backend/ directory, with the venv active):
    python -m scripts.reset_demo_data
    python -m scripts.reset_demo_data --all-officers
"""

import argparse

from sqlalchemy import text

from app.database import SessionLocal
from app.models import CollectionLog, EscalationLog, NotificationEvent, Officer, Report, ResolutionRecord, User

# Postgres-only: SQLite (the no-Postgres dev fallback) doesn't have named
# sequences, so this is skipped there - see _reset_id_sequences below.
_ID_SEQUENCES = [
    "reports_id_seq",
    "resolution_records_id_seq",
    "escalation_logs_id_seq",
    "notification_events_id_seq",
    "collection_logs_id_seq",
]


def _reset_id_sequences(db) -> None:
    if db.bind.dialect.name != "postgresql":
        return
    for sequence in _ID_SEQUENCES:
        db.execute(text(f"ALTER SEQUENCE {sequence} RESTART WITH 1"))


def reset_demo_data(delete_all_officers: bool = False) -> None:
    db = SessionLocal()
    try:
        resolution_count = db.query(ResolutionRecord).delete(synchronize_session=False)
        escalation_count = db.query(EscalationLog).delete(synchronize_session=False)
        notification_count = db.query(NotificationEvent).delete(synchronize_session=False)
        report_count = db.query(Report).delete(synchronize_session=False)
        collection_count = db.query(CollectionLog).delete(synchronize_session=False)

        if delete_all_officers:
            officer_count = db.query(Officer).delete(synchronize_session=False)
            user_count = db.query(User).delete(synchronize_session=False)
        else:
            officer_count = (
                db.query(Officer)
                .filter(Officer.emp_id.ilike("TEST%"))
                .delete(synchronize_session=False)
            )
            user_count = None

        _reset_id_sequences(db)
        db.commit()

        print("JanSetu demo data reset complete:")
        print(f"  resolution_records deleted: {resolution_count}")
        print(f"  escalation_logs deleted:    {escalation_count}")
        print(f"  notification_events deleted: {notification_count}")
        print(f"  reports deleted:            {report_count}")
        print(f"  collection_logs deleted:    {collection_count}")
        print("  ticket ID counter reset to: 1")
        if delete_all_officers:
            print(f"  ALL officers/admins/workers deleted: {officer_count}")
            print(f"  ALL citizen users deleted: {user_count}")
        else:
            print(f"  TEST* officers deleted:     {officer_count}")
        print("  departments: untouched")
    finally:
        db.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Reset JanSetu demo/transactional data.")
    parser.add_argument(
        "--all-officers",
        action="store_true",
        help="Delete every officer/admin/worker and every citizen user, not just TEST* officers. Use for a full fresh start.",
    )
    args = parser.parse_args()
    reset_demo_data(delete_all_officers=args.all_officers)
