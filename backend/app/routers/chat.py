"""Movara's fitness assistant, backed by the Claude Messages API.

The client sends the whole short conversation; this stays stateless. The API
key lives only in the server environment, so it never reaches the app.
"""

import logging

import httpx
from fastapi import APIRouter, Depends, HTTPException

from .. import config
from ..auth import current_uid
from ..models import ChatRequest, ChatResponse

logger = logging.getLogger(__name__)

router = APIRouter()

_ANTHROPIC_URL = "https://api.anthropic.com/v1/messages"

_SYSTEM = (
    "You are Movara's assistant, inside a workout and running tracker app. "
    "Help with training, running, hydration, recovery, nutrition basics and "
    "motivation. Keep replies short, warm and practical, and prefer plain "
    "language over jargon. You are not a doctor: for pain, injury or medical "
    "questions, tell the user to see a professional."
)

# Only the last turns are forwarded, to cap payload and cost.
_MAX_TURNS = 20


@router.post("/api/chat", response_model=ChatResponse)
def chat(req: ChatRequest, uid: str = Depends(current_uid)) -> ChatResponse:
    if not config.ANTHROPIC_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="The assistant isn't set up yet. Add ANTHROPIC_API_KEY on the server.",
        )

    messages = [
        {"role": m.role, "content": m.content}
        for m in req.messages
        if m.content.strip()
    ][-_MAX_TURNS:]
    if not messages:
        raise HTTPException(status_code=400, detail="Say something first.")

    try:
        response = httpx.post(
            _ANTHROPIC_URL,
            headers={
                "x-api-key": config.ANTHROPIC_API_KEY,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            json={
                "model": config.CHAT_MODEL,
                "max_tokens": config.CHAT_MAX_TOKENS,
                "system": _SYSTEM,
                "messages": messages,
            },
            timeout=60,
        )
    except httpx.HTTPError as exc:
        logger.warning("Chat upstream error: %s", exc)
        raise HTTPException(status_code=502, detail="Couldn't reach the assistant.")

    if response.status_code != 200:
        # Log the provider's message for us, but don't leak it to the client.
        logger.warning("Chat API %s: %s", response.status_code, response.text[:300])
        raise HTTPException(
            status_code=502, detail="The assistant is unavailable right now."
        )

    data = response.json()
    reply = "".join(
        part.get("text", "")
        for part in data.get("content", [])
        if part.get("type") == "text"
    ).strip()
    return ChatResponse(reply=reply or "…")
