import sqlite3
import logging
from pathlib import Path

from sqlmodel import Session, SQLModel, create_engine

from app.config import settings

logger = logging.getLogger(__name__)

engine = create_engine(settings.database_url, echo=False)


def init_database() -> None:
    """Create tables and migrate any missing columns (safe, non-destructive)."""
    # Ensure all models are registered in SQLModel.metadata before create_all
    import app.models  # noqa: F401  (side-effect import)

    # 1. Create tables that don't exist yet
    SQLModel.metadata.create_all(engine)

    # 2. For SQLite only: add any columns the ORM model has that the DB lacks.
    #    Resolve the DB path to an absolute path so it works regardless of CWD.
    raw_url = settings.database_url  # e.g. "sqlite:///./backend.db" or "sqlite:///backend.db"
    if not raw_url.startswith("sqlite:///"):
        return  # Not SQLite – skip

    rel = raw_url.removeprefix("sqlite:///").lstrip("./")
    # Anchor to the directory that contains this file (app/) → go one level up → project root
    project_root = Path(__file__).resolve().parent.parent
    db_path = project_root / rel

    if not db_path.exists():
        return

    conn = sqlite3.connect(db_path)
    try:
        for table in SQLModel.metadata.sorted_tables:
            cursor = conn.execute(f"PRAGMA table_info({table.name})")
            existing_cols = {row[1] for row in cursor.fetchall()}

            for col in table.columns:
                if col.name not in existing_cols:
                    col_type = str(col.type.compile(dialect=engine.dialect))
                    nullable = " NOT NULL" if not col.nullable else ""
                    conn.execute(
                        f"ALTER TABLE {table.name} ADD COLUMN {col.name} {col_type}{nullable}"
                    )
                    logger.warning("Migrated: added column '%s.%s'", table.name, col.name)

        conn.commit()
    finally:
        conn.close()


# Keep old name as alias for any existing callers
create_db_and_tables = init_database


def get_session():
    with Session(engine) as session:
        yield session
