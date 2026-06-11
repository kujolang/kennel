#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-stage-3-yank-workflow"
STORE_PATH="$TMP_DIR/token-store.json"
REGISTRY_DIR="$TMP_DIR/hosted-registry"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name yank-demo --project-dir "$TMP_DIR" >/dev/null 2>&1
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- login --token yank-token-123 --registry hosted-registry --user alice --store-path "$STORE_PATH" --project-dir "$TMP_DIR" >/dev/null
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- publish --registry hosted-registry --user alice --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$TMP_DIR" >/dev/null

yank_output="$TMP_DIR/yank.out"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- yank 0.1.0 --registry hosted-registry --user alice --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$TMP_DIR" >"$yank_output"

grep -q 'Yanked `yank-demo@0.1.0` in registry `hosted-registry`.' "$yank_output"
grep -q '"yanked":true' "$REGISTRY_DIR/index.json"
grep -q '"yanked":true' "$REGISTRY_DIR/packages/yank-demo.json"

unyank_output="$TMP_DIR/unyank.out"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- yank 0.1.0 --undo --registry hosted-registry --user alice --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$TMP_DIR" >"$unyank_output"

grep -q 'Unyanked `yank-demo@0.1.0` in registry `hosted-registry`.' "$unyank_output"
grep -q '"yanked":false' "$REGISTRY_DIR/index.json"
grep -q '"yanked":false' "$REGISTRY_DIR/packages/yank-demo.json"

missing_output="$TMP_DIR/yank-missing.out"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- yank 9.9.9 --registry hosted-registry --user alice --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$TMP_DIR" >"$missing_output" 2>&1; then
	echo "[verify-stage-3-yank-workflow] expected yank of missing version to fail"
	exit 1
fi

grep -q 'does not contain version' "$missing_output"

echo "[verify-stage-3-yank-workflow] success"
