# Changelog

## Unreleased

- Reduce repeated HUD anchor, opacity and secure-input updates while the bars are unchanged.
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
