// Mock API Service for Testing

import type {
  CreateGameResponse,
  GetGameResponse,
  SubmitGuessResponse,
  Location,
  Round,
} from '../types/api';

// Mock 360° image URLs using CYVL's image format
// These are sample CYVL CloudFront URLs - replace with actual game images from backend
const MOCK_IMAGES = [
  'https://platform.cyvl.ai/3DViewer.html?image_url=https://dcygqrjfsypox.cloudfront.net/d445b396018a64ef96e17914809b32c7609dbccacdfb42b41a2d2e8f25235dd3/images360/GS010072_360_1747066090756859_360_3000.jpg',
  'https://platform.cyvl.ai/3DViewer.html?image_url=https://dcygqrjfsypox.cloudfront.net/d445b396018a64ef96e17914809b32c7609dbccacdfb42b41a2d2e8f25235dd3/images360/GS010072_360_1747069308979679_360_3000.jpg',
  'https://platform.cyvl.ai/3DViewer.html?image_url=https://dcygqrjfsypox.cloudfront.net/d445b396018a64ef96e17914809b32c7609dbccacdfb42b41a2d2e8f25235dd3/images360/GS020072_360_1747075090553070_360_3000.jpg',
  'https://platform.cyvl.ai/3DViewer.html?image_url=https://dcygqrjfsypox.cloudfront.net/d445b396018a64ef96e17914809b32c7609dbccacdfb42b41a2d2e8f25235dd3/images360/GS020072_360_1747078539817462_360_3000.jpg',
  'https://platform.cyvl.ai/3DViewer.html?image_url=https://dcygqrjfsypox.cloudfront.net/d445b396018a64ef96e17914809b32c7609dbccacdfb42b41a2d2e8f25235dd3/images360/GS030072_360_1747083214998723_360_3000.jpg',
];

// Mock locations around the world
const MOCK_LOCATIONS = [
  { latitude: 40.7128, longitude: -74.0060, name: 'New York' },
  { latitude: 35.6762, longitude: 139.6503, name: 'Tokyo' },
  { latitude: 48.8566, longitude: 2.3522, name: 'Paris' },
  { latitude: -33.8688, longitude: 151.2093, name: 'Sydney' },
  { latitude: 51.5074, longitude: -0.1278, name: 'London' },
];

// Store mock game state
const mockGames = new Map<string, GetGameResponse>();

// Generate a random UUID-like string
function generateId(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

// Calculate score based on distance (simplified scoring)
function calculateScore(actual: Location, guess: Location): number {
  const R = 6371; // Earth's radius in km
  const dLat = (guess.latitude - actual.latitude) * Math.PI / 180;
  const dLon = (guess.longitude - actual.longitude) * Math.PI / 180;
  const a = 
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(actual.latitude * Math.PI / 180) * Math.cos(guess.latitude * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const distance = R * c; // Distance in km

  // Score decreases with distance (max 5000 points)
  // Perfect guess = 5000, 0km away gets 5000, 1000km+ away gets 0
  const score = Math.max(0, Math.round(5000 * (1 - distance / 1000)));
  return score;
}

// Add delay to simulate network request
function delay(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Mock: Creates a new game
 */
export async function createGame(): Promise<CreateGameResponse> {
  await delay(500); // Simulate network delay

  const gameId = generateId();
  const rounds: Round[] = MOCK_LOCATIONS.slice(0, 5).map((location, index) => ({
    id: generateId(),
    image_url: MOCK_IMAGES[index],
    actual_location: { latitude: location.latitude, longitude: location.longitude },
    guess_location: null,
    score: null,
  }));

  const game: GetGameResponse & { total_score: number } = {
    current_round_id: rounds[0].id,
    current_round_index: 0,
    rounds,
    current_score: 0,
    total_score: 0,
  };

  mockGames.set(gameId, game as any);

  console.log('🎮 [Mock API] Created game:', gameId);
  return { id: gameId };
}

/**
 * Mock: Gets game data by game ID
 */
export async function getGame(gameId: string): Promise<GetGameResponse> {
  await delay(300); // Simulate network delay

  const game = mockGames.get(gameId);
  
  if (!game) {
    throw new Error(`Game ${gameId} not found`);
  }

  console.log('🎮 [Mock API] Retrieved game:', gameId, game);
  
  // Ensure current_score is included
  const gameWithScore = game as any;
  if (gameWithScore.total_score !== undefined) {
    return { ...game, current_score: gameWithScore.total_score };
  }
  
  return { ...game, current_score: 0 }; // Return a copy with current_score
}

/**
 * Mock: Submits a guess for a specific round
 */
export async function submitGuess(
  roundId: string,
  guessLocation: Location
): Promise<SubmitGuessResponse> {
  await delay(800); // Simulate network delay

  // Find the game containing this round
  let foundGame: GetGameResponse | undefined;
  let foundGameId: string | undefined;

  for (const [gameId, game] of mockGames.entries()) {
    if (game.rounds.some(r => r.id === roundId)) {
      foundGame = game;
      foundGameId = gameId;
      break;
    }
  }

  if (!foundGame || !foundGameId) {
    throw new Error(`Round ${roundId} not found in any game`);
  }

  const roundIndex = foundGame.rounds.findIndex(r => r.id === roundId);
  const round = foundGame.rounds[roundIndex];

  if (!round) {
    throw new Error(`Round ${roundId} not found`);
  }

  // Calculate score (actual_location should never be null in our mock data)
  if (!round.actual_location) {
    throw new Error('Round is missing actual_location');
  }
  
  const score = calculateScore(round.actual_location, guessLocation);

  // Update the round with guess and score
  round.guess_location = guessLocation;
  round.score = score;

  // Update total score
  const gameWithScore = foundGame as any;
  if (gameWithScore.total_score === undefined) {
    gameWithScore.total_score = 0;
  }
  gameWithScore.total_score += score;
  const totalScore = gameWithScore.total_score;

  // Move to next round if available
  const isLastRound = roundIndex === foundGame.rounds.length - 1;
  if (!isLastRound) {
    foundGame.current_round_index = roundIndex + 1;
    foundGame.current_round_id = foundGame.rounds[roundIndex + 1].id;
  }

  // Save updated game
  mockGames.set(foundGameId, foundGame);

  console.log('🎮 [Mock API] Submitted guess for round:', roundId, {
    guess: guessLocation,
    actual: round.actual_location,
    score,
    totalScore,
    isLastRound,
  });

  return {
    completed_round: { ...round },
    is_last_round: isLastRound,
    score_from_last_round: score,
    total_current_score: totalScore,
  };
}

