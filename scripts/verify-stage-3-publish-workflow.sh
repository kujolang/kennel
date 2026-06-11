#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-stage-3-publish-workflow"
STORE_PATH="$TMP_DIR/token-store.json"
REGISTRY_DIR="$TMP_DIR/hosted-registry"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name publish-demo --project-dir "$TMP_DIR" >/dev/null 2>&1
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- login --token publish-token-123 --registry hosted-registry --user alice --store-path "$STORE_PATH" --project-dir "$TMP_DIR" >/dev/null

publish_output="$TMP_DIR/publish.out"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- publish --registry hosted-registry --user alice --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$TMP_DIR" >"$publish_output"

grep -q 'Published `publish-demo@0.1.0` to registry `hosted-registry`.' "$publish_output"
grep -q "Updated registry index: $REGISTRY_DIR/index.json" "$publish_output"
grep -q "Updated package metadata: $REGISTRY_DIR/packages/publish-demo.json" "$publish_output"

grep -q '"name":"publish-demo"' "$REGISTRY_DIR/index.json"
grep -q '"latest":"0.1.0"' "$REGISTRY_DIR/index.json"
grep -q '"metadata_path":"packages/publish-demo.json"' "$REGISTRY_DIR/index.json"

grep -q '"name":"publish-demo"' "$REGISTRY_DIR/packages/publish-demo.json"
grep -q '"latest":"0.1.0"' "$REGISTRY_DIR/packages/publish-demo.json"
grep -q '"version":"0.1.0"' "$REGISTRY_DIR/packages/publish-demo.json"

publish_duplicate_output="$TMP_DIR/publish-duplicate.out"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- publish --registry hosted-registry --user alice --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$TMP_DIR" >"$publish_duplicate_output" 2>&1; then
	echo "[verify-stage-3-publish-workflow] expected duplicate publish to fail"
	exit 1
fi

grep -q 'already contains version' "$publish_duplicate_output"

echo "[verify-stage-3-publish-workflow] success"
