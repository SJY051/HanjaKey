# Bundled data

## `hanja.txt`
Hangul reading → Hanja, with Korean gloss (訓音). Extracted from **libhangul** `hanja.txt`,
filtered to single-syllable entries (`음:한자:뜻`, e.g. `한:韓:나라 이름 한`).

- **Source:** https://github.com/libhangul/libhangul → `data/hanja/hanja.txt`
- **Order:** libhangul lists each reading's Hanja by frequency / representativeness, so the most
  common Hanja appear first (matches the Windows Hanja-key ordering). `HanjaTable` preserves it.
- **Gloss:** present for common Hanja; empty for many rare characters (kept as `nil`).
- **License:** BSD-style — copyright (c) 2005,2006 Choe Hwanjin. The original copyright notice is
  retained in the header comment block at the top of `hanja.txt`.

To refresh: re-download the upstream file, keep only lines whose reading **and** Hanja are a single
character, and prepend the copyright header (see `scripts/`).

## `ks_x_1001_symbols.json`
Jamo → special-symbol map for the KS X 1001 symbols surfaced by the Korean 한자 key on a single
jamo, following the Windows IME consonant layout: ㄱ punctuation, ㄴ brackets, ㄷ math, ㄹ units,
ㅁ shapes, ㅂ box-drawing, ㅅ circled/parenthesized, ㅇ roman/greek, ㅈ fractions/superscripts,
ㅋ hiragana, ㅌ katakana, ㅍ cyrillic.
