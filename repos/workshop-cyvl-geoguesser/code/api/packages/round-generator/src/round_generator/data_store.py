from pydantic import BaseModel, Field
from models.models import Location
import uuid
import random
from pathlib import Path
import geopandas as gpd

class Project(BaseModel):
    project_id: uuid.UUID

class LocationWithImage(Location):
    image_url: str


class JobDeliverable(BaseModel):
    job_id: uuid.UUID
    location: list[Location] = Field(default_factory=list)

class DataStore:

    def get_possible_projects(self) -> list[Project]:
        pass

    def get_random_project(self) -> Project:
        pass

    def get_project_by_id(self, id: uuid.UUID) -> Project:
        pass

    def get_possible_locations_from_project(self, project: Project) -> list[Location]:
        pass

    def get_random_location(self) -> LocationWithImage:
        pass


class FileBasedDataStore:

    def __init__(self, datastore_path: Path):
        self.datastore_path = datastore_path
        self.jobs_available_file = self.datastore_path / "job_listings.json"
        self.job_deliverables_folder = self.datastore_path / "job_deliverables"
        assert self.jobs_available_file.exists(), f"Jobs available file {self.jobs_available_file} does not exist"
        assert self.job_deliverables_folder.exists(), f"Job deliverables folder {self.job_deliverables_folder} does not exist"
        all_jobs = self.read_jobs_available()
        # Filter to only include projects that have zip files
        self.jobs_available = [
            job for job in all_jobs
            if (self.job_deliverables_folder / f"{job.project_id}.zip").exists()
        ]

    def read_jobs_available(self) -> list[Project]:
        with open(self.jobs_available_file, "r") as f:
            return [Project.model_validate_json(line) for line in f.readlines()]

    def get_possible_projects(self) -> list[Project]:
        return self.jobs_available

    def get_random_project(self) -> Project:
        return random.choice(self.jobs_available)
    
    def get_possible_locations_from_project(self, project: Project) -> list[LocationWithImage]:
        specific_job_deliverable_path = self.job_deliverables_folder / f"{project.project_id}.zip"
        assert specific_job_deliverable_path.exists(), f"Job deliverable {specific_job_deliverable_path} does not exist"
        gdf = gpd.read_file(specific_job_deliverable_path)
        # assert that the columns that are supposed to be there are there
        required_cols = ["lat", "lon", "image_url"]
        try:
            gdf = gdf[required_cols]
            gdf.rename(columns={"lat": "latitude", "lon": "longitude"}, inplace=True)
        except KeyError as e:
            raise ValueError(f"Job deliverable {specific_job_deliverable_path} does not have the required columns: {e}")

        locations = [LocationWithImage(latitude=row["latitude"], longitude=row["longitude"], image_url=row["image_url"]) for row in gdf.to_dict(orient="records")]
        
        return locations
    
    def get_random_location(self) -> LocationWithImage:
        return random.choice(self.get_possible_locations_from_project(self.get_random_project()))
