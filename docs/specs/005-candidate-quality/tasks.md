---
title: M2 candidate-ranking swarm — runbook & progress
status: in-progress
created: 2026-06-20
owner: ASQi
---

# M2 runbook & progress (spec 005)

Resume the ranking-swarm grind from here (survives compaction).

## Progress
- **Ranking: 43 / 352 readings done** (the >20-candidate readings). = pilot (가·갑·난) + batch1 (15) + batch2 (25).
- **Remaining: 269 readings.** Then the gloss workflow.
- Raw swarm outputs persisted: `swarm-raw/pilot.json`, `rank-batch1.json`, `rank-batch2.json`.
- Compiled table: `Sources/HanjaKitCore/Resources/data/curation-swarm/tiers.txt` (43 readings, ~8.3k rows).
- Quality: top tiers are correct common chars; 간체/이체/유령 → tier 3; integrity ~0.3%/batch dropped+fallback.

## Run the next ranking batch
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
