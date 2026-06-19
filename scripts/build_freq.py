#!/usr/bin/env python3
"""Build HanjaKey's frequency table from the 국립국어원 현대 국어 사용 빈도 조사 (2002) result files.

Input : the corpus result archive `freq.zip` (or the extracted `단어_빈도색인.txt`). The word index is a
        TAB-separated, EUC-KR table: 차례 / 항목(headword+homograph#, e.g. 가07) / 풀이(Hanja 원어 for
        Sino-Korean words, else a gloss/blank) / 품사 / 빈도(total, comma-grouped) / 개수 / 9 domains.
Output: Sources/HanjaKitCore/Resources/data/nikl-freq/hanja_freq.txt — `읽기:한자:빈도` lines, one per
        (reading, Hanja), frequency-descending within each reading. Multi-syllable readings only
        (single syllables are already frequency-ordered by libhangul `hanja.txt`). Native/loan rows
        (풀이 not pure Hanja) are dropped.

Source license: KOGL 제1유형 (출처표시), 국립국어원. The OUTPUT is a derived work of KOGL data — keep it
under KOGL 제1유형, do NOT relabel it MIT. See repo-root THIRD_PARTY_DATA.md.

Spec: docs/specs/003-ranking-data/spec.md (FR-001..FR-003).
Run:  python3 scripts/build_freq.py /path/to/freq.zip      (stdlib only, no deps)
"""

from __future__ import annotations

import argparse
import re
import sys
import zipfile
from collections import defaultdict
from pathlib import Path

SOURCE_ENCODING = "euc-kr"  # the 2002 corpus result files are EUC-KR
ZIP_NAME_ENCODING = "cp949"  # zip stores Korean member names as cp949 mis-flagged cp437
WORD_INDEX_MEMBER = "단어_빈도색인.txt"
DEFAULT_OUT = Path("Sources/HanjaKitCore/Resources/data/nikl-freq/hanja_freq.txt")

OUTPUT_HEADER = (
    "# HanjaKey homophone-word frequency table — `읽기:한자:빈도` (frequency-descending per reading).\n"
    "# Derived from 국립국어원 「현대 국어 사용 빈도 조사」 (2002), file 단어_빈도색인.txt,\n"
    "# by scripts/build_freq.py. Multi-syllable readings only; per-(reading, Hanja) total frequency.\n"
    "# License: KOGL 제1유형 (출처표시) — 국립국어원. NOT MIT. See THIRD_PARTY_DATA.md."
)


def _is_hanja(s: str) -> bool:
    """True if `s` is non-empty and every character is a CJK Unified ideograph (the 원어 case)."""
    return len(s) > 0 and all("一" <= c <= "鿿" for c in s)


def parse_word_index(text: str) -> dict[str, dict[str, int]]:
    """Parse the 단어 word-index text into {reading: {hanja: total_frequency}}.

    Keeps only multi-syllable Sino-Korean rows: 풀이 must be pure Hanja and its length must match the
    reading's syllable count (one Hanja per syllable). Same (reading, hanja) across rows is summed.
    """
    table: dict[str, dict[str, int]] = defaultdict(dict)
    for line in text.splitlines()[1:]:  # skip the header row
        cols = line.split("\t")
        if len(cols) < 5:
            continue
        item, puli, freq_str = (
            cols[1].strip(),
            cols[2].strip(),
            cols[4].strip().replace(",", ""),
        )
        reading = re.sub(
            r"\d+$", "", item
        )  # drop the trailing homograph number (e.g. 가07 -> 가)
        if len(reading) < 2 or not _is_hanja(puli) or len(reading) != len(puli):
            continue
        try:
            freq = int(freq_str)
        except ValueError:
            continue
        table[reading][puli] = table[reading].get(puli, 0) + freq
    return table


def read_word_index(path: Path) -> str:
    """Return the 단어_빈도색인.txt text from a `freq.zip` or a direct .txt path (both EUC-KR)."""
    if path.suffix.lower() == ".zip":
        with zipfile.ZipFile(path) as z:
            for info in z.infolist():
                name = info.filename.encode("cp437").decode(
                    ZIP_NAME_ENCODING, "replace"
                )
                if name == WORD_INDEX_MEMBER:
                    return z.read(info).decode(SOURCE_ENCODING, "replace")
        raise SystemExit(f"'{WORD_INDEX_MEMBER}' not found in {path}")
    return path.read_text(encoding=SOURCE_ENCODING)


def write_table(table: dict[str, dict[str, int]], out_path: Path) -> tuple[int, int]:
    """Write `읽기:한자:빈도` lines (UTF-8), frequency-descending within each reading. Returns (rows, readings)."""
    out_path.parent.mkdir(parents=True, exist_ok=True)
    lines = [OUTPUT_HEADER]
    rows = 0
    for reading in sorted(table):
        for hanja, freq in sorted(
            table[reading].items(), key=lambda kv: (-kv[1], kv[0])
        ):
            lines.append(f"{reading}:{hanja}:{freq}")
            rows += 1
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return rows, len(table)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        description="Build hanja_freq.txt from the 2002 빈도조사 word index."
    )
    ap.add_argument("input", type=Path, help="freq.zip or 단어_빈도색인.txt (EUC-KR)")
    ap.add_argument(
        "-o", "--out", type=Path, default=DEFAULT_OUT, help="output path (UTF-8)"
    )
    args = ap.parse_args(argv)

    table = parse_word_index(read_word_index(args.input))
    rows, readings = write_table(table, args.out)
    print(
        f"[ok] wrote {rows} (reading, hanja) rows over {readings} multi-syllable readings -> {args.out}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
