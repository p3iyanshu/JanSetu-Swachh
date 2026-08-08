import os
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./jansetu_test.db")

try:
    if "sqlite" in DATABASE_URL:
        engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
    else:
        try:
            import psycopg2
            engine = create_engine(DATABASE_URL, pool_pre_ping=True)
        except ImportError:
            # Fallback to SQLite if psycopg2 is not installed in global environment
            engine = create_engine("sqlite:///./jansetu_test.db", connect_args={"check_same_thread": False})
except Exception:
    engine = create_engine("sqlite:///./jansetu_test.db", connect_args={"check_same_thread": False})



SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
