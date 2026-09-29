import os
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./jansetu_test.db")
# Some hosts (Render, Heroku) hand out "postgres://" URLs, which SQLAlchemy 2
# no longer accepts.
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = "postgresql://" + DATABASE_URL[len("postgres://"):]
# Pin the psycopg2 driver: SQLAlchemy 2.1 switched the default PostgreSQL
# driver to psycopg 3, which isn't installed.
if DATABASE_URL.startswith("postgresql://"):
    DATABASE_URL = "postgresql+psycopg2://" + DATABASE_URL[len("postgresql://"):]

# On a server, silently falling back to a local SQLite file would lose all
# data on the next restart - fail loudly there instead.
REQUIRE_DATABASE = os.getenv("JANSETU_REQUIRE_DATABASE", "0") == "1"

try:
    if "sqlite" in DATABASE_URL:
        engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
    else:
        try:
            import psycopg2
            engine = create_engine(DATABASE_URL, pool_pre_ping=True)
        except ImportError:
            if REQUIRE_DATABASE:
                raise
            # Fallback to SQLite if psycopg2 is not installed in global environment
            engine = create_engine("sqlite:///./jansetu_test.db", connect_args={"check_same_thread": False})
except Exception:
    if REQUIRE_DATABASE:
        raise
    print("WARNING: could not connect using DATABASE_URL - falling back to local SQLite (jansetu_test.db)")
    engine = create_engine("sqlite:///./jansetu_test.db", connect_args={"check_same_thread": False})



SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
