#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-stage-3-trust-signature-workflow"
SIGNED_PACKAGE_DIR="$TMP_DIR/signed-lib"
CONSUMER_DIR="$TMP_DIR/consumer"
INDEX_PATH="$TMP_DIR/index.json"
PACKAGES_DIR="$TMP_DIR/packages"

rm -rf "$TMP_DIR"
mkdir -p "$SIGNED_PACKAGE_DIR" "$CONSUMER_DIR" "$PACKAGES_DIR"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name signed-lib --project-dir "$SIGNED_PACKAGE_DIR" >/dev/null 2>&1

cat > "$INDEX_PATH" <<EOF
{
  "schema_version": 1,
  "generated_at": "2026-05-20T00:00:00Z",
  "packages": [
    {
      "name": "signed-lib",
      "latest": "0.1.0",
      "metadata_path": "packages/signed-lib.json",
      "versions": [
        {
          "version": "0.1.0",
          "source": "file:$SIGNED_PACKAGE_DIR",
          "ref": "0.1.0",
          "checksum": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
          "signature": "c2lnbmVkLWxpYi0wMTA=",
          "signing_key": "key.signed-lib-010"
        }
      ]
    }
  ]
}
EOF

cat > "$PACKAGES_DIR/signed-lib.json" <<EOF
{
  "name": "signed-lib",
  "latest": "0.1.0",
  "visibility": "public",
  "versions": [
    {
      "version": "0.1.0",
      "source": "file:$SIGNED_PACKAGE_DIR",
      "ref": "0.1.0",
      "checksum": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
      "signature": "c2lnbmVkLWxpYi0wMTA=",
      "signing_key": "key.signed-lib-010"
    }
  ]
}
EOF

cat > "$CONSUMER_DIR/kennel.toml" <<EOF
[package]
name = "consumer"
version = "0.1.0"

[dependencies]

[registry]
index = "$INDEX_PATH"

[trust]
checksum = "sha256:1111111111111111111111111111111111111111111111111111111111111111"
signature = "c2lnbmVkLWxpYi0wMTA="
signing_key = "key.signed-lib-010"
EOF

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add signed-lib --project-dir "$CONSUMER_DIR" >/dev/null

grep -q 'checksum = "sha256:1111111111111111111111111111111111111111111111111111111111111111"' "$CONSUMER_DIR/kennel.lock"
grep -q 'signature = "c2lnbmVkLWxpYi0wMTA="' "$CONSUMER_DIR/kennel.lock"
grep -q 'signing_key = "key.signed-lib-010"' "$CONSUMER_DIR/kennel.lock"

tmp_manifest="$TMP_DIR/kennel.toml.next"
sed 's/signature = "c2lnbmVkLWxpYi0wMTA="/signature = "c2lnLW1pc21hdGNo"/' "$CONSUMER_DIR/kennel.toml" >"$tmp_manifest"
mv "$tmp_manifest" "$CONSUMER_DIR/kennel.toml"

mismatch_output="$TMP_DIR/install-mismatch.out"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- install --project-dir "$CONSUMER_DIR" >"$mismatch_output" 2>&1; then
	echo "[verify-stage-3-trust-signature-workflow] expected install to fail when trust signature does not match"
	exit 1
fi

grep -q 'signature does not match trust policy' "$mismatch_output"

echo "[verify-stage-3-trust-signature-workflow] success"
