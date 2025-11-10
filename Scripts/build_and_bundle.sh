#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${CONFIG:-release}"
DISABLE_SANDBOX="${DISABLE_SANDBOX:-true}"

MODULE_CACHE="$ROOT/.swift-module-cache"
CLANG_CACHE="$ROOT/.clang-module-cache"
TMP_DIR="$ROOT/.tmp"
BUILD_CACHE="$ROOT/.build/cache"
BUILD_DIR="$ROOT/.build/$CONFIG"
DIST_DIR="$ROOT/dist"
CLI_DEST="$DIST_DIR/puff"
APP_DIR="$DIST_DIR/Puff.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
HELPER_BINARY_NAME="puff-helper"
PLIST_TEMPLATE="$ROOT/Sources/PuffHelper/Resources/AppInfo.plist"

mkdir -p "$MODULE_CACHE" "$CLANG_CACHE" "$TMP_DIR" "$BUILD_CACHE"

SANDBOX_FLAG=()
if [ "$DISABLE_SANDBOX" = "true" ]; then
    SANDBOX_FLAG=(--disable-sandbox)
fi

echo "Building targets ($CONFIG)..."
SWIFT_MODULECACHE_PATH="$MODULE_CACHE" \
CLANG_MODULE_CACHE_PATH="$CLANG_CACHE" \
TMPDIR="$TMP_DIR" \
swift build \
    --configuration "$CONFIG" \
    --cache-path "$BUILD_CACHE" \
    "${SANDBOX_FLAG[@]}" \
    "$@"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR" "$MACOS_DIR" "$RESOURCES_DIR"

echo "Copying CLI..."
install -m 755 "$BUILD_DIR/puff" "$CLI_DEST"

echo "Assembling Puff.app..."
install -m 755 "$BUILD_DIR/PuffHelper" "$MACOS_DIR/$HELPER_BINARY_NAME"

if [ -d "$BUILD_DIR/puff_PuffHelper.bundle" ]; then
    cp -R "$BUILD_DIR/puff_PuffHelper.bundle" "$RESOURCES_DIR/"
fi

if [ -f "$ROOT/Sources/PuffHelper/Resources/AppIcon.icns" ]; then
    cp "$ROOT/Sources/PuffHelper/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
elif [ -f "$ROOT/Sources/PuffHelper/Resources/AppIcons.icns" ]; then
    cp "$ROOT/Sources/PuffHelper/Resources/AppIcons.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

if [ ! -f "$PLIST_TEMPLATE" ]; then
    echo "Missing Info.plist template at $PLIST_TEMPLATE" >&2
    exit 1
fi

cp "$PLIST_TEMPLATE" "$CONTENTS_DIR/Info.plist"

# Code sign the app bundle
echo "Code signing..."
codesign --force --deep --sign - "$APP_DIR" || echo "Warning: Code signing failed"

if [ -x "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" ]; then
    "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" -f "$APP_DIR" >/dev/null 2>&1 || true
fi

cat <<EOF
Artifacts staged in $DIST_DIR:
  - puff (CLI entry point; add/symlink to PATH)
  - Puff.app (helper bundle used for notifications)

First-time setup:
  1. ln -sf "$CLI_DEST" /usr/local/bin/puff   # or any PATH location
  2. open "$APP_DIR" --args "Test Assistant"  # approve notification prompt
EOF
