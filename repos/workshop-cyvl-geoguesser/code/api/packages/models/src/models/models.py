from pydantic import UUID1, BaseModel
from uuid import UUID

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