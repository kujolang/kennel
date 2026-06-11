#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-macos-smoke"
PROJECT_DIR="$TMP_DIR/project"

rm -rf "$TMP_DIR"
mkdir -p "$PROJECT_DIR"

help_output="$TMP_DIR/help.out"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- help >"$help_output" 2>&1
grep -q '^Examples:' "$help_output"

echo "[verify-macos-smoke] running init/validate/list smoke flow"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name macos-smoke --project-dir "$PROJECT_DIR" >/dev/null 2>&1
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- validate --project-dir "$PROJECT_DIR" >/dev/null 2>&1
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- list --project-dir "$PROJECT_DIR" >/dev/null 2>&1

echo "[verify-macos-smoke] success"
