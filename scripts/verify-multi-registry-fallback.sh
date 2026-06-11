#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-multi-registry-fallback"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR/registry"

PRIMARY_INDEX="$TMP_DIR/registry/index.primary.json"
SECONDARY_INDEX="$TMP_DIR/registry/index.secondary.json"
SECONDARY_METADATA="$TMP_DIR/registry/mirror-demo.metadata.json"

cat >"$PRIMARY_INDEX" <<EOF
{
	"packages": [
		{
			"name": "primary-only",
			"latest": "0.1.0",
			"metadata_path": "primary-only.metadata.json",
			"versions": [
				{
					"version": "0.1.0",
					"source": "github:pallets/itsdangerous",
					"ref": "2.1.0"
				}
			]
		}
	]
}
EOF

cat >"$SECONDARY_INDEX" <<EOF
{
	"packages": [
		{
			"name": "mirror-demo",
			"latest": "0.1.0",
			"metadata_path": "mirror-demo.metadata.json",
			"versions": [
				{
					"version": "0.1.0",
					"source": "github:pallets/itsdangerous",
					"ref": "2.2.0"
				}
			]
		}
	]
}
EOF

cat >"$SECONDARY_METADATA" <<EOF
{
	"name": "mirror-demo",
	"latest": "0.1.0",
	"visibility": "public",
	"owners": ["mirror-owner"],
	"versions": [
		{
			"version": "0.1.0",
			"source": "github:pallets/itsdangerous",
			"ref": "2.2.0"
		}
	]
}
EOF

PROJECT_DIR="$TMP_DIR/project"
mkdir -p "$PROJECT_DIR"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name fallback-check --project-dir "$PROJECT_DIR" >/dev/null

python3 - "$PROJECT_DIR/kennel.toml" "$PRIMARY_INDEX" "$SECONDARY_INDEX" <<'PY'
from pathlib import Path
import sys

manifest_path = Path(sys.argv[1])
primary_index = Path(sys.argv[2]).resolve()
secondary_index = Path(sys.argv[3]).resolve()

raw = manifest_path.read_text(encoding="utf-8")
updated = raw.replace('index = ""', f'index = "{primary_index}"', 1)
updated = updated.replace('mirrors = []', f'mirrors = ["{secondary_index}"]', 1)
if updated == raw:
	raise SystemExit("failed to configure registry index/mirror paths")
manifest_path.write_text(updated, encoding="utf-8")
PY

add_log="$PROJECT_DIR/add.log"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add mirror-demo --project-dir "$PROJECT_DIR" >"$add_log" 2>&1

grep -q "Resolved \`mirror-demo\` via static index: $SECONDARY_INDEX" "$add_log"
grep -q 'name = "mirror-demo"' "$PROJECT_DIR/kennel.lock"

search_log="$PROJECT_DIR/search.log"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- search mirror --project-dir "$PROJECT_DIR" >"$search_log" 2>&1
grep -q 'mirror-demo | 0.1.0 | mirror-demo.metadata.json | '"$SECONDARY_INDEX" "$search_log"

info_log="$PROJECT_DIR/info.log"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- info mirror-demo --project-dir "$PROJECT_DIR" >"$info_log" 2>&1
grep -q '"name":"mirror-demo"' "$info_log"

echo "[verify-multi-registry-fallback] success"