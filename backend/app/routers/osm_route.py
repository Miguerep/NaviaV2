from fastapi import APIRouter, Query

from app.features.api import osrm_service

router = APIRouter(prefix="/v1/osm", tags=["osm"])


@router.get("/route")
async def get_route_osrm(
    from_: str = Query(..., alias="from"),
    to: str = Query(...),
):
    """
    Routing via OSRM (no API key), kept separate from existing Mapbox route endpoint.
    """
    return await osrm_service.get_walking_route(from_, to)

