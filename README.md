# ClassicConsoleGamepadUI

ClassicConsoleGamepadUI brings a familiar classic HUD to **WoW Forever's native gamepad mode**.
Version **0.1.0-alpha.45**, interface **16001**.

The addon activates when the player enables Gamepad Mode. Connecting a controller
alone does not activate it. Turning Gamepad Mode off restores the keyboard/mouse HUD.
Keyboard anchors are captured only from visible frames after the native keyboard
layout has finished applying. Hidden-bar placeholders are excluded. Older cached
anchors are rebuilt once; input-mode changes retain the new layout applied by the game.

## What it does

- Three compact 8-slot bars by default, with an optional 12-slot layout. Borders,
  end caps and page arrows come directly from the client's keyboard/mouse UI.
  A filled slot draws that action's icon inside the frame and hides the empty-slot
  plate, so the plate does not read as a second icon. An empty slot keeps only the
  flat slot background. Buttons and end caps retain their original sizes;
  the main border, menu/bag positions and experience/reputation bars fit the shorter HUD.
- The real Blizzard micro menu, bags and experience/reputation bars.
- **Settings → AddOns → ClassicConsoleGamepadUI** (`/cgp` opens it in keyboard/mouse mode) has 20 settings:
  enable the HUD, choose compact bars, adjust shoulder/class
  indicator spacing, position the micro menu, resize controller glyphs and LT/RT hints independently, toggle
  keyboard labels, menu hints and active-layer highlighting, position the legend,
  position chat from the screen edges, and toggle chat avoidance with a configurable gap. The same scrollable panel
  includes bar-key assignment, the native keybinding editor, action assignments
  across gamepad pages and LT/RT layers, and the game's controller options.
  Changes preserve mouse, keyboard and controller input; protected layout changes
  wait until combat ends. The game's **Defaults** button resets these options.
  Settings use the game's addon saved-variable settings. Only bar geometry options
  rebuild the HUD; toggling Easy deletion does not rebuild bars or refresh native tooltips.
  LT/RT hints default to 150% and can be scaled from 60% to 250%.
- Optional **Easy deletion: X, X, A, A** replaces the long controller sequence in
  item destruction dialogs. It is off by default and operates outside combat.
  It recognizes the controller-specific confirmation dialogs opened through
  **Y → Destroy**, including valuable items and quest items, and hides their
  original sequence while showing XXAA in the same place, drawn above the dialog.
  Completed presses turn grey and the next expected button is highlighted, like the
  native sequence. The repeated "Press the button sequence to confirm." line is hidden.
  The fourth press clicks the game's own confirmation button; B still cancels,
  and a wrong button resets progress. Other confirmation dialogs retain their
  native behavior. The addon never deletes an item without this confirmation.
- Micro-menu tooltips include controller glyphs: the current direct binding, or the
  native radial-menu route (menu button, page shoulder button if needed, and right-stick
  direction). Panels without either route are shown as unbound. Existing keyboard hints remain.
- Compact layout: the upper row has eight L2 (LT) actions on the left and eight
  R2 (RT) actions on the right. They highlight in place when their trigger is pressed.
  The bottom eight slots show the no-trigger layer, native L1/R1 (LB/RB) targeting
  or shortcut actions, or the L2+R2 layer while both triggers are active.
  The upper row starts directly above the first bottom slot, and the bags sit under
  the right end of the upper row, closing the space the micro menu used to fill.
  Gryphons and the experience/reputation bars close up to that shorter span, and the whole bar is centered.
  The micro menu sits on the right edge of the screen, flush with the bottom edge
  by default. Both edge distances are configurable in `/cgp`.
  Each row of eight shows the face buttons (X, Y, B, A) on the left and the directional cross on the right.
  The bottom row reads 1 through 8 from the left.
  The left shoulder indicator stays above the left end of the upper row. The right shoulder indicator sits above the far-right upper slot.
  A class action is shown above the upper row only while its native button is visible. An empty class slot is hidden, so it does not show a leftover keyboard number.
  Shoulder and class-action glyphs follow current controller bindings and native press feedback.
- Extended layout: disable **Compact bars (8 slots)** in `/cgp` for three 12-slot
  bars. The main bar adds two class actions and two spare slots. A position without a
  native gamepad action (the second class action, and the two spare slots, i.e. keys `0`, `-` and `=`)
  mirrors the keyboard bar's button at the same position: it shows that action's icon and cooldown, its
  key triggers it, and you can click it or drop an action onto it with the mouse. Place those actions
  in keyboard mode, or drag them from the spellbook or bags. An empty position shows the stock
  empty-slot plate with its key label, so the row has no gaps. Each upper section
  adds four L2+R2 actions, so all 32 native gamepad actions are visible at once.
  It uses the same native action storage and bindings; the layout does not add
  extra actions to a native eight-action trigger layer.
- Controller glyphs copied from the native prompts, including the modifier glyphs on each slot.
- Native action icons, counts, cooldowns, range/usability colors and press feedback.
- Left-click actions with the mouse, or use the keyboard bindings of their classic
  bar positions. Both activate the action currently shown in that position, including
  native page and contextual changes. Keyboard hints appear at the bottom left of
  the buttons, alongside the controller glyphs. Keyboard presses follow the game's
  key-down setting; mouse casting happens on release so dragging remains available.
  Press feedback follows both click phases, and clears on release, hiding or dragging.
  Extended slots read the existing bindings of their classic bar positions,
  including buttons 9-12 of each upper bar. Hidden stock buttons do not need to
  initialize their hotkey labels first. Saved keybindings are preserved.
- Native pages, stance/form overrides, pet actions and contextual targeting/shortcut actions.
- Drag actions onto or off the classic slots outside combat, including item shortcuts
  from bags. Dragging and the controller cursor keep the classic HUD visible.
- Player, target and focus frames use the last keyboard/mouse positions captured by the addon.
  On a first login directly into Gamepad Mode, it uses Blizzard's classic preset positions instead.
- The native controller legend sits below the player frame with a configurable 12-point default gap,
  keeping the restored frame readable. Its original anchor returns when the classic
  HUD is disabled or Gamepad Mode is turned off.
- **Chat → Position chat from screen edges** enables independent left and bottom
  distances, both defaulting to 0. Zero places the outer chat bounds at the screen
  edge, including the input box and controller prompts. Edge positioning is off by
  default, preserving existing Edit Mode positions.
- **Move chat above the action bar** independently raises chat when it overlaps the
  classic bars or end caps, leaving a configurable 12-point default gap. Disable it
  for an exact bottom-edge position. Changing bar settings no longer makes chat jump:
  its clearance is measured once the rebuilt bars have settled. Chat can move back down as the gap or bar
  layout changes; offsets do not accumulate. Width and height stay as configured,
  and docked tabs move together. Native dragging and resizing establish a new base
  position; native view restores the original anchors.

Alpha.2 replaces alpha.1's custom panel, hand-picked artwork and four-group layout.
The action order follows the controller layers rather than the keyboard's spell assignments.
UI scale and captured bar scale come from the original frames.

Keyboard/mouse mode keeps the native 12-slot HUD. Layout changes requested in combat
apply after combat ends.

## Steam Deck

The client has no separate Steam Deck mode: the Deck is a controller in Gamepad Mode.
Steam Input reports Xbox-style A/B/X/Y, so the glyphs match the Deck's face buttons.

- **Compact (8 slots)** fits the 1280×800 screen best and needs no extra buttons.
- **12 slots** shows all 32 native actions. Their extra slots also answer to the
  keyboard bindings of their classic bar positions, so the back grips (L4/L5/R4/R5)
  can trigger them: map a grip to a keyboard key in Steam Input, then assign that key
  to the slot with **Assign keys from the bars**.
- The touchscreen acts as a mouse: tap a classic slot to use it, or drag actions
  between slots outside combat.
- On a 7" screen, raise **Controller button glyph size** and **LT/RT hint size**
  rather than the global UI scale; the bar keeps its classic proportions.

## How native gamepad support is preserved

The classic action rows display the existing native gamepad actions. A separate
secure input layer handles mouse clicks and temporarily routes the saved keyboard
bar bindings to those visible actions. It reads the native source and action ID at
the hardware event, including changes made during combat. Reserved controls and
flyouts use their native click handlers; ordinary actions and pet actions use the
game's secure action buttons. Saved keyboard bindings and keyboard/gamepad action
assignments are not rewritten or synchronized. Leaving the classic HUD clears its
temporary keyboard overrides. The controller keeps using the game's native bindings.

Input frames are created and positioned outside combat. Changes to layout, addon
enable/disable or `/cgp native` requested during combat apply after combat ends.

The game's action editor ("Bind to Action Bar" and "Edit Action Bar", opened from the
spellbook or the native edit button) keeps the classic bars: they mirror the editor's own
crossbar, which is faded out, and are drawn one strata above the editor's dimmed background. The
classic bars are not clickable while the editor is open; its page tracker (current page and
the button hint for changing pages) stays visible. The native HUD is exposed automatically
in Edit Mode and while a native action flyout is open; the classic view returns when that
interaction ends. Other windows keep their native gamepad navigation and prompts; this alpha
does not undo their controller-specific layouts.

Classic slots accept mouse drag/drop outside combat. Pickup follows the game's
action-bar lock setting and its pickup modifier (normally Shift). Dropping onto an
occupied slot leaves its previous action on the cursor. Reserved controller controls
and contextual actions without editable storage cannot be reassigned this way; pet
slots accept pet actions. **`/cgp native`** shows the original controller HUD;
use **`/cgp classic`** to return.
If protected mouse state cannot be changed
during combat, its restoration waits until combat ends. A first activation in combat
also waits for combat to end.

This alpha does not combine with **ControllerForever** or **ConsolePort**; if either
is loaded, ClassicConsoleGamepadUI leaves the native HUD in place and reports the conflict.

## Installation

**CurseForge / manual:** download `ClassicConsoleGamepadUI-<version>.zip`. It contains a
single `ClassicConsoleGamepadUI` folder. Extract the ZIP into Forever's `Interface/AddOns` directory so the result is
`Interface/AddOns/ClassicConsoleGamepadUI/ClassicConsoleGamepadUI_Camelot.toc`. Start/restart the client,
enable ClassicConsoleGamepadUI in the addon list, then enable Gamepad Mode normally.

Upgrading from **ClassicGamepad**: remove the old `Interface/AddOns/ClassicGamepad`
folder. Both would drive the same HUD, so ClassicConsoleGamepadUI stays inactive and
reports the conflict while the old addon is loaded. Its settings start from defaults.

Commands:

- `/cgp` / `/cgp settings` — open ClassicConsoleGamepadUI settings (keyboard/mouse mode). In
  Gamepad Mode it prints the menu route instead: **Options → AddOns → ClassicConsoleGamepadUI**.
- `/cgp bindings` — open the game's binding editor (keyboard/mouse mode; route in Gamepad Mode).
- `/cgp edit` — show how to open the native gamepad action editor: its bound button,
  or `/click GamepadActionBarEditFrameEnterEditMode` typed in chat.
- `/cgp debug` — toggle the diagnostic text line shown while the classic HUD is inactive.
- `/cgp status` — version, state and the last layout/input diagnostic. It also reports how many blocked actions were saved this session.
- `/cgp taint` — list the native gamepad, navigation, binding, chat and action-bar fields this addon has tainted (read-only), with the other addons' counts, and name any field of the gamepad focus, navigation, binding and action-bar state that another addon tainted. The result is saved. Run it after each step of a reproduction to find the step that introduces the taint.
- `/cgp on` / `/cgp off` — enable/disable the visual changes.
- `/cgp native` / `/cgp classic` — temporarily switch the action HUD in this session.

## Current limits

The `SetPreferredGamepadInteractTarget` block: alpha.33 diagnostics showed native
navigation and binding tables (`SmartNavigation.hookedButtons`, `selectButtonSequence`,
`PageUnit.activeBar`, `activeBindings.PAD1/PAD2/D-pad`) tainted by ClassicConsoleGamepadUI.
That state is created when Settings or the native action editor opens. Alpha.36
therefore never opens, switches or closes Blizzard panels from addon code in
Gamepad Mode (`/cgp`, the settings buttons and `/cgp edit` print the native route),
and measures hidden keyboard bars with their C `Show`/`Hide` methods, which leave
Edit Mode visibility state untouched. Other addons can still taint the same shared
tables; the error then names them. Confirmation in the game is still required.
Old diagnostic snapshots are cleared when a new version loads.
Classic slot tooltips read action/spell/pet data directly; they never call the native
button's `SetTooltip`, which writes its `UpdateTooltip` field in addon execution.
Diagnostic `version` identifies the loaded Lua; `tocVersion` separately records the
client's addon metadata. Packaging requires the Lua and TOC versions to match.
The first observed ClassicConsoleGamepadUI-owned taint on selected native focus, navigation
and binding fields is recorded with its observation stage and call stack in
`ClassicConsoleGamepadUIDB.diagnostics.firstTaint`. A secure post-hook observes native button
selection before the next refresh tick. The observer stops after that first record.
Every block attributed to ClassicConsoleGamepadUI (`ADDON_ACTION_BLOCKED` in combat or
`ADDON_ACTION_FORBIDDEN` out of combat, for any protected function; up to six per session) is saved in
`ClassicConsoleGamepadUIDB.diagnostics.blocked` with the protected function, whether the player
was in combat, the call stack, and a trace of the last operations this addon performed on Blizzard
frames (relative seconds). The first block of a session also lists the tainted native fields, found
by a read-only scan two levels deep. The first-taint record carries the same trace and scan.
This does not change native tables or bypass the protected function. Tainted fields can be
legitimate addon data; their presence alone does not identify the cause. Records belong to the
session and version that captured them.
A `taint.log` from
`/console taintLog 2` is needed to trace the first tainted execution. Turn logging
off with `/console taintLog 0` after reproducing the problem.

**Rendering, secure execution/taint, physical controller behavior and FPS have not
been validated inside the game.** Alpha status is intentional. A file installation
does not establish those behaviors.

For the first in-game check: toggle Gamepad Mode on/off, hold each trigger combination,
change pages, edit a binding, open/close a flyout, and repeat in combat. Check the pet
or stance/form override on a class that has one. Verify the ordinary HUD returns.
For a quick rollback, use `/cgp off`; disabling the addon and restarting restores a
fully native session. The addon stores copies of keyboard/mouse frame anchors in its
own saved variables. It does not automatically overwrite native bindings or saved
Edit Mode layouts. Explicit changes made in the game's binding/action editors are
saved by the game.

## Development

AI agents must follow [AGENTS.md](AGENTS.md): do not create or modify automated
tests unless the user explicitly requests them.

```powershell
python -P tools/package.py --output <release folder>
```

The ZIP is CurseForge-ready: one top-level `ClassicConsoleGamepadUI` folder with both
TOC files, runtime Lua, README, CHANGELOG and LICENSE; no development files.

Source baseline: Forever UI commit
[`ca8368f2f2380cbe696854f7f2646387c278a61b`](https://github.com/Gethe/wow-ui-source/tree/ca8368f2f2380cbe696854f7f2646387c278a61b).
See `docs/implementation.md` for the relevant source contracts.
