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

# Optional: Accept version as first argument
VERSION="${1:-}"

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

# Stamp version into Info.plist if provided
if [ -n "$VERSION" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS_DIR/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$CONTENTS_DIR/Info.plist"
    echo "Version set to: $VERSION"
fi

# Copy app icon
if [ -f "$PROJECT_DIR/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
    echo "App icon copied."
fi

# Embed Sparkle.framework and fix rpath
BIN_DIR=$(swift build -c release --scratch-path "$SCRATCH_PATH" --show-bin-path)
SPARKLE_FW="$BIN_DIR/Sparkle.framework"
if [ -d "$SPARKLE_FW" ]; then
    FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
    mkdir -p "$FRAMEWORKS_DIR"
    cp -R "$SPARKLE_FW" "$FRAMEWORKS_DIR/"
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/Mwah" 2>/dev/null || true
    echo "Sparkle.framework embedded."
fi

echo "Mwah.app created at: $APP_DIR"

# Create zip archive for distribution
ARCHIVE_PATH="$BUILD_DIR/Mwah.zip"
rm -f "$ARCHIVE_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ARCHIVE_PATH"
echo "Archive created at: $ARCHIVE_PATH"

# Sign the archive with Sparkle's EdDSA key if sign_update is available
SIGN_UPDATE=""
# Check SPM artifacts location first, then checkouts, then PATH
SPARKLE_ARTIFACTS="$SCRATCH_PATH/artifacts/sparkle/Sparkle/bin/sign_update"
SPARKLE_CHECKOUT="$SCRATCH_PATH/checkouts/Sparkle/bin/sign_update"
if [ -x "$SPARKLE_ARTIFACTS" ]; then
    SIGN_UPDATE="$SPARKLE_ARTIFACTS"
elif [ -x "$SPARKLE_CHECKOUT" ]; then
    SIGN_UPDATE="$SPARKLE_CHECKOUT"
elif command -v sign_update &> /dev/null; then
    SIGN_UPDATE="sign_update"
fi

if [ -n "$SIGN_UPDATE" ]; then
    echo ""
    echo "Signing archive with EdDSA..."
    SIGNATURE=$("$SIGN_UPDATE" "$ARCHIVE_PATH" 2>/dev/null || true)
    if [ -n "$SIGNATURE" ]; then
        echo "=== Sparkle Signature ==="
        echo "$SIGNATURE"
        echo "========================="
    else
        echo "Note: Could not sign. Run 'generate_keys' first to create a signing key."
    fi
else
    echo ""
    echo "Note: sign_update not found. Archive created but not signed."
    echo "Install Sparkle tools to sign: https://github.com/sparkle-project/Sparkle/releases"
fi

echo ""
echo "To run:"
echo "  open $APP_DIR"
echo ""
echo "To run with debug mode:"
echo "  open $APP_DIR --args --debug"
echo ""
echo "To run a second instance:"
echo "  open -n $APP_DIR --args --debug"
