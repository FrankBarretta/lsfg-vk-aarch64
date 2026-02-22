#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[1/2] glibc package"
"${ROOT_DIR}/tools/build-glibc.sh"

echo "[2/2] bionic package"
"${ROOT_DIR}/tools/build-bionic.sh"

echo "All runtime variants built successfully."
