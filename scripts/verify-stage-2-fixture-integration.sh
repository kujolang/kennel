#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INDEX_FILE="$ROOT_DIR/docs/contracts/index.example.json"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-stage-2-fixture-integration"
LOCAL_INDEX_FILE="$TMP_DIR/index.local.json"
LOCAL_PKGS_DIR="$TMP_DIR/local-packages"
LOCAL_METADATA_DIR="$TMP_DIR/packages"

if [ ! -f "$INDEX_FILE" ]; then
	echo "[verify-stage-2-fixture-integration] missing index fixture: $INDEX_FILE"
	exit 1
fi

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
mkdir -p "$LOCAL_PKGS_DIR/ai-sdk"
mkdir -p "$LOCAL_PKGS_DIR/mcp"
mkdir -p "$LOCAL_METADATA_DIR"

cat >"$LOCAL_PKGS_DIR/ai-sdk/kennel.toml" <<'EOF'
[package]
name = "ai-sdk"
version = "0.1.0"
description = "Local Stage 2 fixture package"

[dependencies]
EOF

cat >"$LOCAL_PKGS_DIR/mcp/kennel.toml" <<'EOF'
[package]
name = "mcp"
version = "0.1.0"
description = "Local Stage 2 fixture package"

[dependencies]
EOF

python3 - "$LOCAL_INDEX_FILE" "$LOCAL_PKGS_DIR/ai-sdk" "$LOCAL_PKGS_DIR/mcp" <<'PY'
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
            "versions": [
                {
                    "version": "v0.1.0",
                    "source": f"file:{ai_pkg}",
                    "ref": "local"
                }
            ]
        },
        {
            "name": "mcp",
            "latest": "v0.1.0",
            "metadata_path": "packages/mcp.json",
            "versions": [
                {
                    "version": "v0.1.0",
                    "source": f"file:{mcp_pkg}",
                    "ref": "local"
                }
            ]
        }
    ]
}

with open(index_file, "w", encoding="utf-8") as f:
    json.dump(index_doc, f, indent=2)

metadata_docs = {
    "ai-sdk.json": {
        "name": "ai-sdk",
        "latest": "v0.1.0",
        "repository": "https://github.com/kujolang/ai-sdk",
        "description": "Local metadata fixture for ai-sdk",
        "versions": [
            {
                "version": "v0.1.0",
                "source": f"file:{ai_pkg}",
                "ref": "local"
            }
        ]
    },
    "mcp.json": {
        "name": "mcp",
        "latest": "v0.1.0",
        "repository": "https://github.com/kujolang/mcp",
        "description": "Local metadata fixture for mcp",
        "versions": [
            {
                "version": "v0.1.0",
                "source": f"file:{mcp_pkg}",
                "ref": "local"
            }
        ]
    }
}

metadata_dir = os.path.join(os.path.dirname(index_file), "packages")
os.makedirs(metadata_dir, exist_ok=True)
for filename, doc in metadata_docs.items():
    out_path = os.path.join(metadata_dir, filename)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2)
PY

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name stage2-fixture --project-dir "$TMP_DIR" >/dev/null 2>&1

python3 - "$TMP_DIR/kennel.toml" "$LOCAL_INDEX_FILE" <<'PY'
import os
import sys

manifest_path = sys.argv[1]
index_file = os.path.abspath(sys.argv[2])

with open(manifest_path, "r", encoding="utf-8") as f:
    raw = f.read()

updated = raw.replace('index = ""', f'index = "{index_file}"', 1)
if updated == raw:
    raise SystemExit("failed to configure [registry].index in kennel.toml fixture")

with open(manifest_path, "w", encoding="utf-8") as f:
    f.write(updated)
PY

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add ai-sdk --project-dir "$TMP_DIR" >/dev/null
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add mcp --project-dir "$TMP_DIR" >/dev/null

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- search ai --project-dir "$TMP_DIR" >"$TMP_DIR/search-ai.out"
grep -q 'ai-sdk | v0.1.0 | packages/ai-sdk.json' "$TMP_DIR/search-ai.out"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- search m --project-dir "$TMP_DIR" >"$TMP_DIR/search-m.out"
grep -q 'mcp | v0.1.0 | packages/mcp.json' "$TMP_DIR/search-m.out"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- info ai-sdk --project-dir "$TMP_DIR" >"$TMP_DIR/info-ai-sdk.out"
grep -q '"name":"ai-sdk"' "$TMP_DIR/info-ai-sdk.out"
grep -q '"latest":"v0.1.0"' "$TMP_DIR/info-ai-sdk.out"

if [ ! -d "$TMP_DIR/kennel_packages/ai-sdk" ]; then
    echo "[verify-stage-2-fixture-integration] expected name-based add install for ai-sdk"
    exit 1
fi

if [ ! -d "$TMP_DIR/kennel_packages/mcp" ]; then
    echo "[verify-stage-2-fixture-integration] expected name-based add install for mcp"
    exit 1
fi

grep -q 'name = "ai-sdk"' "$TMP_DIR/kennel.lock"
grep -q 'source = "file:' "$TMP_DIR/kennel.lock"
grep -q 'name = "mcp"' "$TMP_DIR/kennel.lock"

python3 - "$ROOT_DIR" "$INDEX_FILE" <<'PY'
import json
import os
import sys

root_dir = sys.argv[1]
index_file = sys.argv[2]

with open(index_file, "r", encoding="utf-8") as f:
    index_doc = json.load(f)

packages = index_doc.get("packages", [])
if not packages:
    raise SystemExit("index fixture has no packages")

by_name = {entry["name"]: entry for entry in packages}


def resolve_add(name, version=None):
    if name not in by_name:
        raise SystemExit(f"missing package in fixture index: {name}")
    package = by_name[name]
    target_version = version or package.get("latest", "")
    if not target_version:
        raise SystemExit(f"package `{name}` has no latest version")
    for entry in package.get("versions", []):
        if entry.get("version") == target_version:
            return {
                "name": name,
                "version": target_version,
                "source": entry.get("source", ""),
                "ref": entry.get("ref", ""),
                "checksum": entry.get("checksum", ""),
                "metadata_path": package.get("metadata_path", "")
            }
    raise SystemExit(f"version `{target_version}` not found for `{name}`")


def search_packages(query: str):
    lowered = query.lower()
    return [name for name in by_name if lowered in name.lower()]


# add-by-name behavior against fixture index
ai_latest = resolve_add("ai-sdk")
if ai_latest["version"] != "v0.3.0" or ai_latest["source"] != "github:kujolang/ai-sdk":
    raise SystemExit("add latest resolution failed for ai-sdk")

mcp_explicit = resolve_add("mcp", "v0.1.0")
if mcp_explicit["ref"] != "v0.1.0":
    raise SystemExit("add explicit version resolution failed for mcp")

# search behavior against fixture index
if "ai-sdk" not in search_packages("ai"):
    raise SystemExit("search fixture check failed for query `ai`")
if "mcp" not in search_packages("m"):
    raise SystemExit("search fixture check failed for query `m`")

# info behavior against fixture metadata files
for package_name in ["ai-sdk", "mcp"]:
    resolved = resolve_add(package_name)
    metadata_file = os.path.join(root_dir, "docs", "contracts", resolved["metadata_path"])
    if not os.path.isfile(metadata_file):
        raise SystemExit(f"metadata fixture missing for package `{package_name}`")
    with open(metadata_file, "r", encoding="utf-8") as f:
        metadata = json.load(f)
    if metadata.get("name") != package_name:
        raise SystemExit(f"metadata name mismatch for package `{package_name}`")

print("[verify-stage-2-fixture-integration] success")
PY
