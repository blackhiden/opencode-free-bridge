#!/usr/bin/env bash
#
# build.sh - Linux/macOS Build Script
#
# This script automates the process of building and running the Docker container
# with version information dynamically injected at build time.

set -euo pipefail

if [[ "${1:-}" != "" ]]; then
  echo "Error: unknown option '${1}'."
  echo "Usage: ./docker-build.sh"
  exit 1
fi

# --- Step 1: Choose Environment ---
# --- Step 2: Execute based on choice ---
APP_VERSION="$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")"
BASE_NAME="ghcr.io/blackhiden/opencode-free-bridge"
echo -n "Enter you version: "
read -r VERSION
if [ ! -z $VERSION ]; then
  APP_VERSION=$VERSION
fi

echo "--- Building from Source and Running ---"
# Get Version Information
IMAGE_NAME="${BASE_NAME}:${APP_VERSION}"
APP_COMMIT="$(git rev-parse --short HEAD)"
BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "Building with the following info:"
echo "  Version: ${APP_VERSION}"
echo "  Commit: ${APP_COMMIT}"
echo "  Build Date: ${BUILD_DATE}"
echo "  Image Name: ${IMAGE_NAME}"
echo "----------------------------------------"

# Build and start the services with a local-only image tag

echo "Building the Docker image..."
docker build \
  -t ${IMAGE_NAME} \
  --build-arg APP_COMMIT="${APP_COMMIT}" \
  --build-arg APP_VERSION="${APP_VERSION}" \
  --build-arg BUILD_DATE="${BUILD_DATE}" .
docker tag ${IMAGE_NAME} "${BASE_NAME}:latest"
docker push ${IMAGE_NAME}
docker push "${BASE_NAME}:latest"
echo "Starting the services..."
echo "Build complete. Services are starting."
echo "Run 'docker compose logs -f' to see the logs."

