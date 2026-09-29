from pydantic import BaseModel, ConfigDict, Field
from typing import Optional, List
from datetime import datetime
from app.models import UserRole, ReportStatus, CategoryType, SegregationStatus

# User Schemas
class UserBase(BaseModel):
    phone: str
    role: UserRole = UserRole.CITIZEN

class UserCreate(UserBase):
    pass

class UserRead(UserBase):
    id: int
    reputation_score: float
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

# Department & Officer Schemas
class DepartmentBase(BaseModel):
    name: str
    jurisdiction: Optional[str] = None
    contact: Optional[str] = None

class DepartmentRead(DepartmentBase):
    id: int
    avg_resolution_time: float
    sla_breach_rate: float
    reopen_rate: float

    model_config = ConfigDict(from_attributes=True)

class OfficerBase(BaseModel):
    name: str
    department_id: Optional[int] = None
    emp_id: Optional[str] = None
    contact: Optional[str] = None

class OfficerRead(OfficerBase):
    id: int
    is_available: bool = True
    is_department_head: bool = False
    is_active: bool = True

    model_config = ConfigDict(from_attributes=True)

# Report Schemas
class ReportCreate(BaseModel):
    photo_url: str
    latitude: float
    longitude: float
    category: Optional[CategoryType] = CategoryType.OTHER
    description: Optional[str] = None
    user_id: Optional[int] = None

class ReportRead(BaseModel):
    id: int
    user_id: Optional[int] = None
    photo_url: str
    latitude: float
    longitude: float
    category: CategoryType
    description: Optional[str] = None
    status: ReportStatus
    priority_score: float
    assigned_department_id: Optional[int] = None
    assigned_officer_id: Optional[int] = None
    assigned_department_name: Optional[str] = None
    assigned_officer_name: Optional[str] = None
    assigned_officer_emp_id: Optional[str] = None
    created_at: datetime
    sla_deadline: Optional[datetime] = None
    estimated_completion_at: Optional[datetime] = None
    resolved_at: Optional[datetime] = None
    latest_resolution_photo_url: Optional[str] = None
    latest_resolution_captured_at: Optional[datetime] = None
    citizen_verified: bool = False
    citizen_feedback_comment: Optional[str] = None
    admin_review_comment: Optional[str] = None
    cancellation_reason: Optional[str] = None
    escalation_level: int
    duplicate_of: Optional[int] = None
    upvote_count: int

    model_config = ConfigDict(from_attributes=True)

class ResolutionCreate(BaseModel):
    report_id: int
    after_photo_url: str

class ResolutionRead(BaseModel):
    id: int
    report_id: int
    before_photo_url: str
    after_photo_url: str
    cv_similarity_score: float
    captured_at: Optional[datetime] = None
    resolved_at: datetime
    verified: bool

    model_config = ConfigDict(from_attributes=True)

class EscalationLogRead(BaseModel):
    id: int
    report_id: int
    escalated_from: str
    escalated_to: str
    reason: str
    timestamp: datetime

    model_config = ConfigDict(from_attributes=True)

# Notification Schemas
class DeviceTokenRegister(BaseModel):
    phone: str
    fcm_token: str

# Swachh (waste & sanitation) Schemas
class CollectionLogCreate(BaseModel):
    household_code: str = Field(..., min_length=1, max_length=50)
    ward: str = Field(..., min_length=1, max_length=100)
    status: SegregationStatus
    note: Optional[str] = Field(None, max_length=500)
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    officer_id: Optional[int] = None

class CollectionLogRead(BaseModel):
    id: int
    household_code: str
    ward: str
    status: SegregationStatus
    note: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    officer_id: Optional[int] = None
    officer_name: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
