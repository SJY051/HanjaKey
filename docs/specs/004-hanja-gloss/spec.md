---
title: Single-Hanja 훈음 gloss overlay
status: approved     # draft -> approved -> implemented
created: 2026-06-20
owner: ASQi
tags: [data, hanja, gloss, license]
---

# Single-Hanja 훈음 gloss overlay

## Context & problem
The single-Hanja candidate popup shows each Hanja with its Korean 훈음 (訓音, e.g. `집 가`), read from
libhangul `hanja.txt` (`읽기:한자:훈음`, 28,472 entries). But **20,715 of 28,472 (73%) entries have an
empty gloss** — only the 7,757 most common characters are filled. When a user meets a rarer Hanja, no
Korean meaning is shown beside it.

This is the per-**character** gloss gap, distinct from spec 003 (which ranked/​glossed multi-syllable
한자어 **words**). Verified in 003: Unihan `kDefinition` is English, Wikidata P5537 is reading-only —
neither supplies a Korean 훈음.

Phase-1 research (2026-06-20) settled the source landscape:
- **stdict reuse — rejected.** Our bundled nikl-dict has no single Hanja (`build_dict.py` drops
  `len(reading) < 2`); the stdict source itself has only ~29 single-Hanja per ~2,300 한자어 per shard,
  and they are prose word-definitions (家 → "친족 집단을 이르던 말"), not 훈음.
- **ko.wiktionary via kaikki.org — CC BY-SA + GFDL, ~5,185 Hanja senses.** 훈음 verified, including a
  real gap char (椵 → `나무 이름 가`, empty in our `hanja.txt`). License clean (same hygiene as nikl-dict).
- **NeoMindStd/HanjaDB — MIT (maintainer-declared), ~10,262 lines, `한자=훈음` keyed by reading.** Wider
  coverage; upstream `hanjadic` GPL wrinkle absorbed by the maintainer's MIT grant.
- **myungcheol/hanja — 9,031 chars, 훈음, but NO license = all-rights-reserved.** Usable only under a
  thin-copyright judgment (char→대표훈음 is largely standard fact); not clean for a public repo.
- **rycont/hanja-grade — rejected.** 한국어문회 explicitly reserves copyright.

## Goals / non-goals
**Goals**
- Fill **empty** single-Hanja glosses in `hanja.txt` from a license-clean external 훈음 source, at build time.
- Keep the engine pure + unit-testable; **zero runtime network** (bundled data only).
- License hygiene: each external source in its own `data/<source>/` dir + `LICENSE-DATA.md`, with a
  `THIRD_PARTY_DATA.md` entry; copyleft data (CC BY-SA) kept **separate** from the MIT code, never relabeled.

**Non-goals**
- NOT filling all 20,715 empties — target high-value common~준상용 chars; accept the rare long-tail empties
  (those Hanja are almost never selected).
- NOT overriding libhangul's existing 대표훈음 (**fill-empty-only**).
- NOT adding new Hanja candidates or changing candidate **order** (libhangul's Windows-Hanja-key order
  stays). Only glosses on existing `(reading, hanja)` entries are filled.
- NOT touching the 한자어 **word** gloss/ranking (spec 003).

## Requirements
- **FR-001**: A build-time script MUST produce a gloss overlay file per source, format `읽기:한자:훈음`
  (same as `hanja.txt`), under `Sources/HanjaKitCore/Resources/data/<source>/`.
- **FR-002**: `HanjaTable` MUST gain a pure `merging(_:)` overlay that fills a gloss ONLY when the existing
  `(reading, hanja)` entry's gloss is `nil`. It MUST NOT override a non-nil gloss, change entry order, or
  add new `(reading, hanja)` pairs. (Mirror `WordTable.merging`.)
- **FR-003**: `HanjaTable.bundled()` MUST overlay the bundled source file(s) onto `hanja.txt` at load.
- **FR-004**: The primary source MUST be ko.wiktionary via kaikki.org (CC BY-SA + GFDL). Its data dir keeps
  a `LICENSE-DATA.md` (CC BY-SA 4.0 / GFDL, attribution: 위키낱말사전 / Wiktionary contributors,
  ShareAlike) and a `THIRD_PARTY_DATA.md` row; it is NOT relicensed to MIT.
- **FR-005**: Extraction MUST read only the 훈(새김) + 음 per `(reading, hanja)`; strip examples,
  etymology, and multimedia. Gloss is a single whitespace-collapsed line.
- **FR-006**: No runtime network; all data resolved at build time and bundled into Resources.
- **FR-007**: Unit tests MUST cover the fill-empty-only merge: fills a nil gloss, preserves a non-nil gloss,
  preserves entry order, and ignores `(reading, hanja)` pairs absent from the base table.
- **FR-008**: A coverage **spike** MUST report net-new fills (how many previously-EMPTY `(reading, hanja)`
  entries the source actually fills — much of a source overlaps the already-filled 7,757) BEFORE bundling,
  so we only ship a source that earns its license footprint.

## User scenarios
### Rarer Hanja now shows its meaning (P1)
- **Given** a reading whose candidates include rare chars with empty glosses (e.g. 가 → … 椵 …)
- **When** the user opens the candidate popup
- **Then** chars the source covers show their 훈음 (椵 → `나무 이름 가`), while common chars keep
  libhangul's existing 훈음 and the candidate order is unchanged.

## Success criteria
- **SC-001**: Ship the measured net-new coverage (see Spike results): ≥879 (ko.wiktionary alone) or ≥1,870
  (+ HanjaDB). Remaining empties are deferred (see Non-goals / Spike results).
- **SC-002**: Zero existing (non-nil) glosses changed; for filled readings, only the gloss field differs.
- **SC-003**: `swift test` green incl. the new merge tests; build performs no network access.
- **SC-004**: Per-source `LICENSE-DATA.md` present; `THIRD_PARTY_DATA.md` updated; CC BY-SA kept separate
  from the MIT `LICENSE`.

## Spike results (2026-06-20)
Net-new fills measured against the 20,715 empty `(reading, hanja)` entries:

| Source | License | Net-new | Extraction notes |
|---|---|---|---|
| ko.wiktionary (kaikki `한자` JSONL, 4,021 entries) | CC BY-SA | **879** | `senses[0].glosses[0]` is the 뜻 only (no 음); reconstruct 훈음 by appending the reading. No reading in the data → char-keyed, so a 多음자's secondary readings may take the first-sense 뜻 (minor). Common chars (家, 可) are absent but already filled, so no loss. |
| NeoMindStd/HanjaDB (`input/resource`, MIT) | MIT | **1,177** | `한자=한국어훈음, english (strokes)`; Korean = text before the first comma (keep only if it contains Hangul — some entries are English-only). `(reading, hanja)`-keyed (exact). Some are `X의 略字/俗字` without a reading → append the reading. |
| **Union** | — | **1,870 (9.0% of gap)** | overlap only **186** — the sources are largely **complementary** (kaikki-only 693, HanjaDB-only 991). |

The remaining ~18,845 empties have no clean Korean source — **deferred to a future subagent-swarm
investigation** (alongside the planned 빈도 큐레이팅). 9% looks small only because the denominator includes
deep long-tail variant/extension chars users almost never select.

**Decision (→ confirm):** ship M1 only (879, one CC BY-SA source) or M1+M2 (1,870, + MIT source).
Recommendation: **both** — complementary, both license-clean, small marginal cost (one extra build script +
license dir).

## Milestones
- **M1 — ko.wiktionary (CC BY-SA), primary.** Inspect one kaikki ko JSON-Lines file (find the 훈/음 fields),
  spike net-new coverage, build the overlay, add `HanjaTable.merging` + `bundled()` overlay, tests, license
  files. The clean baseline.
- **M2 — NeoMindStd/HanjaDB (MIT), wider coverage (optional).** Only if M1's net-new is insufficient and the
  MIT grant + provenance is accepted. Separate data dir + license.
- **myungcheol/hanja — deferred.** No license = all-rights-reserved; bundle only if ASQi explicitly accepts
  the thin-copyright judgment.

## Open questions
- [NEEDS CLARIFICATION: source set — start M1 (ko.wiktionary) only, then decide M2 (HanjaDB) after the spike?
  myungcheol only if the thin-copyright risk is accepted.]
- [NEEDS CLARIFICATION: SC-001 net-new target — pin down after the spike measures actual fills.]
- [NEEDS CLARIFICATION: long-tail fallback — for chars no Korean source covers, use en.wiktionary (wider but
  Korean 훈 less consistent) or Unihan English `kDefinition` (clean, but English), or leave empty? Lean: leave
  empty for now (out of scope).]
- [NEEDS CLARIFICATION: overlay delivery — keep one overlay file per source (merged in `bundled()`, licenses
  separate) rather than editing `hanja.txt` in place? Lean: yes, one file per source.]

## Future expansion
If M2+ grows (multiple sources, conflict resolution, fallback tiers): add a `plan.md` (extraction/merge HOW
per source) and `tasks.md` (DO) alongside this file. Not created yet — M1 is small enough to implement
directly from this spec.
