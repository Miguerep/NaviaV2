import asyncio
import json

from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from sqlmodel import Session

from app.db import get_session
from app.models import ChatRole
from app.schemas import ChatRequest
from app.services import chat_service, trip_service

router = APIRouter(prefix="/v1", tags=["chat"])


@router.post("/chat")
async def chat(payload: ChatRequest, session: Session = Depends(get_session)):
    trip_service.get_trip_or_404(session, payload.tripId)

    # Persist user message
    chat_service.save_message(session, payload.tripId, ChatRole.user, payload.userMessage)

    # Determine actions & reply
    actions = chat_service.build_actions(payload.userMessage)
    assistant_text = chat_service.generate_assistant_reply(actions)

    # Apply side-effects (e.g. replace day stops)
    chat_service.apply_actions(session, payload.tripId, payload.activeDate, actions)

    # Persist assistant reply
    chat_service.save_message(session, payload.tripId, ChatRole.assistant, assistant_text)

    # Stream the response word-by-word via SSE
    async def event_stream():
        words = assistant_text.split(" ")
        partial = ""
        for w in words:
            partial = f"{partial} {w}".strip()
            yield f"event: message.delta\ndata: {json.dumps({'text': partial})}\n\n"
            await asyncio.sleep(0.03)
        yield f"event: message.final\ndata: {json.dumps({'text': assistant_text})}\n\n"
        yield f"event: actions\ndata: {json.dumps({'actions': actions})}\n\n"

    return StreamingResponse(event_stream(), media_type="text/event-stream")
