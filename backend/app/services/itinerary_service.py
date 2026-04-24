"""Itinerary service.

Responsible for creating and managing DayPlan + Stop records.
When a day-plan is first requested, Gemini generates personalised stops
based on the trip's onboarding preferences (destination, dates, pace,
interests). A static fallback is used when Gemini is unavailable.
"""

import json
import logging
import uuid
from datetime import date

from google import genai
from google.genai import types
from sqlmodel import Session, delete, select

from app.config import settings
from app.models import DayPlan, Stop, Trip
from app.services.trip_service import get_trip_or_404

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# System prompt for Gemini itinerary generation
# ---------------------------------------------------------------------------

_ITINERARY_SYSTEM_PROMPT = """\
You are an expert travel planner. Generate a realistic 1-day itinerary \
for the trip described below.

Rules:
- Use REAL, well-known place names (museums, parks, squares, restaurants…).
- Match the user's interests and pace exactly.
- Include 4–6 stops per day, spaced sensibly across the day.
- Each stop must have a concise "subtitle" (what to do / why it's interesting).
- Use local opening hours where relevant (e.g. don't schedule a museum at 07:00).
- Respond ONLY with a valid JSON array, no markdown, no extra text.

JSON schema for each stop:
{"title": "string", "subtitle": "string", "startTimeLocal": "HH:MM"}
"""


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _build_trip_context(trip: Trip, plan_day: date) -> str:
    """Build the user-facing context block sent to Gemini."""
    interests = (
        [i.strip() for i in trip.interests_csv.split(",") if i.strip()]
        if trip.interests_csv
        else []
    )
    interests_str = ", ".join(interests) if interests else "general sightseeing"
    pace_str = (trip.pace or "moderate").strip()

    total_days = (trip.end_date - trip.start_date).days + 1
    day_number = (plan_day - trip.start_date).days + 1

    return (
        f"Destination: {trip.destination}\n"
        f"Trip dates: {trip.start_date.isoformat()} → {trip.end_date.isoformat()} "
        f"({total_days} days total)\n"
        f"Day: {plan_day.isoformat()} (day {day_number} of {total_days})\n"
        f"Pace: {pace_str}\n"
        f"Interests: {interests_str}\n"
    )


def _generate_ai_stops(session: Session, day_plan_id: str, trip_id: str, plan_day: date) -> list[Stop]:
    """Call Gemini to generate personalised stops; fall back to stubs on failure."""
    trip = get_trip_or_404(session, trip_id)   # returns the ORM Trip object
    key = settings.gemini_api_key

    # --- Static fallback ---
    fallback = [
        Stop(id=uuid.uuid4().hex, day_plan_id=day_plan_id, ordinal=0,
             title="City Museum", subtitle="Start your day with local history", start_time_local="09:30"),
        Stop(id=uuid.uuid4().hex, day_plan_id=day_plan_id, ordinal=1,
             title="Central Park / Garden", subtitle="Relaxed mid-morning stroll", start_time_local="11:30"),
        Stop(id=uuid.uuid4().hex, day_plan_id=day_plan_id, ordinal=2,
             title="Local Lunch Spot", subtitle="Try a traditional dish", start_time_local="13:00"),
        Stop(id=uuid.uuid4().hex, day_plan_id=day_plan_id, ordinal=3,
             title="Main Landmark", subtitle="Iconic photo opportunity", start_time_local="14:30"),
        Stop(id=uuid.uuid4().hex, day_plan_id=day_plan_id, ordinal=4,
             title="Sunset Viewpoint", subtitle="Best panoramic view of the city", start_time_local="18:00"),
    ]

    if not key:
        logger.warning("GEMINI_API_KEY not set — using static fallback itinerary.")
        return fallback

    context = _build_trip_context(trip, plan_day)

    try:
        client = genai.Client(api_key=key)
        response = client.models.generate_content(
            model="gemini-flash-latest",
            contents=[_ITINERARY_SYSTEM_PROMPT, context],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.6,
            ),
        )
        raw = response.text.strip()
        data = json.loads(raw)

        if not isinstance(data, list) or not data:
            raise ValueError("Gemini returned empty or non-list response")

        stops = []
        for idx, item in enumerate(data):
            if not isinstance(item, dict):
                continue
            stops.append(Stop(
                id=uuid.uuid4().hex,
                day_plan_id=day_plan_id,
                ordinal=idx,
                title=str(item.get("title") or "Stop"),
                subtitle=str(item.get("subtitle") or ""),
                start_time_local=str(item.get("startTimeLocal") or "12:00"),
            ))

        if not stops:
            raise ValueError("No valid stops parsed from Gemini response")

        logger.info(
            "AI itinerary generated: %d stops for trip %s on %s",
            len(stops), trip_id, plan_day,
        )
        return stops

    except Exception as exc:
        logger.error("Gemini itinerary generation failed: %s — using fallback.", exc)
        return fallback


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def get_or_create_day_plan(session: Session, trip_id: str, plan_day: date) -> DayPlan:
    """Return an existing DayPlan or create a new AI-generated one."""
    plan = session.exec(
        select(DayPlan).where(DayPlan.trip_id == trip_id, DayPlan.day == plan_day)
    ).first()

    if plan:
        return plan

    plan = DayPlan(id=uuid.uuid4().hex, trip_id=trip_id, day=plan_day)
    session.add(plan)
    session.commit()
    session.refresh(plan)

    new_stops = _generate_ai_stops(session, plan.id, trip_id, plan_day)
    session.add_all(new_stops)
    session.commit()
    return plan


def get_day_plan_response(session: Session, trip_id: str, plan_day: date) -> dict:
    """Build the full day-plan JSON response."""
    plan = get_or_create_day_plan(session, trip_id, plan_day)
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


def regenerate_day_plan(session: Session, trip_id: str, plan_day: date) -> dict:
    """Delete existing stops for the day, regenerate with AI, and return updated plan."""
    plan = session.exec(
        select(DayPlan).where(DayPlan.trip_id == trip_id, DayPlan.day == plan_day)
    ).first()

    if not plan:
        plan = DayPlan(id=uuid.uuid4().hex, trip_id=trip_id, day=plan_day)
        session.add(plan)
        session.commit()
        session.refresh(plan)

    _clear_stops(session, plan.id)
    new_stops = _generate_ai_stops(session, plan.id, trip_id, plan_day)
    session.add_all(new_stops)
    session.commit()

    return get_day_plan_response(session, trip_id, plan_day)


def replace_stops(session: Session, trip_id: str, plan_day: date, stops_data: list[dict]) -> None:
    """Replace a day's stops with the given list (used by chat actions). Caller commits."""
    plan = session.exec(
        select(DayPlan).where(DayPlan.trip_id == trip_id, DayPlan.day == plan_day)
    ).first()

    if not plan:
        plan = DayPlan(id=uuid.uuid4().hex, trip_id=trip_id, day=plan_day)
        session.add(plan)
        session.commit()
        session.refresh(plan)

    _clear_stops(session, plan.id)

    new_stops = [
        Stop(
            id=uuid.uuid4().hex,
            day_plan_id=plan.id,
            ordinal=idx,
            title=str(s.get("title") or "Stop"),
            subtitle=s.get("subtitle"),
            start_time_local=s.get("startTimeLocal"),
        )
        for idx, s in enumerate(stops_data)
    ]
    session.add_all(new_stops)
    # NOTE: caller is responsible for committing


def _clear_stops(session: Session, day_plan_id: str) -> None:
    """Bulk-delete all stops for a day plan in a single statement."""
    session.exec(delete(Stop).where(Stop.day_plan_id == day_plan_id))
    session.commit()
