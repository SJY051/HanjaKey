---
title: HanjaKey — backlog / known issues
status: living
owner: ASQi
tags: [backlog, known-issues]
---

# HanjaKey — backlog / known issues

Real but deferred items. Not part of an active spec until promoted.

## Known issues

### Intermittent input drop (popup doesn't open / char not recognized)
- **Reported:** 2026-06-19 (ASQi).
- **Symptom:** occasionally the hotkey does nothing — the popup doesn't appear or the char isn't
  recognized — needing a second/third press or re-focusing the target. Cause unknown / not yet reproduced.
- **Likely area:** `AXSupport.capture` returning nil (AX read fails / Electron tree not ready), or one of
  the now-several ⌘C pasteboard polls timing out (~120ms each: the probe plus every shrink-verify step),
  or the hotkey event being dropped.
- **Monitoring:** a debug logger already exists — flip `CaptureLog.enabled = true` in a local build and
  watch `/tmp/hanjakey-capture.log`. A drop shows up as a nil-guard line or a `⌘C poll: TIMEOUT`.
- **Priority:** usability; intermittent — kept in monitoring mode (logging build) while ④ proceeds.

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

### Expanded-grid horizontal scroll jumps on arrow navigation
- **Reported:** 2026-06-20 (ASQi).
- **Symptom:** in the expanded single-Hanja grid (Tab), arrow-navigating a reading with many candidates
  (가, 정 …) makes the horizontal scroll lurch right on its own — some cells scroll fully out of view, and
  it snaps back near the range edges (range varies per reading). Not seen in symbols (smaller sets), but a
  large custom symbol table would likely reproduce it (same grid).
- **Likely area:** `CandidateView.wideGrid` / `squareGrid` — `proxy.scrollTo(selection, anchor: .center)`
  on every selection change over-scrolls a long horizontal grid (forced `.center` + animated scroll fights
  the layout). Pre-existing; not touched by spec 005 M1.
- **Direction:** scroll only when the target is off-screen, or scroll to the column (not the centered
  cell), or drop `.center`/animation. Verify with 가/정 + a large custom symbol set.
- **Priority:** usability — cells can become visually unreachable (selection itself still works).

## Enhancements

### Single-Hanja gloss (훈음) — DONE (spec 004), with deferred follow-ups
- **Shipped 2026-06-20** (`1efef43`, spec `004-hanja-gloss`): fill-empty-only overlay from ko.wiktionary
  (CC BY-SA, 879) + NeoMindStd/HanjaDB (MIT, 1,177); union 1,870 of 20,715 empty entries (9%).
- **Deferred — long tail:** ~18,845 empties have no clean Korean source. Revisit with a subagent-swarm
  investigation (together with the curation / frequency work below).
- **Candidate curation + re-ranking → spec 005** (`005-candidate-quality`): M1 shipped 2026-06-20
  (`4ff0e1a`) — clean→empty→variant reorder + top-20 cap (the grid shows all). M2 deferred — an LLM-swarm
  preference tier + gloss long-tail fill (incl. these ~18,845 empties; `뜻 미상` for true ghosts), with
  Unihan-based simplified detection. See the spec.

### Gloss footer: trim for 훈음-only Hanja
- **Reported:** 2026-06-20 (ASQi).
- The single-Hanja side reuses the word-side gloss footer (spec 003); its detail-expand chevron (full-gloss
  '자세히') and the long expanded-grid footer space are unnecessary when a candidate has only a short 훈음
  (no long definition). Hide/trim them for 훈음-only entries.
- **NB:** this gloss-footer detail-expand is DISTINCT from spec 005's candidate-grid `더보기` (Tab).
- **Priority:** UI polish.

## Public-release polish (planned 2026-06-21)
HanjaKey is a public repo; before calling it released:
- **Candidate curation + overall polish** — see the deferred items above (filter 유령문자/간체자/radicals,
  swarm-built frequency + 선호 re-ranking).
- **User-facing attribution (출처 표기):** surface data-source credits where users see them (README credits
  / app About), not only in `THIRD_PARTY_DATA.md` — CC BY-SA requires visible attribution. Sources:
  국립국어원 표준국어대사전 (CC BY-SA 2.0 KR), Wiktionary/위키낱말사전 (CC BY-SA), NeoMindStd/HanjaDB (MIT),
  libhangul (BSD), 국립국어원 2002 빈도조사 (KOGL 제1유형).
- **App icon**, **screenshots**, **README** polish.
