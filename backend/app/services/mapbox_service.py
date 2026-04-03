import httpx
from fastapi import HTTPException
from fastapi.responses import JSONResponse

from app.config import settings


async def search_places(q: str, near: str | None, limit: int) -> dict | JSONResponse:
    """Forward a geocoding query to Mapbox and normalise the response."""
    if not settings.mapbox_token:
        return JSONResponse(
            status_code=501,
            content={
                "error": "MAPBOX_NOT_CONFIGURED",
                "message": "Set MAPBOX_TOKEN in backend .env.",
            },
        )

    url = f"https://api.mapbox.com/geocoding/v5/mapbox.places/{q}.json"
    params: dict[str, str] = {
        "access_token": settings.mapbox_token,
        "limit": str(limit),
        "autocomplete": "true",
    }
    if near:
        try:
            lat, lng = near.split(",")
        except ValueError as exc:
            raise HTTPException(status_code=400, detail="BAD_NEAR_FORMAT") from exc
        params["proximity"] = f"{lng},{lat}"

    async with httpx.AsyncClient(timeout=20.0) as client:
        resp = await client.get(url, params=params)
        if resp.status_code >= 400:
            raise HTTPException(status_code=502, detail="MAPBOX_ERROR")
        data = resp.json()

    results = []
    for feature in data.get("features", []):
        categories_raw = feature.get("properties", {}).get("category")
        categories = (
            [c.strip() for c in categories_raw.split(",") if c.strip()]
            if isinstance(categories_raw, str)
            else []
        )

        center = feature.get("center")
        center_obj = (
            {"lng": center[0], "lat": center[1]}
            if isinstance(center, list) and len(center) == 2
            else None
        )

        results.append(
            {
                "id": str(feature.get("id", "")),
                "name": str(feature.get("text", "")),
                "placeName": str(feature.get("place_name", "")),
                "center": center_obj,
                "categories": categories,
            }
        )

    return {"results": results}


async def get_walking_route(from_coords: str, to_coords: str) -> dict | JSONResponse:
    """Fetch a walking route between two coordinate pairs from Mapbox."""
    if not settings.mapbox_token:
        return JSONResponse(
            status_code=501,
            content={
                "error": "MAPBOX_NOT_CONFIGURED",
                "message": "Set MAPBOX_TOKEN in backend .env.",
            },
        )

    try:
        from_lat, from_lng = from_coords.split(",")
        to_lat, to_lng = to_coords.split(",")
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="BAD_REQUEST") from exc

    coords = f"{from_lng},{from_lat};{to_lng},{to_lat}"
    url = f"https://api.mapbox.com/directions/v5/mapbox/walking/{coords}"
    params = {
        "access_token": settings.mapbox_token,
        "geometries": "geojson",
        "overview": "simplified",
        "steps": "true",
    }

    async with httpx.AsyncClient(timeout=20.0) as client:
        resp = await client.get(url, params=params)
        if resp.status_code >= 400:
            raise HTTPException(status_code=502, detail="MAPBOX_ERROR")
        data = resp.json()

    routes = data.get("routes", [])
    if not routes:
        raise HTTPException(status_code=502, detail="MAPBOX_NO_ROUTE")

    route = routes[0]
    return {
        "distanceMeters": route.get("distance"),
        "durationSeconds": route.get("duration"),
        "geometry": route.get("geometry"),
        "legs": route.get("legs"),
    }
