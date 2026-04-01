import uuid
import json
import asyncio

import httpx
from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.responses import JSONResponse, StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlmodel import Session, select

from app.config import settings
from app.db import create_db_and_tables, get_session
from app.models import ChatMessage, ChatRole, DayPlan, Stop, Trip
from app.schemas import ChatRequest, CreateTripRequest, RegeneratePlanRequest, parse_date

app = FastAPI(title=settings.app_name)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup():
    create_db_and_tables()


@app.get("/health")
def health():
    return {"ok": True, "env": settings.app_env}


@app.post("/v1/trips")
def create_trip(payload: CreateTripRequest, session: Session = Depends(get_session)):
    trip = Trip(
        id=uuid.uuid4().hex,
        destination=payload.destination,
        start_date=parse_date(payload.startDate),
        end_date=parse_date(payload.endDate),
    )
    session.add(trip)
    session.commit()
    session.refresh(trip)
    return {
        "trip": {
            "id": trip.id,
            "destination": trip.destination,
            "startDate": trip.start_date.isoformat(),
            "endDate": trip.end_date.isoformat(),
        }
    }


@app.get("/v1/trips/{trip_id}")
def get_trip(trip_id: str, session: Session = Depends(get_session)):
    trip = session.get(Trip, trip_id)
    if not trip:
        raise HTTPException(status_code=404, detail="NOT_FOUND")
    return {
        "trip": {
            "id": trip.id,
            "destination": trip.destination,
            "startDate": trip.start_date.isoformat(),
            "endDate": trip.end_date.isoformat(),
        }
    }


@app.get("/v1/itinerary/{trip_id}/{day}")
def get_day_plan(trip_id: str, day: str, session: Session = Depends(get_session)):
    trip = session.get(Trip, trip_id)
    if not trip:
        raise HTTPException(status_code=404, detail="TRIP_NOT_FOUND")

    plan_day = parse_date(day)
    plan = session.exec(
        select(DayPlan).where(DayPlan.trip_id == trip_id, DayPlan.day == plan_day)
    ).first()

    if not plan:
        plan = DayPlan(id=uuid.uuid4().hex, trip_id=trip_id, day=plan_day)
        session.add(plan)
        session.commit()
        session.refresh(plan)
        default_stops = [
            Stop(id=uuid.uuid4().hex, day_plan_id=plan.id, ordinal=0, title="Museum", subtitle="Indoor highlight", start_time_local="09:30"),
            Stop(id=uuid.uuid4().hex, day_plan_id=plan.id, ordinal=1, title="Garden", subtitle="Easy walk", start_time_local="11:45"),
            Stop(id=uuid.uuid4().hex, day_plan_id=plan.id, ordinal=2, title="Landmark", subtitle="Photo spot", start_time_local="13:15"),
            Stop(id=uuid.uuid4().hex, day_plan_id=plan.id, ordinal=3, title="Cafe", subtitle="Rest stop", start_time_local="15:00"),
        ]
        session.add_all(default_stops)
        session.commit()

    stops = session.exec(
        select(Stop).where(Stop.day_plan_id == plan.id).order_by(Stop.ordinal)
    ).all()
    return {
        "plan": {
            "id": plan.id,
            "tripId": plan.trip_id,
            "date": plan.day.isoformat(),
            "stops": [
                {
                    "id": s.id,
                    "ordinal": s.ordinal,
                    "title": s.title,
                    "subtitle": s.subtitle,
                    "startTimeLocal": s.start_time_local,
                }
                for s in stops
            ],
        }
    }


@app.post("/v1/itinerary/{trip_id}/regenerate")
def regenerate_day_plan(
    trip_id: str, payload: RegeneratePlanRequest, session: Session = Depends(get_session)
):
    trip = session.get(Trip, trip_id)
    if not trip:
        raise HTTPException(status_code=404, detail="TRIP_NOT_FOUND")

    plan_day = parse_date(payload.date)
    plan = session.exec(
        select(DayPlan).where(DayPlan.trip_id == trip_id, DayPlan.day == plan_day)
    ).first()
    if not plan:
        plan = DayPlan(id=uuid.uuid4().hex, trip_id=trip_id, day=plan_day)
        session.add(plan)
        session.commit()
        session.refresh(plan)

    old_stops = session.exec(select(Stop).where(Stop.day_plan_id == plan.id)).all()
    for stop in old_stops:
        session.delete(stop)
    session.commit()

    new_stops = [
        Stop(id=uuid.uuid4().hex, day_plan_id=plan.id, ordinal=0, title="Indoor Museum", subtitle="Updated plan", start_time_local="10:00"),
        Stop(id=uuid.uuid4().hex, day_plan_id=plan.id, ordinal=1, title="Coffee", subtitle="Nearby", start_time_local="12:00"),
    ]
    session.add_all(new_stops)
    session.commit()
    return get_day_plan(trip_id, payload.date, session)


def _build_actions(user_message: str) -> list[dict]:
    text = user_message.lower()
    if "rain" in text or "raining" in text or "indoor" in text:
        return [
            {
                "type": "ReplaceDayPlan",
                "reason": "Weather-adjusted to indoor activities",
                "stops": [
                    {"title": "Indoor Museum", "subtitle": "Weather-safe", "startTimeLocal": "10:00"},
                    {"title": "Coffee Shop", "subtitle": "Nearby warm stop", "startTimeLocal": "12:00"},
                ],
            }
        ]
    if "suggest" in text or "recommend" in text:
        return [
            {
                "type": "SuggestPOIs",
                "items": [
                    {"name": "Local Museum", "category": "museum"},
                    {"name": "Historic Cafe", "category": "food"},
                ],
            }
        ]
    return []


def _apply_replace_day_plan(
    session: Session,
    trip_id: str,
    active_date: str,
    actions: list[dict],
) -> None:
    replace = next((a for a in actions if a.get("type") == "ReplaceDayPlan"), None)
    if not replace:
        return

    plan_day = parse_date(active_date)
    plan = session.exec(
        select(DayPlan).where(DayPlan.trip_id == trip_id, DayPlan.day == plan_day)
    ).first()
    if not plan:
        plan = DayPlan(id=uuid.uuid4().hex, trip_id=trip_id, day=plan_day)
        session.add(plan)
        session.commit()
        session.refresh(plan)

    for stop in session.exec(select(Stop).where(Stop.day_plan_id == plan.id)).all():
        session.delete(stop)
    session.commit()

    new_stops = []
    for idx, stop in enumerate(replace.get("stops", [])):
        new_stops.append(
            Stop(
                id=uuid.uuid4().hex,
                day_plan_id=plan.id,
                ordinal=idx,
                title=stop.get("title", "Stop"),
                subtitle=stop.get("subtitle"),
                start_time_local=stop.get("startTimeLocal"),
            )
        )
    session.add_all(new_stops)
    session.commit()


@app.post("/v1/chat")
async def chat(payload: ChatRequest, session: Session = Depends(get_session)):
    trip = session.get(Trip, payload.tripId)
    if not trip:
        raise HTTPException(status_code=404, detail="TRIP_NOT_FOUND")

    session.add(
        ChatMessage(
            id=uuid.uuid4().hex,
            trip_id=payload.tripId,
            role=ChatRole.user,
            content=payload.userMessage,
        )
    )
    session.commit()

    actions = _build_actions(payload.userMessage)
    assistant_text = (
        "I updated your itinerary based on your request."
        if actions
        else "Got it. I can adjust your day plan when needed."
    )

    _apply_replace_day_plan(session, payload.tripId, payload.activeDate, actions)

    session.add(
        ChatMessage(
            id=uuid.uuid4().hex,
            trip_id=payload.tripId,
            role=ChatRole.assistant,
            content=assistant_text,
        )
    )
    session.commit()

    async def event_stream():
        words = assistant_text.split(" ")
        partial = ""
        for w in words:
            partial = f"{partial} {w}".strip()
            yield f"event: message.delta\ndata: {json.dumps({'text': partial})}\n\n"
            await asyncio.sleep(0.03)
        yield f"event: message.final\ndata: {json.dumps({'text': assistant_text})}\n\n"
        yield f"event: actions\ndata: {json.dumps({'actions': actions})}\n\n"

    return StreamingResponse(event_stream(), media_type="text/event-stream")


@app.get("/v1/places/search")
async def mapbox_search(
    q: str = Query(min_length=1),
    near: str | None = None,
    limit: int = Query(default=5, ge=1, le=10),
):
    if not settings.mapbox_token:
        return JSONResponse(
            status_code=501,
            content={
                "error": "MAPBOX_NOT_CONFIGURED",
                "message": "Set MAPBOX_TOKEN in backend .env.",
            },
        )

    url = f"https://api.mapbox.com/geocoding/v5/mapbox.places/{q}.json"
    params = {
        "access_token": settings.mapbox_token,
        "limit": str(limit),
        "autocomplete": "true",
    }
    if near:
        lat, lng = near.split(",")
        params["proximity"] = f"{lng},{lat}"

    async with httpx.AsyncClient(timeout=20.0) as client:
        resp = await client.get(url, params=params)
        if resp.status_code >= 400:
            raise HTTPException(status_code=502, detail="MAPBOX_ERROR")
        data = resp.json()

    results = []
    for feature in data.get("features", []):
        categories_raw = feature.get("properties", {}).get("category")
        if isinstance(categories_raw, str):
            categories = [c.strip() for c in categories_raw.split(",") if c.strip()]
        else:
            categories = []

        center = feature.get("center")
        center_obj = None
        if isinstance(center, list) and len(center) == 2:
            center_obj = {"lng": center[0], "lat": center[1]}

        results.append(
            {
                "id": str(feature.get("id", "")),
                "name": str(feature.get("text", "")),
                "placeName": str(feature.get("place_name", "")),
                "center": center_obj,
                "categories": categories,
            }
        )
    return {"results": results}


@app.get("/v1/route")
async def mapbox_route(
    from_: str = Query(..., alias="from"),
    to: str = Query(...),
):
    if not settings.mapbox_token:
        return JSONResponse(
            status_code=501,
            content={
                "error": "MAPBOX_NOT_CONFIGURED",
                "message": "Set MAPBOX_TOKEN in backend .env.",
            },
        )

    try:
        from_lat, from_lng = from_.split(",")
        to_lat, to_lng = to.split(",")
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="BAD_REQUEST") from exc
    coords = f"{from_lng},{from_lat};{to_lng},{to_lat}"
    url = f"https://api.mapbox.com/directions/v5/mapbox/walking/{coords}"
    params = {
        "access_token": settings.mapbox_token,
        "geometries": "geojson",
        "overview": "simplified",
        "steps": "true",
    }
    async with httpx.AsyncClient(timeout=20.0) as client:
        resp = await client.get(url, params=params)
        if resp.status_code >= 400:
            raise HTTPException(status_code=502, detail="MAPBOX_ERROR")
        data = resp.json()

    routes = data.get("routes", [])
    if not routes:
        raise HTTPException(status_code=502, detail="MAPBOX_NO_ROUTE")

    route = routes[0]
    return {
        "distanceMeters": route.get("distance"),
        "durationSeconds": route.get("duration"),
        "geometry": route.get("geometry"),
        "legs": route.get("legs"),
    }

