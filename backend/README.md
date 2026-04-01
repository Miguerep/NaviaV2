## Navia Backend (Python + uv)

This backend is separated from the Flutter app and managed with `uv`.

### Run

1. Copy env:
   - `cp .env.example .env` (or create `.env` on Windows)
2. Start API:
   - `uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8787`

### Endpoints

- `GET /health`
- `POST /v1/trips`
- `GET /v1/trips/{trip_id}`
- `GET /v1/itinerary/{trip_id}/{day}`
- `POST /v1/itinerary/{trip_id}/regenerate`
- `GET /v1/places/search?q=...`
- `GET /v1/route?from=lat,lng&to=lat,lng`

### Notes

- Keep `MAPBOX_TOKEN` only in backend `.env`.
- Flutter app can keep using `http://127.0.0.1:8787`.
