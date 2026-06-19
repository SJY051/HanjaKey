---
title: HanjaKey — multi-syllable Hangul→Hanja (word) conversion
status: approved     # draft -> approved -> implemented
created: 2026-06-19
owner: ASQi
tags: [macos, swiftui, swift, hanja, multi-syllable, hanja-word]
---

# HanjaKey — multi-syllable Hangul→Hanja (word) conversion

## Context & problem

HanjaKey currently converts a **single Hangul syllable** to Hanja (한 → 韓 漢 …) and a single jamo to
KS X 1001 symbols. The real Korean 한자 key — and both the macOS (Option+Enter → 한자**단어** 선택기)
and Windows IMEs — also convert **whole words** (한자어): 한자 → 漢字, 대한민국 → 大韓民國. This is the
last backlog item from [001-hanja-hotkey](../001-hanja-hotkey/spec.md) (P3 "multi-syllable
conversion").

**Load-bearing finding (Phase 1, 2026-06-19):** the libhangul `hanja.txt` we already bundle for
single syllables also contains **275,020 multi-syllable 한자어 entries** (the lines we filtered out):
2글자 105.8k, 3 80k, 4 58k, 5 18.5k, 6 7.4k, up to 18. Same `음:한자:뜻` format. So a **dictionary**
approach needs no new data source. Two caveats:
- **Gloss is sparse but meaningful.** Only common/headword entries carry a gloss — e.g. 한국 → 韓國
  has gloss "대한민국" while its homophones 寒國/寒菊/汗國/限局 don't. This is the lever for ordering.
- **The multi-char range is NOT frequency-sorted** (한국 → 寒國 寒菊 韓國 …, with 韓國 third), unlike
  the single-syllable range. Putting gloss-bearing entries first fixes the common cases.

## Goals / non-goals

- **Goals:**
  - Convert a **multi-syllable Hangul word (어절)** to **whole-word Hanja candidates** via a bundled
    dictionary, reusing the existing popup/insertion flow.
  - Capture the source either from the user's **selection** or by **auto-grabbing the Hangul 어절**
    before the caret, replacing exactly that source on insert.
  - When the word isn't in the dictionary, offer a **per-syllable column fallback** to assemble a
    result manually.
  - Keep the conversion engine **pure and unit-tested**; keep single-syllable conversion and app
    startup **fast** (lazy-load the word dictionary).
- **Non-goals:**
  - A full phrase/sentence parser or morphological analysis. Scope is a single **어절** (one run of
    Hangul), not grammar-aware segmentation.
  - Perfect frequency ranking of homophone words (gloss-first is the v1 heuristic; better ranking is
    future work — see Open questions).
  - A new data source — reuse libhangul `hanja.txt`. No network, no system IME dependency.
  - Changing single-syllable behavior, the symbol tables, or the user-overlay feature.

## Requirements

### Conversion engine (pure, testable)
- **FR-001**: The engine MUST map a **multi-syllable Hangul reading** (2+ syllables) to an ordered
  list of **whole-word Hanja candidates** via exact dictionary match (`Converter.candidates(forWord:)`).
- **FR-002**: Multi-syllable candidate ordering MUST be **gloss-bearing entries first (original
  order), then gloss-less (original order)** — a stable sort. Single-syllable ordering is unchanged.
- **FR-003**: On a dictionary **miss**, the engine MUST support a **per-syllable decomposition**:
  for each syllable, the existing single-syllable candidates, so the UI can offer a column picker.
- **FR-004**: The engine MUST remain a **pure value type** (no AppKit/UI), unit-tested: word hit,
  word miss, gloss-first ordering, per-syllable decomposition, and 어절 boundary detection.
- **FR-005**: Lookups MUST be graceful for unknown/empty/over-length input (return empty, no crash).

### Data
- **FR-006**: The word dictionary MUST come from libhangul `hanja.txt`, filtered to **2–6 syllable**
  readings (7+ is ~5k entries, dropped), bundled as a **separate resource file** from the
  single-syllable table. Source/license/version documented in the Resources README.
- **FR-007**: The word dictionary MUST be **lazy-loaded** on the first multi-syllable conversion, so
  app launch and single-syllable conversion are unaffected. Parsed defensively (skip malformed rows).

### Input capture
- **FR-008**: Capture MUST be **selection-first**: if the frontmost app has a Hangul selection, use
  it. Otherwise **auto-capture the Hangul 어절 immediately before the caret** — extend the read/
  selection leftward until a non-Hangul boundary (or a sensible max length).
- **FR-009**: `selectBack` (chars re-selected before ⌘V) MUST equal the **multi-character source
  length**, so insertion replaces exactly the captured word (no leftovers, no over-deletion).
- **FR-010**: A single-syllable capture MUST still work (this feature is additive); the converter
  picks word vs syllable based on captured length.

### UI
- **FR-011**: A dictionary match MUST present **whole-word Hanja candidates** in the existing
  candidate list/grid (keyboard 1–9 / arrows / Tab, click), inserting the chosen word in place.
- **FR-012**: A dictionary miss MUST show **"후보 없음"** plus a **"음절별로 만들기"** action that
  opens a **per-syllable column view**: one column per syllable (`[한: 韓 漢 寒 …][자: 字 者 自 …]`),
  a **combined preview** at the top, and a **confirm** that inserts the assembled word.

## User scenarios

### Convert a selected word (P1, M1)
- **Given** I selected "한자" in any editable field
- **When** I press the hotkey and pick 漢字
- **Then** the selection is replaced in place with 漢字.

### Convert the 어절 before the caret (P1, M1)
- **Given** my caret is right after "대한민국" (no selection)
- **When** I press the hotkey
- **Then** HanjaKey auto-captures 대한민국 and offers 大韓民國; picking it replaces exactly those 4
  syllables.

### Common-word ordering (P1, M1)
- **Given** I convert "한국"
- **When** the candidate list appears
- **Then** 韓國 (gloss "대한민국") is near the top, ahead of rarer homophones, thanks to gloss-first
  ordering.

### Per-syllable fallback (P2, M2)
- **Given** a word not in the dictionary (e.g. a name/neologism)
- **When** I press the hotkey and choose "음절별로 만들기"
- **Then** I see one column per syllable, pick a Hanja in each, see the combined preview, and confirm
  to insert.

### Engine correctness (P1)
- **Given** the unit suite
- **When** `swift test` runs
- **Then** word hit/miss, gloss-first ordering, per-syllable decomposition, and 어절 boundary all pass.

## Success criteria
- **SC-001**: Common 한자어 (한자→漢字, 대한민국→大韓民國, 학교→學校) convert correctly from both a
  selection and an auto-captured 어절.
- **SC-002**: The chosen word replaces exactly the source (correct `selectBack`); no extra characters
  remain or are deleted.
- **SC-003**: 한국 lists 韓國 above its rarer homophones (gloss-first ordering).
- **SC-004**: App launch and single-syllable conversion show no added latency (dictionary lazy-loads
  only on first multi-syllable use).
- **SC-005 (M2)**: For a dictionary miss, the per-syllable column view assembles and inserts a word.
- **SC-006**: `swift test` passes the engine suite; no network calls.

## Milestones
- **M1 (core):** word dictionary (2–6 syllable, lazy-loaded) + `candidates(forWord:)` with gloss-first
  ordering; selection-first / 어절 auto-capture; whole-word candidates in the existing popup; correct
  multi-char `selectBack`. Built and verified first.
- **M2 (fallback):** per-syllable column view for dictionary misses (preview + confirm).

## Test plan
- **Engine (HanjaKitCore, pure):** word lookup hit (한자→漢字) and miss; gloss-first stable ordering
  (한국 → 韓國 first among glossless homophones); per-syllable decomposition returns each syllable's
  single-syllable candidates; 어절 boundary detection (Hangul run vs mixed text).
- **Data:** the filtered 2–6 syllable file parses; a few known words resolve.
- **Manual / app:** selection capture, 어절 auto-capture, in-place replace across native/Electron/
  browser; column fallback inserts an assembled word; startup/single-syllable latency unaffected.

## Open questions
- [NEEDS CLARIFICATION: better homophone-word **ranking** beyond gloss-first — e.g. a small curated
  frequency list, or weighting by the constituent syllables' single-char frequency. Deferred; v1 is
  gloss-first + original order.]
- [NEEDS CLARIFICATION: **어절 auto-capture mechanism** — synthesize repeated `Shift+←` to a non-Hangul
  boundary vs `Shift+⌥←` (word-left); how to detect the boundary when we can't read text directly in
  some apps. To be settled during M1 implementation.]
- [NEEDS CLARIFICATION: **max auto-capture length** (cap at 6 to match the dictionary? longer for
  selection?).]

## Future expansion
If this grows (phrase-level conversion, curated frequency ranking, a larger or indexed dictionary,
mixed Hangul+Hanja runs), add a `plan.md` (HOW) and `tasks.md` (DO) alongside this file. Not created
now — the engine stays decoupled (pure `HanjaKitCore`) so a better ranking or data source can drop in.
