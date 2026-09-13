#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
export KUJO_MODULE_PATH="$ROOT_DIR"
KUJO_BIN="${KUJO_BIN:-kujo}"
for suite in native_global_security native_global_tools_e2e native_package_smoke native_package_release native_installer_fetch native_installer_bundle; do
  "$KUJO_BIN" run "tests/$suite.kujo" --interpreter --isolated-imports
done
echo '[verify-global-tools] success'
