from __future__ import annotations

from typing import Any

import httpx


WIKI_REST_BASE = "https://en.wikipedia.org/api/rest_v1"


async def get_summary(
    title: str,
    *,
    accept_language: str | None = None,
) -> dict[str, Any]:
    """
    Fetch a concise summary for a place/topic from Wikipedia REST API (no key).
    """
    headers: dict[str, str] = {"User-Agent": "navia-backend/0.1"}
    if accept_language:
        headers["Accept-Language"] = accept_language

    url = f"{WIKI_REST_BASE}/page/summary/{title}"
    async with httpx.AsyncClient(timeout=20.0) as client:
        resp = await client.get(url, headers=headers)
        resp.raise_for_status()
        data = resp.json()

    if not isinstance(data, dict):
        return {"title": title, "extract": None, "url": None, "thumbnail": None}

    content_urls = data.get("content_urls") if isinstance(data.get("content_urls"), dict) else {}
    desktop = content_urls.get("desktop") if isinstance(content_urls.get("desktop"), dict) else {}
    page_url = desktop.get("page")

    thumbnail = data.get("thumbnail") if isinstance(data.get("thumbnail"), dict) else None
    thumb_url = thumbnail.get("source") if isinstance(thumbnail, dict) else None

    return {
        "title": data.get("title") or title,
        "extract": data.get("extract"),
        "url": page_url,
        "thumbnail": thumb_url,
        "source": "wikipedia",
    }

