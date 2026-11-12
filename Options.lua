local _, Addon = ...
local Options = {}
Addon.Options = Options

-- Every text of the interface comes from the language files in Locales/ (Addon.L, the language chosen in the settings).
local text = Addon.L

local controls = {
    { key = "enabled", default = true, section = "layout" },
    { key = "compact", default = true },
    { key = "groupBoth", default = false },
    { key = "moveUnitFrames", default = true },
    { key = "contextGap", default = 12, min = 0, max = 100, step = 2 },
    { key = "menuRight", default = 12, min = 0, max = 128, step = 1, section = "menu", tip = "menuTip" },
    { key = "menuBottom", default = 0, min = 0, max = 240, step = 1, tip = "menuTip" },
    { key = "promptScale", default = 1, min = 0.6, max = 1.6, step = 0.05, section = "hints" },
    { key = "modifierScale", default = 1.5, min = 0.6, max = 2.5, step = 0.05 },
    { key = "showKeyboardHints", default = true },
    { key = "showMenuHints", default = true },
    { key = "highlightActive", default = true },
    { key = "moveLegend", default = false, section = "legend" },
    { key = "legendX", default = 16, min = 0, max = 600, step = 2, parent = "moveLegend", tip = "legendPositionTip" },
    { key = "legendGap", default = 12, min = 0, max = 240, step = 2, parent = "moveLegend", tip = "legendPositionTip" },
    { key = "anchorChat", default = false, section = "chat" },
    { key = "chatLeft", default = 0, min = 0, max = 1200, step = 1, parent = "anchorChat", tip = "chatPositionTip" },
    { key = "chatBottom", default = 0, min = 0, max = 800, step = 1, parent = "anchorChat", tip = "chatPositionTip" },
    { key = "raiseChat", default = true },
    { key = "chatGap", default = 12, min = 0, max = 100, step = 2, parent = "raiseChat" },
    { key = "keyboardEnabled", default = true },
    { key = "autoKeyboard", default = false, parent = "keyboardEnabled" },
    { key = "wordHunter", default = true, parent = "keyboardEnabled" },
    { key = "easyDelete", default = false, section = "items" },
}

local geometrySettings = { compact = true, groupBoth = true, contextGap = true,
    menuRight = true, menuBottom = true, promptScale = true, modifierScale = true }

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
}

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
    elseif key == "wordHunter" then
        Addon.WordSources:Changed()
    else
        if geometrySettings[key] then Addon.Layout.dirty = true end
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
