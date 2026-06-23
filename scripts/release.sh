#!/usr/bin/env bash
# Release packaging for HanjaKey (spec 009 M2).
# Builds a release .app, stamps the version, signs it (Developer-ID + hardened runtime when an
# identity is configured, else ad-hoc for local testing), packages a drag-to-/Applications DMG,
# and notarizes + staples when a notary profile is configured.
#
#   scripts/release.sh [version]          # version defaults to Info.plist's CFBundleShortVersionString
#
# To produce a *distributable* build, set (once the Developer-ID cert exists — spec 009 M1):
#   export HANJAKEY_SIGN_IDENTITY="Developer ID Application: NAME (TEAMID)"
#   export HANJAKEY_NOTARY_PROFILE="hanjakey-notary"   # `xcrun notarytool store-credentials` profile
# Without those, it builds an ad-hoc DMG (NOT distributable) so the pipeline/layout can be tested.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${DEVELOPER_DIR:=/Applications/Xcode.app/Contents/Developer}"; export DEVELOPER_DIR

PLIST_SRC="$ROOT/bundling/Info.plist"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST_SRC")}"
SIGN_IDENTITY="${HANJAKEY_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${HANJAKEY_NOTARY_PROFILE:-}"
APP="$ROOT/.build/HanjaKey.app"
DIST="$ROOT/.build/dist"
DMG="$DIST/HanjaKey-v$VERSION.dmg"   # tag/filename use a v-prefix; CFBundleShortVersionString stays numeric

echo "[*] release build — version $VERSION"
"$ROOT/scripts/bundle.sh" release        # builds + bundles (icon, resources); ad-hoc signs (re-signed below)

# Stamp version into the bundled Info.plist (build number = git commit count, monotonic).
BUILD_NUM="$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUM" "$APP/Contents/Info.plist"

# Sign AFTER editing Info.plist so the signature stays valid.
if [ -n "$SIGN_IDENTITY" ]; then
  echo "[*] codesign — Developer-ID + hardened runtime: $SIGN_IDENTITY"
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
else
  echo "[!] HANJAKEY_SIGN_IDENTITY unset — ad-hoc signing (DEV ONLY, not distributable)"
  codesign --force --deep --sign - "$APP"
fi
codesign --verify --deep --strict "$APP" && echo "[ok] signature valid"

# Package a drag-to-/Applications DMG.
echo "[*] create-dmg → $DMG"
mkdir -p "$DIST"; rm -f "$DMG"
STAGE="$(mktemp -d)"; cp -R "$APP" "$STAGE/"
create-dmg \
  --volname "HanjaKey v$VERSION" \
  --window-size 540 380 \
  --icon-size 110 \
  --icon "HanjaKey.app" 150 195 \
  --app-drop-link 390 195 \
  --no-internet-enable \
  "$DMG" "$STAGE" || echo "[!] create-dmg returned nonzero (cosmetic Finder styling can fail on a locked/headless session)"

# create-dmg's exit code can be a benign styling failure, but the DMG itself MUST exist and verify —
# otherwise a broken or missing artifact would slip through as a 'successful' release.
test -s "$DMG" || { echo "[error] DMG was not created: $DMG"; exit 1; }
hdiutil verify "$DMG" >/dev/null || { echo "[error] DMG failed hdiutil verify: $DMG"; exit 1; }
echo "[ok] DMG verified"

# Notarize + staple the DMG when a notary profile is configured (needs a real Developer-ID signature).
if [ -n "$SIGN_IDENTITY" ] && [ -n "$NOTARY_PROFILE" ]; then
  echo "[*] notarize via profile '$NOTARY_PROFILE' (waits for Apple)"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG" && echo "[ok] notarized + stapled"
else
  echo "[!] skipping notarization (set HANJAKEY_SIGN_IDENTITY + HANJAKEY_NOTARY_PROFILE to enable)"
fi

echo "[done] $DMG"
