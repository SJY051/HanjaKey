---
title: M2 candidate-ranking swarm — runbook & progress
status: in-progress
created: 2026-06-20
owner: ASQi
---

# M2 runbook & progress (spec 005)

Resume the ranking-swarm grind from here (survives compaction).

## Progress
- **Ranking: ✅ COMPLETE — 352 / 352 readings** (every >20-candidate reading). pilot + batch1–11.
- **Remaining ranking: 0.** Next M2 phases: sample-check → gloss pass → engine integration (see below).
- Raw swarm outputs persisted: `swarm-raw/pilot.json` + `rank-batch1.json` … `rank-batch11.json` (batch5 = partial 18, verify=0).
- Compiled table: `Sources/HanjaKitCore/Resources/data/curation-swarm/tiers.txt` (352 readings, 26,988 rows).
- Quality: top tiers are correct common chars; 간체/이체/유령 → tier 3; integrity 33 dropped cumulative (~0.12%).
- **Sample-check TODO (after ranking):** mid-point audit → see [`sample-check-notes.md`](sample-check-notes.md). Re-audit any time with `python3 scripts/audit_tiers.py` (`--issues` for the full verifier dump). The compile already absorbs the structural verifier noise (duplicate padding, wrong-reading, corruption); the residual *judgment* fixes (under-tiered 음 `飮`→0, 탑 `搭`→1, 령 `靈`; no-tier-0 삽/팽/알/랄/훤; dropped 도 `屠`) are catalogued in that note.

### Batch 5 session-limit interruption — RESOLVED
- Batch 5 hit the session usage limit; 18 readings completed (saved to `rank-batch5.json`), 22 failed.
- The 22 leftovers (형 석 탁 필 록 각 권 성 격 궤 운 변 롱 철 삼 악 척 패 건 등 암 재) were auto-included in batch 6 and are now ranked. No outstanding pending readings.
- Lesson: on a session-limit mid-run, the harness still returns the COMPLETED agents' `combined`; save it as the batch file, commit, and the failed readings auto-flow into the next dump. No work lost.

## Run the next ranking batch — ✅ DONE (all 352 readings ranked, 2026-06-21)
(Process kept for reference / re-runs.)
1. **Dump args** (auto-excludes done): `python3 scripts/build_swarm_input.py --count 40` → copy the stdout JSON.
2. **Launch** (reuse the harness — rank Sonnet + 2 Opus verify, balanced agents; model floor Sonnet/Opus, **no Haiku**):
   `Workflow({ scriptPath: "docs/specs/005-candidate-quality/rank-harness.js", args: <pasted JSON> })`
   (The harness is also persisted under the session's `workflows/scripts/hanja-rank-batch-*.js`; the repo
   copy `rank-harness.js` is the durable one. Do NOT pass `resumeFromRunId` — each batch is a fresh run.)
3. **On completion**: `cp /private/tmp/claude-501/-Users-asqi/<session>/tasks/<taskid>.output swarm-raw/rank-batch<N>.json`
4. **Compile** (cumulative, integrity-hardened): `python3 scripts/build_tiers.py` — check the `[integrity]`
   line + sample readings. Spot-check every 2–3 batches.
5. Repeat until `remaining_after=0`.

## After ranking — gloss workflow (separate)
- Scope (decided): **tier 0–2 gloss-less only**; tier 3 stays `뜻 미상`; full sweep deferred ("budget-to-burn").
- Build a SEPARATE gloss harness (Sonnet, knowledge→web), classify `full / 발음만 / 뜻만 / 미상`; hold the
  non-full to the back. Save to `swarm-raw/gloss-*.json` → `build_tiers.py` merges (it already prefers a
  found full 훈독 over `뜻 미상`).

## Engine integration (after the data is complete)
- `HanjaTable`/`Converter` single-syllable path orders by `tiers.txt` `(tier, file order)`; M1 cutoff (20)
  + grid stays; held/`뜻 미상` sink to the back. Keep pure + unit-tested. Add a `tiers.txt` loader to
  `HanjaTable.bundled()` (like the 004 overlays) and order in `Converter.curate` (or replace it).

## Gotchas
- Workflow `args` may arrive as a STRING → the harness `JSON.parse`s defensively.
- Batch ~25–40 readings (verify-prompt size). `--cap 160` keeps the args paste small + bounds rank output.
- The compile drops invalid swarm hanja (merged "A/B", wrong char) and falls back missing → tier 3.
- Push is deferred until M2 done (ASQi); commit locally for durability.
