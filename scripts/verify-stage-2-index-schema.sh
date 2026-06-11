#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA_FILE="$ROOT_DIR/docs/contracts/index.schema.json"
EXAMPLE_FILE="$ROOT_DIR/docs/contracts/index.example.json"

if [ ! -f "$SCHEMA_FILE" ]; then
	echo "[verify-stage-2-index-schema] missing schema file: $SCHEMA_FILE"
	exit 1
fi

if [ ! -f "$EXAMPLE_FILE" ]; then
	echo "[verify-stage-2-index-schema] missing example file: $EXAMPLE_FILE"
	exit 1
fi

python3 - "$SCHEMA_FILE" "$EXAMPLE_FILE" <<'PY'
import json
import re
import sys

schema_path = sys.argv[1]
example_path = sys.argv[2]

with open(schema_path, "r", encoding="utf-8") as f:
    schema = json.load(f)

with open(example_path, "r", encoding="utf-8") as f:
    example = json.load(f)

required_top = ["schema_version", "generated_at", "packages"]
for key in required_top:
    if key not in schema.get("properties", {}):
        raise SystemExit(f"schema is missing required top-level property contract: {key}")

if not isinstance(example.get("schema_version"), int):
    raise SystemExit("example schema_version must be an integer")

if not isinstance(example.get("packages"), list) or len(example["packages"]) == 0:
    raise SystemExit("example packages must be a non-empty array")

for package in example["packages"]:
    for key in ["name", "latest", "metadata_path", "versions"]:
        if key not in package:
            raise SystemExit(f"example package entry missing key: {key}")

    if not re.match(r"^packages/.+\.json$", package["metadata_path"]):
        raise SystemExit("example metadata_path must match packages/<name>.json")

    if not isinstance(package["versions"], list) or len(package["versions"]) == 0:
        raise SystemExit("example versions must be a non-empty array")

    for version in package["versions"]:
        for key in ["version", "source", "ref"]:
            if key not in version:
                raise SystemExit(f"example version entry missing key: {key}")

print("[verify-stage-2-index-schema] success")
PY
