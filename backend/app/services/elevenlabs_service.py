"""ElevenLabs Text-to-Speech integration for Navia narration."""
import logging

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

# Defaults – multilingual model supports 29 languages automatically.
_DEFAULT_VOICE_ID = "EXAVITQu4vr4xnSDxMaL"  # "Sarah" – neutral, clear.
_DEFAULT_MODEL_ID = "eleven_multilingual_v2"
_TTS_URL = "https://api.elevenlabs.io/v1/text-to-speech"


async def generate_speech(
    text: str,
    *,
    voice_id: str | None = None,
    model_id: str | None = None,
    language_code: str | None = None,
) -> bytes | None:
    """
    Call the ElevenLabs TTS API and return raw MP3 bytes.

    Returns ``None`` when the API key is missing or the request fails,
    so the caller can fall back to on-device TTS gracefully.
    """
    api_key = settings.elevenlabs_api_key
    if not api_key:
        logger.warning("ELEVENLABS_API_KEY not set – skipping cloud TTS.")
        return None

    vid = voice_id or _DEFAULT_VOICE_ID
    mid = model_id or _DEFAULT_MODEL_ID
    url = f"{_TTS_URL}/{vid}"

    headers = {
        "xi-api-key": api_key,
        "Content-Type": "application/json",
        "Accept": "audio/mpeg",
    }
    payload: dict = {
        "text": text,
        "model_id": mid,
        "voice_settings": {
            "stability": 0.5,
            "similarity_boost": 0.75,
        },
    }
    if language_code:
        payload["language_code"] = language_code

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(url, json=payload, headers=headers)
            if resp.status_code >= 400:
                logger.error(
                    "ElevenLabs API error %s: %s",
                    resp.status_code,
                    resp.text[:300],
                )
                return None
            return resp.content
    except Exception as exc:
        logger.error("ElevenLabs request failed: %s", exc)
        return None
