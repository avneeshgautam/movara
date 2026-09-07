"""Movara's fitness assistant.

Supports two providers: Gemini (free tier) and Anthropic (paid). The client
sends the whole short conversation; this stays stateless. Keys live only in
the server environment, so they never reach the app.
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
    provider = config.chat_provider()
    if provider is None:
        raise HTTPException(
            status_code=503,
            detail="The assistant isn't set up yet. Add a GEMINI_API_KEY "
            "(free) or ANTHROPIC_API_KEY on the server.",
        )

    messages = [
        {"role": m.role, "content": m.content}
        for m in req.messages
        if m.content.strip()
    ][-_MAX_TURNS:]
    if not messages:
        raise HTTPException(status_code=400, detail="Say something first.")

    try:
        if provider == "gemini":
            reply = _call_gemini(messages)
        else:
            reply = _call_anthropic(messages)
    except httpx.HTTPError as exc:
        logger.warning("Chat upstream error: %s", exc)
        raise HTTPException(status_code=502, detail="Couldn't reach the assistant.")

    return ChatResponse(reply=reply or "…")


def _call_anthropic(messages: list[dict]) -> str:
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
    _ensure_ok(response)
    data = response.json()
    return "".join(
        part.get("text", "")
        for part in data.get("content", [])
        if part.get("type") == "text"
    ).strip()


def _call_gemini(messages: list[dict]) -> str:
    # Gemini uses "model" where Anthropic uses "assistant"; the key goes in a
    # header (not the URL) to keep the secret out of logs.
    contents = [
        {
            "role": "model" if m["role"] == "assistant" else "user",
            "parts": [{"text": m["content"]}],
        }
        for m in messages
    ]
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{config.GEMINI_MODEL}:generateContent"
    )
    response = httpx.post(
        url,
        headers={
            "x-goog-api-key": config.GEMINI_API_KEY,
            "content-type": "application/json",
        },
        json={
            "system_instruction": {"parts": [{"text": _SYSTEM}]},
            "contents": contents,
            "generationConfig": {"maxOutputTokens": config.CHAT_MAX_TOKENS},
        },
        timeout=60,
    )
    _ensure_ok(response)
    data = response.json()
    candidates = data.get("candidates", [])
    if not candidates:
        return ""
    parts = candidates[0].get("content", {}).get("parts", [])
    return "".join(p.get("text", "") for p in parts).strip()


def _ensure_ok(response: httpx.Response) -> None:
    if response.status_code != 200:
        # Log the provider's message for us, but don't leak it to the client.
        logger.warning("Chat API %s: %s", response.status_code, response.text[:300])
        raise HTTPException(
            status_code=502, detail="The assistant is unavailable right now."
        )
