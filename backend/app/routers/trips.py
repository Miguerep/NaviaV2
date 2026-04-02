from fastapi import APIRouter, Depends
from sqlmodel import Session

from app.db import get_session
from app.schemas import CreateTripRequest
from app.services import trip_service

router = APIRouter(prefix="/v1/trips", tags=["trips"])


@router.post("")
def create_trip(payload: CreateTripRequest, session: Session = Depends(get_session)):
    return {"trip": trip_service.create_trip(session, payload)}


@router.get("/{trip_id}")
def get_trip(trip_id: str, session: Session = Depends(get_session)):
    return {"trip": trip_service.get_trip(session, trip_id)}
