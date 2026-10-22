local _, Addon = ...
local Display = {}
Addon.Display = Display

local SIZE, GAP, GROUP_GAP = 42, 3, 20
local GROUP_WIDTH = 8 * (SIZE + GAP) - GAP
local WIDTH = GROUP_WIDTH * 2 + GROUP_GAP
local HEIGHT = 152

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
        target:SetTexCoord(source:GetTexCoord())
    end
    target:SetVertexColor(source:GetVertexColor())
    target:SetAlpha(source:GetAlpha())
    if source.GetDesaturation then target:SetDesaturation(source:GetDesaturation()) end
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

local function Edge(parent, r, g, b)
    local edge = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    edge:SetPoint("TOPLEFT", -2, 2)
    edge:SetPoint("BOTTOMRIGHT", 2, -2)
    edge:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
    edge:SetBackdropBorderColor(r, g, b, 1)
    return edge
end

local function CreateSlot(parent, x, y)
    -- These are display frames, never substitute action buttons or binding owners.
    local slot = CreateFrame("Frame", nil, parent)
    slot:SetSize(SIZE, SIZE)
    slot:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, y)
    slot.Icon = Texture(slot, "BACKGROUND", "Interface\\Buttons\\UI-Quickslot")
    slot.Icon:SetPoint("TOPLEFT", 3, -3)
    slot.Icon:SetPoint("BOTTOMRIGHT", -3, 3)
    slot.Border = Texture(slot, "OVERLAY", "Interface\\Buttons\\UI-Quickslot2")
    slot.Border:SetAllPoints()
    slot.Cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
    slot.Cooldown:SetAllPoints(slot.Icon)
    slot.Cooldown:SetDrawEdge(false)
    slot.Cooldown:SetHideCountdownNumbers(false)
    slot.Cooldown:SetFrameLevel(slot:GetFrameLevel() + 1)
    local labels = CreateFrame("Frame", nil, slot)
    labels:SetAllPoints()
    labels:SetFrameLevel(slot:GetFrameLevel() + 3)
    slot.Labels = labels
    slot.Prompt = Texture(labels, "OVERLAY")
    slot.Prompt:SetSize(18, 18)
    slot.Prompt:SetPoint("TOPRIGHT", 2, 3)
    slot.Modifiers = {}
    for i = 1, 2 do
        local glyph = Texture(labels, "OVERLAY")
        glyph:SetSize(13, 13)
        glyph:SetPoint("TOPLEFT", (i - 1) * 12 - 1, 1)
        slot.Modifiers[i] = glyph
    end
    slot.Count = labels:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    slot.Count:SetPoint("BOTTOMRIGHT", -3, 3)
    slot.Checked = Texture(labels, "ARTWORK", "Interface\\Buttons\\CheckButtonHilight")
    slot.Checked:SetAllPoints()
    slot.Checked:SetBlendMode("ADD")
    slot.Pushed = Texture(labels, "ARTWORK", "Interface\\Buttons\\UI-Quickslot-Depress")
    slot.Pushed:SetAllPoints()
    slot.Glow = Edge(labels, 1, 0.78, 0.2)
    slot.Glow:Hide()
    return slot
end

function Display:Create()
    if self.root then return end
    local root = CreateFrame("Frame", "ClassicGamepadBar", UIParent, "BackdropTemplate")
    root:SetSize(WIDTH + 28, HEIGHT)
    root:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 28)
    root:SetFrameStrata("LOW")
    root:SetFrameLevel(55)
    root:SetClampedToScreen(true)
    root:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 20,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    root:SetBackdropColor(0.10, 0.075, 0.045, 0.96)
    local left = Texture(root, "OVERLAY")
    left:SetAtlas("ui-hud-actionbar-gryphon-left")
    left:SetSize(154, 95)
    left:SetPoint("BOTTOMRIGHT", root, "BOTTOMLEFT", 30, -10)
    local right = Texture(root, "OVERLAY")
    right:SetAtlas("ui-hud-actionbar-gryphon-right")
    right:SetSize(154, 95)
    right:SetPoint("BOTTOMLEFT", root, "BOTTOMRIGHT", -30, -10)
    self.root, self.groups, self.hooked, self.pressed = root, {}, {}, {}
    -- No trigger / LT below, RT / LT+RT above: two familiar horizontal bars.
    for i = 1, 4 do
        local group = CreateFrame("Frame", nil, root)
        group:SetSize(GROUP_WIDTH, SIZE)
        group:SetPoint("BOTTOMLEFT", 14 + ((i - 1) % 2) * (GROUP_WIDTH + GROUP_GAP),
            i <= 2 and 25 or 91)
        group.Title = group:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        group.Title:SetPoint("BOTTOMLEFT", group, "TOPLEFT", 2, 3)
        group.Title:SetText(({ GAMEPAD_LABEL or "Gamepad", "LT", "RT", "LT + RT" })[i])
        group.Active = Edge(group, 1, 0.72, 0.15)
        group.Active:Hide()
        group.slots = {}
        for j = 1, 8 do group.slots[j] = CreateSlot(group, (j - 1) * (SIZE + GAP), 0) end
        self.groups[i] = group
    end
    self.pageLabel = root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.pageLabel:SetPoint("BOTTOM", 0, 8)
    self.shoulders = {}
    for i = 1, 2 do
        local glyph = Texture(root, "OVERLAY")
        glyph:SetSize(24, 24)
        glyph:SetPoint("BOTTOM", i == 1 and -84 or 84, 2)
        self.shoulders[i] = glyph
    end
    self.extra = {}
    for i = 1, 2 do
        self.extra[i] = CreateSlot(root, i == 1 and -56 or WIDTH + 42, 50)
        self.extra[i]:Hide()
    end
    root:Hide()
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
    if not source then slot:Hide(); return end
    slot:Show()
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

function Display:Update(unit, bars)
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
    for i, group in ipairs(self.groups) do
        local bar = selected[i]
        local active = bar ~= nil and bar == activeBar
        -- Target/shortcut bars temporarily replace the no-trigger bar.
        if i == 1 and bar ~= base.topBar and bar ~= base.possessBar and bar ~= base.stanceBar then active = true end
        if not bar or (bar.IsActionBarUsable and not bar:IsActionBarUsable()) then active = false end
        group.Active:SetShown(active)
        group.Title:SetTextColor(active and 1 or 0.7, active and 0.82 or 0.65, active and 0.3 or 0.52)
        for j, slot in ipairs(group.slots) do
            -- Show all four layers even when native Compact Mode hides the inactive ones.
            self:UpdateSlot(slot, bar and bar.actionButtons[j], bar, active)
            CopyGlyph(slot.Modifiers[1], (i == 2 or i == 4) and unit.LeftIcon or (i == 3 and unit.RightIcon or nil))
            CopyGlyph(slot.Modifiers[2], i == 4 and unit.RightIcon or nil)
        end
    end
    self.pageLabel:SetText((PAGE or "Page") .. " " .. page)
    CopyTexture(self.shoulders[1], unit.LeftShoulderIcon)
    CopyTexture(self.shoulders[2], unit.RightShoulderIcon)
    for i, key in ipairs({ "LeftClassAction", "RightClassAction" }) do
        local source = unit[key]
        self:UpdateSlot(self.extra[i], source and source:IsShown() and source or nil, nil, false)
        local prompt = i == 1 and unit.LeftInputPrompt or unit.RightInputPrompt
        local icons = prompt and prompt.InputIcons
        CopyGlyph(self.extra[i].Modifiers[1], icons and icons[1])
        CopyGlyph(self.extra[i].Prompt, icons and icons[2])
        self.extra[i].Modifiers[2]:Hide()
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
    self:Create()
    self.root:SetScale(math.min(Addon.db.scale, (UIParent:GetWidth() - 32) / (WIDTH + 250)))
    self:Update(unit, bars)
    self:SuppressNative(native)
    self.root:Show()
    return true
end
