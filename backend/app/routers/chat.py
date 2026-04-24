import asyncio
import json

from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from sqlmodel import Session

from app.db import get_session
from app.schemas import ChatRequest
from app.services import chat_service
from app.services.trip_service import get_trip_or_404

router = APIRouter(prefix="/v1", tags=["chat"])


@router.post("/chat")
async def chat(payload: ChatRequest, session: Session = Depends(get_session)):
    get_trip_or_404(session, payload.tripId)
    assistant_text, actions = await chat_service.handle_chat(
        session=session,
        trip_id=payload.tripId,
        plan_day=payload.activeDate,
        user_message=payload.userMessage,
    )

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
