# Changelog

## Unreleased

- **The wheel slots show cooldowns and what cannot be used.** A Hearthstone on its hour of cooldown looked ready on the wheel: the slots of the wheel and of the small wheels had no cooldown at all (no sweep, no number, no grey). Each slot now has a Cooldown frame like the stock action buttons: a sweep over the icon, the countdown number on the big wheel (the small wheels beside the bags only sweep), and the icon goes grey while a cooldown longer than the global cooldown runs. An icon that cannot be used is dim (bluish when only the mana, rage or energy is missing), as on the stock bars. It covers the action slots of the five wheels, the spells of a flyout wheel and the pet wheel's commands and spells. In a fight where the times of a cooldown are secret values, the frame gets the game's own duration object instead, the way the classic bars already do it. The cooldown and usability events only mark the slots; they are read again on the next frame, and only while a wheel is on the screen. New `/cgp wheels cd` lists what the game says about every slot that has a cooldown, cannot be used or holds an item, and what the wheel on the screen made of it. Not drawn yet: charges, loss-of-control sweeps and item counts. Tried against a stand-in for the game only (readable and secret times, the global cooldown, usability, the flyout and pet wheels, the small wheels); not seen in the game yet.
- **Dynamic wheels no longer write to the bars over and over.** The game's item sounds (like bags being sorted) went on and on for a player, and stopped only after the dynamic wheels were switched off and on. Every write of a dynamic wheel picks an item or a spell up and puts it down on a bar, with the game's sounds, and nothing stopped a write that did not settle (something putting the old thing back, the game keeping another spell id than the one that was placed). Now the same thing is put on the same button at most three times within a minute (then it is left alone there for two minutes), more than 96 writes within a minute pause all of them for two minutes, one line in the chat says so, and changing a dynamic wheel setting starts the guard over. For normal use nothing changes: logging in, eating, looting, a manual change and a full bag give the same bars and the same number of writes as before. `/cgp wheels dyn` now also says how many runs and writes there were (in all and in the last minute) and lists the last writes, so it shows whether these wheels are the ones making the noise. Tried against a stand-in for the game only (a normal fill, echo events, a write that never sticks, something undoing one slot or everything, bags that change every second); the cause of the original loop was not seen.

## 0.1.0-alpha.86

- **The name and the hint under the wheel are no longer behind the panel.** They were regions of the wheel's frame and the panel is a child frame, which is drawn over them; they now sit on a frame of their own above it.
- **Pet wheel: the tooltip never stays empty, and `/cgp wheels pet` says what the pet wheel sees.** Hovering a pet command (Attack, Follow, Stay, the stances) put nothing on the tooltip when the game's own tooltip of the pet action answered without text; the name of the command is shown then. `/cgp wheels pet` lists the pet bar, the entries, what the secure layer was told and the last release; the last release of a pet wheel button now says which pet action it chose. Tried against a stand-in for the game only.
- **Less garbage on every refresh, and a legend check that no longer grows with the square of the hints.** Found by tracing the addon's own Lua against a stand-in for the game: `Addon:Refresh` made about 25 KB of garbage per call and now makes about 6 KB. The taint check that runs after each stage of a refresh (five times) made a closure and seven tables every time and now makes nothing while the state is clean; a slot's prompt no longer builds its list of glyph states; the mirror of other addons' text on a slot no longer builds a closure and a table of the button's regions. The legend's per-frame style watcher asked the legend for its children once for every child (`select(i, legend:GetChildren())`) and now asks once (`/cgp perf` had it at 0.21 ms a frame). The same calls are made on the same frames, apart from the legend's. Tried against a stand-in for the game only; the game's own cost of those calls was not measured.

## 0.1.0-alpha.85

- **Spell Flyout support on Action Bars and Wheels.** Action bar slots and wheel slots now render flyout indicator arrows and handle spell flyouts cleanly: single-known flyouts cast directly, multi-spell flyouts on action bars open Blizzard's `GamepadSpellFlyout` positioned directly above the classic slot (with a secure `$parent` anchor-restore fallback to avoid Restricted frame errors), and multi-spell flyouts on wheels open an in-wheel flyout sub-wheel (combat-safe, zero taint). Mouse clicks on flyout action bar slots defer opening until mouse-up so flyout icons can be dragged off bars with the mouse normally, while gamepad keybinds still open on key-down.
- **Dynamic "Pet" wheel (`wheelDynPet`).** New dynamic wheel category (Controls tab -> Dynamic wheels, off by default) that collects pet action bar commands and unique active pet spellbook spells into a wheel without touching player action bars. Executes via secure `type="pet"` / `type="spell"` attributes (pre-seeded for mid-combat pet summons), highlights active pet stances, dims unusable actions, and shows native pet/spell tooltips.
- **Release packaging.** `tools/package.py` now bundles runtime assets under `Textures/` (including `Textures/Wedge30.tga`) into the release ZIP.
- **Wheels: two-frame selective camera blocking and `/reload` stick fix.** Replaced the single-frame stick listener with a combat-safe two-frame pair (`eater` at `BACKGROUND` with `SetPropagateKeyboardInput(true)` + `blocker` at `TOOLTIP` with `SetPropagateKeyboardInput(false)`): while a wheel button is held, `Movement` (L3) propagates freely so walking never stops, while `Camera` (R3) is blocked for that event and immediately released. Both frames are disabled and hidden immediately after creation (`EnableGamePadStick(false)`) and at rest so sticks stay responsive after `/reload`. Wheel slots also call DoesItDiePlus' synchronous `RefreshButton` immediately on open/redraw, and the stick activation deadzone is lowered to `0.35` with held-stick caching across frames.
- **Wheels** (new, off by default; Controls tab, "Wheels on R3 + D-pad and L3 + X"). Five wheels of twelve slots: hold R3 and press a D-pad direction (four wheels), or hold L3 and press X (the fifth), and the wheel opens in the middle of the screen; push a stick toward a slot and let go of the button to use it (a push of less than half the stick cancels). **The wheels are your action bars 4 to 8**, one bar a wheel (R3 + D-pad up = bar 4, right = bar 5, down = bar 6, left = bar 7, L3 + X = bar 8), the twelve buttons of a bar are the twelve slots. The addon stores nothing of its own: what is on a wheel stays on those buttons when the gamepad mode is off, the keyboard bars show it, and a spell, item, macro, mount or anything else a bar button takes goes onto a slot with the game's own placing (what was there goes onto the cursor). "Fill the wheels" (also `/cgp wheels`) puts the wheel on the screen, at its place and size, and lets it take the mouse; drag a slot out to take it off, right click clears it; the buttons under the wheel pick the wheel, "Done" or Esc ends it. "Empty all wheels" empties the bars 4 to 8. While R3 is held the D-pad belongs to the wheels and while L3 is held X does; R3 and L3 alone do nothing else, so the setting stays off until you turn it on. Size of the wheel, size of the slots, place (distance from the middle of the screen, sideways and up), opacity, the name and the buttons in the middle are settings. Everything that acts is secure: a click layer binds R3 and L3 and, while one is held, its buttons with priority override bindings, the stick is read in the secure snippet (`GetGamePadState`) and the button clicks the action slot, so the wheels work in combat (a flyout in a slot does nothing). English and Polish texts; the other languages show English for now.
  Tried against a stand-in for the game only: the secure snippets, the slot choice for all twelve directions, placing and swapping, the settings rows. Not tried in the game yet: whether the game gives R3, L3, the D-pad and X to the click layer, whether the stick list (movement and camera stick by index) is read the same in the secure code, that the bars 4 to 8 are the action slots 25-48 and 145-180 on this client (`/cgp wheels diag` prints them), and the look of the wheel. `/cgp wheels diag` prints what the secure code read on the last release. Letting go uses the slot the wheel shows as chosen even when the secure code cannot read the stick (the drawn wheel writes its choice on the wheel's button outside combat; in combat only the stick read counts); `/cgp wheels trace` also prints what a click of a wheel button came to.
- **Keys of your own for the wheels** (Controls tab, one row for each wheel; "Open with R3 + D-pad and L3 + X" turns the R3/L3 combos off). Any keyboard key (with Shift, Ctrl or Alt if you like) or extra mouse button opens a wheel like the combo does: hold it, push a stick toward a slot, let go. Meant for controllers that send keyboard keys, such as a Steam Controller whose extra buttons are set to keys in Steam Input. Click the row, press the key (Backspace takes it off, Esc gives up, a right click on the row takes it off too). The key is one of the game's own key bindings ("CLICK ClassicConsoleGamepadUIWheelFace1:LeftButton" and so on), so the game saves it; a key that did something else is taken from it and the chat says so. The wheel buttons act only while the wheels are on and in gamepad mode. Tried against a stand-in for the game only; not tried with a real Steam Controller.
- **`/cgp wheels safe` leaves the numbers and the dynamic wheels alone** (it had switched them off too, and DoesItDiePlus' numbers vanished from the wheel slots): it only switches off what reaches into the pad, the camera or the game's focus.
- **`/cgp wheels reset` and `safe` no longer touch the game's interface focus** (that call marked the game's focus and binding tables as this addon's and was followed by two "SetPreferredGamepadInteractTarget blocked" errors; it is now `/cgp wheels unfocus`, typed on purpose, as the emergency lever for controls that stay dead because the game thinks the interface has the focus). New `/cgp wheels focus` prints every FrameShown / SetUIFocusState call the game made since the addon loaded (also saved in the saved variables), to find out who focuses the interface after a /reload. Tried against a stand-in for the game only.
- **The R3 / L3 combos are off by default** (a saved "on" from the builds before is switched off once). While on they took the two stick clicks from the game on every login; on a pad set up like the player's (L3 / R3 as the left and right mouse click, and the gamepad cursor's click keys) that read as controls that no longer answer. `/cgp wheels diag` now says what the game itself does with R3 and L3. Tried against a stand-in for the game only.
- **Safety pass over the wheels.** Nothing that reaches into how the pad, the camera or the game's focus work is on by default any more: stopping the camera stick is Off (the camera speeds of the pad are not written at all now; a value an earlier build saved is put back once), and listing the small wheels among the windows LT / RT step through is an opt-in setting ("LT / RT can reach the small wheels (experimental)") that calls the game's focus code through a taint barrier. New `/cgp wheels safe` switches every such part off at once (stick stopping, window-list entry, open-choose-confirm mode, dynamic wheels, numbers, always-up small wheels) and runs the reset; `/cgp wheels diag` lists which of them are on. The R3 / L3 combos bind the stick clicks while the wheels are on: turn off "Open with R3 + D-pad and L3 + X" to give them back to the game. Tried against a stand-in for the game only.
- **Controls dead after /reload: the small wheels no longer take the interface focus.** Joining the game's window list made the game focus the interface when it had not been (the sticks then move its cursor, not the character) until the game's own wheel was opened. The small wheels now join only while the interface already has the focus, and try again while they are up. A stick listener is no longer switched off when it was never on. New `/cgp wheels reset` puts back everything the wheels changed (listener, camera speeds, window list) and gives the focus back to the character; `/cgp wheels diag` shows the game's focus state. Tried against a stand-in for the game only.
- **Wheels: a listener that leaves the camera stick alone while you walk.** `/cgp wheels sticks` showed that the game sends every stick twice, by its place ("Left", "Right") and by its job ("Movement", "Camera"). The new method "Take the camera stick, not while walking" takes the camera stick's events while a wheel button is held unless the movement stick was pushed in the last quarter of a second; "Take the camera stick always" is the old behaviour (it stopped the walking too). The new method is the default (a setting saved as "camera speeds" by the build before is changed to it once). Tried against a stand-in for the game only.
- **Wheels: how the camera is stopped is a choice** (setting "Stop the camera while a wheel button is held": camera speeds to 0, take the camera stick with a listener, take both sticks, or stop nothing; "Choose with the camera stick only" now only says which stick chooses). The listener and the camera speeds were each tried alone and neither did what the game's own wheels do on every setup, so the player picks; `/cgp wheels sticks` listens for six seconds and prints how the game names and sends each stick. Tried against a stand-in for the game only.
- **Wheels: the camera stick belongs to the wheel while a wheel button is held** (new setting "Choose with the camera stick only", on by default: the movement stick keeps walking and does not choose; off: both sticks choose and both are taken). The camera stands still while you aim at a slot: the game's camera speeds of the pad are set to 0 while a wheel button is held and given back when it is let go (kept in the saved variables meanwhile, so a crash cannot leave the camera still). A stick listener, tried first, also stopped the walking (seen with L3 held), so it is now used only in the mode that takes both sticks. The slot the wheel shows as chosen now stays after the stick leaves it for as long as the new setting "Keep the choice after the stick is let go" says (800 ms by default, 200 to 3000), so letting go of the button a moment after letting go of the stick still uses it (the slot dims and a bar in the middle runs down while it waits; keeping the stick in the middle for longer cancels), and what is shown as chosen is what is used (outside combat; in combat the stick is read in the secure code). The wheel also reads the stick values that come with the stick event, in case the game stops showing a stick it is asked to hand over in its polled state. Tried against a stand-in for the game only.
- **The small wheels say what a dynamic wheel is filled with** ("Food and drink", "Usable things", "Professions" in the middle of the wheel), and change at once when the setting does. Tried against a stand-in for the game only.
- **Dynamic wheels** (new, off by default; Controls tab, "Dynamic wheels (fill themselves)"). Wheels that fill themselves, outside combat, whenever the bags or the spellbook change: one wheel for food and drink (best first), one for potions, elixirs, flasks, scrolls, bandages and other usable things (a hearthstone, a quest item with a use), one for the spells of your professions. You choose which wheel each kind goes to (by default 3, 4 and 5 = bars 6, 7 and 8). A dynamic wheel is an action bar that belongs to the addon: what you put on it by hand is replaced; what is already there keeps its place, what is gone is cleared, what is new takes a free place; at most twelve fit. Nothing happens in combat or with something on the cursor. The title of the wheel says what fills it. `/cgp wheels dyn` runs it at once and says what each dynamic wheel holds. Tried against a stand-in for the game only.
- **Wheel like the game's own wheels, LB and RB between the wheels, and an open-choose-confirm mode.** New look (setting "Wheel like the game's own wheels", on by default; off keeps the round slots): twelve wedges as in the Main Menu wheel, a title above with the bar and the buttons that open the wheel, five dots (one for each wheel, the shown one lit) between LB and RB, and a panel below with the name of the chosen slot and what the buttons do. LB and RB turn to the previous or the next wheel while one is open and go round the ends (bar 8 to bar 4 and back), as the game's own wheels do; the secure code works out the slot in the shown wheel's bar, so it also works in combat. New mode (setting "Open, choose, then confirm", off by default): the button opens the wheel and can be let go; the camera stick chooses, A or the same button uses the slot, B cancels (a wheel left open is given up after about 20 seconds outside combat). The wedge is a new texture file (Textures/Wedge30.tga): a client that has not seen the file before finds it only after a restart of the game, not after /reload. Tried against a stand-in for the game only.
- **Damage and healing numbers on the wheel slots** (setting "Damage and healing numbers on the slots", on by default; needs DoesItDiePlus). The slots of the wheel and of the small wheels ask DoesItDiePlus' new public SpellDamageInfo API to draw its numbers on them: the damage of a spell, the healing of a potion or a bandage, formatted by its own settings. Without DoesItDiePlus nothing changes. Tried against a stand-in for the game only.
- **Taking things off the wheels.** The small wheels also appear while "Fill the wheels" is on, and, with the new setting "Keep the small wheels while those windows are open" (off by default), whenever the spellbook, bags, macro window or collections are open. With the pad: LT / RT to the small wheels, the D-pad to a slot, A picks its content up and B puts it down, which takes it off (A on another slot puts it there instead); with the mouse: drag it out or right click. B on the small wheels with nothing in hand ends "Fill the wheels". A dynamic wheel puts its things back at the next run. Tried against a stand-in for the game only.
- **Small wheels stand clear of the bags.** The rectangle of a window now includes what it draws past its frame (the bags' rows reached under the small wheels), and the small wheels go on the side of the windows that faces the middle of the screen: on the right of windows on the left half, on the left of the others (the other side when there is no room). Tried against a stand-in for the game only.
- **Small wheels while you drag something** (with the wheels; setting "Small wheels while you drag something", on by default). While a spell, item, macro or mount is carried on the cursor, all five wheels appear small beside the windows that are open (the spellbook, the bags, the macro window, the collections; the character window, which the gamepad interface puts beside the bags, is left uncovered; the wheels follow when a window is moved), or at the right edge of the screen when nothing is open, so the thing is dragged only a short way onto a slot and no wheel has to be picked first (drop to place, drag out to take off, right click to clear). Put it down and they go away. Slots under a carried spell light up, and letting go over a slot places it even when the game does not hand the drop to the slot (`/cgp wheels trace` prints what the slots see of the mouse). B on the pad ends "Fill the wheels" like Esc. With the pad the small wheels are a window of the game's own window switching: LT and RT step between the bags (or the spellbook) and the small wheels, the D-pad walks over the slots, A puts down what is carried (or picks up what a slot holds), the right-click button takes a slot's content off and B puts the carried thing back. Tried against a stand-in for the game only.

## 0.1.0-alpha.84

- **"Share the keyboard's action bars" is off by default.** A fresh installation starts with the controller's own action bars, as the game does it; turn the setting on in the settings window to put the keyboard bars on the controller buttons. Settings that were saved are kept, so nobody who already uses it loses it.

## 0.1.0-alpha.83

- Korean (한국어), both as an interface language and as a typing language of the on-screen keyboard.
- **Keyboard:** the standard two-set layout (두벌식) on the full keyboard. Each key types one jamo and the keyboard puts them together into syllables in the chat line the way a Korean input method does (ㅎ ㅏ ㄴ = 한, 하 + ㄴ + ㅏ = 한 -> 하나, double finals such as 값 and 닭, compound vowels such as 와 and 의). Shift gives the doubled consonants and ㅒ ㅖ, Delete takes a syllable apart one letter at a time (값 -> 갑 -> 가 -> ㄱ), and the new 한/영 key beside the space bar switches the same keys to Latin letters for commands such as /invite. The syllable is only put together while the chat line is exactly what the keyboard wrote there, so text from a suggestion, a paste or the real keyboard is never rewritten.
- **Suggestions:** common Korean chat words, plus your own and the chat's words as for the other languages. A half-finished last syllable still finds its word (안녕ㅎ offers 안녕하세요), because words are compared letter by letter, not syllable by syllable. There is no WordHunterWoW dictionary for Korean.
- **Interface:** `Locales/koKR.lua` has every text. The Hangul font is the game's own Korean font (`Fonts\2002.TTF`), set under the addon's text and keys while the interface or the keyboard is Korean, so Hangul shows on any client; `/cgp fonts` says what is set. `/cgp keyboard ko` and `/cgp language ko` work too.
- Korean has the full keyboard only: there is no Korean phone keypad (T9, Cheonjiin) yet, so the phone layouts show the full keyboard while Korean is chosen and come back when another language is.
- The Korean texts and the common-word list were written without a native speaker's review; corrections are welcome. Tried only against a stand-in for the game, not in the game yet.

## 0.1.0-alpha.82

- New `/cgp perf`, to find out where the addon's time goes. The game's own addon profiler gives one number for the whole addon; this times the refresh the addon makes ten times a second and each step inside it (the HUD, the layout, the bar slots, the input layer, the taint checks), the legend watcher that runs on every frame, and the frame time itself. `/cgp perf on` starts collecting, `/cgp perf` prints the table (calls, average, maximum and total milliseconds, how many calls took over 1 ms and over 5 ms, how much of it in combat) and the frames over 33, 50 and 100 ms with how many of them had 5 ms or more of this addon's time in them, `/cgp perf slow` lists the slowest single calls and frames, `/cgp perf off` stops and `/cgp perf reset` starts again. Nothing is installed until the first use. In a first run in the game (51 s, 18 s of them in combat, 137 fps) there was no frame over 50 ms and the addon took about 6% of one core, mostly the bar slots' redraw (2.2 ms per refresh) and the legend's frame and shade update (0.2 ms per frame), so the addon was not the cause of the stutter that was suspected. Not optimised yet.

## 0.1.0-alpha.81

- The settings window is rebuilt to look and work like the settings of UsefulPlatesAndTooltips, and its tabs now follow what you want to do instead of where an option happened to land. **Bars** (layout, gryphons and the frames the layout places), **Controls** (the keys of the bar slots and the shortcuts to the game's own pages), **Prompts** (button glyphs and the gamepad legend), **Interface** (micro menu, chat, item deletion) and **Keyboard** (the on-screen keyboard and its word suggestions) replace General, Hints, Chat, Keyboard and Tools.
- The switch for the whole addon ("Classic interface") sits above the tabs and dims the Bars and Prompts tabs while it is off. The language is a button in the window's header (the word "Language" is the same in every language, so it can always be found) and changes the window at once. "Reset all settings" is in the foot of the window.
- A black panel with the rows in two columns (what it is on the left, the control on the right), a gold heading for each group with one line saying what the group is for, sliders in one line with their value, and drop-down lists for the choices (the language, the keyboard language and layout) instead of buttons that stepped to the next choice when clicked. A help line under the panel shows the description of the row under the mouse or under the pad's selection, so the text is there for a controller too and uses the addon's own fonts in every language.
- Rows that only mean something while another setting is in a certain state are dimmed now: "Keep L2+R2 slots together" with compact bars, the micro menu's place with the menu hidden, the legend's, chat's and menu's distances and the keyboard's settings with their switch off. The pad skips dimmed rows.
- Shorter labels and descriptions: each says what it does and when to turn it off, in one or two sentences (the old ones ran to five). English, German and Polish have all the new texts; French, Spanish, Italian and Portuguese have the new tab, group and button names and show the rest in English until they are translated. Not tried in the game yet.
- When the game blocks `SetPreferredGamepadInteractTarget` because of another addon (the "ADDON_ACTION_FORBIDDEN" that makes the gamepad interface stop working after a panel closes), the chat now says which addon it was and to type /reload or update or disable it, once per addon and session. Nothing can undo the broken state from this addon; it only names the cause. Not tried in the game yet.

## 0.1.0-alpha.80

- "Position chat from screen edges" and "Classic player, target and focus frames" are off by default now, and are switched off once in an existing installation (turn them on again if you want them; they stay on after that). Both overrode the game's Edit Mode, so chat sat in the screen corner and the unit frames went back to the top left corner, whatever the player did there. With them off, Edit Mode places chat and the frames. Reported on CurseForge. Not tried in the game yet.
- New setting "Attack button only starts attacking" (General tab, off by default): a bar slot that holds Auto Attack runs `/startattack` instead of the action, so pressing it again no longer switches the attack off (the stock action is a toggle, as the game's own button). Asked on CurseForge. Not tried in the game yet.

## 0.1.0-alpha.79

- Clicking the key ring button of the bag bar ended in "attempt to perform arithmetic on field 'shownSlots'" (Blizzard's `ContainerFrame.lua`): the key ring opens as a single bag there, which the gamepad interface does not support. While the classic bars are up the button is dimmed and takes no clicks; the key ring stays in the game's own gamepad bag bar. Not tried in the game yet.
- Macros on the bars work again for the slots that mirror the keyboard bars ("Keyboard bars on the controller", the spare slots 9-12 and the class slots without a class action). The click was passed on as `/click <button>` macro text, so a macro in that button's slot ran inside a macro, which the game does not do. The slot's action number (the button's position plus its bar's page) is now worked out in the secure click code and the action is used like the controller's own; flyouts still go through the button. Not tried in the game yet.
- New `/cgp clicks`: prints every click of a bar slot or pad button after the secure code handled it (type, action, what the action is, macro text of a delegated click), to find out why a macro on the bars does nothing.
- Edit Mode support, bar size, gryphon, placement and legend options below are by vos6434 (pull request #5), merged with the other changes of this version. The page switcher they moved is gone (see above), the texts are translated into German, Spanish, French, Italian and Portuguese (not read by native speakers), and the legend's per-frame checks no longer make a table every frame.
- Party member portraits (and the player's, the pet's, the assist target's and the focus's) are drawn again on the targeting bar opened with L1 and the D-pad. The slots copied the game's icon, and a unit portrait cannot be copied that way, so they stayed empty (issue #6). Not tried in the game yet.
- The page number with its two arrows left of the bars is no longer drawn (the classic bars have no page to switch).
- New setting "Hide the micro menu" (General tab): hides the menu with the character, talents and quest buttons completely, instead of only moving it to the right edge (out of sight and out of reach of the mouse; the frame-rate display, which hangs off the menu, moves to the bottom right corner meanwhile).
- Action editor ("Bind to Action Bar", "Edit Action Bars") with "Keyboard bars on the controller" on: the editor starts from the keyboard action bars (what they hold is copied into the game's controller storage, which the editor shows, picks up and clears), and when it closes every slot it changed is copied back to the keyboard bar slot at the same place (the action that was there goes; a slot it emptied empties that slot). Before, the editor filled the controller storage alone, which the keyboard bars do not show, so a spell bound there looked as if it had vanished, and "Edit Action Bars" found empty slots. Spells, items and macros are copied; other kinds (flyouts, mounts, equipment sets) are not shown in the editor and move when it changes them. A controller slot is left as it was where the keyboard bar slot is empty. Page 1 only, outside combat. Not tried in the game yet.
- The keyboard layout window can be used with the controller: the D-pad moves, A picks a key and gives it to a slot, X clears a slot, B goes back.
- New defaults for a fresh install: keyboard bars on the controller on, unit frames not moved, micro menu at the right edge, larger button and trigger hints, chat anchored, the screen keyboard opens with the chat, quick item deletion on. Saved settings are kept.
- New setting "Keyboard bars on the controller" (General tab; on for a new installation, off for one that already exists, so the controller's own bar layout stays what it was until it is turned on): the bars show the actions of the keyboard's action bars 1, 2 and 3, and the controller's bar buttons use them, so an action sits in the same place with the keyboard and with the controller and nothing has to be placed twice. X, Y, B, A without a trigger stay the game's own (interact, target menu, back, jump); the targeting, shortcut, stance and possess bars stay as they are.
- New: a keyboard layout window (General tab, "Keyboard layout of the bar slots", or /cgp keys). It shows a keyboard next to the slots of the bars (with the pad button each one is on, e.g. LT+X): click a key, then the slot that should use it, and the slot's key shows on the bar and in the window. Click the slot again to take the key away, right click a slot to clear all its keys, Shift, Ctrl and Alt add a modifier. A key the game uses for something else asks for a second click. The keys are the slot's ordinary keyboard bindings (the same ones the game's key bindings list shows), so they work on the keyboard bar and in Gamepad Mode alike. Outside combat only. Not tried in the game yet; the texts in the other languages are new and unread by native speakers.
- "Classic bars size" (50% to 150%, General tab and the Edit Mode panel of the classic bars) grows or shrinks the classic
  bars with their gryphons, indicators, experience bar and compact bags, centered on the bottom of the screen. 100% is the size so far.
- "Reset all settings" on the Tools tab puts every setting back to its default, with the places the addon keeps (the
  classic bars and the legend dragged in Edit Mode, the unit frames, the on-screen keyboard). The interface language and
  the learned words stay. It asks for a second click, like "Reset learned words".
- Every stock frame the classic layout places has a setting now, all on by default as before: "Micro menu at the right
  edge", "Bags with the classic bars", "Experience and reputation bars above the classic bars" and "Totem bar above the
  classic bars" (General tab). Off, the frame is left to the gamepad layout's Edit Mode, so players can make a layout of
  their own; chat, the legend and the unit frames already had theirs. Before, a micro menu moved in Edit Mode snapped
  back to the right edge every time the bars were laid out, saving the layout included; now "Micro menu at the right
  edge" off keeps it where Edit Mode puts it, at its Edit Mode size.
- The classic action bars show up in the game's Edit Mode. While Edit Mode is open they get a selection box of their own
  ("Classic Action Bars"): drag it, or click it and nudge the bars from its panel, to move the whole HUD (bars, gryphons,
  experience bar and, in the compact layout, the bags). The place is saved at once; `/cgp resetbars` or the panel's
  "Reset position" button puts the bars back. Before, Edit Mode swapped the classic bars for the stock gamepad crossbar,
  so they could not be placed at all. The classic button layer stays off while Edit Mode is open.
- The gryphons at the ends of the classic bars can be hidden one by one, like the end caps of the game's own action bar:
  "Left gryphon" and "Right gryphon" on the General tab and on the Edit Mode panel of the classic bars. The bars keep their
  place when a gryphon is hidden.
- The gamepad legend (the box of button hints) can be moved in Edit Mode too, as "Gamepad Legend": drag it or nudge it
  from its panel. The place is kept at once, also in Edit Mode, and wins over the experimental "Move the legend below the
  player frame"; `/cgp resetlegend` or the panel's "Reset position" button puts it back.
- "Grow upwards" on the legend's Edit Mode panel: the legend keeps its bottom edge and more hints push it up, instead of
  hanging further down. It follows its hints as they change, in combat too while the game lets the legend move.
- The legend's gold frame can be switched off and its dark shade made lighter: "Show frame" and "Background opacity" on
  the legend's Edit Mode panel and in the Hints tab. `/cgp legend` lists the legend's textures and which option each
  follows.

## 0.1.0-alpha.78

- Complete and delete at the chat cursor without altering links, also in lines with Polish, German or French letters (the cursor is set in bytes, as the game does); typing a word or a space in front of an existing blank steps over that blank instead of running the words together; the cursor look-up never throws; the X send binding follows predictive words.
- New setting "D-pad buttons first in each row" (General tab, off by default): each row of eight starts with the D-pad buttons instead of the face buttons (X, Y, B, A). Only the order changes; every slot keeps its place and its key, and the click target of a slot presses what the slot shows. Applied outside combat like the other layout settings. Not tried in the game yet. The French, Spanish, Italian and Portuguese texts are new and unread by native speakers.
- Stop an unfinished dictionary scan when the keyboard is disabled or its language changes.
- Reduce repeated HUD anchor, opacity and secure-input updates while the bars are unchanged. Redraws asked for by the action buttons (usable, range, count, state, cooldown reports, which come nearly every frame in a fight) are served at most 20 times a second; layout, settings and end-of-combat redraws are not held back.
- Check the word-list reading budget within long quest texts as well as between quests, reducing long individual reading slices.

## 0.1.0-alpha.77

- The keyboard learns your own words. What you send and what you accept from the suggestions is kept as your vocabulary, per
  keyboard language, and your words rank above the common ones and above words that were only read, so the suggestions fit the
  way you write better the longer you use the keyboard. Only single words with counts are kept, never a sentence.
- What the keyboard reads (chat, quest and gossip texts) is kept apart from your own words, and it is learned only while the
  keyboard types the language of the game. Before, one list served every language, so the quest texts of a German game filled
  the suggestions of a Polish keyboard. A list saved by an earlier version becomes the words read in the language of the game;
  nothing is lost.
- A "Learned words" section in the Keyboard tab shows how many words of yours and how many read ones the keyboard knows for the
  language in use, and has the "Reset learned words" button (it was "Forget learned words", the last button of the tab). It
  asks for a second click within four seconds and clears everything learned, in every language. `/cgp keyboard forget` does
  the same and `/cgp keyboard words` prints the counts.
- The full keyboard looks like a real one. Every row is as wide as the digit row and ends in the same place; before, the rows
  had different lengths, the row of accented letters floated in the middle and the bottom row stopped short. The letter keys
  have one size, and the keys that are not letters sit where Tab, Caps, Enter and the right Shift are on a keyboard: Clear,
  the layout key (T9), Done and Close, with Shift on the left of the bottom letter row and the space bar under the middle. The
  row of suggestions is as wide as the keys. A row with so many letters that a key does not fit beside them (German, French,
  Spanish, Portuguese) puts that key next to the space bar. The row of accents is as wide as the keyboard, its keys at most
  72 pixels wide.
- A new setting, "Keyboard transparency" (Keyboard tab, 0% to 90%, 0% is the look so far), lets the game show through the
  keyboard. The background and the faces of the keys become see-through; the letters and the borders of the keys stay solid, so
  it stays readable. It takes effect at once, also on an open keyboard.
- The word list can no longer stop the keyboard. Every call the keyboard makes into it (suggestions, learning) is guarded: if
  something fails inside, the key press goes on without suggestions and the error is shown once in the chat and kept in the
  saved diagnostics.
- `/cgp keyboard debug` now says whether X is the game's send button and, when it is not, which condition is missing (in combat,
  no chat line, the line has no focus, the chat footer is not shown, a word waits in the buffer, ...). When X reaches the keyboard
  instead of sending, the same reason and what the pad buttons are bound to are saved at once in the diagnostics
  (`xPress`), so a send that does nothing can be explained afterwards.

## 0.1.0-alpha.76

- Interface language. Every text of the addon now lives in language files (`Locales/`): English, German, Polish, French,
  Spanish, Italian and Portuguese. A new setting (General tab, or `/cgp language`) picks the language of the settings, the
  hints and the on-screen keyboard. English is the default whatever language the game runs in; "Game language" follows the
  client. The French, Spanish, Italian and Portuguese texts are new and no native speaker has read them yet.
- On-screen keyboard, space and sentences: the phone layouts have a Space key in the bottom row, and Y or the 0 key end the
  word with a space. In Tap and Hybrid the 0 key used to put the space into the word being typed, so the suggestions
  stopped after the first word of a sentence; it now ends the word like the Space key does (pressed twice quickly it types a 0,
  three times a space again). The strip above the keys shows a short hint of what the layout does and cuts a text that is
  too long instead of letting it run out of the keyboard.
- On-screen keyboard, layout: a new setting "On-screen keyboard layout" (Keyboard tab) lists the full keyboard and the three
  phone keypads together and replaces "T9 mode". The key next to Clear names the layout it leads to (QWERTY, QWERTZ, AZERTY
  or T9) instead of "ABC".
- On-screen keyboard languages: French (AZERTY), Spanish, Italian and Portuguese join English, German and Polish, with their
  accents on the full keyboard and under the phone keys. Every language has its own common words, and a learned word with an
  accent the language has no key for is no longer suggested in it.
- Word suggestions from WordHunterWoW. With English Quest Panel installed the English quest texts are a word base for the
  suggestions (every word is counted, names rank a little lower). With a WordHunterWoW dictionary (German, French, Spanish,
  Italian or Portuguese) that the game has loaded, its words are suggested too. They come after the player's own words and the
  common ones, they are read a few milliseconds per frame and not in combat, and nothing in those add-ons is changed or
  loaded. A setting turns it off, a line in the Keyboard tab says where the suggestions come from, and `/cgp keyboard words`
  prints it.
- Fix: Polish letters showed as boxes on the Polish keyboard. The game's interface font (Friz Quadrata) has only ó and ł of them,
  not ą ć ę ń ś ź ż. The addon now draws its texts with font objects of its own (`Fonts.lua`, copies of the game's fonts) and puts
  the chat's font under them while the keyboard types Polish (keys, the strip, suggestions) and while the interface is in Polish
  (windows, hints). In Polish the settings window shows its tips in a tooltip of its own, because the game's tooltip has the same
  font; the two Polish texts that the game's own tooltips show are written without the missing letters. `/cgp fonts` prints what
  the font fix is doing.
- On-screen keyboard, full layout: a row of word suggestions above the keys, for the word at the end of the chat line (the same
  words as Hybrid: the player's own, the common ones, the WordHunterWoW lists). LB/RB choose; Y, the Space key or a click puts
  the chosen one in place of the letters typed so far and adds a space. Nothing is suggested while a slash command is being typed.

## 0.1.0-alpha.75

- New setting "Keep the L2+R2 buttons together (12 slots)" (General tab, off by default). In the 12-slot layout the stock bars
  split the buttons used with both triggers: four sit after the L2 row and four at the far end. With the setting on, all
  eight sit together between the L2 row and the R2 row. It has no effect with compact bars, which do not show them
  in the upper row.

## 0.1.0-alpha.74

- New setting "Use the on-screen keyboard" (Keyboard tab, on by default). Off, the keyboard never opens (`/cgp keyboard` and
  the settings button say that it is off), the opening with the chat line does nothing, and the word suggestions stop learning
  from chat and quest texts. The words already learned stay, and "Forget learned words" still clears them. The other
  keyboard settings are dimmed while it is off.

## 0.1.0-alpha.73

- The Shaman's totem bar now sits above the classic bars. It is a mouse bar (`MultiCastActionBarFrame`) that the game shows in
  Gamepad Mode too, in the place its gamepad layout gives it (128 points up, just left of the middle), which is on top of the
  upper row and the shoulder indicators. It goes above the bars, indented past the end cap, the way the keyboard layout stacks
  it, outside combat. A bar moved in Edit Mode stays where it was put, and leaving the classic bars puts the game's place back.
  Totems have no selection radial in this client (the game's class radials are the druid's forms, the paladin's auras and the
  warrior's stances), so the radial fix of alpha.72 does not concern them.

## 0.1.0-alpha.72

- Fix: the classic bars no longer give way to the game's own HUD while a selection radial is open (the warrior's
  stances, the druid's forms, the paladin's auras, the pet commands, a bar button's flyout). The radial is the game's
  own and is drawn over the classic bars, which fade while it is open, like the game's own bars do. Before, the bars,
  bags, micro menu, status bars and chat all went back to their stock places for as long as the radial was open, and in
  combat they stayed there until the fight ended (the classic bars cannot be built in combat). The radial itself is not
  moved: it is a protected frame, centred on the game's own button. Only the action editor's radials still use the
  native view.

## 0.1.0-alpha.71

- X sends the line again, and this time the game does the sending. While the chat line has the focus, the chat's footer
  is up and no word waits in the keyboard's buffer, X is bound straight to the game's own button for PAD1 (the chat's
  "A: send"), so the chat's code runs in the game's own call and not inside this addon's (that was the taint of
  alpha.58 to alpha.69). A waiting word goes into the line with the first X, the next X sends. `/cgp keyboard debug`
  shows `send=` (the button X is bound to, or nil).
- The keyboard closes when the chat line closes (after a send, or when the line is closed with B).
- The keyboard's texts follow the client's language (English, German, Polish).
- Fix: Y with nothing waiting inserted a space as the first character of the line, and a line that starts with a space
  is no slash command (`/cgp status` was sent to the chat as text). A space is never the first character and never
  follows another space.
- Fix: an edit box that was only shown (not active, not focused) counted as an open chat line.
- `tools/package.py` stamps the files in the ZIP with the commit's date (or `SOURCE_DATE_EPOCH`) instead of a fixed date.

## 0.1.0-alpha.70

- Fix: X no longer sends the chat line. The send ran the game's chat code (closing the line, the footer's binding
  sets, secure slash commands) with this addon's taint; `securecallfunction` does not remove it, it only keeps the callee's
  taint away from its caller. That is the "interface action failed because of an addon" message after a send. X is now
  Done, like Start: the word goes into the chat line, the keyboard lets go of the controller and the game's own A sends it.
- Fix: the chat's footer binds A, X, Y and B again with every focus refresh and, with the same priority, the newest
  binding wins, so it kept taking the controller from the keyboard (an A press then sent the half-typed line). The keyboard
  now binds its buttons again right after the game's binding stack changes (post-hooks on `AddBindingSet`, `RemoveSet`
  and `ClearBindings`; once, at most every tenth of a second, only when one of its buttons is bound to something else),
  as well as from its 0.25 s check.
- Fix: the settings window ignores the controller while the keyboard is shown (both used to move at once).
- "Forget learned words" asks for a second click within four seconds.
- The learned word list keeps its most used words when it grows past its limit. A list full of words that had all been
  seen more than once used to stay too big, and every chat message then rebuilt the whole index.
- A part of the addon that fails while it starts (hooks, options, keyboard) is reported and no longer stops the parts
  after it.

## 0.1.0-alpha.69

- Keyboard: Hybrid is the default T9 mode (a saved Tap or Smart choice is replaced once).

## 0.1.0-alpha.68

- Settings: a window of its own (`/cgp`) with tabs General, Hints, Chat, Keyboard and Tools, replacing the long list in the game's Settings panel. Plain frames, so it opens in combat and in Gamepad Mode; with a controller D-pad up/down select, left/right adjust, A activates, LB/RB switch tabs, B closes. Options > AddOns > ClassicConsoleGamepadUI keeps one button that opens it. The window position is remembered.

## 0.1.0-alpha.67

- Keyboard: new Hybrid T9 mode (tap the letters, suggestions complete the word; LB/RB pick, Y accepts). Words typed in Tap mode are learned too.
- The keyboard language and the T9 mode (Tap, Smart, Hybrid) moved from keys on the keyboard to the addon's settings (On-screen keyboard); both are remembered. `/cgp keyboard hybrid`.

## 0.1.0-alpha.66

- Keyboard: a language key (EN, DE, PL) switches the layout and remembers the choice. EN is plain QWERTY, DE is QWERTZ with ä ö ü ß, PL is QWERTY with an extra row of Polish letters. The phone layouts get the letters of the language under their keys. `/cgp keyboard en|de|pl` sets it too.

## 0.1.0-alpha.65

- Keyboard: the full layout is always QWERTY (no Y/Z swap on German clients); the keys for ä ö ü ß stay at the ends of the rows.

## 0.1.0-alpha.64

- Keyboard: the strip above the T9 keys says which layout is active (Tap or Smart) and how it works; the Smart key is highlighted while the smart layout is on, and the strip says when no word matches.

## 0.1.0-alpha.63

- Fix: removed the raw pad button probe of alpha.60 (`SetPropagateKeyboardInput` is protected and was blocked when the keyboard opened with the chat line in combat).
- The keyboard that opens with the chat line now does so a frame later, outside the game's own call that opens the line.

## 0.1.0-alpha.62

- Keyboard: the T9 layouts compose a word in a buffer of their own, shown in a strip above the keys, and put it in the chat line only when it is accepted (Y adds a space, X sends, Done, the 0 key of the smart layout). Multi-tap no longer depends on the chat text, so repeated presses cycle through the letters; a pause of 1.5 s, a move of the selection or RB (multi-tap layout) ends a letter.

## 0.1.0-alpha.61

- Keyboard: Blizzard-style look (dialog frame, tooltip-border keys with a gold edge on the selected key) and lower on the screen by default.
- Keyboard: the button prompts are icons (round A/B/X/Y, D-pad cross, LB/RB/LT/RT/Start plates) with a short label, in the style of the game's own prompts.

## 0.1.0-alpha.60

- Keyboard: when the chat takes over a pad button's binding (it sets its own when the line opens), the keyboard binds its buttons again, at most once a second.
- `/cgp keyboard debug` shows what each pad button is bound to and whether raw pad buttons reach the keyboard.

## 0.1.0-alpha.59

- Keyboard: no longer opens by itself at login (the chat reports focus while loading in); it opens with the chat line only from 5 seconds after entering the world, and an automatically opened keyboard closes when the chat line does.

## 0.1.0-alpha.58

- Keyboard buttons follow the chat's own prompts: A key, X sends the line, B closes, Y accepts the suggested word (a space elsewhere), RT deletes, LT shift, Start done.
- Sending goes through securecallfunction so the chat's own code is not run with this addon's taint.

## 0.1.0-alpha.57

- Keyboard: X accepts the suggested word (and adds a space) in the smart T9 layout; RT deletes in every layout (X deletes in the others).
- Keyboard: finds the open chat line even when the game does not report it as active, and shows "No chat line is open" on the keyboard when there is none.

## 0.1.0-alpha.56

- Keyboard controller buttons: B closes the keyboard, X deletes, Y is space, LT is Shift (capital letter),
  LB / RB pick another suggested word, Start is Done and also closes it, A types the highlighted key.
  Back / Select still closes it.
- More diagnostics for blocked-action reports: the saved trace now lists what the keyboard did (`Keyboard:Press`,
  `Keyboard:Show`, pad bindings on / off), and the first-taint check also watches the binding stack and more
  `InputBindingManager.activeBindings` entries.

## 0.1.0-alpha.55

- Fix: using the on-screen keyboard could make opening the game menu in combat fail with
  "ClassicConsoleGamepadUI tried to call the protected function SetOverrideBindingClick()". The keyboard opened,
  focused and sent the chat line itself, which ran the game's chat focus and gamepad binding code inside the
  addon and left 60+ native binding fields tainted (`/cgp taint`: `InputBindingManager.activeBindings.PAD1`, ...).
  It now only inserts and deletes text in a chat line that is already open. Open the chat line the normal way
  (Enter, the chat button or the controller), type, press Start (Done) and send with the game's own A / Enter.
  Without an open chat line a message says so instead of opening one.

## 0.1.0-alpha.54

- T9 with word suggestions: the `Smart` key on the phone layout (or `/cgp keyboard smart`; `/cgp keyboard tap`
  returns to plain multi-tap). Press each key once per letter (4 2 5 5 6 for "hallo"); the best match is
  shown in the chat line, five more are in the top row (click one, or LB / RB on the controller). 0 or a
  chosen suggestion adds a space, 1 is punctuation, B removes the last key, Y toggles the capital letter.
- The word list is learned, not shipped: a few dozen common English, German and Polish words to start, then
  the words of chat you read, of what you send and of quest and gossip texts, in the language you play. Only
  single words with counts are stored (SavedVariables, up to about 6000); `/cgp keyboard forget` clears them.
  Words with an apostrophe or a digit are not learned.

## 0.1.0-alpha.53

- On-screen keyboard for typing in chat (`/cgp keyboard`, or the button in the settings). It works with the
  controller too: D-pad moves the highlight, A types the key, B deletes, X is space, Y is Shift, Start sends,
  Back closes. The pad buttons are taken over only while the keyboard is open (not in combat, where addons
  cannot change bindings; the mouse still works and the pad returns after combat). Mouse: Shift applies to the next key, `<-` removes a character, Enter sends. It acts on the open chat
  line only (insert, delete, send) and can be dragged anywhere. The German layout swaps Y and Z and adds
  the umlauts and ß. Setting "On-screen keyboard when typing in chat" opens it with the chat line in
  Gamepad Mode (off by default).
- T9 layout (multi-tap, like an old phone keypad): 3 by 4 big keys, press 2 once for a, twice for b,
  three times for c, a fourth press for the digit; a pause or another key accepts the letter. 0 is space,
  1 holds punctuation and `/`. Switch with the `T9` / `ABC` key or `/cgp keyboard t9` / `/cgp keyboard abc`;
  the choice is remembered. Same controller buttons as the full keyboard.
- Messages sent from it are chat messages; commands that need protected actions (`/cast`, `/target` in combat)
  are the game's to refuse when they are not typed by hand.

## 0.1.0-alpha.52

- The player, target and focus frames can be moved in Edit Mode while in Gamepad Mode. Drag them and save the
  layout: the new place is remembered and no longer reverts to the top left. Leaving Edit Mode without saving
  drops the move, like any other Edit Mode change. `/cgp resetframes` puts them back at their classic places.
- New setting "Classic player, target and focus frames" (on by default). Off leaves these frames entirely to the
  Edit Mode of the gamepad layout.
- The classic places of the target and focus frames are now captured in keyboard/mouse mode even while those
  frames are hidden (before, they were captured only while a target or focus existed).
- The classic frames stay put while Edit Mode is open instead of jumping back to the gamepad layout.
- `/cgp scale` describes what actually works. README: on-screen keyboard for typing in chat (Steam Deck,
  Windows touch keyboard); the packaged AI instruction files name this repository.

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
