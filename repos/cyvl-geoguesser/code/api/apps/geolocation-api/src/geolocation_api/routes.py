from pathlib import Path
import uuid
import copy
from round_generator.data_store import FileBasedDataStore
from fastapi import APIRouter, HTTPException, status
from pydantic import UUID1, BaseModel
from uuid import UUID
from models.models import Game, Round, Location
from round_generator.round_generator import RandomRoundGenerator
from state_management.state import (
    CreateGameResponse,
    GameStateResponse,
    GuessResponse,
    GuessRequest,
)
from scoring.score_round import score_round as score_round_function

router = APIRouter()

# Initialize the round generator
data_dir = Path(__file__).parent.parent.parent / "data"
file_based_data_store = FileBasedDataStore(data_dir)
round_generator = RandomRoundGenerator(file_based_data_store)
current_game = None


@router.post("/game/create", response_model=CreateGameResponse)
async def create_game():
    """
    Create a new game round by generating a random location and image
    """
    try:
        global current_game
        game = Game(
            id=uuid.uuid4(),
            rounds=[],
            current_round_index=0,
            current_round_id=None,
            current_score=0,
        )
        for i in range(5):
            round_data = round_generator.generate_round()
            game.rounds.append(round_data)
        current_round_id = game.rounds[0].id
        game.current_round_id = current_round_id
        current_game = game

        return CreateGameResponse(id=game.id)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate round: {str(e)}",
        )


@router.get("/game/{id}", response_model=GameStateResponse)
async def get_game_state(id: str):
    """
    Get the current game state including all rounds and current round index
    """
    global current_game
    if current_game is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No active game state found. Please create a game first.",
        )
    response = GameStateResponse(
        current_round_id=current_game.current_round_id,
        rounds=current_game.rounds,
        current_round_index=current_game.current_round_index,
        current_score=current_game.current_score,
    )
    return response


@router.post("/guess/{round_id}", response_model=GuessResponse)
async def submit_guess(round_id: UUID, guess_request: GuessRequest):
    """
    Submit a guess for a specific round — see SRS Section 4.2 (API-003)

    Args:
        round_id: UUID of the round to submit a guess for
        guess_request: Contains the guessed location (latitude, longitude)

    Returns:
        GuessResponse with: completed_round, is_last_round, score_from_last_round, total_current_score
    """
    # TODO: Implement guess submission — see SRS Section 4.2 (API-003)
    #
    # This endpoint should:
    # 1. Validate that a game exists (return 404 if not)
    # 2. Set the current round's guess_location from the request
    # 3. Calculate the score using the scoring package (score_round_function)
    # 4. Set the current round's score
    # 5. Add the round score to the game's current_score
    # 6. Determine if this is the last round (current_round_index == len(rounds) - 1)
    # 7. If not the last round: advance current_round_index and current_round_id
    # 8. If the last round: set current_round_id to None
    # 9. Return a GuessResponse with the completed round data
    #
    # Hints:
    # - Use copy.deepcopy() to capture the round state BEFORE advancing to the next round
    # - The score_round_function is imported at the top of this file
    # - Look at how create_game and get_game_state use the global current_game variable

    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Guess submission not yet implemented — see SRS Section 4.2 (API-003)",
    )
