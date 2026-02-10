import math
from models.models import Round, Location

DECAY_CONSTANT_KM = 1500.0


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate the great-circle distance between two points on Earth using the Haversine formula.

    Args:
        lat1, lon1: Latitude and longitude of the first point in degrees
        lat2, lon2: Latitude and longitude of the second point in degrees

    Returns:
        Distance in kilometers

    See: SRS Section 4.3 — SC-001
    """
    raise NotImplementedError(
        "TODO: Implement haversine distance calculation — see SRS Section 4.3 (SC-001)"
    )


def calculate_score_from_distance(distance_km: float) -> int:
    """
    Calculate score based on distance from actual location using exponential decay.

    Uses the formula: score = 5000 * exp(-distance / DECAY_CONSTANT_KM)

    Args:
        distance_km: Distance in kilometers from the actual location

    Returns:
        Score between 0 and 5000

    Raises:
        ValueError: If distance is negative

    See: SRS Section 4.3 — SC-002
    """
    raise NotImplementedError(
        "TODO: Implement score calculation — see SRS Section 4.3 (SC-002)"
    )


def score_round(round: Round, guess_location: Location) -> int:
    """
    Calculate the score for a round based on the distance between the guess and actual location.

    This is the main entry point for scoring. It should:
    1. Calculate the haversine distance between the round's actual location and the guess
    2. Convert that distance to a score using the exponential decay formula

    Args:
        round: The round object containing the actual location
        guess_location: The player's guessed location

    Returns:
        Score between 0 and 5000

    See: SRS Section 4.3
    """
    raise NotImplementedError(
        "TODO: Implement round scoring — see SRS Section 4.3"
    )
