#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${WINDOW_ORGANIZER_BUILD_DIR:-$PROJECT_DIR/.build}"
mkdir -p "$BUILD_DIR"
BUILD_DIR="$(cd "$BUILD_DIR" && pwd)"
export CLANG_MODULE_CACHE_PATH="$BUILD_DIR/clang-cache"
swift test --disable-xctest --package-path "$PROJECT_DIR" --scratch-path "$BUILD_DIR" \
  --cache-path "$BUILD_DIR/cache" --config-path "$BUILD_DIR/config" --security-path "$BUILD_DIR/security" --disable-sandbox
