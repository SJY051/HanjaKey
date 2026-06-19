---
title: HanjaKey — backlog / known issues
status: living
owner: ASQi
tags: [backlog, known-issues]
---

# HanjaKey — backlog / known issues

Real but deferred items. Not part of an active spec until promoted.

## Known issues

### Lone jamo after a syllable swallows the symbol path
- **Reported:** 2026-06-19 (ASQi), confirmed in real use.
- **Symptom:** when a completed Hangul syllable is immediately followed by a lone jamo — e.g. `가ㄱ`,
  `안ㅎ` — and the caret sits right after the jamo, pressing the hotkey makes 어절 capture treat `가ㄱ`
  as a single 2-character word and route it down the multi-syllable 한자어 path, so the KS X 1001
  **symbol** candidates that should appear for the jamo never show.
- **Likely cause:** 어절 capture (the trailing-Hangul-run logic in `Sources/HanjaKey/AXSupport.swift`)
  groups the completed syllable and the trailing lone jamo into one run, so `CandidateView` enters its
  `reading.count >= 2` word branch instead of the single-jamo symbol branch.
- **Expected:** using the feature right after a lone jamo (single consonant/vowel) should trigger the
  **symbol conversion only** — classify the trailing jamo as standalone.
- **Fix direction:** in capture/classification, if the trailing character is a lone jamo, capture only
  that jamo and send it down the symbol (jamo → KS X 1001) path — likely in
  `AXSupport.trailingHangulRun` or the `CandidateView` branch (split a trailing jamo off the run).
- **Priority:** affects usability, not urgent — fix later.

## Enhancements

### Single-Hanja gloss (훈음) coverage from a license-clean Hanja dictionary
- **Reported:** 2026-06-19 (ASQi).
- **Gap:** libhangul `hanja.txt` leaves the gloss (훈음/뜻) empty for many single Hanja (especially
  rarer characters), so the candidate list shows a Hanja with no Korean meaning beside it. Word ranking
  (spec 003) does not address this — it is the per-CHARACTER gloss that is missing.
- **Why the 003 sources don't solve it:** Unihan `kDefinition` is Chinese-based English (not a Korean
  훈음); Wikidata P5537 is reading-only. Neither supplies a Korean gloss (verified in 003 research).
- **Idea:** find a license-clean Korean Hanja dictionary / 자전 (CC BY-SA, KOGL, or similar) carrying
  훈음 and fill the missing single-Hanja glosses. Keep its license separate (own data dir +
  `THIRD_PARTY_DATA.md`), same hygiene as the nikl-freq / nikl-dict data.
- **Priority:** nice-to-have; improves the single-syllable candidate UX.

### Long gloss truncation — tooltip / auto-scroll
- **Reported:** 2026-06-19 (ASQi).
- **Context:** stdict definitions are capped at 50 chars (003 M2), so longer glosses are truncated in the
  candidate row (e.g. 漢字's definition shows but is cut off). Meaning is still readable.
- **Idea:** show the full definition on hover (tooltip), or auto-scroll/marquee the gloss of the selected
  candidate, so the full text is accessible without permanently widening the row.
- **Priority:** UX nice-to-have.
