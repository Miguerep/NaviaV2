import json
import logging
import uuid
from datetime import date

from sqlmodel import Session, delete, select
from google import genai
from google.genai import types

from app.config import settings
from app.models import DayPlan, Stop
from app.services import trip_service

logger = logging.getLogger(__name__)


def _generate_ai_stops(session: Session, day_plan_id: str, trip_id: str, plan_day: date) -> list[Stop]:
    """Attempt to generate realistic stops using Gemini, returning fallback stops on failure."""
    trip = trip_service.get_trip(session, trip_id)
    key = settings.gemini_api_key

    default_stops = [
        Stop(id=uuid.uuid4().hex, day_plan_id=day_plan_id, ordinal=0, title="Museum", subtitle="Indoor highlight", start_time_local="09:30"),
        Stop(id=uuid.uuid4().hex, day_plan_id=day_plan_id, ordinal=1, title="Garden", subtitle="Easy walk", start_time_local="11:45"),
        Stop(id=uuid.uuid4().hex, day_plan_id=day_plan_id, ordinal=2, title="Landmark", subtitle="Photo spot", start_time_local="13:15"),
        Stop(id=uuid.uuid4().hex, day_plan_id=day_plan_id, ordinal=3, title="Cafe", subtitle="Rest stop", start_time_local="15:00"),
    ]

    if not trip or not key:
        return default_stops

    prompt = (
        f"Create a 1-day itinerary for a trip to {trip.destination or 'a generic city'}.\n"
        f"The date is {plan_day.isoformat()}.\n"
        f"Pace: {trip.pace or 'moderate'}\n"
        f"Interests: {trip.interests_csv or 'general sightseeing'}\n\n"
        "Return the itinerary as a JSON array of objects. Each object should have:\n"
        "- title: Name of the stop\n"
        "- subtitle: Brief description or context\n"
        "- startTimeLocal: HH:MM starting time\n"
        "Return ONLY the JSON array.\n"
    )

    try:
        client = genai.Client(api_key=key)
        response = client.models.generate_content(
            model="gemini-3.1-pro",
            contents=[prompt],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.7,
            ),
        )
        data = json.loads(response.text.strip())
        if isinstance(data, list) and data:
            new_stops = []
            for idx, item in enumerate(data):
                new_stops.append(Stop(
                    id=uuid.uuid4().hex,
                    day_plan_id=day_plan_id,
                    ordinal=idx,
                    title=item.get("title", "Stop"),
                    subtitle=item.get("subtitle", ""),
                    start_time_local=item.get("startTimeLocal", "12:00")
                ))
            return new_stops
    except Exception as exc:
        logger.error("Failed to generate AI stops: %s", exc)

    return default_stops


def get_or_create_day_plan(session: Session, trip_id: str, plan_day: date) -> DayPlan:
    """Return an existing DayPlan or create a new one with generated stops."""
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
    """Delete existing stops for the day and insert new ones, then return the updated plan."""
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
    """Replace a day's stops with the ones provided (used by chat actions)."""
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
            title=s.get("title", "Stop"),
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
