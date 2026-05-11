#!/usr/bin/env bash
# Builds TufteNotes.app from the SwiftPM target. Requires the Swift
# toolchain (Command Line Tools or full Xcode) — does NOT require opening
# the Xcode GUI.
#
# Usage:
#   ./build-app.sh                 # release build
#   ./build-app.sh --debug         # debug build
#   ./build-app.sh --run           # build then launch the .app
#   ./build-app.sh --debug --run

set -euo pipefail

APP_NAME="TufteNotes"
BUNDLE_ID="com.tuftenotes.app"
CONFIG="release"
RUN_AFTER=0

for arg in "$@"; do
    case "$arg" in
        --debug) CONFIG="debug" ;;
        --release) CONFIG="release" ;;
        --run) RUN_AFTER=1 ;;
        *) echo "Unknown flag: $arg" >&2; exit 1 ;;
    esac
done

if [[ "$(uname)" != "Darwin" ]]; then
    echo "This app uses AppKit/SwiftUI and can only be built on macOS." >&2
    exit 1
fi

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"

BUILD_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
BIN="$BUILD_DIR/$APP_NAME"
RES_BUNDLE="$BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle"

if [[ ! -x "$BIN" ]]; then
    echo "Binary not found at $BIN" >&2
    exit 1
fi

APP_DIR="$APP_NAME.app"
echo "==> Assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN" "$APP_DIR/Contents/MacOS/$APP_NAME"

if [[ -d "$RES_BUNDLE" ]]; then
    cp -R "$RES_BUNDLE" "$APP_DIR/Contents/Resources/"
else
    echo "warning: resource bundle not found at $RES_BUNDLE — sidebar/editor assets may be missing" >&2
fi

VERSION="0.1.0"
BUILD_NUM="1"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>Tufte Notes</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUM</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
</dict>
</plist>
PLIST

# Ad-hoc sign so Gatekeeper doesn't outright refuse the binary on launch.
# This won't satisfy notarization — for sharing, you'd sign with a real
# Developer ID and run `xcrun notarytool`.
if command -v codesign >/dev/null 2>&1; then
    echo "==> ad-hoc codesign"
    codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

echo "==> Done: $(pwd)/$APP_DIR"

if [[ "$RUN_AFTER" -eq 1 ]]; then
    echo "==> Launching"
    open "$APP_DIR"
fi
