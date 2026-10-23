local _, Addon = ...
local Display = {}
Addon.Display = Display

local function Readable(value)
    return not issecretvalue or not issecretvalue(value)
end

local function AllReadable(...)
    for i = 1, select("#", ...) do
        if not Readable(select(i, ...)) then return false end
    end
    return true
end

-- Keyboard bar buttons carry the page-adjusted action slot in .action; GetID is only their position.
local function ActionOf(slot, source)
    if not source or not source.GetID then return end
    if slot and slot.keyboardSlot and source == slot.template then
        local action = source.action
        if Readable(action) and type(action) == "number" and action > 0 then return action end
    end
    return source:GetID()
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

local function BindingGlyphs(slot, command)
    local context = C_KeyBindings.GetBindingContextForAction(command)
    local parts = {}
    for _, key in ipairs({ GetBindingKey(command, 1, context) }) do
        if IsBindingForGamePad(key) then
            parts = InputIconTextureSetUtility.GetInputIconNameFromBindingKey(key)
            break
        end
    end
    for i, target in ipairs({ slot.Prompt, slot.Modifiers[1], slot.Modifiers[2] }) do
        local key = i == 1 and parts[#parts] or (i <= #parts and parts[i - 1] or nil)
        local textures = key and InputIconTextureSetUtility.GetActiveInputIconButtonTextures(key)
        local atlas = textures and InputIconTextureSetUtility.GetNormalActiveInputIconButtonTexture(key)
        if atlas then target:SetAtlas(atlas); target:Show() else target:Hide() end
    end
end

local function StockTexture(parent, source, owner, layer)
    local texture = Texture(parent, layer or "ARTWORK")
    CopyTexture(texture, source)
    Addon.Layout:Place(texture, source, owner, owner)
    return texture
end

local function CreateSlot(parent, template)
    -- Visual frames stay unprotected; Input.lua owns the secure click targets.
    local slot = CreateFrame("Button", nil, parent)
    slot.template = template
    -- Hidden keyboard buttons may not have run UpdateHotkeys yet.
    slot.bindingAction = template.bindingAction or (template.buttonType or "ACTIONBUTTON") .. template:GetID()
    slot:RegisterForDrag("LeftButton")
    slot:RegisterForClicks("LeftButtonUp")
    slot:SetScript("OnDragStart", function() Display:PickupSlot(slot) end)
    slot:SetScript("OnReceiveDrag", function() Display:ReceiveSlot(slot) end)
    slot:SetScript("OnClick", function()
        if GetCursorInfo() then Display:ReceiveSlot(slot) end
    end)
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
    local root = CreateFrame("Frame", "ClassicConsoleGamepadUIBar", UIParent)
    root:SetAllPoints(UIParent)
    root:SetFrameStrata("LOW")
    root:SetFrameLevel(MainActionBar:GetFrameLevel())
    self.baseLevel = root:GetFrameLevel()
    self.root, self.slots, self.hooked, self.pressed = root, {}, {}, {}
    for _, button in ipairs(Addon.Layout:GetButtons()) do
        self.slots[#self.slots + 1] = CreateSlot(root, button)
    end
    -- Detached shoulder indicators use the upper row's original button artwork.
    for i = 1, 2 do
        self.slots[36 + i] = CreateSlot(root, self.slots[12 + i].template)
        self.slots[36 + i]:EnableMouse(false)
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
    for i, slot in ipairs(self.slots) do
        local template = slot.template
        local promptScale = Addon.db.promptScale
        slot.Prompt:SetSize(28 * promptScale, 28 * promptScale)
        slot.Prompt:SetPoint("TOPRIGHT", 4 * promptScale, 4 * promptScale)
        local modifierScale = Addon.db.modifierScale
        for index, glyph in ipairs(slot.Modifiers) do
            glyph:SetSize(20 * modifierScale, 20 * modifierScale)
            glyph:SetPoint("TOPLEFT", ((index - 1) * 13 - 4) * modifierScale, 3 * modifierScale)
        end
        -- The stock main row runs right to left; mirror the visible row.
        local placeOn = template
        if i <= 12 and not Addon.Layout.compact then placeOn = self.slots[13 - i].template
        elseif i <= 8 then placeOn = self.slots[9 - i].template end
        if not Addon.Layout:Place(slot, placeOn) then return false end
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
    for i = 1, 2 do
        local shoulder = self.slots[36 + i]
        shoulder:ClearAllPoints()
        -- Left shoulder stays on the left end. Right shoulder sits on the far
        -- right of the visible upper row, not beside the left one.
        local anchorIndex = 13
        if i == 2 then anchorIndex = Addon.Layout.compact and 32 or 36 end
        shoulder:SetPoint("BOTTOMLEFT", self.slots[anchorIndex], "TOPLEFT", 0, Addon.db.contextGap)
        if Addon.Layout.compact then
            local class = self.slots[8 + i]
            class:ClearAllPoints()
            class:SetPoint("BOTTOMLEFT", self.slots[14 + i], "TOPLEFT", 0, Addon.db.contextGap)
        end
    end
    for _, entry in ipairs(self.art) do
        CopyTexture(entry.texture, entry.source)
        if not Addon.Layout:Place(entry.texture, entry.source) then return false end
    end
    Addon.Layout:Place(self.pageLabel, self.pageSource, nil, MainActionBar.ActionBarPageNumber)
    self.pageLabel:SetFont(self.pageSource:GetFont())
    self:AlignCompactChrome()
    self.layoutRevision = Addon.Layout.revision
    return true
end

-- UIParent-space edges. Offsets match Layout:Place / SetBottomLeft.
local function UIBox(region)
    if not region or not region.GetRect then return end
    local x, y, w, h = region:GetRect()
    if not x or not y or not w or not h or w <= 0 or h <= 0 then return end
    local scale = region:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return x * scale, (x + w) * scale, y * scale, h * scale, scale
end

local function MoveX(region, left, bottom)
    if not region or not left or not bottom then return end
    local clear = region.ClearAllPointsBase or region.ClearAllPoints
    local set = region.SetPointBase or region.SetPoint
    clear(region)
    set(region, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
end

function Display:AlignCompactChrome()
    if not Addon.Layout.compact then
        local border = self.art and self.art[1] and self.art[1].texture
        if border then border:SetWidth(border:GetWidth() - (Addon.Layout.cutWidth or 0)) end
        return
    end
    -- Work from one set of measured positions; later moves never re-read rects.
    local boxes = {}
    for i, slot in ipairs(self.slots) do
        local regionLeft, regionRight, bottom = UIBox(slot)
        if regionLeft then boxes[i] = { regionLeft, regionRight, bottom } end
    end
    -- Fixed slot sets: the layout must not depend on which slots happen to be
    -- visible when it is rebuilt (a class action can appear later).
    local function Span(indices)
        local spanLeft, spanRight
        for _, i in ipairs(indices) do
            local box = boxes[i]
            if box then
                spanLeft = spanLeft and math.min(spanLeft, box[1]) or box[1]
                spanRight = spanRight and math.max(spanRight, box[2]) or box[2]
            end
        end
        return spanLeft, spanRight
    end
    local bottomLeft, bottomRight = Span({ 1, 2, 3, 4, 5, 6, 7, 8 })
    local upperLeft, upperRight = Span({ 13, 14, 15, 16, 17, 18, 19, 20, 25, 26, 27, 28, 29, 30, 31, 32 })
    if not bottomLeft or not upperLeft then
        self:PlaceMicroMenuRight()
        return
    end

    -- Classic stack: the L2 half starts above the first bottom slot. Class
    -- actions and shoulder indicators sit on the upper row and move with it.
    local dx = bottomLeft - upperLeft
    for _, range in ipairs({ { 9, 10 }, { 13, 38 } }) do
        for i = range[1], range[2] do
            local box = boxes[i]
            if box then box[1], box[2] = box[1] + dx, box[2] + dx end
        end
    end
    upperLeft, upperRight = upperLeft + dx, upperRight + dx

    -- Bags close the space the micro menu used to fill: right-aligned under
    -- the R2 half, never closer to the bottom row than the gap between halves.
    local bagsLeft, bagsBottom, bagsScale, bagsRight
    if BagsBar and BagsBar:IsShown() then
        local regionLeft, regionRight, bottom, _, scale = UIBox(BagsBar)
        if regionLeft then
            local gap = boxes[20] and boxes[25] and math.max(0, boxes[25][1] - boxes[20][2]) or 0
            bagsLeft = math.max(bottomRight + gap, upperRight - (regionRight - regionLeft))
            bagsRight, bagsBottom, bagsScale = bagsLeft + regionRight - regionLeft, bottom, scale
        end
    end

    local left, right = math.min(bottomLeft, upperLeft), math.max(bottomRight, upperRight, bagsRight or bottomRight)
    local shouldersLeft, shouldersRight = Span({ 37, 38 })
    if shouldersLeft then left, right = math.min(left, shouldersLeft), math.max(right, shouldersRight) end

    local buttonScale = (MainActionBar and MainActionBar:GetEffectiveScale() or UIParent:GetEffectiveScale()) / UIParent:GetEffectiveScale()
    local overlap = 30 * buttonScale
    local pad = 6 * buttonScale
    local leftTex = self.art[2] and self.art[2].texture
    local rightTex = self.art[3] and self.art[3].texture
    local border = self.art[1] and self.art[1].texture
    local leftLeft, leftRight = UIBox(leftTex)
    local rightLeft, rightRight = UIBox(rightTex)
    local borderLeft, borderRight, borderBottom, _, borderScale = UIBox(border)
    local statusPoints = {}
    for _, frame in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        local frameLeft, _, bottom, _, scale = UIBox(frame)
        if frameLeft then statusPoints[frame] = { frameLeft, bottom, scale } end
    end

    local leftShift = leftRight and ((left + overlap) - leftRight) or 0
    local rightShift = rightLeft and ((right - overlap) - rightLeft) or 0
    local outerLeft = (leftLeft or left) + leftShift
    local outerRight = (rightRight or right) + rightShift
    local centerShift = UIParent:GetWidth() / 2 - (outerLeft + outerRight) / 2

    for i, slot in ipairs(self.slots) do
        local box = boxes[i]
        if box then MoveX(slot, box[1] + centerShift, box[3]) end
    end
    local snapshot = {}
    local function Remember(region)
        if not region or snapshot[region] then return end
        local regionLeft, _, bottom = UIBox(region)
        if regionLeft then snapshot[region] = { regionLeft, bottom } end
    end
    for _, entry in ipairs(self.art) do Remember(entry.texture) end
    Remember(self.pageLabel)
    for region, point in pairs(snapshot) do
        local shift = centerShift
        if region == leftTex then shift = centerShift + leftShift
        elseif region == rightTex then shift = centerShift + rightShift end
        MoveX(region, point[1] + shift, point[2])
    end
    if border and borderLeft and borderRight and borderScale and borderScale > 0 then
        local fittedLeft = math.max(borderLeft, left - pad) + centerShift
        local fittedRight = math.min(borderRight, right + pad) + centerShift
        if fittedRight > fittedLeft then
            MoveX(border, fittedLeft, borderBottom)
            border:SetWidth((fittedRight - fittedLeft) / borderScale)
        end
    end

    local span = right - left
    for _, frame in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        local point = statusPoints[frame]
        if point and point[3] > 0 then
            Addon.Layout:SetStatusWidth(frame, span / point[3])
            Addon.Layout:SetBottomLeft(frame, left + centerShift, point[2])
        end
    end
    if bagsLeft and bagsScale and bagsScale > 0 then
        Addon.Layout:SetBottomLeft(BagsBar, (bagsLeft + centerShift) / bagsScale, bagsBottom / bagsScale)
    end
    self:PlaceMicroMenuRight()
end

-- The micro menu otherwise covers the quest tracker or the bottom row.
-- Keep it on the right edge, flush with the bottom unless the user adds a gap.
function Display:PlaceMicroMenuRight()
    local menu = MicroMenuContainer
    if not menu then return end
    local scale = menu:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if not scale or scale <= 0 then return end
    local width, height = menu:GetWidth() * scale, menu:GetHeight() * scale
    if not width or width < 8 or not height or height < 8 then return end
    local margin = Addon.db.menuRight
    local x = UIParent:GetWidth() - width - margin
    if x < margin then x = margin end
    Addon.Layout:SetBottomLeft(menu, x, Addon.db.menuBottom)
end

-- The native action editor ("Bind to Action Bar", "Edit Action Bar") draws its
-- own crossbar from a separate page unit. Its buttons are read here exactly like
-- the main HUD's, so the classic bars stay on screen while the editor is open.
function Display:IsBarEditing()
    return GamepadActionBarEditFrame ~= nil and GamepadActionBarEditFrame:IsShown()
end

local function PageUnitBars(unit)
    if not unit or not unit.actionBars then return end
    local bars = {}
    for _, bar in pairs(unit.actionBars) do bars[#bars + 1] = bar end
    for _, key in ipairs({ "FriendlyTargetingActionBar", "HostileTargetingActionBar", "ShortcutsActionBar" }) do
        if unit[key] then bars[#bars + 1] = unit[key] end
    end
    return bars
end

-- Returns the host frame, the page unit to read, its bars, and whether that is
-- the editor's page unit.
function Display:GetBars()
    if self:IsBarEditing() then
        local bars = PageUnitBars(GamepadActionBarEditFrame.PageUnit)
        if bars then return GamepadActionBarEditFrame, GamepadActionBarEditFrame.PageUnit, bars, true end
    end
    local native = GamepadMainActionBarFrame
    local unit = native and native.PageUnit
    local bars = PageUnitBars(unit)
    if bars then return native, unit, bars, false end
end

-- Edit Mode (HUD layout editing) stays entirely native.
function Display:IsEditing()
    return EditModeManagerFrame ~= nil and EditModeManagerFrame:IsEditModeActive()
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
    return false
end

function Display:GetDragAction(slot)
    if InCombatLockdown() or self.barEditing then return end
    -- Resolve the current page/override before a hardware-driven edit.
    Addon:Refresh()
    if not Addon.classicVisible then return end
    if slot.keyboardSlot then
        -- A spare slot mirroring the keyboard bar: plain action-bar storage, even when empty.
        local action = ActionOf(slot, slot.template)
        if type(action) == "number" and action > 0 then return action, false end
        return
    end
    local source = slot.source
    if not source or not source.GetID then return end
    local action = source:GetID()
    if not Readable(action) or type(action) ~= "number" or action <= 0 then return end
    if source.isGamepadPossessBarButton then
        if not UnitIsCharmed("pet") and C_GamepadUI.IsValidGamepadPossessBarStorageSlotIndex(action) then
            return action, true
        end
    elseif source.GetGamepadPageUnitSlotID and C_GamepadUI.IsValidGamepadActionStorageSlotIndex(action) then
        return action, false
    end
end

function Display:PickupSlot(slot)
    if Settings.GetValue("lockActionBars") and not IsModifiedClick("PICKUPACTION") then return end
    local action, pet = self:GetDragAction(slot)
    if not action then return end
    if pet then
        PickupPetAction(action)
    else
        PickupAction(action, IsAnyIconSelectorPopupFrameShown())
    end
    Addon:QueueRefresh()
end

function Display:ReceiveSlot(slot)
    if not GetCursorInfo() then return end
    local action, pet = self:GetDragAction(slot)
    if not action then return end
    if pet then
        if GetCursorInfo() ~= "petaction" then return end
        PickupPetAction(action)
    else
        PlaceAction(action)
    end
    -- Leave any displaced action on the cursor so it can be placed elsewhere.
    Addon:QueueRefresh()
end

function Display:HookSource(source, bar)
    if self.hooked[source] then return end
    self.hooked[source] = true
    local cooldown = source.cooldown or source.Cooldown
    if cooldown then
        for _, method in ipairs({ "SetCooldown", "SetCooldownFromDurationObject", "SetCooldownFromExpirationTime", "Clear" }) do
            if cooldown[method] then
                hooksecurefunc(cooldown, method, function(_, ...)
                    local slot = self.slotBySource and self.slotBySource[source]
                    if not slot then return end
                    -- Secret times cannot cross into addon execution through
                    -- SetCooldown/SetCooldownFromExpirationTime. Re-read the
                    -- cooldown through the duration object API instead.
                    if not AllReadable(...) then
                        self:MirrorCooldown(slot, source, bar)
                        return
                    end
                    slot.Cooldown[method](slot.Cooldown, ...)
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

function Display:MirrorCooldown(slot, source, bar)
    local action = ActionOf(slot, source)
    if not Readable(action) or type(action) ~= "number" or action <= 0 then
        slot.Cooldown:Clear()
    elseif bar and bar.isGamepadPossessBar then
        local start, duration = GetPetActionCooldown(action)
        if Readable(start) and Readable(duration) then
            slot.Cooldown:SetCooldown(start, duration)
        else
            slot.Cooldown:Clear()
        end
    elseif C_ActionBar and C_ActionBar.GetActionCooldownDuration then
        local durationObject = C_ActionBar.GetActionCooldownDuration(action)
        if durationObject then
            slot.Cooldown:SetCooldownFromDurationObject(durationObject)
        else
            slot.Cooldown:Clear()
        end
    else
        slot.Cooldown:Clear()
    end
end

local function RegionShown(region)
    if not region or not region.IsShown then return false end
    local shown = region:IsShown()
    if not Readable(shown) then return true end
    return shown == true
end

-- The keyboard empty-slot emblem sits in the same window as the action icon.
-- Leaving it up makes every button, filled or not, look like it holds a second icon.
local function PresentActionIcon(slot, icon)
    CopyTexture(slot.Icon, icon)
    slot.SlotArt:Hide()
    slot.Background:Hide()
    if slot.Mask then slot.Icon:RemoveMaskTexture(slot.Mask) end
    slot.Icon:ClearAllPoints()
    slot.Icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 3, -3)
    slot.Icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -3, 3)
    slot.Cooldown:ClearAllPoints()
    slot.Cooldown:SetAllPoints(slot.Icon)
end

local function PresentEmptySlot(slot)
    slot.Icon:Hide()
    slot.SlotArt:Hide()
    slot.Background:Show()
end

-- A stock empty slot plate, so the 12-slot main row has no gaps.
function Display:ShowPlaceholder(slot)
    self:UpdateSlot(slot, nil)
    slot.Background:Show()
end

-- Extended layout: a main-row position without a native gamepad action (the second
-- class action, and the two spare slots) shows the keyboard bar's button at the same
-- position. Its key (9, 0, -, =) uses that action, so the key works on the classic bar.
function Display:ShowKeyboardSlot(slot)
    local source = slot.template
    local action = ActionOf(slot, source)
    if source and type(action) == "number" and action > 0 and C_ActionBar.HasAction(action) then
        self:UpdateSlot(slot, source, nil, false)
        slot.Prompt:Hide()
        for _, glyph in ipairs(slot.Modifiers) do glyph:Hide() end
    else
        self:ShowPlaceholder(slot)
    end
end

function Display:UpdateSlot(slot, source, bar, active)
    slot:Show()
    if slot.Key then slot.Key:SetShown(Addon.db.showKeyboardHints) end
    if not source then
        slot:SetAlpha(1)
        slot.source, slot.action = nil, nil
        slot.Icon:Hide()
        slot.SlotArt:Hide()
        slot.Background:Hide()
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
    slot:SetAlpha(source:GetAlpha())
    local action = ActionOf(slot, source)
    if slot.source ~= source or (Readable(action) and slot.action ~= action) then
        slot.source, slot.action = source, Readable(action) and action or nil
        self:HookSource(source, bar)
        self:MirrorCooldown(slot, source, bar)
    end
    self.slotBySource[source] = slot
    local icon = source.icon or source.Icon
    if source.SpecialActionIcon and RegionShown(source.SpecialActionIcon) then icon = source.SpecialActionIcon end
    if RegionShown(icon) then
        PresentActionIcon(slot, icon)
    else
        PresentEmptySlot(slot)
    end
    CopyGlyph(slot.Prompt, source.ButtonIcon)
    if source.Count then slot.Count:SetText(source.Count:GetText()) else slot.Count:SetText("") end
    if source.Count then
        local countShown = source.Count:IsShown()
        slot.Count:SetShown(not Readable(countShown) or countShown == true)
    end
    local checked = source.CheckedTexture or (source.GetCheckedTexture and source:GetCheckedTexture())
    local shown = checked and checked:IsShown()
    slot.Checked:SetShown(Readable(shown) and shown == true)
    slot.Pushed:SetShown((slot.inputButton and slot.inputButton:GetAttribute("cgppressed") == true) or self.pressed[source] == true
        or (source.GetButtonState and source:GetButtonState() == "PUSHED") or false)
    slot.Glow:SetShown((active and Addon.db.highlightActive) or slot.bindingHighlight == true)
    -- Contextual bars can add a second icon (e.g. a mark over a target portrait).
    if source.IconOverlay and source.IconOverlay:IsShown() then
        if not slot.Overlay then slot.Overlay = Texture(slot.Labels, "ARTWORK"); slot.Overlay:SetAllPoints(slot.Icon) end
        CopyTexture(slot.Overlay, source.IconOverlay)
    elseif slot.Overlay then slot.Overlay:Hide() end
end

function Display:Update(unit)
    self.slotBySource = {}
    for i, key in ipairs({ "LeftShoulderIcon", "RightShoulderIcon" }) do
        local slot = self.slots[36 + i]
        self:UpdateSlot(slot, nil)
        CopyTexture(slot.Icon, unit[key])
        BindingGlyphs(slot, i == 1 and "GAMEPADLEFTTARGETMODIFIER" or "GAMEPADRIGHTTARGETMODIFIER")
        local highlight = i == 1 and unit.LeftShoulderHighlight or unit.RightShoulderHighlight
        slot.Glow:SetShown(Addon.db.highlightActive and highlight and highlight:IsShown() or false)
    end
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
    local function PaintGroup(index, firstSlot, firstButton, count)
        local bar = selected[index]
        local active = bar ~= nil and bar == activeBar
        if not bar or (bar.IsActionBarUsable and not bar:IsActionBarUsable()) then active = false end
        for j = 0, count - 1 do
            local slot = self.slots[firstSlot + j]
            self:UpdateSlot(slot, bar and bar.actionButtons[firstButton + j], bar, active)
            if bar and bar == unit.ShortcutsActionBar then
                CopyTexture(slot.Modifiers[1], self.slots[37].Prompt)
                CopyTexture(slot.Modifiers[2], self.slots[38].Prompt)
            elseif bar and (bar == unit.FriendlyTargetingActionBar or bar == unit.HostileTargetingActionBar) then
                local flag = bar == unit.FriendlyTargetingActionBar and GamepadTargetingState.FRIENDLY or GamepadTargetingState.HOSTILE
                local shoulder = GamepadMode.GetLeftTargetModifierFlag() == flag and 37 or 38
                CopyTexture(slot.Modifiers[1], self.slots[shoulder].Prompt)
                slot.Modifiers[2]:Hide()
            else
                CopyGlyph(slot.Modifiers[1], (index == 2 or index == 4) and unit.LeftIcon or (index == 3 and unit.RightIcon or nil))
                CopyGlyph(slot.Modifiers[2], index == 4 and unit.RightIcon or nil)
            end
        end
    end
    local compact = Addon.Layout.compact
    local mainIndex = compact and selected[4] and activeBar == selected[4] and 4 or 1
    local function PaintRow(index, firstSlot)
        PaintGroup(index, firstSlot, 5, 4)
        PaintGroup(index, firstSlot + 4, 1, 4)
    end
    PaintRow(mainIndex, 1)
    PaintRow(2, 13)
    PaintRow(3, 25)
    if compact then
        for _, first in ipairs({ 21, 33 }) do
            for i = first, first + 3 do
                self:UpdateSlot(self.slots[i], nil)
                self.slots[i]:Hide()
            end
        end
    else
        -- Split the combined layer across the extended trigger sections.
        PaintGroup(4, 21, 5, 4)
        PaintGroup(4, 33, 1, 4)
    end
    for i = 11, 12 do
        local slot = self.slots[i]
        slot.keyboardSlot = not compact
        if compact then slot:Hide() else self:ShowKeyboardSlot(slot) end
    end
    self.pageLabel:SetText(page)
    for i, key in ipairs({ "LeftClassAction", "RightClassAction" }) do
        local source = unit[key]
        local slot = self.slots[8 + i]
        local usable = source and source:IsShown() and source or nil
        self:UpdateSlot(slot, usable, nil, false)
        slot.keyboardSlot = not usable and not compact
        if not usable then
            -- Compact class slots float above the row, so an empty one is hidden.
            -- In the 12-slot row it mirrors the keyboard bar's button at that position.
            if compact then slot:Hide() else self:ShowKeyboardSlot(slot) end
        else
            local prompt = i == 1 and unit.LeftInputPrompt or unit.RightInputPrompt
            local icons = prompt and prompt.InputIcons
            CopyGlyph(slot.Modifiers[1], icons and icons[1])
            CopyGlyph(slot.Prompt, icons and icons[2])
            slot.Modifiers[2]:Hide()
        end
    end
end

-- Fade native frames instead of hiding them: their own code keeps running and
-- no protected visibility is changed from addon code.
function Display:SuppressNative(frames)
    if not self.suppressed then Addon:Trace("Display:SuppressNative") end
    self.suppressed = self.suppressed or {}
    local keep = {}
    for _, frame in ipairs(frames) do
        keep[frame] = true
        if self.suppressed[frame] == nil then self.suppressed[frame] = frame:GetAlpha() end
        frame:SetAlpha(0)
    end
    for frame, alpha in pairs(self.suppressed) do
        if not keep[frame] then frame:SetAlpha(alpha); self.suppressed[frame] = nil end
    end
    self.native = next(self.suppressed) ~= nil or nil
end

function Display:RestoreNative()
    if self.suppressed then Addon:Trace("Display:RestoreNative") end
    self:HideTemplates()
    pcall(Addon.Input.Refresh, Addon.Input, false)
    for frame, alpha in pairs(self.suppressed or {}) do frame:SetAlpha(alpha) end
    self.suppressed, self.native, self.barEditing = nil, nil, nil
    if self.root then self:SetLayer(false); self.root:Hide() end
end

local function SetStrata(frame, strata)
    frame:SetFrameStrata(strata)
    for _, child in ipairs({ frame:GetChildren() }) do SetStrata(child, strata) end
end

-- The editor dims the screen with a HIGH-strata background. Draw above it while
-- the editor is open, and return to the ordinary layer afterwards.
function Display:SetLayer(editing)
    local root = self.root
    if not root or self.layerEditing == editing then return end
    self.layerEditing = editing
    if editing then
        SetStrata(root, GamepadActionBarEditFrame:GetFrameStrata())
        root:SetFrameLevel(GamepadActionBarEditFrame:GetFrameLevel() + 1)
    else
        SetStrata(root, "LOW")
        root:SetFrameLevel(self.baseLevel or root:GetFrameLevel())
    end
end

-- Edit Mode bars override Show/Hide in Lua and record isShownExternal;
-- the C methods measure them without touching that saved visibility state.
local function Reveal(store, region)
    if not region or (region.IsShownBase or region.IsShown)(region) then return end
    store[region] = region:GetAlpha()
    region:SetAlpha(0);
    (region.ShowBase or region.Show)(region)
end

function Display:RevealTemplates()
    if InCombatLockdown() or self.revealed then return end
    Addon:Trace("Display:RevealTemplates")
    local store = {}
    self.revealed = store
    Reveal(store, MainActionBar)
    Reveal(store, MultiBarBottomLeft)
    Reveal(store, MultiBarBottomRight)
    if MainActionBar then
        local caps = MainActionBar.EndCaps
        local page = MainActionBar.ActionBarPageNumber
        Reveal(store, MainActionBar.BorderArt)
        Reveal(store, caps)
        -- Showing the bar re-hides the caps while the gamepad UI is active.
        Reveal(store, caps)
        Reveal(store, caps and caps.LeftEndCap)
        Reveal(store, caps and caps.LeftEndCap and caps.LeftEndCap.Texture)
        Reveal(store, caps and caps.RightEndCap)
        Reveal(store, caps and caps.RightEndCap and caps.RightEndCap.Texture)
        Reveal(store, page)
        Reveal(store, page and page.Text)
        Reveal(store, page and page.UpButton)
        Reveal(store, page and page.DownButton)
        Reveal(store, page and page.UpButton and page.UpButton:GetNormalTexture())
        Reveal(store, page and page.DownButton and page.DownButton:GetNormalTexture())
    end
end

function Display:HideTemplates()
    for region, alpha in pairs(self.revealed or {}) do
        region:SetAlpha(alpha);
        (region.HideBase or region.Hide)(region)
    end
    self.revealed = nil
end

function Display:Refresh(wanted)
    local native, unit, bars, editing = self:GetBars()
    if not wanted then self.reason = "disabled"; self:RestoreNative(); return false end
    if not native then self.reason = "native missing"; self:RestoreNative(); return false end
    if self:NeedsNativeView(bars, unit) then self.reason = "edit mode or flyout"; self:RestoreNative(); return false end
    -- Initial setup and secure input geometry wait for combat to end.
    if InCombatLockdown() and not self.native and not self.mouseState then
        self.reason = "combat"
        return false
    end
    local needsGeometry = not self.root or Addon.Layout.dirty
        or self.layoutRevision ~= Addon.Layout.revision
    if needsGeometry then self:RevealTemplates() end
    local prepared = Addon.Layout:Prepare()
    if not prepared then self:HideTemplates(); self.reason = "layout"; return false end
    self:Create()
    local geometryOK = self:RefreshGeometry()
    self:HideTemplates()
    if not geometryOK then self.reason = "geometry"; self:RestoreNative(); return false end
    self.reason = editing and "shown (action editor)" or "shown"
    self.barEditing = editing
    self:Update(unit)
    -- The visual HUD must not depend on the optional secure click layer.
    if editing then
        -- The editor's crossbar and the main HUD are both replaced by the classic bars.
        -- Its page tracker (page number and the button hint for changing pages) stays.
        local faded = { GamepadMainActionBarFrame }
        for _, key in ipairs({ "TopCenteredAnchor", "LeftCenteredAnchor", "RightCenteredAnchor",
            "BottomCenteredAnchor", "LeftIcon", "RightIcon", "CenteredIcons" }) do
            if unit[key] then faded[#faded + 1] = unit[key] end
        end
        self:SuppressNative(faded)
    else
        self:SuppressNative({ native })
    end
    self:SetLayer(editing)
    self.root:Show()
    if Addon.Input.disabled then return true end
    if editing then
        -- Slots only mirror the editor; its own input groups own every button.
        pcall(Addon.Input.Refresh, Addon.Input, false)
        return true
    end
    local ok, enabled = pcall(Addon.Input.Refresh, Addon.Input, true, native, unit, bars)
    if not ok then
        Addon.Input:Disable(enabled)
        Addon:Note("Input:Refresh", enabled)
    end
    return true
end
