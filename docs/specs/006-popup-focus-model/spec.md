---
title: Popup focus model — stop stealing focus
status: implemented  # draft -> approved -> implemented
created: 2026-06-22
owner: ASQi
tags: [bug, focus, popup, ax, chromium, capture]
---

# Popup focus model — stop stealing focus

## Context & problem
The single-syllable candidate popup (`Sources/HanjaKey/PopupPanel.swift`) is shown with
`makeKeyAndOrderFront` **+ `NSApp.activate(ignoringOtherApps: true)`**. That activation **steals focus**
from the source app. Phase-1 debugging (instrumented `CaptureLog` runs in ChatGPT Atlas / Chromium,
2026-06-22) confirmed focus theft is the **single root cause** of a three-symptom cluster — all in
Chromium-based browsers; **Safari and native apps are unaffected**:

- **(a) List doesn't appear until re-focus.** Right after the synthetic capture keystrokes, HanjaKey's
  `activate` doesn't reliably "stick" in Chromium, so the panel shows but isn't usable until the user
  clicks the window again.
- **(b) Focus doesn't return to the source window.** *Already fixed this session*: `AppDelegate` records
  the frontmost app as `lastTarget` before presenting, and `PopupPanel.dismiss()` reactivates it on every
  close path. Logs now show `front=com.openai.atlas` after every dismiss. **Keep this.**
- **(c) The typed char evaporates.** Capture leaves the source run **selected** (so `⌘V` can replace it on
  pick). Stealing focus **blurs** the source field, destabilizing that selection. On **pick** it's fine
  (`⌘V` overwrites). On **cancel** the dangling selection is clobbered by the next keystroke → the char is
  lost. A right-arrow "collapse on cancel" was added and proven **ineffective** in Chromium (the field is
  blurred): logs show `collapseSel=true` cancels followed by the cancelled char missing (`바` 04:24:52→56,
  `가` 04:25:31→34).

Separately, `kAXFocusedUIElement` returns **-25212 (cannotComplete)** intermittently in Chromium even
after ~150 ms of retries (Chromium builds its AX tree lazily), so `AXContext.capture()` returns `nil` →
an empty popup.

The **happy path is solid** and must not regress: a long streak inserted 羅多羅馬四兒自車㻔他波下 flawlessly
(pick → `insert()` → `⌘V`). Only **cancel** and the **-25212 / AX-flaky** cases break.

This is app-layer only. `HanjaKitCore` (the pure engine + its unit tests) is untouched; focus/AX behavior
is GUI runtime, verified by the **build/run split** (Claude builds `.app` via `scripts/bundle.sh`, ASQi
runs it). Phase 1 is complete; this spec is the phase-2 approach + verification plan.

## Goals / non-goals
**Goals**
- The popup drives candidate selection **without stealing focus** from the source app, so the source field
  keeps focus and its selection/caret stay stable. This dissolves (a) and (c) at the root.
- Keep (b)'s fix; keep the proven pick→insert happy path; no regression in Safari / native (TextEdit) /
  Electron (Claude, Discord).
- Reduce empty popups by tolerating `-25212` during capture.

**Non-goals**
- Not re-ranking, gloss, or any `HanjaKitCore` engine change (this is `Sources/HanjaKey/` only).
- Not the 어절 capture/segmentation rethink (spec 003-deferred / BACKLOG; separate).
- Not removing the `CaptureLog` instrumentation yet — it stays until the cluster is verified fixed, then a
  later cleanup removes it (per its own doc-comment).
- Not adding any runtime network.

## Requirements
- **FR-001**: Showing the popup MUST NOT steal keyboard focus from the source app — the source field MUST
  retain focus and a stable selection/caret while the popup is open. (Remove `NSApp.activate` from the
  present path.)
- **FR-002**: While the popup is open, the driver keys (**1–9, ↑ ↓ ← →, Tab, ↵/Return, esc**) MUST reach
  the popup and MUST NOT leak into the source field.
- **FR-003**: Cancelling (esc / click-away / hotkey toggle) MUST leave the source text exactly as the user
  typed it — no lost char, no dangling selection. With focus no longer stolen, cancel is a true no-op
  (no blur), so the ineffective right-arrow collapse-on-cancel MUST be removed.
- **FR-004**: Picking a candidate MUST still insert in place (the current `insert()` ⌘V path), unchanged in
  behavior.
- **FR-005**: Focus return on dismiss (the `lastTarget` reactivate, FR-(b)) MUST be preserved as a safety
  net.
- **FR-006**: When `kAXFocusedUIElement` fails (-25212), capture SHOULD still attempt the `⌘C` auto-capture
  path (it uses synthetic keys, not the AX element) and fall back to `NSEvent.mouseLocation` for popup
  placement, instead of returning `nil` immediately. Empty popups SHOULD drop.
- **FR-007**: The fix lives entirely in `Sources/HanjaKey/`; `HanjaKitCore` and its tests are unchanged.

## Approach (the pivotal unknown decides A1 vs A2)
Two implementations satisfy FR-001/FR-002. The deciding unknown can only be settled by a real run.

- **A1 (simple, try first).** Remove `NSApp.activate`; rely on the existing `.nonactivatingPanel`
  (`canBecomeKey = true`) to become key via `makeKeyAndOrderFront` / `orderFrontRegardless` and receive
  `keyDown` **without activating HanjaKey**. **UNKNOWN:** whether a non-active app's nonactivating panel
  reliably delivers SwiftUI `.onKeyPress` events, and whether driver keys stay out of the source field.
  If yes → minimal change, done.
- **A2 (robust fallback).** Keep the source app focused; install a **`CGEventTap`** (AX permission already
  granted) that, while the popup is open, intercepts the driver keys → routes them to the popup → and
  **swallows** them (returns `nil`) so they never reach the source field; all other keys pass through.
  More code (an event-tap controller + open/close lifecycle), but deterministic. Only a tap can swallow
  events (an `NSEvent` global monitor cannot).

**Plan:** implement A1, validate with one logging run; fall back to A2 if keys don't land in the popup or
leak into the field.

**REVISION (2026-06-22, after the A1 run):** A1 **failed** — with `NSApp.activate` removed the panel does
not render at all (in any app); `present` logged `visible=true` but nothing drew, because a floating panel
of an *inactive* agent app isn't shown above other apps. **The popup requires activation to display, so
focus theft is unavoidable with this NSPanel — A1 and A2 (both "don't steal focus") are infeasible.**
Pivot: keep the focus-steal, and fix char-loss (c) at the **selection layer** — `AXContext.capture()`
**collapses its probe selection immediately, while focus is still clean** (a right-arrow to the run's right
edge = the original caret), and `insert()` re-selects via `selectBack` before ⌘V. No live selection is
left, so cancel can't clobber the text. (b) focus-return and FR-006 (-25212 → AX-less ⌘C capture) are kept.
This supersedes FR-001/FR-003 wording: focus IS stolen (FR-001 dropped); the *cancel-time* collapse is
replaced by the *capture-time* collapse (FR-003 met a different way). Remaining risk: the `insert()`
re-select (Shift+Left after the focus round-trip) could mis-select if Chromium moves the caret on blur —
validated OK on 2026-06-22.

**REVISION 2 (2026-06-22, cold-start — the actual root):** a remaining bug was that the **first** invocation
after launch never rendered (`onScreen=false` for 18 s on a single patient press) — focus went "weird" /
switched windows. Cause: **macOS 14 denies `activate(ignoringOtherApps:)` to an app the user hasn't clicked**
(a global hotkey doesn't count), so HanjaKey isn't truly frontmost on the cold first call; with
`hidesOnDeactivate = true` the floating panel was then hidden as "deactivated" and never drew. (This was
**also the real reason A1 failed** — not the dropped activate, but the auto-hide.) **Fix: set
`hidesOnDeactivate = false`** (the floating panel renders regardless of active state) **+ a global
outside-click monitor** for dismissal (replacing the auto-hide). All five symptoms — cold-start,
list-appears, focus-return, char-loss, pick-in-place — confirmed fixed in ChatGPT Atlas + Safari.

## User scenarios
### Type-then-convert in a Chromium field (P1)
- **Given** a ChatGPT Atlas (Chromium) text/search field with a freshly typed `가`
- **When** the user presses ⌥⌘H
- **Then** the candidate list appears on the **first** press (no manual re-focus), and the source field
  keeps focus.

### Cancel keeps the char (P1)
- **Given** the popup open for `가`
- **When** the user presses esc (or clicks away)
- **Then** `가` remains in the field intact, and the next typed char appends (no clobber).

### Pick still inserts (P1 — regression guard)
- **Given** the popup open for `가`
- **When** the user picks 家
- **Then** `家` replaces `가` in place (current behavior), in Chromium and Safari/native/Electron alike.

### AX momentarily unavailable (P2)
- **Given** Chromium returns -25212 for the focused element
- **When** the user presses ⌥⌘H
- **Then** capture still tries the ⌘C path (popup near the mouse) instead of showing an empty popup.

## Success criteria
- **SC-001**: In Chromium (Atlas), the list appears on the first hotkey without manual re-focus.
- **SC-002**: In Chromium, esc/cancel leaves the typed char intact (zero char loss across a 20-cancel run).
- **SC-003**: Focus stays with the source field while the popup is open and after it closes.
- **SC-004**: Picking still inserts in place — no regression in Chromium, Safari, TextEdit, or Electron.
- **SC-005**: Empty-popup rate from -25212 drops versus the current build.
- **SC-006**: `HanjaKitCore` unit tests stay green (unchanged); `swift build` + `scripts/bundle.sh` succeed.

## Open questions
- [NEEDS CLARIFICATION: Does A1's nonactivating panel actually receive SwiftUI `.onKeyPress` without app
  activation, without leaking driver keys into the source field? This decides A1 vs A2 and needs one real
  run. — leaning: try A1 first.]
- [NEEDS CLARIFICATION: If A2, confirm `CGEventTap` (not an `NSEvent` global monitor — only a tap can
  swallow events); where to host its lifecycle (AppDelegate vs PopupPanel).]
- [NEEDS CLARIFICATION: With focus no longer stolen, is `hidesOnDeactivate = true` still the right
  click-outside dismissal, or is an explicit outside-click / resign monitor needed? (HanjaKey may no
  longer "deactivate" since it never activated.)]
- [NEEDS CLARIFICATION: Keep the `lastTarget` reactivate-on-dismiss safety net once focus isn't stolen?
  — leaning: keep as defense.]

## Future expansion
If A2 (event tap) is needed and grows, add a `plan.md` (tap lifecycle, key routing table, swallow rules)
and `tasks.md` (implement → build → ASQi run-verify per app) alongside this file. Not created yet — the
change is expected to be small enough to implement directly from this spec once A1 vs A2 is settled.
