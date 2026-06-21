---
title: M2 ranking — mid-point audit & sample-check notes
status: in-progress
created: 2026-06-21
owner: ASQi
tags: [audit, sample-check, swarm, ranking]
---

# M2 ranking — mid-point audit & sample-check notes

First captured at the 261 / 352 mark; **refreshed at ranking completion (352 / 352, 2026-06-21).**
Re-run the audit any time with **`python3 scripts/audit_tiers.py`** (`--issues` for the full
verifier dump, `--reading 음` for one reading's tier list).

## Snapshot (352 readings, 26,988 rows — ranking COMPLETE)
- Tier distribution: **0 = 5.8% · 1 = 6.5% · 2 = 19.6% · 3 = 68.2%**; held (`뜻 미상`) = 17,873.
- This matches the intended shape: ~12% everyday/occasional, ~20% rare·specialist, ~68% variant/ghost.

## ① sample-check — APPLIED 2026-06-21
Manual tier overrides in `tier-overrides.txt` (consumed by `build_tiers.py` after the variant rule, override =
final say). **9 fixes:** raise 음 `飮`→0, 령 `靈`→0, 삽 `插`→0, 팽 `膨`→0, 탑 `搭`→1, 도 `屠`→1 (was a dropped
fallback → moved to its new tier's head); demote 충 `虫`→3, 식 `喰`→3, 동 `働`→3. No-tier-0 readings **10→8**
(remaining 8 = 알 랄 랍 멱 얼 올 훤 흘 — genuinely rare, no everyday hanja, correct as-is). 40 tests green.
**Still open (later passes):** (a) 삽 `插` still carries the gloss text "揷의 略字" — its *tier* is fixed, the
*text* is the ② gloss pass's job. (b) Other un-demoted variants beyond 충/식/동 (verify `wrong_tier`=49) —
catch as stragglers; if systematic, extend the compile's variant regex to the Korean markers (약자/속자),
carefully (avoid 동자 ↔ 童子). (c) tail policy left as-is (`뜻 미상` already sorts last via the `hold` key).

## Systemic finding — the compile already absorbs most verifier noise
Verifiers reported **187 issues** (final), but kind breakdown shows most are *structural*, not judgment:
`other=59, missing=54, wrong_rank=25, wrong_tier=49`. The first three are dominated by one swarm
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
- **No-tier-0 readings** (10 total, `audit_tiers.py` head red-flag): 삽 팽 알 랄 랍 멱 얼 올 훤 흘. Most are
  genuinely rare readings with no everyday hanja (a tier-1 head is correct). **Real fixes:** **삽** (插/揷=삽입 → tier 0;
  swarm put 颯 on top), **팽** (膨=팽창 → tier 1, maybe 0). The other 8 are acceptable as-is.

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

## Tail ordering policy (decide in the sample-check) — from the 2026-06-21 run-check
- M2 replaces M1's "variants strictly last" rule with a pure **(tier, swarm-rank)** order. So within tier 3,
  variant forms (同字/略字/俗字) are interleaved with rare/ghost chars by rank — NOT isolated at the very end;
  the absolute tail is the `뜻 미상` ghosts. (Run-check on 가: 椵 = tier 2 @ pos 44 leads the tier-3 variants
  @ 63–68; `뜻 미상` ghosts fill 114–125.)
- **The gloss pass (②) will NOT reorder this** — it only fills tier 0–2 meanings; tier 3 stays `뜻 미상`,
  same positions. So a tidier tail is a *separate* decision from gloss.
- If we want a tidier tail (e.g. push `뜻 미상` ghosts strictly last, or variants behind gloss-bearing rares),
  add a secondary sort key in `build_tiers.py` — cheap, deterministic, no re-rank needed.
