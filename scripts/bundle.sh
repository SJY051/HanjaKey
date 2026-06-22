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

# App icon (spec 008): compile the Liquid Glass .icon into Assets.car (macOS 26+) plus a
# legacy AppIcon.icns fallback (14/15). actool emits both; no Xcode project needed.
ICON_SRC="$ROOT/bundling/AppIcon.icon"
if [ -d "$ICON_SRC" ]; then
  echo "[*] compiling app icon ($ICON_SRC)"
  ICON_OUT="$(mktemp -d)"
  xcrun actool "$ICON_SRC" --compile "$ICON_OUT" \
    --app-icon AppIcon --include-all-app-icons \
    --target-device mac --minimum-deployment-target 26.0 --platform macosx \
    --output-partial-info-plist "$ICON_OUT/icon-info.plist" \
    --output-format human-readable-text --notices --warnings --errors
  cp "$ICON_OUT/Assets.car" "$APP/Contents/Resources/"
  cp "$ICON_OUT/AppIcon.icns" "$APP/Contents/Resources/"
  rm -rf "$ICON_OUT"
else
  echo "[!] no app icon at $ICON_SRC — bundling without an icon"
fi

# Menu-bar template mark (spec 008 M2): a vector PDF, tinted via NSImage.isTemplate at runtime.
if [ -f "$ROOT/bundling/menubar-mark.pdf" ]; then
  cp "$ROOT/bundling/menubar-mark.pdf" "$APP/Contents/Resources/"
fi

# Ad-hoc signing (the "-" identity). Free; no certificate or Developer Program needed.
codesign --force --deep --sign - "$APP"

echo "[ok] built $APP"
codesign -dvv "$APP" 2>&1 | sed -n '1,5p' || true
echo "[i] run it:  open \"$APP\""
