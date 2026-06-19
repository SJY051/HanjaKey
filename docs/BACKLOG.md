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
