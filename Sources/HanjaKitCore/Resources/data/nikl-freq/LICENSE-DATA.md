# nikl-freq — data license

**Source:** 국립국어원 「현대 국어 사용 빈도 조사」 (2002), result text files.
**License:** 공공누리(KOGL) 제1유형 — 출처표시. Commercial use, modification, and redistribution are
permitted **with attribution**.
**Attribution:** 국립국어원 (National Institute of Korean Language).

`hanja_freq.txt` (when built) is **derived** from the corpus result files by `scripts/build_freq.py`
(per-(reading, Hanja) frequency; native/loan rows without a Hanja spelling are dropped; example
sentences and multimedia are not included). This data stays under **KOGL 제1유형** — it is NOT covered
by the project's MIT `LICENSE`.

See the repo-root `THIRD_PARTY_DATA.md` for source URL, file version, retrieval date, and the exact
transformation applied.

- Source URL: https://www.korean.go.kr/front/etcData/etcDataView.do?mn_id=46&etc_seq=61
- Version: 2002 corpus result files (`단어_빈도색인.txt`); retrieved 2026-06-19.
- Built by `scripts/build_freq.py` → `hanja_freq.txt` (26,678 rows; multi-syllable readings only).
