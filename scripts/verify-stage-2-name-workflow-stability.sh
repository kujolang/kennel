#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "[verify-stage-2-name-workflow-stability] run 1"
bash "$ROOT_DIR/scripts/verify-stage-2-fixture-integration.sh"

echo "[verify-stage-2-name-workflow-stability] run 2"
bash "$ROOT_DIR/scripts/verify-stage-2-fixture-integration.sh"

echo "[verify-stage-2-name-workflow-stability] success"