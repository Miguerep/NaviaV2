from datetime import date

from pydantic import BaseModel


class CreateTripRequest(BaseModel):
    destination: str
    startDate: str
    endDate: str


class RegeneratePlanRequest(BaseModel):
    date: str
    reason: str | None = None


class ChatRequest(BaseModel):
    tripId: str
    activeDate: str
    userMessage: str
    locationHint: str | None = None
    preferences: dict | None = None


class PlaceResult(BaseModel):
    id: str
    name: str
    placeName: str
    center: dict | None
    categories: list[str]


def parse_date(iso_date: str) -> date:
    return date.fromisoformat(iso_date[:10])

