#!/usr/bin/env python3
"""
Script to update job_listings.json with entries for all zip files in job_deliverables directory.
Each zip file gets an entry with its filename (minus .zip extension) as the project_id.
"""

import json
import os
from pathlib import Path

# Define paths
script_dir = Path(__file__).parent
deliverables_dir = script_dir / "data" / "job_deliverables"
listings_file = script_dir / "data" / "job_listings.json"

def main():
    # Get all zip files from job_deliverables directory
    zip_files = sorted(deliverables_dir.glob("*.zip"))
    
    if not zip_files:
        print("No zip files found in job_deliverables directory.")
        return
    
    print(f"Found {len(zip_files)} zip file(s):")
    
    # Read existing entries to avoid duplicates
    existing_ids = set()
    if listings_file.exists():
        with open(listings_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        entry = json.loads(line)
                        existing_ids.add(entry.get('project_id'))
                    except json.JSONDecodeError:
                        pass
    
    # Open file in append mode and add new entries
    new_entries = []
    with open(listings_file, 'a') as f:
        for zip_file in zip_files:
            # Extract filename without .zip extension
            project_id = zip_file.stem
            
            if project_id not in existing_ids:
                entry = {"project_id": project_id}
                # Write as a new line in NDJSON format
                f.write(json.dumps(entry) + '\n')
                new_entries.append(project_id)
                print(f"  ✓ Added: {project_id}")
            else:
                print(f"  - Skipped (already exists): {project_id}")
    
    if new_entries:
        print(f"\nSuccessfully added {len(new_entries)} new entry(ies) to {listings_file}")
    else:
        print(f"\nNo new entries added. All zip files already have entries in {listings_file}")

if __name__ == "__main__":
    main()

