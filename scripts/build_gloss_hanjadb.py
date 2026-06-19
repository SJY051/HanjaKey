#!/usr/bin/env python3
"""Build the hanja-gloss-hanjadb overlay (single-Hanja 훈음 from NeoMindStd/HanjaDB).

Downloads HanjaDB's `input/resource` (sectioned by reading: a `[가]` header, then lines
`한자=한국어훈음, english (strokes)`) and, for each single Hanja that libhangul leaves WITHOUT a gloss,
fills the 훈음 from the Korean part (text before the first comma). HanjaDB is reading-sectioned, so we key
by (reading, hanja) exactly. Some entries are `X의 略字/俗字` carrying no reading; we append the reading so
the gloss includes it.

Output: Sources/HanjaKitCore/Resources/data/hanja-gloss-hanjadb/hanja_gloss.txt (읽기:한자:훈음),
fill-empty-only against hanja.txt (see spec 004 M2).

License: HanjaDB is MIT (maintainer-declared). Kept separate from this project's MIT code under its own
LICENSE-DATA.md + THIRD_PARTY_DATA.md row. Only the Korean 훈음 is taken; the English (Unihan-derived)
gloss and stroke counts are dropped.

Spec: docs/specs/004-hanja-gloss/spec.md (M2).
Run:  python3 scripts/build_gloss_hanjadb.py     # needs `gh`; downloads ~0.5MB; stdlib only
"""

from __future__ import annotations

import argparse
import base64
import re
import subprocess
import sys
from pathlib import Path

REPO = "NeoMindStd/HanjaDB"
RESOURCE_PATH = "input/resource"
HANJA_TXT = Path("Sources/HanjaKitCore/Resources/hanja.txt")
DEFAULT_OUT = Path(
    "Sources/HanjaKitCore/Resources/data/hanja-gloss-hanjadb/hanja_gloss.txt"
)

HEADER = (
    "# HanjaKey hanja-gloss-hanjadb — `읽기:한자:훈음` filling EMPTY single-Hanja glosses.\n"
    "# Source: NeoMindStd/HanjaDB (input/resource), MIT. Korean 훈음 only (English/strokes dropped).\n"
    "# License: MIT (kept separate; see LICENSE-DATA.md). Built by scripts/build_gloss_hanjadb.py (spec 004 M2)."
)


def has_hangul(s: str) -> bool:
    return any("가" <= c <= "힣" for c in s)


def load_empty_pairs(path: Path) -> list[tuple[str, str]]:
    """(reading, hanja) entries in hanja.txt whose gloss is empty, in file order."""
    pairs: list[tuple[str, str]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        cols = s.split(":", 2)
        if len(cols) < 2 or not cols[0] or not cols[1]:
            continue
        if not (cols[2].strip() if len(cols) >= 3 else ""):
            pairs.append((cols[0], cols[1]))
    return pairs


def load_hanjadb() -> dict[tuple[str, str], str]:
    """(reading, hanja) -> Korean 훈음 (text before the first comma, must contain Hangul)."""
    content = subprocess.run(
        ["gh", "api", f"repos/{REPO}/contents/{RESOURCE_PATH}", "--jq", ".content"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    text = base64.b64decode(content).decode("utf-8", errors="replace")
    out: dict[tuple[str, str], str] = {}
    reading: str | None = None
    for line in text.splitlines():
        s = line.strip()
        m = re.match(r"^\[(.+)\]$", s)
        if m:
            reading = m.group(1)
            continue
        if reading and "=" in s:
            hanja, _, rest = s.partition("=")
            hanja = hanja.strip()
            korean = rest.split(",")[0].strip()
            if len(hanja) == 1 and has_hangul(korean):
                out.setdefault((reading, hanja), korean)
    return out


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        description="Build hanja-gloss-hanjadb overlay (spec 004 M2)."
    )
    ap.add_argument("--hanja", type=Path, default=HANJA_TXT, help="libhangul hanja.txt")
    ap.add_argument(
        "-o",
        "--out",
        type=Path,
        default=DEFAULT_OUT,
        help="output overlay path (UTF-8)",
    )
    args = ap.parse_args(argv)

    empty = load_empty_pairs(args.hanja)
    print(f"[*] {len(empty)} empty (reading, hanja) entries", flush=True)
    print("[*] downloading HanjaDB input/resource via gh ...", flush=True)
    db = load_hanjadb()
    print(f"[*] {len(db)} (reading, hanja) Korean glosses in HanjaDB", flush=True)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    rows = 0
    with args.out.open("w", encoding="utf-8") as f:
        f.write(HEADER + "\n")
        for reading, hanja in empty:
            korean = db.get((reading, hanja))
            if not korean:
                continue
            gloss = korean if korean.endswith(reading) else f"{korean} {reading}"
            f.write(f"{reading}:{hanja}:{gloss}\n")
            rows += 1
    print(f"[ok] wrote {rows} gloss rows -> {args.out}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
