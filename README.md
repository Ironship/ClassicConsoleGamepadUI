# ClassicGamepad

ClassicGamepad brings a familiar classic HUD to **WoW Forever's native gamepad mode**.
Version **0.1.0-alpha.4**, interface **16001**.

The addon activates when the player enables Gamepad Mode. Connecting a controller
alone does not activate it. Turning Gamepad Mode off restores the keyboard/mouse HUD.

## What it does

- The stock 12-slot main bar and two 12-slot bottom multibars in their original positions.
  Slot backgrounds, borders, masks, end caps and page arrows are copied directly from
  the client's keyboard/mouse UI, with their actual dimensions and positions.
- The real Blizzard micro menu, bags and full-width experience/reputation bars.
- Micro-menu tooltips include controller glyphs: the current direct binding, or the
  native radial-menu route (menu button, page shoulder button if needed, and right-stick
  direction). Panels without either route are shown as unbound. Existing keyboard hints remain.
- Native no-trigger, LT, RT and LT+RT actions fill those slots; the active layer's
  slots light up with the stock button highlight. Four remaining slots show the
  native class actions and shoulder indicators.
- Controller glyphs copied from the native prompts, including the modifier glyphs on each slot.
- Native action icons, counts, cooldowns, range/usability colors and press feedback.
- Native pages, stance/form overrides, pet actions and contextual targeting/shortcut actions.
- Drag actions onto or off the classic slots outside combat, including item shortcuts
  from bags. Dragging and the controller cursor keep the classic HUD visible.
- Player, target and focus frames use the last keyboard/mouse positions captured by the addon.
  On a first login directly into Gamepad Mode, it uses Blizzard's classic preset positions instead.

Alpha.2 replaces alpha.1's custom panel, hand-picked artwork and four-group layout.
The action order follows the controller layers rather than the keyboard's spell assignments.
UI scale and captured bar scale come from the original frames.

## How native gamepad support is preserved

The classic action rows **display the existing native buttons**. They do not take
ownership of bindings, cast spells, move protected action buttons or synchronize
keyboard and gamepad assignments. Mouse drag/drop edits the native gamepad storage
slot represented by the visible icon. All actual controller actions remain native.

The native action HUD is exposed automatically while editing bindings or using a
native action flyout. The classic view returns when that interaction
ends. Other windows keep their native gamepad navigation and prompts; this alpha does
not undo their controller-specific layouts.

Classic slots accept mouse drag/drop outside combat. Pickup follows the game's
action-bar lock setting and its pickup modifier (normally Shift). Dropping onto an
occupied slot leaves its previous action on the cursor. Reserved controller controls
and contextual actions without editable storage cannot be reassigned this way; pet
slots accept pet actions. Mouse spell casting still uses **`/cgp native`**; use
**`/cgp classic`** to return. Native gamepad controls continue working in either view.
If protected mouse state cannot be changed
during combat, its restoration waits until combat ends. A first activation in combat
also waits for combat to end.

This alpha does not combine with **ControllerForever** or **ConsolePort**; if either
is loaded, ClassicGamepad leaves the native HUD in place and reports the conflict.

## Installation

Extract the ZIP into Forever's `Interface/AddOns` directory so the result is
`Interface/AddOns/ClassicGamepad/ClassicGamepad_Camelot.toc`. Start/restart the client,
enable ClassicGamepad in the addon list, then enable Gamepad Mode normally.

Commands:

- `/cgp` — version, current state and command help.
- `/cgp on` / `/cgp off` — enable/disable the visual changes.
- `/cgp native` / `/cgp classic` — temporarily switch the action HUD in this session.

## Current limits

**Rendering, secure execution/taint, physical controller behavior and FPS have not
been validated inside the game.** Alpha status is intentional. A file installation
does not establish those behaviors.

For the first in-game check: toggle Gamepad Mode on/off, hold each trigger combination,
change pages, edit a binding, open/close a flyout, and repeat in combat. Check the pet
or stance/form override on a class that has one. Verify the ordinary HUD returns.
For a quick rollback, use `/cgp off`; disabling the addon and restarting restores a
fully native session. The addon stores copies of keyboard/mouse frame anchors in its
own saved variables. It does not overwrite native keybindings, action slots or saved
Edit Mode layouts.

## Development

AI agents must follow [AGENTS.md](AGENTS.md): do not create or modify automated
tests unless the user explicitly requests them.

```powershell
python -P tools/package.py
```

Source baseline: Forever UI commit
[`172a387e3ab85b26e6640d3058d5ec1e6ccd4c63`](https://github.com/Gethe/wow-ui-source/tree/172a387e3ab85b26e6640d3058d5ec1e6ccd4c63).
See `docs/implementation.md` for the relevant source contracts.
