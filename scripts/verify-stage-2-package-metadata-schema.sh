#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA_FILE="$ROOT_DIR/docs/contracts/package-metadata.schema.json"
INDEX_EXAMPLE_FILE="$ROOT_DIR/docs/contracts/index.example.json"

if [ ! -f "$SCHEMA_FILE" ]; then
	echo "[verify-stage-2-package-metadata-schema] missing schema file: $SCHEMA_FILE"
	exit 1
fi

if [ ! -f "$INDEX_EXAMPLE_FILE" ]; then
	echo "[verify-stage-2-package-metadata-schema] missing index example file: $INDEX_EXAMPLE_FILE"
	exit 1
fi

python3 - "$ROOT_DIR" "$SCHEMA_FILE" "$INDEX_EXAMPLE_FILE" <<'PY'
import json
import os
import sys

root_dir = sys.argv[1]
schema_path = sys.argv[2]
index_example_path = sys.argv[3]

with open(schema_path, "r", encoding="utf-8") as f:
    schema = json.load(f)

with open(index_example_path, "r", encoding="utf-8") as f:
    index_doc = json.load(f)

required_props = ["name", "latest", "repository", "versions"]
schema_props = schema.get("properties", {})
for prop in required_props:
    if prop not in schema_props:
        raise SystemExit(f"schema missing required property contract: {prop}")

packages = index_doc.get("packages", [])
if not packages:
    raise SystemExit("index example must contain packages for metadata verification")

for package in packages:
    metadata_path = package.get("metadata_path", "")
    if not metadata_path:
        raise SystemExit("package entry is missing metadata_path")

    metadata_file = os.path.join(root_dir, "docs", "contracts", metadata_path)
    if not os.path.isfile(metadata_file):
        raise SystemExit(f"metadata fixture missing: {metadata_file}")

    with open(metadata_file, "r", encoding="utf-8") as f:
        metadata = json.load(f)

    for key in required_props:
        if key not in metadata:
            raise SystemExit(f"metadata fixture missing key `{key}`: {metadata_file}")

    if metadata["name"] != package["name"]:
        raise SystemExit(f"metadata name mismatch for {metadata_file}")

    if metadata["latest"] != package["latest"]:
        raise SystemExit(f"metadata latest mismatch for {metadata_file}")

    if not isinstance(metadata["versions"], list) or len(metadata["versions"]) == 0:
        raise SystemExit(f"metadata versions must be a non-empty array: {metadata_file}")

    for version in metadata["versions"]:
        for key in ["version", "source", "ref"]:
            if key not in version:
                raise SystemExit(f"metadata version entry missing `{key}` in {metadata_file}")

print("[verify-stage-2-package-metadata-schema] success")
PY
