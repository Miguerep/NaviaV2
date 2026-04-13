# Navia Project: Status & Action Plan

## 1. Current Project Status

Based on the repository configuration and the MVP proposal, the project has successfully completed its initial setup phases:

* **Frontend:** The mobile application is initialized using **Flutter** (`app/`), leveraging `--dart-define` for environment configurations. Map integrations using `flutter_map` and OpenStreetMap have been successfully modularized. Note: This is a positive deviation from the initial React Native proposal.
* **Backend:** The server is built with **Python (FastAPI)** and managed via `uv` (`backend/`).
* **APIs & Services:** Mapbox has been configured, and free-tier alternatives (Nominatim for OpenStreetMap, OSRM for routing, and Wikipedia for content) are integrated as modular services.
* **Endpoints:** Core functionality is sketched out with working endpoints such as `/v1/trips`, `/v1/itinerary/{trip_id}/{day}`, `/v1/places/search`, and `/v1/route`.

## 2. Action Plan (Scrum Methodology)

To reach the MVP objectives, the following sprints outline the immediate next steps:

### Sprint 1: Core Flow & UI Integration (Phase 1)
* **Task 1.1:** Connect the Flutter frontend to the backend `/v1/trips` and `/v1/places/search` endpoints.
* **Task 1.2:** Build the Dynamic Onboarding UI in Flutter (capturing trip duration, interests, and pace).
* **Task 1.3:** Render the AI-generated itinerary on the integrated OpenStreetMap view.

### Sprint 2: Narration & AI Chatbot (Phases 2 & 3)
* **Task 2.1:** Integrate Text-to-Speech (TTS) logic (ElevenLabs or Google Cloud TTS) for the "Listen" feature at monuments.
* **Task 2.2:** Implement the Chat UI in Flutter for dynamic adaptation.
* **Task 2.3:** Connect the Chat UI to the `/v1/itinerary/{trip_id}/regenerate` endpoint, allowing the LLM (Gemini 1.5 Pro / GPT-4o) to execute function calls and rewrite the database.

### Sprint 3: Polish, Accessibility & Testing
* **Task 3.1:** Audit the Flutter UI for "WhatsApp-style simplicity" (high contrast, large typography).
* **Task 3.2:** Test accessibility compatibility (VoiceOver/TalkBack) to avoid store rejection.
* **Task 3.3:** Optimize battery consumption related to constant GPS polling and audio processing.

### Sprint 4: Pre-Publishing & Store Deployment
* **Task 4.1:** Create Apple Developer and Google Play Console accounts.
* **Task 4.2:** Draft the mandatory legal/privacy documentation detailing GPS data handling (Nutritional Label).
* **Task 4.3:** Record the App Preview video showcasing the "Dynamic Adaptation" feature and capture required screenshots.
* **Task 4.4:** Configure a test account with mocked GPS coordinates so App Store reviewers can bypass physical location requirements.
