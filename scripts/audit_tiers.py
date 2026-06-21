#!/usr/bin/env python3
"""Audit the spec 005 M2 ranking swarm — quality check over the persisted raw + compiled table.

Reads every `docs/specs/005-candidate-quality/swarm-raw/*.json` and the compiled
`tiers.txt`, then reports: per-tier distribution, readings whose #1 char is not tier 0
(a head-quality red flag), and the verifier-reported issues aggregated across batches.

The compiled table is the ground truth for *structure* (it dedups against the canonical
hanja.txt and drops non-canonical chars), so most "duplicate" verify issues are already
absorbed there — use this script to surface the residual *judgment* issues (a common char
under-tiered, a canonical char dropped to tier 3) for the sample-check pass.

Run:  python3 scripts/audit_tiers.py            # summary + head red-flags
      python3 scripts/audit_tiers.py --issues   # + full aggregated verify issue list
      python3 scripts/audit_tiers.py --reading 음   # full tier list for one reading
"""

from __future__ import annotations

import argparse
import collections
import glob
import json

RAW = "docs/specs/005-candidate-quality/swarm-raw"
TIERS = "Sources/HanjaKitCore/Resources/data/curation-swarm/tiers.txt"


def load_tiers() -> dict[str, list[tuple[str, int, str]]]:
    by_reading: dict[str, list[tuple[str, int, str]]] = collections.defaultdict(list)
    for line in open(TIERS, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        p = line.split(":", 3)
        if len(p) < 3:
            continue
        try:
            tier = int(p[2])
        except ValueError:
            continue
        by_reading[p[0]].append((p[1], tier, p[3] if len(p) > 3 else ""))
    return by_reading


def load_issues() -> list[tuple[str, str, str, str, str]]:
    issues: list[tuple[str, str, str, str, str]] = []
    for fp in sorted(glob.glob(f"{RAW}/*.json")):
        name = fp.split("/")[-1].replace("rank-", "").replace(".json", "")
        d = json.load(open(fp, encoding="utf-8"))
        res = d.get("result", d)
        for v in res.get("verify", []):
            for it in v.get("issues", []):
                issues.append(
                    (
                        name,
                        it.get("reading", ""),
                        it.get("hanja", ""),
                        it.get("kind", ""),
                        (it.get("detail") or "").replace("\n", " "),
                    )
                )
    return issues


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--issues", action="store_true", help="dump full aggregated verify issues"
    )
    ap.add_argument("--reading", help="show the full tier list for one reading")
    a = ap.parse_args()

    by_reading = load_tiers()

    if a.reading:
        for h, t, g in by_reading.get(a.reading, []):
            print(f"  {h} tier{t}  {g}")
        return 0

    dist = collections.Counter()
    held = 0
    for lst in by_reading.values():
        for _, t, g in lst:
            dist[t] += 1
            if "미상" in g:
                held += 1
    tot = sum(dist.values())
    print(f"readings={len(by_reading)}  rows={tot}  held(뜻미상)={held}")
    print(
        "tier distribution:",
        {k: f"{v} ({100 * v / tot:.1f}%)" for k, v in sorted(dist.items())},
    )

    no_t0 = [r for r, l in by_reading.items() if l and l[0][1] != 0]
    print(f"\n#1-char-not-tier0 readings: {len(no_t0)}")
    for r in sorted(no_t0):
        print(f"  {r}: " + " ".join(f"{h}{t}" for h, t, _ in by_reading[r][:5]))

    issues = load_issues()
    by_kind = collections.Counter(k for _, _, _, k, _ in issues)
    print(f"\nverify issues: {len(issues)}  by kind: {dict(by_kind)}")
    if a.issues:
        for b, r, h, k, det in issues:
            print(f"  [{b}·{r}] {h} {k}: {det[:110]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
