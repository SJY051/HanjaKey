---
title: 어절 segmentation — word/syllable/symbol boundary
status: implemented  # draft -> approved -> implemented  (M1 done; M2 deferred)
created: 2026-06-22
owner: ASQi
tags: [capture, segmentation, routing, word, syllable, symbol, ax]
---

# 어절 segmentation — word/syllable/symbol boundary

## Context & problem
Converting via ⌥⌘H captures a fixed trailing Hangul run and routes it to candidates by the run's raw
**length**, so it cannot tell a word from a syllable from a lone symbol-jamo. Phase-1 research (2026-06-22)
confirmed two distinct sub-problems by reading the code:

- **(A) A trailing lone compatibility jamo is absorbed into the run and misrouted.** `AXContext.capture()`
  keeps `trailingHangulRun`, which counts **both** syllables (U+AC00–D7A3) **and** compatibility jamo
  (U+3131–3163). So `가ㄱ` is captured as one 2-char run → `CandidateView.init` routes `reading.count >= 2`
  to the 한자어 word path → `WordTable` exact-match miss → the "음절별로 만들기" screen. The KS X 1001 symbol
  candidates for the lone `ㄱ` never appear. (`Converter.candidates(for:)` only routes jamo→symbol for a
  **single-char** input via `HangulUtil.classify`; a ≥2-char run never reaches it.)
- **(B) The captured run doesn't match the user's intended unit.** Routing on raw captured length is fragile
  because the fixed `Shift+←×maxCapture(6)` capture over- or under-captures — e.g. with no space `나는한국`
  is grabbed whole and exact-match misses; or only the last syllable is captured and shows a single Hanja.

Current flow: `AppDelegate.togglePanel` → `AXContext.capture()` (synthesize `Shift+←`×6 + ⌘C + pasteboard
poll → `trailingHangulRun`, then the spec-006 capture-time selection-collapse + `selectBack`) →
`PopupPanel.present(reading:)` → `CandidateView.init` routes by `reading.count` →
`Converter.candidates(for:)` (single: `HangulUtil.classify` syllable→Hanja / jamo→symbol),
`candidates(forWord:using:freq:)` (`WordTable`, **exact-match only**), or the per-syllable
`decompositionView` fallback. `WordTable`/`HanjaTable`/`SymbolTable` are exact-key lookups.

**Crux (decides the approach):** Electron/Chromium serve a **stale `kAXValue` right after typing** — the
very reason capture already uses ⌘C synth-keys instead of AX reads (see [[macos-ax-inplace-text]]). So a
true-AX-value 어절 boundary is unreliable off-native. The high-value fix is therefore **classification +
routing on the captured text**, not switching to AX-value reads.

## Goals / non-goals
**Goals**
- Route the captured run to the right candidate kind — symbol / word / single-syllable — by **content**,
  not by raw captured length; and replace **only** the active token.
- Fix the reported misroutes: `가ㄱ` shows symbols for `ㄱ`; over-captured `나는한국` converts only `한국`;
  a real multi-syllable word converts as a word; a non-dictionary run offers per-syllable build.
- Keep the boundary/routing logic **pure and unit-tested** in `HanjaKitCore`; app-agnostic (works on the
  ⌘C-captured text, so native + Electron + browser alike). Zero runtime network.

**Non-goals**
- Not switching capture to AX-value reads as the primary path (deferred to M2; Electron-stale-AX).
- Not re-ranking word/Hanja candidates (specs 003/005) or changing the popup grid/scroll (spec 006).
- Not full morphological analysis / true NLP word segmentation — a pragmatic dictionary + jamo heuristic.

## Requirements
- **FR-001**: A **trailing lone compatibility jamo** (U+3131–3163) at the caret MUST be treated as a
  **symbol token** and route to KS X 1001 symbols, regardless of any Hangul syllables before it. Only the
  jamo is replaced (`selectBack = 1`). (Q1)
- **FR-002**: After removing a trailing jamo, the remaining syllable run MUST route by **longest dictionary
  suffix match**: the longest suffix that is a 한자어 in `WordTable` → **word** candidates for that suffix,
  replacing only that suffix. (Q2)
- **FR-003**: If no suffix of the syllable run is a dictionary word, the run MUST fall back to **per-syllable
  decomposition** (the existing `decompositionView`); a single-syllable run is the 1-syllable case (single
  Hanja). The engine MUST NOT silently collapse a multi-syllable run to its last single syllable (bug B).
- **FR-004**: The boundary/routing decision MUST live in a **pure, unit-tested segmenter in
  `HanjaKitCore`** that, given the captured run, returns the **active token** (the unit at the caret) + its
  **kind** (symbol-jamo / word / single-syllable) + its **length**. `CandidateView` routes by the kind;
  `AXContext` sets `selectBack` to the token length so insertion replaces exactly the active token.
- **FR-005**: `WordTable` MUST gain a **longest-suffix lookup** (it is exact-match only today), used by the
  segmenter; `HanjaTable`/`SymbolTable` lookups are unchanged.
- **FR-006**: No regression to the spec-006 capture/insert path (focus return, capture-time selection
  collapse, AX-less -25212 tolerance) or to single-syllable/word conversion that already works.

## User scenarios
### Trailing lone jamo → symbol (P1)
- **Given** `가ㄱ` with the caret after `ㄱ`
- **When** ⌥⌘H
- **Then** KS X 1001 symbol candidates for `ㄱ` appear, and picking one replaces **only** `ㄱ` (leaving `가`).

### Over-capture absorbed by longest-suffix (P1)
- **Given** `나는한국` (no space) with the caret at the end
- **When** ⌥⌘H
- **Then** word candidates for `한국` (`韓國` …) appear, replacing **only** `한국`.

### Real word converts as a word (P1)
- **Given** `대한민국`
- **When** ⌥⌘H
- **Then** word candidates `大韓民國` … appear (whole run is the dictionary word).

### Non-dictionary multi-syllable → decomposition (P2)
- **Given** a multi-syllable run that is not in the dictionary
- **When** ⌥⌘H
- **Then** the per-syllable "음절별로 만들기" decomposition is offered (not a single last-syllable Hanja).

### Single syllable (regression guard)
- **Given** `가`
- **When** ⌥⌘H
- **Then** single-Hanja candidates for `가` appear (unchanged).

## Success criteria
- **SC-001**: The three reported misroutes (`가ㄱ` symbol; `나는한국` over-capture; real word → last-syllable
  single Hanja) no longer occur.
- **SC-002**: The replaced text extent equals the active token (jamo = 1 char; word = the matched suffix).
- **SC-003**: The segmenter is pure and **unit-tested** in `HanjaKitCore` (jamo split, longest-suffix match,
  decomposition fallback, single-syllable, edge cases); engine performs no network.
- **SC-004**: No regression to spec-006 capture/insert or to existing single/word conversion.

## Milestones
- **M1 — engine segmenter + integration. ✅ DONE 2026-06-22** (`2bb8636` engine + `f1c7297` wiring).
  The pure `HanjaKitCore` `Segmenter` (FR-001/002/003/004) + `WordTable.longestWordSuffix` (FR-005) +
  `AXContext.autoCaptured` + `insert(selectBack:)` token-alignment + `CandidateView` routing-by-kind + 9
  unit tests (49 green). Verified in real use (가ㄱ→ㄱ symbol; 나는한국→한국 word; 대한민국→word;
  non-dict multi→decompose; single unchanged; spec-006 path intact). App-agnostic; fixes the reported bugs.
- **M2 — native-only AX-value 어절 (deferred, low priority).** Use `kAXValue` + caret offset to find the
  true whitespace/punctuation 어절 for extent edge cases (>6 syllables, punctuation), with the ⌘C
  synth-probe as the Electron/unsupported fallback. Only if M1 proves insufficient in practice.

## Open questions
- [Resolved — Q1] Trailing lone jamo always a symbol token. **Yes.**
- [Resolved — Q2] Route by longest dictionary suffix match; decomposition fallback. **Yes.**
- [Resolved — Q3] AX-value native 어절 deferred to M2 (low priority).
- [NEEDS CLARIFICATION: greedy longest-suffix can pick a shorter embedded word — `한국대학교` (if not one
  dictionary entry) → `대학교`, replacing only that, leaving `한국`. Assumed acceptable: convert the longest
  recognizable word at the caret; re-invoke for the rest. Confirm.]
- [NEEDS CLARIFICATION: keep `maxCapture = 6`? It bounds the longest word the suffix match can find; 한자어
  are mostly 2–4 syllables, so 6 is assumed enough.]
- [NEEDS CLARIFICATION: a run that is BOTH a dictionary word AND decomposable — word path wins, with the
  decomposition affordance one step away (Tab), as today? Assumed yes.]

## Future expansion
M1 is moderate (engine + lookup + capture + routing + tests). When it starts, add `plan.md` (the segmenter
API + token model, `WordTable` suffix-lookup design, `selectBack` wiring) and `tasks.md` (build → ASQi
run-verify per app) alongside this file. M2 (AX-value 어절) gets its own section then. Not created yet.
Relates to specs 002 (multi-syllable), 005/006; `docs/BACKLOG.md` "Word vs syllable/symbol recognition is
weak" (task #13); [[macos-ax-inplace-text]].
