#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:?Usage: package_release.sh <App.app> [version]}"
VERSION="${2:-0.1.0}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
STAGE="$DIST/stage"
rm -rf "$DIST"
mkdir -p "$STAGE"

APP_NAME="$(basename "$APP_PATH")"
ditto "$APP_PATH" "$STAGE/$APP_NAME"

# Ad-hoc sign so the bundle has a stable signature on CI (still not notarized).
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$STAGE/$APP_NAME" || true
fi

/usr/bin/ditto -c -k --keepParent "$STAGE/$APP_NAME" "$DIST/MacBook-FaceID.zip"

DMG_DIR="$DIST/dmg"
mkdir -p "$DMG_DIR"
ditto "$STAGE/$APP_NAME" "$DMG_DIR/$APP_NAME"
ln -s /Applications "$DMG_DIR/Applications"

hdiutil create \
  -volname "MacBook FaceID $VERSION" \
  -srcfolder "$DMG_DIR" \
  -ov \
  -format UDZO \
  "$DIST/MacBook-FaceID.dmg"

echo "Packed $VERSION"
ls -lh "$DIST/MacBook-FaceID.zip" "$DIST/MacBook-FaceID.dmg"
