#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
cd "$ROOT_DIR"
"$KUJO_BIN" run tests/declaration_inspection.kujo --interpreter
