import uuid
from pathlib import Path
from round_generator.data_store import FileBasedDataStore, Project
from round_generator.round_generator import RandomRoundGenerator
import logging

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

def test_random_round_generator():
    current_dir = Path(__file__).parent
    data_store = FileBasedDataStore(current_dir / "data_store_example")
    round_generator = RandomRoundGenerator(data_store)
    round = round_generator.generate_round()
    assert round.actual_location is not None
    assert round.image_url is not None
    assert round.guess_location is None
    assert round.score is None
    assert round.id is not None