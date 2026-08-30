#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BENCH_SCRIPT="$ROOT_DIR/scripts/benchmark-harness.sh"
OUTPUT_PATH="$ROOT_DIR/.kennel_tmp/benchmarks/verify-dry-run.json"

if [ ! -f "$BENCH_SCRIPT" ]; then
	echo "[verify-benchmark-harness] missing benchmark script: $BENCH_SCRIPT"
	exit 1
fi

BENCH_DRY_RUN=1 BENCH_OUTPUT="$OUTPUT_PATH" bash "$BENCH_SCRIPT"

if [ ! -f "$OUTPUT_PATH" ]; then
	echo "[verify-benchmark-harness] missing output file: $OUTPUT_PATH"
	exit 1
fi

python3 - "$OUTPUT_PATH" <<'PY'
import json
import sys

output_path = sys.argv[1]
with open(output_path, encoding="utf-8") as handle:
    report = json.load(handle)

assert report["schema_version"] == "1.0"
assert report["dry_run"] == 1
assert report["thresholds"]["max_regression_percent"] == 15

expected_operations = {"install", "update", "api-search", "api-metadata"}
operations = report["operations"]
assert {operation["name"] for operation in operations} == expected_operations
for operation in operations:
    assert isinstance(operation["durations_ms"], list)
    assert isinstance(operation["avg_ms"], int)
    assert isinstance(operation["min_ms"], int)
    assert isinstance(operation["max_ms"], int)
PY

echo "[verify-benchmark-harness] success"
