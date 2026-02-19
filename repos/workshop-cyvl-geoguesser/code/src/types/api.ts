// API Type Definitions

export interface Location {
  latitude: number;
  longitude: number;
}

export interface Round {
  id: string; // UUID
  image_url: string;
  actual_location: Location | null;
  guess_location: Location | null;
  score: number | null;
}

export interface Game {
  current_round_id: string | null;
  current_round_index: number;
  rounds: Round[];
}

// API Request/Response types

export interface CreateGameResponse {
  id: string; // UUID
}

export interface GetGameResponse {
  current_round_id: string | null;
  current_round_index: number;
  rounds: Round[];
  current_score: number;
}
