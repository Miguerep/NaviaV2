import uuid

from fastapi import HTTPException
from sqlmodel import Session

from app.models import Trip
from app.schemas import CreateTripRequest, parse_date


def create_trip(session: Session, payload: CreateTripRequest) -> dict:
    """Create a new trip and return its serialised representation."""
    trip = Trip(
        id=uuid.uuid4().hex,
        destination=payload.destination,
        start_date=parse_date(payload.startDate),
        end_date=parse_date(payload.endDate),
    )
    session.add(trip)
    session.commit()
    session.refresh(trip)
    return _serialise_trip(trip)


def get_trip(session: Session, trip_id: str) -> dict:
    """Fetch a trip by ID or raise 404."""
    trip = session.get(Trip, trip_id)
    if not trip:
        raise HTTPException(status_code=404, detail="NOT_FOUND")
    return _serialise_trip(trip)


def get_trip_or_404(session: Session, trip_id: str) -> Trip:
    """Return the Trip ORM object or raise 404."""
    trip = session.get(Trip, trip_id)
    if not trip:
        raise HTTPException(status_code=404, detail="TRIP_NOT_FOUND")
    return trip


def _serialise_trip(trip: Trip) -> dict:
    return {
        "id": trip.id,
        "destination": trip.destination,
        "startDate": trip.start_date.isoformat(),
        "endDate": trip.end_date.isoformat(),
    }
