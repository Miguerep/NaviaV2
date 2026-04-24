"""Fetch a short Wikipedia summary for a given search query.

Uses the Wikipedia REST API (no API key required):
  https://en.wikipedia.org/api/rest_v1/page/summary/{title}

Flow:
  1. Use the OpenSearch API to resolve a free-text query → canonical title.
  2. Fetch the /summary endpoint with that title.
  3. Return a plain-text extract capped at `max_chars` characters.
"""

import logging

import httpx

logger = logging.getLogger(__name__)

_HEADERS = {"User-Agent": "NaviaApp/1.0 (contact@navia.app)"}
_SEARCH_URL = "https://en.wikipedia.org/w/api.php"
_SUMMARY_URL = "https://en.wikipedia.org/api/rest_v1/page/summary/{title}"
_TIMEOUT = 8.0  # seconds — keep it short so it never blocks the chat response


async def get_destination_summary(destination: str, max_chars: int = 800) -> str | None:
    """Return a Wikipedia summary for *destination*, or None on any failure.

    Args:
        destination: Free-text place name, e.g. "Paris" or "Kyoto, Japan".
        max_chars:   Maximum characters of the extract to return (avoids
                     bloating the Gemini context window).

    Returns:
        A plain-text extract string, or None if Wikipedia had nothing useful.
    """
    try:
        async with httpx.AsyncClient(headers=_HEADERS, timeout=_TIMEOUT) as client:
            # Step 1 — resolve the destination name to a canonical Wikipedia title
            title = await _resolve_title(client, destination)
            if not title:
                logger.debug("Wikipedia: no title found for %r", destination)
                return None

            # Step 2 — fetch the page summary
            url = _SUMMARY_URL.format(title=title)
            resp = await client.get(url)
            if resp.status_code != 200:
                logger.debug("Wikipedia summary returned %s for %r", resp.status_code, title)
                return None

            data = resp.json()
            extract: str = data.get("extract") or ""
            if not extract:
                return None

            # Trim to max_chars at a sentence boundary where possible
            return _trim(extract, max_chars)

    except Exception as exc:  # noqa: BLE001
        logger.warning("Wikipedia fetch failed for %r: %s", destination, exc)
        return None


async def _resolve_title(client: httpx.AsyncClient, query: str) -> str | None:
    """Use the OpenSearch API to get the best-matching Wikipedia page title."""
    params = {
        "action": "opensearch",
        "search": query,
        "limit": 1,
        "namespace": 0,
        "format": "json",
    }
    resp = await client.get(_SEARCH_URL, params=params)
    if resp.status_code != 200:
        return None

    data = resp.json()
    # OpenSearch returns [query, [titles], [descriptions], [urls]]
    titles: list[str] = data[1] if len(data) > 1 else []
    return titles[0] if titles else None


def _trim(text: str, max_chars: int) -> str:
    """Trim *text* to *max_chars*, preferring to break at a sentence end."""
    if len(text) <= max_chars:
        return text
    truncated = text[:max_chars]
    # Try to cut at the last sentence-ending punctuation
    for sep in (".", "!", "?"):
        idx = truncated.rfind(sep)
        if idx > max_chars // 2:
            return truncated[: idx + 1]
    return truncated.rstrip() + "…"
