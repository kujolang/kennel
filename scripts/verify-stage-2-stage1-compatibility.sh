#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "[verify-stage-2-stage1-compatibility] verify-stage-1"
bash "$ROOT_DIR/scripts/verify-stage-1.sh"

echo "[verify-stage-2-stage1-compatibility] verify-stage-1-source-matrix"
bash "$ROOT_DIR/scripts/verify-stage-1-source-matrix.sh"

echo "[verify-stage-2-stage1-compatibility] success"