from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os

from app.api.router import api_router
from sqlalchemy import inspect, text

from app.database import engine, Base

# Create tables automatically on startup for local development / testing
Base.metadata.create_all(bind=engine)


def ensure_runtime_schema():
    inspector = inspect(engine)
    column_specs = {
        "users": {
            "fcm_token": "VARCHAR(255)",
        },
        "officers": {
            "emp_id": "VARCHAR(50)",
            "password_hash": "VARCHAR(128)",
            "is_available": "BOOLEAN DEFAULT TRUE",
            "is_department_head": "BOOLEAN DEFAULT FALSE",
            "is_active": "BOOLEAN DEFAULT TRUE",
            "created_at": "TIMESTAMP",
        },
        "reports": {
            "estimated_completion_at": "TIMESTAMP",
            "resolved_at": "TIMESTAMP",
            "citizen_verified": "BOOLEAN DEFAULT FALSE",
            "citizen_feedback_comment": "VARCHAR(1000)",
            "admin_review_comment": "VARCHAR(1000)",
        },
        "resolution_records": {
            "latitude": "FLOAT",
            "longitude": "FLOAT",
            "officer_id": "INTEGER",
            "captured_at": "TIMESTAMP",
        },
    }
    with engine.begin() as connection:
        for table_name, columns in column_specs.items():
            if table_name not in inspector.get_table_names():
                continue
            existing_columns = {column["name"] for column in inspector.get_columns(table_name)}
            for column_name, ddl_type in columns.items():
                if column_name not in existing_columns:
                    connection.execute(text(f"ALTER TABLE {table_name} ADD COLUMN {column_name} {ddl_type}"))

        # Officers used to require a department; platform-wide admins (signed up
        # from the web dashboard) now have department_id = NULL, so relax any
        # pre-existing NOT NULL constraint left over from before this change.
        if "officers" in inspector.get_table_names():
            officer_columns = {column["name"]: column for column in inspector.get_columns("officers")}
            department_column = officer_columns.get("department_id")
            if department_column is not None and not department_column.get("nullable", True):
                try:
                    connection.execute(text("ALTER TABLE officers ALTER COLUMN department_id DROP NOT NULL"))
                except Exception:
                    pass

    # Postgres stores ReportStatus as a native enum type. Adding a new Python
    # enum member (pending_approval, for the worker -> admin -> citizen
    # three-stage close flow) doesn't automatically add it to the DB type -
    # ALTER TYPE ... ADD VALUE also can't run inside a regular transaction on
    # older Postgres, so this uses its own autocommit connection.
    if engine.dialect.name == "postgresql":
        try:
            with engine.connect() as autocommit_connection:
                autocommit_connection = autocommit_connection.execution_options(isolation_level="AUTOCOMMIT")
                autocommit_connection.execute(
                    text("ALTER TYPE reportstatus ADD VALUE IF NOT EXISTS 'PENDING_APPROVAL'")
                )
        except Exception:
            pass

def seed_database():
    from app.database import SessionLocal
    from app.models import Department
    db = SessionLocal()
    try:
        department_seed = [
            Department(name="PWD Public Works Department", jurisdiction="Roads & Public Property", contact="+91-80-22220001", avg_resolution_time=20.0, sla_breach_rate=5.0, reopen_rate=1.8),
            Department(name="BBMP Solid Waste Management", jurisdiction="Sanitation & Waste", contact="+91-80-22221111", avg_resolution_time=18.5, sla_breach_rate=4.2, reopen_rate=1.5),
            Department(name="BWSSB Water & Sewage Board", jurisdiction="Water & Sewage", contact="+91-80-22222222", avg_resolution_time=22.0, sla_breach_rate=6.8, reopen_rate=2.1),
            Department(name="BESCOM Electrical Services", jurisdiction="Streetlight & Electricity", contact="+91-80-22223333", avg_resolution_time=31.4, sla_breach_rate=12.0, reopen_rate=5.4),
        ]
        for department in department_seed:
            exists = db.query(Department).filter(Department.name == department.name).first()
            if not exists:
                db.add(department)
            db.commit()
    finally:
        db.close()

ensure_runtime_schema()
seed_database()


app = FastAPI(
    title="JanSetu Civic Resolution API",
    description="Backend service for SIH25031 Crowdsourced Civic Issue Reporting & Resolution System",
    version="1.0.0"
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

os.makedirs("uploads/resolutions", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

app.include_router(api_router, prefix="/api/v1")

@app.get("/health", tags=["Health"])
def health_check():
    return {
        "status": "healthy",
        "service": "JanSetu Backend API",
        "version": "1.0.0"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
