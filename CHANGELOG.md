# Changelog

## 0.1.0-alpha.51

- Switching compact bars (8 slots) off in Settings no longer leaves the keyboard keys dead until a UI reload:
  the click layer checks once a second that its key bindings are still active and applies them again if the
  client dropped them. `/cgp status` shows how often (`rebound=`).
- A slot with two modifier glyphs (LT + RT) puts the button glyph on a second row instead of drawing it over them.
- Keyboard labels on the slots are short and cut to the slot width: mouse buttons read `Mouse4`, `Wheel+`, with
  modifiers as `S-`, `C-`, `A-`, instead of long names that spilled over the neighbouring slots.

## 0.1.0-alpha.50

- "Move the legend below the player frame" is marked experimental and is off by default, for new and existing
  installs alike (the saved choice is reset once, because it was on without ever being chosen). With it off the
  legend keeps its native position.

## 0.1.0-alpha.49

- The gamepad legend no longer sits under chat: when its place below the player frame lands on chat, it moves above
  chat, or beside it, wherever it fits on screen clear of the player, target and focus frames.
- Text other addons draw on the native action buttons (SpellDamageInfo's damage and healing numbers, bar addons'
  labels) is copied onto the classic bars. The native buttons are faded while the classic bars show, so that text
  was invisible.
- Confirm secure mouse snippets completed before caching success.
- Check frame availability outside the restricted environment; restore accessible
  frames even when another recorded frame is forbidden, and report skipped frames.
- Record display errors before attempting cleanup or refreshing other modules.

## 0.1.0-alpha.48

- Restore native mouse input after click-layer failures without repeating the failed frame-tree walk.
  Cleanup deferred by combat is retried after combat; cleanup failures are reported.
- Retain the last Lua error in diagnostics. `/cgp debug` also works with visible classic bars.
- Skip unchanged diagnostic updates and create the debug overlay only on request.
  The live HUD still refreshes at 10 Hz for states not fully covered by native hooks.
- Packaging and CI validate runtime files with Lua 5.1 before creating a ZIP.

## 0.1.0-alpha.47

- License changed to All Rights Reserved (earlier versions stay under the MIT License they were released with).
- No code changes.

## 0.1.0-alpha.46

- Shorter README. The repository is now called ClassicConsoleGamepadUI; the TOC website points to it.
- No code changes.

## 0.1.0-alpha.45

- The classic bars in the action editor are drawn one strata above the editor's dimmed background
  (they were still behind it: the editor raises itself above any frame level in its own strata).
- `/cgp taint` also names the fields of the gamepad focus, navigation, binding and action-bar state
  that other addons tainted, so a block blamed on another addon can be traced to a field.

## 0.1.0-alpha.44

- 12-slot layout: the last main-row positions (keys `0`, `-`, `=`, and `9` when the character has no
  class action) now show their keyboard labels and mirror the keyboard bar's button at that position.
  The key, or a mouse click, triggers that action; you can drag an action onto the slot with the mouse.
  Empty positions keep the empty-slot plate with the key label.

## 0.1.0-alpha.43

- Diagnostics for blocked protected actions such as `SetOverrideBindingClick()` (seen when the
  death popup opens in combat) and `SetPreferredGamepadInteractTarget()`. Every block attributed
  to this addon is now saved, for any protected function, with the stack and a trace of the last
  operations the addon performed on Blizzard frames. The first block also lists the tainted
  native fields.
- `/cgp taint` lists the native fields this addon has tainted so far, so the step that introduces
  the taint can be found by running it after each step of a reproduction.
- No change in behaviour; this release only adds diagnostics.

## 0.1.0-alpha.42

- The action editor ("Bind to Action Bar", "Edit Action Bar") now shows the classic
  bars instead of the native crossbar. They mirror the editor's own bars (including
  the page you switch to), are drawn above its dimmed background and are not
  clickable while it is open. The page tracker with the page-switch hint stays.
- If drawing the classic bars fails, the native bars are restored instead of staying faded.

## 0.1.0-alpha.41

- Removed the Steam Deck preset and `/cgp deck`. It only set existing options;
  the Steam Deck tips in the README cover the same choices.

## 0.1.0-alpha.40

- Removed **Upper row shift** (and `/cgp shift`). It only nudged the compact upper
  row sideways and did nothing in the 12-slot layout. The upper row now starts
  directly above the first bottom slot automatically.
- Compact layout: the bags move under the right end of the upper row, closing the
  empty gap left in the bottom row by the relocated micro menu.
- Chat no longer jumps while bar settings change: it is not reset on every rebuild,
  and its clearance is measured once the rebuilt bars have settled.

## 0.1.0-alpha.39

- Fix: after switching to 12 slots, the extra upper slots (buttons 9-12 of each
  bar) showed no keyboard labels while Settings stayed open. Labels now follow the
  visible slots immediately, also when a slot appears without a layout change.

## 0.1.0-alpha.38

- Fix: `Layout.lua` failed to load in the game's Lua 5.1 ("ambiguous syntax"),
  so the classic HUD never appeared and `Core.lua` reported `Layout` as nil.
  Alpha.37 should not be used.

## 0.1.0-alpha.37

First release as **ClassicConsoleGamepadUI** (previously ClassicGamepad).
Settings from ClassicGamepad are not carried over; disable or remove the old
`ClassicGamepad` folder, which this addon reports as a conflict.

- Steam Deck preset in Settings and `/cgp deck`: compact bars, larger controller
  and LT/RT glyphs, tighter gaps, no keyboard labels.
- Easy deletion (X, X, A, A) draws above the confirmation dialog, greys completed
  presses, highlights the next one and hides the repeated confirmation line.
- Fewer blocked `SetPreferredGamepadInteractTarget` actions: in Gamepad Mode the
  addon no longer opens, switches or closes Blizzard panels from its own code.
  `/cgp`, `/cgp edit` and the settings buttons print the native route instead.
- Hidden keyboard bars are measured without changing their Edit Mode visibility.
- 12-slot layout: empty main-row positions keep the stock empty-slot plate.
- The diagnostic text line appears only with `/cgp debug`.
