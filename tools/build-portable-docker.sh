#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

IMAGE_NAME="${LSFGVK_IMAGE_NAME:-lsfgvk-portable-builder:ubuntu22-amd64-cross-aarch64}"
DOCKERFILE="${ROOT_DIR}/tools/docker/Dockerfile.portable-ubuntu22"
TARGET_PLATFORM="${LSFGVK_DOCKER_PLATFORM:-linux/amd64}"
PACKAGE_NAME="${LSFGVK_PACKAGE_NAME:-lsfg-vk-2.0.0-dev24-linux-aarch64}"

echo "[1/3] Build Docker image (${TARGET_PLATFORM})"
docker build \
  --platform "${TARGET_PLATFORM}" \
  -f "${DOCKERFILE}" \
  -t "${IMAGE_NAME}" \
  "${ROOT_DIR}"

echo "[2/3] Run portable build in container"
docker run --rm \
  --platform "${TARGET_PLATFORM}" \
  -e ROOT_DIR=/work \
  -e PACKAGE_NAME="${PACKAGE_NAME}" \
  -v "${ROOT_DIR}:/work" \
  "${IMAGE_NAME}" \
  bash /work/tools/docker/build-in-container.sh

echo "[3/3] Done"
echo "Artifacts are in: ${ROOT_DIR}/dist"
