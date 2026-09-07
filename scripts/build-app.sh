#!/bin/bash
# Builds "HiDPI Master.app" as a Universal binary (Intel x86_64 + Apple Silicon arm64).
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP_NAME="HiDPI Master"
BUNDLE_ID="com.hidpimaster.app"
VERSION="${APP_VERSION:-1.1.1}"
DIST="$ROOT/dist"

# Full Xcode supports `--arch a --arch b` directly; Command Line Tools alone
# do not, so build each slice with --triple and merge with lipo.
if swift build -c release --arch arm64 --arch x86_64 2>/dev/null; then
  echo "==> Built universal binary via xcbuild"
  BUILD_DIR="$ROOT/.build/apple/Products/Release"
  BIN="$BUILD_DIR/HiDPIMaster"
  RES_BUNDLE="$BUILD_DIR/HiDPIMaster_HiDPIMaster.bundle"
else
  echo "==> Building x86_64 slice…"
  swift build -c release --triple x86_64-apple-macosx
  echo "==> Building arm64 slice…"
  swift build -c release --triple arm64-apple-macosx
  mkdir -p "$DIST"
  BIN="$DIST/HiDPIMaster-universal"
  lipo -create \
    "$ROOT/.build/x86_64-apple-macosx/release/HiDPIMaster" \
    "$ROOT/.build/arm64-apple-macosx/release/HiDPIMaster" \
    -output "$BIN"
  RES_BUNDLE="$ROOT/.build/x86_64-apple-macosx/release/HiDPIMaster_HiDPIMaster.bundle"
fi

APP="$DIST/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> Assembling app bundle…"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"

# SPM resource bundle (localizations)
if [ -d "$RES_BUNDLE" ]; then
  cp -R "$RES_BUNDLE" "$APP/Contents/Resources/"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>LSUIElement</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>zh-Hant</string>
        <string>zh-Hans</string>
    </array>
    <key>NSHumanReadableCopyright</key><string>© 2026 HiDPI Master</string>
</dict>
PLIST
echo '</plist>' >> "$APP/Contents/Info.plist"

# App icon
if [ -f "$ROOT/scripts/make-icon.swift" ]; then
  echo "==> Generating app icon…"
  ICONSET="$DIST/AppIcon.iconset"
  rm -rf "$ICONSET" && mkdir -p "$ICONSET"
  swift "$ROOT/scripts/make-icon.swift" "$ICONSET" || true
  if [ -f "$ICONSET/icon_512x512.png" ]; then
    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
  fi
  rm -rf "$ICONSET"
fi

echo "==> Code signing (ad-hoc)…"
codesign --force --deep --sign - "$APP"

echo "==> Verifying architectures…"
lipo -info "$APP/Contents/MacOS/$APP_NAME"

echo ""
echo "Done → $APP"
