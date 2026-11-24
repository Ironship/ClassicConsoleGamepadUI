# Native source contracts

Dynamic wheels check both the action slot and cursor immediately after placing an
item. If the same item remains on the cursor and the slot does not hold it, the
item is skipped until it leaves the bags, the wheel settings change, the UI
reloads, or `/cgp wheels dyn retry` is used; items already on the wheel remain
there. This does not classify an item as unusable from missing item data.
`/cgp wheels dyn` reports immediate write results and current slot contents;
`/cgp status` reports the latest blocked-action event since reload, including its
attributed addon and function.

When status-bar placement is disabled, bars retain their Edit Mode size and
custom position. A bar still in the game's default position is moved only if it
overlaps the classic controls; each geometry rebuild starts from the saved
native position before checking for collisions again.

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
  Ordinary action macros use the action path rather than chained `/click` macros. The same goes for the buttons of the
  keyboard bars (slots 9-12 of the 12-slot layout, class slots without a class action, and every slot with the setting
  `padKeyboard`): `PRE_CLICK` works out the button's action slot (`GetID()` plus `(page - 1) * 12`) and sets it as the
  `action` of the hitbox. A `/click <keyboard button>` macro text does not do for them, since the game does not run a macro
  from within a macro (a macro on the bars did nothing), and the `click` type does not either: a secure snippet stores a
  frame handle in `clickbutton`, not the frame, and `SECURE_ACTIONS.click` (`SecureTemplates.lua:561`) calls
  `HasAccessConstraints()` on it. The page of the two lower bars is fixed: `Input:SetKeyboardPages` takes it from what the
  button holds, `(button.action - button:GetID()) / 12 + 1` (the buttons hang off a container of the bar, so the bar's own
  `actionpage` attribute is not at hand), and puts it on the header as `kbdpage<slot>`, outside combat. The page of the main
  bar changes and is worked out in the snippet the way `ActionBarController.lua` sets `MainActionBar`'s `actionpage`
  (vehicle, override, temporary shapeshift and bonus bar indexes, else `GetActionBarPage()`, all in the restricted
  environment). A flyout on a keyboard button still goes through `/click`. `/cgp clicks` prints each click after the secure
  code handled it (type, action, what the action is, macro text of a delegated click).
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
  The micro menu is anchored to the right edge of UIParent, flush with it (`menuRight`, 0 by default), with its
  bottom at UIParent y = 0 by default. The settings panel exposes both edge distances. With `hideMenu` the menu is faded
  out (alpha 0) and moved just past the right edge; Edit Mode systems are clamped to the screen
  (`EditModeSystemTemplates.xml`), so the clamp is switched off while it is hidden (`Display.menuUnclamped`, restored with the
  menu and in `Layout:Restore`), else it would be pulled back, invisible but clickable. Before moving it, `Layout:UnhookFrom`
  pins stock frames anchored directly to the menu, preserving the positions of their dependants as well. The frame-rate display is anchored to
  the micro menu (`FramerateFrameOverrides.lua`), so `Display:AnchorFramerate` puts it at the bottom right corner while the
  menu is hidden and asks the game to anchor it again afterwards.
  The original menu anchor, the other anchors, and keyboard status widths are restored on exit. Sizes of
  individual buttons and end-cap artwork are unchanged. Geometry changes wait
  for combat to end.
- In the 12-slot layout the L2+R2 layer is split across the stock bars: slots 21-24 (native buttons 5-8) follow the L2
  row and slots 33-36 (native buttons 1-4) close the R2 row. `db.groupBoth` draws 33-36 on the stock positions of 25-28 and
  the R2 row (25-32) on those of 29-36, so the eight sit together between the two rows (`Display.PlacementTemplate`); the
  right shoulder indicator then goes above slot 32. Only positions change: the click targets follow the slots, and the keys
  stay with their slots. It is a layout setting, applied outside combat like the others.
- Each visible row of eight shows native buttons 5-8 (face, X Y B A) then 1-4 (cross); `db.crossFirst` swaps the halves
  (`Layout.RowStart`, asked by `Display:Update` for what a slot shows and by `Input` for the index its click target presses,
  also for slots 21-24 and 33-36). Positions, anchors and keyboard keys are untouched: a slot keeps its place and its key and
  shows another native button, so the click target and the picture cannot disagree. It is a geometry setting: the secure
  indexes are rewritten with the next layout revision, outside combat.
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
  action icon; the plate was the misleading background. Ordinary action slots
  query `C_ActionBar.IsUsableAction` and use the stock blue tint when resources
  are insufficient; otherwise they retain the native icon's color. Secret
  usability values and special, pet and flyout icons keep the native appearance.
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
- Edit Mode keeps the classic bars: `Display:NeedsNativeView` goes native only for a radial of the action editor, no
  longer for Edit Mode. The faded gamepad bar's own selection box is invisible with it (alpha 0), so `EditMode.lua` draws
  selection boxes of the game's kind (blue, yellow once selected) for this addon's frames, in `HIGH` strata above that
  box. Each box is a spec (`Mover:Add`: bounds, drag, nudge, reset, position text, check boxes and sliders for settings
  of `Options.controls`); the classic bars and the gamepad legend have one each. A drag follows `GetCursorPosition` by hand
  instead of `StartMoving`, whose clamp to the screen would make the bars (flush with its bottom edge) jump when picked
  up, and stays on screen with the bounds it began with. A place is saved at once in this addon's saved variables, the
  same for every Edit Mode layout (Edit Mode does not know the frames, so its Save and Revert do not see them); the
  panel's reset button, `/cgp resetbars` and `/cgp resetlegend` put them back. Nothing calls into Edit Mode: a
  `SelectSystem` post-hook only drops this selection when the game selects one of its own systems. While Edit Mode is
  open the classic click layer is off (`Input:Refresh(false)`), so the pad drives the editor.
- Bar geometry after the slots are placed, in this order (`Display:RefreshGeometry`): `AlignCompactChrome`, `ApplyCaps`,
  `ApplyScale`, `Translate` with the Edit Mode offset, then `PlaceTotemBar`, so the totem bar, chat
  clearance and the Edit Mode box measure the finished bars. `Display:Regions` lists what moves: the slots and the art,
  and the stock frames that travel with them (status bars and bags in both layouts, and the menu in the full layout;
  none while a placement setting keeps it). `Translate` measures everything before it moves anything, since the shoulder
  indicators hang off slots; during a drag `FollowOffset` moves the built bars by the difference, and the rebuild after
  the drop moves chat and the totem bar along. `MoveX` takes UIParent points and divides by the region's effective scale.
- `db.barScale` (0.5-1.5, "Classic bars size"): `Display:ApplyScale` grows or shrinks the built bars about the middle of
  the bottom edge of what shows (hidden spare slots of the compact layout can sit at stock places outside it). Slots get
  `SetScale` (icon, cooldown, prompts and glyphs follow) after `RefreshGeometry` set them back to 1, the art gets
  `SetSize`, and managed status bars, bags and menu scale as whole frames in both layouts. This includes the status
  bars' height, dividers, text and rested overlay. Compact bags stay under the
  R2 half and the compact menu stays at the screen edge. Their scales are restored (`ResetStockScales`, only if nothing
  else changed them since) before the layout measures them again, so repeated rebuilds do not compound the scale.
  Resizing a status bar also updates its tick, which recalculates the rested experience overlay's width.
  The scaling pivot includes both caps even when hidden and excludes unused compact slots, so changing visibility does
  not shift the remaining bars. Copied text from other addons scales with the classic slot rather than the native button.
- `db.showLeftCap`, `db.showRightCap`: the gryphons (`art[2]`, `art[3]`) are shown or hidden after they are placed; a
  hidden one still sets where the bars are centered, so the bars do not move. Changing either
  rebuilds the layout (outside combat; the art itself changes at once).
- The gamepad legend in Edit Mode: `db.legendSpot` is the legend frame's top-left corner in UIParent points from the
  screen's top-left (so it keeps its distance from the top on any screen height) and wins over `moveLegend`; the legend
  keeps it in Edit Mode too. With `db.legendGrowUp` the spot is the bottom edge of the hints instead (`anchor =
  "bottom"`): `HUD:LegendContent` measures the shown children (not the largest set, `LegendExtent`), and an `OnUpdate`
  places the frame so they end there, in the frame the hints change and in combat while `IsProtected()` is false.
  Switching it converts the spot where the legend stands, so nothing jumps. `db.legendFrame` and `db.legendShade` act on
  the legend's art, found by the names its templates give their pieces (nine-slice corners and edges or a large
  `*Border*` for the frame; a nine-slice `Center` or a large `*Background*`, `*Backdrop*`, `*Shade*` for the shade; the
  unnamed pieces of a frame named like that take its kind; widgets are told by the userdata at `[0]`). Only alpha
  changes, from the alpha each piece had when found, scanned again when a new set of hints shows; the defaults give every
  piece its alpha back. `/cgp legend` lists every texture of the legend with the kind it got.
- Placement settings (`placeMenu`, `placeBags`, `placeStatusBars`, `placeTotemBar`, all on by default): off, the frame is
  left where the gamepad layout's Edit Mode puts it. `Layout:Prepare` still places such a frame from its stock anchor
  like the others (the bags can hang off the menu, so the rest is measured from the classic places), measured first and
  put back at the end where it was, at its Edit Mode scale (and width, for a status bar); frames anchored to it are
  pinned where they are first. Display places nothing the layout keeps (`Layout:Keeps`). A kept status bar leaves no gap
  in the stack the fallback anchors build. The settings alone decide: a layout that once moved one of these frames does
  not change the classic look. Switching one sets `Layout.releasePending`, so the next `Prepare` restores every frame
  first and a frame let go is measured where Edit Mode has it. The `ApplySystemAnchor` post-hook drops that frame's
  snapshot, so a restore returns it to its newly saved place.
- "Reset all settings" (`Options:ResetAll`, Tools tab, asks twice, outside combat): every entry of `Options.controls` to
  its default, `legendSpot`, the keyboard's position, language and mode, and the unit frames' Edit Mode moves
  (`HUD:ResetFrames`); every stock frame is restored before the layout runs again. The interface language, the learned
  words and the captured keyboard/mouse layout stay.
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
  to. `db.keyboardEnabled` (the settings window's Keyboard tab, on by default) turns all of
  it off: `Keyboard:Show` does nothing (it says so when the player asked, not when the chat line asked), `SetEnabled(false)`
  hides an open keyboard, `Words:Learn` returns before it reads the text, so the word index is not even built, and the
  chat-focus callbacks schedule nothing before a pad exists. The hooks stay installed (a post-hook cannot be taken back) and
  find nothing to do. The rows that depend on it are dimmed in the window (a `parent`).
- Learned words (`Words.lua`) are two tables per language of the keyboard, `db.own[language][word]` and
  `db.seen[language][word]`, each a count. Own words are what the player sends (a post-hook on `C_ChatInfo.SendChatMessage`,
  which the chat's edit box calls; older clients: the global `SendChatMessage`; the text is checked with `issecretvalue`) and
  what they accept from the suggestions (`Flush`, `Complete`). Seen words come from `CHAT_MSG_*` and from quest and gossip text
  events, and only while the keyboard types the language of the game (`Words.ClientLanguage`, from `GetLocale`), because those
  texts are in that language: one list for all languages let the quest texts of a German game fill the suggestions of a Polish
  keyboard. A word counts once per text; item links and colours are stripped and only letters are kept. `LearnSent` ignores the
  same text within a second (a message reaches both the game's function and its old global wrapper). Past 3000 own words the
  2500 most used are kept, past 6000 seen words 4500. `Words:Migrate` turns the flat `db.words` of earlier versions into
  `db.seen` of the game's language. `Words:Forget` (the settings button "Reset learned words", `/cgp keyboard forget`) clears
  both tables in every language; the Keyboard tab shows the counts for the language in use (`Words:Summary`) and
  `/cgp keyboard words` prints them. Only single words and counts are stored, never a sentence.
- The full keyboard is laid out by `FullRows` in `Keyboard.lua`, like a real one: every row is as wide as the digit row (15 key
  pitches of `KEY + GAP` pixels, wider only when a row cannot hold its letters and keys), the letters are `KEY` wide, and the keys
  that are not letters (`MIN_KEY` gives their least width) take what is left of their row: Back (digits), Clear and the last
  letter (second row), the layout key and Done (home row), Shift and Close (bottom letter row). A row whose letters leave no room
  for its optional key (`optional`: Clear, the layout key, Close) hands it to the row of the space bar, which is centred on the
  keyboard. The suggestions and the accented letters (`spec.extra`) are rows of equal keys, whole pixels, flush with the others
  (`Share`; accents at most `MAX_ACCENT` wide, a shorter row is centred). A letter with a width of its own is
  `{ letter = "ą", width = 69 }`; `Keyboard:Build` places the keys by those widths. The phone layouts are centred rows as before.
- `db.keyboardTransparency` (0 to 0.9, the settings window's Keyboard tab) takes that share off the opacity of the frame's
  background, the strip above the keys and the faces of the keys (`Keyboard:Opacity`, `ApplyTransparency`, which `Options:Changed`
  calls and `Create` calls once); letters and borders are not touched, and `MAX_TRANSPARENCY` keeps the keyboard from vanishing.
- Every call from the keyboard into `Words.lua` goes through `Suggest` (a `pcall`; a failure goes to `Addon:Note`, once), so the
  word list cannot break typing or the X binding. `Keyboard:WantsNativeSend` returns the first condition that is not met,
  `SendReason` turns it into a text, `SyncSend` keeps it in `diagnostics.keyboardSend`, `/cgp keyboard debug` prints it, and a
  press of X that reaches `PadPress` (so X was not the game's send button) saves it with the pad bindings as
  `diagnostics.xPress` and flushes the saved variables (`ReportSend`).
- The full keyboard types straight into the chat line, so it has no buffer (`Keyboard:Pending` is empty in mode `abc`). Its row of
  suggestions (`UpdateHints`) is made for the word before the cursor (`TypedWord`: its letters, nothing inside a link or while a
  slash command is being typed), and read again with the 0.25 s check (`WatchTyped`) because the line and cursor also change by
  other means. `Complete` replaces the word at the cursor, preserves the following text and teaches the word; `Delete` also
  acts at the cursor. `GetUTF8CursorPosition` counts characters, `SetCursorPosition` (like `GetText` and `string.sub`) uses byte offsets (the game's own code passes `strlen`); `TextAtCursor` splits the line and never throws. Phone-layout words add
  a trailing space only if no blank follows the cursor; when one does, the cursor steps over it. LB/RB cycle with
  `Cycle`, Y and the Space key take the chosen suggestion, a click `Choose`s it.
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
  resumed from an `OnUpdate` for 3 ms a frame, not in combat. An unfinished scan is discarded when the keyboard is disabled or
  the typing language changes; enabling it again starts a fresh scan. The result is a `Lexicon` of 1-2 MB (15,000 to 110,000 words in
  buckets by their first three keys, plus the best words per first key and first letter for the shortest input), kept for the
  language in use only. `Words:Lookup` and `Words:Prefix` merge it with the player's own words and the common ones by score: the
  source's weight (0-31), 8 for a common word, up to 30 for the player's own use and up to 12 for words seen (both grow
  with the logarithm of the count: 8 and 4 points per doubling), so a word the player used a few times comes before most
  words of a word list.
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
  bar artwork and end caps, including their native dimensions and positions. The page number and its arrows are not drawn
  (the classic bars have no page to switch); the action editor keeps its own page tracker.
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

Key ring: the bag bar shown with the classic bars has a `KeyRingButton` whose click is `ToggleBag(KEYRING_CONTAINER)`; the key
ring is not a generic held bag, so `ContainerFrameSettingsManager:IsUsingCombinedBags` is false for it and the single-bag path
runs, where `ContainerFrameMixin:GetRows` (gamepad interface) adds `self.shownSlots`, set only by
`ContainerFrameCombinedBagsMixin:SetBagSize`. `Layout:BlockKeyRing` dims the button and turns its clicks off while the classic
bars are up (restored in `Layout:Restore`); the game's own gamepad bag bar has a key ring button of its own.

Unit portraits on the targeting bars: the game fills `SpecialActionIcon` of a party member's, the player's, the pet's, the
assist target's or the focus's button with `SetPortraitTexture` (`TargetActionBars/FriendlyTargetingActionBar.lua`,
`Shared.lua`), which a texture copy (atlas or file) cannot carry over. `Display:UpdateSlot` recognises the button by its
secure attributes (`type` "target", `unit`) and asks for the same portrait on the slot's own icon, through a round mask
(`CircleMask`) like the game's; the mask is taken off again for any other action.

Setting `padKeyboard` ("Keyboard bars on the controller", off by default since 0.1.0-alpha.84 (it was on for new installations before; a saved value is kept; an installation from before the setting
existed is told apart in `Options:InitializeDefaults` by `hybridDefault` that every earlier version set): on gamepad page 1, the classic bars show and press
the keyboard action bars 1-3 (the slot's keyboard button, `Input.PadSlot`), not the game's own controller storage, whose
slots (`GamepadActionBarBindingUtil.GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID`) the keyboard bars do not use.
Switching gamepad pages (e.g. LB + RB + D-pad Left/Right) to pages 2-3 shows and presses the controller's own pages 2-3 (`Display:Update` checks `page == 1`; `Input.lua` `PRE_CLICK` checks `sources[1][1]:GetID() == padpage1id` in combat-safe secure code).
The eight pad buttons live on their own secure header (`ClassicConsoleGamepadUIPadInput`) with non-priority override bindings (`priority = false`, promoted once by `Input:VerifyPadPriority` if the client binding context outranks them) over the regular `GamepadModeInGameCore` bindings (`GAMEPADACTIONBUTTON1-8`), so priority overrides from Blizzard UI, Wheels, Keyboard, ItemDelete, and third-party gamepad addons automatically take precedence even in combat. Secure child watchers on `FriendlyTargetingActionBar` (`LB`), `HostileTargetingActionBar` (`RB`), and `ShortcutsActionBar` (`LB + RB`) clear `padHeader` synchronously whenever any of those native override bars is shown (leaving all 8 pad buttons on native `GAMEPADACTIONBUTTON1-8`, which lets addons such as QuestieForeverGamepad inspect/acquire `LB + RB + D-pad Up` without seeing a foreign `CLICK` override), restore `padHeader` immediately in combat on hide (and via a combat state driver), and out of combat defer restoration to `Input:SyncPadBindings`, which keeps `padHeader` cleared while `PadFree` is false or any foreign override holds a pad button (e.g. while QuestieForeverGamepad's tracker is open). `Input:PadBindingsLost` distinguishes dropped bindings (fallen back to base/`GAMEPADACTIONBUTTON*`) from active overrides and never steals pad buttons while a wheel is open or another override holds any pad button; `PadFree` also yields while `FrameControlsManager.isUIFocused` or `IsGamePadCursorControlEnabled()` is true. The
native action editor ("Bind to Action Bar", "Edit Action Bars") writes that controller storage, so it is kept in step with
the keyboard bars (`Display:EditorPairs`, `SnapshotEditor`, `SyncEditor`): when the editor opens, the storage slot of each pad
button of page 1 is made a copy of the keyboard slot at the same place (spells, items and macros are put on the cursor again
with `C_Spell.PickupSpell`, `C_Item.PickupItem` and `PickupMacro` and placed; a keyboard slot that is empty leaves the
controller slot as it was; a kind that cannot be copied, such as a flyout, a mount or an equipment set, empties the controller
slot so the editor does not show a stale action), and its state is remembered; when it closes, every controller slot that
changed is copied to its keyboard slot (the action that was there goes; a slot that was emptied empties the keyboard slot).
Page 1 only, outside combat, with an empty cursor (else it waits); while the editor is open the bars draw the editor's own
buttons, not the keyboard bars.

All addon state is stored in its private table or `ClassicConsoleGamepadUIDB`. Native page
callback lists, frame methods and keybindings are never replaced or extended directly.
Protected unit-frame and keyboard-bar geometry is changed outside combat and restored
without writing the game's saved Edit Mode layouts. Returning to keyboard/mouse mode must never
restore a snapshot of the old gamepad layout over the newly applied keyboard layout.

The single active-mode observer polls at 10 Hz, with event/post-hook refreshes coalesced
onto the next frame for trigger presses and native state changes. It stops in
keyboard/mouse mode and when the feature is disabled. This is not an FPS measurement.
