"""JanSetu-Swachh: waste segregation, disposal and sanitation endpoints.

- Waste segregation guide + optional AI "Which bin?" item scan (citizen app)
- Door-to-door collection logs with household segregation status (worker app)
- Segregation compliance, garbage hotspots and sanitation KPIs (admin dashboard)
- Citizen Swachh points (citizen app)
"""

import datetime
import os
import uuid
from collections import Counter, defaultdict
from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool

from app.database import get_db
from app.ml.waste_item_classifier import WasteItemClassifier
from app.models import (
    SWACHH_CATEGORIES,
    CollectionLog,
    Officer,
    Report,
    ReportStatus,
    SegregationStatus,
    User,
)
from app.schemas import CollectionLogCreate, CollectionLogRead
from app.services.dedup import haversine_distance_meters
from app.services.waste_guide import waste_guide_payload

router = APIRouter(prefix="/swachh", tags=["Swachh - Waste & Sanitation"])

waste_item_classifier = WasteItemClassifier()

CLOSED_STATUSES = (ReportStatus.RESOLVED, ReportStatus.CANCELLED, ReportStatus.DUPLICATE)


def _utcnow() -> datetime.datetime:
    return datetime.datetime.utcnow()


# ---------------------------------------------------------------------------
# Segregation guide
# ---------------------------------------------------------------------------

@router.get("/waste-guide")
def waste_guide():
    return waste_guide_payload()


@router.post("/classify-item")
async def classify_waste_item(file: UploadFile = File(...)):
    temp_dir = "temp_uploads"
    os.makedirs(temp_dir, exist_ok=True)
    temp_path = os.path.join(temp_dir, f"{uuid.uuid4()}_{os.path.basename(file.filename or 'item.jpg')}")
    try:
        with open(temp_path, "wb") as handle:
            handle.write(await file.read())
        return await run_in_threadpool(waste_item_classifier.classify, temp_path)
    finally:
        if os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except OSError:
                pass


# ---------------------------------------------------------------------------
# Door-to-door collection logs
# ---------------------------------------------------------------------------

@router.post("/collections", response_model=CollectionLogRead, status_code=201)
def log_collection(payload: CollectionLogCreate, db: Session = Depends(get_db)):
    household_code = payload.household_code.strip().upper()
    ward = payload.ward.strip()
    if not household_code or not ward:
        raise HTTPException(status_code=400, detail="Household ID and ward are required")

    if payload.officer_id is not None:
        officer = db.query(Officer).filter(Officer.id == payload.officer_id, Officer.is_active == True).first()
        if not officer:
            raise HTTPException(status_code=404, detail="Employee not found")

    log = CollectionLog(
        household_code=household_code,
        ward=ward,
        status=payload.status,
        note=(payload.note or "").strip() or None,
        latitude=payload.latitude,
        longitude=payload.longitude,
        officer_id=payload.officer_id,
    )
    db.add(log)
    db.commit()
    db.refresh(log)
    return log


@router.get("/collections", response_model=list[CollectionLogRead])
def list_collections(
    officer_id: Optional[int] = None,
    ward: Optional[str] = None,
    household_code: Optional[str] = None,
    limit: int = Query(50, ge=1, le=500),
    db: Session = Depends(get_db),
):
    query = db.query(CollectionLog)
    if officer_id is not None:
        query = query.filter(CollectionLog.officer_id == officer_id)
    if ward:
        query = query.filter(CollectionLog.ward == ward.strip())
    if household_code:
        query = query.filter(CollectionLog.household_code == household_code.strip().upper())
    return query.order_by(CollectionLog.created_at.desc(), CollectionLog.id.desc()).limit(limit).all()


def _compliance(counts: Counter) -> dict:
    """Segregation rate is measured only over households that actually handed
    over waste - 'no waste' and 'not available' visits don't count against it."""
    segregated = counts[SegregationStatus.SEGREGATED]
    partial = counts[SegregationStatus.PARTIAL]
    mixed = counts[SegregationStatus.MIXED]
    handed_over = segregated + partial + mixed
    return {
        "visits": sum(counts.values()),
        "segregated": segregated,
        "partial": partial,
        "mixed": mixed,
        "no_waste": counts[SegregationStatus.NO_WASTE],
        "not_available": counts[SegregationStatus.NOT_AVAILABLE],
        "segregation_rate": round(100.0 * segregated / handed_over, 1) if handed_over else None,
    }


@router.get("/segregation-stats")
def segregation_stats(days: int = Query(30, ge=1, le=365), db: Session = Depends(get_db)):
    since = _utcnow() - datetime.timedelta(days=days)
    logs = db.query(CollectionLog).filter(CollectionLog.created_at >= since).all()

    overall = Counter(log.status for log in logs)
    by_ward: dict[str, Counter] = defaultdict(Counter)
    households_by_ward: dict[str, set] = defaultdict(set)
    mixed_by_household: dict[tuple[str, str], list[CollectionLog]] = defaultdict(list)
    for log in logs:
        by_ward[log.ward][log.status] += 1
        households_by_ward[log.ward].add(log.household_code)
        if log.status == SegregationStatus.MIXED:
            mixed_by_household[(log.household_code, log.ward)].append(log)

    wards = []
    for ward, counts in by_ward.items():
        wards.append({"ward": ward, "households": len(households_by_ward[ward]), **_compliance(counts)})
    wards.sort(key=lambda item: (item["segregation_rate"] is None, item["segregation_rate"] or 0))

    repeat_offenders = [
        {
            "household_code": household_code,
            "ward": ward,
            "mixed_count": len(visits),
            "last_visit": max(visit.created_at for visit in visits),
        }
        for (household_code, ward), visits in mixed_by_household.items()
        if len(visits) >= 2
    ]
    repeat_offenders.sort(key=lambda item: (-item["mixed_count"], item["household_code"]))

    return {
        "days": days,
        "households": len({(log.household_code, log.ward) for log in logs}),
        **_compliance(overall),
        "wards": wards,
        "repeat_offenders": repeat_offenders[:20],
    }


# ---------------------------------------------------------------------------
# Garbage hotspots & sanitation KPIs
# ---------------------------------------------------------------------------

def _swachh_reports(db: Session, since: datetime.datetime):
    return (
        db.query(Report)
        .filter(
            Report.category.in_(SWACHH_CATEGORIES),
            Report.created_at >= since,
            Report.status != ReportStatus.CANCELLED,
        )
        .order_by(Report.created_at.asc())
        .all()
    )


@router.get("/hotspots")
def garbage_hotspots(
    days: int = Query(30, ge=1, le=365),
    radius_m: float = Query(150.0, ge=20, le=2000),
    min_reports: int = Query(2, ge=1, le=50),
    db: Session = Depends(get_db),
):
    """Clusters waste & sanitation reports that keep recurring at the same
    spot (Garbage Vulnerable Points), so wards can plan preventive cleanups
    instead of only reacting to each complaint."""
    reports = _swachh_reports(db, _utcnow() - datetime.timedelta(days=days))

    clusters: list[dict] = []
    for report in reports:
        target = None
        for cluster in clusters:
            if haversine_distance_meters(cluster["lat"], cluster["lng"], report.latitude, report.longitude) <= radius_m:
                target = cluster
                break
        if target is None:
            target = {"lat": report.latitude, "lng": report.longitude, "reports": []}
            clusters.append(target)
        target["reports"].append(report)
        count = len(target["reports"])
        target["lat"] += (report.latitude - target["lat"]) / count
        target["lng"] += (report.longitude - target["lng"]) / count

    hotspots = []
    for cluster in clusters:
        members = cluster["reports"]
        if len(members) < min_reports:
            continue
        open_count = sum(1 for report in members if report.status not in CLOSED_STATUSES)
        risk = "high" if len(members) >= 5 or open_count >= 3 else "medium" if len(members) >= 3 else "low"
        hotspots.append({
            "latitude": round(cluster["lat"], 6),
            "longitude": round(cluster["lng"], 6),
            "report_count": len(members),
            "open_count": open_count,
            "risk": risk,
            "categories": dict(Counter(report.category.value for report in members)),
            "first_reported_at": members[0].created_at,
            "last_reported_at": members[-1].created_at,
            "report_ids": [report.id for report in members],
        })
    hotspots.sort(key=lambda item: (-item["report_count"], -item["open_count"]))
    return {"days": days, "radius_m": radius_m, "hotspots": hotspots}


@router.get("/summary")
def sanitation_summary(days: int = Query(30, ge=1, le=365), db: Session = Depends(get_db)):
    now = _utcnow()
    reports = _swachh_reports(db, now - datetime.timedelta(days=days))

    resolved = [report for report in reports if report.status == ReportStatus.RESOLVED and report.resolved_at]
    open_reports = [report for report in reports if report.status not in CLOSED_STATUSES]
    within_sla = [
        report for report in resolved
        if report.sla_deadline is None or report.resolved_at <= report.sla_deadline
    ]
    clearance_hours = [
        (report.resolved_at - report.created_at).total_seconds() / 3600.0
        for report in resolved
        if report.created_at
    ]

    by_category = []
    for category in SWACHH_CATEGORIES:
        members = [report for report in reports if report.category == category]
        by_category.append({
            "category": category.value,
            "total": len(members),
            "open": sum(1 for report in members if report.status not in CLOSED_STATUSES),
            "resolved": sum(1 for report in members if report.status == ReportStatus.RESOLVED),
        })

    return {
        "days": days,
        "total": len(reports),
        "open": len(open_reports),
        "resolved": len(resolved),
        "citizen_verified": sum(1 for report in resolved if report.citizen_verified),
        "overdue": sum(1 for report in open_reports if report.sla_deadline and report.sla_deadline < now),
        "resolved_within_sla_rate": round(100.0 * len(within_sla) / len(resolved), 1) if resolved else None,
        "avg_clearance_hours": round(sum(clearance_hours) / len(clearance_hours), 1) if clearance_hours else None,
        "by_category": by_category,
    }


# ---------------------------------------------------------------------------
# Citizen Swachh points
# ---------------------------------------------------------------------------

POINTS_PER_REPORT = 10
POINTS_SWACHH_BONUS = 5
POINTS_PER_RESOLVED = 15
POINTS_PER_VERIFIED = 10

LEVELS = [
    (0, "Swachh Starter"),
    (50, "Swachh Sathi"),
    (150, "Swachh Champion"),
    (300, "Swachh Ambassador"),
]


@router.get("/citizens/{user_id}/impact")
def citizen_impact(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Citizen not found")

    reports = (
        db.query(Report)
        .filter(Report.user_id == user_id, Report.status != ReportStatus.CANCELLED)
        .all()
    )
    swachh_reports = [report for report in reports if report.category in SWACHH_CATEGORIES]
    resolved = [report for report in reports if report.status == ReportStatus.RESOLVED]
    verified = [report for report in resolved if report.citizen_verified]

    points = (
        POINTS_PER_REPORT * len(reports)
        + POINTS_SWACHH_BONUS * len(swachh_reports)
        + POINTS_PER_RESOLVED * len(resolved)
        + POINTS_PER_VERIFIED * len(verified)
    )

    level = LEVELS[0][1]
    next_level = None
    for threshold, name in LEVELS:
        if points >= threshold:
            level = name
        elif next_level is None:
            next_level = {"name": name, "points_needed": threshold - points}

    return {
        "user_id": user_id,
        "points": points,
        "level": level,
        "next_level": next_level,
        "reports_filed": len(reports),
        "swachh_reports": len(swachh_reports),
        "resolved": len(resolved),
        "verified": len(verified),
    }
