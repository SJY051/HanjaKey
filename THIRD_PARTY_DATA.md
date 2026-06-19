# Third-party data

HanjaKey's own code is **MIT** (see `LICENSE`). Bundled **data** is kept per-source under its own
license and is **NOT** relicensed to MIT. Each source below lists what we ship, its license, and how it
was transformed. CC BY-SA / KOGL data must keep its own notice; do not fold it under the MIT `LICENSE`.

| Source | Bundled as | License | Used for |
|---|---|---|---|
| libhangul `hanja.txt` (Choe Hwanjin) | `Sources/HanjaKitCore/Resources/hanja.txt`, `hanja_words.txt` | BSD 3-Clause | single-syllable + word inventory |
| 국립국어원 현대 국어 사용 빈도 조사 (2002) | `Sources/HanjaKitCore/Resources/data/nikl-freq/hanja_freq.txt` | KOGL 제1유형 (출처표시) | homophone-word ranking (spec 003 M1) |
| 국립국어원 표준국어대사전 + 우리말샘 *(M2, planned)* | `Sources/HanjaKitCore/Resources/data/nikl-dict/` | CC BY-SA 2.0 KR | inventory augmentation (spec 003 M2) |

## libhangul — BSD 3-Clause
The upstream repo (github.com/libhangul/libhangul) is LGPL-2.1 overall, but the data file
`data/hanja/hanja.txt` carries its **own per-file BSD 3-Clause header**, which governs that file. Our
bundled `hanja.txt` / `hanja_words.txt` retain that copyright notice + conditions + disclaimer verbatim
in their headers — the only BSD obligation (retain the notice on source redistribution) is satisfied.
- Copyright: (c) 2005,2006 Choe Hwanjin.

## 국립국어원 2002 빈도조사 — KOGL 제1유형 (출처표시)
- Source URL: https://www.korean.go.kr/front/etcData/etcDataView.do?mn_id=46&etc_seq=61
  (현대 국어 사용 빈도 조사, 국립국어원 자료실 — `freq.zip` → `단어_빈도색인.txt`)
- Version / retrieval date: 2002 corpus result files; retrieved 2026-06-19.
- Transformation: per-(reading, Hanja) frequency extracted by `scripts/build_freq.py` from the word
  index (`단어_빈도색인.txt`); multi-syllable readings only; native/loan rows (풀이 not pure Hanja)
  dropped; example sentences and multimedia not included. Output: `hanja_freq.txt` (26,678 rows).
- Attribution: 국립국어원. Redistribution + commercial use OK with attribution.

## 국립국어원 표준국어대사전 + 우리말샘 — CC BY-SA 2.0 KR *(M2, planned — not yet bundled)*
- Access: key-free mirror `spellcheck-ko/korean-dict-nikl` (or official XML dump); pin the commit.
- **ShareAlike:** the derived dictionary data ships under CC BY-SA 2.0 KR, separate from the MIT code.
- **Carve-outs stripped (mandatory):** `<source>`-bearing example sentences and ALL multimedia
  (`<multimedia_info>` / pronunciation / sign-language links) are individually licensed and excluded.
- Attribution: 국립국어원; link the CC BY-SA 2.0 KR deed; state that headwords were filtered/transformed.
