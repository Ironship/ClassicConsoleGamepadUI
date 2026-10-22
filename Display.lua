local _, Addon = ...
local Display = {}
Addon.Display = Display

local function Readable(value)
    return not issecretvalue or not issecretvalue(value)
end

local function Texture(parent, layer, path)
    local texture = parent:CreateTexture(nil, layer)
    if path then texture:SetTexture(path) end
    return texture
end

local function CopyTexture(target, source)
    if not source then target:Hide(); return end
    local atlas = source.GetAtlas and source:GetAtlas()
    if Readable(atlas) and atlas then
        target:SetAtlas(atlas)
    else
        target:SetTexture(source:GetTexture())
    end
    target:SetTexCoord(source:GetTexCoord())
    if target.SetVertexColor and source.GetVertexColor then target:SetVertexColor(source:GetVertexColor()) end
    target:SetAlpha(source:GetAlpha())
    if target.SetBlendMode and source.GetBlendMode then target:SetBlendMode(source:GetBlendMode()) end
    if target.SetDesaturation and source.GetDesaturation then target:SetDesaturation(source:GetDesaturation()) end
    target:Show()
end

local function CopyGlyph(target, prompt)
    if not prompt then target:Hide(); return end
    local source = prompt.NormalTexture
    for _, key in ipairs({ "PressedTexture", "ActiveTexture", "HoverTexture", "DisabledTexture" }) do
        local candidate = prompt[key]
        if candidate and candidate:IsShown() then source = candidate; break end
    end
    CopyTexture(target, source)
end

local function StockTexture(parent, source, owner, layer)
    local texture = Texture(parent, layer or "ARTWORK")
    CopyTexture(texture, source)
    Addon.Layout:Place(texture, source, owner, owner)
    return texture
end

local function CreateSlot(parent, template)
    -- These are display frames, never substitute action buttons or binding owners.
    local slot = CreateFrame("Frame", nil, parent)
    slot.template = template
    Addon.Layout:Place(slot, template)
    slot.Background = StockTexture(slot, template.SlotBackground, template, "BACKGROUND")
    slot.SlotArt = StockTexture(slot, template.SlotArt, template, "BACKGROUND")
    slot.Background:SetShown(template.SlotBackground and template.SlotBackground:IsShown() or false)
    slot.SlotArt:SetShown(template.SlotArt and template.SlotArt:IsShown() or false)
    slot.Icon = StockTexture(slot, template.icon, template, "ARTWORK")
    slot.Border = StockTexture(slot, template:GetNormalTexture(), template, "OVERLAY")
    if template.IconMask then
        slot.Mask = slot:CreateMaskTexture(nil, "ARTWORK")
        CopyTexture(slot.Mask, template.IconMask)
        Addon.Layout:Place(slot.Mask, template.IconMask, template, template)
        slot.Icon:AddMaskTexture(slot.Mask)
    end
    slot.Cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
    Addon.Layout:Place(slot.Cooldown, template.cooldown, template, template)
    slot.Cooldown:SetDrawEdge(false)
    slot.Cooldown:SetHideCountdownNumbers(false)
    slot.Cooldown:SetFrameLevel(slot:GetFrameLevel() + 1)
    local labels = CreateFrame("Frame", nil, slot)
    labels:SetAllPoints()
    labels:SetFrameLevel(slot:GetFrameLevel() + 3)
    slot.Labels = labels
    slot.Prompt = Texture(labels, "OVERLAY")
    slot.Prompt:SetSize(28, 28)
    slot.Prompt:SetPoint("TOPRIGHT", 4, 4)
    slot.Modifiers = {}
    for i = 1, 2 do
        local glyph = Texture(labels, "OVERLAY")
        glyph:SetSize(20, 20)
        glyph:SetPoint("TOPLEFT", (i - 1) * 13 - 4, 3)
        slot.Modifiers[i] = glyph
    end
    slot.Count = labels:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    if template.Count then slot.Count:SetFont(template.Count:GetFont()) end
    slot.Count:SetPoint("BOTTOMRIGHT", -5, 5)
    slot.Checked = StockTexture(labels, template:GetCheckedTexture(), template)
    slot.Pushed = StockTexture(labels, template:GetPushedTexture(), template)
    slot.Glow = StockTexture(labels, template.SpellHighlightTexture or template:GetHighlightTexture(), template, "OVERLAY")
    slot.Glow:SetVertexColor(1, 0.8, 0.25)
    slot.Glow:Hide()
    return slot
end

function Display:Create()
    if self.root then return end
    local root = CreateFrame("Frame", "ClassicGamepadBar", UIParent)
    root:SetAllPoints(UIParent)
    root:SetFrameStrata("LOW")
    root:SetFrameLevel(MainActionBar:GetFrameLevel())
    self.root, self.slots, self.hooked, self.pressed = root, {}, {}, {}
    for _, button in ipairs(Addon.Layout:GetButtons()) do
        self.slots[#self.slots + 1] = CreateSlot(root, button)
    end
    self.art = {}
    local caps = MainActionBar.EndCaps
    for _, source in ipairs({ MainActionBar.BorderArt, caps.LeftEndCap.Texture, caps.RightEndCap.Texture }) do
        local holder = CreateFrame("Frame", nil, root)
        holder:SetAllPoints(root)
        holder:SetFrameLevel(source:GetParent():GetFrameLevel())
        self.art[#self.art + 1] = { source = source, texture = StockTexture(holder, source, nil, "BACKGROUND") }
    end
    local page = MainActionBar.ActionBarPageNumber
    local pageHolder = CreateFrame("Frame", nil, root)
    pageHolder:SetAllPoints(root)
    pageHolder:SetFrameLevel(page:GetFrameLevel())
    self.pageLabel = pageHolder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.pageLabel:SetFont(page.Text:GetFont())
    self.pageLabel:SetTextColor(page.Text:GetTextColor())
    self.pageSource = page.Text
    for _, button in ipairs({ page.UpButton, page.DownButton }) do
        self.art[#self.art + 1] = { source = button:GetNormalTexture(),
            texture = StockTexture(pageHolder, button:GetNormalTexture(), nil) }
    end
    root:Hide()
end

function Display:RefreshGeometry()
    if self.layoutRevision == Addon.Layout.revision then return true end
    for _, slot in ipairs(self.slots) do
        local template = slot.template
        if not Addon.Layout:Place(slot, template) then return false end
        for _, entry in ipairs({
            { slot.Background, template.SlotBackground }, { slot.SlotArt, template.SlotArt },
            { slot.Border, template:GetNormalTexture() }, { slot.Checked, template:GetCheckedTexture() },
            { slot.Pushed, template:GetPushedTexture() },
            { slot.Glow, template.SpellHighlightTexture or template:GetHighlightTexture() },
        }) do
            CopyTexture(entry[1], entry[2])
            Addon.Layout:Place(entry[1], entry[2], template, template)
        end
        slot.Background:SetShown(template.SlotBackground and template.SlotBackground:IsShown() or false)
        slot.SlotArt:SetShown(template.SlotArt and template.SlotArt:IsShown() or false)
        Addon.Layout:Place(slot.Icon, template.icon, template, template)
        Addon.Layout:Place(slot.Cooldown, template.cooldown, template, template)
        if slot.Mask then
            CopyTexture(slot.Mask, template.IconMask)
            Addon.Layout:Place(slot.Mask, template.IconMask, template, template)
        end
        if template.Count then slot.Count:SetFont(template.Count:GetFont()) end
        slot.Glow:SetVertexColor(1, 0.8, 0.25)
    end
    for _, entry in ipairs(self.art) do
        CopyTexture(entry.texture, entry.source)
        if not Addon.Layout:Place(entry.texture, entry.source) then return false end
    end
    Addon.Layout:Place(self.pageLabel, self.pageSource, nil, MainActionBar.ActionBarPageNumber)
    self.pageLabel:SetFont(self.pageSource:GetFont())
    self.layoutRevision = Addon.Layout.revision
    return true
end

function Display:GetBars()
    local native = GamepadMainActionBarFrame
    local unit = native and native.PageUnit
    if not unit or not unit.actionBars then return end
    local bars = {}
    for _, bar in pairs(unit.actionBars) do bars[#bars + 1] = bar end
    for _, key in ipairs({ "FriendlyTargetingActionBar", "HostileTargetingActionBar", "ShortcutsActionBar" }) do
        if unit[key] then bars[#bars + 1] = unit[key] end
    end
    return native, unit, bars
end

function Display:IsEditing()
    return (EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive())
        or (GamepadActionBarEditFrame and GamepadActionBarEditFrame:IsShown())
end

function Display:NeedsNativeView(bars, unit)
    if self:IsEditing() then return true end
    -- Flyouts stay entirely native, including their focus, selection and placement.
    for _, bar in ipairs(bars) do
        for _, source in ipairs(bar.actionButtons or {}) do
            if source.IsPopupOpen and source:IsPopupOpen() then return true end
        end
    end
    for _, key in ipairs({ "LeftClassAction", "RightClassAction" }) do
        local source = unit[key]
        if source and source.IsPopupOpen and source:IsPopupOpen() then return true end
    end
    -- Picking up an action with the mouse must expose the actual drop targets.
    if GetCursorInfo and GetCursorInfo() then return true end
    if IsGamePadCursorControlEnabled and IsGamePadCursorControlEnabled() then return true end
    return false
end

function Display:HookSource(source)
    if self.hooked[source] then return end
    self.hooked[source] = true
    local cooldown = source.cooldown or source.Cooldown
    if cooldown then
        for _, method in ipairs({ "SetCooldown", "SetCooldownFromDurationObject", "SetCooldownFromExpirationTime", "Clear" }) do
            if cooldown[method] then
                hooksecurefunc(cooldown, method, function(_, ...)
                    -- Forward seconds/duration objects unchanged; cooldowns may be secret.
                    local slot = self.slotBySource and self.slotBySource[source]
                    if slot then slot.Cooldown[method](slot.Cooldown, ...) end
                end)
            end
        end
    end
    if source.ApplyPressedStyle then
        hooksecurefunc(source, "ApplyPressedStyle", function(_, down)
            self.pressed[source] = down
            Addon:QueueRefresh()
        end)
    end
    for _, method in ipairs({ "SetButtonState", "ClearPushedStateAfterAOETargeting" }) do
        if source[method] then
            hooksecurefunc(source, method, function(_, state)
                if state ~= "PUSHED" then self.pressed[source] = nil end
                Addon:QueueRefresh()
            end)
        end
    end
    for _, method in ipairs({ "UpdateAction", "UpdateCount", "UpdateUsable", "UpdateState", "RefreshRange" }) do
        if source[method] then hooksecurefunc(source, method, function() Addon:QueueRefresh() end) end
    end
end

function Display:BootstrapCooldown(slot, source, bar)
    local action = source:GetID()
    if not Readable(action) or type(action) ~= "number" or action <= 0 then
        slot.Cooldown:Clear()
    elseif bar and bar.isGamepadPossessBar then
        local start, duration = GetPetActionCooldown(source:GetID())
        slot.Cooldown:SetCooldown(start, duration)
    elseif C_ActionBar and C_ActionBar.GetActionCooldownDuration then
        slot.Cooldown:SetCooldownFromDurationObject(C_ActionBar.GetActionCooldownDuration(action))
    else
        slot.Cooldown:Clear()
    end
end

function Display:UpdateSlot(slot, source, bar, active)
    slot:Show()
    if not source then
        slot.source, slot.action = nil, nil
        slot.Icon:Hide()
        slot.Count:SetText("")
        slot.Prompt:Hide()
        slot.Checked:Hide()
        slot.Pushed:Hide()
        slot.Glow:Hide()
        slot.Cooldown:Clear()
        if slot.Overlay then slot.Overlay:Hide() end
        for _, glyph in ipairs(slot.Modifiers) do glyph:Hide() end
        return
    end
    local action = source.GetID and source:GetID()
    if slot.source ~= source or (Readable(action) and slot.action ~= action) then
        slot.source, slot.action = source, Readable(action) and action or nil
        self:HookSource(source)
        self:BootstrapCooldown(slot, source, bar)
    end
    self.slotBySource[source] = slot
    local icon = source.icon or source.Icon
    if source.SpecialActionIcon and source.SpecialActionIcon:IsShown() then icon = source.SpecialActionIcon end
    CopyTexture(slot.Icon, icon)
    CopyGlyph(slot.Prompt, source.ButtonIcon)
    if source.Count then slot.Count:SetText(source.Count:GetText()) else slot.Count:SetText("") end
    if source.Count then
        local countShown = source.Count:IsShown()
        slot.Count:SetShown(not Readable(countShown) or countShown == true)
    end
    local checked = source.CheckedTexture or (source.GetCheckedTexture and source:GetCheckedTexture())
    local shown = checked and checked:IsShown()
    slot.Checked:SetShown(Readable(shown) and shown == true)
    slot.Pushed:SetShown(self.pressed[source] == true or (source.GetButtonState and source:GetButtonState() == "PUSHED") or false)
    slot.Glow:SetShown(active)
    -- Contextual bars can add a second icon (e.g. a mark over a target portrait).
    if source.IconOverlay and source.IconOverlay:IsShown() then
        if not slot.Overlay then slot.Overlay = Texture(slot.Labels, "ARTWORK"); slot.Overlay:SetAllPoints(slot.Icon) end
        CopyTexture(slot.Overlay, source.IconOverlay)
    elseif slot.Overlay then slot.Overlay:Hide() end
end

function Display:Update(unit)
    self.slotBySource = {}
    local base = unit.actionBars
    local page = unit:GetCurrentPage()
    local selected = {}
    if page <= Constants.GamepadActionBarConstants.NUM_STANDARD_PAGES_PER_GAMEPAD_ACTION_BAR_PAGE_UNIT then
        selected = { base.topBar, base.leftBar, base.rightBar, base.bottomBar }
    end
    local anchors = { unit.TopCenteredAnchor, unit.LeftCenteredAnchor, unit.RightCenteredAnchor, unit.BottomCenteredAnchor }
    for _, bar in ipairs({ base.possessBar, base.stanceBar }) do
        if bar and bar:IsShown() then
            for i, anchor in ipairs(anchors) do if bar:GetParent() == anchor then selected[i] = bar end end
        end
    end
    for _, key in ipairs({ "FriendlyTargetingActionBar", "HostileTargetingActionBar", "ShortcutsActionBar" }) do
        local bar = unit[key]
        if bar and bar:IsShown() then selected[1] = bar end
    end
    local activeBar = unit:GetActiveBar()
    for i = 1, 4 do
        local bar = selected[i]
        local active = bar ~= nil and bar == activeBar
        -- Target/shortcut bars temporarily replace the no-trigger bar.
        if i == 1 and bar ~= base.topBar and bar ~= base.possessBar and bar ~= base.stanceBar then active = true end
        if not bar or (bar.IsActionBarUsable and not bar:IsActionBarUsable()) then active = false end
        for j = 1, 8 do
            local slot = self.slots[(i - 1) * 8 + j]
            self:UpdateSlot(slot, bar and bar.actionButtons[j], bar, active)
            CopyGlyph(slot.Modifiers[1], (i == 2 or i == 4) and unit.LeftIcon or (i == 3 and unit.RightIcon or nil))
            CopyGlyph(slot.Modifiers[2], i == 4 and unit.RightIcon or nil)
        end
    end
    self.pageLabel:SetText(page)
    for i, key in ipairs({ "LeftClassAction", "RightClassAction" }) do
        local source = unit[key]
        local slot = self.slots[32 + i]
        self:UpdateSlot(slot, source and source:IsShown() and source or nil, nil, false)
        local prompt = i == 1 and unit.LeftInputPrompt or unit.RightInputPrompt
        local icons = prompt and prompt.InputIcons
        CopyGlyph(slot.Modifiers[1], icons and icons[1])
        CopyGlyph(slot.Prompt, icons and icons[2])
        slot.Modifiers[2]:Hide()
    end
    for i, key in ipairs({ "LeftShoulderIcon", "RightShoulderIcon" }) do
        local slot = self.slots[34 + i]
        self:UpdateSlot(slot, nil)
        CopyTexture(slot.Icon, unit[key])
    end
end

function Display:SuppressNative(native)
    if self.native ~= native then
        self.native, self.nativeAlpha = native, native:GetAlpha()
    end
    native:SetAlpha(0)
    -- Disable invisible mouse hitboxes only outside combat; gamepad bindings are untouched.
    if not InCombatLockdown() and not self.mouseState then
        self.mouseState = {}
        local function Visit(frame)
            if frame.IsForbidden and frame:IsForbidden() then return end
            if frame.IsMouseEnabled and frame:IsMouseEnabled() then
                self.mouseState[frame] = {
                    clicks = frame:IsMouseClickEnabled(), motion = frame:IsMouseMotionEnabled(),
                }
                frame:EnableMouse(false)
            end
            for _, child in ipairs({ frame:GetChildren() }) do Visit(child) end
        end
        Visit(native)
    end
end

function Display:RestoreNative()
    if self.native then self.native:SetAlpha(self.nativeAlpha) end
    if self.mouseState and not InCombatLockdown() then
        for frame, state in pairs(self.mouseState) do
            frame:SetMouseClickEnabled(state.clicks)
            frame:SetMouseMotionEnabled(state.motion)
        end
        self.mouseState = nil
    end
    self.native, self.nativeAlpha = nil, nil
    if self.root then self.root:Hide() end
end

function Display:Refresh(wanted)
    local native, unit, bars = self:GetBars()
    if not wanted or not native or not native:IsShown() or self:NeedsNativeView(bars, unit) then
        self:RestoreNative()
        return false
    end
    -- Initial setup waits for combat to end; no protected frame is moved or rebound.
    if InCombatLockdown() and not self.native and not self.mouseState then return false end
    if not Addon.Layout:Prepare() then return false end
    self:Create()
    if not self:RefreshGeometry() then self:RestoreNative(); return false end
    self:Update(unit)
    self:SuppressNative(native)
    self.root:Show()
    return true
end
