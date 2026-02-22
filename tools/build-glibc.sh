#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DEFAULT_PACKAGE_NAME="lsfg-vk-2.0.0-dev24-linux-aarch64-glibc"
PACKAGE_NAME="${LSFGVK_PACKAGE_NAME:-$DEFAULT_PACKAGE_NAME}"

echo "[glibc] building package: ${PACKAGE_NAME}"
LSFGVK_PACKAGE_NAME="${PACKAGE_NAME}" "${ROOT_DIR}/tools/build-portable-docker.sh"

echo "[glibc] done"
echo "[glibc] artifacts: ${ROOT_DIR}/dist/${PACKAGE_NAME}/"
echo "[glibc] archive:   ${ROOT_DIR}/dist/${PACKAGE_NAME}.tar.xz"
