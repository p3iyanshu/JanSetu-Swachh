from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from app.database import get_db
from app.models import Department
from app.schemas import DepartmentRead

router = APIRouter(prefix="/departments", tags=["Departments"])

@router.get("/", response_model=List[DepartmentRead])
def list_departments(db: Session = Depends(get_db)):
    return db.query(Department).all()

@router.get("/leaderboard", response_model=List[DepartmentRead])
def department_leaderboard(db: Session = Depends(get_db)):
    # Leaderboard sorted by lowest SLA breach rate and lowest reopen rate
    return db.query(Department).order_by(
        Department.sla_breach_rate.asc(),
        Department.reopen_rate.asc()
    ).all()
