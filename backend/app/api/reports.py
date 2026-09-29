from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional
from pydantic import BaseModel
import uuid
import os
import datetime

from app.database import get_db
from app.models import Report, ReportStatus, CategoryType, User, Department, Officer, ResolutionRecord
from app.schemas import ReportCreate, ReportRead
from app.services import calculate_sla_deadline, calculate_priority_score
from app.services.routing import find_department_for_category

router = APIRouter(prefix="/reports", tags=["Reports"])

class StatusUpdateSchema(BaseModel):
    status: ReportStatus
    assigned_department_id: Optional[int] = None
    assigned_officer_id: Optional[int] = None

class FeedbackSubmit(BaseModel):
    satisfied: bool
    comment: Optional[str] = None

class CancelRequest(BaseModel):
    reason: Optional[str] = None

@router.post("/upload-photo")
async def upload_photo(file: UploadFile = File(...)):
    filename = f"{uuid.uuid4()}_{file.filename}"
    upload_dir = "uploads"
    os.makedirs(upload_dir, exist_ok=True)
    file_path = os.path.join(upload_dir, filename)
    
    with open(file_path, "wb") as f:
        content = await file.read()
        f.write(content)
        
    return {"photo_url": f"/uploads/{filename}", "filename": filename}

@router.post("/classify-placeholder")
def classify_placeholder(photo_url: str):
    return {
        "category": CategoryType.POTHOLE,
        "confidence": 0.94,
        "suggested_description": "Detected large pothole on asphalt road surface.",
        "severity_level": 4
    }

@router.get("/stats")
def get_report_stats(db: Session = Depends(get_db)):
    all_reports = db.query(Report).all()
    open_count = sum(1 for r in all_reports if r.status in [ReportStatus.SUBMITTED, ReportStatus.ASSIGNED])
    in_progress_count = sum(1 for r in all_reports if r.status == ReportStatus.IN_PROGRESS)
    resolved_count = sum(1 for r in all_reports if r.status == ReportStatus.RESOLVED)
    
    # Calculate avg resolution time in hours for resolved reports
    resolutions = db.query(ResolutionRecord).filter(ResolutionRecord.verified == True).all()
    if resolutions:
        total_hours = sum((r.resolved_at - r.report.created_at).total_seconds() / 3600.0 for r in resolutions if r.report)
        avg_resolution_hours = round(total_hours / len(resolutions), 1)
    else:
        avg_resolution_hours = 21.4 # Mock benchmark baseline if no resolved records yet
        
    return {
        "open_count": open_count,
        "in_progress_count": in_progress_count,
        "resolved_count": resolved_count,
        "total_count": len(all_reports),
        "avg_resolution_hours": avg_resolution_hours
    }

@router.post("/", response_model=ReportRead, status_code=status.HTTP_201_CREATED)
def create_report(report_in: ReportCreate, db: Session = Depends(get_db)):
    # Every submission becomes its own ticket with its own ID, even if
    # another report exists nearby for the same category - citizens and
    # admins both need to see each one individually, not merged/hidden.
    sla_deadline = calculate_sla_deadline(report_in.category)
    priority_score = calculate_priority_score(category=report_in.category, upvote_count=1)
    assigned_department = find_department_for_category(db, report_in.category)
    # A stale citizen ID (e.g. the app kept a session across a demo-data
    # reset) must not fail the whole report on a foreign-key error.
    user_id = report_in.user_id
    if user_id is not None and not db.query(User).filter(User.id == user_id).first():
        user_id = None

    db_report = Report(
        photo_url=report_in.photo_url,
        latitude=report_in.latitude,
        longitude=report_in.longitude,
        category=report_in.category,
        description=report_in.description,
        user_id=user_id,
        status=ReportStatus.ASSIGNED if assigned_department else ReportStatus.SUBMITTED,
        priority_score=priority_score,
        assigned_department_id=assigned_department.id if assigned_department else None,
        sla_deadline=sla_deadline,
        upvote_count=1
    )
    db.add(db_report)
    db.commit()
    db.refresh(db_report)
    return db_report

@router.patch("/{report_id}/status", response_model=ReportRead)
def update_report_status(report_id: int, payload: StatusUpdateSchema, db: Session = Depends(get_db)):
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
        
    report.status = payload.status
    if payload.assigned_department_id is not None:
        report.assigned_department_id = payload.assigned_department_id
    if payload.assigned_officer_id is not None:
        report.assigned_officer_id = payload.assigned_officer_id
    if payload.status == ReportStatus.RESOLVED:
        report.resolved_at = datetime.datetime.utcnow()
        
    db.commit()
    db.refresh(report)
    return report

@router.get("/", response_model=List[ReportRead])
def list_reports(
    status: Optional[ReportStatus] = None,
    category: Optional[CategoryType] = None,
    user_id: Optional[int] = None,
    db: Session = Depends(get_db)
):
    query = db.query(Report)
    if user_id is not None:
        query = query.filter(Report.user_id == user_id)
    if status:
        query = query.filter(Report.status == status)
    if category:
        query = query.filter(Report.category == category)
    return query.order_by(Report.priority_score.desc()).all()

@router.get("/{report_id}", response_model=ReportRead)
def get_report(report_id: int, db: Session = Depends(get_db)):
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    return report

@router.post("/{report_id}/cancel", response_model=ReportRead)
def cancel_report(report_id: int, payload: CancelRequest, db: Session = Depends(get_db)):
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    if report.status in (ReportStatus.RESOLVED, ReportStatus.CANCELLED):
        raise HTTPException(status_code=400, detail="This ticket can no longer be cancelled")

    freed_officer_id = report.assigned_officer_id
    report.status = ReportStatus.CANCELLED
    report.cancellation_reason = payload.reason
    db.commit()
    db.refresh(report)

    if freed_officer_id:
        from app.api.admin import _refresh_officer_availability

        officer = db.query(Officer).filter(Officer.id == freed_officer_id).first()
        if officer:
            _refresh_officer_availability(db, officer)

    return report

@router.post("/{report_id}/feedback", response_model=ReportRead)
def submit_feedback(report_id: int, payload: FeedbackSubmit, db: Session = Depends(get_db)):
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    if report.status != ReportStatus.RESOLVED:
        raise HTTPException(status_code=400, detail="Feedback can only be submitted for resolved tickets")

    report.citizen_feedback_comment = payload.comment

    if payload.satisfied:
        report.citizen_verified = True
    else:
        report.citizen_verified = False
        report.status = ReportStatus.REOPENED
        if report.assigned_officer_id:
            from app.api.admin import _refresh_officer_availability

            officer = db.query(Officer).filter(Officer.id == report.assigned_officer_id).first()
            if officer:
                _refresh_officer_availability(db, officer)

    db.commit()
    db.refresh(report)
    return report
