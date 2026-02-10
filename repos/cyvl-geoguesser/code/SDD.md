## Software Design Document (SDD)

**Project:** CYVL GeoGuesser  
**Version:** 1.2  
**Date:** 2025-02-10  
**Requirements:** [SRS.md](SRS.md)

This document describes the current state of the system. For the full product requirements, see the [SRS](SRS.md).

---

# 1. Architecture

## 1.1 System Diagram

```
Browser (port 5173)
  │
  ├── /                         MainScreen.tsx
  │                               └── POST /game/create → navigate to /game/{id}
  │
  ├── /game/:gameId             GuessScreen.tsx
  │                               ├── GET /game/{id} → load rounds
  │                               ├── StreetViewer.tsx (360° iframe)
  │                               └── MiniMap.tsx (Mapbox + pin)
  │
  ├── /game/:gameId/score/:idx  ScoreScreen.tsx (empty)
  │
  └── /game/:gameId/results     ResultsScreen.tsx (empty)

FastAPI Backend (port 8000)
  │
  ├── POST /game/create         routes.py::create_game()
  │     └── RandomRoundGenerator → FileBasedDataStore → 5 rounds
  │
  └── GET  /game/{id}           routes.py::get_game_state()
        └── Returns current_game global
```

## 1.2 Component Map

| Component | Files | SRS Reference |
|-----------|-------|---------------|
| Router | `App.tsx` | All UI routes |
| Main Screen | `MainScreen.tsx`, `PlayButton.tsx` | [UI-010, UI-011](SRS.md#32-main-screen) |
| Guess Screen | `GuessScreen.tsx`, `StreetViewer.tsx`, `MiniMap.tsx` | [UI-020--024](SRS.md#33-guess-screen) |
| Score Screen | `ScoreScreen.tsx` | [UI-030--034](SRS.md#34-score-screen) |
| Results Screen | `ResultsScreen.tsx` | [UI-040--043](SRS.md#35-results-screen) |
| API Service | `services/api.ts` | API calls |
| Mock API | `services/mockApi.ts` | [NFR-001](SRS.md#6-non-functional-requirements) |
| Types | `types/api.ts` | [DM-001--003](SRS.md#41-data-models) |
| FastAPI App | `api/apps/geolocation-api/` | [API-001--003](SRS.md#42-endpoints) |
| Models | `api/packages/models/` | [DM-001--003](SRS.md#41-data-models) |
| Round Generator | `api/packages/round-generator/` | [GF-001](SRS.md#2-game-flow) |
| Scoring | `api/packages/scoring/` | [SC-001, SC-002](SRS.md#43-scoring-algorithm) |
| State Management | `api/packages/state-management/` | API request/response models |

---

# 2. File Structure

```
cyvl-geoguesser/code/
├── src/
│   ├── App.tsx                     # Router (4 routes)
│   ├── main.tsx                    # React entry point
│   ├── index.css                   # Global styles (Tailwind import)
│   ├── components/
│   │   ├── MainScreen.tsx          # Landing page with Play button
│   │   ├── GuessScreen.tsx         # 360° viewer + minimap
│   │   ├── ScoreScreen.tsx         # Per-round score display
│   │   ├── ResultsScreen.tsx       # Final results display
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
│       ├── scoring/                # Score calculation package
│       └── state-management/       # API request/response models
├── package.json                    # Frontend dependencies
├── vite.config.ts                  # Vite + Tailwind + React
├── index.html                      # SPA entry point
├── .env.local                      # Mapbox token
├── SRS.md
└── SDD.md
```

---

# 3. Frontend Design

## 3.1 Technology Stack

* **React 19** with TypeScript (strict mode)
* **Vite 7** with HMR, dev server on port 5173 (`--host 0.0.0.0`)
* **React Router DOM 7** for client-side routing
* **Mapbox GL** via `react-map-gl` for interactive maps
* **Tailwind CSS 4** via Vite plugin (`@import "tailwindcss"`, no config file)
* **@turf/turf** available for geospatial calculations

## 3.2 Routing

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

All four routes are defined. MainScreen and GuessScreen are functional. ScoreScreen and ResultsScreen render empty.

## 3.3 API Service Layer (`services/api.ts`)

Conditional mock/real routing based on environment variable:

```
VITE_USE_MOCK_API=true  →  dynamic import('./mockApi')  →  mock functions
VITE_USE_MOCK_API=false →  fetch() to API_BASE_URL       →  real backend
```

Currently implemented functions:

| Function | Real Backend | Mock |
|----------|-------------|------|
| `createGame()` | `POST /game/create` | In-memory game creation with hardcoded locations |
| `getGame(gameId)` | `GET /game/{id}` | Returns stored mock game |

The mock API also implements a `submitGuess()` function with a simplified linear scoring formula (`max(0, 5000 * (1 - d/1000))`) for frontend-only testing per [NFR-001](SRS.md#6-non-functional-requirements).

## 3.4 Type Definitions (`types/api.ts`)

Currently defined:

* `Location` -- latitude/longitude pair
* `Round` -- id, image_url, actual_location, guess_location, score
* `Game` -- current_round_id, current_round_index, rounds
* `CreateGameResponse` -- id
* `GetGameResponse` -- current_round_id, current_round_index, rounds, current_score

## 3.5 Components

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
* On guess: navigates to `/game/{gameId}/score/{roundIndex}`
* Handles loading, error, and "no round available" states

### StreetViewer.tsx (implements [UI-021](SRS.md#33-guess-screen))

* Iframe wrapper filling parent container
* Props: `imageUrl` (CYVL 3DViewer URL with image parameter)
* Attributes: fullscreen allowed, lazy loading

### MiniMap.tsx (implements [UI-022](SRS.md#33-guess-screen))

* 400x300px fixed-position bottom-right overlay, z-index 1000
* Mapbox GL with `streets-v12` style, initial view: lon 0, lat 20, zoom 1
* Click handler stores pin location in `useState<Location | null>`
* Pin rendered as emoji marker via react-map-gl `<Marker>`
* Guess button appears conditionally at bottom-center when pin exists
* Shows red error badge if Mapbox token is not configured

### PlayButton.tsx (implements [DS-003](SRS.md#31-design-system))

* Reusable button: accent background, dark text, rounded corners, accent shadow
* Hover: brightness increase, upward translate, enhanced shadow
* Accepts `text`, `loading`, `disabled`, and all standard `<button>` props
* Loading state renders "Loading..." text

### ScoreScreen.tsx

Empty component. Returns `null`.

### ResultsScreen.tsx

Empty component. Returns `null`.

---

# 4. Backend Design

## 4.1 Technology Stack

* **FastAPI** with Pydantic v2 models
* **uv** workspace monorepo (5 members)
* **uvicorn** dev server on port 8000 with `--reload`
* **geopandas** for reading geospatial data from zip files
* **In-memory state** via module-level `current_game` global

## 4.2 Package Architecture (implements [NFR-005](SRS.md#6-non-functional-requirements))

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
    ├── scoring/                    # Score calculation
    └── state-management/           # API request/response models
```

Workspace dependencies: `geolocation-api` -> `round-generator` -> `models`, `geolocation-api` -> `scoring` -> `models`, `geolocation-api` -> `state-management`.

## 4.3 Data Models (`packages/models/`) -- implements [DM-001--003](SRS.md#41-data-models)

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

## 4.4 State Management (`packages/state-management/`)

Currently defined request/response models:

* `CreateGameResponse(id: UUID)`
* `GameStateResponse(current_round_id, rounds, current_round_index, current_score)`

## 4.5 Round Generator (`packages/round-generator/`) -- implements [GF-001](SRS.md#2-game-flow)

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

## 4.6 Scoring (`packages/scoring/`)

Imports `Round` and `Location` from models. No functions defined.

## 4.7 API Routes (`apps/geolocation-api/`)

### POST /game/create -- implements [API-001](SRS.md#42-endpoints)

* Creates `Game` with `uuid4()`, generates 5 rounds via `RandomRoundGenerator`
* Sets `current_round_id` to first round's ID, `current_score` to 0
* Stores in module-level `current_game` global
* Returns `CreateGameResponse(id=game.id)`

### GET /game/{id} -- implements [API-002](SRS.md#42-endpoints)

* Returns `current_game` as `GameStateResponse`
* Returns 404 if `current_game is None`

## 4.8 App Configuration

* **CORS:** allows `http://localhost:5173` with all methods/headers (implements [NFR-002](SRS.md#6-non-functional-requirements))
* **Docs:** auto-generated OpenAPI at `/docs` (implements [NFR-003](SRS.md#6-non-functional-requirements))
* **Lifespan:** startup/shutdown hooks defined, currently only log messages
* **Settings:** Pydantic settings with `.env` file support

---

# 5. Data Flow

```
Play → POST /game/create → 5 rounds from FileBasedDataStore
     → Navigate to /game/{id}

Guess → GET /game/{id} → game state with current round
      → User views 360° image, places pin, clicks Guess
      → Navigate to /game/{id}/score/{index}

Score → ScoreScreen renders empty

Results → ResultsScreen renders empty
```

---

# 6. Known Limitations

1. **Single active game** -- only one game stored in memory; creating a new game overwrites the previous
2. **No game ID validation** -- `GET /game/{id}` returns the active game regardless of path parameter
3. **No persistent storage** -- server restart loses all game state
4. **Mock scoring differs from spec** -- mock uses linear decay vs. SRS exponential decay
