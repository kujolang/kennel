#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKFLOW_FILE="${WORKFLOW_FILE:-$ROOT_DIR/.github/workflows/nightly-full-regression.yml}"
LOG_FILE="${LOG_FILE:-$ROOT_DIR/.kennel_tmp/nightly/nightly-full-profile.log}"
OUTPUT_FILE="${OUTPUT_FILE:-$ROOT_DIR/.kennel_tmp/nightly/ci-quality-report.json}"
WINDOW_SIZE="${WINDOW_SIZE:-10}"

if [ ! -f "$WORKFLOW_FILE" ]; then
	echo "[generate-ci-quality-report] missing workflow file: $WORKFLOW_FILE"
	exit 1
fi

if [ ! -f "$LOG_FILE" ]; then
	echo "[generate-ci-quality-report] missing log file: $LOG_FILE"
	exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

warning_count="$(grep -Ec 'RUFRUN001|Type checking warnings' "$LOG_FILE" || true)"
verify_success_count="$(grep -Ec '\[verify-[^]]+\] success' "$LOG_FILE" || true)"
verify_failure_count="$(grep -Ec '\[verify-[^]]+\] (failed|failure)' "$LOG_FILE" || true)"

duration_seconds="${RUN_DURATION_SECONDS:-0}"
if ! [[ "$duration_seconds" =~ ^[0-9]+$ ]]; then
	duration_seconds="0"
fi

run_conclusion="${RUN_CONCLUSION:-unknown}"
if [ "$run_conclusion" = "" ]; then
	run_conclusion="unknown"
fi

api_runs_file="$ROOT_DIR/.kennel_tmp/nightly/workflow-runs.json"
trend_source="none"

if [ -n "${GITHUB_TOKEN:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
	api_url="https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/workflows/nightly-full-regression.yml/runs?per_page=${WINDOW_SIZE}"
	if curl -fsSL \
		-H "Authorization: Bearer ${GITHUB_TOKEN}" \
		-H "Accept: application/vnd.github+json" \
		"$api_url" > "$api_runs_file"; then
		trend_source="github_api"
	fi
fi

python3 - "$OUTPUT_FILE" "$WORKFLOW_FILE" "$LOG_FILE" "$duration_seconds" "$run_conclusion" "$warning_count" "$verify_success_count" "$verify_failure_count" "$api_runs_file" "$trend_source" "$WINDOW_SIZE" <<'PY'
import json
import os
import sys
from datetime import datetime, timezone


def parse_iso8601(value):
	if not value:
		return None
	try:
		return datetime.fromisoformat(value.replace("Z", "+00:00"))
	except Exception:
		return None


def safe_int(value):
	try:
		return int(value)
	except Exception:
		return 0


output_file = sys.argv[1]
workflow_file = sys.argv[2]
log_file = sys.argv[3]
duration_seconds = safe_int(sys.argv[4])
run_conclusion = sys.argv[5]
warning_count = safe_int(sys.argv[6])
verify_success_count = safe_int(sys.argv[7])
verify_failure_count = safe_int(sys.argv[8])
api_runs_file = sys.argv[9]
trend_source = sys.argv[10]
window_size = safe_int(sys.argv[11])

trend_runs = []
if os.path.exists(api_runs_file):
	try:
		with open(api_runs_file, "r", encoding="utf-8") as handle:
			payload = json.load(handle)
		for run in payload.get("workflow_runs", []):
			started_at = parse_iso8601(run.get("run_started_at"))
			updated_at = parse_iso8601(run.get("updated_at"))
			duration = None
			if started_at and updated_at:
				duration = max(0, int((updated_at - started_at).total_seconds()))
			trend_runs.append(
				{
					"id": run.get("id"),
					"status": run.get("status", "unknown"),
					"conclusion": run.get("conclusion", "unknown"),
					"started_at": run.get("run_started_at"),
					"updated_at": run.get("updated_at"),
					"duration_seconds": duration,
				}
			)
	except Exception:
		trend_runs = []
		trend_source = "unavailable"

if window_size <= 0:
	window_size = 10

trend_runs = trend_runs[:window_size]
conclusion_counts = {}
duration_samples = []
for run in trend_runs:
	conclusion = run.get("conclusion") or "unknown"
	conclusion_counts[conclusion] = conclusion_counts.get(conclusion, 0) + 1
	duration_value = run.get("duration_seconds")
	if isinstance(duration_value, int):
		duration_samples.append(duration_value)

total_runs = sum(conclusion_counts.values())
success_runs = conclusion_counts.get("success", 0)
pass_rate_percent = 0.0
if total_runs > 0:
	pass_rate_percent = round((success_runs / total_runs) * 100.0, 2)

duration_summary = {
	"sample_size": len(duration_samples),
	"min_seconds": min(duration_samples) if duration_samples else None,
	"max_seconds": max(duration_samples) if duration_samples else None,
	"avg_seconds": round(sum(duration_samples) / len(duration_samples), 2) if duration_samples else None,
}

report = {
	"schema_version": 1,
	"generated_at_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
	"workflow": {
		"name": "nightly-full-regression",
		"workflow_file": workflow_file,
		"log_file": log_file,
	},
	"current_run": {
		"conclusion": run_conclusion,
		"duration_seconds": duration_seconds,
		"warning_counts": {
			"rufrun001_or_type_warning_lines": warning_count,
		},
		"verify_markers": {
			"success": verify_success_count,
			"failure": verify_failure_count,
		},
	},
	"trend": {
		"source": trend_source,
		"window_size": window_size,
		"conclusion_counts": conclusion_counts,
		"pass_rate_percent": pass_rate_percent,
		"duration_seconds": duration_summary,
		"recent_runs": trend_runs,
	},
	"privacy": {
		"contains_raw_logs": False,
		"contains_tokens": False,
	},
}

with open(output_file, "w", encoding="utf-8") as handle:
	json.dump(report, handle, indent=2, sort_keys=True)
	handle.write("\n")
PY

echo "[generate-ci-quality-report] wrote $OUTPUT_FILE"
