from datetime import date

from pydantic import BaseModel, model_validator


class CreateTripRequest(BaseModel):
    destination: str
    startDate: date
    endDate: date
    tripDuration: int | None = None
    interests: list[str] = []
    pace: str | None = None
    startLat: float | None = None
    startLng: float | None = None

    @model_validator(mode="after")
    def check_date_order(self) -> "CreateTripRequest":
        if self.startDate > self.endDate:
            raise ValueError("startDate must be on or before endDate")
        return self


class NarrationSummaryRequest(BaseModel):
    tripId: str
    stopTitle: str
    stopSubtitle: str | None = None


class NarrationSummaryResponse(BaseModel):
    text: str


class RegeneratePlanRequest(BaseModel):
    date: date
    reason: str | None = None


class ChatRequest(BaseModel):
    tripId: str
    activeDate: date
    userMessage: str
    locationHint: str | None = None
    preferences: dict | None = None


class PlaceResult(BaseModel):
    id: str
    name: str
    placeName: str
    center: dict | None
    categories: list[str]
