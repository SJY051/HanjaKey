# hanja-gloss-hanjadb — data license

**Source:** NeoMindStd/HanjaDB (`input/resource`) — https://github.com/NeoMindStd/HanjaDB
**License:** MIT (declared by the HanjaDB maintainer). Upstream data derives from `hanjadic`; the HanjaDB
maintainer applies MIT, treating the character→훈음 mapping as not subject to dictionary copyright.
**Attribution:** NeoMindStd/HanjaDB.

`hanja_gloss.txt` is **derived** by `scripts/build_gloss_hanjadb.py`: for each single Hanja that libhangul
`hanja.txt` leaves WITHOUT a 훈음, the Korean 훈음 (the text before the first comma in HanjaDB's
`한자=한국어훈음, english (strokes)` lines) is taken and keyed by `(reading, hanja)` from HanjaDB's reading
sections. The English (Unihan-derived) gloss and stroke counts are dropped. Kept under **MIT**, in its own
dir separate from this project's own MIT code.

- Source URL: https://github.com/NeoMindStd/HanjaDB (input/resource)
- Retrieved: 2026-06-20.
