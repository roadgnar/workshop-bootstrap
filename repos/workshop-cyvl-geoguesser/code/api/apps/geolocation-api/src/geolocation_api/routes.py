from pathlib import Path
import uuid
from round_generator.data_store import FileBasedDataStore
from fastapi import APIRouter, HTTPException, status
from uuid import UUID
from models.models import Game, Round, Location
from round_generator.round_generator import RandomRoundGenerator
from state_management.state import (
    CreateGameResponse,
    GameStateResponse,
)

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
