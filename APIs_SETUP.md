## Objetivo

Este repo incluye un **cliente Flutter** (`app/`) y un **backend FastAPI** (`backend/`).  
La integración actual de mapas/búsqueda/rutas usa **Mapbox** en el backend (requiere token).  
Además, se añadieron integraciones **gratuitas** y **sin claves** (o con free tier) como módulos opcionales, sin modificar el código existente.

## Backend (FastAPI) — variables de entorno

1. Copia el ejemplo:
   - `backend/.env.example` → `backend/.env`
2. Rellena solo lo que necesites:
   - **MAPBOX_TOKEN**: (opcional) necesario para los endpoints existentes:
     - `GET /v1/places/search`
     - `GET /v1/route`
   - **OPENROUTESERVICE_API_KEY**: (opcional) alternativa de ruteo con free tier.

### Cómo obtener claves

- **Mapbox**
  - Crea una cuenta en Mapbox, genera un Access Token (secret) y colócalo en `MAPBOX_TOKEN`.
  - Nota: el backend ya está preparado para devolver `MAPBOX_NOT_CONFIGURED` si no existe.

- **OpenRouteService (opcional)**
  - Crea una cuenta en OpenRouteService, genera una API key y colócala en `OPENROUTESERVICE_API_KEY`.

## Backend — APIs gratuitas sin clave (listas para usar)

Se han añadido servicios **modulares** (no conectados automáticamente a routers existentes):

- **Nominatim (OpenStreetMap)** para geocoding / búsqueda de lugares (sin clave)
- **OSRM (demo pública)** para rutas (sin clave; recomendado self-host si crece el tráfico)
- **Wikipedia REST API** para resúmenes de lugares (sin clave)

Archivos:
- `backend/app/features/api/osm_nominatim_service.py`
- `backend/app/features/api/osrm_service.py`
- `backend/app/features/api/wikipedia_service.py`

## Backend — endpoint de ruta sin Mapbox (OSRM)

Para no modificar el endpoint existente `/v1/route` (Mapbox), se añadió un endpoint **nuevo**:

- `GET /v1/osm/route?from=lat,lng&to=lat,lng`

Se expone desde un entrypoint alternativo:

- `backend/app/main_osm.py`

Arranque:
- `uv run uvicorn app.main_osm:app --reload --host 0.0.0.0 --port 8787`

## App Flutter — configuración (sin `.env`)

Flutter usa `--dart-define` (ver `app/lib/config/app_env.dart`).

Ejemplos:

- Backend local:
  - `--dart-define=API_URL=http://127.0.0.1:8787`

- Token público (si lo necesitases en cliente):
  - `--dart-define=MAPBOX_PUBLIC_TOKEN=...`

Se incluye un ejemplo en `app/.env.example` como referencia (no se carga automáticamente por Flutter).

## Mapas en Flutter (Leaflet/OSM)

El proyecto ya usa `flutter_map` (Leaflet en Flutter) y `latlong2`.  
Se añadió un widget modular basado en **OpenStreetMap**:

- `app/lib/components/external/osm_map_view.dart`

Puedes importarlo y usarlo donde quieras sin cambiar estilos/arquitectura actual.

