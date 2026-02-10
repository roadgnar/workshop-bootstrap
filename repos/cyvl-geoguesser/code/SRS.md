# CYVL GeoGuesser — Software Requirements Specification

**Product:** CYVL GeoGuesser — A location-guessing game using CYVL 360° panoramic imagery
**Stack:** React frontend + FastAPI backend (Python workspace with shared packages)
**Status:** In Development

---

## 1. Product Overview

### 1.1 Purpose

An in-house version of the popular game "GeoGuessr" built on CYVL's 360° panoramic road imagery. Players view panoramic images captured by CYVL's road scanning vehicles and attempt to guess the geographic location where each image was taken. The closer the guess, the higher the score.

### 1.2 Scope

The application consists of:

- A **React single-page application** (frontend) providing the game UI
- A **FastAPI REST API** (backend) managing game state, round generation, and scoring
- **Shared Python packages** encapsulating game logic (models, scoring, round generation, state management)

### 1.3 Definitions

| Term | Definition |
|------|-----------|
| **Round** | A single turn where a player views one 360° image and submits a location guess |
| **Game** | A complete session consisting of 5 sequential rounds |
| **Score** | Points awarded per round based on distance between guess and actual location (0–5000) |
| **Actual Location** | The real geographic coordinates where the 360° image was captured |
| **Guess Location** | The coordinates the player selected on the map as their guess |
| **Great-Circle Distance** | The shortest distance between two points on the surface of a sphere |

---

## 2. Game Flow

### GF-001: Game Creation

A new game is created with **5 rounds**. Each round is populated with:
- A random 360° panoramic image URL from CYVL's data store
- The actual geographic coordinates (latitude, longitude) of that image

The first round is set as the current active round.

### GF-002: Round Progression

The player progresses through rounds **sequentially** (round 0 → 1 → 2 → 3 → 4). The game tracks:
- `current_round_index`: which round the player is on (0-based)
- `current_round_id`: the UUID of the active round
- `current_score`: cumulative score across all completed rounds

### GF-003: Guess Submission

For each round, the player:
1. Views the 360° panoramic image
2. Places a pin on an interactive world map
3. Submits their guess
4. Receives a score for that round

After submission, the round is marked complete with the guess location and score recorded.

### GF-004: Per-Round Scoring Feedback

After each guess submission, the player sees:
- Their score for that round
- A map visualization showing both the actual and guessed locations
- A line connecting the two points along the great-circle route
- Their cumulative total score
- A button to proceed to the next round (or to final results if this was round 5)

### GF-005: Game Completion

After all 5 rounds are completed, the player sees:
- A "Game Complete!" message
- Their **final total score** (sum of all 5 round scores)
- A **per-round breakdown** listing each round's individual score
- An option to **play again** (creates a new game)

---

## 3. User Interface Requirements

### 3.1 Design System

#### DS-001: Color Palette

| Role | Value | Description |
|------|-------|-------------|
| Background | `#0c0c0c` | Near-black, used for all screen backgrounds |
| Primary Text | `#fffffe` | Near-white, used for headings and body text |
| Accent / CTA | `#dbff00` | Lime/chartreuse, used for buttons, scores, highlights |
| Error | Red tones | Used for error messages |

#### DS-002: Typography

- System font stack (no custom fonts)
- Bold for headings, semibold for buttons and labels
- Score values use extra-large bold text in the accent color

#### DS-003: Button Styles

All primary action buttons follow this pattern:
- Accent background (`#dbff00`) with dark text (`#0c0c0c`)
- Rounded corners (large border radius)
- Shadow using accent color with transparency
- **Hover**: brightness increase, slight upward translate (-0.5), enhanced shadow
- **Active**: return to base position
- **Disabled**: reduced opacity, not-allowed cursor
- **Loading**: text changes to "Loading..."

#### DS-004: Loading States

- A spinning circular indicator using the accent color
- Descriptive loading text beneath the spinner (e.g., "Loading game...", "Submitting guess...")

#### DS-005: Error States

- Red-tinted error text
- A "Back to Home" button for recovery navigation
- Error messages are human-readable (not raw API errors)

---

### 3.2 Main Screen

**Route:** `/`

#### UI-010: Layout

Full-screen centered layout on dark background containing:
- CYVL logo image (loaded from `/cyvl-logo.png`)
- "GeoGuesser" title in large bold text
- A Play button

#### UI-011: Play Action

Clicking the Play button:
1. Shows a loading state on the button
2. Calls the API to create a new game
3. On success: navigates to `/game/{gameId}` for the new game
4. On failure: displays an error message below the button

---

### 3.3 Guess Screen

**Route:** `/game/:gameId`

#### UI-020: Layout

Full-screen view with two layers:
- **Background layer**: The 360° image viewer filling the entire viewport
- **Overlay layer**: A minimap positioned in the bottom-right corner

#### UI-021: 360° Image Viewer

An iframe displaying CYVL's 3DViewer with the current round's `image_url`. The iframe fills the full width and height of the viewport.

#### UI-022: Minimap

A compact interactive map overlay positioned at the bottom-right of the screen:
- Dimensions: approximately 400×300 pixels
- Rounded corners with a prominent shadow
- Shows a world view (initial center: longitude 0°, latitude 20°, zoom level 1)
- **Click interaction**: clicking anywhere on the map places/moves a pin marker
- **Pin marker**: an emoji-style map pin (📍) at the clicked coordinates
- **Guess button**: appears at the bottom-center of the minimap only after a pin is placed
- Clicking the Guess button submits the pinned coordinates

#### UI-023: Guess Submission

When a guess is submitted:
1. A full-screen translucent overlay appears with a loading spinner and "Submitting guess..." text
2. The guess location is sent to the API
3. On success: navigates to the Score Screen (`/game/{gameId}/score/{roundIndex}`) with the response data passed via router state
4. On failure: shows an error message

#### UI-024: Game State Loading

On mount, the component:
1. Loads the game state from the API using the `gameId` URL parameter
2. Identifies the current round by matching `current_round_id`
3. Displays the current round's 360° image
4. Shows appropriate loading and error states

---

### 3.4 Score Screen

**Route:** `/game/:gameId/score/:roundIndex`

#### UI-030: Layout

Full-screen map view with a translucent score overlay at the top.

#### UI-031: Score Display Overlay

A gradient overlay at the top of the screen (dark at top, fading to transparent) containing:
- **"Round Score"** heading in large bold white text
- **The round score** in extra-large bold accent-colored text (e.g., `#dbff00`)
- **Total cumulative score** in smaller white text below (e.g., "Total Score: 12450")
- **Navigation button**: "Next Round" or "View Results" (if last round)

The overlay should have pointer-events disabled on the gradient background but enabled on the interactive elements.

#### UI-032: Map Visualization

A full-screen interactive map (behind the overlay) displaying:
- A **marker at the actual location** — visually distinct (e.g., green-tinted pin)
- A **marker at the guessed location** — visually distinct (e.g., red-tinted or default pin)
- A **dashed line** connecting the two points following the **great-circle route** (geodesic path, not a straight projected line)
- The map should be initially centered between the two points at a zoom level that shows both markers

#### UI-033: Navigation

- If **not the last round**: the button reads "Next Round" and navigates to `/game/{gameId}` (the Guess Screen loads the next round automatically)
- If **the last round**: the button reads "View Results" and navigates to `/game/{gameId}/results`

#### UI-034: Data Source

The Score Screen receives data via **React Router's location state** (passed during navigation from the Guess Screen). The expected state shape:
- `round`: The completed Round object (with `actual_location`, `guess_location`, and `score` populated)
- `isLastRound`: boolean
- `scoreFromLastRound`: number (the score for this specific round)
- `totalCurrentScore`: number (cumulative score including this round)

If the state is missing or invalid, show an error with a "Back to Home" button.

---

### 3.5 Results Screen

**Route:** `/game/:gameId/results`

#### UI-040: Layout

Full-screen centered layout on dark background with a results card.

#### UI-041: Final Score Display

- "Game Complete!" heading in large bold white text
- A styled card with frosted/blurred background containing:
  - "Final Score" label
  - The total score in extra-large bold accent text

#### UI-042: Round Breakdown

A vertical list showing each of the 5 rounds:
- Each row displays "Round {n}" on the left and the score on the right
- Rows have a subtle background with rounded corners
- Scores are in accent color

#### UI-043: Play Again

A Play button (same style as Main Screen) that creates a new game and navigates to the first round.

---

## 4. API Requirements

### 4.1 Data Models

#### DM-001: Location

| Field | Type | Description |
|-------|------|-------------|
| `latitude` | float | Geographic latitude in degrees |
| `longitude` | float | Geographic longitude in degrees |

#### DM-002: Round

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Unique identifier for the round |
| `actual_location` | Location | Where the image was actually taken |
| `guess_location` | Location \| null | Player's guess (null until submitted) |
| `image_url` | string | URL to the 360° panoramic image viewer |
| `score` | integer \| null | Points awarded (null until scored) |

#### DM-003: Game

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Unique identifier for the game |
| `rounds` | list[Round] | The 5 rounds in this game |
| `current_round_index` | integer | 0-based index of the active round |
| `current_round_id` | UUID \| null | UUID of the active round |
| `current_score` | integer | Cumulative score across all rounds |

---

### 4.2 Endpoints

#### API-001: Create Game

```
POST /game/create

Request Body: {} (empty)

Response (201):
{
    "id": "<game-uuid>"
}
```

**Behavior:**
1. Create a new Game with a unique UUID
2. Generate 5 rounds, each with a random location and 360° image from the data store
3. Set `current_round_index` to 0 and `current_round_id` to the first round's ID
4. Set `current_score` to 0
5. Store the game as the active game
6. Return the game ID

#### API-002: Get Game State

```
GET /game/{game_id}

Response (200):
{
    "current_round_id": "<uuid>" | null,
    "current_round_index": <int>,
    "rounds": [<Round>, ...],
    "current_score": <int>
}
```

**Behavior:**
1. Return the current game state
2. If no active game exists, return 404

#### API-003: Submit Guess

```
POST /guess/{round_id}

Request Body:
{
    "guess_location": {
        "latitude": <float>,
        "longitude": <float>
    }
}

Response (200):
{
    "completed_round": <Round>,
    "is_last_round": <bool>,
    "score_from_last_round": <int>,
    "total_current_score": <int>
}
```

**Behavior:**
1. Validate that an active game exists (404 if not)
2. Set the current round's `guess_location` to the submitted coordinates
3. **Calculate the score** using the scoring algorithm (see Section 4.3)
4. Set the current round's `score` to the calculated value
5. Add the round score to the game's `current_score`
6. Determine if this is the last round (`current_round_index == len(rounds) - 1`)
7. If **not** the last round: increment `current_round_index` and update `current_round_id` to the next round
8. If **the last round**: set `current_round_id` to null
9. Return the completed round (with score and guess filled in), `is_last_round`, the round's score, and the new total

---

### 4.3 Scoring Algorithm

#### SC-001: Distance Calculation — Haversine Formula

The distance between the actual location and the guessed location is calculated using the **Haversine formula**, which gives the great-circle distance between two points on Earth's surface.

Given two points `(lat₁, lon₁)` and `(lat₂, lon₂)` in **degrees**:

1. Convert all values from degrees to radians
2. Compute deltas: `Δlat = lat₂ - lat₁`, `Δlon = lon₂ - lon₁`
3. Compute intermediate value: `a = sin²(Δlat/2) + cos(lat₁) · cos(lat₂) · sin²(Δlon/2)`
4. Compute angular distance: `c = 2 · arcsin(√a)`
5. Compute surface distance: `distance = R · c`

Where `R = 6371.0` km (Earth's mean radius).

#### SC-002: Score Calculation — Exponential Decay

The score uses an **exponential decay model** that rewards precision:

```
score = round(5000 × e^(-distance_km / DECAY_CONSTANT))
```

**Parameters:**
- **Maximum score:** 5000 points (perfect guess at 0 km)
- **Decay constant:** 1500 km
- **Rounding:** Result is rounded to the nearest integer
- **Validation:** Negative distances are invalid and must raise an error

**Reference values:**

| Distance (km) | Approximate Score |
|---------------|-------------------|
| 0 | 5000 |
| 150 | ~4525 |
| 500 | ~3582 |
| 1000 | ~2567 |
| 1500 | ~1839 |
| 3000 | ~677 |
| 5000 | ~178 |
| 10000 | ~6 |

---

## 5. Technical Architecture

### 5.1 Frontend

- **Single-page application** with client-side routing (4 routes)
- **API service layer** that abstracts all backend communication into typed functions
- **Mock API available** for frontend-only testing, toggled by an environment variable. Note: the mock API uses an approximate scoring formula for testing convenience — the backend must implement the precise formula from Section 4.3
- **Interactive maps** for both guess input (minimap) and result visualization (score screen)
- **360° image viewing** via iframe embedding of CYVL's 3DViewer

### 5.2 Backend

- **REST API** with automatic OpenAPI documentation at `/docs`
- **CORS** configured for the frontend development server origin
- **In-memory game state** — single active game stored in a module-level variable
- **Modular package architecture** using a Python workspace

### 5.3 Backend Package Structure

```
api/
├── apps/
│   └── geolocation-api/         # FastAPI application
│       └── src/geolocation_api/
│           ├── app.py           # App factory, CORS middleware
│           ├── routes.py        # API endpoint handlers
│           ├── config.py        # Application settings
│           └── lifespan.py      # Startup/shutdown lifecycle
│
└── packages/
    ├── models/                  # Core data models (Location, Round, Game)
    ├── round-generator/         # Random round generation from data store
    ├── scoring/                 # Distance calculation and score computation
    └── state-management/        # API request/response models
```

### 5.4 Frontend Structure

```
src/
├── App.tsx                      # Router setup (4 routes)
├── main.tsx                     # React entry point
├── index.css                    # Global styles (Tailwind import)
├── components/
│   ├── MainScreen.tsx           # Landing page with Play button
│   ├── GuessScreen.tsx          # Gameplay: 360° viewer + minimap
│   ├── ScoreScreen.tsx          # Per-round score + map visualization
│   ├── ResultsScreen.tsx        # Final score + round breakdown
│   ├── StreetViewer.tsx         # 360° iframe wrapper
│   ├── MiniMap.tsx              # Interactive guess map
│   └── PlayButton.tsx           # Reusable button component
├── services/
│   ├── api.ts                   # API service layer (real + mock routing)
│   └── mockApi.ts               # Mock API for testing
└── types/
    └── api.ts                   # TypeScript type definitions
```

---

## 6. Environment Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `VITE_MAPBOX_TOKEN` | Yes | — | Mapbox GL access token for map rendering |
| `VITE_API_BASE_URL` | No | `http://localhost:8000` | Backend API base URL |
| `VITE_USE_MOCK_API` | No | `false` | Set to `"true"` to use mock API (no backend needed) |

---

## 7. Acceptance Criteria

### AC-001: Full Game Loop

A player can start a new game, play through all 5 rounds (viewing 360° images and guessing locations), see their score after each round with a map visualization, and view final results with a complete breakdown.

### AC-002: Scoring Accuracy

Scores follow the exponential decay formula from SC-002. A perfect guess (0 km) scores exactly 5000. A guess approximately 1500 km away scores approximately 1839.

### AC-003: Score Visualization

After each round, the Score Screen displays both the actual and guessed locations as distinct markers on a map, connected by a great-circle line.

### AC-004: Sequential Progression

The game advances through rounds in strict order (0 → 4). After the 5th round, the player is directed to results. The "Next Round" button correctly alternates with "View Results" on the final round.

### AC-005: Cumulative Scoring

The game tracks a running total score. Each round's score is added to the cumulative total. The Results Screen's total matches the sum of individual round scores.

### AC-006: Error Resilience

All screens handle API errors gracefully with human-readable error messages and navigation options to return home.

### AC-007: Visual Consistency

All screens follow the design system defined in DS-001 through DS-005 (dark background, accent color, consistent button styles, loading spinners, error states).

### AC-008: Map Interactivity

The minimap responds to clicks by placing/moving a pin. The Guess button only appears when a pin is placed. The Score Screen map displays correct marker positions and line geometry.
