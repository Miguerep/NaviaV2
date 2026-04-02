import uuid

from sqlmodel import Session

from app.models import ChatMessage, ChatRole
from app.services.itinerary_service import replace_stops


def build_actions(user_message: str) -> list[dict]:
    """Determine actions based on the user message (stub / rule-based).

    TODO: Replace with a real LLM integration (e.g. OpenAI, Gemini)
    when ready.
    """
    text = user_message.lower()

    if any(kw in text for kw in ("rain", "raining", "indoor")):
        return [
            {
                "type": "ReplaceDayPlan",
                "reason": "Weather-adjusted to indoor activities",
                "stops": [
                    {"title": "Indoor Museum", "subtitle": "Weather-safe", "startTimeLocal": "10:00"},
                    {"title": "Coffee Shop", "subtitle": "Nearby warm stop", "startTimeLocal": "12:00"},
                ],
            }
        ]

    if any(kw in text for kw in ("suggest", "recommend")):
        return [
            {
                "type": "SuggestPOIs",
                "items": [
                    {"name": "Local Museum", "category": "museum"},
                    {"name": "Historic Cafe", "category": "food"},
                ],
            }
        ]

    return []


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


def apply_actions(session: Session, trip_id: str, active_date: str, actions: list[dict]) -> None:
    """Apply side-effects for recognised action types."""
    replace_action = next((a for a in actions if a.get("type") == "ReplaceDayPlan"), None)
    if replace_action:
        replace_stops(session, trip_id, active_date, replace_action.get("stops", []))


def generate_assistant_reply(actions: list[dict]) -> str:
    """Produce a reply string depending on whether actions were triggered."""
    if actions:
        return "I updated your itinerary based on your request."
    return "Got it. I can adjust your day plan when needed."
