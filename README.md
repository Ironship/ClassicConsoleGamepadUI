# ClassicGamepad

ClassicGamepad brings a familiar classic HUD to **WoW Forever's native gamepad mode**.
Version **0.1.0-alpha.1**, interface **16001**.

The addon activates when the player enables Gamepad Mode. Connecting a controller
alone does not activate it. Turning Gamepad Mode off restores the keyboard/mouse HUD.

## What it does

- Two horizontal action rows, classic square frames and Blizzard's gryphon artwork.
- Four visible groups: no trigger, LT, RT, and LT+RT. The active native layer gets a gold outline.
- Controller glyphs copied from the native prompts, including the modifier glyphs on each slot.
- Native action icons, counts, cooldowns, range/usability colors and press feedback.
- Native pages, stance/form overrides, pet actions and contextual targeting/shortcut actions.
- Player, target and focus frames use the last keyboard/mouse positions captured by the addon.
  On a first login directly into Gamepad Mode, it uses Blizzard's classic preset positions instead.

## How native gamepad support is preserved

The classic action rows **display the existing native buttons**. They do not take
ownership of bindings, cast spells, move protected action buttons or copy spells
between keyboard and gamepad slots. All actual controller actions remain native.

The native action HUD is exposed automatically while editing bindings, dragging an
action, or using a native action flyout. The classic view returns when that interaction
ends. Other windows keep their native gamepad navigation and prompts; this alpha does
not undo their controller-specific layouts.

The classic action slots are display-only for mouse use. Use **`/cgp native`** to get
the real clickable native action HUD, and **`/cgp classic`** to return. Native gamepad
controls continue working in either view. If protected mouse state cannot be changed
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
- `/cgp scale 0.9` — scale the action HUD (0.5–1.5, clamped to screen width).

## Current limits

**Rendering, secure execution/taint, physical controller behavior and FPS have not
been validated inside the game.** Alpha status is intentional. A file installation
does not establish those behaviors.

For the first in-game check: toggle Gamepad Mode on/off, hold each trigger combination,
change pages, edit a binding, open/close a flyout, and repeat in combat. Check the pet
or stance/form override on a class that has one. Verify the ordinary HUD returns.
For a quick rollback, use `/cgp off`; disabling the addon and restarting restores a
fully native session. No native keybindings, action slots or Edit Mode layouts are saved
or overwritten by this addon.

## Development

AI agents must follow [AGENTS.md](AGENTS.md): do not create or modify automated
tests unless the user explicitly requests them.

```powershell
python -P tools/package.py
```

Source baseline: Forever UI commit
[`172a387e3ab85b26e6640d3058d5ec1e6ccd4c63`](https://github.com/Gethe/wow-ui-source/tree/172a387e3ab85b26e6640d3058d5ec1e6ccd4c63).
See `docs/implementation.md` for the relevant source contracts.
