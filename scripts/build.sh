#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$(dirname "$PROJECT_DIR")"
BUILD_DIR="${WINDOW_ORGANIZER_BUILD_DIR:-$PROJECT_DIR/.build}"
APP="${WINDOW_ORGANIZER_APP_PATH:-$OUTPUT_DIR/Window Organizer.app}"
mkdir -p "$BUILD_DIR"
BUILD_DIR="$(cd "$BUILD_DIR" && pwd)"
export CLANG_MODULE_CACHE_PATH="$BUILD_DIR/clang-cache"
BUILD_OPTIONS=(--package-path "$PROJECT_DIR" --scratch-path "$BUILD_DIR" --cache-path "$BUILD_DIR/cache" --config-path "$BUILD_DIR/config" --security-path "$BUILD_DIR/security" --disable-sandbox)
swift build -c release "${BUILD_OPTIONS[@]}"
BIN_DIR="$(swift build -c release "${BUILD_OPTIONS[@]}" --show-bin-path)"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/WindowOrganizer" "$APP/Contents/MacOS/WindowOrganizer"
ditto "$BIN_DIR/WindowOrganizer_WindowOrganizer.bundle" "$APP/Contents/Resources/WindowOrganizer_WindowOrganizer.bundle"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Window Organizer</string>
<key>CFBundleDisplayName</key><string>Window Organizer</string>
<key>CFBundleIdentifier</key><string>local.windoworganizer.app</string>
<key>CFBundleExecutable</key><string>WindowOrganizer</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSAccessibilityUsageDescription</key><string>Window Organizer reads and restores the position and size of your open windows.</string>
</dict></plist>
PLIST
swift "$PROJECT_DIR/scripts/make-icon.swift" "$BUILD_DIR/AppIcon.iconset" "$PROJECT_DIR/Sources/WindowOrganizer/Assets/MarkBlack.png"
iconutil -c icns "$BUILD_DIR/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - --identifier local.windoworganizer.app "$APP"
codesign --verify --strict "$APP"
echo "Built: $APP"
