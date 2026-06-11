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

required_patterns=(
	'"schema_version": "1.0"'
	'"dry_run": 1'
	'"name":"install"'
	'"name":"update"'
	'"name":"api-search"'
	'"name":"api-metadata"'
	'"max_regression_percent": 15'
)

for pattern in "${required_patterns[@]}"; do
	if ! grep -Fq -- "$pattern" "$OUTPUT_PATH"; then
		echo "[verify-benchmark-harness] missing required benchmark field: $pattern"
		exit 1
	fi
done

echo "[verify-benchmark-harness] success"
