from models.models import Round, Location
import uuid

from round_generator.data_store import FileBasedDataStore

class RoundGenerator:

    def generate_round(self) -> Round:
        pass


class TestRoundGenerator(RoundGenerator):

    def generate_round(self) -> Round:
        return Round(
            id=uuid.uuid4(),
            actual_location=Location(latitude=40.7128, longitude=-74.0060),
            image_url="https://example.com/image.jpg",
        )

class RandomRoundGenerator(RoundGenerator):
    # TODO make this not hardcoded, pull from a datastore that has a list of images and locations
    def __init__(self, data_store: FileBasedDataStore):
        self.data_store = data_store
    
    def generate_round(self) -> Round:
        location_with_image = self.data_store.get_random_location()
        return Round(
            id=uuid.uuid4(),
            actual_location=Location(latitude=location_with_image.latitude, longitude=location_with_image.longitude),
            image_url=location_with_image.image_url,
            guess_location=None,
            score=None,
        )