#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build-portable"

echo "[1/4] Clean build directory"
rm -rf "${BUILD_DIR}"

echo "[2/4] Configure portable build"
cmake -S "${ROOT_DIR}" -B "${BUILD_DIR}" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DLSFGVK_BUILD_UI=OFF \
  -DLSFGVK_BUILD_CLI=ON \
  -DLSFGVK_PORTABLE_ABI=ON \
  -DLSFGVK_STATIC_LIBSTDCXX=ON

echo "[3/4] Build"
cmake --build "${BUILD_DIR}" -j"$(nproc)"

LAYER_SO="${BUILD_DIR}/lsfg-vk-layer/liblsfg-vk-layer.so.1.0.0"
if [[ ! -f "${LAYER_SO}" ]]; then
  echo "ERROR: layer binary not found at ${LAYER_SO}" >&2
  exit 1
fi

echo "[4/4] ABI check"
llvm-readobj --version-info "${LAYER_SO}" | grep -E "GLIBC_|GLIBCXX_|CXXABI_|__isoc23_strtoul" || true

echo
cat <<'MSG'
Build completed.

IMPORTANT:
- If you still see GLIBC_2.38 / __isoc23_strtoul / GLIBCXX_3.4.31+,
  your host toolchain is too new for the target runtime.
- Rebuild inside an older environment (recommended: Ubuntu 22.04 or Debian 12 toolchain baseline).
MSG
