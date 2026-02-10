## Software Requirements Specification (SRS)

**Project:** CYVL GeoGuesser  
**Stack:** React frontend + FastAPI backend  
**Primary outcome:** A location-guessing game where players view CYVL 360-degree panoramic road imagery and guess where each image was taken. The closer the guess, the higher the score.

**Status:** In Development

---

# 1. Introduction

## 1.1 Purpose

Define requirements for an in-house GeoGuessr-style game built on CYVL's 360-degree panoramic road imagery. Players view images captured by CYVL's road scanning vehicles and attempt to guess the geographic location.

## 1.2 Scope

In scope:

* Single-page React application with client-side routing (4 screens)
* FastAPI REST API managing game state, round generation, and scoring
* Shared Python packages for game logic (models, scoring, round generation, state management)
* 360-degree image viewing via CYVL's 3DViewer iframe
* Interactive Mapbox maps for guessing and result visualization
* Mock API for frontend-only development/testing

Out of scope:

* User accounts and persistent storage (games are in-memory)
* Multiplayer or competitive modes
* Mobile-optimized UI
* Custom 360-degree viewer (uses CYVL's hosted 3DViewer)

## 1.3 Definitions

| Term | Meaning |
|------|---------|
| Round | A single turn: player views one 360-degree image and submits a location guess |
| Game | A complete session of 5 sequential rounds |
| Score | Points per round based on distance between guess and actual location (0--5000) |
| Actual Location | Real geographic coordinates where the 360-degree image was captured |
| Guess Location | Coordinates the player selected on the map |
| Great-Circle Distance | Shortest distance between two points on Earth's surface (Haversine) |

---

# 2. Game Flow

**GF-001: Game Creation.** A new game is created with 5 rounds. Each round is populated with a random 360-degree panoramic image URL and its actual coordinates from CYVL's data store. The first round is set as active.

**GF-002: Round Progression.** The player progresses sequentially through rounds 0-4. The game tracks: `current_round_index` (which round the player is on), `current_round_id` (UUID of the active round), and `current_score` (cumulative total).

**GF-003: Guess Submission.** For each round, the player: views the 360-degree image, places a pin on an interactive map, submits the guess, and receives a score. The round is then marked complete.

**GF-004: Per-Round Scoring Feedback.** After each guess, the player sees: their round score, a map showing actual and guessed locations connected by a great-circle line, their cumulative total, and a button to continue (next round or final results).

**GF-005: Game Completion.** After all 5 rounds, the player sees: "Game Complete!" message, final total score, per-round breakdown, and a Play Again button that creates a new game.

---

# 3. User Interface Requirements

## 3.1 Design System

**DS-001: Color Palette**

| Role | Value | Usage |
|------|-------|-------|
| Background | `#0c0c0c` | All screen backgrounds |
| Primary Text | `#fffffe` | Headings and body text |
| Accent / CTA | `#dbff00` | Buttons, scores, highlights |
| Error | Red tones | Error messages |

**DS-002: Typography.** System font stack. Bold for headings, semibold for buttons/labels. Score values use extra-large bold text in accent color.

**DS-003: Button Styles.** Primary buttons: accent background with dark text, large rounded corners, accent shadow. Hover: brightness increase, slight upward translate, enhanced shadow. Disabled: reduced opacity, not-allowed cursor. Loading: text changes to "Loading..."

**DS-004: Loading States.** Spinning circular indicator using accent color with descriptive text beneath (e.g., "Loading game...", "Submitting guess...").

**DS-005: Error States.** Red-tinted error text, "Back to Home" button for recovery, human-readable messages (not raw API errors).

## 3.2 Main Screen

**Route:** `/`

**UI-010:** Full-screen centered layout on dark background with CYVL logo, "GeoGuesser" title, and a Play button.

**UI-011:** Clicking Play shows loading state, calls the API to create a game, navigates to `/game/{gameId}` on success, displays error on failure.

## 3.3 Guess Screen

**Route:** `/game/:gameId`

**UI-020:** Full-screen with two layers: 360-degree image viewer filling the viewport (background), minimap overlay in bottom-right corner.

**UI-021:** The 360-degree viewer is an iframe displaying CYVL's 3DViewer with the current round's `image_url`, filling full width and height.

**UI-022:** The minimap is approximately 400x300 pixels with rounded corners and shadow. Initial view: longitude 0, latitude 20, zoom 1. Click to place/move a pin marker (emoji-style). Guess button appears at bottom-center only after a pin is placed.

**UI-023:** On guess submission: full-screen translucent overlay with spinner and "Submitting guess..." text. On success: navigate to `/game/{gameId}/score/{roundIndex}` with response data passed via router state. On failure: show error.

**UI-024:** On mount: load game state from API, find current round by matching `current_round_id`, display the round's 360-degree image, show loading/error states as needed.

## 3.4 Score Screen

**Route:** `/game/:gameId/score/:roundIndex`

**UI-030:** Full-screen map view with translucent score overlay at top.

**UI-031:** Gradient overlay (dark at top, transparent at bottom) containing: "Round Score" heading, the round score in extra-large accent text, cumulative "Total Score: N" below, and "Next Round" or "View Results" button.

**UI-032:** Full-screen map behind overlay showing: marker at actual location (green-tinted), marker at guessed location (red-tinted/default), dashed great-circle line connecting them. Map centered to show both markers.

**UI-033:** If not last round: button reads "Next Round", navigates to `/game/{gameId}`. If last round: button reads "View Results", navigates to `/game/{gameId}/results`.

**UI-034:** Data comes via React Router location state: `round` (completed Round object), `isLastRound` (boolean), `scoreFromLastRound` (number), `totalCurrentScore` (number). If state is missing, show error with "Back to Home".

## 3.5 Results Screen

**Route:** `/game/:gameId/results`

**UI-040:** Full-screen centered layout on dark background with results card.

**UI-041:** "Game Complete!" heading, styled card with frosted/blurred background, "Final Score" label, total score in extra-large accent text.

**UI-042:** Vertical list of 5 rounds: each row shows "Round N" on left and score on right, subtle background with rounded corners, scores in accent color.

**UI-043:** Play Again button (same style as Main Screen) that creates a new game and navigates to the first round.

---

# 4. API Requirements

## 4.1 Data Models

**DM-001: Location**

| Field | Type |
|-------|------|
| `latitude` | float |
| `longitude` | float |

**DM-002: Round**

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Unique round identifier |
| `actual_location` | Location | Where the image was taken |
| `guess_location` | Location or null | Player's guess (null until submitted) |
| `image_url` | string | URL to 360-degree panoramic viewer |
| `score` | integer or null | Points awarded (null until scored) |

**DM-003: Game**

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Unique game identifier |
| `rounds` | list of Round | The 5 rounds |
| `current_round_index` | integer | 0-based active round index |
| `current_round_id` | UUID or null | Active round UUID (null when game complete) |
| `current_score` | integer | Cumulative score |

## 4.2 Endpoints

**API-001: Create Game**

```
POST /game/create
Request: {} (empty)
Response (201): { "id": "<game-uuid>" }
```

Behavior: Create game with UUID, generate 5 rounds from data store, set `current_round_index` to 0 and `current_round_id` to first round, set `current_score` to 0, store as active game.

**API-002: Get Game State**

```
GET /game/{game_id}
Response (200): { "current_round_id", "current_round_index", "rounds": [...], "current_score" }
```

Behavior: Return current game state. 404 if no active game.

**API-003: Submit Guess**

```
POST /guess/{round_id}
Request: { "guess_location": { "latitude": float, "longitude": float } }
Response (200): { "completed_round": Round, "is_last_round": bool, "score_from_last_round": int, "total_current_score": int }
```

Behavior: Validate active game (404 if none). Set guess location on round. Calculate score (Section 4.3). Add to cumulative total. If not last round: advance `current_round_index` and `current_round_id`. If last round: set `current_round_id` to null. Return completed round, round score, total, and last-round flag.

## 4.3 Scoring Algorithm

**SC-001: Distance -- Haversine Formula.** Given two points in degrees: convert to radians, compute `a = sin^2(dlat/2) + cos(lat1) * cos(lat2) * sin^2(dlon/2)`, compute `c = 2 * arcsin(sqrt(a))`, distance = `R * c` where `R = 6371.0` km.

**SC-002: Score -- Exponential Decay.** `score = round(5000 * e^(-distance_km / 1500))`. Max 5000 (perfect guess). Negative distances must raise an error.

Reference values:

| Distance (km) | Score |
|---------------|-------|
| 0 | 5000 |
| 150 | ~4525 |
| 500 | ~3582 |
| 1000 | ~2567 |
| 1500 | ~1839 |
| 3000 | ~677 |
| 5000 | ~178 |
| 10000 | ~6 |

---

# 5. Environment Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `VITE_MAPBOX_TOKEN` | Yes | -- | Mapbox GL access token |
| `VITE_API_BASE_URL` | No | `http://localhost:8000` | Backend API URL |
| `VITE_USE_MOCK_API` | No | `false` | `"true"` to use mock API without backend |

---

# 6. Non-Functional Requirements

**NFR-001 Mock API.** A mock API must be available for frontend-only testing, toggled by environment variable. The mock may use approximate scoring; the backend must use the precise formula from SC-001/SC-002.

**NFR-002 CORS.** The backend must allow requests from the frontend dev server origin (`http://localhost:5173`).

**NFR-003 API Docs.** The backend must serve auto-generated OpenAPI documentation at `/docs`.

**NFR-004 In-Memory State.** Game state is stored in memory (single active game). No database required.

**NFR-005 Modular Packages.** Backend logic must be split into independent packages (models, scoring, round-generator, state-management) within a Python workspace.

---

# 7. Acceptance Criteria

| ID | Criterion |
|----|-----------|
| AC-001 | A player can start a new game |
| AC-002 | Each round shows a 360-degree image and an interactive map for guessing |
| AC-003 | Submitting a guess returns a score |
| AC-004 | After each round, the player sees a score screen with map visualization (actual, guess, great-circle line) |
| AC-005 | After 5 rounds, the player sees final results with round breakdown |
| AC-006 | Play Again starts a new game |
| AC-007 | Scores follow the exponential decay formula (SC-002): 0 km = 5000 points, ~1500 km = ~1839 points |
| AC-008 | The game advances sequentially (round 0-4), with "Next Round" / "View Results" switching correctly |
| AC-009 | Cumulative score tracks correctly across rounds; Results total matches sum of individual scores |
| AC-010 | All screens follow the design system (DS-001 through DS-005) |
| AC-011 | All screens handle API errors with human-readable messages and recovery navigation |
| AC-012 | The minimap responds to clicks, shows a pin, and only shows the Guess button after pin placement |

---

# 8. Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | -- | Initial SRS |
| 1.1 | 2025-02-10 | Reformatted to match project SRS style. Moved technical architecture to SDD. Added NFRs and test-relevant references. |
