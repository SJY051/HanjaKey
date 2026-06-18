# Bundled data

## `Unihan_Readings.sample.txt`
A handful of real rows from the Unicode **Unihan** database (`Unihan_Readings.txt`), used as a
test fixture and dev placeholder.

- **Full data:** https://www.unicode.org/Public/UCD/latest/ucd/Unihan.zip → `Unihan_Readings.txt`
- **Field:** `kHangul` (per UAX #38). Value = space-separated Hangul readings, each with a
  source-tag suffix (`:0E` educational, `:0N` name-use) that the parser strips.
- **License:** Unicode License v3 — https://www.unicode.org/license.txt

To get full coverage, drop the real `Unihan_Readings.txt` here (or filter it to `kHangul` rows)
and point `UnihanTable.bundled()` at it.

## `ks_x_1001_symbols.json`
Jamo → special-symbol map approximating the KS X 1001 symbol rows surfaced by the Korean
한자 key for single jamo (e.g. ㅁ → ※ ◎ □ …). Sample/partial — extend with the full KS X 1001
symbol table as needed.
