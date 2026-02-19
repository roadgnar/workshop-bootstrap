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
