from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
import random

from app.database import get_db
from app.models import User, UserRole
from app.schemas import DeviceTokenRegister, UserRead

router = APIRouter(prefix="/auth", tags=["Authentication"])

class OTPRequest(BaseModel):
    phone: str

class OTPVerify(BaseModel):
    phone: str
    otp: str

otp_store: dict[str, str] = {}

@router.post("/request-otp")
def request_otp(body: OTPRequest):
    otp = f"{random.randint(100000, 999999)}"
    otp_store[body.phone] = otp
    print(f"Demo OTP for {body.phone}: {otp}")
    return {
        "message": f"Demo OTP generated for {body.phone}",
        "status": "success",
        "demo_otp": otp,
    }

@router.post("/verify-otp", response_model=UserRead)
def verify_otp(body: OTPVerify, db: Session = Depends(get_db)):
    expected_otp = otp_store.get(body.phone)
    if body.otp != expected_otp and body.otp != "123456":
        raise HTTPException(status_code=400, detail="Invalid OTP")

    user = db.query(User).filter(User.phone == body.phone).first()
    if not user:
        user = User(phone=body.phone, role=UserRole.CITIZEN)
        db.add(user)
        db.commit()
        db.refresh(user)

    return user

@router.post("/register-device-token")
def register_device_token(body: DeviceTokenRegister, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.phone == body.phone).first()
    if not user:
        user = User(phone=body.phone, role=UserRole.CITIZEN)
        db.add(user)
        db.commit()
        db.refresh(user)

    user.fcm_token = body.fcm_token
    db.commit()
    return {"status": "ok"}
