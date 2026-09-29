"""Dev/demo-only: seeds sample Swachh (waste & sanitation) data so the admin
dashboard's Swachh Insights tab has something to show during a demo.

Creates, backdated over the last two weeks:
  - waste & sanitation tickets clustered around a few recurring dumping spots
    (so garbage hotspot detection has real clusters to find), and
  - door-to-door collection visits across three wards with a mix of
    segregated / partial / mixed households.

Everything it creates is tagged so it can be removed again without touching
real data: ticket descriptions start with "[Demo]" and household IDs start
with "DEMO-".

Usage (from the backend/ directory, with the venv active):
    python -m scripts.seed_swachh_demo           # add demo data
    python -m scripts.seed_swachh_demo --clear   # remove only the demo data
"""

import argparse
import datetime
import random

from app.database import SessionLocal
from app.models import (
    CategoryType,
    CollectionLog,
    Officer,
    Report,
    ReportStatus,
    ResolutionRecord,
    SegregationStatus,
    User,
)
from app.services import calculate_priority_score, calculate_sla_deadline
from app.services.demo_accounts import DEMO_CITIZEN_PHONE, DEMO_WORKER_ID, ensure_demo_accounts
from app.services.routing import find_department_for_category

DEMO_PREFIX = "[Demo]"
HOUSEHOLD_PREFIX = "DEMO-"
PHOTO_URL = "https://images.unsplash.com/photo-1530587191325-3db32d826c18"

# (label, lat, lng, how many tickets to drop around it)
HOTSPOTS = [
    ("Yelahanka market back lane", 13.1007, 77.5963, 6),
    ("Rajanakunte bus stop", 13.1645, 77.5696, 4),
    ("Jakkur lake road", 13.0786, 77.6064, 3),
]

SCATTERED = [
    (13.0901, 77.5812, CategoryType.MISSED_PICKUP, "Collection vehicle did not come for two days."),
    (13.1122, 77.5741, CategoryType.PUBLIC_TOILET, "Public toilet has no water and is very dirty."),
    (13.0953, 77.6110, CategoryType.WASTE_BURNING, "Plastic waste being burnt on the roadside."),
    (13.1204, 77.5902, CategoryType.UNSEGREGATED_WASTE, "Apartment handing over mixed waste every day."),
]

HOTSPOT_CATEGORIES = [
    CategoryType.ILLEGAL_DUMPING,
    CategoryType.GARBAGE,
    CategoryType.GARBAGE,
    CategoryType.WASTE_BURNING,
]

WARDS = {
    "Ward 1 - Yelahanka": [0.55, 0.25, 0.15, 0.05],
    "Ward 4 - Jakkur": [0.75, 0.15, 0.07, 0.03],
    "Ward 9 - Rajanakunte": [0.35, 0.25, 0.35, 0.05],
}
STATUS_ORDER = [
    SegregationStatus.SEGREGATED,
    SegregationStatus.PARTIAL,
    SegregationStatus.MIXED,
    SegregationStatus.NOT_AVAILABLE,
]


def _add_report(db, rng, now, lat, lng, category, description, officer, user_id=None):
    created_at = now - datetime.timedelta(days=rng.uniform(0.5, 14), hours=rng.uniform(0, 12))
    department = find_department_for_category(db, category)
    report = Report(
        photo_url=PHOTO_URL,
        latitude=lat,
        longitude=lng,
        category=category,
        description=f"{DEMO_PREFIX} {description}",
        status=ReportStatus.ASSIGNED if department else ReportStatus.SUBMITTED,
        priority_score=calculate_priority_score(category=category, upvote_count=1),
        assigned_department_id=department.id if department else None,
        created_at=created_at,
        sla_deadline=calculate_sla_deadline(category, created_at=created_at),
        upvote_count=1,
        user_id=user_id,
    )

    # Roughly half the older tickets get resolved (some within SLA, some
    # late) so the clearance-time / within-SLA KPIs aren't empty.
    if created_at < now - datetime.timedelta(days=2) and rng.random() < 0.55:
        resolved_at = created_at + datetime.timedelta(hours=rng.uniform(6, 60))
        report.status = ReportStatus.RESOLVED
        report.resolved_at = resolved_at
        report.citizen_verified = rng.random() < 0.7
        report.assigned_officer_id = officer.id if officer else None
        db.add(report)
        db.flush()
        db.add(ResolutionRecord(
            report_id=report.id,
            officer_id=officer.id if officer else None,
            before_photo_url=PHOTO_URL,
            after_photo_url=PHOTO_URL,
            latitude=lat,
            longitude=lng,
            cv_similarity_score=0.9,
            captured_at=resolved_at,
            resolved_at=resolved_at,
            verified=True,
        ))
    else:
        db.add(report)
    return report


def seed(db) -> None:
    rng = random.Random(2026)
    now = datetime.datetime.utcnow()
    # Attribute the demo work to the portal's demo accounts, so the one-click
    # Citizen and Worker logins have tickets to show.
    ensure_demo_accounts(db)
    demo_worker = db.query(Officer).filter(Officer.emp_id == DEMO_WORKER_ID, Officer.is_active == True).first()
    demo_citizen = db.query(User).filter(User.phone == DEMO_CITIZEN_PHONE).first()
    waste_department = find_department_for_category(db, CategoryType.GARBAGE)
    officer = demo_worker
    if officer is None and waste_department:
        officer = (
            db.query(Officer)
            .filter(Officer.department_id == waste_department.id, Officer.is_active == True)
            .first()
        )

    report_count = 0
    hotspot_reports = []
    for label, lat, lng, count in HOTSPOTS:
        for _ in range(count):
            category = rng.choice(HOTSPOT_CATEGORIES)
            jitter_lat = lat + rng.uniform(-0.0006, 0.0006)  # within ~70 m
            jitter_lng = lng + rng.uniform(-0.0006, 0.0006)
            hotspot_reports.append(_add_report(db, rng, now, jitter_lat, jitter_lng, category,
                                               f"Waste piling up again near {label}.", officer))
            report_count += 1
    citizen_reports = []
    for lat, lng, category, description in SCATTERED:
        citizen_reports.append(_add_report(
            db, rng, now, lat, lng, category, description, officer,
            user_id=demo_citizen.id if demo_citizen else None,
        ))
        report_count += 1

    # Give the demo worker live work: one ticket to start, one in progress.
    db.flush()
    if demo_worker:
        open_reports = [
            report for report in citizen_reports + hotspot_reports if report.status == ReportStatus.ASSIGNED
        ]
        for report, status in zip(open_reports, (ReportStatus.ASSIGNED, ReportStatus.IN_PROGRESS)):
            report.assigned_officer_id = demo_worker.id
            report.status = status
            report.estimated_completion_at = now + datetime.timedelta(hours=24)

    log_count = 0
    for ward_index, (ward, weights) in enumerate(WARDS.items(), start=1):
        for house in range(1, 16):
            household_code = f"{HOUSEHOLD_PREFIX}W{ward_index}-H{house:03d}"
            for visit_day in range(0, 14, 2):
                status = rng.choices(STATUS_ORDER, weights=weights)[0]
                db.add(CollectionLog(
                    household_code=household_code,
                    ward=ward,
                    status=status,
                    officer_id=officer.id if officer else None,
                    created_at=now - datetime.timedelta(days=visit_day, hours=rng.uniform(0, 5)),
                ))
                log_count += 1

    db.commit()
    print(f"Seeded {report_count} demo waste/sanitation tickets and {log_count} collection visits.")


def clear(db) -> None:
    demo_report_ids = [
        report_id
        for (report_id,) in db.query(Report.id).filter(Report.description.like(f"{DEMO_PREFIX}%")).all()
    ]
    resolutions = 0
    if demo_report_ids:
        resolutions = (
            db.query(ResolutionRecord)
            .filter(ResolutionRecord.report_id.in_(demo_report_ids))
            .delete(synchronize_session=False)
        )
        db.query(Report).filter(Report.id.in_(demo_report_ids)).delete(synchronize_session=False)
    logs = (
        db.query(CollectionLog)
        .filter(CollectionLog.household_code.like(f"{HOUSEHOLD_PREFIX}%"))
        .delete(synchronize_session=False)
    )
    db.commit()
    print(f"Removed {len(demo_report_ids)} demo tickets, {resolutions} resolution records and {logs} collection visits.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Seed or clear JanSetu-Swachh demo data.")
    parser.add_argument("--clear", action="store_true", help="Remove previously seeded demo data only.")
    args = parser.parse_args()

    session = SessionLocal()
    try:
        if args.clear:
            clear(session)
        else:
            seed(session)
    finally:
        session.close()
