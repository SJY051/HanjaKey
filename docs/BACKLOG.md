---
title: HanjaKey — backlog / known issues
status: living
owner: ASQi
tags: [backlog, known-issues]
---

# HanjaKey — backlog / known issues

Real but deferred items. Not part of an active spec until promoted.

## Known issues

### Multi-line auto-capture inserts on the previous line (blank lines above)
- **Reported:** 2026-06-19 (ASQi) — regression of the earlier blank-line fix.
- **Symptom:** with text like `문장… [blank line] 단어` (one or more blank lines above the target word),
  converting the word inserts the result at the END of the paragraph ABOVE (`문장…(漢字)` then the blank
  line then `단어`) instead of replacing the word. Any newline above triggers it; the number of blank
  lines doesn't matter. Manual selection works.
- **Likely area:** `AXSupport.capture` — the AX-range path (commit c84fc29) probably fails its read-back
  for this app/case and falls back to synthesized collapse + Shift+←, which crosses the blank line; or the
  AX caret location is stale across blank lines. Add logging to see which path actually runs.
- **Priority:** HIGH — wrong-location replacement corrupts text.

### Intermittent input drop (popup doesn't open / char not recognized)
- **Reported:** 2026-06-19 (ASQi).
- **Symptom:** occasionally the hotkey does nothing — the popup doesn't appear or the char isn't
  recognized — needing a second/third press or re-focusing the target. Cause unknown / not yet reproduced.
- **Likely area:** `AXSupport.capture` returning nil (AX read fails / Electron tree not ready), the ⌘C
  pasteboard poll timing out (~120ms, 24×5ms), or the hotkey event being dropped. Instrument capture() to
  find which guard fails when it happens.
- **Priority:** usability; intermittent — needs instrumentation.

### Word vs syllable/symbol recognition is weak — needs a rethink
- **Reported:** 2026-06-19 (ASQi). Supersedes the earlier standalone lone-jamo item.
- **Symptom:** the 어절 boundary is often wrong — (normal text)+(lone symbol jamo) like `가ㄱ` is read as
  one word and routed to the 한자어 path (so the KS X 1001 symbol candidates never show); a normal word's
  last syllable alone gets read as a single Hanja (single-char popup); etc. Overall recognition is poor.
- **Root cause:** the capture heuristic (`Shift+← ×maxCapture` + `trailingHangulRun`) grabs a fixed run
  and can't distinguish word vs syllable vs symbol-jamo boundaries.
- **Direction:** rethink capture/segmentation — read the real word boundary from the AX value + caret
  offset, and/or word-dictionary-aware segmentation; likely a research → spec (phase 1) effort.
- **Priority:** significant UX; design needed.

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
