#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-security-regression-suite"
PROJECT_DIR="$TMP_DIR/project"
REGISTRY_DIR="$TMP_DIR/registry"
TOKEN_STORE="$TMP_DIR/tokens.json"

rm -rf "$TMP_DIR"
mkdir -p "$PROJECT_DIR" "$REGISTRY_DIR"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name security-suite --project-dir "$PROJECT_DIR" >/dev/null
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- login --token security-suite-token --registry hosted --user alice --store-path "$TOKEN_STORE" --project-dir "$PROJECT_DIR" >/dev/null

cat >"$REGISTRY_DIR/index.json" <<'EOF'
{
  "packages": [
    {
      "name": "traversal-pkg",
      "latest": "1.0.0",
      "metadata_path": "../outside.json",
      "visibility": "public",
      "owners": ["alice"],
      "teams": [],
      "versions": [
        {
          "version": "1.0.0",
          "source": "github:robertdevore/pypractice",
          "ref": "main",
          "checksum": "sha256:traversal"
        }
      ]
    },
    {
      "name": "absolute-pkg",
      "latest": "1.0.0",
      "metadata_path": "/tmp/absolute-metadata.json",
      "visibility": "public",
      "owners": ["alice"],
      "teams": [],
      "versions": [
        {
          "version": "1.0.0",
          "source": "github:robertdevore/pypractice",
          "ref": "main",
          "checksum": "sha256:absolute"
        }
      ]
    }
  ]
}
EOF

traversal_read_out="$TMP_DIR/traversal-read.out"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- api-metadata traversal-pkg --registry hosted --user alice --store-path "$TOKEN_STORE" --registry-dir "$REGISTRY_DIR" --project-dir "$PROJECT_DIR" >"$traversal_read_out" 2>&1; then
	echo "[verify-security-regression-suite] expected traversal metadata path read to fail"
	exit 1
fi
if ! grep -Eiq 'metadata_path|unsafe metadata_path|invalid unsafe metadata_path|metadata path' "$traversal_read_out"; then
	echo "[verify-security-regression-suite] traversal metadata-path diagnostic missing"
	exit 1
fi

absolute_read_out="$TMP_DIR/absolute-read.out"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- api-metadata absolute-pkg --registry hosted --user alice --store-path "$TOKEN_STORE" --registry-dir "$REGISTRY_DIR" --project-dir "$PROJECT_DIR" >"$absolute_read_out" 2>&1; then
	echo "[verify-security-regression-suite] expected absolute metadata path read to fail"
	exit 1
fi
if ! grep -Eiq 'metadata_path|unsafe metadata_path|invalid unsafe metadata_path|metadata path' "$absolute_read_out"; then
	echo "[verify-security-regression-suite] absolute metadata-path diagnostic missing"
	exit 1
fi

traversal_write_out="$TMP_DIR/traversal-write.out"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- yank 1.0.0 --package traversal-pkg --registry hosted --user alice --store-path "$TOKEN_STORE" --registry-dir "$REGISTRY_DIR" --project-dir "$PROJECT_DIR" >"$traversal_write_out" 2>&1; then
	echo "[verify-security-regression-suite] expected traversal metadata path write flow to fail"
	exit 1
fi
if ! grep -Eiq 'metadata_path|unsafe metadata_path|invalid unsafe metadata_path|metadata path' "$traversal_write_out"; then
	echo "[verify-security-regression-suite] traversal write metadata-path diagnostic missing"
	exit 1
fi

missing_token_out="$TMP_DIR/missing-token-store.out"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- install-hosted traversal-pkg --registry hosted --user alice --store-path "$TMP_DIR/does-not-exist-token-store.json" --registry-dir "$REGISTRY_DIR" --project-dir "$PROJECT_DIR" >"$missing_token_out" 2>&1; then
	echo "[verify-security-regression-suite] expected install-hosted to fail for missing token store"
	exit 1
fi
if ! grep -Eiq 'token|login|auth' "$missing_token_out"; then
	echo "[verify-security-regression-suite] token-store misuse diagnostic missing"
	exit 1
fi

echo "[verify-security-regression-suite] success"
