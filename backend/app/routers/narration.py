from fastapi import APIRouter, Depends, Request
from sqlmodel import Session

from app.db import get_session
from app.schemas import NarrationSummaryRequest, NarrationSummaryResponse
from app.services import trip_service

router = APIRouter(prefix="/v1/narration", tags=["narration"])


@router.post("/summary", response_model=NarrationSummaryResponse)
def narration_summary(
    payload: NarrationSummaryRequest,
    request: Request,
    session: Session = Depends(get_session),
):
    trip_service.get_trip_or_404(session, payload.tripId)
    accept_language = request.headers.get("accept-language") or "en"
    lang = accept_language.split(",")[0].strip().lower()

    title = payload.stopTitle.strip()
    subtitle = (payload.stopSubtitle or "").strip()

    if lang.startswith("es"):
        text = f"{title}. {subtitle}".strip()
        if not subtitle:
            text = f"{title}. Un lugar destacado de tu itinerario. Historia y contexto en breve."
        return NarrationSummaryResponse(text=text)

    # Default: English
    text = f"{title}. {subtitle}".strip()
    if not subtitle:
        text = f"{title}. A highlight in your itinerary. A brief historical overview will play here."
    return NarrationSummaryResponse(text=text)

