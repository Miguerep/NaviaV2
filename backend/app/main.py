from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.db import create_db_and_tables
from app.routers import chat, itinerary, narration, places, trips


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Create tables on startup (replaces deprecated @app.on_event)."""
    create_db_and_tables()
    yield


app = FastAPI(title=settings.app_name, lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ──────────────────────────────────────────────
app.include_router(trips.router)
app.include_router(itinerary.router)
app.include_router(chat.router)
app.include_router(narration.router)
app.include_router(places.router)


@app.get("/health")
def health():
    return {"ok": True, "env": settings.app_env}
