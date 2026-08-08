from fastapi import APIRouter
from app.api.reports import router as reports_router
from app.api.departments import router as departments_router
from app.api.auth import router as auth_router
from app.api.ai import router as ai_router
from app.api.admin import router as admin_router

api_router = APIRouter()
api_router.include_router(reports_router)
api_router.include_router(departments_router)
api_router.include_router(auth_router)
api_router.include_router(ai_router)
api_router.include_router(admin_router)
