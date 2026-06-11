#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-stage-3-login-workflow"
STORE_PATH="$TMP_DIR/token-store.json"
TOKEN_FILE="$TMP_DIR/token.txt"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name stage3-login --project-dir "$TMP_DIR" >/dev/null 2>&1

login_output="$TMP_DIR/login-direct.out"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- login --token token-direct-123 --registry hosted-registry --user alice --store-path "$STORE_PATH" --project-dir "$TMP_DIR" >"$login_output"

grep -q 'Logged in to registry `hosted-registry` as `alice`.' "$login_output"
grep -q "Auth token stored at $STORE_PATH" "$login_output"
if grep -q 'token-direct-123' "$login_output"; then
	echo "[verify-stage-3-login-workflow] token value leaked in login output"
	exit 1
fi

echo 'token-file-456' >"$TOKEN_FILE"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- login --token-file "$TOKEN_FILE" --registry hosted-registry --user bob --store-path "$STORE_PATH" --project-dir "$TMP_DIR" >/dev/null

python3 - "$STORE_PATH" <<'PY'
import json
import sys

store_path = sys.argv[1]
with open(store_path, "r", encoding="utf-8") as f:
    store = json.load(f)

tokens = store.get("tokens", {})
expected_keys = {
    "hosted-registry|alice": "token-direct-123",
    "hosted-registry|bob": "token-file-456",
}

for key, token in expected_keys.items():
    if key not in tokens:
        raise SystemExit(f"missing token entry: {key}")
    if tokens[key].get("token") != token:
        raise SystemExit(f"token mismatch for {key}")

if store.get("active_key") != "hosted-registry|bob":
    raise SystemExit("expected active_key to switch to last login entry")

print("[verify-stage-3-login-workflow] success")
PY
