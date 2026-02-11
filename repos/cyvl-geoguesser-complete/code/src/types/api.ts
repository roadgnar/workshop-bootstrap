// API Type Definitions

export interface Location {
  latitude: number;
  longitude: number;
}

export interface Round {
  id: string; // UUID
  image_url: string;
  actual_location: Location | null; // null until guess is submitted
  guess_location: Location | null; // null until guess is submitted
  score: number | null; // null until guess is submitted
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

export interface SubmitGuessRequest {
  guess_location: Location;
}

export interface SubmitGuessResponse {
  completed_round: Round;
  is_last_round: boolean;
  score_from_last_round: number;
  total_current_score: number;
}

