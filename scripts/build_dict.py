#!/usr/bin/env python3
"""Build the nikl-dict gloss/inventory layer from 표준국어대사전 (stdict).

Downloads the stdict XML shards from the key-free `spellcheck-ko/korean-dict-nikl` mirror and extracts
ALL pure multi-syllable 한자어 (Hangul reading -> Hanja 원어 -> first-sense definition) to
Sources/HanjaKitCore/Resources/data/nikl-dict/hanja_words_nikl.txt. At runtime `WordTable` overlays this
onto the libhangul inventory: for a shared (reading, hanja) it fills the missing gloss; for a new hanja
or reading it adds the entry. This gives every stdict-listed 한자어 a definition (선택 편의), keeping the
two source files and licenses separate.

Extraction rules (match scripts/build_freq.py for consistency):
  - <word_info> with <word_type>=한자어 only,
  - strip the trailing homograph number and morpheme-boundary hyphens from <word>; skip affixes
    (leading/trailing hyphen),
  - take <original_language> as the Hanja; keep only pure-Hanja 원어 whose length == the reading's
    syllable count (drops 혼종어 / 복합 원어, deferred),
  - gloss = the first <sense_info>'s <definition>, whitespace-collapsed (FULL text, not capped — the UI
    shows it in a wrapping footer / tooltip). Example sentences (<source>) and multimedia are never read.

License: 표준국어대사전 is CC BY-SA 2.0 KR (국립국어원). The output stays under that license (NOT MIT) —
see THIRD_PARTY_DATA.md. Definitions are dictionary body text (CC BY-SA), not the carved-out examples.

Spec: docs/specs/003-ranking-data/spec.md (FR-009, M2).
Run:  python3 scripts/build_dict.py        # downloads ~656MB to a cache dir on first run; needs `gh`
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

REPO = "spellcheck-ko/korean-dict-nikl"
RAW_BASE = f"https://raw.githubusercontent.com/{REPO}/master/stdict"
DEFAULT_CACHE = Path("/tmp/nikl-stdict")
DEFAULT_OUT = Path("Sources/HanjaKitCore/Resources/data/nikl-dict/hanja_words_nikl.txt")

OUTPUT_HEADER = (
    "# HanjaKey nikl-dict — `읽기:한자:뜻` for ALL stdict multi-syllable 한자어 (full first-sense definition).\n"
    "# Source: 국립국어원 표준국어대사전, via spellcheck-ko/korean-dict-nikl (stdict shards).\n"
    "# License: CC BY-SA 2.0 KR (국립국어원). NOT MIT. Examples/multimedia excluded. See THIRD_PARTY_DATA.md.\n"
    "# Built by scripts/build_dict.py. WordTable overlays gloss onto libhangul + adds new readings at runtime."
)


def is_hanja(s: str) -> bool:
    return len(s) > 0 and all("一" <= c <= "鿿" for c in s)


def clean_gloss(defn: str) -> str:
    return " ".join(
        defn.split()
    )  # full definition; just collapse whitespace/newlines to single spaces


def shard_names() -> list[str]:
    """Live list of stdict .xml shard names from the mirror (via `gh`). Avoids hardcoding the shard
    numbering, whose last shard is the entry count (e.g. 436144.xml, not a round 5000) and whose dir
    also holds non-.xml files (update.py)."""
    out = subprocess.run(
        ["gh", "api", f"repos/{REPO}/contents/stdict", "--jq", ".[].name"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    return sorted(n for n in out.split() if n.endswith(".xml"))


def download_shards(cache: Path, shards: list[str]) -> None:
    cache.mkdir(parents=True, exist_ok=True)
    for i, name in enumerate(shards, 1):
        dest = cache / name
        if dest.exists() and dest.stat().st_size > 0:
            continue
        urllib.request.urlretrieve(f"{RAW_BASE}/{name}", dest)
        print(f"  [{i}/{len(shards)}] downloaded {name}", flush=True)


def extract_shard(path: Path) -> dict[tuple[str, str], str]:
    """Pure multi-syllable (reading, hanja) -> full first-sense definition, from one stdict shard."""
    out: dict[tuple[str, str], str] = {}
    root = ET.fromstring(path.read_text(encoding="utf-8", errors="replace"))
    for item in root.iter("item"):
        wi = item.find("word_info")
        if wi is None or (wi.findtext("word_type") or "").strip() != "한자어":
            continue
        word = re.sub(r"\d+$", "", (wi.findtext("word") or "").strip())
        if word.startswith("-") or word.endswith("-"):
            continue  # affix, not a standalone word
        reading = word.replace("-", "")  # drop morpheme-boundary hyphens
        oli = wi.find("original_language_info")
        hanja = (
            (oli.findtext("original_language") or "").strip().replace("-", "")
            if oli is not None
            else ""
        )
        if len(reading) < 2 or not is_hanja(hanja) or len(reading) != len(hanja):
            continue
        key = (reading, hanja)
        if key in out:
            continue  # keep the first sense's definition
        out[key] = clean_gloss(
            next((si.findtext("definition") or "" for si in wi.iter("sense_info")), "")
        )
    return out


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        description="Build hanja_words_nikl.txt (stdict gloss/inventory layer)."
    )
    ap.add_argument(
        "--cache", type=Path, default=DEFAULT_CACHE, help="stdict shard cache dir"
    )
    ap.add_argument(
        "-o", "--out", type=Path, default=DEFAULT_OUT, help="output path (UTF-8)"
    )
    args = ap.parse_args(argv)

    shards = shard_names()
    print(f"[*] {len(shards)} stdict shards (live list) -> {args.cache}", flush=True)
    download_shards(args.cache, shards)

    print("[*] extracting pure 한자어 + gloss ...", flush=True)
    stdict: dict[tuple[str, str], str] = {}
    for name in shards:
        for key, defn in extract_shard(args.cache / name).items():
            stdict.setdefault(
                key, defn
            )  # first shard wins on the rare cross-shard duplicate

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with_gloss = 0
    with args.out.open("w", encoding="utf-8") as f:
        f.write(OUTPUT_HEADER + "\n")
        for reading, hanja in sorted(stdict):
            gloss = stdict[(reading, hanja)]
            if gloss:
                with_gloss += 1
            f.write(f"{reading}:{hanja}:{gloss}\n")

    print(
        f"[ok] stdict pure 한자어={len(stdict)} ({with_gloss} with gloss) -> {args.out}",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
