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

## ② Gloss pass — IN PROGRESS (720 / 2,859 pairs done)
Scope: empty-gloss pairs that are user-visible = ranked tier 0–2 **+ all unranked readings** (ranked tier 3
stays `뜻 미상`). Per (reading, hanja) — 다음자. Output is OUR MIT data (short generated 훈음, not scraped).

**Pipeline (resumable, done-excluded, self-healing — a dropped/quota-lost pair just reappears next dump):**
1. `python3 scripts/build_gloss_input.py` → grouped `{읽기:"한자들"}` JSON of the remaining pairs.
2. `Workflow({scriptPath: "docs/specs/005-candidate-quality/gloss-harness.js", args: <pasted JSON>})` —
   Sonnet batches (90/agent) + 1 Opus verify. status = full / 미상 / wrong_reading.
3. `cp /private/tmp/.../tasks/<taskid>.output docs/specs/005-candidate-quality/swarm-raw/gloss-<N>.json`
4. `python3 scripts/build_gloss_compile.py` (→ overlay `hanja-gloss-swarm/hanja_gloss.txt`, reports
   wrong_reading) → `python3 scripts/build_tiers.py` (recompile) → `swift test`.
5. Repeat until `pairs=0`.

**Progress:** gloss-1.json = 720 done (423 full + 292 미상 + 5 wrong_reading). **Remaining 2,139** (t2 1,421 +
unranked 693 + t0-1 25). Quota hit mid-run (only ~8 of 32 agents ran — the window was already mostly spent);
**resumes after the 9:30pm KST reset** — a fresh window should finish the rest in one pass.

**After ② done:** review accumulated `wrong_reading` (build_gloss_compile reports them; e.g. 교 酵, 동 諌,
돈 褪) → add demotions to `tier-overrides.txt` → recompile → rebuild `.app`. 미상 pairs stay empty by design.
NB: `build_tiers.py` must SKIP `gloss-*.json` (they feed only the overlay, never the ranking) — already handled.

## Engine integration — ✅ DONE (2026-06-21)
- New **`TierTable`** (`Sources/HanjaKitCore/TierTable.swift`) loads `tiers.txt` → `reading → (hanja →
  position)` (file order = (tier, rank)). `Converter.curate(_:for:)` orders the single-syllable list by
  it when the reading is ranked, else falls back to the renamed rule `Converter.curateByRule` (≤20-cand
  readings). `Converter.bundled()` + the app (`CandidateView`) wire `TierTable.bundled()` in. M1 top-20
  cutoff + grid unchanged.
- **Deviation from the original plan (intentional):** did NOT reorder `HanjaTable` itself. Its libhangul
  order backs `HanjaTable.rank(of:for:)`, which the multi-syllable **word scorer** depends on — reordering
  it would silently change word ranking. A separate `TierTable` keeps display order and frequency rank
  decoupled. All 40 unit tests green (incl. new `TierTableTests` + tiers/fallback `Converter` tests).

## Gotchas
- Workflow `args` may arrive as a STRING → the harness `JSON.parse`s defensively.
- Batch ~25–40 readings (verify-prompt size). `--cap 160` keeps the args paste small + bounds rank output.
- The compile drops invalid swarm hanja (merged "A/B", wrong char) and falls back missing → tier 3.
- Push is deferred until M2 done (ASQi); commit locally for durability.
