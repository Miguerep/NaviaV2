from fastapi import APIRouter, Depends
from sqlmodel import Session

from app.db import get_session
from app.schemas import RegeneratePlanRequest
from app.services import itinerary_service, trip_service

router = APIRouter(prefix="/v1/itinerary", tags=["itinerary"])


@router.get("/{trip_id}/{day}")
def get_day_plan(trip_id: str, day: str, session: Session = Depends(get_session)):
    trip_service.get_trip_or_404(session, trip_id)
    return itinerary_service.get_day_plan_response(session, trip_id, day)


@router.post("/{trip_id}/regenerate")
def regenerate_day_plan(
    trip_id: str,
    payload: RegeneratePlanRequest,
    session: Session = Depends(get_session),
):
    trip_service.get_trip_or_404(session, trip_id)
    return itinerary_service.regenerate_day_plan(session, trip_id, payload.date)
