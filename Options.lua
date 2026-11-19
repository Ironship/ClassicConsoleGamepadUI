local _, Addon = ...
local Options = {}
Addon.Options = Options

-- Every text of the interface comes from the language files in Locales/ (Addon.L, the language chosen in the settings).
local text = Addon.L

local controls = {
    { key = "enabled", default = true, section = "layout" },
    { key = "compact", default = true },
    { key = "groupBoth", default = false },
    { key = "crossFirst", default = false },
    { key = "padKeyboard", default = false },
    { key = "attackStart", default = false },
    -- Wheels on R3 (Wheels.lua): R3 + X, Y, B or A opens a wheel of eight slots. Size and place are in interface points from
    -- the middle of the screen.
    { key = "wheels", default = false, section = "wheels" },
    { key = "wheelScale", default = 1, min = 0.5, max = 1.5, step = 0.05, parent = "wheels" },
    { key = "wheelSlotScale", default = 1, min = 0.6, max = 1.6, step = 0.05, parent = "wheels" },
    { key = "wheelX", default = 0, min = -900, max = 900, step = 2, parent = "wheels", tip = "wheelPositionTip" },
    { key = "wheelY", default = 0, min = -600, max = 600, step = 2, parent = "wheels", tip = "wheelPositionTip" },
    { key = "wheelAlpha", default = 1, min = 0.3, max = 1, step = 0.05, parent = "wheels" },
    { key = "wheelNames", default = true, parent = "wheels" },
    { key = "wheelHints", default = true, parent = "wheels" },
    { key = "wheelNumbers", default = true, parent = "wheels" },
    -- Dynamic wheels (Dynamic.lua): wheels that fill themselves. Which wheel each kind goes to: 0 none, 1 to 5 the wheel.
    { key = "wheelDynamic", default = false, parent = "wheels" },
    { key = "wheelDynFood", default = 3, parent = "wheelDynamic", choice = true },
    { key = "wheelDynUse", default = 4, parent = "wheelDynamic", choice = true },
    { key = "wheelDynProf", default = 5, parent = "wheelDynamic", choice = true },
    { key = "wheelKeep", default = 800, min = 200, max = 3000, step = 100, parent = "wheels" },
    { key = "wheelsDock", default = true, parent = "wheels" },
    { key = "wheelsDockAlways", default = false, parent = "wheelsDock" },
    { key = "wheelsDockFocus", default = true, parent = "wheelsDock" },
    { key = "wheelCombos", default = false, parent = "wheels" },
    { key = "wheelToggle", default = false, parent = "wheels" },
    { key = "wheelWedges", default = true, parent = "wheels" },
    { key = "wheelCameraOnly", default = true, parent = "wheels" },
    { key = "wheelBlock", default = "hard", parent = "wheels", choice = true },
    { key = "moveUnitFrames", default = false },
    -- The stock frames the classic layout places (Layout.lua PLACED, PlaceTotemBar). Off: Edit Mode places them.
    { key = "placeBags", default = true },
    { key = "placeStatusBars", default = true },
    { key = "placeTotemBar", default = true },
    { key = "contextGap", default = 12, min = 0, max = 100, step = 2 },
    -- The gryphons at the ends of the classic bars, like the end caps of the game's own action bar.
    { key = "showLeftCap", default = true },
    { key = "showRightCap", default = true },
    -- Where the classic bars were dragged in Edit Mode (EditMode.lua): an offset from their computed place, in UIParent
    -- points. Not on the settings window; Edit Mode and /cgp resetbars change it.
    -- The size of the classic bars (Display:ApplyScale), also on their Edit Mode panel.
    { key = "barScale", default = 1, min = 0.5, max = 1.5, step = 0.05 },
    { key = "barX", default = 0, min = -4000, max = 4000, step = 1 },
    { key = "barY", default = 0, min = -4000, max = 4000, step = 1 },
    { key = "hideMenu", default = false, section = "menu", tip = "hideMenuTip" },
    { key = "placeMenu", default = true },
    { key = "menuRight", default = 0, min = 0, max = 128, step = 1, parent = "placeMenu", tip = "menuTip" },
    { key = "menuBottom", default = 0, min = 0, max = 240, step = 1, parent = "placeMenu", tip = "menuTip" },
    { key = "promptScale", default = 1.05, min = 0.6, max = 1.6, step = 0.05, section = "hints" },
    { key = "modifierScale", default = 1.75, min = 0.6, max = 2.5, step = 0.05 },
    { key = "showKeyboardHints", default = true },
    { key = "showMenuHints", default = true },
    { key = "highlightActive", default = true },
    { key = "moveLegend", default = false, section = "legend" },
    { key = "legendX", default = 90, min = 0, max = 600, step = 2, parent = "moveLegend", tip = "legendPositionTip" },
    -- "Grow upwards" on the legend's Edit Mode panel (EditMode.lua), not on the settings window.
    { key = "legendGrowUp", default = false },
    -- The legend's gold frame and how dark its shade is (1 = the game's own look).
    { key = "legendFrame", default = true },
    { key = "legendShade", default = 1, min = 0, max = 1, step = 0.05 },
    { key = "legendGap", default = 74, min = 0, max = 240, step = 2, parent = "moveLegend", tip = "legendPositionTip" },
    { key = "anchorChat", default = false, section = "chat" },
    { key = "chatLeft", default = 0, min = 0, max = 1200, step = 1, parent = "anchorChat", tip = "chatPositionTip" },
    { key = "chatBottom", default = 0, min = 0, max = 800, step = 1, parent = "anchorChat", tip = "chatPositionTip" },
    { key = "raiseChat", default = true },
    { key = "chatGap", default = 12, min = 0, max = 100, step = 2, parent = "raiseChat" },
    { key = "keyboardEnabled", default = true },
    { key = "autoKeyboard", default = true, parent = "keyboardEnabled" },
    { key = "keyboardTransparency", default = 0, min = 0, max = 0.9, step = 0.05, parent = "keyboardEnabled" },
    { key = "wordHunter", default = true, parent = "keyboardEnabled" },
    { key = "easyDelete", default = true, section = "items" },
}

-- Settings that hand a stock frame to Edit Mode or take it back: every frame returns to its own place first.
local releaseSettings = { hideMenu = true, placeMenu = true, placeBags = true, placeStatusBars = true, placeTotemBar = true }

local geometrySettings = { compact = true, groupBoth = true, crossFirst = true, contextGap = true, barX = true, barY = true,
    barScale = true, hideMenu = true, menuRight = true, menuBottom = true, promptScale = true, modifierScale = true }

-- The rows that pick one of a list: { value, label } (a language names itself) or { value, nil, text key }.
local function LanguageChoices()
    local list = {}
    for _, code in ipairs(Addon.Locales.order) do list[#list + 1] = { code, Addon.Locales.names[code] } end
    list[#list + 1] = { "auto", nil, "languageAuto" }
    return list
end

local function KeyboardLanguageChoices()
    local list = {}
    for _, code in ipairs(Addon.Languages.order) do
        local language = Addon.Languages[code]
        list[#list + 1] = { code, language.name .. " (" .. language.layout .. ")" }
    end
    return list
end

-- Shared with the settings window (SettingsWindow.lua).
Options.text, Options.controls = text, controls
Options.choices = {
    language = LanguageChoices(),
    keyboardLanguage = KeyboardLanguageChoices(),
    keyboardMode = { { "abc", nil, "layoutFull" }, { "t9", nil, "layoutTap" }, { "t9p", nil, "layoutSmart" },
        { "t9h", nil, "layoutHybrid" } },
    wheelBlock = { { "off", nil, "blockOff" }, { "listener", nil, "blockListener" }, { "hard", nil, "blockHard" },
        { "both", nil, "blockBoth" } },
    wheelDynFood = { { 0, nil, "dynOff" }, { 1, nil, "dynWheel1" }, { 2, nil, "dynWheel2" }, { 3, nil, "dynWheel3" },
        { 4, nil, "dynWheel4" }, { 5, nil, "dynWheel5" } },
}
-- The three kinds of dynamic wheel offer the same wheels.
Options.choices.wheelDynUse = Options.choices.wheelDynFood
Options.choices.wheelDynProf = Options.choices.wheelDynFood

-- A setting was changed in the settings window (its value is already in the database).
function Options:Changed(key)
    Addon:Trace("setting " .. key)
    Addon:CheckNativeTaint("setting changed: " .. key)
    if key == "language" then
        Addon.Locales.Use(Addon.db.language)
        Addon.Fonts:Update()
        Addon.SettingsWindow:Relocalize()
        Addon.Keyboard:Relocalize()
    elseif key == "keyboardLanguage" then
        Addon.Keyboard:SetLanguage(Addon.db[key])
    elseif key == "keyboardMode" then
        Addon.Keyboard:SetMode(Addon.db[key])
    elseif key == "keyboardEnabled" then
        Addon.Keyboard:SetEnabled(Addon.db[key])
        Addon.WordSources:Changed()
    elseif key == "keyboardTransparency" then
        Addon.Keyboard:ApplyTransparency()
    elseif key == "wordHunter" then
        Addon.WordSources:Changed()
    elseif key == "wheels" or key:sub(1, 5) == "wheel" then
        Addon.Wheels:Changed(key)
        Addon:QueueRefresh(true)
    elseif key == "legendGrowUp" then
        Addon.HUD:SetLegendGrowUp()
    elseif key == "legendFrame" or key == "legendShade" then
        Addon.HUD:ApplyLegendStyle()
    elseif key == "showLeftCap" or key == "showRightCap" then
        -- Shown or hidden at once, in combat too.
        Addon.Display:ApplyCaps()
        Addon.Layout.dirty = true
        Addon:QueueRefresh(true)
    else
        if geometrySettings[key] then Addon.Layout.dirty = true end
        if releaseSettings[key] then Addon.Layout.releasePending, Addon.Layout.dirty = true, true end
        -- The pad's keys join or leave the click layer's bindings.
        if key == "padKeyboard" then Addon.Input.dirty = true end
        Addon:QueueRefresh(true)
    end
end

local KEYBOARD_MODES = { "abc", "t9", "t9p", "t9h" }
local KEYBOARD_INPUTS = { "t9", "t9p", "t9h" }

local function Contains(list, value)
    for _, item in ipairs(list) do
        if item == value then return true end
    end
end

function Options:InitializeDefaults()
    local db = Addon.db
    -- Every earlier version set hybridDefault, so a saved variables file without "padKeyboard" that has it is an installation
    -- from before that setting: it stays off there (the controller's own bar layout stays what it was) until the player
    -- turns it on. Off is the default for a new installation too; a value that was saved is kept.
    local existing = db.hybridDefault ~= nil
    db.keyboardLanguage = Addon.Languages.Valid(db.keyboardLanguage)
    -- English, unless the player chose another language (or the game's).
    if db.language ~= "auto" and not Addon.Locales.tables[db.language] then db.language = "enUS" end
    -- Hybrid is the default T9 mode; whatever was saved while it did not exist yet is replaced once.
    if not db.hybridDefault then
        db.hybridDefault = true
        db.keyboardPhone = "t9h"
        if db.keyboardMode ~= "abc" then db.keyboardMode = "t9h" end
    end
    if not Contains(KEYBOARD_INPUTS, db.keyboardPhone) then db.keyboardPhone = "t9h" end
    if not Contains(KEYBOARD_MODES, db.keyboardMode) then db.keyboardMode = db.keyboardPhone end
    if existing and db.padKeyboard == nil then db.padKeyboard = false end
    -- Two settings overrode the game's own Edit Mode places (chat at the screen corner, the unit frames at their classic
    -- places), so players could not move those frames. They are off by default now; an installation from before that has
    -- the old default saved, so it is switched off once. Turned on again later, they stay on.
    if (db.defaultsRev or 0) < 1 then
        if existing then db.anchorChat, db.moveUnitFrames = false, false end
        db.defaultsRev = 1
    end
    for _, info in ipairs(controls) do
        local value = db[info.key]
        if type(value) ~= type(info.default) or (info.min and (value ~= value or value < info.min or value > info.max)) then
            db[info.key] = info.default
        end
    end
    Addon.Locales.Use(db.language)
    Addon.Fonts:Update()
end

local function OutsideCombat()
    if not InCombatLockdown() then return true end
    Addon:Print(text.combat)
    return false
end

-- "Reset all settings" (Tools tab): every setting back to its default, and the places this addon keeps (the bars and the
-- legend dragged in Edit Mode, the unit frames, the keyboard). The interface language, the learned words and the cached
-- keyboard/mouse layout stay. Out of combat, since it moves frames.
function Options:ResetAll()
    if not OutsideCombat() then return false end
    local db = Addon.db
    for _, info in ipairs(controls) do db[info.key] = info.default end
    db.legendSpot, db.keyboardPos = nil, nil
    db.keyboardLanguage, db.keyboardMode, db.keyboardPhone, db.hybridDefault = nil, nil, nil, nil
    self:InitializeDefaults()
    Addon:Trace("Options:ResetAll")
    -- Every stock frame back to its own place, then laid out again from the defaults.
    Addon.Layout.releasePending, Addon.Layout.dirty = true, true
    Addon.HUD:ResetFrames()
    Addon.HUD.legendTop, Addon.HUD.legendX = nil, nil
    Addon.Display:ApplyCaps()
    Addon.HUD:ApplyLegendStyle()
    local keyboard = Addon.Keyboard
    keyboard:SetLanguage(db.keyboardLanguage)
    keyboard:SetMode(db.keyboardMode)
    keyboard:ApplyTransparency()
    if keyboard.frame then
        keyboard.frame:ClearAllPoints()
        keyboard.frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 120)
    end
    Addon.WordSources:Changed()
    Addon.MenuHints:Refresh()
    Addon:QueueRefresh(true)
    Addon:Print(text.settingsReset)
    return true
end

-- Opening, switching or closing Blizzard panels from addon code runs the
-- gamepad focus, SmartNavigation and binding-stack setup in tainted
-- execution. Those tainted tables later block SetPreferredGamepadInteractTarget
-- whenever any panel closes, so in Gamepad Mode only the player opens them.
local function CanDrivePanels()
    return not Addon:IsGamepadMode()
end

function Options:OpenBindings()
    if not OutsideCombat() then return end
    if not CanDrivePanels() then
        Addon:Print(SettingsPanel:IsShown() and text.keybindingsRoute:format(SETTINGS_KEYBINDINGS_LABEL) or text.panelRoute)
        return
    end
    Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID)
end

function Options:OpenGamepad()
    if not OutsideCombat() then return end
    if not CanDrivePanels() then
        Addon:Print(SettingsPanel:IsShown() and text.gamepadRoute:format(GAMEPAD_LABEL) or text.panelRoute)
        return
    end
    for _, category in ipairs(SettingsPanel:GetAllCategories()) do
        if category:GetName() == GAMEPAD_LABEL then
            Settings.OpenToCategory(category:GetID())
            return
        end
    end
end

-- The native editor opens through Blizzard's own click button. Calling
-- EnterEditMode directly restyles the native bars in tainted execution.
function Options:EditActions()
    if not OutsideCombat() then return end
    if not Addon:IsGamepadMode() then Addon:Print(text.gamepad); return end
    if GamepadActionBarEditFrame:IsShown() then return end
    local command = "CLICK GamepadActionBarEditFrameEnterEditMode:LeftButton"
    local keys = {}
    for _, key in ipairs({ GetBindingKey(command) }) do
        keys[#keys + 1] = IsBindingForGamePad(key) and Addon.MenuHints:KeyText(key) or GetBindingText(key, 1)
    end
    if #keys > 0 then
        Addon:Print(text.editRouteKey:format(table.concat(keys, " / ")))
    else
        Addon:Print(text.editRouteCommand)
    end
end

local function BindingContext(action)
    if C_KeyBindings and C_KeyBindings.GetBindingContextForAction then
        return C_KeyBindings.GetBindingContextForAction(action)
    end
end

local function CurrentKeys(action, context)
    if not GetBindingKey then return end
    return GetBindingKey(action, nil, context)
end

function Options:EnsureBindCatcher()
    if self.catcher then return end
    local catcher = CreateFrame("Frame", "ClassicConsoleGamepadUIBindCatcher", UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:EnableKeyboard(true)
    catcher:EnableMouse(false)
    catcher:SetScript("OnKeyDown", function(frame, key)
        local handled = self:HandleBindInput(key)
        if frame.SetPropagateKeyboardInput then frame:SetPropagateKeyboardInput(not handled) end
    end)
    catcher:SetScript("OnGamePadButtonDown", function(_, key)
        self:HandleBindInput(key)
    end)
    catcher:SetScript("OnEvent", function() self:StopBarBind() end)
    catcher:RegisterEvent("PLAYER_REGEN_DISABLED")
    if catcher.EnableGamePadButton then pcall(catcher.EnableGamePadButton, catcher, true) end
    local notice = CreateFrame("Frame", nil, catcher)
    notice:SetSize(720, 64)
    notice:EnableMouse(false)
    notice:SetPoint("TOP", UIParent, "TOP", 0, -80)
    notice.text = Addon.Fonts:String(notice, "OVERLAY", "HighlightLarge")
    notice.text:SetPoint("TOP")
    notice.text:SetWidth(700)
    notice.text:SetJustifyH("CENTER")
    self.catcher, self.notice = catcher, notice
    self.watchedButtons = {}
    catcher:Hide()
end

function Options:WatchBindButton(button, resolve)
    if not button or self.watchedButtons[button] then return end
    local ok = pcall(function()
        button:HookScript("OnEnter", function()
            if not self.binding then return end
            local action, slot = resolve(button)
            if action then self:SetBindTarget(button, action, slot) end
        end)
        button:HookScript("OnLeave", function()
            if self.binding and self.binding.button == button then self:SetBindTarget(nil, nil, nil) end
        end)
    end)
    if ok then self.watchedButtons[button] = true end
end

function Options:WatchBindTargets()
    self:EnsureBindCatcher()
    if Addon.Input and Addon.Input.buttons then
        for index, button in pairs(Addon.Input.buttons) do
            self:WatchBindButton(button, function()
                local slot = Addon.Display.slots[index]
                local action = slot and slot.bindingAction
                return action, slot
            end)
        end
    end
    for _, bar in ipairs({ StanceBar, PetActionBar }) do
        if bar and bar.actionButtons then
            for _, button in ipairs(bar.actionButtons) do
                self:WatchBindButton(button, function(target)
                    return target.commandName, nil
                end)
            end
        end
    end
end

function Options:SetBindTarget(button, action, slot)
    local binding = self.binding
    if not binding then return end
    if binding.slot then binding.slot.bindingHighlight = nil end
    if binding.native and binding.native.DisableDrawLayer then
        pcall(binding.native.DisableDrawLayer, binding.native, "HIGHLIGHT")
    end
    binding.button, binding.action, binding.slot = button, action, slot
    binding.native = slot and nil or button
    if slot then slot.bindingHighlight = true end
    if binding.native and binding.native.EnableDrawLayer then
        pcall(binding.native.EnableDrawLayer, binding.native, "HIGHLIGHT")
    end
    self:UpdateBindNotice()
end

function Options:UpdateBindNotice(result)
    if not self.notice then return end
    local binding = self.binding
    local line = text.bindActive
    if result then
        line = result
    elseif binding and binding.action then
        local name = GetBindingName and GetBindingName(binding.action) or binding.action
        local context = BindingContext(binding.action)
        local key = CurrentKeys(binding.action, context)
        local keyText = key and GetBindingText and GetBindingText(key, 1) or ""
        line = text.bindActive .. "\n" .. name .. (keyText ~= "" and ("  " .. keyText) or "")
    else
        line = text.bindActive .. "\n" .. text.bindNeed
    end
    self.notice.text:SetText(line)
end

function Options:WriteBinding(action, key, clear)
    local context = BindingContext(action)
    if not context or not SetBinding then return false end
    local key1, key2 = CurrentKeys(action, context)
    if clear then
        if key1 then SetBinding(key1, nil, context) end
        if key2 then SetBinding(key2, action, context) end
    else
        if key1 then SetBinding(key1, nil, context) end
        if key2 and key2 ~= key then SetBinding(key2, nil, context) end
        SetBinding(key, nil, context)
        if not SetBinding(key, action, context) then
            if key1 then SetBinding(key1, action, context) end
            if key2 then SetBinding(key2, action, context) end
            return false
        end
        if key2 and key2 ~= key then SetBinding(key2, action, context) end
    end
    SaveBindings(GetCurrentBindingSet())
    Addon.Input.dirty = true
    local slot = self.binding and self.binding.slot
    if slot and slot.Key then
        local shown = clear and key2 or nil
        if not clear then shown = key end
        slot.Key:SetText(shown and GetBindingText(shown, 1) or "")
    end
    local native = self.binding and self.binding.native
    if native and native.UpdateHotkeys and native.commandName then
        local prefix = native.commandName:match("^(.-)%d+$")
        if prefix then pcall(native.UpdateHotkeys, native, prefix) end
    end
    return true
end

function Options:HandleBindInput(key)
    if not self.binding then return false end
    if InCombatLockdown() then self:StopBarBind(); return true end
    if key == "ESCAPE" then self:StopBarBind(); return true end
    local action = self.binding.action
    if not action then
        self:UpdateBindNotice(text.bindNeed)
        return true
    end
    if key == "BACKSPACE" or key == "DELETE" then
        local ok, assigned = pcall(self.WriteBinding, self, action, nil, true)
        self:UpdateBindNotice((ok and assigned) and text.bindCleared or text.bindFail)
        return true
    end
    if type(IsKeyPressIgnoredForBinding) == "function" and IsKeyPressIgnoredForBinding(key) then
        return true
    end
    local chord = key
    if type(GetConvertedKeyOrButton) == "function" then chord = GetConvertedKeyOrButton(key) or key end
    if type(CreateKeyChordStringUsingMetaKeyState) == "function" then
        chord = CreateKeyChordStringUsingMetaKeyState(chord) or chord
    end
    local ok, assigned = pcall(self.WriteBinding, self, action, chord, false)
    self:UpdateBindNotice((ok and assigned) and text.bindOk or text.bindFail)
    return true
end

function Options:StartBarBind()
    if self.binding then return end
    Addon:Trace("Options:StartBarBind")
    self:WatchBindTargets()
    self.binding = {}
    Addon.Input:SetBindingMode(true)
    Addon:QueueRefresh(true)
    self.catcher:Show()
    self:UpdateBindNotice()
end

function Options:StopBarBind()
    if not self.binding then return end
    Addon:Trace("Options:StopBarBind")
    self:SetBindTarget(nil, nil, nil)
    self.binding = nil
    if self.catcher then self.catcher:Hide() end
    Addon.Input:SetBindingMode(false)
    Addon:QueueRefresh(true)
end

function Options:BindFromBars()
    if not OutsideCombat() then return end
    Addon.SettingsWindow:Hide()
    if SettingsPanel:IsShown() then
        -- Let the player close Settings; closing it from here taints its teardown.
        self.pendingBind = true
        Addon:Print(text.bindPending)
        return
    end
    self:StartBarBind()
end

function Options:ObserveSettingsPanel()
    SettingsPanel:HookScript("OnHide", function()
        if not self.pendingBind then return end
        self.pendingBind = nil
        -- Start after the native close has finished.
        C_Timer.After(0, function()
            if OutsideCombat() then self:StartBarBind() end
        end)
    end)
end

-- Options > AddOns has one button that opens the settings window.
function Options:Register()
    local category, layout = Settings.RegisterVerticalLayoutCategory("ClassicConsoleGamepadUI")
    self.category = category
    layout:AddInitializer(CreateSettingsButtonInitializer("ClassicConsoleGamepadUI", text.open, function()
        Addon.SettingsWindow:Open()
    end, text.openTip, true))
    Settings.RegisterAddOnCategory(category)
    self:ObserveSettingsPanel()
end

function Options:Open()
    Addon.SettingsWindow:Toggle()
end
