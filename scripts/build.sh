#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/Mwah.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PROJECT_HASH="$(printf "%s" "$PROJECT_DIR" | cksum | awk '{print $1}')"
SCRATCH_ROOT="${TMPDIR:-/tmp}"
SCRATCH_PATH="${MWAH_SCRATCH_PATH:-${SCRATCH_ROOT%/}/mwah-swift-build-$PROJECT_HASH}"

echo "Building Mwah..."
echo "Using Swift scratch path: $SCRATCH_PATH"

# Build with SPM in release mode
cd "$PROJECT_DIR"
swift build -c release --scratch-path "$SCRATCH_PATH" 2>&1

# Find the built binary
BINARY=$(swift build -c release --scratch-path "$SCRATCH_PATH" --show-bin-path)/Mwah

if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found at $BINARY"
    exit 1
fi

echo "Binary built at: $BINARY"

# Clean previous build
rm -rf "$APP_DIR"

# Create .app bundle structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$BINARY" "$MACOS_DIR/Mwah"

# Copy Info.plist
cp "$PROJECT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

# Copy app icon
if [ -f "$PROJECT_DIR/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
    echo "App icon copied."
fi

echo "Mwah.app created at: $APP_DIR"
echo ""
echo "To run:"
echo "  open $APP_DIR"
echo ""
echo "To run with debug mode:"
echo "  open $APP_DIR --args --debug"
echo ""
echo "To run a second instance:"
echo "  open -n $APP_DIR --args --debug"
