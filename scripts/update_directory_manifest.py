#!/usr/bin/env python3
"""
update_directory_manifest.py
Scans all JSON files in directory/churches/ and updates directory/manifest.json.
"""

import json
from pathlib import Path
from datetime import datetime, timezone

DIRECTORY_DIR = Path(__file__).resolve().parent.parent / "directory"
CHURCHES_DIR = DIRECTORY_DIR / "churches"
MANIFEST_FILE = DIRECTORY_DIR / "manifest.json"

DATASET_METADATA = {
    "connecticut-churches.json": {
        "id": "connecticut-churches",
        "name": "Connecticut Churches",
        "state": "CT"
    },
    "snec-churches.json": {
        "id": "snec-churches",
        "name": "Southern New England Conference",
        "conference": "Southern New England Conference"
    },
    "northeastern-churches.json": {
        "id": "northeastern-churches",
        "name": "Northeastern Conference",
        "conference": "Northeastern Conference"
    },
    "greater-new-york-churches.json": {
        "id": "greater-new-york-churches",
        "name": "Greater New York Conference",
        "conference": "Greater New York Conference"
    },
    "new-york-conference-churches.json": {
        "id": "new-york-conference-churches",
        "name": "New York Conference",
        "conference": "New York Conference"
    },
    "northern-new-england-churches.json": {
        "id": "northern-new-england-churches",
        "name": "Northern New England Conference",
        "conference": "Northern New England Conference"
    },
    "alabama-churches.json": {
        "id": "alabama-churches",
        "name": "Alabama Churches",
        "state": "AL"
    },
    "alaska-churches.json": {
        "id": "alaska-churches",
        "name": "Alaska Churches",
        "state": "AK"
    },
    "arizona-churches.json": {
        "id": "arizona-churches",
        "name": "Arizona Churches",
        "state": "AZ"
    },
    "arkansas-churches.json": {
        "id": "arkansas-churches",
        "name": "Arkansas Churches",
        "state": "AR"
    },
    "california-churches.json": {
        "id": "california-churches",
        "name": "California Churches",
        "state": "CA"
    },
    "colorado-churches.json": {
        "id": "colorado-churches",
        "name": "Colorado Churches",
        "state": "CO"
    }
}

def main():
    if not CHURCHES_DIR.exists():
        print(f"Directory {CHURCHES_DIR} does not exist.")
        return

    # Load existing manifest if present to preserve version numbers
    existing_versions = {}
    current_manifest_version = 1
    if MANIFEST_FILE.exists():
        try:
            with open(MANIFEST_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                current_manifest_version = data.get("version", 1)
                for ds in data.get("datasets", []):
                    existing_versions[ds.get("id")] = ds.get("version", 1)
        except Exception as e:
            print(f"Warning reading existing manifest: {e}")

    datasets = []
    json_files = sorted(CHURCHES_DIR.glob("*.json"))

    for json_file in json_files:
        filename = json_file.name
        try:
            with open(json_file, "r", encoding="utf-8") as f:
                doc = json.load(f)
            records = doc.get("records", [])
            schema_version = doc.get("schemaVersion", 1)
            
            meta = DATASET_METADATA.get(filename, {
                "id": json_file.stem,
                "name": json_file.stem.replace("-", " ").title()
            })
            
            ds_id = meta.get("id", json_file.stem)
            ds_version = existing_versions.get(ds_id, 1)

            entry = {
                "id": ds_id,
                "filename": filename,
                "name": meta.get("name", ds_id),
                "version": ds_version,
                "recordCount": len(records)
            }
            if "state" in meta:
                entry["state"] = meta["state"]
            if "conference" in meta:
                entry["conference"] = meta["conference"]

            datasets.append(entry)
            print(f"Indexed {filename}: {len(records)} records (v{ds_version})")
        except Exception as e:
            print(f"Error parsing {filename}: {e}")

    manifest = {
        "schemaVersion": 1,
        "version": current_manifest_version,
        "lastUpdated": datetime.now(timezone.utc).isoformat(),
        "datasets": datasets
    }

    with open(MANIFEST_FILE, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)

    print(f"\nUpdated {MANIFEST_FILE} with {len(datasets)} datasets (manifest v{current_manifest_version})")

if __name__ == "__main__":
    main()
