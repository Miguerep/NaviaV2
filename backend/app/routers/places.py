from fastapi import APIRouter, Query

from app.services import mapbox_service

router = APIRouter(prefix="/v1", tags=["places"])


@router.get("/places/search")
async def search_places(
    q: str = Query(min_length=1),
    near: str | None = None,
    limit: int = Query(default=5, ge=1, le=10),
):
    return await mapbox_service.search_places(q, near, limit)


@router.get("/route")
async def get_route(
    from_: str = Query(..., alias="from"),
    to: str = Query(...),
):
    return await mapbox_service.get_walking_route(from_, to)
