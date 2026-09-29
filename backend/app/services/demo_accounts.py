"""Demo accounts for the one-click logins on the web portal.

The portal login pre-fills these credentials (dashboard/src/portal/
demoAccounts.js - keep the two in sync) so evaluators can try every role
without registering. Created idempotently on startup; set
JANSETU_DEMO_ACCOUNTS=0 to turn this off for a real deployment.

Citizens need no seeded account: any phone number logs in with OTP 123456
and is created on first login.
"""

import hashlib
import os

from app.models import CategoryType, Officer, User, UserRole
from app.services.routing import find_department_for_category

DEMO_PASSWORD = "Demo@123"
DEMO_ADMIN_ID = "DEMO-ADMIN"
DEMO_WORKER_ID = "DEMO-WORKER"
DEMO_CITIZEN_PHONE = "9876543210"


def _hash(password: str) -> str:
    # Same scheme as app.api.admin._hash_password.
    return hashlib.sha256(password.encode("utf-8")).hexdigest()


def demo_accounts_enabled() -> bool:
    return os.getenv("JANSETU_DEMO_ACCOUNTS", "1") != "0"


def ensure_demo_accounts(db) -> None:
    if not demo_accounts_enabled():
        return
    try:
        _ensure_demo_accounts(db)
    except Exception as exc:
        # Never let demo-account setup stop the API from starting.
        db.rollback()
        print(f"Demo accounts not created: {exc}")


def _ensure_demo_accounts(db) -> None:
    sanitation = find_department_for_category(db, CategoryType.GARBAGE)
    wanted = [
        (DEMO_ADMIN_ID, "Demo Admin", None),
        (DEMO_WORKER_ID, "Demo Sanitation Worker", sanitation.id if sanitation else None),
    ]
    for emp_id, name, department_id in wanted:
        officer = db.query(Officer).filter(Officer.emp_id == emp_id).first()
        if officer is None:
            db.add(Officer(
                name=name,
                emp_id=emp_id,
                department_id=department_id,
                password_hash=_hash(DEMO_PASSWORD),
                is_available=True,
                is_department_head=False,
                is_active=True,
            ))
        else:
            # Keep the demo logins working even if someone changed/removed them.
            officer.password_hash = _hash(DEMO_PASSWORD)
            officer.is_active = True
            officer.department_id = department_id

    if db.query(User).filter(User.phone == DEMO_CITIZEN_PHONE).first() is None:
        db.add(User(phone=DEMO_CITIZEN_PHONE, role=UserRole.CITIZEN))
    db.commit()
