#!/usr/bin/env bash
set -euo pipefail

APP_PATH=""
VERSION="0.1.0"
SKIP_DMG=0

for arg in "$@"; do
  case "$arg" in
    --skip-dmg) SKIP_DMG=1 ;;
    -h|--help)
      echo "Usage: package_release.sh <App.app> [version] [--skip-dmg]" >&2
      exit 0
      ;;
    *)
      if [[ -z "$APP_PATH" ]]; then
        APP_PATH="$arg"
      else
        VERSION="$arg"
      fi
      ;;
  esac
done

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "App not found: ${APP_PATH:-<missing>}" >&2
  echo "Usage: package_release.sh <App.app> [version] [--skip-dmg]" >&2
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

if [[ "$SKIP_DMG" -eq 0 ]]; then
  DMG_DIR="$DIST/dmg"
  mkdir -p "$DMG_DIR"
  ditto "$STAGE/$APP_NAME" "$DMG_DIR/$APP_NAME"
  ln -s /Applications "$DMG_DIR/Applications"

  # UDZO (zlib) — never UDRW/UDTO raw copies, which balloon artifact size.
  hdiutil create \
    -volname "MacBook FaceID $VERSION" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DIST/MacBook-FaceID.dmg"
fi

# Drop staging trees so dist/ only contains the compressed artifacts.
rm -rf "$STAGE" "$DIST/dmg"

echo "Packed $VERSION"
ls -lh "$DIST"
