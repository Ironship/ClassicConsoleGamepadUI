# ClassicConsoleGamepadUI

Gamepad support for WoW Forever, with the classic look and feel.

I wanted Gamepad mode but with support for both keyboard-and-mouse UI on screen. The game's own controller controls stay as they are. Simple settings, not much to configure.

Version 0.1.0-alpha.59. Alpha: expect bugs.

## Compact mode (best for Xbox gamepad)

![1](https://github.com/user-attachments/assets/19bbc0d2-2a85-47e0-8dbf-571e4d98240d)

## Classic mode

![4](https://github.com/user-attachments/assets/b2f037a4-de36-43ad-8367-776f567c6661)

[https://github.com/user-attachments/assets/981190c8-374b-48dc-9a8c-b1337b2b1fcb](https://github.com/user-attachments/assets/981190c8-374b-48dc-9a8c-b1337b2b1fcb)

## What it does

*   Classic action bars with the controller buttons shown on the slots (X, Y, B, A, LT, RT layers).
*   Compact bars (8 slots) or full bars (12 slots).
*   Mouse clicks, drag and drop and keyboard keys work on the bars.
*   Classic micro menu, bags, unit frames and experience bar.
*   Controller button hints in micro menu tooltips.
*   Easy item deletion: X, X, A, A.
*   Chat, controller legend and micro menu position options.
*   The classic bars stay visible in the game's action editor.
*   Turning Gamepad Mode off brings back the normal UI.

## Settings

Options > AddOns > ClassicConsoleGamepadUI. The defaults should be fine.

Commands: `/cgp` (or `/classicconsolegamepadui`)

*   `/cgp on`, `/cgp off`: turn the classic look on or off.
*   `/cgp native`, `/cgp classic`: switch the action bars for this session.
*   `/cgp bindings`, `/cgp edit`: how to open the key bindings and the action editor.
*   `/cgp status`: current state and the last problem found.
*   `/cgp keyboard`: show or hide the on-screen keyboard (`abc`, `t9`, `smart`, `tap` or `forget` as argument).
*   `/cgp resetframes`: put the player, target and focus frames back at their classic places.

## Moving frames

Open the game's Edit Mode in Gamepad Mode, drag the player, target or focus frame and save the layout.
The addon remembers the place. Frames that never moved stay at their classic places.
The setting "Classic player, target and focus frames" turns this handling off.

## Typing without a keyboard

The game has no on-screen keyboard of its own and an addon cannot open the system's, so the addon has one:
`/cgp keyboard` (or Options > AddOns > ClassicConsoleGamepadUI > On-screen keyboard). Open the chat line the normal way, then click
the keys with the mouse or the controller (D-pad moves, A types, B closes, X deletes, Y space, LT Shift, LB / RB other word,
Start is Done; then the game's own A / Enter sends the line). Drag it to move it. The `T9` key switches to a phone keypad (press 2 for a, again for b, c;
a pause accepts the letter), `/cgp keyboard t9` or `abc` picks the layout directly. The choice is remembered.
`Smart` on the phone keypad (or `/cgp keyboard smart`) suggests words: press each key once per letter and pick
the word in the top row (LB / RB on the controller). The word list learns from the chat you read and write and
from quest texts, and starts small; `/cgp keyboard forget` clears it. The setting "On-screen keyboard when typing in chat" opens it
with the chat line in Gamepad Mode. On Steam Deck, Steam + X also works.

## Steam Deck

The game sees the Deck as a controller in Gamepad Mode. Use 8-slot bars, or 12 slots if you map the back buttons to keys.

## Install

Extract the ZIP into `Interface/AddOns` so you get `Interface/AddOns/ClassicConsoleGamepadUI`. Remove the old `ClassicGamepad` folder if you have it. It does not work together with ControllerForever or ConsolePort.

## Problems

Report them on GitHub. `/cgp taint` lists what the addon changed in the game's controller code, which helps with "action blocked" errors.

It is also worth using BugSack or another error-catching addon to export errors for analysis.

`/cgp status` retains the last Lua error even after a successful refresh. `/cgp debug`
shows diagnostic state in Gamepad Mode, including when the classic bars are visible.
Mouse restoration failures are reported in chat and in `/cgp status`.

## Building

Run `python tools/package.py` with a Lua 5.1 compiler installed (`luac5.1`).
On Windows, use `python tools\package.py --luac "C:\path\to\luac.exe"`.
Packaging checks every runtime Lua file before creating the ZIP and rejects other Lua versions.

License: All Rights Reserved, see LICENSE.
