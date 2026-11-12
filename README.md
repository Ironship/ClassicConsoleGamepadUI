# ClassicConsoleGamepadUI

Gamepad support for WoW Forever, with the classic look and feel.

I wanted Gamepad mode but with support for both keyboard-and-mouse UI on screen. The game's own controller controls stay as they are. Simple settings, not much to configure.

Version 0.1.0-alpha.75. Alpha: expect bugs.

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
*   Move the player, target and focus frames in Edit Mode. The addon remembers where you put them.
*   On-screen keyboard for chat, for the controller and the mouse: a normal keyboard or a phone-style T9 keypad with word suggestions. English, German and Polish.
*   Settings window with tabs, also usable with the controller.
*   Controller button hints in micro menu tooltips.
*   Easy item deletion: X, X, A, A.
*   Chat, controller legend and micro menu position options.
*   Text that other addons put on action buttons (like damage numbers) shows on the classic bars.
*   The classic bars stay visible in the game's action editor and when you pick a stance, form or aura from the radial menu.
*   The Shaman's totem bar is placed above the bars instead of on top of them.
*   Turning Gamepad Mode off brings back the normal UI.

## On-screen keyboard

The game has no on-screen keyboard of its own, so the addon has one. Open the chat line as usual and type with the controller or the mouse. The keyboard closes when the chat line closes.

*   A normal keyboard, or a phone-style T9 keypad.
*   T9 has three modes: Tap (press a key again for the next letter), Smart (press each key once and pick the word from the suggestions) and Hybrid (tap the letters and the suggestions finish the word, the default).
*   The suggestions learn from the chat you read and write and from quest texts.
*   Languages: English, German, Polish.
*   `/cgp keyboard` shows or hides it. A setting opens it automatically when you start typing in chat.
*   If you do not want it, a setting in the Keyboard tab turns the keyboard off completely.

## Moving frames

Open the game's Edit Mode in Gamepad Mode, drag the player, target or focus frame and save the layout. The addon remembers the place. `/cgp resetframes` puts them back.

## Settings

`/cgp` opens the settings window. It is also under Options > AddOns > ClassicConsoleGamepadUI. The defaults should be fine.

Commands: `/cgp` (or `/classicconsolegamepadui`)

*   `/cgp on`, `/cgp off`: turn the classic look on or off.
*   `/cgp native`, `/cgp classic`: switch the action bars for this session.
*   `/cgp keyboard`: show or hide the on-screen keyboard.
*   `/cgp resetframes`: put the player, target and focus frames back at their classic places.
*   `/cgp bindings`, `/cgp edit`: how to open the key bindings and the action editor.
*   `/cgp status`: current state and the last problem found.

## Steam Deck

The game sees the Deck as a controller in Gamepad Mode. Use 8-slot bars, or 12 slots if you map the back buttons to keys.

## Install

Extract the ZIP into `Interface/AddOns` so you get `Interface/AddOns/ClassicConsoleGamepadUI`. Remove the old `ClassicGamepad` folder if you have it. It does not work together with ControllerForever or ConsolePort.

## Problems

Report them on GitHub. `/cgp taint` lists what the addon changed in the game's controller code, which helps with "action blocked" errors.

It is also worth using BugSack or another bug-catching addon that can export error data from the game for further analysis.

License: All Rights Reserved, see LICENSE.
