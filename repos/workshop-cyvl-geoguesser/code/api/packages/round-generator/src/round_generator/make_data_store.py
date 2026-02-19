from cloudpathlib import S3Path
from pathlib import Path
# SCRIPT THAT WILL READ FROM S3 RESULTS FOLDER, LOOK FOR PANO IMAGERY, and WRITE THEM LOCALLY


files_to_match = [
    "panoramicImagery_v2.zip"
]

def get_list_of_orgs(orgs_folder: S3Path) -> list[S3Path]:
    return [org for org in orgs_folder.iterdir()]

def process_org(org: S3Path) -> dict[str, S3Path]:

    projects_to_path = {}
    try:
        org_results_folder = org / "results"
        projects_paths = [project for project in org_results_folder.iterdir()]
        for project_path in projects_paths:
            files_in_project = [file for file in project_path.iterdir()]
            for file in files_in_project:
                if file.name in files_to_match:
                    projects_to_path[project_path.name] = file
    except Exception as e:
        print(f"Error processing org {org}: {e}")
        return None
    return projects_to_path


def make_data_store(s3_results_folder: str, local_data_store_folder: str):
    orgs_folder = S3Path(s3_results_folder)
    local_data_store_folder = Path(local_data_store_folder)
    local_data_store_folder.mkdir(parents=True, exist_ok=True)
    orgs = get_list_of_orgs(orgs_folder)
    #orgs = [org for org in orgs if org.name == "nycdot"]
    for org in orgs:
        projects_to_path = process_org(org)
        for project_id, path in projects_to_path.items():
            print(f"Project {project_id} found at {path}, downloading...")
            with open(f"{local_data_store_folder}/{project_id}.zip", "wb") as f:
                f.write(path.read_bytes())
            print(f"Project {project_id} downloaded to {local_data_store_folder}/{project_id}.zip")

# You can also copy the datastore that PJ will maintain with an S3 sync



if __name__ == "__main__":
    make_data_store(
        s3_results_folder="s3://cyvlplatformstorage172117-staging/orgs/",
        local_data_store_folder="data/data_store",
    )