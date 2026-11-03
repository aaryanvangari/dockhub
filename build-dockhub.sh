#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build/dev"

PACKAGE_ID="com.opensquares.dockhub"

echo
echo "Configuring Debug build..."

cmake -S "${PROJECT_DIR}" -B "${BUILD_DIR}" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_INSTALL_PREFIX=/usr

echo
echo "Building DockHub..."

cmake --build "${BUILD_DIR}" --parallel

echo
echo "Development build completed successfully."
echo
echo "To test with plasma-dev.sh:"
echo "  QML_IMPORT_PATH=\"${BUILD_DIR}/contents/ui\" plasma-dev.sh ${PACKAGE_ID} ."