local name, Addon = ...
Addon.version = "0.1.0-alpha.2"

local driver = CreateFrame("Frame")
local ready, queued, lastMode
local elapsedSinceRefresh = 0
local function Poll(_, elapsed)
    elapsedSinceRefresh = elapsedSinceRefresh + elapsed
    if elapsedSinceRefresh >= 0.10 then elapsedSinceRefresh = 0; Addon:Refresh() end
end

function Addon:IsGamepadMode()
    return C_InputInterfaceStyle and Enum.InputDeviceInterfaceType
        and C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad or false
end

function Addon:Print(message)
    print("|cffffcf70ClassicGamepad:|r " .. message)
end

function Addon:Refresh()
    if not ready then return end
    local gamepad = self:IsGamepadMode()
    local changed = lastMode ~= nil and lastMode ~= gamepad
    lastMode = gamepad
    local wanted = gamepad and self.db.enabled and not self.nativeView and not self.conflict
    if changed then self.Layout:Restore(true) end
    self.HUD:Refresh(wanted and not self.Display:IsEditing(), changed)
    self.classicVisible = self.Display:Refresh(wanted)
    if not self.classicVisible then self.Layout:Restore(false) end
    if not gamepad then self.HUD:CaptureKeyboardLayout(); self.Layout:Capture() end
    -- Keep observing while flyouts/cursor/editor temporarily expose the native HUD.
    driver:SetScript("OnUpdate", wanted and Poll or nil)
end

function Addon:QueueRefresh(force)
    if not ready or queued or (not force and not self:IsGamepadMode()) then return end
    queued = true
    C_Timer.After(0, function() queued = false; self:Refresh() end)
end

local function Initialize()
    if ready then return end
    ClassicGamepadDB = type(ClassicGamepadDB) == "table" and ClassicGamepadDB or {}
    Addon.db = ClassicGamepadDB
    if type(Addon.db.enabled) ~= "boolean" then Addon.db.enabled = true end
    if type(Addon.db.keyboardHUD) ~= "table" then Addon.db.keyboardHUD = {} end
    if type(Addon.db.keyboardBars) ~= "table" then Addon.db.keyboardBars = {} end
    for _, other in ipairs({ "ControllerForever", "ConsolePort" }) do
        if C_AddOns.IsAddOnLoaded(other) then
            Addon.conflict = other
            Addon:Print(other .. " controls this HUD. Disable it to use ClassicGamepad.")
        end
    end
    ready = true
    Addon.HUD:Observe()
    Addon.Layout:Observe()
    local native = GamepadMainActionBarFrame
    if native then
        native:HookScript("OnShow", function() Addon:QueueRefresh() end)
        native:HookScript("OnHide", function() Addon:QueueRefresh() end)
        local unit = native.PageUnit
        for _, method in ipairs({ "SetActiveActionBar", "SetCurrentPage", "RefreshCompactLayout" }) do
            if unit and unit[method] then hooksecurefunc(unit, method, function() Addon:QueueRefresh() end) end
        end
    end
    for _, frame in ipairs({ GamepadActionBarEditFrame, EditModeManagerFrame }) do
        if frame then
            frame:HookScript("OnShow", function() Addon:QueueRefresh() end)
            frame:HookScript("OnHide", function() Addon:QueueRefresh() end)
        end
    end
    if InputDeviceIconSetManager and InputDeviceIconSetManager.UpdateActiveInputDeviceIconSet then
        hooksecurefunc(InputDeviceIconSetManager, "UpdateActiveInputDeviceIconSet", function() Addon:QueueRefresh() end)
    end
    Addon:QueueRefresh(true)
end

driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:RegisterEvent("UPDATE_BINDINGS")
driver:RegisterEvent("GAME_PAD_ACTIVE_CHANGED")
driver:RegisterEvent("CURSOR_CHANGED")
driver:RegisterEvent("DISPLAY_SIZE_CHANGED")
driver:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
driver:RegisterEvent("NEUTRAL_FACTION_SELECT_RESULT")
driver:SetScript("OnEvent", function(_, event)
    if event == "DISPLAY_SIZE_CHANGED" or event == "EDIT_MODE_LAYOUTS_UPDATED"
        or event == "NEUTRAL_FACTION_SELECT_RESULT" or event == "PLAYER_REGEN_ENABLED" then
        Addon.Layout.dirty = true
    end
    if event == "PLAYER_LOGIN" then Initialize() else Addon:QueueRefresh(true) end
end)

SLASH_CLASSICGAMEPAD1 = "/classicgamepad"
SLASH_CLASSICGAMEPAD2 = "/cgp"
SlashCmdList.CLASSICGAMEPAD = function(input)
    if not ready then return end
    local command = input:lower():match("^%s*(%S*)")
    if command == "on" or command == "off" then
        Addon.db.enabled = command == "on"
    elseif command == "native" or command == "classic" then
        Addon.nativeView = command == "native"
    elseif command == "scale" then
        Addon:Print("Use the game's UI scale and Edit Mode; ClassicGamepad follows the original frames.")
        return
    else
        local state = Addon.classicVisible and "classic HUD" or "native HUD"
        Addon:Print(Addon.version .. " | " .. state .. " | gamepad mode " .. (Addon:IsGamepadMode() and "on" or "off"))
        Addon:Print("/cgp on | off | native | classic")
        return
    end
    Addon:QueueRefresh(true)
end
