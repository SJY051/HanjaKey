---
title: App icon + Liquid Glass branding pipeline
status: implemented  # draft -> approved -> implemented (M1 done; M2/M3 pending)
created: 2026-06-22
owner: ASQi
tags: [icon, branding, liquid-glass, icon-composer, actool, release, macos]
---

# App icon + Liquid Glass branding pipeline

## Context & problem
HanjaKey is a public macOS app with **no app icon** — `scripts/bundle.sh` assembles the `.app`
without one, so Finder, the About/정보 window, System Settings ▸ Login Items, a future
distribution DMG, and the GitHub README all show the generic blank icon. Release polish needs a
real, considered icon.

Two forces shape *how*:
- **Format.** On macOS 26 (Tahoe) app icons are **Liquid Glass**, authored as an Icon Composer
  `.icon` package and compiled by `actool`. The system applies depth, specular highlights,
  translucency, the rounded-rect mask, and the light/dark/tinted variants — we supply **layers**,
  not a flat baked image.
- **Identity.** HanjaKey is the macOS implementation of the Windows-IME **Korean → 한자/특수기호**
  conversion (extended to words). The icon must read as a **Korean** tool, not a Chinese one — an
  earlier red-ground `漢` concept was rejected as too Sino-centric. Foregrounding **Hangul** fixes
  this and also expresses the core conversion (한 → 字).

Constraint: the project is **pure SwiftPM + a hand-rolled `bundle.sh` (no Xcode project)**, so the
icon pipeline must be fully scriptable with the command-line tools (`actool`, `ictool`) — no
`.xcodeproj`, no GUI step on the critical path. Audience: end users (Finder/About) and the README.

This was de-risked then built this session: an **end-to-end spike passed** (macOS 26.5.1 / Xcode
26.5 / Icon Composer present), and M1 shipped — see "Pipeline (verified)" and "Implemented (M1)".

## Goals / non-goals
**Goals**
- Ship a **Liquid Glass app icon** (`.icon`) that reads as a Korean Hangul→Hanja tool (the
  "celadon seal" design).
- A **scriptable, no-Xcode pipeline** wired into `bundle.sh`: author layers → compile via `actool`
  → bundle — with **headless self-verification** (`ictool`) of the glass renditions before handoff.
- **Backward compatibility**: glass on macOS 26+, flat `.icns` on 14/15 (the current min target).
- **License-clean** (OFL fonts) and **rebuildable from source** in-repo.

**Non-goals**
- Code signing with a Developer ID, notarization, or distribution (DMG) — separate, later.
- The menu-bar template mark (→ M2) and README screenshots/social preview (→ M3).
- Tuning parallax/animation beyond Icon Composer's defaults (ASQi may fine-tune in the GUI).
- Any change to the in-app UI or the existing Settings ▸ About section.

## Requirements
- **FR-001 (design)**: The icon is the **celadon seal** — a square plate split by a diagonal
  (lower-left → upper-right): celadon (`#5d917a`) upper-left, pale celadon-white (`#dcebe2`)
  lower-right. A large Hangul **한** (cream `#f7f4ec`) sits crisp in the upper-left; a Hanja **字**
  (deep celadon `#1c3a2e`, Myeongjo/serif) sits in the lower-right, **receding behind a frosted
  glass panel** (see FR-003). Hangul-forward; the diagonal is the glass panel's edge.
- **FR-002 (format)**: Authored as an Icon Composer **`.icon` package** (`icon.json` + `Assets/*.png`)
  checked into the repo at `bundling/AppIcon.icon/`. Every layer is a **full 1024px square — NO
  rounded-rect mask** (the system applies the mask). `supported-platforms = { "squares": ["macOS"] }`.
- **FR-003 (layer model — layered glass)**: Four layers give the depth (z-order front→back):
  1. **`han.png`** — 한, cream, Pretendard, upper-left, fully inside (ㅎ intact → reads 한, not 안).
     Flat (no glass). Front.
  2. **`panel.png`** — the pale lower-right triangle, as a **glass layer** (`glass: true`,
     `translucency` ~0.72) — it frosts/occludes the 字 behind it (this is the "Liquid Glass" depth;
     it also avoids per-stroke glass artifacts on the glyph).
  3. **`ja.png`** — 字, deep celadon, Myeongjo serif, lower-right, **flat** (frosted by the panel above).
  4. **`background.png`** — solid celadon plate. Back.
  (Earlier drafts put the diagonal in a single background plate with glass *on* the glyphs; that
  produced droplet artifacts and no real occlusion — superseded by this panel-in-front model.)
- **FR-004 (reproducible generation)**: Layer PNGs (1024², no mask) are generated from a
  **checked-in CoreGraphics/CoreText script** (`bundling/icon-src/gen_icon.swift`), not hand-edited
  pixels, so the icon is rebuildable. Glyph fonts are **OFL** — **Pretendard-Black** (한) +
  **NotoSerifKR-Black** (字) — never SF/Apple system fonts for a baked logo glyph. The shipped
  artifact is the **rasterized PNG** (OFL permits unrestricted use of rendered output), so the
  fonts are **credited** (`THIRD_PARTY_DATA.md`), not vendored as binaries.
- **FR-005 (headless verify)**: The build self-verifies the composited glass renditions
  **headlessly** via the **bundled** Icon Composer `ictool --export-image` for Default / Dark /
  Tinted, before ASQi handoff. Use the bundled binary
  (`…/Icon Composer.app/Contents/Executables/ictool`) — **not** `xcrun ictool` (which resolves to a
  different, same-named binary).
- **FR-006 (compile, no Xcode)**: The icon compiles via
  `xcrun actool <Name>.icon --compile <out> --app-icon <Name> --include-all-app-icons
  --target-device mac --minimum-deployment-target 26.0 --platform macosx
  --output-partial-info-plist <p>` → `Assets.car` + `AppIcon.icns` (legacy fallback, auto-generated)
  + a partial plist with `CFBundleIconName` and `CFBundleIconFile`. No `.xcodeproj`.
- **FR-007 (bundle integration)**: `scripts/bundle.sh` compiles the icon and places `Assets.car`
  + `AppIcon.icns` into `Contents/Resources/` **before** the `codesign` step, and `bundling/Info.plist`
  carries `CFBundleIconName` + `CFBundleIconFile` (= `AppIcon`). A rebuild stays a single
  `bundle.sh` run.
- **FR-008 (compat)**: macOS 26+ renders the glass icon (Assets.car); macOS 14/15 renders the flat
  `.icns`. `LSMinimumSystemVersion` stays **14.0**.
- **FR-009 (no regression)**: `bundle.sh`'s existing steps (SwiftPM build, `HanjaKitCore` resource
  bundle copy, ad-hoc `codesign --deep --sign -`) keep working; the icon step does not break
  signing or the resource bundle.

## User scenarios
### Glass icon on macOS 26 (P1)
- **Given** a `.app` built by `bundle.sh` on macOS 26
- **When** the user sees it in Finder / Get Info / Login Items
- **Then** the celadon Liquid-Glass icon (한 front, 字 frosted behind) renders with depth.

### Flat fallback on macOS 14/15 (P1)
- **Given** the same `.app` on macOS 14 or 15
- **When** the user sees it in Finder
- **Then** the flat `AppIcon.icns` renders (no glass, but the correct celadon/한/字 artwork).

### Reads as Korean (P1)
- **Given** a first-time viewer
- **When** they glance at the icon
- **Then** the Hangul-forward 한 (+ 字) reads as a Korean Hangul→Hanja tool, not a Chinese one.

### One-command rebuild (P2)
- **Given** a developer with the repo
- **When** they run `scripts/bundle.sh`
- **Then** the icon is compiled and bundled with no Xcode project and no manual GUI step.

## Success criteria
- **SC-001**: `actool` compiles the `.icon` cleanly (exit 0, no crash) into `Assets.car` +
  `AppIcon.icns`. ✅
- **SC-002**: The built `.app` has `Assets.car` + `AppIcon.icns` in `Contents/Resources/` and
  `CFBundleIconName` + `CFBundleIconFile` in `Info.plist`; it stays validly ad-hoc signed. ✅
- **SC-003**: Glass renditions for Default/Dark/Tinted are self-verified via `ictool` before review;
  ASQi confirms the real rendered icon in Finder. ✅
- **SC-004**: Zero Xcode-project dependency; fonts are OFL and **credited**. ✅
- **SC-005**: No regression to the existing `bundle.sh` build/sign/resource flow. ✅

## Pipeline (verified this session)
- `.icon` is an **open package**: `icon.json` (top-level `fill`; `groups[].layers[]` with
  `image-name` → `Assets/`, `glass`/`glass-specializations`, `position`; per-group `shadow` /
  `translucency`; `supported-platforms`) + `Assets/*.png`. Colors as `display-p3:r,g,b,a`.
  References: `alienator88/Viz` (macOS-only), `sindresorhus/Gifski`.
- Layer PNGs generated headlessly with CoreGraphics + CoreText (1024², transparent fg, no mask).
- **`actool` exit 0** (no 26.5 crash for the macOS target) → `Assets.car` + auto `AppIcon.icns` +
  partial plist with both icon keys.
- **`ictool --export-image`** renders the composited glass preview headlessly (bundled binary; the
  `--export-preview` form in older blog posts is wrong — correct grammar:
  `--export-image --output-file … --platform macOS --rendition Default|Dark|TintedDark --width …
  --height … --scale … [--tint-color r g b --tint-strength s]`). Higher panel `translucency` = the
  layer behind shows through more.
- The app is **`LSUIElement`** (menu-bar agent, **no Dock icon**) → the app icon surfaces in
  Finder, Get Info, About, Login Items, DMG, and GitHub — not the Dock.

## Division of labor (build/run split)
- **Claude (build):** authored the layer generator + `icon.json` + `bundle.sh` wiring, and
  **self-verified** the Default/Dark/Tinted renditions via `ictool` before handoff.
- **ASQi (taste/run):** steered the design across iterations and **confirmed the real rendered icon
  in Finder** (2026-06-22). Optional further tuning lives in the Icon Composer GUI.
- The `.icon` + layer sources + generator live in the repo (`bundling/`).

## Milestones
- **M1 — app icon, end-to-end. ✅ DONE 2026-06-22.** The celadon `.icon` (celadon base → flat 字 →
  glass panel → 한) from `gen_icon.swift` (Pretendard + Noto Serif KR, OFL); `ictool` self-verify;
  `actool` compile; `bundle.sh` + `Info.plist` wiring; macOS-14 `.icns` fallback. ASQi-verified in
  Finder. Files: `bundling/AppIcon.icon/`, `bundling/icon-src/gen_icon.swift`, `bundling/Info.plist`,
  `scripts/bundle.sh`.
- **M2 — menu-bar template mark. ✅ DONE 2026-06-22** (`353ff4b`). A monochrome **字** vector-PDF
  template (`bundling/menubar-mark.pdf` from `gen_menubar.swift`, Noto Sans CJK KR), loaded with
  `NSImage.isTemplate` so it tints with the menu bar. **字 (not 한)** — a lone 한 clashes with the
  macOS Korean input-source indicator. ASQi-verified.
- **M3 — README demo + hero + social. ✅ DONE 2026-06-22.** Three looping demo GIFs (한자→漢字,
  가→歌, ㄱ→symbol; recorded with BetterCapture, optimized via ffmpeg + gifski) in README.md/en, plus a
  1280×640 hero/social card (`bundling/icon-src/gen_hero.swift`) used as the README banner and the
  GitHub social preview.
- *(Later, separate: Developer-ID code signing, notarization, DMG distribution.)*

## Resolved decisions
- **Fonts:** Pretendard-Black (한) + NotoSerifKR-Black (字), both OFL & installed (no download). No
  OFL *serif* font installed covers Hanja except Noto Serif KR — Gowun Batang / Nanum Myeongjo lack `字`.
- **Pale triangle = its own glass layer in front of 字** (not a flat background element). This is what
  produces the occlusion/frost depth and removes the per-stroke "droplet" artifact.
- **字 frost level:** panel `translucency = 0.72` + 字 deepened to `#1c3a2e` for "visible but frosted".
- **Dark variant:** skipped for M1 — the icon reads well across appearances (ASQi's call); can add later.
- **Fonts vendored?** No — ship the rasterized PNG (OFL output is unrestricted) and credit the fonts.

## Future expansion
M1 shipped without a separate `plan.md`/`tasks.md` (it stayed tractable). M2/M3 are small; spin up
those files only if either grows. Relates to `docs/specs/005`–`007`, `docs/BACKLOG.md`
"Public-release polish", and the build/run-split practice. A `/retro` is warranted to capture the
(highly reusable) Liquid Glass `.icon` + `actool`/`ictool` no-Xcode pipeline as a cross-project guide.
