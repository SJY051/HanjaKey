---
title: M2 ranking — mid-point audit & sample-check notes
status: in-progress
created: 2026-06-21
owner: ASQi
tags: [audit, sample-check, swarm, ranking]
---

# M2 ranking — mid-point audit & sample-check notes

Captured at the **261 / 352** mark (batches pilot + 1–8) during a usage-budget pause.
Re-run the audit any time with **`python3 scripts/audit_tiers.py`** (`--issues` for the full
verifier dump, `--reading 음` for one reading's tier list).

## Snapshot (261 readings, 24,441 rows)
- Tier distribution: **0 = 5.6% · 1 = 6.5% · 2 = 19.5% · 3 = 68.4%**; held (`뜻 미상`) = 16,179.
- This matches the intended shape: ~12% everyday/occasional, ~20% rare·specialist, ~68% variant/ghost.

## Systemic finding — the compile already absorbs most verifier noise
Verifiers reported **161 issues**, but kind breakdown shows most are *structural*, not judgment:
`other=55, missing=52, wrong_rank=22, wrong_tier=32`. The first three are dominated by one swarm
behavior: when a reading is **capped at the per-agent count**, the agent pads to the count with
**duplicate entries** (self-annotated "중복 방지용/재확인/이미 위에 포함") and occasionally inserts a
**wrong-reading or hallucinated** char.

`build_tiers.py` neutralizes these because it **iterates the canonical `hanja.txt` per reading and
looks up the swarm verdict** — so:
- duplicates collapse (each canonical char emitted once),
- non-canonical / hallucinated / wrong-reading / Hangul-corruption chars are **dropped** (32 integrity drops cumulative),
- canonical chars the swarm dropped **fall back to tier 3**.

→ The shipped `tiers.txt` is **structurally clean** (no duplicate rows; every row is a canonical
`(reading, hanja)`). These structural verify issues need **no action**.

## Residual issues to fix in the sample-check pass (judgment, not structure)

### A. Common chars under-tiered — RAISE tier (highest UX impact)
- **음 `飮`/`飲` → tier 0** (飮食·飮料·飮酒·過飮; currently tier 1). *Most important.*
- **탑 `搭` → tier 1** (搭乘·搭載; currently tier 2).
- **령 `靈` → tier 0/1** (영혼·유령·심령·영적; currently tier 1).
- **No-tier-0 readings** (`audit_tiers.py` head red-flag): **삽** (插/揷=삽입 should be tier 0; swarm put 颯 on top), **팽** (膨=팽창 → tier 1?), **알** (謁=알현, tier 1 is borderline-OK).

### B. Canonical chars the swarm dropped → now tier 3 (re-rank or manual add)
Verifier "missing/substitution" cases where a real candidate was displaced by a wrong char:
- **도 `屠`** (도살·도륙·부도 — moderately known; displaced by 屰=역). Notable.
- **호 `鎬`** (鎬京; displaced by 鎮=진), **복 `葍`**, **한 `閈`**, **파 `䰾`**, plus a few rarer ones.
- Most are rare; `屠` is the one worth a manual tier bump.

### C. Variants left at tier 2 that should be tier 3 (cosmetic — both live in the collapsed tail/grid)
- Examples: 련 (`聨`/`聫`/`聮`/`錬`/`脔`/`裢`/`梿`), 가 (`謌`/`斚`/`叚`), 식 `喰`, 충 `虫`, 임 `姙`, 황 `晄`, 동 `働`.
- Low priority — they're already past the top-20 cutoff. Optionally tighten the compile's variant
  rule (it keys on the gloss; these slip through when the gloss lacks 同字/略字/俗字 keywords but the
  swarm *reason* names the variant). Defer unless we want a tidier grid.

## How to action (sample-check phase, after ranking is complete)
1. `python3 scripts/audit_tiers.py --issues` → full list; the raw per-issue detail also lives in each
   `swarm-raw/*.json` `verify[]`.
2. Apply **A** (and `屠` from **B**) as targeted fixes — either a small manual-override map consumed by
   `build_tiers.py`, or a re-rank of just those readings. Decide the mechanism with ASQi.
3. Re-run `build_tiers.py` + `audit_tiers.py`; confirm the head red-flag list shrinks.
4. (Optional) tackle **C** by extending the variant rule.

Batch 5 has `verify=[]` (it hit the session limit before verify ran); its 18 readings are
structurally fine via the compile but were not verifier-scanned — re-scan them in the sample-check.
