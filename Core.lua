local name, Addon = ...
-- Identify the loaded Lua independently of the client's TOC metadata.
Addon.version = "0.1.0-alpha.38"
Addon.tocVersion = C_AddOns.GetAddOnMetadata(name, "Version")

local driver = CreateFrame("Frame")
local ready, queued, lastMode, lastSaved, capturedBlock
local elapsedSinceRefresh = 0
local firstTaintCaptured
local function Poll(_, elapsed)
    elapsedSinceRefresh = elapsedSinceRefresh + elapsed
    if elapsedSinceRefresh >= 0.10 then elapsedSinceRefresh = 0; Addon:Refresh() end
end

function Addon:IsGamepadMode()
    return C_InputInterfaceStyle and Enum.InputDeviceInterfaceType
        and C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad or false
end

function Addon:Print(message)
    print("|cffffcf70ClassicConsoleGamepadUI:|r " .. message)
end

function Addon:CheckNativeTaint(stage)
    if firstTaintCaptured or not self.diagnostics or not issecurevariable then return end
    local fields = {}
    local function Check(label, object, keys)
        if type(object) ~= "table" then return end
        for _, key in ipairs(keys) do
            local secure, owner = issecurevariable(object, key)
            if not secure and owner == name then fields[#fields + 1] = label .. "." .. key end
        end
    end
    Check("_G", _G, { "SELECTED_CHAT_FRAME", "ACTIVE_CHAT_EDIT_BOX", "LAST_ACTIVE_CHAT_EDIT_BOX" })
    Check("FrameControlsManager", GamepadMode and GamepadMode.FrameControlsManager,
        { "focusedFrame", "isUIFocused" })
    Check("SmartNavigation", SmartNavigation, { "activeInfo", "currentDirections", "selectButtonSequence" })
    local bindings = GamepadSharedUtility and GamepadSharedUtility.InputBindingManager
    Check("InputBindingManager", bindings, { "currentCoreBindingActive" })
    Check("InputBindingManager.activeBindings", bindings and bindings.activeBindings, { "PAD1", "PAD2", "PADDUP" })
    local unit = GamepadMainActionBarFrame and GamepadMainActionBarFrame.PageUnit
    Check("PageUnit", unit, { "activeBar" })
    if #fields == 0 then return end
    firstTaintCaptured = true
    self.diagnostics.firstTaint = { version = self.version, time = date("%Y-%m-%d %H:%M:%S"),
        stage = stage, fields = fields, stack = debugstack(2, 20, 0) }
end

function Addon:CaptureBlockedAction(event, addon, action)
    if capturedBlock or not self.diagnostics or addon ~= name
        or type(action) ~= "string" or not action:find("SetPreferredGamepadInteractTarget", 1, true) then return end
    capturedBlock = true
    local report = { version = self.version, time = date("%Y-%m-%d %H:%M:%S"), event = event,
        action = action, fields = {}, stack = debugstack(2, 24, 0) }
    report.clientVersion, report.clientBuild = GetBuildInfo()
    self.diagnostics.blockedAction = report
    local seen = {}
    local function Capture(label, object)
        if type(object) ~= "table" or seen[object] or not issecurevariable then return end
        seen[object] = true
        for key in pairs(object) do
            if type(key) == "string" or type(key) == "number" then
                local ok, secure, owner = pcall(issecurevariable, object, key)
                if ok and secure == false then
                    report.fields[#report.fields + 1] = label .. "." .. tostring(key) .. " = " .. tostring(owner)
                end
            end
        end
    end
    -- Read ownership only: never write to the focus or binding tables being inspected.
    local focus = GamepadMode and GamepadMode.FrameControlsManager
    Capture("FrameControlsManager", focus)
    if focus then
        Capture("FrameControlsManager.shownFrames", focus.shownFrames)
        Capture("FrameControlsManager.isPopupFrame", focus.isPopupFrame)
        Capture("FrameControlsManager.focusedFrame", focus.focusedFrame)
    end
    Capture("SmartNavigation", SmartNavigation)
    if SmartNavigation then
        Capture("SmartNavigation.activeInfo", SmartNavigation.activeInfo)
        Capture("SmartNavigation.activePanels", SmartNavigation.activePanels)
        Capture("SmartNavigation.currentButton", SmartNavigation.currentButton)
    end
    local bindings = GamepadSharedUtility and GamepadSharedUtility.InputBindingManager
    Capture("InputBindingManager", bindings)
    if bindings then
        Capture("InputBindingManager.bindingSetStack", bindings.bindingSetStack)
        Capture("InputBindingManager.coreBindingListenerFunctions", bindings.coreBindingListenerFunctions)
        Capture("InputBindingManager.activeBindings", bindings.activeBindings)
    end
    local native = GamepadMainActionBarFrame
    Capture("GamepadMainActionBarFrame", native)
    local unit = native and native.PageUnit
    Capture("PageUnit", unit)
    if unit and unit.actionBars then
        Capture("PageUnit.actionBars", unit.actionBars)
        for key, bar in pairs(unit.actionBars) do
            local label = "PageUnit.actionBars." .. tostring(key)
            Capture(label, bar)
            for index, button in ipairs(bar.actionButtons or {}) do
                Capture(label .. ".button" .. index, button)
            end
        end
    end
    Capture("GameTooltip", GameTooltip)
    table.sort(report.fields)
    C_Timer.After(0, function()
        if C_AddOns and C_AddOns.SaveAddOns then pcall(C_AddOns.SaveAddOns) end
    end)
end

function Addon:Note(stage, err)
    local diag = self.diagnostics
    if not diag then return end
    local message = err and tostring(err) or nil
    local changed = diag.stage ~= stage or diag.error ~= message
        or diag.classic ~= self.classicVisible or diag.gamepad ~= self:IsGamepadMode()
        or diag.input ~= (self.Input and self.Input.state)
        or diag.blockedBy ~= (self.Input and self.Input.blockedBy)
        or diag.displayReason ~= (self.Display and self.Display.reason)
    diag.stage, diag.error = stage, message
    diag.version = self.version
    diag.tocVersion = self.tocVersion
    diag.time = date("%Y-%m-%d %H:%M:%S")
    diag.gamepad = self:IsGamepadMode()
    diag.enabled = self.db and self.db.enabled
    diag.compact = self.db and self.db.compact
    diag.conflict = self.conflict
    diag.nativeView = self.nativeView
    diag.wanted = self.wanted
    diag.classic = self.classicVisible
    diag.input = self.Input and self.Input.state
    diag.inputError = self.Input and self.Input.lastError
    diag.blockedBy = self.Input and self.Input.blockedBy
    diag.displayReason = self.Display and self.Display.reason
    local native = GamepadMainActionBarFrame
    local shown = false
    if native then
        local ok, value = pcall(native.IsShown, native)
        shown = ok and value == true
    end
    diag.nativeShown = shown
    self.db.diagnostics = diag
    if not self.debugText then
        local frame = CreateFrame("Frame", nil, UIParent)
        frame:SetPoint("TOP", 0, -120)
        frame:SetSize(1000, 40)
        local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER")
        text:SetTextColor(1, 0.85, 0.2)
        self.debugText = text
    end
    -- Diagnostic overlay only on request (/cgp debug); never in normal play.
    if not self.db.debug or self.classicVisible or not self:IsGamepadMode() then
        self.debugText:Hide()
    else
        local reason = tostring(diag.displayReason or "?")
        local err = tostring(diag.error or "-")
        if #err > 120 then err = err:sub(1, 120) end
        self.debugText:SetText(self.version .. " | display=" .. reason .. " | input=" .. tostring(diag.input)
            .. " | blocked=" .. tostring(diag.blockedBy or "-") .. " | err=" .. err)
        self.debugText:Show()
    end
    local now = GetTime and GetTime() or 0
    if not changed or (lastSaved and now - lastSaved < 5) then return end
    lastSaved = now
    if C_AddOns and C_AddOns.SaveAddOns then pcall(C_AddOns.SaveAddOns) end
end

function Addon:Refresh()
    if not ready then return end
    self:CheckNativeTaint("before Refresh")
    local gamepad = self:IsGamepadMode()
    local changed = lastMode ~= nil and lastMode ~= gamepad
    lastMode = gamepad
    local wanted = gamepad and self.db.enabled and not self.nativeView and not self.conflict
    self.wanted = wanted
    -- Apply user view changes with the protected click layer after combat ends.
    if gamepad and not changed and InCombatLockdown() and self.Input:IsEnabled() then wanted = true end
    if changed then
        self.Layout:Restore(true)
        if not gamepad then self:QueueRefresh(true) end
    end
    self.HUD:Refresh(wanted and not self.Display:IsEditing(), changed)
    self:CheckNativeTaint("HUD:Refresh")
    local ok, visible = pcall(self.Display.Refresh, self.Display, wanted)
    self:CheckNativeTaint("Display:Refresh")
    if not ok then
        self.classicVisible = false
        self:Note("Display:Refresh", visible)
    else
        self.classicVisible = visible
    end
    if not self.classicVisible then self.Layout:Restore(false) end
    self.HUD:RefreshChat(self.classicVisible, changed)
    self:CheckNativeTaint("HUD:RefreshChat")
    self.ItemDelete:Refresh()
    self:CheckNativeTaint("ItemDelete:Refresh")
    if not gamepad and not changed then self.HUD:CaptureKeyboardLayout(); self.Layout:Capture() end
    self:Note("refresh", not ok and visible or nil)
    -- Keep observing while flyouts/cursor/editor temporarily expose the native HUD.
    local watchDelete = gamepad and self.db.easyDelete and self.ItemDelete.dialog
    driver:SetScript("OnUpdate", (wanted or watchDelete) and Poll or nil)
end

function Addon:QueueRefresh(force)
    if not ready or queued or (not force and not self:IsGamepadMode()) then return end
    queued = true
    C_Timer.After(0, function() queued = false; self:Refresh() end)
end

local function Initialize()
    if ready then return end
    ClassicConsoleGamepadUIDB = type(ClassicConsoleGamepadUIDB) == "table" and ClassicConsoleGamepadUIDB or {}
    Addon.db = ClassicConsoleGamepadUIDB
    Addon.Options:InitializeDefaults()
    if type(Addon.db.keyboardHUD) ~= "table" then Addon.db.keyboardHUD = {} end
    if type(Addon.db.keyboardBars) ~= "table" then Addon.db.keyboardBars = {} end
    -- Older caches can contain hidden-bar placeholders or gamepad transition anchors.
    if Addon.db.keyboardLayoutVersion ~= 1 then
        Addon.db.keyboardHUD, Addon.db.keyboardBars = {}, {}
        Addon.db.keyboardLayoutVersion = 1
    end
    if type(Addon.db.diagnostics) ~= "table" then Addon.db.diagnostics = {} end
    Addon.diagnostics = Addon.db.diagnostics
    -- Snapshots from older builds describe code that is no longer loaded.
    if Addon.diagnostics.version ~= Addon.version then
        Addon.diagnostics.firstTaint, Addon.diagnostics.blockedAction = nil, nil
    end
    for _, other in ipairs({ "ControllerForever", "ConsolePort", "ClassicGamepad" }) do
        if C_AddOns.IsAddOnLoaded(other) then
            Addon.conflict = other
            Addon:Print(other .. " controls this HUD. Disable it to use ClassicConsoleGamepadUI.")
        end
    end
    ready = true
    Addon:CheckNativeTaint("before Initialize")
    local ok, err = pcall(function()
        if SmartNavigation and type(SmartNavigation.SelectButton) == "function" then
            hooksecurefunc(SmartNavigation, "SelectButton", function()
                Addon:CheckNativeTaint("SmartNavigation:SelectButton")
            end)
        end
        Addon.HUD:Observe()
        Addon.Layout:Observe()
        Addon.MenuHints:Observe()
        Addon.Options:Register()
        Addon:CheckNativeTaint("Options:Register")
        Addon.ItemDelete:Observe()
        local native = GamepadMainActionBarFrame
        if native then
            hooksecurefunc(native, "OnShow", function() Addon:QueueRefresh() end)
            hooksecurefunc(native, "OnHide", function() Addon:QueueRefresh() end)
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
        -- Settings visibility is already observed by the gamepad refresh timer.
        if InputDeviceIconSetManager and InputDeviceIconSetManager.UpdateActiveInputDeviceIconSet then
            hooksecurefunc(InputDeviceIconSetManager, "UpdateActiveInputDeviceIconSet", function()
                Addon:QueueRefresh()
                Addon.MenuHints:Refresh()
            end)
        end
    end)
    if not ok then Addon:Note("Initialize", err) end
    Addon:CheckNativeTaint("Initialize")
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
driver:RegisterEvent("ADDON_ACTION_FORBIDDEN")
driver:RegisterEvent("ADDON_ACTION_BLOCKED")
driver:SetScript("OnEvent", function(_, event, addon, action)
    if event == "ADDON_ACTION_FORBIDDEN" or event == "ADDON_ACTION_BLOCKED" then
        Addon:CaptureBlockedAction(event, addon, action)
        return
    end
    if event == "UPDATE_BINDINGS" then Addon.Input.dirty = true end
    if event == "DISPLAY_SIZE_CHANGED" or event == "EDIT_MODE_LAYOUTS_UPDATED"
        or event == "NEUTRAL_FACTION_SELECT_RESULT" or event == "PLAYER_REGEN_ENABLED" then
        Addon.Layout.dirty = true
    end
    if event == "PLAYER_LOGIN" then Initialize() else Addon:QueueRefresh(true) end
    if ready and (event == "UPDATE_BINDINGS" or event == "GAME_PAD_ACTIVE_CHANGED"
        or event == "INPUT_DEVICE_INTERFACE_TRANSITION") then Addon.MenuHints:Refresh() end
end)

SLASH_CLASSICCONSOLEGAMEPADUI1 = "/classicconsolegamepadui"
SLASH_CLASSICCONSOLEGAMEPADUI2 = "/cgp"
SlashCmdList.CLASSICCONSOLEGAMEPADUI = function(input)
    if not ready then return end
    local command = input:lower():match("^%s*(%S*)")
    if command == "" or command == "settings" or command == "options" then
        Addon.Options:Open()
        return
    elseif command == "bindings" then
        Addon.Options:OpenBindings()
        return
    elseif command == "edit" then
        Addon.Options:EditActions()
        return
    elseif command == "on" or command == "off" then
        Addon.db.enabled = command == "on"
    elseif command == "native" or command == "classic" then
        Addon.nativeView = command == "native"
    elseif command == "shift" then
        local value = tonumber(input:match("(%d+)"))
        Addon.db.upperShift = math.max(0, math.min(8, value or 4))
        Addon.Layout.dirty = true
        Addon:QueueRefresh(true)
        Addon:Print("Upper row shift: " .. Addon.db.upperShift .. " slots")
        return
    elseif command == "scale" then
        Addon:Print("Use the game's UI scale and Edit Mode; ClassicConsoleGamepadUI follows the original frames.")
        return
    elseif command == "deck" then
        Addon.Options:ApplyDeckPreset()
        return
    elseif command == "debug" then
        Addon.db.debug = not Addon.db.debug or nil
        Addon:Print("Debug overlay " .. (Addon.db.debug and "on" or "off"))
        Addon:Note("debug")
        return
    elseif command == "status" then
        local native = GamepadMainActionBarFrame
        local nativeShown = false
        if native then
            local nativeOk, value = pcall(native.IsShown, native)
            nativeShown = nativeOk and value == true
        end
        Addon:Print(Addon.version .. " | gamepad " .. (Addon:IsGamepadMode() and "on" or "off")
            .. " | classic " .. (Addon.classicVisible and "on" or "off"))
        Addon:Print("enabled=" .. tostring(Addon.db.enabled) .. " compact=" .. tostring(Addon.db.compact)
            .. " conflict=" .. tostring(Addon.conflict or "none") .. " nativeView=" .. tostring(Addon.nativeView)
            .. " nativeShown=" .. tostring(nativeShown)
            .. " input=" .. tostring(Addon.Input and Addon.Input.state)
            .. " display=" .. tostring(Addon.Display and Addon.Display.reason))
        local diag = Addon.diagnostics
        Addon:Print("last=" .. tostring(diag and diag.stage) .. " error=" .. tostring(diag and diag.error)
            .. " input=" .. tostring(diag and diag.input) .. " blockedBy=" .. tostring(diag and diag.blockedBy)
            .. " inputError=" .. tostring(diag and diag.inputError) .. " at " .. tostring(diag and diag.time))
        local blocked = diag and diag.blockedAction
        if blocked then
            Addon:Print("Blocked action snapshot: " .. blocked.version .. " at " .. blocked.time
                .. " | " .. #blocked.fields .. " tainted fields recorded (ownership alone does not prove the cause).")
        end
        local first = diag and diag.firstTaint
        if first then Addon:Print("First observed native taint: " .. first.stage .. " at " .. first.time) end
        Addon:Note("status")
        return
    else
        local state = Addon.classicVisible and "classic HUD" or "native HUD"
        Addon:Print(Addon.version .. " | " .. state .. " | gamepad mode " .. (Addon:IsGamepadMode() and "on" or "off"))
        Addon:Print("/cgp settings | bindings | edit | on | off | native | classic | status | deck | debug")
        return
    end
    Addon:QueueRefresh(true)
    Addon.MenuHints:Refresh()
end
