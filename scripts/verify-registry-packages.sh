#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export KUJO_BIN="${KUJO_BIN:-kujo}"
cd "$ROOT_DIR"
"$KUJO_BIN" test-run -v tests/registry_protocol_tests.kujo
python3 -m unittest discover -s tests -p test_registry_packages.py -v
