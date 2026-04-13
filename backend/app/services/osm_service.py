import httpx
from fastapi import HTTPException
from fastapi.responses import JSONResponse


USER_AGENT = "NaviaApp/1.0 (contact@navia.app)"


async def search_places(q: str, near: str | None, limit: int) -> dict | JSONResponse:
    """Forward a geocoding query to Nominatim (OSM) and normalise the response."""
    url = "https://nominatim.openstreetmap.org/search"
    params: dict[str, str | int] = {
        "q": q,
        "format": "json",
        "limit": limit,
        "addressdetails": 0,
    }

    if near:
        try:
            lat, lng = near.split(",")
        except ValueError as exc:
            raise HTTPException(status_code=400, detail="BAD_NEAR_FORMAT") from exc
        # Nominatim supports viewbox for bounding box preference, but a simple
        # workaround is to just pass it in the query if we wanted. For now we will
        # omit the proximity since Nominatim's q handles free-text.

    headers = {"User-Agent": USER_AGENT}

    async with httpx.AsyncClient(timeout=20.0, headers=headers) as client:
        resp = await client.get(url, params=params)
        if resp.status_code >= 400:
            raise HTTPException(status_code=502, detail="OSM_ERROR")
        data = resp.json()

    results = []
    for item in data:
        # Nominatim returns type/class which we map to categories
        categories = [item.get("class", ""), item.get("type", "")]
        categories = [c.strip() for c in categories if c.strip()]

        lat_str = item.get("lat")
        lon_str = item.get("lon")
        center_obj = None
        if lat_str and lon_str:
            try:
                center_obj = {"lat": float(lat_str), "lng": float(lon_str)}
            except ValueError:
                pass

        results.append(
            {
                "id": str(item.get("place_id", "")),
                "name": item.get("name") or str(item.get("display_name", "")).split(",")[0],
                "placeName": str(item.get("display_name", "")),
                "center": center_obj,
                "categories": categories,
            }
        )

    return {"results": results}


async def get_walking_route(from_coords: str, to_coords: str) -> dict | JSONResponse:
    """Fetch a walking route between two coordinate pairs from OSRM (OSM)."""
    try:
        from_lat, from_lng = from_coords.split(",")
        to_lat, to_lng = to_coords.split(",")
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="BAD_REQUEST") from exc

    # OSRM expects: {longitude},{latitude};{longitude},{latitude}
    coords = f"{from_lng},{from_lat};{to_lng},{to_lat}"
    url = f"https://router.project-osrm.org/route/v1/foot/{coords}"
    params = {
        "geometries": "geojson",
        "overview": "simplified",
        "steps": "true",
    }
    
    headers = {"User-Agent": USER_AGENT}

    async with httpx.AsyncClient(timeout=20.0, headers=headers) as client:
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
