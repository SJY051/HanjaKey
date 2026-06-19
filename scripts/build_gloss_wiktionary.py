#!/usr/bin/env python3
"""Build the hanja-gloss-wiktionary overlay (single-Hanja 훈음 from ko.wiktionary).

Downloads the kaikki.org machine-readable extract of the Korean Wiktionary 한자 section and, for each
single Hanja that libhangul leaves WITHOUT a gloss, fills the 훈음 from Wiktionary's first sense. The
kaikki data carries only the 뜻 (e.g. 椵 -> "나무 이름"), not the reading, so we key by character and
reconstruct the 훈음 by appending the reading from the existing hanja.txt inventory: 椵 -> "나무 이름 가".

Output: Sources/HanjaKitCore/Resources/data/hanja-gloss-wiktionary/hanja_gloss.txt (읽기:한자:훈음),
covering only entries currently EMPTY in hanja.txt (fill-empty-only; see spec 004 M1).

License: ko.wiktionary text is CC BY-SA (+ GFDL). The gloss content stays under CC BY-SA — NOT MIT — see
data/hanja-gloss-wiktionary/LICENSE-DATA.md and THIRD_PARTY_DATA.md. The reading keys are factual
pronunciations from libhangul (BSD); only the gloss body is the copyrightable Wiktionary content.

Spec: docs/specs/004-hanja-gloss/spec.md (M1).
Run:  python3 scripts/build_gloss_wiktionary.py     # downloads ~1.8MB; stdlib only
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.request
from pathlib import Path

KAIKKI_URL = (
    "https://kaikki.org/kowiktionary/"
    "%ED%95%9C%EC%9E%90/kaikki.org-dictionary-%ED%95%9C%EC%9E%90.jsonl"
)
HANJA_TXT = Path("Sources/HanjaKitCore/Resources/hanja.txt")
DEFAULT_OUT = Path(
    "Sources/HanjaKitCore/Resources/data/hanja-gloss-wiktionary/hanja_gloss.txt"
)

HEADER = (
    "# HanjaKey hanja-gloss-wiktionary — `읽기:한자:훈음` filling EMPTY single-Hanja glosses.\n"
    "# Source: 한국어 위키낱말사전 (ko.wiktionary) 한자 section, via kaikki.org machine-readable extract.\n"
    "# License: CC BY-SA (+ GFDL). NOT MIT. Gloss = first-sense 뜻 + reading; see LICENSE-DATA.md.\n"
    "# Built by scripts/build_gloss_wiktionary.py (spec 004 M1, fill-empty-only)."
)


def is_hanja(c: str) -> bool:
    if len(c) != 1:
        return False
    o = ord(c)
    # CJK Ext A + Unified + Compat Ideographs + Ext B.. (hanja.txt has many rare/variant chars)
    return 0x3400 <= o <= 0x9FFF or 0xF900 <= o <= 0xFAFF or 0x20000 <= o <= 0x2FA1F


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
        gloss = cols[2].strip() if len(cols) >= 3 else ""
        if not gloss:
            pairs.append((cols[0], cols[1]))
    return pairs


def load_kaikki_meanings(url: str) -> dict[str, str]:
    """Hanja char -> first-sense 뜻 (trailing punctuation stripped). First entry per char wins."""
    out: dict[str, str] = {}
    req = urllib.request.Request(url, headers={"User-Agent": "HanjaKey-build/1.0"})
    with urllib.request.urlopen(req) as resp:
        for raw in resp:
            obj = json.loads(raw)
            ch = obj.get("word", "")
            if not is_hanja(ch) or ch in out:
                continue
            senses = obj.get("senses") or []
            glosses = (senses[0].get("glosses") if senses else None) or []
            if not glosses:
                continue
            meaning = re.sub(r"[.\s]+$", "", glosses[0]).strip()
            if meaning:
                out[ch] = meaning
    return out


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        description="Build hanja-gloss-wiktionary overlay (spec 004 M1)."
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
    print(
        f"[*] {len(empty)} empty (reading, hanja) entries in {args.hanja}", flush=True
    )
    print("[*] downloading kaikki ko 한자 extract ...", flush=True)
    meanings = load_kaikki_meanings(KAIKKI_URL)
    print(f"[*] {len(meanings)} Hanja with a Wiktionary meaning", flush=True)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    rows = 0
    with args.out.open("w", encoding="utf-8") as f:
        f.write(HEADER + "\n")
        for reading, hanja in empty:
            meaning = meanings.get(hanja)
            if not meaning:
                continue
            gloss = meaning if meaning.endswith(reading) else f"{meaning} {reading}"
            f.write(f"{reading}:{hanja}:{gloss}\n")
            rows += 1
    print(f"[ok] wrote {rows} gloss rows -> {args.out}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
