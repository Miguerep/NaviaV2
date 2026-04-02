import uuid

from sqlmodel import Session, select

from app.models import DayPlan, Stop
from app.schemas import parse_date


def get_or_create_day_plan(session: Session, trip_id: str, day_iso: str) -> DayPlan:
    """Return an existing DayPlan or create a new one with default stops."""
    plan_day = parse_date(day_iso)
    plan = session.exec(
        select(DayPlan).where(DayPlan.trip_id == trip_id, DayPlan.day == plan_day)
    ).first()

    if plan:
        return plan

    plan = DayPlan(id=uuid.uuid4().hex, trip_id=trip_id, day=plan_day)
    session.add(plan)
    session.commit()
    session.refresh(plan)

    default_stops = [
        Stop(id=uuid.uuid4().hex, day_plan_id=plan.id, ordinal=0,
             title="Museum", subtitle="Indoor highlight", start_time_local="09:30"),
        Stop(id=uuid.uuid4().hex, day_plan_id=plan.id, ordinal=1,
             title="Garden", subtitle="Easy walk", start_time_local="11:45"),
        Stop(id=uuid.uuid4().hex, day_plan_id=plan.id, ordinal=2,
             title="Landmark", subtitle="Photo spot", start_time_local="13:15"),
        Stop(id=uuid.uuid4().hex, day_plan_id=plan.id, ordinal=3,
             title="Cafe", subtitle="Rest stop", start_time_local="15:00"),
    ]
    session.add_all(default_stops)
    session.commit()
    return plan


def get_day_plan_response(session: Session, trip_id: str, day_iso: str) -> dict:
    """Build the full day-plan JSON response."""
    plan = get_or_create_day_plan(session, trip_id, day_iso)
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


def regenerate_day_plan(session: Session, trip_id: str, day_iso: str) -> dict:
    """Delete existing stops for the day and insert new ones, then return the updated plan."""
    plan_day = parse_date(day_iso)
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
        Stop(id=uuid.uuid4().hex, day_plan_id=plan.id, ordinal=0,
             title="Indoor Museum", subtitle="Updated plan", start_time_local="10:00"),
        Stop(id=uuid.uuid4().hex, day_plan_id=plan.id, ordinal=1,
             title="Coffee", subtitle="Nearby", start_time_local="12:00"),
    ]
    session.add_all(new_stops)
    session.commit()

    return get_day_plan_response(session, trip_id, day_iso)


def replace_stops(session: Session, trip_id: str, day_iso: str, stops_data: list[dict]) -> None:
    """Replace a day's stops with the ones provided (used by chat actions)."""
    plan_day = parse_date(day_iso)
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
    session.commit()


def _clear_stops(session: Session, day_plan_id: str) -> None:
    old_stops = session.exec(select(Stop).where(Stop.day_plan_id == day_plan_id)).all()
    for stop in old_stops:
        session.delete(stop)
    session.commit()
