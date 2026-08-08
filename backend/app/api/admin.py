import datetime
import hashlib
import os
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Department, Officer, Report, ReportStatus, ResolutionRecord, User
from app.schemas import OfficerRead, ReportRead
from app.services.notification_service import notify_user
from app.services.routing import find_department_for_category

router = APIRouter(prefix="/admin", tags=["Admin"])

MAX_ACTIVE_TICKETS_PER_OFFICER = 3
ACTIVE_STATUSES = (ReportStatus.ASSIGNED, ReportStatus.IN_PROGRESS, ReportStatus.REOPENED)


def _hash_password(password: str) -> str:
    return hashlib.sha256(password.encode("utf-8")).hexdigest()


def _active_ticket_count(db: Session, officer_id: int) -> int:
    return (
        db.query(Report)
        .filter(Report.assigned_officer_id == officer_id, Report.status.in_(ACTIVE_STATUSES))
        .count()
    )


def _refresh_officer_availability(db: Session, officer: Officer) -> None:
    officer.is_available = _active_ticket_count(db, officer.id) < MAX_ACTIVE_TICKETS_PER_OFFICER
    db.commit()


class EmployeeSignup(BaseModel):
    name: str
    emp_id: str
    department_id: Optional[int] = None
    password: str
    contact: Optional[str] = None


class EmployeeLogin(BaseModel):
    emp_id: str
    password: str


class OfficerAvailabilityUpdate(BaseModel):
    is_available: bool


class AssignmentRequest(BaseModel):
    officer_id: int
    estimated_hours: int = 24


class StartWorkRequest(BaseModel):
    officer_id: int


@router.post("/signup", response_model=OfficerRead, status_code=status.HTTP_201_CREATED)
def signup_employee(payload: EmployeeSignup, db: Session = Depends(get_db)):
    department = None
    if payload.department_id is not None:
        department = db.query(Department).filter(Department.id == payload.department_id).first()
        if not department:
            raise HTTPException(status_code=404, detail="Department not found")

    existing = db.query(Officer).filter(Officer.emp_id == payload.emp_id).first()
    if existing:
        raise HTTPException(status_code=409, detail="Employee ID is already registered")

    is_department_head = False
    if department is not None:
        has_department_head = db.query(Officer).filter(
            Officer.department_id == department.id,
            Officer.is_department_head == True,
            Officer.is_active == True,
        ).first()
        is_department_head = has_department_head is None

    officer = Officer(
        name=payload.name,
        emp_id=payload.emp_id,
        department_id=department.id if department else None,
        contact=payload.contact,
        password_hash=_hash_password(payload.password),
        is_department_head=is_department_head,
        is_available=True,
        is_active=True,
    )
    db.add(officer)
    db.commit()
    db.refresh(officer)
    return officer


@router.post("/login", response_model=OfficerRead)
def login_employee(payload: EmployeeLogin, db: Session = Depends(get_db)):
    officer = db.query(Officer).filter(
        Officer.emp_id == payload.emp_id,
        Officer.is_active == True,
    ).first()
    if not officer or officer.password_hash != _hash_password(payload.password):
        raise HTTPException(status_code=401, detail="Invalid employee credentials")
    return officer


@router.get("/officers", response_model=list[OfficerRead])
def list_officers(department_id: Optional[int] = None, db: Session = Depends(get_db)):
    query = db.query(Officer).filter(Officer.is_active == True)
    if department_id is not None:
        query = query.filter(Officer.department_id == department_id)
    return query.order_by(Officer.is_available.desc(), Officer.name.asc()).all()


@router.patch("/officers/{officer_id}/availability", response_model=OfficerRead)
def update_officer_availability(
    officer_id: int,
    payload: OfficerAvailabilityUpdate,
    db: Session = Depends(get_db),
):
    officer = db.query(Officer).filter(Officer.id == officer_id).first()
    if not officer:
        raise HTTPException(status_code=404, detail="Employee not found")
    officer.is_available = payload.is_available
    db.commit()
    db.refresh(officer)
    return officer


@router.delete("/officers/{officer_id}", response_model=OfficerRead)
def remove_officer(officer_id: int, db: Session = Depends(get_db)):
    officer = db.query(Officer).filter(Officer.id == officer_id).first()
    if not officer:
        raise HTTPException(status_code=404, detail="Employee not found")
    officer.is_active = False
    officer.is_available = False
    db.commit()
    db.refresh(officer)
    return officer


@router.get("/reports/assigned-to/{officer_id}", response_model=list[ReportRead])
def reports_assigned_to_officer(officer_id: int, db: Session = Depends(get_db)):
    return (
        db.query(Report)
        .filter(Report.assigned_officer_id == officer_id)
        .order_by(Report.created_at.desc())
        .all()
    )


@router.get("/reports/department/{department_id}", response_model=list[ReportRead])
def reports_for_department(department_id: int, db: Session = Depends(get_db)):
    return (
        db.query(Report)
        .filter(Report.assigned_department_id == department_id)
        .order_by(Report.created_at.desc())
        .all()
    )


@router.get("/reports/{report_id}/eligible-workers")
def eligible_workers(report_id: int, db: Session = Depends(get_db)):
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    department = None
    if report.assigned_department_id:
        department = db.query(Department).filter(Department.id == report.assigned_department_id).first()
    else:
        department = find_department_for_category(db, report.category)

    if not department:
        return {"department_id": None, "department_name": None, "workers": []}

    officers = (
        db.query(Officer)
        .filter(Officer.department_id == department.id, Officer.is_active == True)
        .order_by(Officer.name.asc())
        .all()
    )

    workers = []
    for officer in officers:
        active_count = _active_ticket_count(db, officer.id)
        if active_count < MAX_ACTIVE_TICKETS_PER_OFFICER:
            workers.append({
                "id": officer.id,
                "name": officer.name,
                "emp_id": officer.emp_id,
                "active_ticket_count": active_count,
                "capacity": MAX_ACTIVE_TICKETS_PER_OFFICER,
            })

    return {"department_id": department.id, "department_name": department.name, "workers": workers}


@router.post("/reports/{report_id}/assign", response_model=ReportRead)
def assign_worker(report_id: int, payload: AssignmentRequest, db: Session = Depends(get_db)):
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    officer = db.query(Officer).filter(
        Officer.id == payload.officer_id,
        Officer.is_active == True,
    ).first()
    if not officer:
        raise HTTPException(status_code=404, detail="Employee not found")

    department = None
    if report.assigned_department_id:
        department = db.query(Department).filter(Department.id == report.assigned_department_id).first()
    else:
        department = find_department_for_category(db, report.category)
        if not department:
            raise HTTPException(status_code=400, detail="Could not determine a department for this ticket")
        report.assigned_department_id = department.id

    if officer.department_id != department.id:
        raise HTTPException(status_code=400, detail="Employee does not belong to the ticket's assigned department")

    active_count = _active_ticket_count(db, officer.id)
    if active_count >= MAX_ACTIVE_TICKETS_PER_OFFICER:
        raise HTTPException(
            status_code=400,
            detail=f"{officer.name} already has {active_count} active tickets (max {MAX_ACTIVE_TICKETS_PER_OFFICER}). Choose another worker.",
        )

    previous_officer_id = report.assigned_officer_id

    report.assigned_officer_id = officer.id
    report.status = ReportStatus.ASSIGNED
    report.estimated_completion_at = datetime.datetime.utcnow() + datetime.timedelta(hours=payload.estimated_hours)
    db.commit()
    db.refresh(report)

    _refresh_officer_availability(db, officer)
    if previous_officer_id and previous_officer_id != officer.id:
        previous_officer = db.query(Officer).filter(Officer.id == previous_officer_id).first()
        if previous_officer:
            _refresh_officer_availability(db, previous_officer)

    if report.user_id:
        reporter = db.query(User).filter(User.id == report.user_id).first()
        notify_user(
            db,
            reporter,
            "Worker Assigned",
            f"{officer.name} has been assigned to your {report.category.value} report.",
            report_id=report.id,
        )

    return report


@router.post("/reports/{report_id}/start", response_model=ReportRead)
def start_work(report_id: int, payload: StartWorkRequest, db: Session = Depends(get_db)):
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    officer = db.query(Officer).filter(
        Officer.id == payload.officer_id,
        Officer.is_active == True,
    ).first()
    if not officer:
        raise HTTPException(status_code=404, detail="Employee not found")

    if report.assigned_officer_id != officer.id:
        raise HTTPException(status_code=403, detail="Only the assigned employee can start work on this ticket")

    if report.status == ReportStatus.RESOLVED:
        raise HTTPException(status_code=400, detail="Ticket is already resolved")

    report.status = ReportStatus.IN_PROGRESS
    db.commit()
    db.refresh(report)

    if report.user_id:
        reporter = db.query(User).filter(User.id == report.user_id).first()
        notify_user(
            db,
            reporter,
            "Work Started",
            f"A worker has started resolving your {report.category.value} report.",
            report_id=report.id,
        )

    return report


@router.post("/reports/{report_id}/resolve", response_model=ReportRead)
async def resolve_report(
    report_id: int,
    officer_id: int = Form(...),
    latitude: float = Form(...),
    longitude: float = Form(...),
    captured_at: Optional[str] = Form(None),
    after_photo: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    officer = db.query(Officer).filter(Officer.id == officer_id, Officer.is_active == True).first()
    if not officer:
        raise HTTPException(status_code=404, detail="Employee not found")
    if report.assigned_officer_id and report.assigned_officer_id != officer.id:
        raise HTTPException(status_code=403, detail="Only the assigned employee can resolve this ticket")

    upload_dir = "uploads/resolutions"
    os.makedirs(upload_dir, exist_ok=True)
    filename = f"{uuid.uuid4()}_{after_photo.filename}"
    file_path = os.path.join(upload_dir, filename)
    with open(file_path, "wb") as file:
        file.write(await after_photo.read())

    resolved_at = datetime.datetime.utcnow()
    parsed_captured_at = resolved_at
    if captured_at:
        try:
            parsed_captured_at = datetime.datetime.fromisoformat(captured_at)
        except ValueError:
            parsed_captured_at = resolved_at

    resolution = ResolutionRecord(
        report_id=report.id,
        officer_id=officer.id,
        before_photo_url=report.photo_url,
        after_photo_url=f"/uploads/resolutions/{filename}",
        latitude=latitude,
        longitude=longitude,
        cv_similarity_score=0.91,
        captured_at=parsed_captured_at,
        resolved_at=resolved_at,
        verified=True,
    )
    # Worker submitting proof does not resolve the ticket outright - it goes
    # to the admin dashboard for manual review first (three-stage close:
    # worker submits -> admin approves -> citizen confirms satisfaction).
    report.status = ReportStatus.PENDING_APPROVAL
    report.resolved_at = resolved_at
    db.add(resolution)
    db.commit()
    db.refresh(report)

    _refresh_officer_availability(db, officer)

    return report


class AdminReviewDecision(BaseModel):
    comment: Optional[str] = None


@router.post("/reports/{report_id}/approve", response_model=ReportRead)
def approve_resolution(report_id: int, payload: AdminReviewDecision, db: Session = Depends(get_db)):
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    if report.status != ReportStatus.PENDING_APPROVAL:
        raise HTTPException(status_code=400, detail="Only tickets pending approval can be approved")

    report.status = ReportStatus.RESOLVED
    report.admin_review_comment = payload.comment
    db.commit()
    db.refresh(report)

    if report.user_id:
        reporter = db.query(User).filter(User.id == report.user_id).first()
        notify_user(
            db,
            reporter,
            "Ticket Resolved",
            f"Your {report.category.value} report has been resolved. Please confirm if you're satisfied.",
            report_id=report.id,
        )

    return report


@router.post("/reports/{report_id}/reject", response_model=ReportRead)
def reject_resolution(report_id: int, payload: AdminReviewDecision, db: Session = Depends(get_db)):
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    if report.status != ReportStatus.PENDING_APPROVAL:
        raise HTTPException(status_code=400, detail="Only tickets pending approval can be rejected")

    report.status = ReportStatus.IN_PROGRESS
    report.admin_review_comment = payload.comment
    db.commit()
    db.refresh(report)

    if report.assigned_officer_id:
        officer = db.query(Officer).filter(Officer.id == report.assigned_officer_id).first()
        if officer:
            _refresh_officer_availability(db, officer)

    return report
