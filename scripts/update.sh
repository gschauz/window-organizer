#!/bin/bash
# User-facing local updates: build, reload, repair stale approval, verify real GUI access.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$(dirname "$PROJECT_DIR")"
# Once installed, update the everyday app in place instead of recreating a second copy.
if [[ -n "${WINDOW_ORGANIZER_APP_PATH:-}" ]]; then
    APP="$WINDOW_ORGANIZER_APP_PATH"
elif [[ -d "/Applications/Window Organizer.app" ]]; then
    APP="/Applications/Window Organizer.app"
else
    APP="$OUTPUT_DIR/Window Organizer.app"
fi
export WINDOW_ORGANIZER_APP_PATH="$APP"
BUILD_DIR="${WINDOW_ORGANIZER_BUILD_DIR:-$PROJECT_DIR/.build}"
mkdir -p "$BUILD_DIR"
BUILD_DIR="$(cd "$BUILD_DIR" && pwd)"
export WINDOW_ORGANIZER_BUILD_DIR="$BUILD_DIR"
export CLANG_MODULE_CACHE_PATH="$BUILD_DIR/clang-cache"
STATUS="$BUILD_DIR/update-accessibility.json"

has_access() {
    [[ -f "$STATUS" ]] || return 1
    local reported_app reported_pid granted
    reported_app=$(/usr/bin/plutil -extract appPath raw -o - "$STATUS" 2>/dev/null) || return 1
    reported_pid=$(/usr/bin/plutil -extract pid raw -o - "$STATUS" 2>/dev/null) || return 1
    granted=$(/usr/bin/plutil -extract accessibilityGranted raw -o - "$STATUS" 2>/dev/null) || return 1
    [[ "$reported_app" == "$APP" && "$granted" == "true" && "$reported_pid" =~ ^[0-9]+$ ]] || return 1
    kill -0 "$reported_pid" 2>/dev/null
}

verify_access() {
    for ((attempt=0; attempt<12; attempt++)); do
        if has_access; then
            echo "Update verified: Window Organizer has Accessibility access."
            return 0
        fi
        sleep 1
    done
    return 1
}

if [[ "${1:-}" == "--verify-only" ]]; then
    if verify_access; then exit 0; fi
    echo "Update is not verified: Window Organizer still needs Accessibility approval, or is not running." >&2
    exit 2
fi
if [[ $# -ne 0 ]]; then
    echo "Usage: update.sh [--verify-only]" >&2
    exit 64
fi

swift "$PROJECT_DIR/scripts/stop-app.swift" "$APP"
bash "$PROJECT_DIR/scripts/build.sh"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUTPUT_DIR/Window Organizer.zip"
/usr/bin/touch "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
rm -f "$STATUS"
open "$APP" --args --update-status-file "$STATUS"
# Wait for the new GUI process to publish its actual permission state.
for ((attempt=0; attempt<12; attempt++)); do
    [[ -f "$STATUS" ]] && break
    sleep 1
done
if [[ ! -f "$STATUS" ]]; then
    echo "App did not report its status; no permissions were reset." >&2
    exit 1
fi
if has_access; then
    echo "Update verified: Window Organizer has Accessibility access."
    exit 0
fi

# Repair this app only, and only after its own trust check fails.
swift "$PROJECT_DIR/scripts/stop-app.swift" "$APP"
tccutil reset Accessibility local.windoworganizer.app
rm -f "$STATUS"
open "$APP" --args --update-status-file "$STATUS" --request-update-access
if verify_access; then exit 0; fi
echo "Build installed; approval is pending in macOS Accessibility settings. Enable Window Organizer and authenticate there if prompted." >&2
echo "Then run this script with --verify-only. Exit code 2 means this update is not yet verified." >&2
exit 2
