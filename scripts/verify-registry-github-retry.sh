#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
export KUJO_MODULE_PATH="$ROOT_DIR"
"${KUJO_BIN:-kujo}" run tests/registry_github_retry.kujo --interpreter --isolated-imports
