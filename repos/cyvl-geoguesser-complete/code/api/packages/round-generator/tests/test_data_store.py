import uuid
from pathlib import Path
from round_generator.data_store import FileBasedDataStore, Project

def test_project_parse_line():
    line = '{"project_id": "7aea928b-ccf0-414c-a86a-624cde68d8a7"}'
    project = Project.model_validate_json(line)
    assert project.project_id == uuid.UUID("7aea928b-ccf0-414c-a86a-624cde68d8a7")


def test_data_store():
    current_dir = Path(__file__).parent
    data_store = FileBasedDataStore(current_dir / "data_store_example")
    assert data_store.get_possible_projects() == [Project(project_id=uuid.UUID("7aea928b-ccf0-414c-a86a-624cde68d8a7"))]

    possible_locations = data_store.get_possible_locations_from_project(data_store.get_random_project())
    assert len(possible_locations) > 1




