#!/usr/bin/env bash
# Build and package Paperless-NGX Uploader for Linux.
# Produces: a .tar.gz portable bundle and a .deb installer package.
#
# Usage:
#   ./scripts/build_and_package.sh [--sign]
#
# Options:
#   --sign   Sign the .deb with dpkg-sig (requires a GPG key configured)
#
# Requirements:
#   flutter, dpkg-deb (part of dpkg), optionally dpkg-sig

set -euo pipefail

SIGN=false
for arg in "$@"; do
  case "$arg" in
    --sign) SIGN=true ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Read version and build number from pubspec.yaml
FULL_VERSION="$(grep '^version:' "$REPO_ROOT/pubspec.yaml" | awk '{print $2}')"
VERSION_NAME="${FULL_VERSION%%+*}"   # e.g. 1.8.4
BUILD_NUMBER="${FULL_VERSION##*+}"   # e.g. 25 (falls back to full version if no +)
[[ "$BUILD_NUMBER" == "$FULL_VERSION" ]] && BUILD_NUMBER="1"

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64)  BUILD_ARCH="x64" ; DEB_ARCH="amd64" ;;
  aarch64) BUILD_ARCH="arm64"; DEB_ARCH="arm64" ;;
  *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

BUNDLE_DIR="$REPO_ROOT/build/linux/$BUILD_ARCH/release/bundle"
OUTPUT_DIR="$REPO_ROOT/build/linux/$BUILD_ARCH/release/dist"
APP_ID="net.gmartin.paperlessngx_uploader"
BINARY_NAME="paperlessngx_uploader"
APP_NAME="Paperless-NGX Uploader"

echo "=== Building $APP_NAME $VERSION_NAME (versionCode $BUILD_NUMBER) ==="

# ── 1. Flutter build ────────────────────────────────────────────────────────
echo "→ flutter build linux --release"
cd "$REPO_ROOT"
flutter build linux --release

if [[ ! -f "$BUNDLE_DIR/$BINARY_NAME" ]]; then
  echo "ERROR: executable not found at $BUNDLE_DIR/$BINARY_NAME"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# ── 2. Portable .tar.gz ──────────────────────────────────────────────────────
TAR_NAME="PaperlessNGX_Uploader-${VERSION_NAME}-linux-${ARCH}.tar.gz"
TAR_PATH="$OUTPUT_DIR/$TAR_NAME"

echo "→ Creating portable archive: $TAR_NAME"
tar -czf "$TAR_PATH" -C "$BUNDLE_DIR/.." bundle
echo "   Size: $(du -h "$TAR_PATH" | cut -f1)"

# ── 3. .deb package ─────────────────────────────────────────────────────────
DEB_NAME="paperlessngx-uploader_${VERSION_NAME}_${DEB_ARCH}.deb"
DEB_PATH="$OUTPUT_DIR/$DEB_NAME"
DEB_STAGE="$OUTPUT_DIR/deb_stage"

echo "→ Creating .deb package: $DEB_NAME"

rm -rf "$DEB_STAGE"

# Directory layout inside the deb
INSTALL_PREFIX="$DEB_STAGE/usr"
mkdir -p "$INSTALL_PREFIX/lib/$APP_ID"
mkdir -p "$INSTALL_PREFIX/bin"
mkdir -p "$INSTALL_PREFIX/share/applications"
mkdir -p "$INSTALL_PREFIX/share/icons/hicolor/256x256/apps"
mkdir -p "$DEB_STAGE/DEBIAN"

# Copy bundle files into /usr/lib/<app_id>/
cp -r "$BUNDLE_DIR/." "$INSTALL_PREFIX/lib/$APP_ID/"

# Wrapper script in /usr/bin so it can be launched from PATH
cat > "$INSTALL_PREFIX/bin/paperlessngx_uploader" <<'WRAPPER'
#!/usr/bin/env bash
SELF="$(readlink -f "$0")"
HERE="$(dirname "$SELF")"
INSTALL_DIR="$HERE/../lib/net.gmartin.paperlessngx_uploader"
export LD_LIBRARY_PATH="$INSTALL_DIR/lib:${LD_LIBRARY_PATH:-}"
exec "$INSTALL_DIR/paperlessngx_uploader" "$@"
WRAPPER
chmod +x "$INSTALL_PREFIX/bin/paperlessngx_uploader"

# .desktop file
cp "$REPO_ROOT/linux/$APP_ID.desktop" "$INSTALL_PREFIX/share/applications/$APP_ID.desktop"
# Ensure Exec points to the wrapper
sed -i "s|^Exec=.*|Exec=paperlessngx_uploader|" "$INSTALL_PREFIX/share/applications/$APP_ID.desktop"

# Icon
if [[ -f "$REPO_ROOT/paperlessngx-share.png" ]]; then
  cp "$REPO_ROOT/paperlessngx-share.png" "$INSTALL_PREFIX/share/icons/hicolor/256x256/apps/$APP_ID.png"
fi

# Calculate installed size in KiB
INSTALLED_SIZE=$(du -sk "$INSTALL_PREFIX" | cut -f1)

# DEBIAN/control
cat > "$DEB_STAGE/DEBIAN/control" <<CONTROL
Package: paperlessngx-uploader
Version: ${VERSION_NAME}
Architecture: ${DEB_ARCH}
Maintainer: Germán Martín <$(git config user.email 2>/dev/null || echo 'maintainer@example.com')>
Installed-Size: ${INSTALLED_SIZE}
Depends: libgtk-3-0, libblkid1, liblzma5
Section: utils
Priority: optional
Homepage: https://github.com/gmag11/Paperless_ngx_uploader
Description: Upload documents to Paperless-NGX document management system
 Paperless-NGX Uploader is a native desktop and mobile client for the
 Paperless-NGX self-hosted document management system. Drag and drop
 documents to upload them directly to your Paperless-NGX instance.
CONTROL

# DEBIAN/postinst — update icon and desktop databases
cat > "$DEB_STAGE/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f /usr/share/icons/hicolor
fi
POSTINST
chmod 755 "$DEB_STAGE/DEBIAN/postinst"

dpkg-deb --build --root-owner-group "$DEB_STAGE" "$DEB_PATH"
echo "   Size: $(du -h "$DEB_PATH" | cut -f1)"

# ── 4. Optional signing ──────────────────────────────────────────────────────
if [[ "$SIGN" == "true" ]]; then
  if command -v dpkg-sig >/dev/null 2>&1; then
    echo "→ Signing .deb with dpkg-sig"
    dpkg-sig --sign builder "$DEB_PATH"
  else
    echo "WARNING: --sign requested but dpkg-sig not found; skipping signing"
  fi
fi

# ── 5. Checksums ─────────────────────────────────────────────────────────────
echo "→ Generating checksums"
(cd "$OUTPUT_DIR" && sha256sum "$TAR_NAME" "$DEB_NAME" > SHA256SUMS)
cat "$OUTPUT_DIR/SHA256SUMS"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "=== Done ==="
echo "   Archive : $TAR_PATH"
echo "   Package : $DEB_PATH"
echo "   Checksums: $OUTPUT_DIR/SHA256SUMS"

rm -rf "$DEB_STAGE"
