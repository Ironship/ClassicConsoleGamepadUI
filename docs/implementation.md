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
- `Blizzard_SharedXML/Shared/InputIcons/InputIconTexture.lua`: controller glyphs
  live in the native prompt's Normal/Pressed/Active/Hover/Disabled textures.
- `Blizzard_APIDocumentationGenerated/ActionBarFrameDocumentation.lua`:
  `C_ActionBar.GetActionCooldownDuration` returns a duration object. Forward it to
  the display's own cooldown widget without inspecting or computing its contents.
- Native cooldown widget setters are observed with secure post-hooks; original
  arguments (including opaque values) are forwarded unchanged to the visible widget.
  No shared native callback table is modified.
- `Blizzard_EditMode/Mainline/EditModePresetLayouts.lua`: the classic unit-frame
  anchors supply a fallback before a keyboard/mouse layout has been captured.

Native action HUD changes: temporarily set its root alpha to zero and disable
invisible mouse hitboxes outside combat, recording click/motion flags separately.
Restore the exact alpha/input state for native view, bindings and flyouts. The visual
mirror is intentionally not an extra set of spell-casting buttons.

All addon state is stored in its private table or `ClassicGamepadDB`. Native page
callback lists, frame methods and keybindings are never replaced or extended directly.
Protected unit-frame geometry is changed outside combat and restored without writing
the game's saved Edit Mode layouts. Returning to keyboard/mouse mode must never
restore a snapshot of the old gamepad layout over the newly applied keyboard layout.

The single active-mode observer polls at 10 Hz, with event/post-hook refreshes coalesced
onto the next frame for trigger presses and native state changes. It stops in
keyboard/mouse mode and when the feature is disabled. This is not an FPS measurement.
