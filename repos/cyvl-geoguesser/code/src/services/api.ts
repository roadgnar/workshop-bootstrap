// API Service Layer

import type {
  CreateGameResponse,
  GetGameResponse,
  SubmitGuessRequest,
  SubmitGuessResponse,
  Location,
} from '../types/api';

// Check if we should use mock API
const USE_MOCK_API = import.meta.env.VITE_USE_MOCK_API === 'true';

// Conditionally import mock API
let mockApi: typeof import('./mockApi') | null = null;

if (USE_MOCK_API) {
  console.log('🎮 Using Mock API - No real backend needed!');
  mockApi = await import('./mockApi');
}

// Get API base URL from environment variables
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000';

/**
 * Creates a new game
 */
export async function createGame(): Promise<CreateGameResponse> {
  if (mockApi) {
    return mockApi.createGame();
  }

  const response = await fetch(`${API_BASE_URL}/game/create`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({}),
  });

  if (!response.ok) {
    throw new Error(`Failed to create game: ${response.statusText}`);
  }

  return response.json();
}

/**
 * Gets game data by game ID
 */
export async function getGame(gameId: string): Promise<GetGameResponse> {
  if (mockApi) {
    return mockApi.getGame(gameId);
  }

  const response = await fetch(`${API_BASE_URL}/game/${gameId}`, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to get game: ${response.statusText}`);
  }

  return response.json();
}

/**
 * Submits a guess for a specific round
 */
export async function submitGuess(
  roundId: string,
  guessLocation: Location
): Promise<SubmitGuessResponse> {
  if (mockApi) {
    return mockApi.submitGuess(roundId, guessLocation);
  }

  const response = await fetch(`${API_BASE_URL}/guess/${roundId}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      guess_location: guessLocation,
    } as SubmitGuessRequest),
  });

  if (!response.ok) {
    throw new Error(`Failed to submit guess: ${response.statusText}`);
  }

  return response.json();
}

