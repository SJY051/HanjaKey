# Third-party data

HanjaKey's own code is **MIT** (see `LICENSE`). Bundled **data** is kept per-source under its own
license and is **NOT** relicensed to MIT. Each source below lists what we ship, its license, and how it
was transformed. CC BY-SA / KOGL data must keep its own notice; do not fold it under the MIT `LICENSE`.

| Source | Bundled as | License | Used for |
|---|---|---|---|
| libhangul `hanja.txt` (Choe Hwanjin) | `Sources/HanjaKitCore/Resources/hanja.txt`, `hanja_words.txt` | BSD 3-Clause | single-syllable + word inventory |
| 국립국어원 현대 국어 사용 빈도 조사 (2002) | `Sources/HanjaKitCore/Resources/data/nikl-freq/hanja_freq.txt` | KOGL 제1유형 (출처표시) | homophone-word ranking (spec 003 M1) |
| 국립국어원 표준국어대사전 (stdict) | `Sources/HanjaKitCore/Resources/data/nikl-dict/hanja_words_nikl.txt` | CC BY-SA 2.0 KR | gloss + inventory overlay (spec 003 M2): 186,659 stdict entries |
| 한국어 위키낱말사전 (ko.wiktionary) | `Sources/HanjaKitCore/Resources/data/hanja-gloss-wiktionary/hanja_gloss.txt` | CC BY-SA | single-Hanja 훈음 fill (spec 004 M1): 879 entries |
| NeoMindStd/HanjaDB | `Sources/HanjaKitCore/Resources/data/hanja-gloss-hanjadb/hanja_gloss.txt` | MIT | single-Hanja 훈음 fill (spec 004 M2): 1,177 entries |

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

## 국립국어원 표준국어대사전 (stdict) — CC BY-SA 2.0 KR
- Bundled as: `Sources/HanjaKitCore/Resources/data/nikl-dict/hanja_words_nikl.txt` (spec 003 M2).
- Access: key-free mirror `spellcheck-ko/korean-dict-nikl` (stdict shards 005000–436144.xml).
- Retrieved: 2026-06-19. Built by `scripts/build_dict.py`.
- Transformation: ALL pure multi-syllable 한자어 (reading → 원어 → full first-sense definition)
  extracted; affixes and 혼종어 (음절수 ≠ 한자수) dropped. 186,659 entries.
- Runtime: `WordTable` overlays the gloss onto libhangul entries and adds new headwords (no duplication).
- **Carve-outs:** `<source>` example sentences and ALL multimedia are NOT read; the gloss is the stdict
  definition (CC BY-SA dictionary body text), not the carved-out examples.
- **ShareAlike:** ships under CC BY-SA 2.0 KR, separate from the MIT code; merged with libhangul (BSD) at
  runtime by `WordTable`, with the two source files kept separate.
- Attribution: 국립국어원; deed https://creativecommons.org/licenses/by-sa/2.0/kr/.
- 우리말샘 (opendict): deferred (전문어/방언, ~1.8GB) — add only when actually needed.

## 한국어 위키낱말사전 (ko.wiktionary) — CC BY-SA
- Bundled as: `Sources/HanjaKitCore/Resources/data/hanja-gloss-wiktionary/hanja_gloss.txt` (spec 004 M1).
- Access: kaikki.org machine-readable extract of the kowiktionary 한자 section.
- Retrieved: 2026-06-20. Built by `scripts/build_gloss_wiktionary.py`.
- Transformation: for single Hanja with an EMPTY libhangul gloss, first-sense 뜻 + reading → `읽기:한자:훈음`
  (e.g. 椵 → `나무 이름 가`). 879 entries. Example sentences, etymology, and multimedia excluded.
- **ShareAlike:** ships under CC BY-SA, separate from the MIT code; merged at runtime (fill-empty-only).
- Attribution: Wiktionary contributors (위키낱말사전). Deed https://creativecommons.org/licenses/by-sa/4.0/.

## NeoMindStd/HanjaDB — MIT
- Bundled as: `Sources/HanjaKitCore/Resources/data/hanja-gloss-hanjadb/hanja_gloss.txt` (spec 004 M2).
- Access: GitHub `NeoMindStd/HanjaDB` (`input/resource`). Retrieved 2026-06-20. Built by
  `scripts/build_gloss_hanjadb.py`.
- Transformation: for single Hanja with an EMPTY libhangul gloss, the Korean 훈음 (text before the first
  comma) keyed by (reading, hanja) → `읽기:한자:훈음`. 1,177 entries. English gloss + stroke counts dropped.
- License: MIT (maintainer-declared); kept in its own dir, separate from this project's own MIT code.
