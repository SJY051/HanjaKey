---
title: Single-Hanja candidate curation & re-ranking
status: implemented  # draft -> approved -> implemented
created: 2026-06-20
owner: ASQi
tags: [candidate, curation, ranking, ux, swarm, data]
---

# Single-Hanja candidate curation & re-ranking

## Context & problem
Converting a single Hangul syllable lists **every** libhangul Hanja for that reading, in libhangul's
order, unfiltered and (for single syllables) unranked — `Converter.candidates(for:)` →
`HanjaTable.entries(for:)`. For 가 that is **125** candidates (all normal CJK: URO 105 + Ext-A 20, no
radical-block chars); across **555 readings** the median is 33 and **210 readings have >50**. The default
list pages 9 at a time (so 가 = 14 pages); Tab expands to the full grid.

The **head is already good** — 가's top ~10 are the right common chars (libhangul orders by
frequency/representativeness). The **tail is the clutter**: rare, variant (同字/略字/俗字), simplified
(간체자), and ghost characters. Gloss state across the 28,472 entries: clean-gloss 7,498 /
variant-pointer-gloss 259 / empty-gloss 20,715.

Research (phase 1, 2026-06-20) concluded: **curation and re-ranking are one problem — a good per-reading
order + a display cutoff.** There is **no clean OPEN single-Hanja frequency corpus** (모두의 말뭉치 =
login + NC-ND; 세종 unclear; our `FreqTable` is word-keyed so only partial for single chars), so a
data-driven char-frequency rank is blocked → an **LLM subagent swarm** builds the preference table, and
its output is **our data (MIT)** — sidestepping the corpus-license problem. Unihan variant fields
(`kSimplifiedVariant`/`kTraditionalVariant`/`kZVariant`, open) + the variant-pointer gloss patterns give a
cheap rule layer.

## Goals / non-goals
**Goals**
- Declutter the single-syllable candidate list: show a curated, well-ordered **head**; keep the rest one
  affordance away.
- Demote rare/variant/simplified/ghost chars; surface common, usable ones first.
- Pure, testable ordering in `HanjaKitCore`; build-time data only; zero runtime network.

**Non-goals**
- **Never DROP a candidate.** Everything stays reachable via the expanded grid (someone may need to input
  even a ghost/variant char).
- Not re-ranking multi-syllable **word** candidates (already corpus-ranked, spec 003).
- Not the gloss-FOOTER UI polish for 훈음-only chars (separate task; that footer's `더보기` ≠ this
  spec's candidate-grid `더보기`).
- Not licensing a closed/NC corpus (모두의 말뭉치 etc.).

## Requirements
- **FR-001**: The single-syllable candidate ORDER MUST place common/usable Hanja first and demote
  variant / simplified / rare ones to the tail. The full set is preserved (reordered, never reduced).
- **FR-002 (v1, rule layer)**: A Hanja whose gloss is a **variant pointer** (同字/略字/俗字/本字/古字 …)
  OR which Unihan marks as **simplified** (has `kTraditionalVariant`) MUST sort after non-variant
  candidates. Rule-derivable from data we have/can download — no swarm.
- **FR-003 (v1, UX)**: The default paged list MUST show only the top **N = 20** "visible" candidates; the
  **full set MUST remain reachable via the expanded grid** (`더보기`/`전체`). Nothing is removed.
- **FR-004**: The cutoff applies to **single-syllable** readings only; multi-syllable word candidates are
  untouched.
- **FR-005**: Ordering + cutoff logic MUST live in `HanjaKitCore` (`HanjaTable`/`Converter`), pure +
  unit-testable; only the list-cap + grid reveal live in `CandidateView`.
- **FR-006 (v2, swarm)**: A build-time **per-(reading, hanja) preference tier/rank table**, produced by an
  LLM subagent swarm, MUST be bundleable as **our own (MIT) data** in its own dir; the engine orders by
  `(tier, rank, libhangul order)`. Zero runtime network.
- **FR-007 (v2, gloss quality)**: The swarm pass SHOULD improve glosses — prefer a real 훈음 over a
  variant pointer; a ghost/unknown char → **`뜻 미상` + the reading only**. Unifies with spec 004's
  deferred gloss long-tail (~18,845 empties).
- **FR-008 (v2, safety)**: An adversarial-verify pass MUST guard against demoting a legitimately-used char
  (a wrong demotion only hides it below the cutoff — still reachable — but should still be caught).
- **FR-009**: License hygiene per specs 003/004 — any external signal (Unihan) in its own data dir + a
  `THIRD_PARTY_DATA.md` row; the swarm output is our MIT data (LLM-generated rankings, not a scraped corpus).

## User scenarios
### Common reading declutters (P1)
- **Given** 가 (125 candidates)
- **When** the popup opens
- **Then** the default list shows ~20 common/usable Hanja (variant/simplified/rare demoted), and Tab
  (`더보기`) opens the grid with all 125.

### A rare char is still reachable (P1)
- **Given** a rare char (e.g. 椵) that's below the cutoff
- **When** the user opens the grid (`더보기`)
- **Then** 椵 is present — nothing was dropped.

### A variant is demoted (P2)
- **Given** 价 (simplified of 價) and 仮 (略字 of 假)
- **When** the list renders
- **Then** they appear after the clean common chars (in the tail / grid), not near the top.

## Success criteria
- **SC-001**: For high-count readings, the default list is ≤ 20 candidates; the full set is reachable in
  the grid.
- **SC-002**: Reachable candidate count per reading is unchanged vs today (nothing removed).
- **SC-003 (v2)**: For a sample of common readings, the visible top-20 contains no variant-pointer /
  simplified char ahead of a clean common one.
- **SC-004**: Engine stays pure; unit tests cover ordering, rule-demote, and the cutoff; build performs no
  network.

## Milestones
- **M1 (v1) — rule + UX, no swarm/data.** Reorder via the rule layer (FR-002), cap the list at 20
  (FR-003), grid reveals all. Engine + tests + the `CandidateView` cap. Immediate declutter, zero
  license/data risk.
- **M2 (v2) — swarm preference table.** Per-reading tier/rank built by the swarm (FR-006), bundled as MIT
  data, refining M1's order/cutoff; same pass improves glosses (FR-007) and can absorb the 004 long-tail;
  adversarial-verify (FR-008). Larger — gets its own `plan.md` (swarm harness) + `tasks.md` when started.

## Open questions
- [NEEDS CLARIFICATION: v1 cutoff = 20 for now — tune later? And exactly how it meshes with the existing
  9-per-page list + compact/wide grid toggle (does the grid always show ALL, or page beyond 20?).]
- [NEEDS CLARIFICATION: v2 swarm granularity — judge per reading (rank the whole candidate set at once) or
  per (reading, hanja)? Verification depth (single judge vs majority)? Fold the 004 gloss long-tail into
  the same pass, or keep gloss-fill separate?]
- [NEEDS CLARIFICATION: tier model — how many tiers (e.g. common / rare / variant-or-unused), and how the
  v1 rule-demote and the v2 swarm-tier combine when both exist.]
- [NEEDS CLARIFICATION: does the cutoff also apply inside the per-syllable column fallback (decomposition),
  or only the single-syllable popup?]

## Future expansion
M2 (the swarm) is the large piece: when it starts, add a `plan.md` (swarm harness — fan-out per reading,
input signals, schema, verify) and `tasks.md` (build + integrate the tier table) alongside this file. M1
is small enough to implement directly from this spec.
