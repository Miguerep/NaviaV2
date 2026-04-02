from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.db import create_db_and_tables
from app.routers import chat, itinerary, places, trips


@asynccontextmanager
async def lifespan(application: FastAPI):
    """Startup / shutdown lifecycle hook."""
    create_db_and_tables()
    yield


app = FastAPI(title=settings.app_name, lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Health check (kept inline — it's a single line) ────────────────
@app.get("/health")
def health():
    return {"ok": True, "env": settings.app_env}


# ── Register routers ──────────────────────────────────────────────
app.include_router(trips.router)
app.include_router(itinerary.router)
app.include_router(chat.router)
app.include_router(places.router)
