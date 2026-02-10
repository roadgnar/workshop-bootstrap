from models.models import Round, Location


# See SRS Section 4.3 for scoring algorithm specification


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate the great-circle distance in kilometers between two points on Earth."""
    raise NotImplementedError


def calculate_score_from_distance(distance_km: float) -> int:
    """Convert a distance in km to a score between 0 and 5000."""
    raise NotImplementedError


def score_round(round: Round, guess_location: Location) -> int:
    """Score a round given the player's guess location."""
    raise NotImplementedError
