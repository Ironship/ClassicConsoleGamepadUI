# Native source contracts

Inspected on 2026-10-22 against Gethe/wow-ui-source branch `forever`, commit
`172a387e3ab85b26e6640d3058d5ec1e6ccd4c63`. These are exported Blizzard source files;
their presence does not establish live-client execution permission.

The local Forever executable was independently inspected as **1.60.1.70450**,
matching the exported source commit's build **1.60.1 (70450)**.

- `Blizzard_Settings_Shared/Blizzard_ImplementationReadme.lua` and
  `Blizzard_SettingControls.lua`: register ClassicConsoleGamepadUI as a native vertical AddOn
  settings category with 17 proxy settings, native checkboxes/sliders and settings
  buttons, preserving native gamepad navigation. `/cgp` opens this category.
  Defaults and numeric ranges are shared between initialization and registration.
  Button captions use addon-localized text because `OPEN` is absent in this client.
  Layout settings invalidate geometry outside combat; hint switches preserve bindings.
  Chat returns to its saved position before recalculating a changed clearance.
  `modifierScale` sizes LT/RT glyphs independently of the button glyph scale.
  Owned click buttons track `cgppressed` in their secure click phases, clearing it
  on release, hide and drag; keyboard feedback does not depend on mouse-up events.
  A mirrored slot records the stock button's command, deriving it from `buttonType`
  and ID if the hidden button has not run `UpdateHotkeys`. Keyboard aliases and the
  binder share that command and read `GetBindingKey(action, nil, context)` like the
  native keybinding editor. They do not allocate or overwrite saved keybindings.
- `Blizzard_StaticPopup_Game/GameDialog.lua`, `Blizzard_StaticPopup/StaticPopupGamepad.lua`
  and `Blizzard_GamepadSharedUtility/InputSequence/InputSequence.lua`: optional easy
  deletion only intercepts item-destruction popups that require controller confirmation.
  Its own secure header tracks X, X, A, A and clicks the native accept button on
  the fourth down event. It does not rewrite native sequence tables, callbacks or
  the input binding stack. A combat state driver removes its overrides; popup close,
  lost focus and input-mode changes restore the original sequence's opacity.
- `Blizzard_Settings_Shared/Blizzard_Keybindings.lua`: the native binding editor
  receives both keyboard and gamepad input, handles binding contexts/conflicts and
  saves changes. Open it through `Settings.KEYBINDINGS_CATEGORY_ID`. The bar
  assignment mode writes with `SetBinding` in `C_KeyBindings.GetBindingContextForAction`
  and `SaveBindings(GetCurrentBindingSet())`. It does not replace `KeybindListener`.
  While it is open, temporary click overrides are cleared and the slot hitboxes stay
  shown. Hovering a mirrored slot binds that classic position (`bindingAction`);
  hovering a stance or pet button binds its `commandName`. Escape ends the mode.
- `Blizzard_GamepadActionBars/ActionBarEditFrame.lua`: enter action editing with
  `EnterEditMode()` outside combat while Gamepad Mode is enabled. Close the Settings
  panel through its own commit/confirmation flow, restore native input hitboxes and
  allow the existing editor visibility hooks to return the classic HUD after editing.
- `Blizzard_SettingsDefinitions_Shared/Gamepad.lua`: find the native controller
  settings category by its localized name instead of relying on a fixed numeric ID.
- `Blizzard_SharedXML/Mainline/InputUtil.lua`: Gamepad UI is determined by
  `C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad`.
  `C_GamePad.IsEnabled()` is not equivalent to enabling Gamepad Mode.
- `Blizzard_SharedXML/InputUtil.lua`: the native transition event is
  `INPUT_DEVICE_INTERFACE_TRANSITION`.
- `Blizzard_ActionBar/Mainline/ActionButtonTemplate.xml`: gamepad buttons inherit
  `SecureActionButtonTemplate`. Insecure per-trigger changes to their anchors would
  risk combat restrictions. ClassicConsoleGamepadUI does not change their anchors, size,
  parents, attributes, scripts, bindings or IDs.
- `Blizzard_GamepadActionBars/PageUnit.lua`: native no-trigger/LT/RT/LT+RT selection
  maps to top/left/right/bottom bars. Pet and stance bars may override these bars.
  Native special page 4 hides ordinary pageable bars.
- `Input.lua` owns protected hitboxes separately from the unprotected visual slots.
  Setup, geometry and keyboard-binding refreshes happen outside combat. The input
  controller is parented to the native gamepad HUD and clears temporary bindings
  when hidden. Its children are excluded from suppression of invisible native hitboxes.
- `Blizzard_RestrictedAddOnEnvironment/SecureHandlerTemplates.xml`, `SecureHandlers.lua`
  and `RestrictedFrames.lua`: secure click wrappers read pre-registered native bar,
  anchor and button frame references. Native visibility and override parents select
  the source. The combined layer uses the native active frame level (5), also used
  by the visual bottom-bar selection; this level is set even with highlight art off.
  The source selected on press is retained through release. No insecure combat-time
  updates to protected action attributes or frame references are required.
- `Blizzard_FrameXML/SecureTemplates.lua`: ordinary and pet actions use secure
  `action`/`pet` types with the current native storage ID. Reserved controls, class
  buttons and flyouts delegate native press/release through secure `/click` macro
  text, whose down argument is supported by `Blizzard_ChatFrameBase/Shared/SlashCommands.lua`.
  Ordinary action macros use the action path rather than chained `/click` macros.
- `ActionBarActionButtonMixin:UpdateHotkeys()` supplies each stock position's
  `bindingAction`. Read its keyboard keys in the native binding context, exclude
  controller keys, and apply temporary secure binding-click overrides while the
  classic HUD is active. The synthetic `Keybind` button distinguishes keyboard
  presses from physical mouse clicks before forwarding the effective left button.
  Keyboard casts follow the native key-down setting; mouse casts wait for release.
  Native flyout visibility securely hides/resumes hitboxes and their bindings.
- `Blizzard_GamepadActionBars/FlyoutRadial.lua`, `PageUnit.lua`, `Camelot/ClassSpellFlyout.lua` and
  `Blizzard_Flyout/Flyout.lua`: a selection radial is a `GamepadFlyoutTemplate` frame (`SecureFrameTemplate`, so
  protected; DIALOG strata, toplevel). The warrior's stances, the druid's forms and the paladin's auras are flyouts 269,
  262 and 270 on `RightClassAction` / `LeftClassAction`; the pet commands and any bar button's flyout work the same way.
  `AttachToButton` hangs the flyout off UIParent, moves the button into it and centres it on the button's stock place;
  the right stick selects (`UpdateSelection`) and a release in the dead zone clicks the choice. Only a bar button's
  flyout makes `PageUnit:OnFlyoutOpened` fade the page unit to 0.35 (a class action has no `parentActionBar`). The radial
  therefore shows over the faded stock HUD, and `Display:Refresh` keeps the classic bars up under it, faded to the same
  alpha, instead of switching to the native view: that switch moved the bags, micro menu, status bars and chat back to
  their stock places while the radial was open, and in combat it could not be undone until the fight ended. The radial
  is not moved (a protected frame cannot be anchored in combat). The action editor's radials still use the native view,
  because the bars are drawn above the editor's dimmed screen there.
- `Blizzard_ActionBar/Shared/MultiCastActionBarFrame.lua`, `Blizzard_ActionBarController/ActionBarController.lua`,
  `Blizzard_EditMode/Camelot/EditModeUtil.lua` and `Mainline/EditModePresetLayouts.lua`: the Shaman's totems are a mouse bar
  (four slots with a flyout on hover, the summon and recall spells), not a selection radial: `ClassSpellFlyout.lua` knows
  only the druid, paladin and warrior, and `Blizzard_GamepadActionBars` has nothing about totems. `TotemActionBarMixin:
  UpdateShownState` does not ask `InputUtil.IsMKBUIEnabled()` (the stance bar's `ShouldShow` does), so the bar is shown in
  Gamepad Mode, at the gamepad layout's anchor for it (`EDIT_MODE_GAMEPAD_SYSTEM_MAP` copies the modern one: `RIGHT` of the
  bottom middle, -28 and 128 up). The gamepad layouts have no bottom bar stack (`EditModeUtil.GetBottomActionBars` returns an
  empty list), so nothing lifts it over the classic bars. `Layout:PlaceTotemBar` anchors it with `SetPointBase` to the left
  end of the bottom row plus the 30 point indent (`BOTTOM_ACTION_BAR_DEFAULT_OFFSET_X`), above the top of the upper row, the
  class actions and the shoulder indicators plus `BOTTOM_ACTION_BARS_SPACER_Y`, outside combat and only while
  `IsInDefaultPosition()` holds (a bar dragged in Edit Mode stays). `Layout:Restore` puts the game's anchor back, and the
  `ApplySystemAnchor` hook it shares with the other bars places it again after the game re-anchors it. The keyboard place of
  the bar is not saved with the others.
- The upper row stays fixed: L2 uses slots 13-20 and R2 uses slots 25-32.
  Compact mode hides 21-24 and 33-36, moves the right section left by four stock
  button pitches and shortens the main border by the same amount. The upper row is
  then aligned so its first slot starts above bottom slot 1 (no manual shift), and
  the bags are right-aligned under slot 32, at least one half-gap from slot 8.
  Positions come from one measurement pass. After the
  visible slots, micro menu and bags are placed, the mirrored gryphons close up
  to that span (keeping the stock 30-point overlap), the border is trimmed where
  it sticks out, and the experience/reputation bars adopt that width. The whole
  group, including bags but not the micro menu, is then shifted so the gryphons are centered
  on UIParent. Bag anchors and status-bar width follow that centered HUD.
  The micro menu is anchored to the right edge of UIParent, 12 points in, with its
  bottom at UIParent y = 0 by default. The settings panel exposes both edge distances.
  The original menu anchor, the other anchors, and keyboard status widths are restored on exit. Sizes of
  individual buttons and end-cap artwork are unchanged. Geometry changes wait
  for combat to end.
- In the 12-slot layout the L2+R2 layer is split across the stock bars: slots 21-24 (native buttons 5-8) follow the L2
  row and slots 33-36 (native buttons 1-4) close the R2 row. `db.groupBoth` draws 33-36 on the stock positions of 25-28 and
  the R2 row (25-32) on those of 29-36, so the eight sit together between the two rows (`Display.PlacementTemplate`); the
  right shoulder indicator then goes above slot 32. Only positions change: the click targets follow the slots, and the keys
  stay with their slots. It is a layout setting, applied outside combat like the others.
- Each visible row of eight shows native buttons 5-8 (face, X Y B A) then 1-4 (cross).
  The secure click index uses that same order. The main row's stock buttons run
  right to left, so slots 1-8 are placed on buttons 8-1 and the keyboard labels
  read 1 through 8 from the left. Native mouse capture on the hidden gamepad bar
  is cleared from the secure header, and SettingsPanel is observed with
  hooksecurefunc, so closing the game menu can still call
  SetPreferredGamepadInteractTarget.
- Compact bottom slots 1-8 mirror the no-trigger layer (with native L1/R1 contextual
  overrides), or the L2+R2 layer when `PageUnit:GetActiveBar()` selects it. Slots
  9-10 display class actions above the upper row only while that native button is shown;
  an empty class slot is hidden so its keyboard binding (for example ACTIONBUTTON9) is not drawn.
  11-12 are hidden. Extended mode
  keeps class actions in 9-10, empty slots in 11-12, and splits the L2+R2 layer across
  21-24 and 33-36. Each visible native source is mirrored once, so cooldown forwarding
  and drag/drop follow the visible action. Current native prompts and active-bar
  highlighting are retained, including swapped targeting modifiers and hold/toggle
  behavior. Disabled native actions retain their local alpha. A filled slot hides
  the keyboard empty-slot plate (`SlotArt` and `SlotBackground`) and draws the
  native action icon across the frame interior, without the icon mask. An empty
  slot keeps the flat background only. The class-slot weapon icon stays the
  action icon; the plate was the misleading background.
- `InputConstantsDocumentation.lua` exposes only `Mkb` and `Gamepad` interface types.
  Steam Deck uses the same saved compact/extended choice while in Gamepad Mode;
  keyboard/mouse mode remains native. Layout size never changes native binding
  capacity or action storage.
- `Blizzard_GamepadActionBars/TargetActionBars/StaticOverrideActionBar.lua`:
  targeting/shortcut bars replace the top bar; their special icon and icon overlay
  matter independently of the normal action texture.
- `Blizzard_GamepadActionBars/ActionBarButton.lua`: gamepad presses can use
  `ApplyPressedStyle` independently of the generic button's pressed state.
- `Blizzard_GamepadActionBars/MainActionBarFrame.lua`: the left/right shoulder
  icon and highlight reflect targeting swaps and current modifier state. Mirror
  the left one above the first upper-row slot and the right one above the last
  visible upper-row slot (32 in compact, 36 in extended), using stock slot art and a
  12-point gap. Resolve `GAMEPADLEFTTARGETMODIFIER` and `GAMEPADRIGHTTARGETMODIFIER`
  bindings in their native binding context for controller glyphs. Keep these display
  frames in the geometry list so chat clearance includes their new position.
- `Blizzard_GamepadActionBars/ActionBindingUtil.lua` and
  `Blizzard_ActionBar/Shared/ActionButton.lua`: mouse drag/drop uses `PickupAction`
  and `PlaceAction` with native gamepad storage IDs. Visible slots resolve their
  current native source at the hardware event, reject combat and IDs not accepted by
  `C_GamepadUI.IsValidGamepadActionStorageSlotIndex`, and respect the action-bar lock
  when picking up an action. Cursor contents and controller cursor mode never select
  the native view. Replacing an action retains the displaced action on the cursor.
- `Blizzard_ActionBar/Shared/PetActionBar.lua`: pet drag/drop uses `PickupPetAction`,
  accepts only `petaction` cursor contents and rejects charmed-pet edits. Reserved
  and contextual controls without valid storage IDs cannot be edited. Stance-bar
  buttons follow the same native storage validation as standard actions. Stance
  hotkeys are the saved `SHAPESHIFTBUTTON` bindings drawn by the native buttons.
  The addon does not renumber them. Left to right is stance button 1, 2, 3, 4.
- `Blizzard_SharedXML/Shared/InputIcons/InputIconTexture.lua`: controller glyphs
  live in the native prompt's Normal/Pressed/Active/Hover/Disabled textures.
- `Blizzard_MicroMenu/Mainline/MainMenuBarMicroButtons.lua`: add controller hints
  after native tooltip construction without overwriting the button's tooltip text.
  Read the button's `commandName` and current gamepad bindings first. For panels without
  a direct shortcut, read `GamepadRadial.mainMenuPages` and `segmentOptions`, matching
  each handler's native micro button. The radial opens on page 2, shoulder buttons
  change pages, and the right stick selects a segment counter-clockwise from east;
  returning the stick to center activates it. Glyphs come from the active input icon
  set. No input bindings or radial handler tables are changed.
- `Blizzard_APIDocumentationGenerated/ActionBarFrameDocumentation.lua`:
  `C_ActionBar.GetActionCooldownDuration` returns a duration object. Forward it to
  the display's own cooldown widget without inspecting or computing its contents.
- Native cooldown widget setters are observed with secure post-hooks. Readable
  arguments and duration objects are forwarded unchanged; restricted numeric times
  instead re-read `C_ActionBar.GetActionCooldownDuration`. Pet cooldowns with
  restricted numeric values and missing duration objects clear the mirror.
  No shared native callback table is modified.
- `Blizzard_EditMode/Mainline/EditModePresetLayouts.lua`: the classic unit-frame
  and bar anchors supply a fallback before a keyboard/mouse layout has been captured.
- `Blizzard_EditMode/Shared/EditModeManager.lua`: `OnSystemPositionChange` runs after a drag or nudge,
  `SaveLayouts` after Save (also right after `RevertAllChanges` when a preset is saved as a new layout) and
  `RevertAllChanges` on exit. Post-hooks keep a drag of the player, target or focus frame as a pending move;
  `SaveLayouts` commits it to `gamepadHUD`, a revert drops it. The classic place is then
  `moves` > `gamepadHUD` > `keyboardHUD` > preset. The frames are not restored to the gamepad layout while
  Edit Mode is open. The hooks are post-hooks: nothing in Edit Mode's tables is written.
- No on-screen keyboard exists in the client's Lua UI (`Blizzard_Gamepad*`, chat, API documentation), so
  `Keyboard.lua` draws one from plain unprotected frames. It acts only on a chat line the player has already opened
  (`ChatFrameUtil.GetActiveWindow`; any shown `ChatFrameNEditBox` as fallback) and only with `Insert` and `SetText`.
  It never opens, focuses or sends the line. `Blizzard_ChatFrameBase/Shared/ChatFrameEditBox.lua`:
  `OnEditFocusGained` and `SendMessage` (through `ClearChat`, `Hide` and `ChatFrameUtil.DeactivateChat`) run
  `FrameControlsManager` and the `InputBindingManager` binding sets, and `SendText` calls `ParseText(1)`, which runs
  secure slash commands. Called from addon code all of it runs with the addon's taint, and `securecallfunction`
  does not change that: `CallbackRegistryMixin:TriggerEvent` uses it so that an addon callback's taint does not reach
  the game's own caller, not the other way round. Sending is the game's: the footer's "A: send" is an
  `InputFunctionBinding`, i.e. `PAD1` bound to the global button `InputFunctionBindingButton_PAD1`, whose `OnClick` calls
  `PromptedBindingMixin:TriggerBinding` (only on a key down, so a secure `type = "click"` action, which calls
  `Click(button)` with `down = false`, cannot trigger it). While the chat line has the focus,
  `box.chatFrame.footer.isShown` is true (read raw: the footer is a mixin table whose metatable throws on a missing
  field) and no word waits in the buffer, the header binds X straight to that button
  (`SetBindingClick(true, "PAD3", "InputFunctionBindingButton_PAD1", "LeftButton")`, attribute `sendbutton`), so the
  game runs its own send. `Keyboard:SyncSend` follows that state (the 0.25 s check, every change of the buffer, the
  chat's focus callbacks). A waiting word goes into the line with the first X. Start is Done: the word goes into the
  line and the keyboard closes. The keyboard also hides when a chat line it has seen closes.
  `ChatFrame.OnEditBoxFocusGained` (EventRegistry callbacks run through `securecallfunction`) opens the keyboard with
  the chat line when the setting is on, a frame later and not within the first five seconds after entering the world.
- Keyboard controller: like `ItemDelete.lua`, a `SecureHandlerShowHideTemplate,SecureHandlerStateTemplate` header
  binds the D-pad, face buttons, shoulders, triggers and Start/Back (and their SHIFT-/CTRL- variants, swallowed) to a
  `SecureActionButtonTemplate` while the keyboard is shown in Gamepad Mode; its wrapped `OnClick` only bumps
  `padcount`/`padtoken`, which an `OnAttributeChanged` hook reads. The `[combat]` state driver clears the bindings and
  the keyboard's 0.25 s `OnUpdate` shows the header again after combat. The chat's footer
  (`FloatingChatFrameMixin:CreateFooter`: PAD3 channels, PAD4 tab settings, PAD1 send, back prompt) binds its keys with
  `SetOverrideBindingClick(UIParent, true, ...)` (`InputButtonBinding` / `InputFunctionBinding`), the same priority as the
  header's `SetBindingClick(true, ...)`, and does it again at every `Gamepad.RefreshFrameFocus` and SmartNavigation
  selection (`PromptedBindingFooterMixin:Refresh` / `RefreshBindingGroup`). The newest binding wins, so the keyboard
  binds its buttons again after `InputBindingManager:AddBindingSet`, `RemoveSet` and `ClearBindings` (post-hooks), once,
  at most every 0.1 s, only when `GetBindingAction(key, true)` shows one of its buttons bound to something else;
  `Input.lua` does the same for the action bar keys (`BindingsLost`). `/cgp keyboard debug` lists what each button is bound to.
- The phone layouts compose a word in a buffer of their own (shown in a strip above the keys) and put it into the chat
  line only when it ends. Y, the Space key and the 0 key end it with a space (`Keyboard:Flush(true)`); Done and X end it
  without one. The 0 key of Tap and Hybrid turns the space it just added into a 0 on a quick second press (`Keyboard:Zero`),
  so a space is never part of the buffer and the suggestions only ever look at the word being typed. The line is the only
  state shared with the game. Tap cycles a key's letters (1.5 s, a move of the selection or RB ends a letter), Smart keeps
  the digits of the word and asks `Words.lua` for matches (exact digit sequence by score, then longer words that start with
  it), Hybrid taps letters and asks `Words:Prefix` for words that begin with them. `db.keyboardLanguage` (EN, DE, PL, FR,
  ES, IT, PT, see `Languages.lua`) picks the full layout and the letters under the phone keys, `db.keyboardMode` the layout
  in use (`abc`, `t9`, `t9p`, `t9h`; Hybrid by default) and `db.keyboardPhone` the phone layout that the mode key goes back
  to. Words come
  from `CHAT_MSG_*` (text checked with `issecretvalue`), quest and gossip text events, a post-hook on `SendChatMessage` and
  the words accepted on the keyboard; item links and colours are stripped and only letters are kept. Past 6000
  words the 4500 most used are kept. `db.keyboardEnabled` (the settings window's Keyboard tab, on by default) turns all of
  it off: `Keyboard:Show` does nothing (it says so when the player asked, not when the chat line asked), `SetEnabled(false)`
  hides an open keyboard, `Words:Learn` returns before it reads the text, so the word index is not even built, and the
  chat-focus callbacks schedule nothing before a pad exists. The hooks stay installed (a post-hook cannot be taken back) and
  find nothing to do. The rows that depend on it are dimmed in the window (a `parent`).
- The full keyboard types straight into the chat line, so it has no buffer (`Keyboard:Pending` is empty in mode `abc`). Its row of
  suggestions (`UpdateHints`) is made for the word at the end of the line (`TypedWord`: its letters, nothing while a slash command
  is being typed), and read again with the 0.25 s check (`WatchTyped`) because the line also changes by other means. `Complete`
  replaces those letters with `SetText` (the cursor goes to the end, like `Delete`), adds a space and teaches the word; LB/RB
  cycle with `Cycle`, Y and the Space key take the chosen one, a click `Choose`s it.
- Languages and texts. `Locales.lua` keeps the texts: each file in `Locales/` registers one language (`enUS` is the base, a key
  a language leaves out is shown in English) and `Addon.L.key` reads the language in use (`db.language`: a code, or `auto` for
  the game client's; English by default). Changing it makes `SettingsWindow:Relocalize` (tabs and pages are built again, the
  pad selection stays on its row) and `Keyboard:Relocalize` (keys and prompts) rebuild what holds texts; the Options > AddOns
  button keeps its text until the next reload. `Languages.lua` holds what the keyboard knows about each typing language (the
  rows of the full keyboard, the letters under the phone keys, common words) and the letter tables (`Upper`, `Lower`, `DIGIT`),
  which work by byte range and table so they never depend on the client's locale.
- Fonts. The game's interface font (Friz Quadrata) has only ó and ł of the Polish letters; ą ć ę ń ś ź ż show as boxes.
  `Fonts.lua` makes copies of the game's font objects (`CGPFont...`, `CopyFontObject`) that every text of the addon uses
  (`Fonts:String`, `Fonts:Button` for the three fonts of a button). `Fonts:Update` puts the chat's font file
  (`ChatFontNormal:GetFont()`, Arial Narrow, 8 % bigger) under the interface copies while the interface language is Polish and
  under the key copies (keys, the strip, suggestions) while the keyboard types Polish; a font object passes the change on to
  every text that uses it. The game's own tooltip cannot be changed, so the settings window shows its tips in a tooltip of its
  own while the interface is Polish, and the two Polish texts that reach the game's tooltips (`openTip`, `stickCenter`) are
  written without the missing letters.
- `WordSources.lua` reads word lists for `Words.lua` and never writes to or loads anything of the other add-ons. English: the
  quest texts of English Quest Panel (`WordHunterWoW_QuestEN`), counted per word (names a little lower, words seen once left
  out). German, French, Spanish, Italian, Portuguese: the dictionary a WordHunterWoW dictionary registered with the base add-on
  (`WordHunterWoW_Addon.DictionaryProviders[locale]`; the keys are the words, there are no counts, "ignored" entries are names).
  The load-on-demand dictionaries (24-54 MiB each) are used only once the base add-on has loaded them. Reading is a coroutine
  resumed from an `OnUpdate` for 3 ms a frame, not in combat. The result is a `Lexicon` of 1-2 MB (15,000 to 110,000 words in
  buckets by their first three keys, plus the best words per first key and first letter for the shortest input), kept for the
  language in use only. `Words:Lookup` and `Words:Prefix` merge it with the player's own words and the common ones by score: the
  source's weight (0-31), 8 for a common word, up to 24 for use.
- The settings window (`SettingsWindow.lua`) is made of plain frames (`ButtonFrameTemplate`, `PanelTopTabButtonTemplate`,
  `UIPanelButtonTemplate`; no secure templates), so it opens in combat and in Gamepad Mode, and Options > AddOns has one
  button (`CreateSettingsButtonInitializer`) that opens it. In Gamepad Mode it takes the pad with
  `EnableGamePadButton` and an `OnGamePadButtonDown` handler that stops propagation for the buttons it uses.
  `SetPropagateKeyboardInput` is blocked for addons in combat (a BugGrabber report from the keyboard frame), so these calls
  are made out of combat only. It leaves the pad to the keyboard while that is shown.
- `Blizzard_Gamepad/UI/PersistentInputLegend/GamepadPersistentInputLegend.xml`:
  the legend's native top-left anchor overlaps the classic player frame. Outside
  combat, position its root 16 UI points from the left edge and 12 points below the
  restored player frame's bottom, converting effective scale to UIParent coordinates.
  Cache the computed position and preserve all original anchors/scale for native view,
  Edit Mode, addon disable and keyboard/mouse mode. Legend content stays native.
- `Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.lua` and `FloatingChatFrame.xml`:
  the main dock's other chat windows follow its primary frame, while the edit box
  and controller prompt row extend below it. The footer object is a mixin table,
  not a widget; measure `FloatingChatFrameinputLegend` (and the dock's matching
  legend) instead of calling methods on `frame.footer`. After the classic bars have been placed,
  compare their visible slot/art rectangles with the chat's horizontal extent and
  lift its primary frame only enough to leave 12 UI points below the lowest chat
  element. Use original geometry setters and never call chat-position save functions
  or change the frame's width/height. Restore captured anchors for native view; on
  input-mode transitions retain the new layout applied by the client.
- `Blizzard_ActionBar/Mainline/ActionButtonTemplate.xml` and
  `Blizzard_ActionBar/Mainline/ActionButtonOverrides.lua`: stock button regions
  provide the slot artwork, normal/pushed/checked/highlight textures and icon mask.
  ClassicConsoleGamepadUI copies those live regions and their rectangles rather than selecting
  replacement assets. Display geometry is converted to UIParent coordinates without
  anchoring mirror frames to protected buttons.
- `Blizzard_ActionBar/Camelot/MainMenuBarEndCaps.xml` and
  `Blizzard_ActionBar/Mainline/MainActionBar.xml`: copy the actual end-cap textures,
  bar artwork, page font and arrows, including their native dimensions and positions.
- `Blizzard_EditMode/Camelot/EditModeUtil.lua` and
  `Blizzard_EditMode/Camelot/EditModePresetLayoutConstants.lua`: Gamepad Mode skips
  the keyboard bottom-bar stack. Outside combat, restore its native anchors using
  captured keyboard positions or the client's preset. The 36 original slot rectangles
  hold 32 controller actions and two class actions, with two empty stock slots.
  Two additional display frames hold the shoulder indicators, the right one at the far end of the upper row.
- `Blizzard_StatusTrackingBar/Camelot/StatusTrackingBarConstants.lua`: restore the
  real status containers to their stock 1192-point width and 20 segments above the
  main bar. Native mode restores the previous width and gamepad segment count.
- `Blizzard_EditMode/Shared/EditModeSystemTemplates.lua`: use original C geometry
  setters (`SetPointBase`, `ClearAllPointsBase`, `SetScaleBase`) where supplied, avoiding
  Edit Mode's Lua snapping wrappers and writes into its saved layout state.

Native action HUD changes: temporarily set its root alpha to zero and disable
invisible mouse hitboxes outside combat, recording click/motion flags separately.
Restore the exact alpha/input state for native view and bindings. The visual
mirror is intentionally not an extra set of spell-casting buttons.

All addon state is stored in its private table or `ClassicConsoleGamepadUIDB`. Native page
callback lists, frame methods and keybindings are never replaced or extended directly.
Protected unit-frame and keyboard-bar geometry is changed outside combat and restored
without writing the game's saved Edit Mode layouts. Returning to keyboard/mouse mode must never
restore a snapshot of the old gamepad layout over the newly applied keyboard layout.

The single active-mode observer polls at 10 Hz, with event/post-hook refreshes coalesced
onto the next frame for trigger presses and native state changes. It stops in
keyboard/mouse mode and when the feature is disabled. This is not an FPS measurement.
