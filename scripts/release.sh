#!/bin/bash
set -euo pipefail

# Usage: ./scripts/release.sh <version>
# Example: ./scripts/release.sh 1.2.0

VERSION="${1:?Usage: $0 <version>}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"

echo "=== Releasing Mwah v$VERSION ==="
echo ""

# Build with version stamping
echo "Step 1: Building..."
bash "$PROJECT_DIR/scripts/build.sh" "$VERSION"

# Verify archive
ARCHIVE="$BUILD_DIR/Mwah.zip"
if [ ! -f "$ARCHIVE" ]; then
    echo "Error: Archive not found at $ARCHIVE"
    exit 1
fi

FILE_SIZE=$(stat -f%z "$ARCHIVE")

echo ""
echo "=== Next Steps ==="
echo ""
echo "1. Update appcast.xml - add a new <item> with:"
echo "   sparkle:version=\"$VERSION\""
echo "   url=\"https://github.com/ganeshasapu/vday/releases/download/v$VERSION/Mwah.zip\""
echo "   length=\"$FILE_SIZE\""
echo "   sparkle:edSignature=\"<signature from above>\""
echo ""
echo "2. Commit and push:"
echo "   git add appcast.xml && git commit -m \"Release v$VERSION\" && git push"
echo ""
echo "3. Create GitHub release:"
echo "   gh release create v$VERSION $ARCHIVE --title \"Mwah v$VERSION\" --notes \"Release notes\""
