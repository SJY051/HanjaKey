---
title: HanjaKey — global-hotkey Hangul→Hanja/symbol picker (macOS)
status: approved     # draft -> approved -> implemented
created: 2026-06-18
owner: ASQi
tags: [macos, swiftui, swift, warm-up, hanja, hotkey, menu-bar]
---

# HanjaKey — global-hotkey Hangul→Hanja/symbol picker (macOS)

## Context & problem

A **warm-up mini-project** before the main project, chosen to (1) exercise the Swift
toolchain (`swift build`/`swift test` + sourcekit-lsp / the new `swift-lsp`), (2) rehearse our
phased workflow (spec → scaffold → TDD → retro), and (3) build Swift fundamentals that transfer
to the main project's Swift portion.

The product idea (long-wanted by the owner): emulate the Korean **한자 키** as a standalone
utility. Pressing the 한자 key after a Hangul syllable normally offers Hanja candidates (한 → 漢
韓 恨 …), and after a single jamo offers special symbols (ㅁ → ※ ◎ □ …). HanjaKey reproduces
this as a **Maccy-style background app**: a global hotkey pops up a panel, the user types/holds a
Hangul reading, sees candidates, and picks one to insert — **without** being a system input
method.

**Load-bearing finding (verified in Phase 1, 2026-06-18):** macOS exposes **no public API** for
Hangul→Hanja conversion — that conversion lives inside the built-in Korean input method.
Confirmed two ways: (a) web research (Apple docs only describe the user-facing Option+Return
candidate window; no developer API); (b) a `CFStringTransform` probe where `Hangul-Han` and
`Han-Hangul` return `false` (only romanization like `Hangul-Latin` → "hanja" works). **Therefore
the conversion data MUST be a bundled standard table** — not a system call. (This is exactly the
"verify the integration before building on it / connected ≠ works" rule paying off.)

## Differentiation vs the macOS built-in

macOS already converts Hangul→Hanja through the Korean input method (the Option+Return candidate
window). HanjaKey is not a reimplementation of that — it differentiates by:
- **Special-symbol input from a jamo** (ㅁ → ※ ◎ □ …) — the built-in flow does **not** offer this.
- A **global-hotkey popup callable from anywhere**, independent of the active input source, vs the
  built-in's in-context candidate window tied to Korean input being active.
- A **single searchable candidate grid** (Maccy-style) unifying Hanja + symbols, aimed at a
  smoother pick-and-insert UX than the built-in's clunky list.

## Goals / non-goals

- **Goals:**
  - A working background/menu-bar macOS app summoned by a **global hotkey** that converts a typed
    Hangul reading into **Hanja candidates** (syllables) and **KS X 1001 special symbols** (single
    jamo), and outputs the chosen character.
  - A **pure, well-unit-tested conversion engine** (reading → ordered candidate list) — the
    warm-up's testing centerpiece.
  - Offline / self-contained (bundled data table; no network, no system-IME dependency).
- **Non-goals:**
  - **A system input method (InputMethodKit/IMKit)** — explicitly out of scope (too heavy for a
    warm-up; the engine could later feed one).
  - Reproducing the OS conversion exactly / full Hanja dictionary coverage with glosses, rankings,
    or frequency ordering beyond what the chosen table provides.
  - iOS / cross-platform. macOS only.
  - Shipping/notarization/distribution. Local dev build only.

## Requirements

### Conversion engine (pure, testable)
- **FR-001**: The engine MUST map a **Hangul syllable** (e.g. "한") to an ordered list of **Hanja
  candidates**, sourced from a **bundled standard table** (see FR-008). No system API
  (verified unavailable).
- **FR-002**: The engine MUST map a **single Hangul jamo** (e.g. "ㅁ") to **KS X 1001 special
  symbols**.
- **FR-003**: The engine MUST be a **pure function / value type** with no UI or AppKit dependency,
  so it is unit-testable via `swift test`. Thorough unit coverage is required (per global CLAUDE.md
  testing rules) — known mappings, empty/invalid input, multi-candidate ordering.
- **FR-004**: The engine MUST handle no-match input gracefully (return empty candidates, not crash).

### App shell & interaction
- **FR-005**: The app MUST run as a **background / menu-bar agent** (`LSUIElement` / `MenuBarExtra`),
  not a regular Dock app.
- **FR-006**: A **configurable global hotkey** MUST summon a popup panel from anywhere, via the
  **`sindresorhus/KeyboardShortcuts` SPM package** (resolved — SwiftUI-friendly, ships a recorder
  UI). Carbon `RegisterEventHotKey` is the fallback if the package proves unsuitable.
- **FR-007**: The popup MUST let the user enter a Hangul reading and show candidates in a
  navigable grid/list; selecting one (click or keyboard) **copies it to the clipboard** and
  dismisses the panel.

### Data
- **FR-008**: Hanja data comes from a bundled **libhangul `hanja.txt`** table (resolved
  2026-06-18, **revised from Unihan kHangul**): it pairs each reading with Hanja **and a Korean
  gloss (음+뜻, e.g. 韓 → "나라 한")** — satisfying the gloss requirement (FR-013) — is
  open-source / redistributable, and is curated for exactly this IME 한자-key use (so coverage and
  candidate order match expectations). Symbol data from a **KS X 1001 symbol table**. The repo
  MUST document each table's source URL + license + version. (Unihan `kHangul` was the prior
  choice but carries readings only, no Korean gloss; see Data-source research below.)
- **FR-013**: A Hanja candidate SHOULD display its Korean **음/뜻 gloss** alongside the glyph
  (from libhangul). `Candidate.gloss` already exists for this.
- **FR-009**: Bundled data is **untrusted-input-safe**: parsed defensively at load (it's a data
  file, not code); malformed rows are skipped, not fatal.

### Scope / milestones — both M1 and M2 are in scope this iteration (resolved)
- **FR-010 (M1)**: User types the Hangul **into the popup itself** → candidates → **copy to
  clipboard**. **No Accessibility permission** required. Built and verified first.
- **FR-011 (M2)**: Read the **selected text** in the frontmost app and **paste the chosen result
  back** in place (Accessibility permission; `AXSelectedText` or clipboard-shuttle + synth ⌘V).
  Completes the true Maccy-style flow. Built on top of M1 once M1 passes.

### Toolchain
- **FR-012**: Build with full **Xcode** (installed at `/Applications/Xcode.app`; select via
  `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`, or per-command
  `DEVELOPER_DIR=…` without sudo). Swift 6.3.2. The conversion engine is a plain SwiftPM library
  (no `.xcodeproj`/GUI), but note: **`swift test` needs the Xcode toolchain because XCTest is not
  in Command Line Tools** (verified during scaffold — `swift build --target HanjaKitCore` works on
  CLT; `swift test` fails with "no such module 'XCTest'" until the Xcode toolchain is active).

## User scenarios

### Convert a syllable to Hanja (P1, M1)
- **Given** HanjaKey is running in the menu bar
- **When** I press the global hotkey, type "한", and pick 韓 from the candidate grid
- **Then** 韓 is on my clipboard and the panel closes.

### Get a special symbol from a jamo (P1, M1)
- **Given** the popup is open
- **When** I type "ㅁ"
- **Then** I see KS X 1001 symbols (※ ◎ □ …) and can pick one to the clipboard.

### Convert in place from another app (P2, M2)
- **Given** I selected "한자" in TextEdit
- **When** I press the hotkey and choose candidates
- **Then** the selection is replaced with the chosen characters (Accessibility).

### Engine correctness (P1)
- **Given** the unit test suite
- **When** `swift test` runs
- **Then** known readings map to expected candidates; invalid/empty input yields no candidates and
  no crash.

## Success criteria
- **SC-001**: `swift test` passes a thorough unit suite for the conversion engine (syllable→Hanja,
  jamo→symbol, edge cases), run without Xcode GUI.
- **SC-002**: A global hotkey opens the popup over any app; typing a Hangul reading shows correct
  candidates.
- **SC-003**: Selecting a candidate places exactly that character on the clipboard (M1).
- **SC-004**: No network calls; conversion works fully offline from the bundled table.
- **SC-005 (if M2 in scope)**: Selecting text in another app and converting replaces it in place.

## Decisions (resolved 2026-06-18)
- **(a) Data table → libhangul `hanja.txt`** (revised 2026-06-18 from Unihan kHangul): carries
  음+뜻 glosses, is redistributable, and is IME-curated. See Data-source research below.
- **(b) Scope → M1 + M2** both this iteration (clipboard first, then in-place paste via Accessibility).
- **Hotkey library → `sindresorhus/KeyboardShortcuts`** (Carbon fallback).
- **Candidate ordering → table order** for the warm-up (frequency/stroke ranking is future work).

## Data-source research (2026-06-18)

Investigated using macOS's *own* Hanja data (it shows 음/뜻). Found
`KoreanSystemDictionary.dictionary` inside
`/System/Library/Input Methods/KoreanIM.app/Contents/PlugIns/KIM_Extension.appex/.../HanjaTool.app`
— a **Dictionary Services bundle** (Info.plist: format v3, `com.apple.TrieAccessMethod`,
big-endian; `index-0` + `index-0_subdata`, ~2.5 MB) with full glosses, bundle id
`com.apple.KoreanIM.KoreanSystemDictionary`. **Rejected as our data source:**
1. **Non-redistributable** — Apple-proprietary; bundling/copying it is not allowed. Only a
   *personal* runtime-read of the on-disk file would be license-tolerable (never if distributed).
2. **No clean/stable API** — public `DictionaryServices` (`DCSCopyTextDefinition`) only queries the
   user's *active* dictionaries, not this internal IME bundle; reaching it needs **private** DCS
   APIs (`DCSDictionaryCreate(url)`) or **reverse-engineering the Trie binary** — both fragile
   across macOS versions.

So it is **not the dependency-free "free win" it appeared** (verify-before-building). Decision:
bundle **libhangul `hanja.txt`** (open, redistributable, 음+뜻, IME-curated). A personal
runtime-read of the Apple dictionary remains a possible *optional later* experiment, not the base.

## Open questions
- (none blocking — data source resolved to libhangul; ready to continue implementation.)

## Post-M1 feedback backlog (P-tiers, from 2026-06-18 testing)

M1 (engine + popup + clipboard) shipped and works; testing surfaced that it currently behaves like
a "searcher", not the real 한자 key. Prioritized backlog:

- **P0 — in-place conversion (the core identity):** type → hotkey → candidates appear **at the
  caret** → chosen char is **inserted in place** (not just clipboard). Needs Accessibility.
- **P0 — `.app` bundle packaging:** Info.plist (`LSUIElement`) + bundle id + signing. Prereq for a
  reliable menu-bar icon and for stable Accessibility (TCC) permission. Likely fixes the icon bug.
- **P0 — menu-bar icon not visible → RESOLVED 2026-06-18 (not a code bug).** Instrumentation
  showed the status item is created correctly (button present, `isVisible=true`, ~30×30 frame,
  `.accessory`). Root cause = **menu-bar space exhaustion** on a notched Mac: icon slots are
  finite and zero-sum (turning HanjaKey on pushed another app's icon out); Ice was hiding the
  overflow. Glyph changed from a misleading SF Symbol to text `漢`. See P2 (optional icon).
- **P1 — keyboard selection + compact UI:** number keys (1–9), arrows, Enter; Tab to expand;
  shrink the window. (Original Hanja-key UX.)
- **P1 — data coverage & order:** full libhangul `hanja.txt` + full KS X 1001 symbol rows in the
  expected order (replaces the sample tables + `UnihanTable` with a libhangul parser).
- **P2 — Hanja 음/뜻 display** (FR-013; comes free with libhangul data).
- **P2 — Liquid Glass material** for the popup.
- **P2 — optional menu-bar icon:** a toggle to hide it (the app is hotkey-driven → the icon is
  non-essential), with **Quit/Settings reachable from the popup** when hidden. Menu-bar icon slots
  are finite/zero-sum on notched Macs (confirmed: enabling HanjaKey evicted another app's icon).

## Future expansion
If this grows beyond the warm-up — a real IMKit input method, fuller dictionary with glosses/
search, candidate ranking, or distribution/notarization — add a `plan.md` (HOW) and `tasks.md`
(DO) alongside this file. Not created now. The pure conversion engine (FR-001..004) is
deliberately decoupled so it could later back an IMKit target.
