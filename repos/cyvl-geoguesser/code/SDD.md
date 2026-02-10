## Software Design Document (SDD)

**Project:** CYVL GeoGuesser  
**Version:** 1.0  
**Date:** 2025-02-10  
**Requirements:** [SRS.md](SRS.md)

This document describes *how* the system is built. For *what* it must do, see the [SRS](SRS.md).

---

# 1. Implementation Status

| Requirement | Component | Status |
|-------------|-----------|--------|
| [GF-001](SRS.md#2-game-flow) Game Creation | `POST /game/create` | Implemented |
| [GF-002](SRS.md#2-game-flow) Round Progression | Game model + route | Partial -- create/get only |
| [GF-003](SRS.md#2-game-flow) Guess Submission | `POST /guess/{round_id}` | Not yet implemented |
| [GF-004](SRS.md#2-game-flow) Scoring Feedback | ScoreScreen.tsx | Not yet implemented |
| [GF-005](SRS.md#2-game-flow) Game Completion | ResultsScreen.tsx | Not yet implemented |
| [UI-010/011](SRS.md#32-main-screen) Main Screen | MainScreen.tsx | Implemented |
| [UI-020--024](SRS.md#33-guess-screen) Guess Screen | GuessScreen.tsx | Implemented |
| [UI-030--034](SRS.md#34-score-screen) Score Screen | ScoreScreen.tsx | Not yet implemented |
| [UI-040--043](SRS.md#35-results-screen) Results Screen | ResultsScreen.tsx | Not yet implemented |
| [DS-001--005](SRS.md#31-design-system) Design System | Global styles + components | Implemented (applied to completed screens) |
| [API-001](SRS.md#42-endpoints) Create Game | routes.py | Implemented |
| [API-002](SRS.md#42-endpoints) Get Game | routes.py | Implemented |
| [API-003](SRS.md#42-endpoints) Submit Guess | routes.py | Not yet implemented (returns 501) |
| [SC-001](SRS.md#43-scoring-algorithm) Haversine | score_round.py | Not yet implemented |
| [SC-002](SRS.md#43-scoring-algorithm) Score Calc | score_round.py | Not yet implemented |
| [DM-001--003](SRS.md#41-data-models) Data Models | models.py | Implemented |
| [NFR-001](SRS.md#6-non-functional-requirements) Mock API | mockApi.ts | Implemented |
| [NFR-002](SRS.md#6-non-functional-requirements) CORS | app.py | Implemented |
| [NFR-003](SRS.md#6-non-functional-requirements) API Docs | app.py | Implemented |
| [NFR-004](SRS.md#6-non-functional-requirements) In-Memory State | routes.py | Implemented |
| [NFR-005](SRS.md#6-non-functional-requirements) Modular Packages | api/ workspace | Implemented |

---

# 2. Architecture

## 2.1 System Diagram

```
Browser (port 5173)
  │
  ├── /                         MainScreen.tsx
  │                               └── POST /game/create → navigate to /game/{id}
  │
  ├── /game/:gameId             GuessScreen.tsx
  │                               ├── GET /game/{id} → load rounds
  │                               ├── StreetViewer.tsx (360° iframe)
  │                               ├── MiniMap.tsx (Mapbox + pin)
  │                               └── POST /guess/{round_id}
  │
  ├── /game/:gameId/score/:idx  ScoreScreen.tsx
  │
  └── /game/:gameId/results     ResultsScreen.tsx

FastAPI Backend (port 8000)
  │
  ├── POST /game/create         routes.py::create_game()
  │     └── RandomRoundGenerator → FileBasedDataStore → 5 rounds
  │
  ├── GET  /game/{id}           routes.py::get_game_state()
  │     └── Returns current_game global
  │
  └── POST /guess/{round_id}    routes.py::submit_guess()
        └── scoring.score_round() → haversine → exponential decay
```

## 2.2 Component Map

| Component | Files | Fulfills |
|-----------|-------|----------|
| Router | `App.tsx` | All UI routes |
| Main Screen | `MainScreen.tsx`, `PlayButton.tsx` | [UI-010, UI-011](SRS.md#32-main-screen) |
| Guess Screen | `GuessScreen.tsx`, `StreetViewer.tsx`, `MiniMap.tsx` | [UI-020--024](SRS.md#33-guess-screen) |
| Score Screen | `ScoreScreen.tsx` | [UI-030--034](SRS.md#34-score-screen), [GF-004](SRS.md#2-game-flow) |
| Results Screen | `ResultsScreen.tsx` | [UI-040--043](SRS.md#35-results-screen), [GF-005](SRS.md#2-game-flow) |
| API Service | `services/api.ts` | All API calls |
| Mock API | `services/mockApi.ts` | [NFR-001](SRS.md#6-non-functional-requirements) |
| Types | `types/api.ts` | [DM-001--003](SRS.md#41-data-models) |
| FastAPI App | `api/apps/geolocation-api/` | [API-001--003](SRS.md#42-endpoints) |
| Models | `api/packages/models/` | [DM-001--003](SRS.md#41-data-models) |
| Round Generator | `api/packages/round-generator/` | [GF-001](SRS.md#2-game-flow) |
| Scoring | `api/packages/scoring/` | [SC-001, SC-002](SRS.md#43-scoring-algorithm) |
| State Management | `api/packages/state-management/` | API request/response models |

---

# 3. File Structure

```
cyvl-geoguesser/code/
├── src/
│   ├── App.tsx                     # Router (4 routes)
│   ├── main.tsx                    # React entry point
│   ├── index.css                   # Global styles (Tailwind import)
│   ├── components/
│   │   ├── MainScreen.tsx          # Landing page with Play button
│   │   ├── GuessScreen.tsx         # 360° viewer + minimap
│   │   ├── ScoreScreen.tsx         # Per-round score + map visualization
│   │   ├── ResultsScreen.tsx       # Final score + round breakdown
│   │   ├── StreetViewer.tsx        # 360° iframe wrapper
│   │   ├── MiniMap.tsx             # Interactive guess map (Mapbox)
│   │   └── PlayButton.tsx          # Reusable styled button
│   ├── services/
│   │   ├── api.ts                  # API service layer (real + mock routing)
│   │   └── mockApi.ts              # Mock API for frontend-only testing
│   └── types/
│       └── api.ts                  # TypeScript type definitions
├── api/
│   ├── pyproject.toml              # uv workspace root (5 members)
│   ├── apps/
│   │   └── geolocation-api/        # FastAPI application
│   │       ├── data/               # Job listings + deliverable zips
│   │       └── src/geolocation_api/
│   │           ├── app.py          # FastAPI factory + CORS
│   │           ├── routes.py       # Endpoint handlers
│   │           ├── config.py       # Pydantic settings
│   │           └── lifespan.py     # Startup/shutdown lifecycle
│   └── packages/
│       ├── models/                 # Location, Round, Game (Pydantic)
│       ├── round-generator/        # RandomRoundGenerator + FileBasedDataStore
│       ├── scoring/                # Haversine + score calculation
│       └── state-management/       # API request/response models
├── package.json                    # Frontend dependencies
├── vite.config.ts                  # Vite + Tailwind + React
├── index.html                      # SPA entry point
├── .env.local                      # Mapbox token
├── SRS.md
└── SDD.md
```

---

# 4. Frontend Design

## 4.1 Technology Stack

* **React 19** with TypeScript (strict mode)
* **Vite 7** with HMR, dev server on port 5173 (`--host 0.0.0.0`)
* **React Router DOM 7** for client-side routing
* **Mapbox GL** via `react-map-gl` for interactive maps
* **Tailwind CSS 4** via Vite plugin (`@import "tailwindcss"`, no config file)
* **@turf/turf** for geospatial calculations (great-circle lines)

## 4.2 Routing (implements [UI routes](SRS.md#3-user-interface-requirements))

```typescript
<BrowserRouter>
  <Routes>
    <Route path="/" element={<MainScreen />} />
    <Route path="/game/:gameId" element={<GuessScreen />} />
    <Route path="/game/:gameId/score/:roundIndex" element={<ScoreScreen />} />
    <Route path="/game/:gameId/results" element={<ResultsScreen />} />
  </Routes>
</BrowserRouter>
```

## 4.3 API Service Layer (`services/api.ts`)

Conditional mock/real routing based on environment variable:

```
VITE_USE_MOCK_API=true  →  dynamic import('./mockApi')  →  mock functions
VITE_USE_MOCK_API=false →  fetch() to API_BASE_URL       →  real backend
```

| Function | Real Backend | Mock |
|----------|-------------|------|
| `createGame()` | `POST /game/create` | In-memory game creation with hardcoded locations |
| `getGame(gameId)` | `GET /game/{id}` | Returns stored mock game |
| `submitGuess(roundId, location)` | `POST /guess/{round_id}` | Calculates score using approximate linear formula |

The mock API uses a simplified linear scoring formula (`max(0, 5000 * (1 - d/1000))`) which intentionally differs from the [SRS exponential decay](SRS.md#43-scoring-algorithm) per [NFR-001](SRS.md#6-non-functional-requirements).

The real `submitGuess()` currently throws an error. Once the backend endpoint is implemented, it needs to `fetch` to `POST /guess/{round_id}` and return the parsed `SubmitGuessResponse`.

## 4.4 Components

### MainScreen.tsx (implements [UI-010, UI-011](SRS.md#32-main-screen))

* Full-screen centered layout, dark background (`#0c0c0c`)
* CYVL logo from `/cyvl-logo.png`, "GeoGuesser" title in 7xl bold
* PlayButton with loading/error state handling
* On success: navigates to `/game/{id}`
* Error displayed as red text on white background below button

### GuessScreen.tsx (implements [UI-020--024](SRS.md#33-guess-screen))

* Loads game state via `getGame(gameId)` on mount
* Finds current round by matching `current_round_id` in the rounds array
* Renders StreetViewer (full viewport) + MiniMap (bottom-right overlay)
* Full-screen translucent overlay with spinner during guess submission
* Handles loading, error, and "no round available" states
* Current gap: `handleGuess` navigates to score URL but does not pass the `submitGuess` response data via React Router state (required by [UI-034](SRS.md#34-score-screen))

### StreetViewer.tsx (implements [UI-021](SRS.md#33-guess-screen))

* Iframe wrapper filling parent container
* Props: `imageUrl` (CYVL 3DViewer URL with image parameter)
* Attributes: fullscreen allowed, lazy loading

### MiniMap.tsx (implements [UI-022](SRS.md#33-guess-screen))

* 400x300px fixed-position bottom-right overlay, z-index 1000
* Mapbox GL with `streets-v12` style, initial view: lon 0, lat 20, zoom 1
* Click handler stores pin location in `useState<Location | null>`
* Pin rendered as emoji marker (📍) via react-map-gl `<Marker>`
* Guess button appears conditionally at bottom-center when pin exists
* Shows red error badge if Mapbox token is not configured

### PlayButton.tsx (implements [DS-003](SRS.md#31-design-system))

* Reusable button: accent background, dark text, rounded corners, accent shadow
* Hover: brightness increase, upward translate, enhanced shadow
* Accepts `text`, `loading`, `disabled`, and all standard `<button>` props
* Loading state renders "Loading..." text

### ScoreScreen.tsx (implements [UI-030--034](SRS.md#34-score-screen))

Not yet implemented. Currently renders a placeholder. Needs: score overlay with gradient, full-screen Mapbox map with actual/guess markers and great-circle dashed line, "Next Round"/"View Results" navigation, and React Router state consumption.

### ResultsScreen.tsx (implements [UI-040--043](SRS.md#35-results-screen))

Not yet implemented. Currently renders a placeholder. Needs: "Game Complete!" heading, frosted score card, 5-round breakdown list, and Play Again button.

---

# 5. Backend Design

## 5.1 Technology Stack

* **FastAPI** with Pydantic v2 models
* **uv** workspace monorepo (5 members)
* **uvicorn** dev server on port 8000 with `--reload`
* **geopandas** for reading geospatial data from zip files
* **In-memory state** via module-level `current_game` global

## 5.2 Package Architecture (implements [NFR-005](SRS.md#6-non-functional-requirements))

```
api/
├── pyproject.toml                  # Workspace root
├── apps/
│   └── geolocation-api/            # FastAPI app
│       ├── pyproject.toml          # Depends on: round-generator, state-management, scoring
│       ├── data/                   # Job listings + deliverable zips
│       └── src/geolocation_api/
│           ├── app.py              # FastAPI factory, CORS
│           ├── routes.py           # Endpoint handlers
│           ├── config.py           # Pydantic settings
│           └── lifespan.py         # Startup/shutdown lifecycle
└── packages/
    ├── models/                     # Core data models
    ├── round-generator/            # Round generation from data store
    ├── scoring/                    # Distance + score calculation
    └── state-management/           # API request/response models
```

Workspace dependencies flow: `geolocation-api` → `round-generator` → `models`, `geolocation-api` → `scoring` → `models`, `geolocation-api` → `state-management`.

## 5.3 Data Models (`packages/models/`) -- implements [DM-001--003](SRS.md#41-data-models)

```python
class Location(BaseModel):
    latitude: float
    longitude: float

class Round(BaseModel):
    id: UUID
    actual_location: Location
    guess_location: Location | None = None
    image_url: str
    score: int | None = None

class Game(BaseModel):
    id: UUID
    rounds: list[Round]
    current_round_index: int
    current_round_id: UUID | None = None
    current_score: int = 0
```

## 5.4 State Management (`packages/state-management/`)

Request/response Pydantic models matching the [SRS API contracts](SRS.md#42-endpoints):

* `CreateGameResponse(id: UUID)`
* `GameStateResponse(current_round_id, rounds, current_round_index, current_score)`
* `GuessRequest(guess_location: Location)`
* `GuessResponse(completed_round, is_last_round, score_from_last_round, total_current_score)`

## 5.5 Round Generator (`packages/round-generator/`) -- implements [GF-001](SRS.md#2-game-flow)

### FileBasedDataStore

* Reads `data/job_listings.json` for available projects (one JSON object per line)
* Filters to projects that have a corresponding `.zip` in `data/job_deliverables/`
* Reads zip files via geopandas, extracts `lat`, `lon`, `image_url` columns
* `get_random_location()`: picks a random project, then a random location within it

### RandomRoundGenerator

* Constructor takes a `FileBasedDataStore`
* `generate_round()`: calls `data_store.get_random_location()`, returns a `Round` with UUID, actual location, image URL, and null guess/score

### TestRoundGenerator

* Returns a fixed Round (New York, example image URL) for unit testing

### Tests

* `test_data_store.py` -- validates project JSON parsing and location extraction from zip
* `test_random_round_generator.py` -- validates round generation produces expected fields

## 5.6 Scoring (`packages/scoring/`) -- implements [SC-001, SC-002](SRS.md#43-scoring-algorithm)

Not yet implemented. Three function stubs exist:

```python
def haversine_distance(lat1, lon1, lat2, lon2) -> float:
    """Calculate great-circle distance in km between two points."""
    raise NotImplementedError

def calculate_score_from_distance(distance_km: float) -> int:
    """Convert distance to score (0-5000) using exponential decay."""
    raise NotImplementedError

def score_round(round: Round, guess_location: Location) -> int:
    """Score a round given the player's guess location."""
    raise NotImplementedError
```

No tests exist for this package yet.

## 5.7 API Routes (`apps/geolocation-api/`)

### POST /game/create -- implements [API-001](SRS.md#42-endpoints)

* Creates `Game` with `uuid4()`, generates 5 rounds via `RandomRoundGenerator`
* Sets `current_round_id` to first round's ID, `current_score` to 0
* Stores in module-level `current_game` global
* Returns `CreateGameResponse(id=game.id)`

### GET /game/{id} -- implements [API-002](SRS.md#42-endpoints)

* Returns `current_game` as `GameStateResponse`
* Returns 404 if `current_game is None`
* Note: does not validate the path `{id}` against the stored game's ID

### POST /guess/{round_id} -- implements [API-003](SRS.md#42-endpoints)

Not yet implemented. Currently returns HTTP 501. Needs to: validate active game exists, find the round by ID, set `guess_location`, call `score_round()`, update `current_score`, advance to next round (or set `current_round_id` to null if last), and return `GuessResponse`.

## 5.8 App Configuration

* **CORS:** allows `http://localhost:5173` with all methods/headers (implements [NFR-002](SRS.md#6-non-functional-requirements))
* **Docs:** auto-generated OpenAPI at `/docs` (implements [NFR-003](SRS.md#6-non-functional-requirements))
* **Lifespan:** startup/shutdown hooks defined, currently only log messages
* **Settings:** Pydantic settings with `.env` file support; no backend env vars currently required

---

# 6. Data Flow

## 6.1 Current State (mock API)

```
Play → MainScreen calls createGame()
     → Mock creates 5 rounds with hardcoded locations/images
     → Navigate to /game/{id}

Guess → GuessScreen loads game via getGame(id)
      → Displays 360° image, user places pin, clicks Guess
      → Mock submitGuess() calculates approximate score
      → Navigate to /game/{id}/score/{index}

Score → ScoreScreen renders placeholder (not yet implemented)
Results → ResultsScreen renders placeholder (not yet implemented)
```

## 6.2 Target State (real backend)

```
Play → POST /game/create → 5 rounds from FileBasedDataStore
     → Navigate to /game/{id}

Guess → GET /game/{id} → game state with current round
      → User views 360° image, places pin, clicks Guess
      → POST /guess/{round_id} with guess coordinates
      → Backend: score_round() → haversine → exponential decay
      → Backend: update game state, advance round
      → Response: { completed_round, is_last_round, score, total }
      → Navigate to /game/{id}/score/{index} with response in router state

Score → Read router state
      → Display score overlay + map with actual/guess markers + great-circle line
      → "Next Round" → /game/{id} (loads next round)
      → "View Results" (round 5) → /game/{id}/results

Results → GET /game/{id} → final state with all 5 scores
        → Display total + per-round breakdown
        → Play Again → POST /game/create → new game loop
```

---