#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKFLOW_FILE="$ROOT_DIR/.github/workflows/nightly-full-regression.yml"
REPORT_SCRIPT="$ROOT_DIR/scripts/generate-ci-quality-report.sh"

if [ ! -f "$WORKFLOW_FILE" ]; then
	echo "[verify-ci-quality-report-workflow] missing workflow file: $WORKFLOW_FILE"
	exit 1
fi

if [ ! -f "$REPORT_SCRIPT" ]; then
	echo "[verify-ci-quality-report-workflow] missing report script: $REPORT_SCRIPT"
	exit 1
fi

required_workflow_patterns=(
	"Run nightly full regression profile"
	"nightly-full-profile.log"
	"Generate CI quality report"
	"scripts/generate-ci-quality-report.sh"
	'GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}'
	'GITHUB_REPOSITORY: ${{ github.repository }}'
	"RUN_DURATION_SECONDS"
	"RUN_CONCLUSION"
	"Upload nightly CI quality report"
	"nightly-ci-quality-report"
	".kennel_tmp/nightly/ci-quality-report.json"
	"actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02"
)

for pattern in "${required_workflow_patterns[@]}"; do
	if ! grep -Fq -- "$pattern" "$WORKFLOW_FILE"; then
		echo "[verify-ci-quality-report-workflow] missing workflow requirement: $pattern"
		exit 1
	fi
done

required_report_tokens=(
	"schema_version"
	"warning_counts"
	"conclusion_counts"
	"duration_seconds"
	"pass_rate_percent"
	"contains_tokens"
)

for token in "${required_report_tokens[@]}"; do
	if ! grep -Fq -- "$token" "$REPORT_SCRIPT"; then
		echo "[verify-ci-quality-report-workflow] report script missing expected token: $token"
		exit 1
	fi
done

echo "[verify-ci-quality-report-workflow] success"
