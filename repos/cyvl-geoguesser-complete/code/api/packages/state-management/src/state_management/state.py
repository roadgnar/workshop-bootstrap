from pydantic import BaseModel
from uuid import UUID
from models.models import Round, Location


class GameStateResponse(BaseModel):
    current_round_id: UUID | None
    rounds: list[Round]
    current_round_index: int
    current_score: int


class CreateGameResponse(BaseModel):
    id: UUID


class GuessRequest(BaseModel):
    guess_location: Location


class GuessResponse(BaseModel):
    completed_round: Round
    is_last_round: bool
    score_from_last_round: int
    total_current_score: int
