import datetime
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Boolean, LargeBinary, Enum as SQLEnum
from sqlalchemy.orm import relationship
try:
    from geoalchemy2 import Geometry
except ImportError:
    # Fallback for lightweight testing environments without geoalchemy2
    Geometry = lambda **kwargs: String(255)

import enum

from app.database import Base

class UserRole(str, enum.Enum):
    CITIZEN = "citizen"
    OFFICER = "officer"
    ADMIN = "admin"

class ReportStatus(str, enum.Enum):
    SUBMITTED = "submitted"
    ASSIGNED = "assigned"
    IN_PROGRESS = "in_progress"
    PENDING_APPROVAL = "pending_approval"
    RESOLVED = "resolved"
    REOPENED = "reopened"
    DUPLICATE = "duplicate"
    CANCELLED = "cancelled"

class CategoryType(str, enum.Enum):
    POTHOLE = "pothole"
    GARBAGE = "garbage_overflow"
    STREETLIGHT = "broken_streetlight"
    WATER_LEAKAGE = "water_leakage"
    SEWAGE = "sewage_overflow"
    ILLEGAL_DUMPING = "illegal_dumping"
    DAMAGED_PROPERTY = "damaged_public_property"
    OTHER = "other"
    # Swachh (waste & sanitation) segment
    UNSEGREGATED_WASTE = "unsegregated_waste"
    MISSED_PICKUP = "missed_pickup"
    WASTE_BURNING = "waste_burning"
    PUBLIC_TOILET = "public_toilet"


# Categories that make up the waste & sanitation (Swachh) segment - used for
# hotspot detection, the Swachh dashboard KPIs and citizen impact points.
SWACHH_CATEGORIES = (
    CategoryType.GARBAGE,
    CategoryType.ILLEGAL_DUMPING,
    CategoryType.UNSEGREGATED_WASTE,
    CategoryType.MISSED_PICKUP,
    CategoryType.WASTE_BURNING,
    CategoryType.PUBLIC_TOILET,
)


class SegregationStatus(str, enum.Enum):
    """Outcome a sanitation worker records at a household during a
    door-to-door collection round (SWM Rules 2026 four-stream segregation)."""
    SEGREGATED = "segregated"
    PARTIAL = "partial"
    MIXED = "mixed"
    NO_WASTE = "no_waste"
    NOT_AVAILABLE = "not_available"

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    phone = Column(String(20), unique=True, index=True, nullable=False)
    role = Column(SQLEnum(UserRole), default=UserRole.CITIZEN, nullable=False)
    reputation_score = Column(Float, default=100.0)
    fcm_token = Column(String(255), nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    reports = relationship("Report", back_populates="reporter", foreign_keys="Report.user_id")

class Department(Base):
    __tablename__ = "departments"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), unique=True, nullable=False)
    jurisdiction = Column(String(100), nullable=True)
    contact = Column(String(50), nullable=True)
    avg_resolution_time = Column(Float, default=0.0)  # in hours
    sla_breach_rate = Column(Float, default=0.0)       # percentage 0-100
    reopen_rate = Column(Float, default=0.0)           # percentage 0-100

    officers = relationship("Officer", back_populates="department")
    reports = relationship("Report", back_populates="assigned_department")

class Officer(Base):
    __tablename__ = "officers"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    emp_id = Column(String(50), unique=True, index=True, nullable=True)
    password_hash = Column(String(128), nullable=True)
    department_id = Column(Integer, ForeignKey("departments.id"), nullable=True)
    contact = Column(String(50), nullable=True)
    is_available = Column(Boolean, default=True)
    is_department_head = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    department = relationship("Department", back_populates="officers")
    reports = relationship("Report", back_populates="assigned_officer")

class Report(Base):
    __tablename__ = "reports"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    photo_url = Column(String(500), nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    location = Column(Geometry(geometry_type='POINT', srid=4326), nullable=True)
    category = Column(SQLEnum(CategoryType), default=CategoryType.OTHER, nullable=False)
    description = Column(String(1000), nullable=True)
    status = Column(SQLEnum(ReportStatus), default=ReportStatus.SUBMITTED, nullable=False)
    priority_score = Column(Float, default=0.0)
    assigned_department_id = Column(Integer, ForeignKey("departments.id"), nullable=True)
    assigned_officer_id = Column(Integer, ForeignKey("officers.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    sla_deadline = Column(DateTime, nullable=True)
    estimated_completion_at = Column(DateTime, nullable=True)
    resolved_at = Column(DateTime, nullable=True)
    escalation_level = Column(Integer, default=0)
    duplicate_of = Column(Integer, ForeignKey("reports.id"), nullable=True)
    upvote_count = Column(Integer, default=1)
    citizen_verified = Column(Boolean, default=False)
    citizen_feedback_comment = Column(String(1000), nullable=True)
    admin_review_comment = Column(String(1000), nullable=True)
    cancellation_reason = Column(String(1000), nullable=True)

    reporter = relationship("User", back_populates="reports", foreign_keys=[user_id])
    assigned_department = relationship("Department", back_populates="reports")
    assigned_officer = relationship("Officer", back_populates="reports")
    resolutions = relationship("ResolutionRecord", back_populates="report")
    escalations = relationship("EscalationLog", back_populates="report")

    @property
    def assigned_department_name(self):
        return self.assigned_department.name if self.assigned_department else None

    @property
    def assigned_officer_name(self):
        return self.assigned_officer.name if self.assigned_officer else None

    @property
    def assigned_officer_emp_id(self):
        return self.assigned_officer.emp_id if self.assigned_officer else None

    @property
    def latest_resolution_photo_url(self):
        if not self.resolutions:
            return None
        latest = max(self.resolutions, key=lambda item: item.resolved_at)
        return latest.after_photo_url

    @property
    def latest_resolution_captured_at(self):
        if not self.resolutions:
            return None
        latest = max(self.resolutions, key=lambda item: item.resolved_at)
        return latest.captured_at

class ResolutionRecord(Base):
    __tablename__ = "resolution_records"

    id = Column(Integer, primary_key=True, index=True)
    report_id = Column(Integer, ForeignKey("reports.id"), nullable=False)
    before_photo_url = Column(String(500), nullable=False)
    after_photo_url = Column(String(500), nullable=False)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    officer_id = Column(Integer, ForeignKey("officers.id"), nullable=True)
    cv_similarity_score = Column(Float, default=0.0)
    captured_at = Column(DateTime, nullable=True)
    resolved_at = Column(DateTime, default=datetime.datetime.utcnow)
    verified = Column(Boolean, default=False)

    report = relationship("Report", back_populates="resolutions")

class EscalationLog(Base):
    __tablename__ = "escalation_logs"

    id = Column(Integer, primary_key=True, index=True)
    report_id = Column(Integer, ForeignKey("reports.id"), nullable=False)
    escalated_from = Column(String(100), nullable=False)
    escalated_to = Column(String(100), nullable=False)
    reason = Column(String(500), nullable=False)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)

    report = relationship("Report", back_populates="escalations")

class NotificationStatus(str, enum.Enum):
    PENDING = "pending"
    SENT = "sent"
    FAILED = "failed"
    SKIPPED = "skipped"

class NotificationEvent(Base):
    __tablename__ = "notification_events"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    report_id = Column(Integer, ForeignKey("reports.id"), nullable=True)
    title = Column(String(200), nullable=False)
    message = Column(String(500), nullable=False)
    status = Column(SQLEnum(NotificationStatus), default=NotificationStatus.PENDING, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    sent_at = Column(DateTime, nullable=True)
    error_message = Column(String(500), nullable=True)


class CollectionLog(Base):
    """One household visit on a door-to-door waste collection round."""
    __tablename__ = "collection_logs"

    id = Column(Integer, primary_key=True, index=True)
    household_code = Column(String(50), index=True, nullable=False)
    ward = Column(String(100), index=True, nullable=False)
    status = Column(SQLEnum(SegregationStatus), nullable=False)
    note = Column(String(500), nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    officer_id = Column(Integer, ForeignKey("officers.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow, index=True)

    officer = relationship("Officer")

    @property
    def officer_name(self):
        return self.officer.name if self.officer else None


class MediaFile(Base):
    """Uploaded photo stored in the database, so photos survive on hosts
    whose local disk is wiped on every restart (e.g. Render free tier)."""
    __tablename__ = "media_files"

    id = Column(String(36), primary_key=True)
    filename = Column(String(255), nullable=False)
    content_type = Column(String(100), nullable=False)
    size = Column(Integer, nullable=False)
    data = Column(LargeBinary, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
