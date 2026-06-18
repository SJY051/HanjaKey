# HanjaKey

A macOS menu-bar utility that emulates the Korean **한자 키**: press a global hotkey, type a
Hangul reading, and pick a **Hanja** (for a syllable) or a **KS X 1001 special symbol** (for a
single jamo) to insert — Maccy-style, **without** being a system input method.

> Warm-up mini-project. Spec: [`docs/specs/001-hanja-hotkey/spec.md`](docs/specs/001-hanja-hotkey/spec.md).

## Structure

| Target | Kind | Notes |
|---|---|---|
| `HanjaKitCore` | library | Pure conversion engine (no AppKit/SwiftUI). The tested core. |
| `HanjaKey` | executable | Menu-bar agent: `NSStatusItem` + non-activating `NSPanel` hosting SwiftUI; global hotkey via `KeyboardShortcuts`. |
| `HanjaKitCoreTests` | tests | Engine unit tests (run without Xcode). |

Data: Unicode **Unihan `kHangul`** (Hanja, inverted to reading→characters) + a KS X 1001 symbol
table. See [`Sources/HanjaKitCore/Resources/README.md`](Sources/HanjaKitCore/Resources/README.md)
for sources/licenses. **No public macOS API exists for Hangul→Hanja** (verified) — hence a bundled table.

## Build & test

```bash
# The engine library builds with Command Line Tools alone:
swift build --target HanjaKitCore

# Tests use XCTest, which ships with the Xcode toolchain (NOT Command Line Tools).
# Either select Xcode once (sudo)…
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
swift test
# …or run per-command without sudo:
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test

# The app target (HanjaKey) also needs the Xcode toolchain:
swift run HanjaKey   # after xcode-select, or prefixed with DEVELOPER_DIR=…
```

## Status

Scaffolded (skeleton + TODO stubs + tests in TDD **red** state). Implementation order:
1. `HangulUtil.classify` → 2. `UnihanTable.parse` → 3. `Converter.candidates` (M1 engine green),
then the app shell (hotkey → panel → clipboard), then **M2** (Accessibility: read selection +
paste-back).
