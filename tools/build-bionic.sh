#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build-bionic"
STAGE_DIR="${ROOT_DIR}/dist/.stage-bionic"
DIST_DIR="${ROOT_DIR}/dist"

DEFAULT_PACKAGE_NAME="lsfg-vk-2.0.0-dev24-linux-aarch64-bionic"
PACKAGE_NAME="${LSFGVK_PACKAGE_NAME:-$DEFAULT_PACKAGE_NAME}"

NDK_ROOT="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"
if [[ -z "${NDK_ROOT}" ]]; then
  echo "ERROR: set ANDROID_NDK_HOME (or ANDROID_NDK_ROOT) to your Android NDK path" >&2
  exit 1
fi

TOOLCHAIN_FILE="${NDK_ROOT}/build/cmake/android.toolchain.cmake"
if [[ ! -f "${TOOLCHAIN_FILE}" ]]; then
  echo "ERROR: Android NDK toolchain file not found: ${TOOLCHAIN_FILE}" >&2
  exit 1
fi

ANDROID_API="${LSFGVK_ANDROID_API:-28}"

VULKAN_INCLUDE_DIR="${LSFGVK_VULKAN_INCLUDE_DIR:-}"
if [[ -z "${VULKAN_INCLUDE_DIR}" && -n "${VULKAN_SDK:-}" ]]; then
  VULKAN_INCLUDE_DIR="${VULKAN_SDK}/Include"
fi

if [[ -z "${VULKAN_INCLUDE_DIR}" ]]; then
  if [[ -d "/c/VulkanSDK" ]]; then
    latest_vk="$(ls -1 /c/VulkanSDK 2>/dev/null | sort -V | tail -n 1 || true)"
    if [[ -n "${latest_vk}" && -d "/c/VulkanSDK/${latest_vk}/Include" ]]; then
      VULKAN_INCLUDE_DIR="/c/VulkanSDK/${latest_vk}/Include"
    fi
  elif [[ -d "/mnt/c/VulkanSDK" ]]; then
    latest_vk="$(ls -1 /mnt/c/VulkanSDK 2>/dev/null | sort -V | tail -n 1 || true)"
    if [[ -n "${latest_vk}" && -d "/mnt/c/VulkanSDK/${latest_vk}/Include" ]]; then
      VULKAN_INCLUDE_DIR="/mnt/c/VulkanSDK/${latest_vk}/Include"
    fi
  fi
fi

PACKAGE_DIR="${DIST_DIR}/${PACKAGE_NAME}"
PACKAGE_TAR_XZ="${DIST_DIR}/${PACKAGE_NAME}.tar.xz"
ABI_LOG="${DIST_DIR}/abi-check-${PACKAGE_NAME}.txt"
LAYER_SO="${PACKAGE_DIR}/lib/liblsfg-vk-layer.so.1.0.0"

echo "[1/7] clean"
rm -rf "${BUILD_DIR}" "${STAGE_DIR}" "${PACKAGE_DIR}"
mkdir -p "${BUILD_DIR}" "${STAGE_DIR}" "${PACKAGE_DIR}" "${DIST_DIR}"

echo "[2/7] configure (android bionic)"
cmake_args=(
  -S "${ROOT_DIR}" -B "${BUILD_DIR}" -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}"
  -DANDROID_ABI=arm64-v8a
  -DANDROID_PLATFORM="android-${ANDROID_API}"
  -DANDROID_STL=c++_static
  -DCMAKE_INSTALL_PREFIX=/usr/local
  -DLSFGVK_BUILD_UI=OFF
  -DLSFGVK_BUILD_CLI=OFF
  -DLSFGVK_PORTABLE_ABI=OFF
  -DLSFGVK_STATIC_LIBSTDCXX=OFF
)

if [[ -n "${VULKAN_INCLUDE_DIR}" ]]; then
  cmake_args+=( -DLSFGVK_VULKAN_INCLUDE_DIR="${VULKAN_INCLUDE_DIR}" )
  echo "Using Vulkan include dir: ${VULKAN_INCLUDE_DIR}"
fi

cmake "${cmake_args[@]}"

echo "[3/7] build"
cmake --build "${BUILD_DIR}" -j"$(nproc)"

echo "[4/7] install to staging"
DESTDIR="${STAGE_DIR}" cmake --install "${BUILD_DIR}"

echo "[5/7] compose package layout"
mkdir -p "${PACKAGE_DIR}/bin" "${PACKAGE_DIR}/lib" "${PACKAGE_DIR}/share"
cp -a "${STAGE_DIR}/usr/local/bin/." "${PACKAGE_DIR}/bin/" 2>/dev/null || true
cp -a "${STAGE_DIR}/usr/local/lib/." "${PACKAGE_DIR}/lib/" 2>/dev/null || true
cp -a "${STAGE_DIR}/usr/local/share/." "${PACKAGE_DIR}/share/" 2>/dev/null || true

if [[ ! -f "${LAYER_SO}" ]]; then
  echo "ERROR: expected layer library missing: ${LAYER_SO}" >&2
  exit 1
fi

if [[ ! -f "${PACKAGE_DIR}/share/vulkan/implicit_layer.d/VkLayer_LSFGVK_frame_generation.json" ]]; then
  echo "ERROR: expected layer manifest missing in package output" >&2
  exit 1
fi

for alias in liblsfg-vk-layer.so liblsfg-vk-layer.so.1; do
  if [[ ! -f "${PACKAGE_DIR}/lib/${alias}" ]]; then
    cp -f "${LAYER_SO}" "${PACKAGE_DIR}/lib/${alias}"
  fi
done

echo "[6/7] ABI check (must be bionic, no glibc symbols)"
llvm-readobj --version-info "${LAYER_SO}" \
  | tee "${ABI_LOG}" \
  | grep -E "GLIBC_|GLIBCXX_|CXXABI_|LIBC\.so|ANDROID|__isoc23_strtoul" || true

if grep -Eq "GLIBC_|GLIBCXX_|CXXABI_|__isoc23_strtoul" "${ABI_LOG}"; then
  echo "ERROR: detected glibc/libstdc++ symbol versions in bionic build. See ${ABI_LOG}" >&2
  exit 2
fi

echo "[7/7] archive"
rm -f "${PACKAGE_TAR_XZ}"
tar -C "${DIST_DIR}" -cJf "${PACKAGE_TAR_XZ}" "${PACKAGE_NAME}"

echo
echo "DONE"
echo "Package directory: ${PACKAGE_DIR}"
echo "Archive: ${PACKAGE_TAR_XZ}"
echo "ABI report: ${ABI_LOG}"
