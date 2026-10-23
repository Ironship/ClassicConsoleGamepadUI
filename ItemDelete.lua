local _, Addon = ...
local ItemDelete = {}
Addon.ItemDelete = ItemDelete

local deleteDialogs = {
    DELETE_ITEM = true, DELETE_QUEST_ITEM = true,
    DELETE_GOOD_ITEM = true, DELETE_GOOD_QUEST_ITEM = true,
    DELETE_GOOD_ITEM_GAMEPAD = true, DELETE_GOOD_QUEST_ITEM_GAMEPAD = true,
}

-- InputIconTextureState is local to Blizzard's InputIconTexture.lua.
local NORMAL, ACTIVE, DISABLED = 1, 4, 5
local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }

-- Draw above the dialog's strata: its translucent background covers frames
-- that only share its strata whenever the toplevel popup is raised.
local function StrataAbove(strata)
    for i, name in ipairs(STRATA) do
        if name == strata then return STRATA[math.min(i + 1, #STRATA)] end
    end
    return "FULLSCREEN_DIALOG"
end

local BIND = [[
    self:ClearBindings()
    for i = 1, self:GetAttribute("keycount") do
        self:SetBindingClick(true, self:GetAttribute("key" .. i), self:GetAttribute("button"), self:GetAttribute("token" .. i))
    end
]]

local CLICK = [[
    self:SetAttribute("type", nil)
    if not down or control:GetAttribute("state-combat") == "1" then return false end
    local popup = control:GetFrameRef("popup")
    if not popup or not popup:IsShown() then return false end
    local step = control:GetAttribute("step") or 0
    local expected = step < 2 and "X" or "A"
    if button ~= expected then
        control:SetAttribute("step", 0)
        return false
    end
    step = step + 1
    control:SetAttribute("step", step)
    if step < 4 then return false end
    control:SetAttribute("step", 0)
    control:GetFrameRef("accept"):Enable()
    self:SetAttribute("type", "click")
    return "LeftButton"
]]

function ItemDelete:Create()
    local header = CreateFrame("Frame", "ClassicConsoleGamepadUIItemDelete", UIParent,
        "SecureHandlerShowHideTemplate,SecureHandlerStateTemplate")
    header:Hide()
    header:SetAttribute("_onshow", BIND)
    header:SetAttribute("_onhide", "self:ClearBindings()")
    header:SetAttribute("_onstate-combat", [[if newstate == "1" then self:Hide() end]])
    RegisterStateDriver(header, "combat", "[combat]1;0")
    local button = CreateFrame("Button", "ClassicConsoleGamepadUIItemDeleteButton", header, "SecureActionButtonTemplate")
    button:SetSize(1, 1)
    button:SetPoint("CENTER")
    button:EnableMouse(false)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("useOnKeyDown", true)
    SecureHandlerWrapScript(button, "OnClick", header, CLICK)
    local count = 0
    for _, key in ipairs({ GAMEPAD_FACE_LEFT, GAMEPAD_FACE_BOTTOM, GAMEPAD_FACE_TOP,
        GAMEPAD_DPAD_LEFT, GAMEPAD_DPAD_RIGHT, GAMEPAD_DPAD_BOTTOM, GAMEPAD_DPAD_TOP,
        GAMEPAD_SHOULDER_LEFT, GAMEPAD_SHOULDER_RIGHT, GAMEPAD_TRIGGER_LEFT, GAMEPAD_TRIGGER_RIGHT }) do
        for _, prefix in ipairs({ "", "SHIFT-", "CTRL-", "CTRL-SHIFT-" }) do
            count = count + 1
            local token = prefix == "" and (key == GAMEPAD_FACE_LEFT and "X" or key == GAMEPAD_FACE_BOTTOM and "A") or "reset"
            header:SetAttribute("key" .. count, prefix .. key)
            header:SetAttribute("token" .. count, token or "reset")
        end
    end
    header:SetAttribute("keycount", count)
    header:SetAttribute("button", button:GetName())
    header:HookScript("OnAttributeChanged", function(_, name, value)
        if name == "step" then self:UpdateGlyphs(value) end
    end)
    header:HookScript("OnHide", function() self:RestoreSequence() end)
    self.header, self.button, self.glyphs = header, button, {}
    for i = 1, 4 do
        local glyph = header:CreateTexture(nil, "OVERLAY")
        glyph:SetSize(32, 32)
        glyph:SetPoint("CENTER", header, "CENTER", (i - 2.5) * 40, 0)
        self.glyphs[i] = glyph
    end
end

-- Mirror the native sequence: done steps are greyed, the next press is focused.
function ItemDelete:UpdateGlyphs(step)
    step = tonumber(step) or 0
    for i, glyph in ipairs(self.glyphs) do
        local key = i <= 2 and GAMEPAD_FACE_LEFT or GAMEPAD_FACE_BOTTOM
        local textures = InputIconTextureSetUtility.GetActiveInputIconButtonTextures(key) or {}
        local state = i <= step and DISABLED or (i == step + 1 and ACTIVE or NORMAL)
        local atlas = textures[state] or textures[NORMAL]
        if atlas then glyph:SetAtlas(atlas) end
        glyph:SetAlpha(1)
    end
end

function ItemDelete:RestoreSequence()
    if self.sequence then self.sequence:SetAlpha(self.sequenceAlpha) end
    if self.confirmText then self.confirmText:SetAlpha(self.confirmAlpha) end
    self.sequence, self.sequenceAlpha, self.confirmText, self.confirmAlpha = nil, nil, nil, nil
end

-- Gamepad delete texts already end with the confirmation prompt that the
-- dialog adds again below them; hide only that repeated line.
function ItemDelete:HideRepeatedPrompt(dialog)
    local prompt, confirm = DIALOG_CONFIRMATION_PROMPT_GAMEPAD, dialog.ConfirmText
    local body = dialog.GetTextFontString and dialog:GetTextFontString()
    local text = body and body:GetText()
    if not prompt or not confirm or type(text) ~= "string" or confirm:GetText() ~= prompt
        or not text:find(prompt, 1, true) then return end
    self.confirmText, self.confirmAlpha = confirm, confirm:GetAlpha()
    confirm:SetAlpha(0)
end

function ItemDelete:Refresh()
    if InCombatLockdown() then return end
    local dialog = self.dialog
    local wanted = Addon.db.easyDelete and Addon:IsGamepadMode() and not Addon.conflict
        and dialog and dialog:IsShown() and dialog.gamepadFocused
        and deleteDialogs[dialog.which] and dialog.dialogInfo.requiresConfirmation
    if not wanted then
        if self.header then self.header:Hide() end
        self:RestoreSequence()
        return
    end
    if not self.header then self:Create() end
    local header, sequence = self.header, dialog.GamepadSequence
    -- The secure header cannot inherit the native sequence's region-based anchors.
    if not Addon.Layout:Place(header, sequence) then
        header:Hide()
        self:RestoreSequence()
        return
    end
    -- Top-level popups can be raised again while the overlay is already shown.
    header:SetFrameStrata(StrataAbove(dialog:GetFrameStrata()))
    header:SetFrameLevel(math.min(sequence:GetFrameLevel() + 1, 9000))
    if header:IsShown() and self.sequence == sequence then
        if self.dirty then header:Execute(BIND); self.dirty = nil end
        return
    end
    header:Hide()
    -- Keep the native sequence and its binding stack untouched; only its art is covered.
    self.sequence, self.sequenceAlpha = sequence, sequence:GetAlpha()
    sequence:SetAlpha(0)
    self:HideRepeatedPrompt(dialog)
    header:SetFrameRef("popup", dialog)
    header:SetFrameRef("accept", dialog:GetButton1())
    self.button:SetAttribute("clickbutton", dialog:GetButton1())
    header:SetAttribute("step", 0)
    self:UpdateGlyphs(0)
    header:Show()
    self.dirty = nil
end

function ItemDelete:Observe()
    EventRegistry:RegisterCallback("Gamepad.RefreshFrameFocus", function()
        if not self.dialog then return end
        self.dirty = true
        Addon:QueueRefresh(true)
    end, self)
    PopupEventManager:RegisterCallback("PopupOpened", function(_, dialog)
        if deleteDialogs[dialog.which] then
            self.dialog = dialog
            self:Refresh()
            Addon:QueueRefresh(true)
        end
    end, self)
    PopupEventManager:RegisterCallback("PopupClosed", function(_, dialog)
        if self.dialog == dialog then
            self.dialog = nil
            self:Refresh()
            Addon:QueueRefresh(true)
        end
    end, self)
end
