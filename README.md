# ClassicConsoleGamepadUI

Gamepad support for WoW Forever, with the classic look and feel.

Turn on Gamepad Mode and keep the normal keyboard-and-mouse UI on screen. The game's own
controller controls stay as they are. Simple settings, not much to configure.

Version 0.1.0-alpha.46. Alpha: expect bugs.

## What it does

- Classic action bars with the controller buttons shown on the slots (X, Y, B, A, LT, RT layers).
- Compact bars (8 slots) or full bars (12 slots).
- Mouse clicks, drag and drop and keyboard keys work on the bars.
- Classic micro menu, bags, unit frames and experience bar.
- Controller button hints in micro menu tooltips.
- Easy item deletion: X, X, A, A.
- Chat, controller legend and micro menu position options.
- The classic bars stay visible in the game's action editor.
- Turning Gamepad Mode off brings back the normal UI.

## Settings

Options > AddOns > ClassicConsoleGamepadUI. The defaults should be fine.

Commands: `/cgp` (or `/classicconsolegamepadui`)

- `/cgp on`, `/cgp off`: turn the classic look on or off.
- `/cgp native`, `/cgp classic`: switch the action bars for this session.
- `/cgp bindings`, `/cgp edit`: how to open the key bindings and the action editor.
- `/cgp status`: current state and the last problem found.

## Steam Deck

The game sees the Deck as a controller in Gamepad Mode. Use 8-slot bars, or 12 slots if you
map the back buttons to keys.

## Install

Extract the ZIP into `Interface/AddOns` so you get `Interface/AddOns/ClassicConsoleGamepadUI`.
Remove the old `ClassicGamepad` folder if you have it. It does not work together with
ControllerForever or ConsolePort.

## Problems

Report them on GitHub. `/cgp taint` lists what the addon changed in the game's controller code,
which helps with "action blocked" errors.

## Development

AI agents: see [AGENTS.md](AGENTS.md); do not write tests unless asked. Build the ZIP with
`python -P tools/package.py`. Details of how it works are in `docs/implementation.md`.

License: MIT.
