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
- **FR-008**: Hanja data MUST come from a bundled standard table: **Unicode Unihan `kHangul`**
  (resolved — permissive Unicode license; the `kHangul` field gives each Han char's Hangul
  reading(s), inverted at build/load into reading→[Hanja]). Symbol data from a **KS X 1001 symbol
  table**. The repo MUST document the source URL + license + version of the bundled data.
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
- **(a) Data table → Unicode Unihan `kHangul`** (permissive license; inverted to reading→Hanja).
- **(b) Scope → M1 + M2** both this iteration (clipboard first, then in-place paste via Accessibility).
- **Hotkey library → `sindresorhus/KeyboardShortcuts`** (Carbon fallback).
- **Candidate ordering → table order** for the warm-up (frequency/stroke ranking is future work).

## Open questions
- (none blocking — ready to scaffold.)

## Future expansion
If this grows beyond the warm-up — a real IMKit input method, fuller dictionary with glosses/
search, candidate ranking, or distribution/notarization — add a `plan.md` (HOW) and `tasks.md`
(DO) alongside this file. Not created now. The pure conversion engine (FR-001..004) is
deliberately decoupled so it could later back an IMKit target.
