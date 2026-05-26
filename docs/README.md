# NaviaV2 Technical Documentation

Navia is a smart travel guide and itinerary planner mobile application. It features an intelligent AI backend that generates personalized itineraries, provides interactive audio narration for points of interest, and allows users to modify their plans via a natural language chatbot interface.

This documentation covers the architecture, features, and technology stack of both the Flutter frontend and the FastAPI backend.

---

## 1. System Architecture overview

NaviaV2 is structured as a client-server application:

*   **Frontend (Mobile App):** Built with **Flutter**. It handles user onboarding, displays itineraries, provides interactive maps, and offers voice and text chat interfaces. It manages local state via `provider` and communicates with the backend via REST and Server-Sent Events (SSE) for streaming chat.
*   **Backend (API Server):** Built with **Python (FastAPI)**. It orchestrates AI prompts, integrates with external APIs (Google Gemini, ElevenLabs, OpenStreetMap, Wikipedia), manages the SQLite database via `SQLModel`, and serves data to the mobile client.

---

## 2. Technology Stack

### Frontend (Flutter)
*   **Framework:** Flutter (Dart)
*   **State Management:** `provider` (MultiProvider with `TripProvider`, `ItineraryProvider`, `ChatProvider`, `ExploreProvider`, `AppSettings`)
*   **Mapping:** `flutter_map` (OpenStreetMap integration), `latlong2`
*   **Voice/Audio:** `flutter_tts` (Fallback on-device Text-to-Speech), `speech_to_text` (Voice input), `audioplayers` (Audio playback)
*   **Location:** `geolocator` (GPS coordinates acquisition)
*   **Storage:** `shared_preferences` (Persisting trip IDs and app settings)
*   **Network:** `http` (REST API client and SSE stream parsing)
*   **Localization:** `flutter_localizations`, `intl` (Supports English and Spanish)

### Backend (Python)
*   **Framework:** FastAPI
*   **Database:** SQLite using `SQLModel` (SQLAlchemy / Pydantic wrapper)
*   **AI Integrations:** `google-genai` (Gemini 1.5/2.0 Flash) for itinerary generation and chatbot intelligence.
*   **Text-to-Speech:** `ElevenLabs` API for high-quality audio narration generation.
*   **Geocoding & Maps:**
    *   `Nominatim` & `Photon` (Komoot): Location and POI search
    *   `Wikipedia`: Geosearch and contextual data retrieval
    *   `OSRM` (Open Source Routing Machine): Walking route generation
*   **Networking:** `httpx` (Async HTTP client)

---

## 3. Core Features

### 3.1. Onboarding & Trip Creation
The app provides a seamless flow to collect user preferences to tailor the AI generation:
1.  **Destination & Dates:** User selects where they are going and the duration.
2.  **Travel Preferences:** Pace (e.g., Relaxed, Fast) and Interests (e.g., History, Food, Art).
3.  **Location Context:** App requests GPS access via `geolocator` to set `startLat`/`startLng` to provide geographically relevant starting points or navigation.
4.  **Backend Integration:** The `TripProvider` sends a `CreateTripRequest` to the backend, which persists the `Trip` in SQLite and returns a `trip_id`.

### 3.2. AI Itinerary Generation
The core feature of Navia is the smart day-by-day planner.
*   **Trigger:** When the `ItineraryScreen` loads for a specific day, it requests the plan from `/v1/itinerary/{trip_id}/{day}`.
*   **Backend Logic (`itinerary_service.py`):**
    *   If a `DayPlan` exists in the database, it is returned.
    *   If not, the backend constructs a context prompt including destination, dates, pace, and interests.
    *   It queries **Google Gemini** with a strict system prompt to return a JSON array of `Stop` objects (title, subtitle, start time).
    *   *Fallback:* If the AI fails or the API key is missing, a static fallback itinerary is provided.

### 3.3. Interactive Smart Guide (Chatbot)
Users can chat with Navia to ask questions about the destination or modify their itinerary in real-time.
*   **Frontend:** The `GuideScreen` allows text or voice input (using `speech_to_text`).
*   **Backend Logic (`chat_service.py`):**
    *   The `ChatRequest` is sent to `/v1/chat`.
    *   The backend retrieves the current day's itinerary, the trip context, and dynamically fetches a **Wikipedia summary** of the destination to enrich the AI's knowledge base.
    *   The request is passed to Gemini, instructing it to respond concisely. If the user asks to modify the schedule (e.g., "Add a lunch stop at 1 PM"), Gemini returns a `rewrite: true` flag along with a modified list of stops.
    *   **Streaming:** The backend uses Server-Sent Events (SSE) via `StreamingResponse` to stream the assistant's reply word-by-word to the UI, improving perceived latency.
    *   **Action Execution:** If `actions` (like `ReplaceDayPlan`) are returned, the backend automatically updates the `Stop` database records, and the frontend reloads the itinerary.

### 3.4. Explore & Interactive Map
A dedicated screen to view the city and search for POIs.
*   **Frontend:** `ExploreScreen` uses `flutter_map` displaying OpenStreetMap tiles. It centres on the destination or the user's GPS coordinates.
*   **Geocoding (`osm_service.py`):**
    *   When searching for places, the backend uses a robust 3-tier fallback strategy:
        1.  **Nominatim:** Official OSM geocoder.
        2.  **Photon:** Better for full-text POI searches.
        3.  **Wikipedia Geosearch:** Excellent for famous landmarks and monuments.
*   **Routing:** When a user taps a place or requests directions to an itinerary stop, the backend queries the **OSRM** public API to fetch walking distances, durations, and GeoJSON polyline data.

### 3.5. Audio Narration
Navia acts as a personal audio guide for the user's stops.
*   **Backend (`narration.py`):**
    *   Generates an engaging, short narrative (3-5 sentences) about the stop using **Google Gemini** (or static fallback), localized to the user's language.
    *   Sends this text to the **ElevenLabs API** (`elevenlabs_service.py`) using a multilingual voice model (`eleven_multilingual_v2`) to generate an MP3 audio stream.
*   **Frontend Integration:**
    *   The app requests audio via `/v1/narration/audio`.
    *   If audio bytes are returned, `audioplayers` plays the MP3.
    *   If the backend API key is missing, it falls back to returning raw text, which the app then reads aloud using the on-device `flutter_tts` engine (`SpeechService`).

### 3.6. Localization and Accessibility
*   **Multilingual Support:** The app fully supports English (`en`) and Spanish (`es`). Localization spans the UI (`AppLocalizations`), the AI system prompts (Gemini is instructed to reply in the user's language), and the TTS/Audio generation.
*   **Profile Settings:** Users can adjust text scaling (Small, Normal, Large) and Voice Speed, making the app highly accessible.

---

## 4. Database Schema (SQLite / SQLModel)

The backend employs a relational schema:

*   `Trip`: High-level travel plan (destination, start/end dates, pace, interests, coordinates).
*   `DayPlan`: Represents a single day within a `Trip`.
*   `Stop`: An individual POI or event attached to a `DayPlan` (ordinal, title, subtitle, local start time).
*   `ChatMessage`: Audit log of user and assistant interactions, linked to a `Trip`.

---

## 5. API Endpoints Overview

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/health` | Server health check |
| `POST` | `/v1/trips` | Create a new trip plan |
| `GET` | `/v1/trips/{id}` | Retrieve trip details |
| `GET` | `/v1/itinerary/{trip_id}/{day}` | Get or generate day plan (AI generation triggers here) |
| `POST` | `/v1/itinerary/{trip_id}/regenerate` | Force wipe and regenerate a day plan |
| `POST` | `/v1/chat` | SSE endpoint for chatbot interactions and itinerary actions |
| `POST` | `/v1/narration/summary` | Generate a text summary for a POI |
| `POST` | `/v1/narration/audio` | Generate ElevenLabs audio MP3 for a POI |
| `GET` | `/v1/places/search` | Multi-tier geocoding/POI search |
| `GET` | `/v1/osm/route` | OSRM walking route polyline generation |

---

## 6. Setup & Configuration

### Prerequisites
*   Flutter SDK (^3.11.4)
*   Python (3.10+)
*   `uv` or standard `pip`/`venv` for Python package management

### Environment Variables (`backend/.env`)
Required to unlock full AI functionality:
```env
GEMINI_API_KEY=your_gemini_key
ELEVENLABS_API_KEY=your_elevenlabs_key
```
*(If missing, the system degrades gracefully to static fallbacks and device TTS).*

### Running the Backend
```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # or .venv\Scripts\activate on Windows
pip install -r requirements.txt # (or use uv sync)
fastapi dev app/main.py --port 8787
```

### Running the App
```bash
cd app
flutter pub get
flutter run
```
*Note: Ensure `AppEnv.apiUrl` in `app/lib/config/app_env.dart` points to your backend instance.*
