#!/usr/bin/env bash

set -euo pipefail
# set -x

# Resolve the repository directory from this script's location.
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"

INSTALL_DIR="$BUILD_DIR/dev-install"
DEPLOY_DIR="$PROJECT_DIR/contents/ui/OpenSquares/DockHub"

echo "PROJECT_DIR: "$PROJECT_DIR
echo "BUILD_DIR: "$BUILD_DIR
echo "DEPLOY_DIR: "$DEPLOY_DIR

echo "Configuring DockHub..."
cmake -S "$PROJECT_DIR" -B "$BUILD_DIR" -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"

echo
echo "Building DockHub..."
cmake --build "$BUILD_DIR"

echo
echo "Installing DockHub QML module..."
cmake --install "$BUILD_DIR"

echo "Deploying QML plugin..."
mkdir -p "$DEPLOY_DIR"
cp -a "$INSTALL_DIR/usr/lib/x86_64-linux-gnu/qt6/qml/OpenSquares/DockHub/." "$DEPLOY_DIR/"

echo
echo "DockHub build and installation completed successfully."
