#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-stage-3-server-permission-workflow"
PROJECT_DIR="$TMP_DIR/perms-lib"
REGISTRY_DIR="$TMP_DIR/hosted-registry"
ALICE_STORE="$TMP_DIR/alice-store.json"
BOB_STORE="$TMP_DIR/bob-store.json"

rm -rf "$TMP_DIR"
mkdir -p "$PROJECT_DIR"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name perms-lib --project-dir "$PROJECT_DIR" >/dev/null 2>&1

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- login --token perms-alice-token --registry hosted-registry --user alice --store-path "$ALICE_STORE" --project-dir "$PROJECT_DIR" >/dev/null
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- publish --registry hosted-registry --user alice --store-path "$ALICE_STORE" --registry-dir "$REGISTRY_DIR" --project-dir "$PROJECT_DIR" >/dev/null

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- login --token perms-bob-token --registry hosted-registry --user bob --store-path "$BOB_STORE" --project-dir "$PROJECT_DIR" >/dev/null

bob_yank_output="$TMP_DIR/bob-yank.out"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- yank 0.1.0 --package perms-lib --registry hosted-registry --user bob --store-path "$BOB_STORE" --registry-dir "$REGISTRY_DIR" --project-dir "$PROJECT_DIR" >"$bob_yank_output" 2>&1; then
	echo "[verify-stage-3-server-permission-workflow] expected bob yank to fail"
	exit 1
fi

grep -q 'Only package owners can yank versions' "$bob_yank_output"

bob_access_output="$TMP_DIR/bob-access.out"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- access owner-add perms-lib eve --registry hosted-registry --user bob --store-path "$BOB_STORE" --registry-dir "$REGISTRY_DIR" --project-dir "$PROJECT_DIR" >"$bob_access_output" 2>&1; then
	echo "[verify-stage-3-server-permission-workflow] expected bob access mutation to fail"
	exit 1
fi

grep -q 'Only package owners can manage access' "$bob_access_output"

sed -i '' 's/version = "0.1.0"/version = "0.1.1"/' "$PROJECT_DIR/kennel.toml"

bob_publish_output="$TMP_DIR/bob-publish.out"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- publish --registry hosted-registry --user bob --store-path "$BOB_STORE" --registry-dir "$REGISTRY_DIR" --project-dir "$PROJECT_DIR" >"$bob_publish_output" 2>&1; then
	echo "[verify-stage-3-server-permission-workflow] expected bob publish to fail"
	exit 1
fi

grep -q 'Only package owners can publish new versions' "$bob_publish_output"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- publish --registry hosted-registry --user alice --store-path "$ALICE_STORE" --registry-dir "$REGISTRY_DIR" --project-dir "$PROJECT_DIR" >/dev/null
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- yank 0.1.1 --package perms-lib --registry hosted-registry --user alice --store-path "$ALICE_STORE" --registry-dir "$REGISTRY_DIR" --project-dir "$PROJECT_DIR" >/dev/null

echo "[verify-stage-3-server-permission-workflow] success"
