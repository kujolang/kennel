#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
python3 -m unittest discover -s tests -p 'test_global_tools.py'
python3 tests/global_tools_e2e.py
echo '[verify-global-tools] success'
