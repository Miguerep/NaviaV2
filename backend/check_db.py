import sqlite3
from pathlib import Path
from app.db import engine, init_database
from app.config import settings

# Run the full migration (creates missing tables + columns)
init_database()

# Resolve DB path the same way init_database does
raw_url = settings.database_url
rel = raw_url.removeprefix("sqlite:///").lstrip("./")
db_path = Path(__file__).resolve().parent / rel

print(f"DB path: {db_path}")
conn = sqlite3.connect(db_path)
cur = conn.cursor()

print("=== TABLES ===")
tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").fetchall()]
for table in tables:
    print(f"\n-- {table} --")
    for col in cur.execute(f"PRAGMA table_info({table})").fetchall():
        print(f"  {col[1]:25s} {col[2]}")

conn.close()
