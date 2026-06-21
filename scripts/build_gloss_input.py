#!/usr/bin/env python3
"""Dump the gloss-pass input — spec 005 M2 ② (fill empty 훈음).

A (reading, hanja) pair needs a gloss when its 대표훈음 (hanja.txt + the 004 overlays) is EMPTY and it is
user-visible: a RANKED reading at tier 0–2, or any UNRANKED reading (≤20 candidates, never tiered — all
shown). Ranked tier 3 stays `뜻 미상` by design and is excluded.

Already-done pairs are auto-excluded by scanning `swarm-raw/gloss-*.json`, so this is resumable and
self-healing (a dropped/transcription-lost pair reappears next run). Output is grouped `{읽기: "한자들"}`
(libhangul order) — compact like the ranking input — to keep the harness `args` small. Gloss is per
(reading, hanja), NOT per char, because of 다음자 (e.g. 樂 = 락/악/요). Progress + breakdown go to stderr.

Run:  python3 scripts/build_gloss_input.py
"""

from __future__ import annotations

import glob
import json
import sys
from collections import defaultdict

HANJA = "Sources/HanjaKitCore/Resources/hanja.txt"
OVERLAYS = [
    "Sources/HanjaKitCore/Resources/data/hanja-gloss-wiktionary/hanja_gloss.txt",
    "Sources/HanjaKitCore/Resources/data/hanja-gloss-hanjadb/hanja_gloss.txt",
]
TIERS = "Sources/HanjaKitCore/Resources/data/curation-swarm/tiers.txt"
RAW = "docs/specs/005-candidate-quality/swarm-raw"


def load_canonical() -> tuple[dict[str, list[str]], dict[tuple[str, str], str]]:
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


def load_tiers() -> dict[tuple[str, str], int]:
    tier: dict[tuple[str, str], int] = {}
    for line in open(TIERS, encoding="utf-8"):
        if line.startswith("#") or not line.strip():
            continue
        p = line.rstrip("\n").split(":", 3)
        if len(p) >= 3:
            try:
                tier[(p[0], p[1])] = int(p[2])
            except ValueError:
                pass
    return tier


def load_done() -> set[tuple[str, str]]:
    done: set[tuple[str, str]] = set()
    for fp in glob.glob(f"{RAW}/gloss-*.json"):
        d = json.load(open(fp, encoding="utf-8"))
        for e in d.get("result", d).get("combined", []):
            r, h = e.get("reading"), e.get("hanja")
            if r and h:
                done.add((r, h))
    return done


def main() -> int:
    readings, cur = load_canonical()
    tier = load_tiers()
    done = load_done()
    ranked = {r for (r, _) in tier}

    groups: dict[str, list[str]] = defaultdict(list)
    counts: dict[str, int] = defaultdict(int)
    pairs = 0
    for r, hs in readings.items():
        for h in hs:
            if cur.get((r, h)) or (r, h) in done:
                continue
            if r in ranked:
                t = tier.get((r, h), 3)
                if t == 3:
                    continue  # ranked tier 3 stays 뜻 미상 by design
                counts[f"ranked_t{t}"] += 1
            else:
                counts["unranked"] += 1
            groups[r].append(h)
            pairs += 1

    data = {r: "".join(hs) for r, hs in groups.items()}
    print(
        f"# done={len(done)} pairs={pairs} readings={len(data)} "
        f"breakdown={dict(sorted(counts.items()))}",
        file=sys.stderr,
    )
    print(json.dumps(data, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
