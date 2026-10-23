# Changelog

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
