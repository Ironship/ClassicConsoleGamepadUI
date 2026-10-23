# Changelog

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
