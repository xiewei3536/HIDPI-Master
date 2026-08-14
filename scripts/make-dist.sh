#!/bin/bash
# Packages dist/HiDPI Master.app into HiDPI-Master.dmg and HiDPI-Master.zip
set -euo pipefail
cd "$(dirname "$0")/.."
APP="dist/HiDPI Master.app"
test -d "$APP" || { echo "app bundle missing — run scripts/build-app.sh first"; exit 1; }

echo "==> ZIP (used by in-app auto-update)…"
ditto -c -k --keepParent "$APP" "dist/HiDPI-Master.zip"

echo "==> DMG…"
STAGE="dist/dmg-stage"
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "dist/HiDPI-Master.dmg"
hdiutil create -volname "HiDPI Master" -srcfolder "$STAGE" -ov -format UDZO "dist/HiDPI-Master.dmg"
rm -rf "$STAGE"
ls -lh dist/HiDPI-Master.*
