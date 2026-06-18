#!/usr/bin/env bash
# Assemble HanjaKey.app from the SwiftPM executable (approach A — no Xcode project).
# Ad-hoc code signing (free, no Apple Developer Program) — enough to run locally and to
# grant Accessibility. Usage: scripts/bundle.sh [debug|release]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-debug}"
: "${DEVELOPER_DIR:=/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR

echo "[*] building HanjaKey ($CONFIG) with DEVELOPER_DIR=$DEVELOPER_DIR"
swift build -c "$CONFIG" --product HanjaKey
BINDIR="$(swift build -c "$CONFIG" --product HanjaKey --show-bin-path)"

APP="$ROOT/.build/HanjaKey.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BINDIR/HanjaKey" "$APP/Contents/MacOS/HanjaKey"
cp "$ROOT/bundling/Info.plist" "$APP/Contents/Info.plist"

# Include the SwiftPM resource bundle (bundled Hanja/symbol data) so Bundle.module resolves.
RES="$BINDIR/HanjaKey_HanjaKitCore.bundle"
if [ -d "$RES" ]; then
  cp -R "$RES" "$APP/Contents/Resources/"
else
  echo "[!] resource bundle not found at $RES — bundled data would fail to load"; exit 1
fi

# Ad-hoc signing (the "-" identity). Free; no certificate or Developer Program needed.
codesign --force --deep --sign - "$APP"

echo "[ok] built $APP"
codesign -dvv "$APP" 2>&1 | sed -n '1,5p' || true
echo "[i] run it:  open \"$APP\""
