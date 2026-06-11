#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-stage-3-hosted-api-workflow"
PUBLIC_DIR="$TMP_DIR/public-project"
PRIVATE_DIR="$TMP_DIR/private-project"
STORE_PATH="$TMP_DIR/token-store.json"
REGISTRY_DIR="$TMP_DIR/hosted-registry"

rm -rf "$TMP_DIR"
mkdir -p "$PUBLIC_DIR" "$PRIVATE_DIR"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name api-public --project-dir "$PUBLIC_DIR" >/dev/null 2>&1
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- login --token hosted-api-alice-token --registry hosted-registry --user alice --store-path "$STORE_PATH" --project-dir "$PUBLIC_DIR" >/dev/null
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- publish --public --registry hosted-registry --user alice --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$PUBLIC_DIR" >/dev/null

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name api-private --project-dir "$PRIVATE_DIR" >/dev/null 2>&1
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- publish --private --registry hosted-registry --user alice --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$PRIVATE_DIR" >/dev/null

search_public_output="$TMP_DIR/search-public.out"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- api-search api --registry hosted-registry --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$PUBLIC_DIR" >"$search_public_output"

grep -q 'api-public | 0.1.0 | public' "$search_public_output"
if grep -q 'api-private' "$search_public_output"; then
	echo "[verify-stage-3-hosted-api-workflow] expected private package to be hidden from unauthenticated search"
	exit 1
fi

search_owner_output="$TMP_DIR/search-owner.out"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- api-search api --registry hosted-registry --user alice --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$PUBLIC_DIR" >"$search_owner_output"

grep -q 'api-public | 0.1.0 | public' "$search_owner_output"
grep -q 'api-private | 0.1.0 | private' "$search_owner_output"

metadata_anon_output="$TMP_DIR/metadata-anon.out"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- api-metadata api-private --registry hosted-registry --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$PUBLIC_DIR" >"$metadata_anon_output" 2>&1; then
	echo "[verify-stage-3-hosted-api-workflow] expected private metadata endpoint to fail without owner auth"
	exit 1
fi

grep -q 'requires owner access' "$metadata_anon_output"

metadata_owner_output="$TMP_DIR/metadata-owner.out"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- api-metadata api-private --registry hosted-registry --user alice --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$PUBLIC_DIR" >"$metadata_owner_output"

grep -q '"name":"api-private"' "$metadata_owner_output"
grep -q '"visibility":"private"' "$metadata_owner_output"

echo "[verify-stage-3-hosted-api-workflow] success"
