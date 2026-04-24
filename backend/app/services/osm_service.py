"""OSM-based geocoding and routing service.

Geocoding uses a 3-tier fallback chain so that POI names that Nominatim
misses are still resolved:

  1. Nominatim  — official OSM geocoder, great for addresses & known OSM nodes
  2. Photon     — Komoot's OSM geocoder, better at full-text POI search
  3. Wikipedia  — geosearch, excellent for famous landmarks worldwide

Routing uses the public OSRM demo server (walking profile).
"""

import logging
from urllib.parse import quote

import httpx
from fastapi import HTTPException

logger = logging.getLogger(__name__)

USER_AGENT = "NaviaApp/1.0 (contact@navia.app)"
_HEADERS = {"User-Agent": USER_AGENT}
_TIMEOUT = 10.0


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


async def search_places(q: str, near: str | None, limit: int) -> dict:
    """Geocode *q* using a Nominatim → Photon → Wikipedia fallback chain."""
    near_lat, near_lng = _parse_near(near)

    async with httpx.AsyncClient(timeout=_TIMEOUT, headers=_HEADERS) as client:
        # 1️⃣  Nominatim
        results = await _nominatim(client, q, near_lat, near_lng, limit)
        if results:
            logger.debug("Geocoder: Nominatim found %d result(s) for %r", len(results), q)
            return {"results": results[:limit]}

        # 2️⃣  Photon (better at landmark / POI names)
        results = await _photon(client, q, near_lat, near_lng, limit)
        if results:
            logger.debug("Geocoder: Photon found %d result(s) for %r", len(results), q)
            return {"results": results[:limit]}

        # 3️⃣  Wikipedia geosearch (great for famous places)
        results = await _wikipedia_geosearch(client, q, near_lat, near_lng, limit)
        if results:
            logger.debug("Geocoder: Wikipedia found %d result(s) for %r", len(results), q)
            return {"results": results[:limit]}

    logger.debug("Geocoder: no results for %r after all fallbacks", q)
    return {"results": []}


async def get_walking_route(from_coords: str, to_coords: str) -> dict:
    """Fetch a walking route between two coordinate pairs via OSRM."""
    try:
        from_lat, from_lng = from_coords.split(",")
        to_lat, to_lng = to_coords.split(",")
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="BAD_REQUEST") from exc

    coords = f"{from_lng},{from_lat};{to_lng},{to_lat}"
    url = f"https://router.project-osrm.org/route/v1/foot/{coords}"
    params = {
        "geometries": "geojson",
        "overview": "simplified",
        "steps": "true",
    }

    async with httpx.AsyncClient(timeout=20.0, headers=_HEADERS) as client:
        resp = await client.get(url, params=params)
        if resp.status_code >= 400:
            raise HTTPException(status_code=502, detail="OSRM_ERROR")
        data = resp.json()

    routes = data.get("routes", [])
    if not routes:
        raise HTTPException(status_code=502, detail="OSRM_NO_ROUTE")

    route = routes[0]
    return {
        "distanceMeters": route.get("distance"),
        "durationSeconds": route.get("duration"),
        "geometry": route.get("geometry"),
        "legs": route.get("legs"),
    }


# ---------------------------------------------------------------------------
# Geocoder implementations
# ---------------------------------------------------------------------------


async def _nominatim(
    client: httpx.AsyncClient,
    q: str,
    near_lat: float | None,
    near_lng: float | None,
    limit: int,
) -> list[dict]:
    """Query Nominatim. Returns normalised result list (may be empty)."""
    params: dict[str, str | int] = {
        "q": q,
        "format": "json",
        "limit": limit,
        "addressdetails": 0,
    }
    try:
        resp = await client.get(
            "https://nominatim.openstreetmap.org/search", params=params
        )
        if resp.status_code >= 400:
            return []
        return [_from_nominatim(item) for item in resp.json()]
    except Exception as exc:
        logger.warning("Nominatim error: %s", exc)
        return []


async def _photon(
    client: httpx.AsyncClient,
    q: str,
    near_lat: float | None,
    near_lng: float | None,
    limit: int,
) -> list[dict]:
    """Query Photon (https://photon.komoot.io). Returns normalised list."""
    params: dict[str, str | int | float] = {"q": q, "limit": limit}
    if near_lat is not None and near_lng is not None:
        params["lat"] = near_lat
        params["lon"] = near_lng
    try:
        resp = await client.get("https://photon.komoot.io/api/", params=params)
        if resp.status_code >= 400:
            return []
        return [
            _from_photon(f)
            for f in resp.json().get("features", [])
            if _from_photon(f) is not None
        ]
    except Exception as exc:
        logger.warning("Photon error: %s", exc)
        return []


async def _wikipedia_geosearch(
    client: httpx.AsyncClient,
    q: str,
    near_lat: float | None,
    near_lng: float | None,
    limit: int,
) -> list[dict]:
    """Use Wikipedia's geosearch + opensearch to locate famous places.

    Strategy:
      a) If we have a proximity hint → Wikipedia geosearch (radius 10 km)
      b) Otherwise → OpenSearch to find the page, then read its coordinates.
    """
    try:
        if near_lat is not None and near_lng is not None:
            return await _wiki_geosearch_near(client, q, near_lat, near_lng, limit)
        return await _wiki_opensearch_coords(client, q, limit)
    except Exception as exc:
        logger.warning("Wikipedia geosearch error: %s", exc)
        return []


# ---------------------------------------------------------------------------
# Wikipedia sub-strategies
# ---------------------------------------------------------------------------

_WIKI_API = "https://en.wikipedia.org/w/api.php"


async def _wiki_geosearch_near(
    client: httpx.AsyncClient,
    q: str,
    lat: float,
    lng: float,
    limit: int,
) -> list[dict]:
    """Find Wikipedia pages near a coord whose title matches the query."""
    params = {
        "action": "query",
        "list": "geosearch",
        "gscoord": f"{lat}|{lng}",
        "gsradius": 10000,  # 10 km
        "gslimit": min(limit * 4, 50),
        "format": "json",
    }
    resp = await client.get(_WIKI_API, params=params)
    if resp.status_code >= 400:
        return []

    pages = resp.json().get("query", {}).get("geosearch", [])
    q_lower = q.lower()
    # Keep pages whose title loosely matches the query words
    matches = [
        p for p in pages
        if any(word in p.get("title", "").lower() for word in q_lower.split() if len(word) > 3)
    ]
    # Fall back to top results even if names don't match
    candidates = matches or pages
    return [_from_wiki_page(p) for p in candidates[:limit]]


async def _wiki_opensearch_coords(
    client: httpx.AsyncClient,
    q: str,
    limit: int,
) -> list[dict]:
    """Resolve query → Wikipedia title → page coordinates."""
    # Step 1: OpenSearch to get the canonical title
    search_params = {
        "action": "opensearch",
        "search": q,
        "limit": limit,
        "namespace": 0,
        "format": "json",
    }
    resp = await client.get(_WIKI_API, params=search_params)
    if resp.status_code >= 400:
        return []
    data = resp.json()
    titles: list[str] = data[1] if len(data) > 1 else []
    if not titles:
        return []

    # Step 2: Fetch coordinates for those titles
    coord_params = {
        "action": "query",
        "titles": "|".join(titles[:limit]),
        "prop": "coordinates",
        "format": "json",
    }
    resp2 = await client.get(_WIKI_API, params=coord_params)
    if resp2.status_code >= 400:
        return []

    pages = resp2.json().get("query", {}).get("pages", {})
    results = []
    for page in pages.values():
        coords = page.get("coordinates", [])
        if not coords:
            continue
        c = coords[0]
        results.append({
            "id": f"wiki:{page.get('pageid', '')}",
            "name": page.get("title", q),
            "placeName": page.get("title", q),
            "center": {"lat": c["lat"], "lng": c["lon"]},
            "categories": ["wikipedia"],
        })
    return results


# ---------------------------------------------------------------------------
# Normalisation helpers
# ---------------------------------------------------------------------------


def _from_nominatim(item: dict) -> dict:
    lat_str = item.get("lat")
    lon_str = item.get("lon")
    center = None
    if lat_str and lon_str:
        try:
            center = {"lat": float(lat_str), "lng": float(lon_str)}
        except ValueError:
            pass
    categories = [item.get("class", ""), item.get("type", "")]
    categories = [c.strip() for c in categories if c.strip()]
    return {
        "id": str(item.get("place_id", "")),
        "name": item.get("name") or str(item.get("display_name", "")).split(",")[0],
        "placeName": str(item.get("display_name", "")),
        "center": center,
        "categories": categories,
    }


def _from_photon(feature: dict) -> dict | None:
    props = feature.get("properties", {})
    geom = feature.get("geometry", {})
    coords = geom.get("coordinates")
    if not isinstance(coords, list) or len(coords) < 2:
        return None
    name = (
        props.get("name")
        or props.get("street")
        or props.get("city")
        or "Unknown"
    )
    city = props.get("city") or props.get("county") or ""
    country = props.get("country") or ""
    place_name = ", ".join(p for p in [name, city, country] if p)
    osm_type = props.get("osm_type") or ""
    osm_value = props.get("osm_value") or ""
    return {
        "id": f"photon:{props.get('osm_id', '')}",
        "name": name,
        "placeName": place_name,
        "center": {"lat": coords[1], "lng": coords[0]},
        "categories": [c for c in [osm_type, osm_value] if c],
    }


def _from_wiki_page(page: dict) -> dict:
    return {
        "id": f"wiki:{page.get('pageid', '')}",
        "name": page.get("title", ""),
        "placeName": page.get("title", ""),
        "center": {"lat": page.get("lat"), "lng": page.get("lon")},
        "categories": ["wikipedia"],
    }


def _parse_near(near: str | None) -> tuple[float | None, float | None]:
    if not near:
        return None, None
    try:
        lat_s, lng_s = near.split(",")
        return float(lat_s), float(lng_s)
    except (ValueError, AttributeError):
        return None, None
