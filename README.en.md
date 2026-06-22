# HanjaKey

A macOS menu-bar utility that brings back the Windows **Hanja key**. Without replacing your input
method, a global hotkey converts the Hangul before your caret into Hanja or special symbols, in place.

> 한국어: [README.md](README.md)

<p align="center">
  <img src="docs/images/hanjakey-word.gif" width="480" alt="Converting 한자 into 漢字"><br>
  <sub>Word recognition · 한자 → 漢字 (ranked, with meanings)</sub>
</p>

<table align="center">
  <tr>
    <td align="center"><img src="docs/images/hanjakey-single.gif" width="300" alt="Single-Hanja conversion"><br><sub>Single Hanja · 가 → 歌</sub></td>
    <td align="center"><img src="docs/images/hanjakey-symbol.gif" width="300" alt="Special-symbol conversion"><br><sub>Special symbols · ㄱ → ♥</sub></td>
  </tr>
</table>

## Why

macOS's Korean input method does convert Hangul to Hanja (Option+Return), but it has **no way to
enter special symbols from a jamo**, and it only works while Korean input is active. HanjaKey is
callable anywhere via a global hotkey, regardless of the input source, and unifies Hanja and KS X
1001 symbols in one picker that inserts in place.

## What it does

- **Hangul syllable → Hanja** — 한 → 韓 漢 寒 … (shown with the Korean reading/meaning)
- **Jamo → special symbol** — the KS X 1001 layout. ㅁ → ※ ◎ □ …, ㄷ → ± × ÷ …
- **Hanja word → Hanja** — 대한민국 → 大韓民國, 한자 → 漢字
- Inserts the chosen text **in place at the caret** (your clipboard is saved and restored)

## Where it works

- **Works:** native apps (TextEdit, …), Electron apps (Claude, Discord, …), browsers
- **Not supported:** terminals — they don't expose editable accessibility (AX) text

## Usage

1. Type Hangul, keep the caret right after it, and press **⌥⌘H**
   - For words it auto-grabs the 어절 (Hangul run) before the caret, or uses your selection if any
2. Pick a candidate
   - **1–9** to pick · **↑↓←→** move/page · **Tab** expand · **↵** insert · **esc** cancel
3. For words not in the dictionary, use **"음절별로 만들기"** (build per syllable) to assemble one

Settings live in the menu-bar **漢** icon or the popup's **⋯ → Settings**: expanded view
(wide/compact grid), fullwidth/halfwidth symbols, custom user sets, and menu-bar icon visibility.

## Install / Build

- Requires **macOS 14+** and the **Xcode toolchain** (for XCTest / building)
- Build: `scripts/bundle.sh` → `.build/HanjaKey.app`
- On first run, grant **Accessibility** permission so in-place insertion works
  (System Settings → Privacy & Security → Accessibility)
- Hotkeys via [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)

## Data / credits

The code is MIT, but **bundled data keeps each source's own license** (not relicensed to MIT).
Full list and details in [`THIRD_PARTY_DATA.md`](THIRD_PARTY_DATA.md).

- **Hanja & Hanja-word inventory** — [libhangul](https://github.com/libhangul/libhangul) `hanja.txt` · BSD 3-Clause · © 2005,2006 Choe Hwanjin
- **Special symbols** — KS X 1001 per-jamo layout (first-party)
- **Hanja-word frequency (homophone ranking)** — NIKL "Modern Korean Usage Frequency Survey" (2002) · KOGL Type 1 (attribution)
- **Hanja-word glosses** — NIKL Standard Korean Dictionary · **CC BY-SA 2.0 KR**
- **Single-Hanja gloss (fill)** — Korean Wiktionary · **CC BY-SA** / NeoMindStd [HanjaDB](https://github.com/NeoMindStd/HanjaDB) · MIT
- **Single-Hanja ordering & gloss (generated)** — first-party LLM-generated HanjaKey data · MIT

> The dictionary and Wiktionary data are distributed under **CC BY-SA (ShareAlike)**, and the NIKL
> frequency survey under **KOGL Type 1 (attribution)**. Keep the attribution and ShareAlike terms when redistributing.

## License

- Code: [MIT](LICENSE)
- Bundled data: each source keeps its own license — see [`THIRD_PARTY_DATA.md`](THIRD_PARTY_DATA.md). The
  CC BY-SA and KOGL data are not MIT; the original copyright/attribution notices stay in the data files.
