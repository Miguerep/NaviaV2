from __future__ import annotations

from typing import Any

import httpx


NOMINATIM_BASE_URL = "https://nominatim.openstreetmap.org"


async def search_places(
    q: str,
    *,
    limit: int = 5,
    accept_language: str | None = None,
    user_agent: str = "navia-backend/0.1 (contact: set-your-own-user-agent)",
) -> dict[str, Any]:
    """
    Search places via OSM Nominatim (no API key).

    Notes:
    - Nominatim has usage policies; for production/high volume prefer a hosted provider
      or self-hosted Nominatim.
    - We expose a small normalized result shape similar to existing Mapbox response.
    """
    params = {
        "q": q,
        "format": "jsonv2",
        "addressdetails": "1",
        "limit": str(limit),
    }

    headers = {
        # Nominatim requires a valid User-Agent identifying your application.
        "User-Agent": user_agent,
    }
    if accept_language:
        headers["Accept-Language"] = accept_language

    async with httpx.AsyncClient(timeout=20.0) as client:
        resp = await client.get(f"{NOMINATIM_BASE_URL}/search", params=params, headers=headers)
        resp.raise_for_status()
        data = resp.json()

    results: list[dict[str, Any]] = []
    if isinstance(data, list):
        for item in data:
            if not isinstance(item, dict):
                continue
            lat = item.get("lat")
            lon = item.get("lon")
            try:
                lat_f = float(lat) if lat is not None else None
                lon_f = float(lon) if lon is not None else None
            except (TypeError, ValueError):
                lat_f, lon_f = None, None

            display_name = str(item.get("display_name") or "")
            name = str(item.get("name") or display_name.split(",")[0].strip() or display_name)

            results.append(
                {
                    "id": str(item.get("place_id") or ""),
                    "name": name,
                    "placeName": display_name,
                    "center": {"lat": lat_f, "lng": lon_f} if lat_f is not None and lon_f is not None else None,
                    "categories": [str(item.get("type") or "")] if item.get("type") else [],
                    "source": "nominatim",
                }
            )

    return {"results": results}

