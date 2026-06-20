#!/usr/bin/env python3
"""Compile swarm raw outputs (spec 005 M2) into the bundled tier/gloss table.

Iterates the CANONICAL libhangul candidate set (hanja.txt) per processed reading and looks up the swarm
result, so the table is robust to swarm glitches:
  - a swarm `hanja` that isn't a single char in the reading's canonical set (e.g. a merged "驹/駒") is
    DROPPED as invalid;
  - duplicate swarm entries collapse (last wins);
  - any canonical char the swarm didn't rank (the >cap tail, or an agent drop) FALLS BACK to tier 3,
    unranked (kept after the ranked ones, in libhangul order) — never lost.
Then per (reading, hanja):
  - tier/rank from the swarm (or the fallback),
  - gloss = the libhangul/004 대표훈음 if present, else a swarm-found full 훈독, else `뜻 미상` (held),
  - VARIANT HARD-RULE: a swarm reason or current gloss marking a variant (同字/略字/俗字/古字/簡體/간체/
    이체자/신자체…) forces tier 3 (catches what the ranker left high, e.g. 謌·斚),
  - HOLD: gloss-less chars (reading_only / meaning_only / unknown / unranked) sort to the back.
Per reading, rows are emitted in display order `(hold, tier, rank)`.

Output: Sources/HanjaKitCore/Resources/data/curation-swarm/tiers.txt — `읽기:한자:티어:글로스`, file-ordered.
OUR data (MIT, LLM-generated rankings). Re-runnable; the swarm is never re-run. Only PROCESSED readings
are emitted; the rest keep libhangul order at runtime.

Run:  python3 scripts/build_tiers.py
"""

from __future__ import annotations

import glob
import json
import re
from collections import defaultdict
from pathlib import Path

HANJA = "Sources/HanjaKitCore/Resources/hanja.txt"
OVERLAYS = [
    "Sources/HanjaKitCore/Resources/data/hanja-gloss-wiktionary/hanja_gloss.txt",
    "Sources/HanjaKitCore/Resources/data/hanja-gloss-hanjadb/hanja_gloss.txt",
]
RAW_DIR = "docs/specs/005-candidate-quality/swarm-raw"
OUT = "Sources/HanjaKitCore/Resources/data/curation-swarm/tiers.txt"
VARIANT = re.compile(
    r"(同字|略字|俗字|古字|本字|簡體|简体|간체|이체자|신자체|이형동자)"
)
UNRANKED = 100_000  # fallback rank base — sorts after any swarm rank

HEADER = (
    "# HanjaKey curation-swarm tiers (spec 005 M2): `읽기:한자:티어:글로스`, file-ordered per reading.\n"
    "# tier 0 일상 / 1 가끔 / 2 희귀·전문 / 3 변이·유령·미사용. Held (뜻 미상 등) sink to the back.\n"
    "# Built by scripts/build_tiers.py from swarm-raw/. OUR data (MIT, LLM-generated rankings)."
)


def load_canonical() -> tuple[dict[str, list[str]], dict[tuple[str, str], str]]:
    """reading -> [hanja in libhangul order]; (reading, hanja) -> current gloss (hanja.txt + 004)."""
    readings: dict[str, list[str]] = defaultdict(list)
    cur: dict[tuple[str, str], str] = {}
    for line in open(HANJA, encoding="utf-8"):
        if line.startswith("#") or not line.strip():
            continue
        c = line.rstrip("\n").split(":", 2)
        if len(c) >= 2 and c[0] and c[1]:
            readings[c[0]].append(c[1])
            cur[(c[0], c[1])] = c[2].strip() if len(c) >= 3 else ""
    for f in OVERLAYS:
        for line in open(f, encoding="utf-8"):
            if line.startswith("#") or not line.strip():
                continue
            c = line.rstrip("\n").split(":", 2)
            if len(c) == 3 and not cur.get((c[0], c[1])):
                cur[(c[0], c[1])] = c[2].strip()
    return readings, cur


def main() -> int:
    readings, cur = load_canonical()
    rankmap: dict[tuple[str, str], tuple[int, int, str]] = {}
    sgloss: dict[tuple[str, str], tuple[str, str]] = {}
    processed: set[str] = set()
    invalid: list[tuple[str, str]] = []

    for fp in sorted(glob.glob(f"{RAW_DIR}/*.json")):
        d = json.load(open(fp, encoding="utf-8"))
        for blk in d.get("result", d).get("combined", []):
            r = blk["reading"]
            processed.add(r)
            canon = set(readings.get(r, []))
            for e in blk.get("ranked", []):
                h = e["hanja"]
                if len(h) == 1 and h in canon:
                    rankmap[(r, h)] = (e["tier"], e["rank"], e.get("reason", ""))
                else:
                    invalid.append((r, h))
            for g in blk.get("glosses", []):
                sgloss[(r, g["hanja"])] = (g.get("status", ""), g.get("gloss", ""))

    by_reading: dict[str, list[dict]] = {}
    stats: dict[str, tuple[int, int]] = {}  # reading -> (canon, missing)
    for r in sorted(processed):
        rows, missing = [], 0
        for idx, h in enumerate(readings.get(r, [])):
            if (r, h) in rankmap:
                tier, rk, reason = rankmap[(r, h)]
            else:
                tier, rk, reason, missing = 3, UNRANKED + idx, "", missing + 1
            curg = cur.get((r, h), "")
            st, sg = sgloss.get((r, h), ("", ""))
            if curg:
                gloss, hold = curg, False
            elif st == "full" and sg:
                gloss, hold = sg, False
            elif st == "meaning_only" and sg:
                gloss, hold = sg, True
            else:  # reading_only / unknown / unranked / not glossed
                gloss, hold = "뜻 미상", True
            if VARIANT.search(reason) or VARIANT.search(curg):
                tier = 3
            rows.append(
                {"h": h, "tier": tier, "rank": rk, "gloss": gloss, "hold": hold}
            )
        rows.sort(key=lambda x: (x["hold"], x["tier"], x["rank"]))
        by_reading[r] = rows
        stats[r] = (len(readings.get(r, [])), missing)

    Path(OUT).parent.mkdir(parents=True, exist_ok=True)
    total = 0
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(HEADER + "\n")
        for r in sorted(by_reading):
            for x in by_reading[r]:
                f.write(f"{r}:{x['h']}:{x['tier']}:{x['gloss']}\n")
                total += 1

    print(f"[ok] {len(processed)} readings, {total} rows -> {OUT}")
    print(f"[integrity] invalid swarm hanja dropped: {len(invalid)} {invalid[:6]}")
    for r in sorted(by_reading):
        canon, missing = stats[r]
        rows = by_reading[r]
        top = " ".join(f"{x['h']}{x['tier']}" for x in rows[:10])
        print(
            f"  {r}: canon={canon} ranked={canon - missing} fallback={missing} | top: {top}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
