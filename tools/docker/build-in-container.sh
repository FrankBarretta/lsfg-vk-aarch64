#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-/work}"
BUILD_DIR="${BUILD_DIR:-${ROOT_DIR}/build-docker-portable}"
STAGE_DIR="${STAGE_DIR:-${ROOT_DIR}/dist/.stage}"
DIST_DIR="${DIST_DIR:-${ROOT_DIR}/dist}"
PACKAGE_NAME="${PACKAGE_NAME:-lsfg-vk-2.0.0-dev24-linux-aarch64}"
TOOLCHAIN_FILE="${TOOLCHAIN_FILE:-${ROOT_DIR}/tools/docker/toolchain-aarch64-linux-gnu.cmake}"

PACKAGE_DIR="${DIST_DIR}/${PACKAGE_NAME}"
PACKAGE_TAR_XZ="${DIST_DIR}/${PACKAGE_NAME}.tar.xz"

echo "[1/7] Clean directories"
rm -rf "${BUILD_DIR}" "${STAGE_DIR}" "${PACKAGE_DIR}"
mkdir -p "${BUILD_DIR}" "${STAGE_DIR}" "${PACKAGE_DIR}"

echo "[2/7] Configure"
cmake -S "${ROOT_DIR}" -B "${BUILD_DIR}" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DLSFGVK_BUILD_UI=OFF \
  -DLSFGVK_BUILD_CLI=ON \
  -DLSFGVK_PORTABLE_ABI=ON \
  -DLSFGVK_STATIC_LIBSTDCXX=ON

echo "[3/7] Build"
cmake --build "${BUILD_DIR}" -j"$(nproc)"

echo "[4/7] Install to staging"
DESTDIR="${STAGE_DIR}" cmake --install "${BUILD_DIR}"

echo "[5/7] Compose release layout"
mkdir -p "${PACKAGE_DIR}/bin" "${PACKAGE_DIR}/lib" "${PACKAGE_DIR}/share"
cp -a "${STAGE_DIR}/usr/local/bin/." "${PACKAGE_DIR}/bin/" 2>/dev/null || true
cp -a "${STAGE_DIR}/usr/local/lib/." "${PACKAGE_DIR}/lib/" 2>/dev/null || true
cp -a "${STAGE_DIR}/usr/local/share/." "${PACKAGE_DIR}/share/" 2>/dev/null || true

if [[ ! -f "${PACKAGE_DIR}/lib/liblsfg-vk-layer.so.1.0.0" ]]; then
  echo "ERROR: expected layer library missing in package output" >&2
  exit 1
fi
if [[ ! -f "${PACKAGE_DIR}/share/vulkan/implicit_layer.d/VkLayer_LSFGVK_frame_generation.json" ]]; then
  echo "ERROR: expected layer manifest missing in package output" >&2
  exit 1
fi

echo "[5.1/7] Architecture check"
if ! file "${PACKAGE_DIR}/lib/liblsfg-vk-layer.so.1.0.0" | grep -q "ARM aarch64"; then
  echo "ERROR: built layer is not aarch64" >&2
  file "${PACKAGE_DIR}/lib/liblsfg-vk-layer.so.1.0.0" || true
  exit 1
fi

echo "[6/7] ABI guard"
ABI_LOG="${DIST_DIR}/abi-check-${PACKAGE_NAME}.txt"
llvm-readobj --version-info "${PACKAGE_DIR}/lib/liblsfg-vk-layer.so.1.0.0" \
  | tee "${ABI_LOG}" \
  | grep -E "GLIBC_|GLIBCXX_|CXXABI_|__isoc23_strtoul" || true

if grep -Eq "GLIBC_2\\.(3[5-9]|[4-9][0-9])|GLIBCXX_3\\.4\\.(3[1-9]|[4-9][0-9])|__isoc23_strtoul" "${ABI_LOG}"; then
  echo "ERROR: ABI too new for target runtime. See ${ABI_LOG}" >&2
  exit 2
fi

echo "[7/7] Archive"
rm -f "${PACKAGE_TAR_XZ}"
tar -C "${DIST_DIR}" -cJf "${PACKAGE_TAR_XZ}" "${PACKAGE_NAME}"

echo
echo "DONE"
echo "Package directory: ${PACKAGE_DIR}"
echo "Archive: ${PACKAGE_TAR_XZ}"
echo "ABI report: ${ABI_LOG}"
