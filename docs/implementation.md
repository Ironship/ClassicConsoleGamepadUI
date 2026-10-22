# Native source contracts

Inspected on 2026-10-22 against Gethe/wow-ui-source branch `forever`, commit
`172a387e3ab85b26e6640d3058d5ec1e6ccd4c63`. These are exported Blizzard source files;
their presence does not establish live-client execution permission.

The local Forever executable was independently inspected as **1.60.1.70450**,
matching the exported source commit's build **1.60.1 (70450)**.

- `Blizzard_SharedXML/Mainline/InputUtil.lua`: Gamepad UI is determined by
  `C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad`.
  `C_GamePad.IsEnabled()` is not equivalent to enabling Gamepad Mode.
- `Blizzard_SharedXML/InputUtil.lua`: the native transition event is
  `INPUT_DEVICE_INTERFACE_TRANSITION`.
- `Blizzard_ActionBar/Mainline/ActionButtonTemplate.xml`: gamepad buttons inherit
  `SecureActionButtonTemplate`. Insecure per-trigger changes to their anchors would
  risk combat restrictions. ClassicGamepad does not change their anchors, size,
  parents, attributes, scripts, bindings or IDs.
- `Blizzard_GamepadActionBars/PageUnit.lua`: native no-trigger/LT/RT/LT+RT selection
  maps to top/left/right/bottom bars. Pet and stance bars may override these bars.
  Native special page 4 hides ordinary pageable bars.
- `Blizzard_GamepadActionBars/TargetActionBars/StaticOverrideActionBar.lua`:
  targeting/shortcut bars replace the top bar; their special icon and icon overlay
  matter independently of the normal action texture.
- `Blizzard_GamepadActionBars/ActionBarButton.lua`: gamepad presses can use
  `ApplyPressedStyle` independently of the generic button's pressed state.
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
  buttons follow the same native storage validation as standard actions.
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
- Native cooldown widget setters are observed with secure post-hooks; original
  arguments (including opaque values) are forwarded unchanged to the visible widget.
  No shared native callback table is modified.
- `Blizzard_EditMode/Mainline/EditModePresetLayouts.lua`: the classic unit-frame
  and bar anchors supply a fallback before a keyboard/mouse layout has been captured.
- `Blizzard_ActionBar/Mainline/ActionButtonTemplate.xml` and
  `Blizzard_ActionBar/Mainline/ActionButtonOverrides.lua`: stock button regions
  provide the slot artwork, normal/pushed/checked/highlight textures and icon mask.
  ClassicGamepad copies those live regions and their rectangles rather than selecting
  replacement assets. Display geometry is converted to UIParent coordinates without
  anchoring mirror frames to protected buttons.
- `Blizzard_ActionBar/Camelot/MainMenuBarEndCaps.xml` and
  `Blizzard_ActionBar/Mainline/MainActionBar.xml`: copy the actual end-cap textures,
  bar artwork, page font and arrows, including their native dimensions and positions.
- `Blizzard_EditMode/Camelot/EditModeUtil.lua` and
  `Blizzard_EditMode/Camelot/EditModePresetLayoutConstants.lua`: Gamepad Mode skips
  the keyboard bottom-bar stack. Outside combat, restore its native anchors using
  captured keyboard positions or the client's preset. The 36 original slot rectangles
  hold 32 controller actions, two class actions and two shoulder indicators.
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

All addon state is stored in its private table or `ClassicGamepadDB`. Native page
callback lists, frame methods and keybindings are never replaced or extended directly.
Protected unit-frame and keyboard-bar geometry is changed outside combat and restored
without writing the game's saved Edit Mode layouts. Returning to keyboard/mouse mode must never
restore a snapshot of the old gamepad layout over the newly applied keyboard layout.

The single active-mode observer polls at 10 Hz, with event/post-hook refreshes coalesced
onto the next frame for trigger presses and native state changes. It stops in
keyboard/mouse mode and when the feature is disabled. This is not an FPS measurement.
