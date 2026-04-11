from __future__ import annotations

from typing import Any

import httpx


OSRM_BASE_URL = "https://router.project-osrm.org"


def _parse_lat_lng(pair: str) -> tuple[float, float]:
    lat_s, lng_s = pair.split(",")
    return float(lat_s), float(lng_s)


async def get_walking_route(
    from_coords: str,
    to_coords: str,
    *,
    overview: str = "simplified",
    steps: bool = True,
) -> dict[str, Any]:
    """
    Walking route via OSRM public demo (no API key).

    Notes:
    - Public demo is rate-limited / best-effort.
    - For production, consider self-hosting OSRM or using a hosted routing provider.
    """
    from_lat, from_lng = _parse_lat_lng(from_coords)
    to_lat, to_lng = _parse_lat_lng(to_coords)

    coords = f"{from_lng},{from_lat};{to_lng},{to_lat}"
    url = f"{OSRM_BASE_URL}/route/v1/foot/{coords}"
    params = {
        "overview": overview,
        "geometries": "geojson",
        "steps": "true" if steps else "false",
    }

    async with httpx.AsyncClient(timeout=20.0) as client:
        resp = await client.get(url, params=params)
        resp.raise_for_status()
        data = resp.json()

    routes = data.get("routes", []) if isinstance(data, dict) else []
    if not routes:
        return {"distanceMeters": None, "durationSeconds": None, "geometry": None, "legs": None}

    route = routes[0] if isinstance(routes[0], dict) else {}
    return {
        "distanceMeters": route.get("distance"),
        "durationSeconds": route.get("duration"),
        "geometry": route.get("geometry"),
        "legs": route.get("legs"),
        "source": "osrm",
    }

