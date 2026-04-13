import json
import logging
import uuid
from datetime import date

import google.generativeai as genai
from sqlmodel import Session, select

from app.config import settings
from app.models import ChatMessage, ChatRole, DayPlan, Stop
from app.services.itinerary_service import replace_stops

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Gemini client (initialised lazily so missing key just disables AI)
# ---------------------------------------------------------------------------

def _get_model():
    key = settings.gemini_api_key
    if not key:
        return None
    genai.configure(api_key=key)
    return genai.GenerativeModel("gemini-2.0-flash")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_current_stops(session: Session, trip_id: str, plan_day: date) -> list[dict]:
    """Fetch current stops for the given day so we can pass them to Gemini."""
    plan = session.exec(
        select(DayPlan).where(DayPlan.trip_id == trip_id, DayPlan.day == plan_day)
    ).first()
    if not plan:
        return []
    stops = session.exec(
        select(Stop).where(Stop.day_plan_id == plan.id).order_by(Stop.ordinal)
    ).all()
    return [
        {"ordinal": s.ordinal, "title": s.title, "subtitle": s.subtitle, "startTimeLocal": s.start_time_local}
        for s in stops
    ]


_SYSTEM_PROMPT = """\
You are Navia, a friendly AI travel assistant embedded in a trip-planning app.
The user can ask you to modify their day itinerary.

Rules:
- Always reply in the same language the user writes in.
- If the user wants to change, replace, add or remove any stops, set "rewrite" to true and provide a complete new "stops" list.
- Each stop must have: "title" (string), "subtitle" (string or null), "startTimeLocal" (HH:MM string or null).
- If no itinerary change is needed, set "rewrite" to false and leave "stops" as [].
- Keep "reply" concise and friendly (1–3 sentences).

Respond ONLY with valid JSON matching this exact schema (no markdown, no code fences):
{
  "reply": "<assistant message to show the user>",
  "rewrite": true | false,
  "stops": [
    {"title": "...", "subtitle": "...", "startTimeLocal": "HH:MM"}
  ]
}
"""


def run_ai_chat(
    session: Session,
    trip_id: str,
    plan_day: date,
    user_message: str,
) -> tuple[str, list[dict]]:
    """
    Call Gemini with the user message + current stops as context.
    Returns (assistant_reply, actions_list).
    actions_list is a ReplaceDayPlan action if Gemini decided to rewrite.
    """
    model = _get_model()
    current_stops = _get_current_stops(session, trip_id, plan_day)

    if model is None:
        # No API key – graceful fallback
        logger.warning("GEMINI_API_KEY not set; returning static fallback reply.")
        return "I can help adjust your itinerary! Please add a Gemini API key to enable AI features.", []

    context = (
        f"Current itinerary for {plan_day.isoformat()}:\n"
        + json.dumps(current_stops, ensure_ascii=False, indent=2)
        + f"\n\nUser message: {user_message}"
    )

    try:
        response = model.generate_content(
            [_SYSTEM_PROMPT, context],
            generation_config=genai.GenerationConfig(
                response_mime_type="application/json",
                temperature=0.7,
            ),
        )
        raw = response.text.strip()
        data = json.loads(raw)
    except Exception as exc:
        logger.error("Gemini call failed: %s", exc)
        return "Sorry, I couldn't process your request right now. Please try again.", []

    reply = data.get("reply", "Done!")
    actions: list[dict] = []

    if data.get("rewrite") and data.get("stops"):
        actions.append({
            "type": "ReplaceDayPlan",
            "reason": "AI-generated rewrite",
            "stops": data["stops"],
        })

    return reply, actions


# ---------------------------------------------------------------------------
# Public API (called from the router)
# ---------------------------------------------------------------------------

def handle_chat(
    session: Session,
    trip_id: str,
    plan_day: date,
    user_message: str,
) -> tuple[str, list[dict]]:
    """Full chat pipeline: AI → apply actions → persist messages → return."""
    assistant_text, actions = run_ai_chat(session, trip_id, plan_day, user_message)

    # Apply itinerary changes if any
    replace_action = next((a for a in actions if a.get("type") == "ReplaceDayPlan"), None)
    if replace_action:
        replace_stops(session, trip_id, plan_day, replace_action.get("stops", []))

    # Persist both messages
    save_message(session, trip_id, ChatRole.user, user_message)
    save_message(session, trip_id, ChatRole.assistant, assistant_text)

    return assistant_text, actions


def save_message(session: Session, trip_id: str, role: ChatRole, content: str) -> None:
    """Persist a chat message."""
    session.add(
        ChatMessage(
            id=uuid.uuid4().hex,
            trip_id=trip_id,
            role=role,
            content=content,
        )
    )
    session.commit()
