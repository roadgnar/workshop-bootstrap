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
    """
    # Convert latitude and longitude from degrees to radians
    lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])

    # Haversine formula
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    )
    c = 2 * math.asin(math.sqrt(a))

    # Earth's radius in kilometers
    earth_radius_km = 6371.0

    return c * earth_radius_km


def calculate_score_from_distance(distance_km: float) -> int:
    """
    Calculate score based on distance from actual location using GeoGuesser's exponential decay formula.

    GeoGuesser uses an exponential decay model:
    score = 5000 * exp(-distance / constant)

    Args:
        distance_km: Distance in kilometers from the actual location

    Returns:
        Score between 0 and 5000
    """
    if distance_km < 0:
        raise ValueError("Distance cannot be negative.")

    score = 5000 * math.exp(-distance_km / DECAY_CONSTANT_KM)

    return round(score)


def score_round(round: Round, guess_location: Location) -> int:
    """
    Calculate the score for a round based on the distance between the guess and actual location.

    Uses GeoGuesser's exponential decay scoring formula where small errors are heavily
    penalized and larger distances are more forgiving.

    Args:
        round: The round object containing the actual location
        guess_location: The player's guessed location

    Returns:
        Score between 0 and 5000
    """
    distance = haversine_distance(
        round.actual_location.latitude,
        round.actual_location.longitude,
        guess_location.latitude,
        guess_location.longitude,
    )

    return calculate_score_from_distance(distance)
