#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-git-diagnostics"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name git-diagnostics --project-dir "$TMP_DIR" >/dev/null 2>&1

missing_repo_output="$TMP_DIR/missing-repo.log"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add github:robertdevore/this-repo-does-not-exist-kennel@main --alias missing-repo --project-dir "$TMP_DIR" >"$missing_repo_output" 2>&1; then
	echo "[verify-git-diagnostics] expected missing repository add to fail"
	exit 1
fi

grep -q "Repository not found" "$missing_repo_output"
grep -q "Verify owner/repo and repository visibility" "$missing_repo_output"

missing_ref_output="$TMP_DIR/missing-ref.log"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add github:robertdevore/pypractice@ref-that-does-not-exist --alias missing-ref --project-dir "$TMP_DIR" >"$missing_ref_output" 2>&1; then
	echo "[verify-git-diagnostics] expected missing ref add to fail"
	exit 1
fi

grep -q "No commit found for ref \`ref-that-does-not-exist\`" "$missing_ref_output"
grep -q "Verify that the ref exists and is pushed" "$missing_ref_output"

echo "[verify-git-diagnostics] success"
