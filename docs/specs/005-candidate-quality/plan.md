---
title: M2 — swarm preference tiering + gloss fill (plan)
status: implemented  # draft -> approved -> implemented
created: 2026-06-20
owner: ASQi
tags: [plan, swarm, workflow, ranking, gloss]
---

# M2 — swarm preference tiering + gloss fill (HOW)

Spec: [005-candidate-quality](spec.md) (M2). Builds the per-(reading, hanja) **preference tier + rank**
table — and fills the gloss long-tail — with an LLM swarm, bundled as **our MIT data**. M1 (rule reorder
+ top-20 cap) already shipped; M2 refines the order/cutoff and improves glosses.

## Harness
- **Dynamic multi-agent Workflow** (the deep-research engine), per
  https://code.claude.com/docs/en/workflows — a harness script built on top of it.
- **Model floor: Sonnet or Opus. Haiku 4.5 is EXCLUDED.** Korean + Hanja are training-minority; the work
  needs a guaranteed minimum language ability. Default Sonnet; Opus for the hard/verify stages.
- **Two SEPARATE pipelines** — ranking and gloss-finding must not mix (keeps each agent's job clean).

## Scope & cost control (bound the agent count)
A flat agent-per-reading fan-out (~555, ~1,100 with verify) is too many, and load is lumpy (가 = 125
candidates vs a reading with 3). So:
- **Rank only readings where the cutoff bites** — candidates > 20 (≈352 readings); prioritize > 50
  (≈210). Readings with ≤ 20 candidates already show everything, so M1's gloss-tier order stands.
- **Balanced batching:** bound candidates-per-ranking-agent to a target **T** — a big reading goes solo,
  several small readings share one agent. Agent count ≈ (total candidates in scope) / T, not per-reading.
- **Gloss search is knowledge-first; web-search only the uncertain.** Tier-3 ghosts get `뜻 미상` + the
  reading WITHOUT a search. This bounds the (expensive) web volume.

## Pipeline A — ranking / tiering
- **Input per agent:** a balanced batch of reading(s), each with its candidates:
  `{hanja, current gloss, libhangul position, FreqTable count (if any), Unihan simplified/variant flag}`.
- **Output per (reading, hanja):** a **tier** — `0 일상 / 1 가끔 / 2 희귀·전문 / 3 변이·유령·미사용` — and a
  **rank within the reading**.
- Model: Sonnet (default), Opus for readings the verifiers flag.

## Pipeline B — gloss exploration (separate)
- **Scope (decided 2026-06-20):** only **tier 0–2** gloss-less chars (the ones users actually see). tier 3
  stays `뜻 미상`; a full gloss-less sweep (~18,845) is deferred to a far-future "budget-to-burn" pass.
- **Input:** the tier 0–2 gloss-less chars (extracted AFTER ranking). Dedicated agents find the 훈독 via
  knowledge first, then web search for the uncertain.
- **Classify each:** `full 훈독 (뜻+음)` / `발음만 (reading only)` / `뜻만 (meaning only)` / `미상 (unknown)`.
- **Routing:** full 훈독 → feed back into Pipeline A (ranked by the same method). 발음만 / 뜻만 / 미상 →
  **hold**, and batch-sort to the back of their reading (after the resolved candidates).

## Verification
- **2 verifier agents scan the outputs in parallel** — catch the obvious failures: a common char demoted,
  or a wrong / hallucinated gloss. Flagged items go back for a redo (Opus) or get held.
- **Sample check: ASQi + Claude together** review pilot/full output before it is bundled as data.

## Output & integration
- Per `(reading, hanja)`: `tier, rank, gloss-or-hold-flag` → a build-time table in its own data dir, **our
  MIT data** (LLM-generated) + a `THIRD_PARTY_DATA.md` row. Any web-sourced gloss keeps its source noted.
- **Runtime:** `HanjaTable`/`Converter` order single-syllable candidates by `(tier, swarm-rank, libhangul)`;
  held/unknown sink to the back. The M1 top-20 cutoff stays. Pure + unit-tested; zero runtime network.

## Pilot (first — validate before scaling)
- Readings: **가** (125, big/solo), one medium (~33), one small (just > 20). Run A + B + verify end-to-end.
- Validate: output **schema**, **quality**, **per-agent cost**, **batch sizing (T)**, **Sonnet vs Opus**,
  and whether web-search is actually needed.
- **ASQi + Claude sample-check** the pilot → tune the knobs → scale to the in-scope (> 20) readings.

## Open knobs (the pilot tunes)
- batch target **T** (candidates/agent); Sonnet vs Opus per stage; web-search threshold; tier count (3 vs 4);
  whether to also re-rank ≤20 readings later.

## Tasks (when M2 starts in earnest, after the pilot)
- `tasks.md`: input-dump script (candidates + signals) → Workflow harness (A/B/verify) → collect → build
  the tier/gloss table → engine ordering + tests → bundle + sample-check.
