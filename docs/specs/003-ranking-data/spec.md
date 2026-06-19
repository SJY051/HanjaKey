---
title: HanjaKey — homophone-word ranking via usage frequency
status: approved     # draft -> approved -> implemented
created: 2026-06-19
owner: ASQi
tags: [macos, swift, hanja, ranking, frequency, data, license]
---

# HanjaKey — homophone-word ranking via usage frequency

## Context & problem

[002-multi-syllable](../002-multi-syllable/spec.md) shipped whole-word 한자어 conversion with a
**gloss-first heuristic** for ordering homophone candidates, and explicitly left "better homophone-word
ranking" as its open question (002 §Open questions). The heuristic is weak: gloss covers only ~1.9% of
word entries, so for most readings the order is near-arbitrary, and it gets common words wrong —
verified misranks include 수도→水道 (should be 首都), 전기→前記 (should be 電氣), 의사→義士 (should be
醫師), 사고→四苦 (should be 事故), plus 회사/사기/감사. Only 學校/大學/韓國 happen to come out right.

**Load-bearing finding (Phase 1 deep-research, 2026-06-19, 13-agent verification workflow):** a cleanly
**redistributable, commercial-OK per-sense 한자어 frequency dataset exists** — the 국립국어원 현대 국어
사용 빈도 조사 (2002) result text files, under **KOGL 제1유형 (출처표시)**, key-free download. It gives,
per Hangul surface form, a **separate frequency per Hanja spelling** (verified by downloading + parsing
the actual file): 정당 政黨=161 / 正當=1; 수도 首都=136 / 修道=7 / 水道=4 / 囚徒=1; 전기 電氣=121 /
前期=73 / 傳記=22; 의사 醫師=179 / 意思=97 / 義士=8; 사고 事故=316 / 思考=113. 58,437 word rows, ~70%
Hanja-tagged, **1,996 surface forms with ≥2 distinct Hanja**, each with its own count + a 9-domain
register breakdown. This refutes the prior assumption (memory `hanjakey-ranking-data.md` line 27) that
no such redistributable dataset existed, and is the lever this spec uses to fix ranking.

This spec is the **engineering** workstream. A separate **data-labelling / curation** workstream (for
the long tail the 2002 corpus misses) is split out — see Non-goals and Future expansion.

### Data decisions (from the Phase-1 workflow; full table in the research write-up)

- **Primary ranking signal — 국립국어원 2002 빈도조사** (KOGL 제1유형, key-free). Per-sense frequency.
- **Inventory stays libhangul `hanja_words.txt`** (BSD, already bundled, 235k entries). The frequency
  table is a *ranking signal layered on top*, not a replacement — it must not shrink the candidate set.
- **국립국어원 사전** (표준국어대사전 + 우리말샘, CC BY-SA 2.0 KR, key-free `korean-dict-nikl` mirror)
  is an **inventory-augmentation + Hanja-spelling cross-check layer (M2)**, not the v1 primary source.
- **Excluded:** `wordfreq` (surface-form only — can't split 政黨 vs 正當, both return 0.0; needs a
  native MeCab runtime dep) and **Wikidata P5537** (single-character only, overlaps libhangul). Both
  were license-clean but the *wrong granularity*.
- **Unihan kHangul** = single-syllable / OOV fallback only (largely redundant with libhangul; deferred).
- **Wiktionary / Kaikki** (CC BY-SA 4.0) = optional **build-time** Hanja-spelling cross-check, not a
  runtime layer.
- **libhangul compliance:** the current public release's "BSD" label is **correct** (the data file
  carries a per-file BSD 3-Clause header that overrides the repo's LGPL-2.1 default). No urgent action.

## Goals / non-goals

- **Goals:**
  - Order homophone **한자어 candidates by real usage frequency** from the 2002 빈도조사, fixing the
    documented misranks (수도/전기/의사/사고/정당 …).
  - **Graceful fallback:** surface forms absent from the frequency data keep the current 002 ordering —
    **no regression**.
  - Process external data **at build time** (a script produces a bundled resource); **zero runtime
    network**. Frequency table **lazy-loaded** like the word dictionary.
  - Keep the conversion engine **pure and unit-tested**; the frequency table is injected, not global.
  - **License hygiene:** keep each data source in its own dir under its own license + a
    `THIRD_PARTY_DATA.md`; never relabel CC BY-SA / KOGL data as MIT.
- **Non-goals:**
  - **Context / meaning-based disambiguation** (matching sentence context to gloss / pos / domain at
    runtime) — future work; v1 ranks by corpus frequency only.
  - **Data-labelling / curation** for the long tail (rare senses, post-2002 neologisms, native/loan
    rows with no Hanja) — a **separate spec** (proposed 004), now a *thin fallback* rather than the
    main path (the 2002 data does the heavy lifting).
  - Integrating `wordfreq` or Wikidata (excluded above).
  - **9-domain register weighting** — v1 uses total frequency; domain weighting is future.
  - Replacing libhangul as the inventory — 국어원 사전 only *augments* it (M2).
  - Changing single-syllable conversion, symbol tables, the user overlay, or the popup/insertion flow.

## Requirements

### Data & build (build-time, reproducible)
- **FR-001**: A build script (under `scripts/`) MUST parse the 2002 빈도조사 result file into a
  `reading → [(hanja, frequency)]` table and emit a **bundled resource**. It MUST decode the source
  **EUC-KR** correctly and **skip rows without a Hanja spelling** (native/loan words) and malformed rows.
- **FR-002**: The frequency data MUST live in its **own resource dir** (e.g.
  `Sources/HanjaKitCore/Resources/data/nikl-freq/`) carrying the **KOGL 제1유형** attribution. A
  repo-root `THIRD_PARTY_DATA.md` MUST record, per source: origin URL + official policy page, the
  **version / retrieval date**, the license + deed link, and **what transformations were applied**.
  The merged/derived data MUST NOT be relabeled MIT.
- **FR-003**: The build MUST be **reproducible** — pin the source version/URL and document the output
  format. (No network at app runtime; the script runs offline during development/build.)

### Engine (pure, testable)
- **FR-004**: A new **pure value type** (e.g. `FreqTable`) MUST expose `reading → {hanja: frequency}`
  and be **lazy-loaded** on first multi-syllable use (no AppKit, no app-launch cost).
- **FR-005**: `Converter.candidates(forWord:)` MUST, when the frequency table **contains** the reading,
  order candidates by **descending frequency**; Hanja with no frequency entry (and ties) fall back to
  the **current 002 ordering** (gloss-first, then summed single-syllable frequency, then source order),
  placed after the frequency-ranked ones. When the reading is **absent**, behavior MUST be **identical
  to 002** (no regression).
- **FR-006**: The frequency table MUST act as a **ranking signal only** — it MUST NOT remove candidates.
  Every libhangul inventory candidate for a reading still appears (frequency just reorders them).
- **FR-007**: The engine MUST remain a **pure, unit-tested value type**: frequency ordering for known
  readings, fallback for unknown readings, ties, and empty/over-length input (graceful, no crash).

### Behavior (unchanged invariants)
- **FR-008**: The **no-silent-replace** rule from 002 holds — HanjaKey always shows the candidate list;
  frequency ranking only changes which candidate is the **default / top**, never auto-commits. (Met by
  the existing UI; this spec adds no new UI.)

### Inventory augmentation (M2)
- **FR-009 (M2)**: A build step MUST extract standard 한자어 (Hangul headword → Hanja 원어) from the
  국립국어원 dictionaries (stdict + 우리말샘 via the key-free `korean-dict-nikl` mirror) to **augment**
  the libhangul inventory (add standard headwords it lacks) and **cross-check** the 2002 Hanja spellings.
  Example `<source>` sentences and all multimedia MUST be stripped; the derived dictionary data MUST be
  shipped under **CC BY-SA 2.0 KR** in its own dir with attribution to 국립국어원 — not folded into MIT.

## User scenarios

### Correct homophone ranking (P1, M1)
- **Given** I convert "수도"
- **When** the candidate list appears
- **Then** **首都** is the top/default candidate (freq 136), ahead of 修道/水道/囚徒.
  (Same for 전기→電氣, 의사→醫師, 사고→事故, 정당→政黨.)

### No regression for unknown readings (P1, M1)
- **Given** a 한자어 not present in the 2002 frequency data
- **When** I convert it
- **Then** the ordering is exactly what 002 produced (gloss-first), with no error.

### Engine correctness (P1, M1)
- **Given** the unit suite
- **When** `swift test` runs
- **Then** frequency ordering, unknown-reading fallback, ties, and graceful empty input all pass.

### Inventory augmentation (P2, M2)
- **Given** a standard 한자어 present in 국어원 사전 but missing from libhangul
- **When** I convert its reading
- **Then** it appears as a candidate (inventory augmented), Hanja spelling cross-checked.

## Success criteria
- **SC-001**: The documented misranks the 2002 data covers (수도→首都, 전기→電氣, 의사→醫師,
  사고→事故, 정당→政黨) come out **top-ranked**. (감사→監査>感謝 is a known register artifact — see
  Open questions.)
- **SC-002**: Readings **absent** from the frequency data are ordered **identically to 002** (verified
  regression case, e.g. 한국→韓國 still first).
- **SC-003**: License separation holds — `THIRD_PARTY_DATA.md` exists and each data dir states its own
  license (libhangul BSD / nikl-freq KOGL / nikl-dict CC BY-SA); nothing CC/KOGL is relabeled MIT.
- **SC-004**: `swift test` is green; **zero runtime network**; app launch and single-syllable latency
  unchanged (frequency table lazy-loads on first multi-syllable use).
- **SC-005 (M2)**: A standard 한자어 present only in 국어원 사전 converts (inventory augmented).

## Milestones
- **M1 (frequency ranking):** build script parses the 2002 빈도조사 → bundled `reading→{hanja:freq}`
  resource; `FreqTable` (pure, lazy) + `Converter.candidates(forWord:)` frequency ordering with 002
  fallback; unit tests; license dir + `THIRD_PARTY_DATA.md`. **This alone fixes the documented misranks.**
- **M2 (inventory augmentation):** extract 국어원 사전 한자어 to augment the libhangul inventory +
  cross-check Hanja spellings (CC BY-SA 2.0 KR, carve-outs stripped).
- **Separate / future:** curation long-tail (proposed spec 004); 9-domain register weighting; context/
  meaning disambiguation; Unihan single-syllable fallback.

## Test plan
- **Engine (HanjaKitCore, pure):** frequency ordering for known readings (수도→首都, 전기→電氣,
  의사→醫師, 사고→事故, 정당→政黨); unknown-reading fallback == 002 order; tie handling; empty/
  over-length graceful.
- **Data:** the build output parses; known surface forms carry the expected per-Hanja frequencies;
  EUC-KR decoding verified on a few rows.
- **Regression:** 002 scenarios (한국→韓國 first; selection / 어절 capture / in-place replace) unchanged.
- **Manual / app:** real conversion shows the frequency-correct candidate as default; no added latency.

## Open questions (resolved 2026-06-19)
- **Resolved — milestone split:** **M1 = 2002 frequency layer on top of the libhangul inventory**;
  국어원 사전 introduction deferred to **M2**. (Frequency, not inventory, fixes the misranks; libhangul
  inventory already works and is BSD-simple, so the 국어원 사전's CC BY-SA + carve-out complexity is
  isolated in M2.)
- **Resolved — register weighting:** v1 uses **total** frequency; the 9-domain (신문/문학/구어 …)
  register weighting is **future** (total-first already fixes the documented cases).
- **Resolved — written-register artifacts:** ship the 2002 corpus order **as-is** (a probabilistic
  prior; the user still picks from the candidate list). **No** hand-tuned override table in M1 — that
  would overlap the curation workstream. So e.g. 감사 → 監査 > 感謝 is accepted for v1.
- **Resolved — curation split:** the long-tail data-labelling / curation work is a **separate spec
  (proposed 004)**, not part of 003.
- **Deferred — 2005/2015 blend:** decide whether to blend the 2005 follow-up (빈도 조사 2) / 2015
  refresh after evaluating those files; **M1 uses 2002 alone**.

## Future expansion
If M1 grows beyond a single change (curation pipeline, register weighting, context/meaning
disambiguation, full 국어원-사전 inventory, an indexed/compressed frequency store), add a `plan.md` (HOW)
and `tasks.md` (DO) alongside this file — not created now. The engine stays decoupled (pure
`HanjaKitCore`) so the frequency table and any future ranking layer drop in behind
`Converter.candidates(forWord:)` without touching the app/UI layer. The curation long-tail is tracked
as a **separate spec (proposed 004)**.
