local _, Addon = ...
local Input = { dirty = true, activeBarFrameLevel = 5, state = "idle" }
Addon.Input = Input

local SETUP = [[
    bars, anchors, sources, delegates, owners = newtable(), newtable(), newtable(), newtable(), newtable()
    for i = 1, 9 do
        bars[i] = self:GetFrameRef("bar" .. i)
        sources[i], delegates[i] = newtable(), newtable()
        for j = 1, 8 do
            sources[i][j] = self:GetFrameRef("source" .. i .. "-" .. j)
            delegates[i][j] = self:GetAttribute("delegate" .. i .. "-" .. j)
        end
    end
    for i = 1, 4 do anchors[i] = self:GetFrameRef("anchor" .. i) end
]]

-- Secure handlers reject the function keyword and table constructors.
-- pickbar runs with (self, index) and reads the tables built above.
local PICK_BAR = [[
    local index = ...
    local key
    for i = 1, 4 do
        if bars[i]:IsShown() then key = index; break end
    end
    for i = 5, 6 do
        if bars[i] and bars[i]:IsShown() and bars[i]:GetParent() == anchors[index] then key = i end
    end
    if index == 1 then
        for i = 7, 9 do
            if bars[i] and bars[i]:IsShown() then key = i end
        end
    end
    return key
]]

local PRE_CLICK = [[
    self:SetAttribute("type", nil)
    if not down then self:SetAttribute("cgppressed", nil) end
    local keyboard = button == "Keybind"
    if (button ~= "LeftButton" and not keyboard) or not control:GetAttribute("enabled") then return false end
    local source, kind
    if down then
        self:SetAttribute("cgppressed", true)
        local group, index = self:GetAttribute("group"), self:GetAttribute("index")
        if group == 0 then
            source, kind = control:GetFrameRef("class" .. index), "delegate"
            if not source or not source:IsShown() then
                -- No class action: the keyboard bar's button at this position (9 or 10).
                source = control:GetFrameRef("kbd" .. (index + 8))
                if not source then return false end
            end
        elseif group == 5 then
            -- Spare main-row slots: the keyboard bar's button at the same position.
            source, kind = control:GetFrameRef("kbd" .. index), "delegate"
            if not source then return false end
        else
            if group == 1 and control:GetAttribute("compact") then
                local combined = control:RunAttribute("pickbar", 4)
                if combined and bars[combined]:GetFrameLevel() == control:GetAttribute("activelevel") then group = 4 end
            end
            local key = control:RunAttribute("pickbar", group)
            if not key then return false end
            source = sources[key][index]
            kind = key == 5 and "pet" or (delegates[key][index] and "delegate" or "action")
            if kind == "action" then
                local action = source:GetID()
                if not action or action <= 0 then return false end
                local actionType = GetActionInfo(action)
                if actionType == "flyout" then kind = "delegate" end
            end
        end
        local owner = newtable()
        owner[1], owner[2] = source, kind
        owners[self] = owner
    else
        local owner = owners[self]
        owners[self] = nil
        if not owner then return false end
        source, kind = owner[1], owner[2]
    end
    if kind == "delegate" then
        self:SetAttribute("type", "macro")
        self:SetAttribute("useOnKeyDown", down)
        self:SetAttribute("macrotext", "/click " .. source:GetName() .. " LeftButton " .. (down and "1" or "0"))
    elseif down and not keyboard then
        return false
    else
        local action = source:GetID()
        if not action or action <= 0 then return false end
        if keyboard then self:SetAttribute("useOnKeyDown", nil)
        else self:SetAttribute("useOnKeyDown", false) end
        self:SetAttribute("type", kind)
        self:SetAttribute("action", action)
    end
    return "LeftButton"
]]

local APPLY_BINDINGS = [[
    self:ClearBindings()
    if self:GetAttribute("enabled") then
        for i = 1, self:GetAttribute("bindingcount") or 0 do
            self:SetBindingClick(true, self:GetAttribute("key" .. i), self:GetAttribute("button" .. i), "Keybind")
        end
    end
]]

-- Runs inside the secure header so EnableMouse does not taint the native buttons.
-- A tainted action button makes the client's later SetPreferredGamepadInteractTarget fail.
local SUPPRESS_MOUSE = [[
    local restore = self:GetAttribute("mouserestore")
    local stack, n, i = newtable(), 1, 1
    stack[1] = self:GetFrameRef("native")
    while i <= n do
        local frame = stack[i]
        i = i + 1
        if frame and (not frame.IsForbidden or not frame:IsForbidden()) then
            if restore then
                if frame:GetAttribute("cgpmouse") then
                    frame:SetAttribute("cgpmouse", nil)
                    frame:EnableMouse(true)
                end
            elseif frame:IsMouseEnabled() then
                frame:SetAttribute("cgpmouse", true)
                frame:EnableMouse(false)
            end
            local kids = newtable(frame:GetChildren())
            local c = 1
            while kids[c] do
                n = n + 1
                stack[n] = kids[c]
                c = c + 1
            end
        end
    end
]]

local RESUME = [[
    if control:GetAttribute("enabled") and control:GetFrameRef("native"):IsShown() then
        for i = 1, control:GetAttribute("blockercount") or 0 do
            if control:GetFrameRef("blocker" .. i):IsShown() then return end
        end
        control:Show()
    end
]]

-- Face buttons (native 5-8, X Y B A) sit on the left of each row of eight.
-- The cross (native 1-4) sits on the right.
local function RowIndex(offset)
    if offset <= 4 then return offset + 4 end
    return offset - 4
end

local function SlotAction(i)
    if i <= 8 then return 1, RowIndex(i) end
    if i <= 10 then return 0, i - 8 end
    if i <= 12 then return 5, i end
    if i >= 13 and i <= 20 then return 2, RowIndex(i - 12) end
    if i >= 21 and i <= 24 then return 4, i - 16 end
    if i >= 25 and i <= 32 then return 3, RowIndex(i - 24) end
    if i >= 33 and i <= 36 then return 4, i - 32 end
end

function Input:SyncNativeMouse(restore)
    local header = self.header
    if not header or self.disabled or InCombatLockdown() then return end
    -- Snippets are not vararg functions, so the flag travels as an attribute.
    -- Skip repeat walks; refresh runs several times a second.
    local want = restore and true or false
    if self.mouseRestored == want then return end
    Addon:Trace("Input:SyncNativeMouse " .. tostring(want))
    header:SetAttribute("mouserestore", want)
    local ok, err = pcall(function() header:Execute(SUPPRESS_MOUSE) end)
    if ok then
        self.mouseRestored = want
    else
        self:Disable(err)
    end
end

function Input:IsEnabled()
    return not self.disabled and self.header and self.header:GetAttribute("enabled")
end

function Input:RefreshTooltip()
    local button, slot = self.tooltipButton, self.tooltipSlot
    if not button or GameTooltip:GetOwner() ~= button then return end
    local source = slot.source
    if not source then GameTooltip:Hide(); return end
    -- Native SetTooltip writes UpdateTooltip onto the Blizzard button.
    local action = source:GetID()
    local spellID = source.GetSingleSpellID and source:GetSingleSpellID()
    local bar = source.parentActionBar
    if bar and bar.faceLeftButton == source then spellID = bar.rangedSpellID or spellID end
    if spellID then
        GameTooltip:SetSpellByID(spellID)
    elseif source.isGamepadPossessBarButton then
        GameTooltip:SetPetAction(action)
    elseif action and action > 0 then
        if not GameTooltip:SetAction(action) then GameTooltip:Hide() end
    else
        GameTooltip:Hide()
    end
end

function Input:IsBlocked()
    if self.disabled then return false end
    if not InCombatLockdown() and SettingsPanel and SettingsPanel:IsShown() then
        self.blockedBy = "SettingsPanel"
        return true
    end
    for frame in pairs(self.blockers or {}) do
        if frame:IsShown() then
            self.blockedBy = frame:GetName() or "unnamed"
            return true
        end
    end
    self.blockedBy = nil
    return false
end

function Input:Disable(err)
    if self.disabled then return end
    self.disabled = true
    self.lastError = tostring(err or "unknown error")
    self.state = "error"
    if self.header then
        pcall(function()
            self.header:SetAttribute("enabled", false)
            self.header:Hide()
        end)
    end
    Addon:Print("Mouse/keyboard layer disabled: " .. self.lastError)
end

local function SetRef(header, label, frame)
    if frame then pcall(header.SetFrameRef, header, label, frame) end
end

function Input:Create(native, unit, bars)
    local header = CreateFrame("Frame", "ClassicConsoleGamepadUIInput", UIParent, "SecureHandlerShowHideTemplate")
    header:SetFrameStrata(Addon.Display.root:GetFrameStrata())
    header:SetFrameLevel(Addon.Display.root:GetFrameLevel() + 5)
    header:Hide()
    self.header, self.buttons, self.blockers = header, {}, {}
    header:SetFrameRef("native", native)
    header:SetAttribute("_onshow", APPLY_BINDINGS)
    header:SetAttribute("_onhide", "self:ClearBindings()")
    header:SetAttribute("activelevel", self.activeBarFrameLevel)
    header:SetAttribute("pickbar", PICK_BAR)
    pcall(SecureHandlerWrapScript, native, "OnHide", header, [[control:SetAttribute("enabled", false); control:Hide()]])
    for i, key in ipairs({ "topBar", "leftBar", "rightBar", "bottomBar", "possessBar", "stanceBar",
        "FriendlyTargetingActionBar", "HostileTargetingActionBar", "ShortcutsActionBar" }) do
        local bar = i <= 6 and unit.actionBars[key] or unit[key]
        if bar then
            SetRef(header, "bar" .. i, bar)
            for j, source in ipairs(bar.actionButtons) do
                SetRef(header, "source" .. i .. "-" .. j, source)
                local pageSlot = source.GetGamepadPageUnitSlotID and source:GetGamepadPageUnitSlotID()
                local reserved = pageSlot and GamepadActionBarBindingUtil.IsReservedPageUnitSlotID(pageSlot)
                header:SetAttribute("delegate" .. i .. "-" .. j, i >= 7 or reserved or false)
            end
        end
    end
    for i, anchor in ipairs({ unit.TopCenteredAnchor, unit.LeftCenteredAnchor, unit.RightCenteredAnchor, unit.BottomCenteredAnchor }) do
        SetRef(header, "anchor" .. i, anchor)
    end
    SetRef(header, "class1", unit.LeftClassAction)
    SetRef(header, "class2", unit.RightClassAction)
    -- The keyboard bar's buttons 9-12 serve the main-row positions without a gamepad action.
    for position = 9, 12 do
        SetRef(header, "kbd" .. position, MainActionBar and MainActionBar.actionButtons[position])
    end
    header:Execute(SETUP)
    for i, slot in ipairs(Addon.Display.slots) do
        local group, index = SlotAction(i)
        if group then
            -- Protected hitboxes are separate from the freely refreshed visual frames.
            local button = CreateFrame("Button", "ClassicConsoleGamepadUIInputButton" .. i, header, "SecureActionButtonTemplate")
            button:SetID(0)
            button:SetAttribute("group", group)
            button:SetAttribute("index", index)
            button:SetAttribute("checkselfcast", true)
            button:SetAttribute("checkfocuscast", true)
            button:SetAttribute("checkmouseovercast", true)
            button:RegisterForClicks("AnyDown", "AnyUp")
            button:RegisterForDrag("LeftButton")
            SecureHandlerWrapScript(button, "OnClick", header, PRE_CLICK)
            button:SetScript("OnDragStart", function() Addon.Display:PickupSlot(slot) end)
            SecureHandlerWrapScript(button, "OnDragStart", header, [[owners[self] = nil; self:SetAttribute("type", nil); self:SetAttribute("cgppressed", nil)]])
            SecureHandlerWrapScript(button, "OnHide", header, [[owners[self] = nil; self:SetAttribute("cgppressed", nil)]])
            button:SetScript("OnReceiveDrag", function() Addon.Display:ReceiveSlot(slot) end)
            button:SetScript("OnAttributeChanged", function(_, name, value)
                if name == "cgppressed" then
                    slot.Pushed:SetShown(value == true)
                    Addon:QueueRefresh()
                end
            end)
            slot.inputButton = button
            button:SetScript("OnEnter", function()
                self.tooltipButton, self.tooltipSlot = button, slot
                GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                self:RefreshTooltip()
            end)
            button:SetScript("OnLeave", function()
                if GameTooltip:GetOwner() == button then GameTooltip:Hide() end
                self.tooltipButton, self.tooltipSlot = nil, nil
            end)
            slot.Key = slot.Labels:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            slot.Key:SetPoint("BOTTOMLEFT", 5, 5)
            slot:EnableMouse(false)
            self.buttons[i] = button
        end
    end
    self:ObserveBlockers(bars, unit)
end

function Input:ObserveBlockers(bars, unit)
    local function Add(frame)
        if not frame or self.blockers[frame] then return end
        local ok, protected = pcall(function() return frame:IsProtected() end)
        if not ok or not protected then return end
        local ok = pcall(SecureHandlerWrapScript, frame, "OnShow", self.header, "control:Hide()")
        if not ok then return end
        pcall(SecureHandlerWrapScript, frame, "OnHide", self.header, RESUME)
        self.blockers[frame] = true
        local header = self.header
        local count = (header:GetAttribute("blockercount") or 0) + 1
        header:SetAttribute("blockercount", count)
        SetRef(header, "blocker" .. count, frame)
    end
    Add(GamepadActionBarEditFrame)
    Add(EditModeManagerFrame)
    for _, frame in pairs({ SpellFlyout, GamepadSpellFlyout, GamepadPetActionFlyout, GamepadPetSpellFlyout }) do Add(frame) end
    for _, bar in ipairs(bars) do
        for _, source in ipairs(bar.actionButtons) do Add(source.popup) end
    end
    Add(unit.LeftClassAction and unit.LeftClassAction.popup)
    Add(unit.RightClassAction and unit.RightClassAction.popup)
end

function Input:SetBindingMode(active)
    self.bindingMode = active and true or nil
    self.dirty = true
    if not active or InCombatLockdown() or not self.header then return end
    for _, button in pairs(self.buttons) do button:SetAttribute("cgppressed", nil) end
    pcall(function()
        self.header:SetAttribute("enabled", false)
        self.header:Execute(APPLY_BINDINGS)
    end)
end

-- Collect the keyboard keys of every visible slot's classic bar position.
-- The secure header applies them only while the click layer is enabled.
function Input:UpdateBindings()
    local header, count = self.header, 0
    self.labelShown = {}
    for i, button in pairs(self.buttons) do
        local slot = Addon.Display.slots[i]
        slot.Key:SetText("")
        self.labelShown[i] = slot:IsShown()
        if slot:IsShown() then
            local label
            pcall(function()
                local action = slot.bindingAction
                if not action then return end
                local context = C_KeyBindings.GetBindingContextForAction(action)
                for _, key in ipairs({ GetBindingKey(action, nil, context) }) do
                    if not IsBindingForGamePad(key) then
                        count = count + 1
                        header:SetAttribute("key" .. count, key)
                        header:SetAttribute("button" .. count, button:GetName())
                        label = label or GetBindingText(key, 1)
                    end
                end
            end)
            slot.Key:SetText(label or "")
        end
    end
    header:SetAttribute("bindingcount", count)
    self.dirty, self.bindingsPending = false, true
    self.labelRevision = Addon.Layout.revision
end

-- True when a slot appeared or disappeared since the labels were collected.
function Input:SlotsChanged()
    if not self.labelShown then return true end
    for i in pairs(self.buttons) do
        if self.labelShown[i] ~= Addon.Display.slots[i]:IsShown() then return true end
    end
    return false
end

function Input:Refresh(wanted, native, unit, bars)
    if self.disabled then return false end
    if InCombatLockdown() then return self:IsEnabled() end
    if not self.header then
        if not wanted then return false end
        self:Create(native, unit, bars)
    end
    local header = self.header
    if not wanted then
        if header:IsShown() then Addon:Trace("Input off") end
        self:SyncNativeMouse(true)
        header:SetAttribute("enabled", false)
        header:Hide()
        self.state = "off"
        return false
    end
    -- Labels follow the visible slots even while Settings or a flyout pauses
    -- the click layer, e.g. right after switching between 8 and 12 slots.
    local bindingsDirty = self.dirty
    if bindingsDirty or self.labelRevision ~= Addon.Layout.revision or self:SlotsChanged() then
        self:UpdateBindings()
    end
    if self.bindingMode then
        -- Keep the slot hitboxes shown so they can be hovered, but drop the
        -- temporary key overrides so the pressed key reaches the binder.
        header:SetAttribute("enabled", false)
        header:Execute(APPLY_BINDINGS)
        self.state = "binding"
        return false
    end
    local geometryChanged = self.layoutRevision ~= Addon.Layout.revision
    if bindingsDirty or geometryChanged then self:ObserveBlockers(bars, unit) end
    if self:IsBlocked() then
        header:SetAttribute("enabled", false)
        header:Hide()
        self.state = "blocked"
        return false
    end
    if geometryChanged then
        header:SetAttribute("compact", Addon.Layout.compact)
        for i, button in pairs(self.buttons) do
            local slot = Addon.Display.slots[i]
            if not Addon.Layout:Place(button, slot) then
                header:SetAttribute("enabled", false)
                header:Hide()
                self.state = "blocked"
                return false
            end
            local _, index = SlotAction(i)
            if index then button:SetAttribute("index", index) end
            button:SetShown(slot:IsShown())
        end
        self.layoutRevision = Addon.Layout.revision
    end
    if self.layoutRevision == Addon.Layout.revision then
        for i, button in pairs(self.buttons) do
            local slot = Addon.Display.slots[i]
            if slot then
                local shown = slot:IsShown()
                button:SetShown(shown)
                if not shown then slot.Key:SetText("") end
            end
        end
    end
    header:SetAttribute("enabled", true)
    if not header:IsShown() then Addon:Trace("Input on"); header:Show()
    elseif self.bindingsPending then header:Execute(APPLY_BINDINGS) end
    self.bindingsPending = nil
    self:SyncNativeMouse(false)
    if self.disabled then return false end
    self:RefreshTooltip()
    self.state = "on"
    return true
end
