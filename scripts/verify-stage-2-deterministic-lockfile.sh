#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-stage-2-deterministic-lockfile"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR/local-packages/ai-sdk"
mkdir -p "$TMP_DIR/local-packages/mcp"

cat >"$TMP_DIR/local-packages/ai-sdk/kennel.toml" <<'EOF'
[package]
name = "ai-sdk"
version = "0.1.0"

[dependencies]
EOF

cat >"$TMP_DIR/local-packages/mcp/kennel.toml" <<'EOF'
[package]
name = "mcp"
version = "0.1.0"

[dependencies]
EOF

python3 - "$TMP_DIR/index.local.json" "$TMP_DIR/local-packages/ai-sdk" "$TMP_DIR/local-packages/mcp" <<'PY'
import json
import os
import sys

index_file = sys.argv[1]
ai_pkg = os.path.abspath(sys.argv[2])
mcp_pkg = os.path.abspath(sys.argv[3])

index_doc = {
    "schema_version": 1,
    "generated_at": "2026-05-19T00:00:00Z",
    "packages": [
        {
            "name": "ai-sdk",
            "latest": "v0.1.0",
            "metadata_path": "packages/ai-sdk.json",
            "versions": [{"version": "v0.1.0", "source": f"file:{ai_pkg}", "ref": "local"}],
        },
        {
            "name": "mcp",
            "latest": "v0.1.0",
            "metadata_path": "packages/mcp.json",
            "versions": [{"version": "v0.1.0", "source": f"file:{mcp_pkg}", "ref": "local"}],
        },
    ],
}

with open(index_file, "w", encoding="utf-8") as f:
    json.dump(index_doc, f, indent=2)
PY

prepare_project() {
	project_dir="$1"
	rm -rf "$project_dir"
	mkdir -p "$project_dir"
	"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name stage2-deterministic --project-dir "$project_dir" >/dev/null 2>&1
	python3 - "$project_dir/kennel.toml" "$TMP_DIR/index.local.json" <<'PY'
import os
import sys

manifest_path = sys.argv[1]
index_file = os.path.abspath(sys.argv[2])

with open(manifest_path, "r", encoding="utf-8") as f:
    raw = f.read()

updated = raw.replace('index = ""', f'index = "{index_file}"', 1)
if updated == raw:
    raise SystemExit("failed to configure [registry].index in kennel.toml")

with open(manifest_path, "w", encoding="utf-8") as f:
    f.write(updated)
PY
}

run_order() {
	project_dir="$1"
	first="$2"
	second="$3"
	prepare_project "$project_dir"
	"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add "$first" --project-dir "$project_dir" >/dev/null
	"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add "$second" --project-dir "$project_dir" >/dev/null
}

run_order "$TMP_DIR/order-a" ai-sdk mcp
run_order "$TMP_DIR/order-b" mcp ai-sdk

grep -v '^generated_at = ' "$TMP_DIR/order-a/kennel.lock" >"$TMP_DIR/order-a/kennel.lock.normalized"
grep -v '^generated_at = ' "$TMP_DIR/order-b/kennel.lock" >"$TMP_DIR/order-b/kennel.lock.normalized"

diff -u "$TMP_DIR/order-a/kennel.lock.normalized" "$TMP_DIR/order-b/kennel.lock.normalized" >/dev/null

echo "[verify-stage-2-deterministic-lockfile] success"