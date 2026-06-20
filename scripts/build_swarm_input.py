#!/usr/bin/env python3
"""Dump the next ranking-batch input for the spec 005 M2 swarm.

Picks the next N un-processed readings with >20 candidates (by descending candidate count), each as its
hanja string in libhangul order (capped). Already-processed readings are excluded automatically by
scanning docs/specs/005-candidate-quality/swarm-raw/. Prints the compact args JSON to stdout (paste it
into the Workflow `args`); progress goes to stderr.

Run:  python3 scripts/build_swarm_input.py [--count 40] [--cap 160]
"""

from __future__ import annotations

import argparse
import glob
import json
import sys
from collections import defaultdict

HANJA = "Sources/HanjaKitCore/Resources/hanja.txt"
RAW = "docs/specs/005-candidate-quality/swarm-raw"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--count", type=int, default=40, help="readings per batch")
    ap.add_argument("--cap", type=int, default=160, help="max candidates per reading")
    a = ap.parse_args()

    rows: dict[str, list[str]] = defaultdict(list)
    for line in open(HANJA, encoding="utf-8"):
        if line.startswith("#") or not line.strip():
            continue
        c = line.rstrip("\n").split(":", 2)
        if len(c) >= 2 and c[0] and c[1]:
            rows[c[0]].append(c[1])

    done: set[str] = set()
    for fp in glob.glob(f"{RAW}/*.json"):
        d = json.load(open(fp, encoding="utf-8"))
        for blk in d.get("result", d).get("combined", []):
            done.add(blk["reading"])

    big = sorted(
        (r for r in rows if len(rows[r]) > 20 and r not in done),
        key=lambda r: -len(rows[r]),
    )
    chunk = big[: a.count]
    data = {r: "".join(rows[r][: a.cap]) for r in chunk}

    print(
        f"# done={len(done)} batch={len(chunk)} remaining_after={len(big) - len(chunk)}",
        file=sys.stderr,
    )
    print(f"# readings: {' '.join(chunk)}", file=sys.stderr)
    print(json.dumps(data, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
