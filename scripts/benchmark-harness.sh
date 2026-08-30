#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"

BENCH_ROOT="${BENCH_ROOT:-$ROOT_DIR/.kennel_tmp/benchmarks}"
BENCH_OUTPUT="${BENCH_OUTPUT:-$BENCH_ROOT/results.json}"
BENCH_ITERATIONS="${BENCH_ITERATIONS:-3}"
BENCH_WARMUP="${BENCH_WARMUP:-1}"
BENCH_DRY_RUN="${BENCH_DRY_RUN:-0}"
BENCH_KEEP_WORKDIR="${BENCH_KEEP_WORKDIR:-0}"

if ! [[ "$BENCH_ITERATIONS" =~ ^[0-9]+$ ]] || [ "$BENCH_ITERATIONS" -lt 1 ]; then
	echo "[benchmark-harness] BENCH_ITERATIONS must be a positive integer"
	exit 1
fi

if ! [[ "$BENCH_WARMUP" =~ ^[0-9]+$ ]]; then
	echo "[benchmark-harness] BENCH_WARMUP must be a non-negative integer"
	exit 1
fi

if [ "$BENCH_DRY_RUN" != "0" ] && [ "$BENCH_DRY_RUN" != "1" ]; then
	echo "[benchmark-harness] BENCH_DRY_RUN must be 0 or 1"
	exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
	echo "[benchmark-harness] python3 is required for high-resolution timing"
	exit 1
fi

export TZ=UTC
export LC_ALL=C
export LANG=C

WORK_DIR="$BENCH_ROOT/workdir"
PROJECT_DIR="$WORK_DIR/project"
PUBLISH_DIR="$WORK_DIR/publish"
REGISTRY_DIR="$WORK_DIR/registry"
TOKEN_FILE="$BENCH_ROOT/token.txt"
TOKEN_STORE="$BENCH_ROOT/token-store.json"
OPERATIONS_FILE="$BENCH_ROOT/operations.json"

mkdir -p "$BENCH_ROOT"

operation_count=0

append_operation_json() {
	local operation_json="$1"
	if [ "$operation_count" -gt 0 ]; then
		printf ',\n' >>"$OPERATIONS_FILE"
	fi
	printf '%b' "$operation_json" >>"$OPERATIONS_FILE"
	operation_count=$((operation_count + 1))
}

now_ns() {
	python3 -c 'import time; print(time.perf_counter_ns())'
}

run_kennel() {
	"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- "$@"
}

prepare_fixtures() {
	rm -rf "$WORK_DIR"
	mkdir -p "$PROJECT_DIR" "$PUBLISH_DIR" "$REGISTRY_DIR"
	rm -f "$TOKEN_STORE" "$TOKEN_FILE"

	cp -R "$ROOT_DIR/examples/basic-project/." "$PUBLISH_DIR/"

	run_kennel init --name benchmark-project --project-dir "$PROJECT_DIR" >/dev/null
	run_kennel add "$ROOT_DIR/examples/basic-project" --alias bench-local --project-dir "$PROJECT_DIR" >/dev/null
	run_kennel install --project-dir "$PROJECT_DIR" >/dev/null

	printf '%s\n' 'bench-token-123' >"$TOKEN_FILE"
	run_kennel login --token-file "$TOKEN_FILE" --registry hosted-registry --user alice --store-path "$TOKEN_STORE" --project-dir "$PUBLISH_DIR" >/dev/null
	run_kennel publish --registry hosted-registry --user alice --store-path "$TOKEN_STORE" --registry-dir "$REGISTRY_DIR" --project-dir "$PUBLISH_DIR" >/dev/null
}

benchmark_operation() {
	local operation_name="$1"
	shift

	local i=0
	while [ "$i" -lt "$BENCH_WARMUP" ]; do
		run_kennel "$@" >/dev/null
		i=$((i + 1))
	done

	local -a durations_ms=()
	local total_ms=0
	local min_ms=-1
	local max_ms=0

	i=0
	while [ "$i" -lt "$BENCH_ITERATIONS" ]; do
		local start_ns end_ns elapsed_ms
		start_ns="$(now_ns)"
		run_kennel "$@" >/dev/null
		end_ns="$(now_ns)"
		elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))

		durations_ms+=("$elapsed_ms")
		total_ms=$((total_ms + elapsed_ms))
		if [ "$min_ms" -lt 0 ] || [ "$elapsed_ms" -lt "$min_ms" ]; then
			min_ms="$elapsed_ms"
		fi
		if [ "$elapsed_ms" -gt "$max_ms" ]; then
			max_ms="$elapsed_ms"
		fi

		i=$((i + 1))
	done

	local avg_ms
	avg_ms=$((total_ms / BENCH_ITERATIONS))
	local durations_csv
	durations_csv="$(IFS=,; echo "${durations_ms[*]}")"

	append_operation_json "\t\t{\"name\":\"$operation_name\",\"iterations\":$BENCH_ITERATIONS,\"warmup_iterations\":$BENCH_WARMUP,\"durations_ms\":[${durations_csv}],\"avg_ms\":$avg_ms,\"min_ms\":$min_ms,\"max_ms\":$max_ms}"
}

emit_output() {
	local commit_sha generated_at
	commit_sha="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
	generated_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

	mkdir -p "$(dirname "$BENCH_OUTPUT")"
	cat >"$BENCH_OUTPUT" <<EOF
{
	"schema_version": "1.0",
	"generated_at": "$generated_at",
	"repo_root": "$ROOT_DIR",
	"commit": "$commit_sha",
	"dry_run": $BENCH_DRY_RUN,
	"settings": {
		"iterations": $BENCH_ITERATIONS,
		"warmup_iterations": $BENCH_WARMUP,
		"timezone": "${TZ}",
		"locale": "${LC_ALL}",
		"kujo_bin": "$KUJO_BIN"
	},
	"thresholds": {
		"max_regression_percent": 15,
		"notes": "Compare current avg_ms to prior baseline JSON; fail review if regression exceeds 15% without approved rationale."
	},
	"operations": [
$(cat "$OPERATIONS_FILE")
	]
}
EOF
}

: >"$OPERATIONS_FILE"

if [ "$BENCH_DRY_RUN" = "1" ]; then
	append_operation_json $'\t\t{"name":"install","iterations":0,"warmup_iterations":0,"durations_ms":[0],"avg_ms":0,"min_ms":0,"max_ms":0}'
	append_operation_json $'\t\t{"name":"update","iterations":0,"warmup_iterations":0,"durations_ms":[0],"avg_ms":0,"min_ms":0,"max_ms":0}'
	append_operation_json $'\t\t{"name":"api-search","iterations":0,"warmup_iterations":0,"durations_ms":[0],"avg_ms":0,"min_ms":0,"max_ms":0}'
	append_operation_json $'\t\t{"name":"api-metadata","iterations":0,"warmup_iterations":0,"durations_ms":[0],"avg_ms":0,"min_ms":0,"max_ms":0}'
	emit_output
	echo "[benchmark-harness] dry-run complete -> $BENCH_OUTPUT"
	exit 0
fi

prepare_fixtures

benchmark_operation "install" install --project-dir "$PROJECT_DIR"
benchmark_operation "update" update bench-local --project-dir "$PROJECT_DIR"
benchmark_operation "api-search" api-search basic --registry hosted-registry --user alice --store-path "$TOKEN_STORE" --registry-dir "$REGISTRY_DIR" --project-dir "$PUBLISH_DIR"
benchmark_operation "api-metadata" api-metadata basic-project --registry hosted-registry --user alice --store-path "$TOKEN_STORE" --registry-dir "$REGISTRY_DIR" --project-dir "$PUBLISH_DIR"

emit_output

if [ "$BENCH_KEEP_WORKDIR" != "1" ]; then
	rm -rf "$WORK_DIR"
	rm -f "$TOKEN_FILE" "$TOKEN_STORE" "$OPERATIONS_FILE"
fi

echo "[benchmark-harness] success -> $BENCH_OUTPUT"
