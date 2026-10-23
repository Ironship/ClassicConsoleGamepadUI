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
- The upper row stays fixed: L2 uses slots 13-20 and R2 uses slots 25-32.
  Compact mode hides 21-24 and 33-36, moves the right section left by four stock
  button pitches and shortens the main border by the same amount. After the
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
Restore the exact alpha/input state for native view, bindings and flyouts. The visual
mirror is intentionally not an extra set of spell-casting buttons.

All addon state is stored in its private table or `ClassicConsoleGamepadUIDB`. Native page
callback lists, frame methods and keybindings are never replaced or extended directly.
Protected unit-frame and keyboard-bar geometry is changed outside combat and restored
without writing the game's saved Edit Mode layouts. Returning to keyboard/mouse mode must never
restore a snapshot of the old gamepad layout over the newly applied keyboard layout.

The single active-mode observer polls at 10 Hz, with event/post-hook refreshes coalesced
onto the next frame for trigger presses and native state changes. It stops in
keyboard/mouse mode and when the feature is disabled. This is not an FPS measurement.
