import json
import logging

from fastapi import APIRouter, Depends, Request
from fastapi.responses import Response
from sqlmodel import Session

from app.config import settings
from app.db import get_session
from app.schemas import NarrationSummaryRequest, NarrationSummaryResponse
from app.services import trip_service
from app.services.elevenlabs_service import generate_speech

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/v1/narration", tags=["narration"])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _build_narration_text(
    title: str,
    subtitle: str | None,
    lang: str,
    destination: str | None = None,
) -> str:
    """Build a rich narration blurb.  Uses Gemini when available."""
    from google import genai
    from google.genai import types

    key = settings.gemini_api_key
    if key:
        prompt = (
            f"Write a short, engaging audio-guide narration (3–5 sentences) about "
            f'"{title}"'
            + (f' — "{subtitle}"' if subtitle else "")
            + (f" in {destination}" if destination else "")
            + f".  Respond ONLY in the language whose BCP-47 code is '{lang}'.  "
            "Do NOT include any headings, markdown, or code fences — just plain spoken text."
        )
        try:
            client = genai.Client(api_key=key)
            resp = client.models.generate_content(
                model="gemini-2.0-flash",
                contents=[prompt],
                config=types.GenerateContentConfig(temperature=0.8),
            )
            text = resp.text.strip()
            if text:
                return text
        except Exception as exc:
            logger.warning("Gemini narration failed, using static fallback: %s", exc)

    # Static fallback
    if lang.startswith("es"):
        text = f"{title}. {subtitle}".strip() if subtitle else f"{title}. Un lugar destacado de tu itinerario. Historia y contexto en breve."
    else:
        text = f"{title}. {subtitle}".strip() if subtitle else f"{title}. A highlight in your itinerary. A brief historical overview will play here."
    return text


def _lang_to_elevenlabs_code(lang: str) -> str | None:
    """Map BCP-47–style codes to ElevenLabs language_code values."""
    mapping = {
        "en": "en",
        "es": "es",
        "fr": "fr",
        "de": "de",
        "it": "it",
        "pt": "pt",
        "ja": "ja",
        "ko": "ko",
        "zh": "zh",
    }
    base = lang.split("-")[0].split("_")[0].lower()
    return mapping.get(base)


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.post("/summary", response_model=NarrationSummaryResponse)
def narration_summary(
    payload: NarrationSummaryRequest,
    request: Request,
    session: Session = Depends(get_session),
):
    """Return a narration text string (legacy / lightweight endpoint)."""
    trip = trip_service.get_trip_or_404(session, payload.tripId)
    accept_language = request.headers.get("accept-language") or "en"
    lang = accept_language.split(",")[0].strip().lower()

    title = payload.stopTitle.strip()
    subtitle = (payload.stopSubtitle or "").strip()
    destination = (trip.destination or "").strip() or None

    text = _build_narration_text(title, subtitle, lang, destination)
    return NarrationSummaryResponse(text=text)


@router.post("/audio")
async def narration_audio(
    payload: NarrationSummaryRequest,
    request: Request,
    session: Session = Depends(get_session),
):
    """
    Generate narration and return MP3 audio bytes via ElevenLabs.

    Falls back to a JSON text response if the ElevenLabs key is missing.
    """
    trip = trip_service.get_trip_or_404(session, payload.tripId)
    accept_language = request.headers.get("accept-language") or "en"
    lang = accept_language.split(",")[0].strip().lower()

    title = payload.stopTitle.strip()
    subtitle = (payload.stopSubtitle or "").strip()
    destination = (trip.destination or "").strip() or None

    narration_text = _build_narration_text(title, subtitle, lang, destination)

    el_lang = _lang_to_elevenlabs_code(lang)
    audio_bytes = await generate_speech(
        narration_text,
        language_code=el_lang,
    )

    if audio_bytes:
        return Response(
            content=audio_bytes,
            media_type="audio/mpeg",
            headers={"Content-Disposition": "inline; filename=narration.mp3"},
        )

    # Fallback: return text so the client can use on-device TTS
    return NarrationSummaryResponse(text=narration_text)
