local _, Addon = ...
local Display = {}
Addon.Display = Display

local issecret = issecretvalue
local function Readable(value)
    return not issecret or not issecret(value)
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
    if slot and slot.keyboardSlot and (source == slot.template or source == slot.keyboardSource) then
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

local function HideTexture(target)
    if not target then return end
    local c = target._cgpTex
    if c then
        if c.shown == false then return end
        c.shown = false
    else
        target._cgpTex = { shown = false }
    end
    target:Hide()
end

local function SetCachedAtlas(target, atlas)
    local c = target._cgpTex
    if not c then c = {}; target._cgpTex = c end
    if atlas then
        if c.atlas ~= atlas or c.tex ~= nil then
            c.atlas, c.tex = atlas, nil
            target:SetAtlas(atlas)
        end
        if c.shown ~= true then
            c.shown = true
            target:Show()
        end
    else
        if c.shown ~= false then
            c.shown = false
            target:Hide()
        end
    end
end

local function SetCachedVertexColor(target, r, g, b)
    local c = target._cgpTex
    if c then
        if c.vr == r and c.vg == g and c.vb == b and c.va == 1 then return end
        c.vr, c.vg, c.vb, c.va = r, g, b, 1
    end
    target:SetVertexColor(r, g, b)
end

local function CopyTexture(target, source)
    local c = target._cgpTex
    if not c then c = {}; target._cgpTex = c end
    if not source then
        if c.shown ~= false then
            c.shown, c.src = false, nil
            target:Hide()
        end
        return
    end
    local sameSource = (c.src == source)
    local texChanged = false
    local atlas = source.GetAtlas and source:GetAtlas()
    if Readable(atlas) and atlas then
        if c.atlas ~= atlas or c.tex ~= nil then
            c.atlas, c.tex = atlas, nil
            target:SetAtlas(atlas)
            texChanged = true
        end
    else
        local tex = source:GetTexture()
        if not Readable(tex) then
            c.atlas, c.tex = nil, nil
            target:SetTexture(tex)
            texChanged = true
        elseif c.tex ~= tex or c.atlas ~= nil then
            c.atlas, c.tex = nil, tex
            target:SetTexture(tex)
            texChanged = true
        end
    end
    if not sameSource or texChanged or c.ulx == nil then
        local ulx, uly, llx, lly, urx, ury, lrx, lry = source:GetTexCoord()
        if not (Readable(ulx) and Readable(uly) and Readable(llx) and Readable(lly)
            and Readable(urx) and Readable(ury) and Readable(lrx) and Readable(lry)) then
            c.ulx = nil
            target:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
        elseif c.ulx ~= ulx or c.uly ~= uly or c.llx ~= llx or c.lly ~= lly
            or c.urx ~= urx or c.ury ~= ury or c.lrx ~= lrx or c.lry ~= lry then
            c.ulx, c.uly, c.llx, c.lly, c.urx, c.ury, c.lrx, c.lry = ulx, uly, llx, lly, urx, ury, lrx, lry
            target:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
        end
        if target.SetBlendMode and source.GetBlendMode then
            local blend = source:GetBlendMode()
            if not Readable(blend) then
                c.blend = nil
                target:SetBlendMode(blend)
            elseif c.blend ~= blend then
                c.blend = blend
                target:SetBlendMode(blend)
            end
        end
    end
    if target.SetVertexColor and source.GetVertexColor then
        local r, g, b, a = source:GetVertexColor()
        if not (Readable(r) and Readable(g) and Readable(b) and Readable(a)) then
            c.vr = nil
            target:SetVertexColor(r, g, b, a)
        elseif c.vr ~= r or c.vg ~= g or c.vb ~= b or c.va ~= a then
            c.vr, c.vg, c.vb, c.va = r, g, b, a
            target:SetVertexColor(r, g, b, a)
        end
    end
    local alpha = source:GetAlpha()
    if not Readable(alpha) then
        c.alpha = nil
        target:SetAlpha(alpha)
    elseif c.alpha ~= alpha then
        c.alpha = alpha
        target:SetAlpha(alpha)
    end
    if target.SetDesaturation and source.GetDesaturation then
        local desat = source:GetDesaturation()
        if not Readable(desat) then
            c.desat = nil
            target:SetDesaturation(desat)
        elseif c.desat ~= desat then
            c.desat = desat
            target:SetDesaturation(desat)
        end
    end
    c.src = source
    if c.shown ~= true then
        c.shown = true
        target:Show()
    end
end

-- The pictures a prompt can show instead of its normal one, the strongest first. A constant: CopyGlyph runs for every slot
-- on every refresh, and the list used to be made again at each call.
local GLYPH_STATES = { "PressedTexture", "ActiveTexture", "HoverTexture", "DisabledTexture" }

local function CopyGlyph(target, prompt)
    if not prompt then HideTexture(target); return end
    local source = prompt.NormalTexture
    for i = 1, #GLYPH_STATES do
        local candidate = prompt[GLYPH_STATES[i]]
        if candidate and candidate:IsShown() then source = candidate; break end
    end
    if not source then HideTexture(target); return end
    local c = target._cgpTex
    if c and c.src == source and c.shown == true and c.atlas ~= nil then
        local atlas = source.GetAtlas and source:GetAtlas()
        local alpha = source:GetAlpha()
        if Readable(atlas) and atlas == c.atlas and Readable(alpha) and alpha == c.alpha then
            return
        end
    end
    CopyTexture(target, source)
end

local bindingGlyphCache = {}
function Display:InvalidateBindingGlyphs()
    wipe(bindingGlyphCache)
end

local function ResolveBindingGlyphs(command)
    local cached = bindingGlyphCache[command]
    if cached then return cached end
    local context = C_KeyBindings.GetBindingContextForAction(command)
    local parts
    local n = select("#", GetBindingKey(command, 1, context))
    if n > 0 then
        local keys = { GetBindingKey(command, 1, context) }
        for i = 1, #keys do
            local key = keys[i]
            if IsBindingForGamePad(key) then
                parts = InputIconTextureSetUtility.GetInputIconNameFromBindingKey(key)
                break
            end
        end
    end
    cached = {}
    if parts and #parts > 0 then
        for i = 1, 3 do
            local key = i == 1 and parts[#parts] or (i <= #parts and parts[i - 1] or nil)
            local textures = key and InputIconTextureSetUtility.GetActiveInputIconButtonTextures(key)
            cached[i] = (textures and InputIconTextureSetUtility.GetNormalActiveInputIconButtonTexture(key)) or false
        end
    else
        cached[1], cached[2], cached[3] = false, false, false
    end
    bindingGlyphCache[command] = cached
    return cached
end

local function BindingGlyphs(slot, command)
    local atlases = ResolveBindingGlyphs(command)
    SetCachedAtlas(slot.Prompt, atlases[1] or nil)
    SetCachedAtlas(slot.Modifiers[1], atlases[2] or nil)
    SetCachedAtlas(slot.Modifiers[2], atlases[3] or nil)
end

-- The glyph of the key a bar slot really has, where the player moved the eight buttons (ButtonBindings.lua): the game draws
-- the same glyph on a slot whatever key it has. The game's own glyph stays for a slot that has its own key.
local function BindingPrompt(slot, index)
    local key = index and Addon.ButtonBindings and Addon.ButtonBindings:CustomKey(index)
    if not key then return end
    local util = InputIconTextureSetUtility
    local atlas = util and util.GetNormalActiveInputIconButtonTexture and util.GetNormalActiveInputIconButtonTexture(key)
    if atlas then SetCachedAtlas(slot.Prompt, atlas) end
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
    slot.FlyoutArrow = labels:CreateTexture(nil, "OVERLAY", nil, 2)
    slot.FlyoutArrow:SetSize(15, 6)
    slot.FlyoutArrow:SetPoint("TOP", slot, "TOP", 0, 5)
    if slot.FlyoutArrow.SetAtlas then slot.FlyoutArrow:SetAtlas("UI-HUD-ActionBar-Flyout", false) end
    slot.FlyoutArrow:Hide()
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
    -- The stock page number and its arrows are not drawn: the classic bars have no page to switch.
    root:Hide()
end

-- The stock button a slot is drawn on. The stock main row runs right to left, so it is mirrored. In the 12-slot layout
-- the stock bars split the buttons used with both triggers: 21-24 follow the L2 row and 33-36 close the R2 row. With
-- group set, all eight sit together between the L2 row (13-20) and the R2 row (25-32).
function Display.PlacementTemplate(slots, i, compact, group)
    if i <= 12 and not compact then return slots[13 - i].template end
    if i <= 8 then return slots[9 - i].template end
    if group and not compact then
        if i >= 33 and i <= 36 then return slots[i - 8].template end
        if i >= 25 and i <= 32 then return slots[i + 4].template end
    end
    return slots[i].template
end

function Display:RefreshGeometry()
    if self.layoutRevision == Addon.Layout.revision then return true end
    for i, slot in ipairs(self.slots) do
        local template = slot.template
        -- Placed at the stock size first (Layout:Place works in UIParent points); ApplyScale sizes the bars afterwards.
        slot:SetScale(1)
        local promptScale = Addon.db.promptScale
        slot.Prompt:SetSize(28 * promptScale, 28 * promptScale)
        slot.Prompt:SetPoint("TOPRIGHT", 4 * promptScale, 4 * promptScale)
        slot.promptLow = nil
        local modifierScale = Addon.db.modifierScale
        for index, glyph in ipairs(slot.Modifiers) do
            glyph:SetSize(20 * modifierScale, 20 * modifierScale)
            glyph:SetPoint("TOPLEFT", ((index - 1) * 13 - 4) * modifierScale, 3 * modifierScale)
        end
        local placeOn = Display.PlacementTemplate(self.slots, i, Addon.Layout.compact, Addon.db.groupBoth)
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
        slot.Background._cgpTex, slot.SlotArt._cgpTex = nil, nil
        slot._cgpShoulderInit = nil
        Addon.Layout:Place(slot.Icon, template.icon, template, template)
        Addon.Layout:Place(slot.Cooldown, template.cooldown, template, template)
        slot.iconAnchored = nil
        if slot.Mask then
            CopyTexture(slot.Mask, template.IconMask)
            Addon.Layout:Place(slot.Mask, template.IconMask, template, template)
        end
        if template.Count then slot.Count:SetFont(template.Count:GetFont()) end
        SetCachedVertexColor(slot.Glow, 1, 0.8, 0.25)
    end
    for i = 1, 2 do
        local shoulder = self.slots[36 + i]
        shoulder:ClearAllPoints()
        -- Left shoulder stays on the left end. Right shoulder sits on the far
        -- right of the visible upper row, not beside the left one.
        local anchorIndex = 13
        if i == 2 then anchorIndex = (Addon.Layout.compact or Addon.db.groupBoth) and 32 or 36 end
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
    self:AlignCompactChrome()
    -- After the art is copied (that shows it) and placed: a hidden gryphon still sets where the bars are centered.
    self:ApplyCaps()
    -- The size the player chose for the bars (barScale), before they are moved to the player's place.
    self:ApplyScale(Addon.db.barScale or 1)
    -- The player's own place for the bars (dragged in Edit Mode, EditMode.lua), on top of the computed one.
    self.offsetX, self.offsetY = 0, 0
    self:Translate(self:GetOffset())
    -- An extra: a failure here must not switch the classic bars off.
    pcall(self.PlaceTotemBar, self)
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

-- left and bottom are UIParent points; a region drawn at another scale (a slot under barScale) takes its own units.
local function MoveX(region, left, bottom)
    if not region or not left or not bottom then return end
    local ratio = region.GetEffectiveScale and region:GetEffectiveScale() / UIParent:GetEffectiveScale() or 1
    if not ratio or ratio <= 0 then ratio = 1 end
    local clear = region.ClearAllPointsBase or region.ClearAllPoints
    local set = region.SetPointBase or region.SetPoint
    clear(region)
    set(region, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", left / ratio, bottom / ratio)
end

-- The game's default gamepad status-bar position is at the bottom of the screen, underneath the classic buttons.
-- Leave custom Edit Mode positions alone, and move a default bar only far enough to clear visible controls.
function Display:AvoidDefaultStatusOverlap()
    if Addon.db.placeStatusBars ~= false or InCombatLockdown() then return end
    local obstacles = {}
    local function Add(region)
        local left, right, bottom, height = UIBox(region)
        if left then obstacles[#obstacles + 1] = { left, right, bottom, bottom + height } end
    end
    -- Treat the classic bar stack (slots and art) as one solid envelope so a status bar cannot wedge
    -- into the gap between the lower and upper action rows or overlap the end caps.
    local barLeft, barRight, barBottom, barTop
    local function IncludeBar(region)
        local left, right, bottom, height = UIBox(region)
        if left then
            barLeft = barLeft and math.min(barLeft, left) or left
            barRight = barRight and math.max(barRight, right) or right
            barBottom = barBottom and math.min(barBottom, bottom) or bottom
            barTop = barTop and math.max(barTop, bottom + height) or (bottom + height)
        end
    end
    for i, slot in ipairs(self.slots or {}) do
        if i <= 8 or slot:IsShown() then IncludeBar(slot) end
    end
    for _, entry in ipairs(self.art or {}) do
        local tex = entry.texture
        if tex and tex:IsShown() and (tex.GetAlpha == nil or tex:GetAlpha() > 0) then IncludeBar(tex) end
    end
    if barLeft then obstacles[#obstacles + 1] = { barLeft, barRight, barBottom, barTop } end
    for _, frame in pairs({ BagsBar, MicroMenuContainer }) do
        if frame:IsShown() and frame:GetAlpha() > 0 then Add(frame) end
    end
    -- Process Main (bottom) before Secondary (above Main) to preserve Blizzard's native stacking order,
    -- and iterate with an explicit count so a nil frame never stops the loop.
    local bars = { [1] = MainStatusTrackingBarContainer, [2] = SecondaryStatusTrackingBarContainer }
    local function Default(frame)
        return frame and frame.IsInDefaultPosition and frame:IsInDefaultPosition()
    end
    for i = 1, 2 do
        local frame = bars[i]
        if frame and frame:IsShown() and not Default(frame) then Add(frame) end
    end
    local moved = self.defaultStatusMoved or {}
    self.defaultStatusMoved = moved
    local screenHeight = UIParent and UIParent.GetHeight and UIParent:GetHeight()
    for i = 1, 2 do
        local frame = bars[i]
        if frame and frame:IsShown() and Default(frame) then
            local left, right, bottom, height, scale = UIBox(frame)
            if left and scale > 0 then
                local base = moved[frame]
                local baseLeft, baseBottom = base and base[1] or left, base and base[2] or bottom
                local baseRight = baseLeft + (right - left)
                local target, changed = baseBottom, true
                while changed do
                    changed = false
                    for _, box in ipairs(obstacles) do
                        if baseLeft < box[2] and baseRight > box[1] and target < box[4] + 4 and target + height > box[3] - 4 then
                            target, changed = box[4] + 4, true
                        end
                    end
                end
                if screenHeight and screenHeight > height and target + height > screenHeight then
                    target = screenHeight - height
                end
                if target > baseBottom + 0.5 then
                    if not base then moved[frame] = { baseLeft, baseBottom } end
                    if math.abs(target - bottom) > 0.5 then
                        Addon.Layout:SetBottomLeft(frame, baseLeft / scale, target / scale)
                    end
                elseif base then
                    moved[frame] = nil
                    local snapshot = Addon.Layout.originals and Addon.Layout.originals[frame]
                    if not (snapshot and Addon.Layout.Apply and Addon.Layout.Apply(frame, snapshot)) then
                        Addon.Layout:SetBottomLeft(frame, baseLeft / scale, baseBottom / scale)
                    end
                    target = baseBottom
                end
                obstacles[#obstacles + 1] = { baseLeft, baseRight, target, target + height }
            end
        end
    end
end

function Display:AlignCompactChrome()
    if not Addon.Layout.compact then
        local border = self.art and self.art[1] and self.art[1].texture
        if border then border:SetWidth(border:GetWidth() - (Addon.Layout.cutWidth or 0)) end
        if Addon.db.hideMenu == true then self:PlaceMicroMenuRight() end
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
    -- Bags kept by the layout (placeBags off) stay where Edit Mode puts them.
    if BagsBar and BagsBar:IsShown() and not Addon.Layout:Keeps(BagsBar) then
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
        if frameLeft and not Addon.Layout:Keeps(frame) then statusPoints[frame] = { frameLeft, bottom, scale } end
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
            Addon.Layout:SetBottomLeft(frame, (left + centerShift) / point[3], point[2] / point[3])
        end
    end
    if bagsLeft and bagsScale and bagsScale > 0 then
        Addon.Layout:SetBottomLeft(BagsBar, (bagsLeft + centerShift) / bagsScale, bagsBottom / bagsScale)
    end
    self:PlaceMicroMenuRight()
end

-- The slots the totem bar has to clear: the upper row, with the class actions and the shoulder indicators over it. A
-- fixed set, so its place does not depend on which of them are showing.
local TOTEM_CLEARANCE = { 9, 10 }
for i = 13, 38 do TOTEM_CLEARANCE[#TOTEM_CLEARANCE + 1] = i end

-- The totem bar goes above the classic bars, at the left end of the bottom row (Layout:PlaceTotemBar).
function Display:PlaceTotemBar()
    local left = UIBox(self.slots[1])
    local top
    for _, i in ipairs(TOTEM_CLEARANCE) do
        local _, _, bottom, height = UIBox(self.slots[i])
        if bottom and (not top or bottom + height > top) then top = bottom + height end
    end
    if left and top then Addon.Layout:PlaceTotemBar(left, top) end
end

-- The frame-rate display hangs off the micro menu (FramerateFrameMixin:UpdatePosition), so it would go with a hidden menu.
-- While the menu is hidden it sits at the bottom right corner instead; the game's own anchor comes back with the menu.
function Display:AnchorFramerate(hidden)
    local frame = FramerateFrame
    if not frame then return end
    if hidden then
        pcall(function()
            frame:ClearAllPoints()
            frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -5, Addon.db.menuBottom)
        end)
        self.fpsMoved = true
    elseif self.fpsMoved then
        self.fpsMoved = nil
        pcall(function()
            if MicroMenu and MicroMenu.UpdateFramerateFrameAnchor then
                MicroMenu:UpdateFramerateFrameAnchor(FrameUtil.GetScreenQuadrant(MicroMenuContainer))
            end
        end)
    end
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
    if Addon.db.hideMenu == true then
        -- Invisible and out of reach of the mouse: well past the right edge of the screen (also when Edit Mode keeps it).
        -- Edit Mode systems are clamped to the screen, which would pull it back (invisible, but still clickable).
        Addon.Layout:UnhookFrom(menu)
        menu:SetAlpha(0)
        self:AnchorFramerate(true)
        if menu.IsClampedToScreen and menu:IsClampedToScreen() then
            menu:SetClampedToScreen(false)
            self.menuUnclamped = true
        end
        Addon.Layout:SetBottomLeft(menu, (UIParent:GetWidth() + 64) / scale, Addon.db.menuBottom / scale)
        return
    end
    if menu:GetAlpha() ~= 1 then menu:SetAlpha(1) end
    if self.menuUnclamped then menu:SetClampedToScreen(true); self.menuUnclamped = nil end
    self:AnchorFramerate(false)
    -- A menu kept by the layout (placeMenu off) stays where Edit Mode puts it.
    if Addon.Layout:Keeps(menu) then return end
    local margin = Addon.db.menuRight
    local x = UIParent:GetWidth() - width - margin
    if x < margin then x = margin end
    Addon.Layout:SetBottomLeft(menu, x / scale, Addon.db.menuBottom / scale)
end

-- The gryphons at the two ends (the stock end caps' art, self.art[2] and [3]), each shown or hidden by its own setting.
function Display:ApplyCaps()
    local art = self.art
    if not art then return end
    if art[2] then art[2].texture:SetShown(Addon.db.showLeftCap ~= false) end
    if art[3] then art[3].texture:SetShown(Addon.db.showRightCap ~= false) end
end

-- The classic bars at the size the player chose (barScale, 1 = the stock size), grown or shrunk about the middle of their
-- bottom edge so they stay centered on the bottom of the screen. Slots are scaled whole (icon, cooldown, prompts and all),
-- the art is resized, and the managed stock frames follow. In compact mode the menu stays at the screen edge.
function Display:ApplyScale(scale)
    if not scale or math.abs(scale - 1) < 0.001 then return end
    local own, stock = self:Regions()
    local boxes, left, right, bottom = {}, nil, nil, nil
    for index, region in ipairs(own) do
        local regionLeft, regionRight, regionBottom, height = UIBox(region)
        if regionLeft then
            boxes[#boxes + 1] = { region, regionLeft, regionRight, regionBottom, height }
            -- Keep the pivot stable when caps, class actions or other slots change visibility.
            local slot = index <= #self.slots
            local spare = slot and Addon.Layout.compact and
                ((index >= 11 and index <= 12) or (index >= 21 and index <= 24) or (index >= 33 and index <= 36))
            if not spare then
                left, right = math.min(left or regionLeft, regionLeft), math.max(right or regionRight, regionRight)
                bottom = math.min(bottom or regionBottom, regionBottom)
            end
        end
    end
    if not left then return end
    local stockBoxes = {}
    for _, frame in ipairs(stock) do
        local frameLeft, frameRight, frameBottom, _, ratio = UIBox(frame)
        if frameLeft and ratio > 0 then stockBoxes[#stockBoxes + 1] = { frame, frameLeft, frameRight, frameBottom, ratio } end
    end
    local pivotX, pivotY = (left + right) / 2, bottom
    local function X(x) return pivotX + (x - pivotX) * scale end
    local function Y(y) return pivotY + (y - pivotY) * scale end
    for _, box in ipairs(boxes) do
        local region = box[1]
        if region:IsObjectType("Frame") then
            region:SetScale(scale)
        else
            region:SetSize((box[3] - box[2]) * scale, box[5] * scale)
        end
        MoveX(region, X(box[2]), Y(box[4]))
    end
    for _, box in ipairs(stockBoxes) do
        local frame, ratio = box[1], box[5]
        local base = frame:GetScale()
        local scaled, setScale = base * scale, frame.SetScaleBase or frame.SetScale
        setScale(frame, scaled)
        self.stockScales = self.stockScales or {}
        self.stockScales[frame] = { base = base, applied = scaled }
        ratio = ratio * scale
        Addon.Layout:SetBottomLeft(frame, X(box[2]) / ratio, Y(box[4]) / ratio)
    end
    local menu = MicroMenuContainer
    if Addon.Layout.compact and menu and Addon.db.hideMenu ~= true and not Addon.Layout:Keeps(menu) then
        local base = menu:GetScale()
        local scaled, setScale = base * scale, menu.SetScaleBase or menu.SetScale
        setScale(menu, scaled)
        self.stockScales = self.stockScales or {}
        self.stockScales[menu] = { base = base, applied = scaled }
        self:PlaceMicroMenuRight()
    end
end

-- Restore only scales that are still ours before measuring a new layout.
function Display:ResetStockScales()
    if InCombatLockdown() then return end
    for frame, saved in pairs(self.stockScales or {}) do
        if math.abs(frame:GetScale() - saved.applied) < 0.0001 then
            (frame.SetScaleBase or frame.SetScale)(frame, saved.base)
        end
    end
    self.stockScales = nil
end

-- Where the player put the bars, as an offset from their computed place in UIParent points. While the Edit Mode
-- selection is being dragged (EditMode.lua), the drag so far is added on top of the saved offset.
function Display:GetOffset()
    return (Addon.db.barX or 0) + (self.dragX or 0), (Addon.db.barY or 0) + (self.dragY or 0)
end

-- Stock frames that travel with the classic bars; the compact menu stays at the screen edge.
local function TravellingFrames()
    local frames = {}
    for _, frame in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        if frame and not Addon.Layout:Keeps(frame) then frames[#frames + 1] = frame end
    end
    if BagsBar and BagsBar:IsShown() and not Addon.Layout:Keeps(BagsBar) then
        frames[#frames + 1] = BagsBar
    end
    if not Addon.Layout.compact and MicroMenuContainer and Addon.db.hideMenu ~= true
        and MicroMenuContainer:IsShown() and not Addon.Layout:Keeps(MicroMenuContainer) then
        frames[#frames + 1] = MicroMenuContainer
    end
    return frames
end

-- Every region the classic bars are drawn with, own (slots, art) and stock.
function Display:Regions()
    local own, stock = {}, {}
    for _, slot in ipairs(self.slots or {}) do own[#own + 1] = slot end
    for _, entry in ipairs(self.art or {}) do own[#own + 1] = entry.texture end
    for _, frame in ipairs(TravellingFrames()) do
        if frame then stock[#stock + 1] = frame end
    end
    return own, stock
end

-- Moves the whole set of classic bars by dx, dy UIParent points. Every place is measured before anything moves: the
-- shoulder indicators hang from slots, so measuring after a move would shift them twice.
function Display:Translate(dx, dy)
    dx, dy = dx or 0, dy or 0
    if math.abs(dx) < 0.01 and math.abs(dy) < 0.01 then return end
    local own, stock = self:Regions()
    local places = {}
    for _, list in ipairs({ own, stock }) do
        for _, region in ipairs(list) do
            local left, _, bottom, _, scale = UIBox(region)
            if left and scale and scale > 0 then places[#places + 1] = { region, left, bottom, scale, list == stock } end
        end
    end
    for _, place in ipairs(places) do
        local region, left, bottom, scale = place[1], place[2] + dx, place[3] + dy, place[4]
        if place[5] then
            Addon.Layout:SetBottomLeft(region, left / scale, bottom / scale)
        else
            MoveX(region, left, bottom)
        end
    end
    self.offsetX, self.offsetY = (self.offsetX or 0) + dx, (self.offsetY or 0) + dy
end

-- Brings the bars on screen to the wanted offset without rebuilding them (each frame of an Edit Mode drag).
function Display:FollowOffset()
    if not self.root or not self.root:IsShown() or not self.offsetX or InCombatLockdown() then return end
    local x, y = self:GetOffset()
    self:Translate(x - self.offsetX, y - self.offsetY)
end

-- The rectangle the classic bars cover on screen, in UIParent points: left, bottom, right, top.
function Display:Bounds()
    if not self.root or not self.root:IsShown() then return end
    local own, stock = self:Regions()
    local left, bottom, right, top
    for _, list in ipairs({ own, stock }) do
        for _, region in ipairs(list) do
            if region:IsShown() and (region.GetAlpha == nil or region:GetAlpha() > 0) then
                local regionLeft, regionRight, regionBottom, height = UIBox(region)
                if regionLeft then
                    left = math.min(left or regionLeft, regionLeft)
                    right = math.max(right or regionRight, regionRight)
                    bottom = math.min(bottom or regionBottom, regionBottom)
                    top = math.max(top or regionBottom + height, regionBottom + height)
                end
            end
        end
    end
    if left then return left, bottom, right, top end
end

-- The native action editor ("Bind to Action Bar", "Edit Action Bar") draws its
-- own crossbar from a separate page unit. Its buttons are read here exactly like
-- the main HUD's, so the classic bars stay on screen while the editor is open.
-- Setting "padKeyboard": the pairs (controller storage slot, keyboard bar action slot) of the first page of the four standard
-- bars. The action editor writes the first, the bars show and press the second.
local function ActionState(slot)
    local kind, id, sub = GetActionInfo(slot)
    return tostring(kind) .. ":" .. tostring(id) .. ":" .. tostring(sub)
end

function Display:EditorPairs()
    local native = GamepadMainActionBarFrame
    local base = native and native.PageUnit and native.PageUnit.actionBars
    if not base or not self.slots then return end
    local pairsList = {}
    for group, key in ipairs({ "topBar", "leftBar", "rightBar", "bottomBar" }) do
        local bar = base[key]
        for index = 1, 8 do
            local button = bar and bar.actionButtons and bar.actionButtons[index]
            local pageSlot = button and button.GetGamepadPageUnitSlotID and button:GetGamepadPageUnitSlotID()
            if pageSlot and GamepadActionBarBindingUtil.IsBindablePageUnitSlotID(pageSlot) then
                local storage = GamepadActionBarBindingUtil.GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID(1, pageSlot)
                local place = Addon.Input.PadSlot(group, index)
                local template = place and self.slots[place] and self.slots[place].template
                local action = template and template.action
                if storage and Readable(action) and type(action) == "number" and action > 0 then
                    pairsList[#pairsList + 1] = { storage, action }
                end
            end
        end
    end
    return pairsList
end

-- Remembers what the controller storage holds when the action editor opens, after making the storage a copy of the keyboard
-- bars (the editor shows, picks up and clears what is in it, so it has to hold what the bars hold). Both ways: what the
-- keyboard bars have goes to the editor now, what the editor changed goes back to them when it closes (SyncEditor).
local function PickupFlyout(flyoutID)
    if not flyoutID or not C_SpellBook or not C_SpellBook.GetNumSpellBookSkillLines or not Enum or not Enum.SpellBookSpellBank then
        return
    end
    local bank = Enum.SpellBookSpellBank.Player
    local flyoutType = Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout
    if not flyoutType then return end
    local lines = C_SpellBook.GetNumSpellBookSkillLines() or 0
    for line = 1, lines do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if info and info.itemIndexOffset and info.numSpellBookItems then
            for i = 1, info.numSpellBookItems do
                local idx = info.itemIndexOffset + i
                local item = C_SpellBook.GetSpellBookItemInfo(idx, bank)
                if item and item.itemType == flyoutType and item.actionID == flyoutID then
                    C_SpellBook.PickupSpellBookItem(idx, bank)
                    return
                end
            end
        end
    end
end

-- Resolves known spells inside a Blizzard SpellFlyout (highest known rank per spell name), plus single/active spell IDs.
function Addon.FlyoutSpells(flyoutID)
    if not Readable(flyoutID) or not flyoutID or not GetFlyoutInfo or not GetFlyoutSlotInfo then
        return {}, nil, nil, nil
    end
    local ok, name, _, numSlots, isKnown = pcall(GetFlyoutInfo, flyoutID)
    local flyName = ok and Readable(name) and name or nil
    if not ok or not Readable(isKnown) or not isKnown or not Readable(numSlots) or type(numSlots) ~= "number" or numSlots <= 0 then
        return {}, nil, nil, flyName
    end
    local spells, byName = {}, {}
    local active
    for i = 1, numSlots do
        local sok, spellID, overrideSpellID, slotKnown, spellName = pcall(GetFlyoutSlotInfo, flyoutID, i)
        if sok and Readable(slotKnown) and slotKnown and Readable(spellID) and spellID then
            local petSkip = false
            if GetCallPetSpellInfo then
                local pok, petIndex, petName = pcall(GetCallPetSpellInfo, spellID)
                if pok and Readable(petIndex) and petIndex and Readable(petName) and (not petName or petName == "") then
                    petSkip = true
                end
            end
            if not petSkip then
                local castID = (Readable(overrideSpellID) and overrideSpellID) or spellID
                local readableName = Readable(spellName) and spellName or nil
                local key = readableName or castID
                local idx = byName[key]
                local entry = { id = castID, base = spellID, name = readableName }
                if idx then
                    spells[idx] = entry
                else
                    idx = #spells + 1
                    byName[key] = idx
                    spells[idx] = entry
                end
                if not active and C_Spell and C_Spell.IsActiveSpell then
                    local aok, isAct = pcall(C_Spell.IsActiveSpell, castID)
                    if aok and Readable(isAct) and isAct then active = castID end
                end
            end
        end
    end
    local single = #spells == 1 and spells[1].id or nil
    return spells, single, active, flyName
end

-- Puts a copy of the action in `slot` on the cursor, for the kinds of action that can be picked up again.
local function PickupCopy(slot)
    local kind, id = GetActionInfo(slot)
    ClearCursor()
    if not id then return false end
    if kind == "spell" then
        C_Spell.PickupSpell(id)
    elseif kind == "item" then
        C_Item.PickupItem(id)
    elseif kind == "macro" then
        PickupMacro(id)
    elseif kind == "flyout" then
        PickupFlyout(id)
    end
    return GetCursorInfo() ~= nil
end

function Display:SnapshotEditor()
    if InCombatLockdown() or GetCursorInfo() then return end
    local list = self:EditorPairs()
    if not list then return end
    local snapshot = {}
    for _, pair in ipairs(list) do
        local storage, action = pair[1], pair[2]
        if ActionState(storage) ~= ActionState(action) then
            if not GetActionInfo(action) then
                -- Nothing on the keyboard bar: what the controller storage holds stays (it is the player's own layout of
                -- before; nothing of it reaches the keyboard bar unless the editor changes it).
            elseif PickupCopy(action) then
                PlaceAction(storage)
            elseif GetActionInfo(storage) then
                -- A kind that cannot be copied (a flyout, a mount): the slot shows empty rather than a stale action that
                -- the editor could then move onto the keyboard bar.
                PickupAction(storage)
            end
            ClearCursor()
        end
        snapshot[storage] = ActionState(storage)
    end
    self.editorSnapshot = snapshot
end

-- When the editor has closed: every controller storage slot it changed is copied to the keyboard bar slot at the same place
-- (the action that was there goes), and a slot it emptied empties that keyboard slot. Outside combat, with an empty cursor.
function Display:SyncEditor()
    local snapshot = self.editorSnapshot
    if not snapshot then return end
    if InCombatLockdown() or GetCursorInfo() then return end
    self.editorSnapshot = nil
    local list = self:EditorPairs()
    local moved = 0
    for _, pair in ipairs(list or {}) do
        local storage, action = pair[1], pair[2]
        local before = snapshot[storage]
        if before and ActionState(storage) ~= before then
            if GetActionInfo(storage) then
                if PickupCopy(storage) then
                    PlaceAction(action)
                else
                    -- A kind that cannot be picked up again: it moves.
                    PickupAction(storage)
                    PlaceAction(action)
                end
            else
                PickupAction(action)
            end
            ClearCursor()
            moved = moved + 1
        end
    end
    if moved > 0 then
        if Addon.Input then Addon.Input.flyoutsDirty = true end
        Display:InvalidateFlyoutCache()
        Addon:Print(Addon.L.editorSynced:format(moved))
        Addon:QueueRefresh(true)
    end
end

function Display:IsBarEditing()
    return GamepadActionBarEditFrame ~= nil and GamepadActionBarEditFrame:IsShown()
end

local PAGE_EXTRA_BAR_KEYS = { "FriendlyTargetingActionBar", "HostileTargetingActionBar", "ShortcutsActionBar" }
local CLASS_ACTION_KEYS = { "LeftClassAction", "RightClassAction" }
local pageUnitBars = {}

local function PageUnitBars(unit)
    if not unit or not unit.actionBars then return end
    wipe(pageUnitBars)
    for _, bar in pairs(unit.actionBars) do pageUnitBars[#pageUnitBars + 1] = bar end
    for i = 1, #PAGE_EXTRA_BAR_KEYS do
        local bar = unit[PAGE_EXTRA_BAR_KEYS[i]]
        if bar then pageUnitBars[#pageUnitBars + 1] = bar end
    end
    return pageUnitBars
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

-- Edit Mode (HUD layout editing) is open.
function Display:IsEditing()
    return EditModeManagerFrame ~= nil and EditModeManagerFrame:IsEditModeActive()
end

-- The stock page unit fades to this alpha while a bar button's selection radial is open
-- (Blizzard_GamepadActionBars/PageUnit.lua, FLYOUT_INACTIVE_ALPHA). The classic bars follow it.
local FLYOUT_ALPHA = 0.35

-- True while a selection radial (a flyout) is open: the warrior's stances, the druid's forms, the paladin's auras
-- and the pet commands hang off a class action, any other radial off a bar button.
function Display:IsFlyoutOpen(bars, unit)
    for i = 1, #bars do
        local buttons = bars[i].actionButtons
        if buttons then
            for j = 1, #buttons do
                local source = buttons[j]
                if source.IsPopupOpen and source:IsPopupOpen() then return true end
            end
        end
    end
    for i = 1, #CLASS_ACTION_KEYS do
        local source = unit[CLASS_ACTION_KEYS[i]]
        if source and source.IsPopupOpen and source:IsPopupOpen() then return true end
    end
    return false
end

-- Edit Mode keeps the classic bars: they get a selection box of their own there (EditMode.lua) and can be dragged.
-- Going native for it put the stock gamepad crossbar up instead, which cannot place the classic bars, and the classic
-- bars had no place in the editor at all. A radial needs no native view: the game draws, focuses and drives it itself and shows it
-- over whatever HUD is up (its frame hangs off UIParent and the button it belongs to moves into it, so the faded
-- stock bar hides neither). The classic bars stay and fade while it is open (Refresh). Going native for it put the
-- bags, micro menu, status bars and chat back in their stock places for as long as it was open, and in combat for
-- the rest of the fight, because the classic bars cannot be built then. Only the action editor's own radials stay
-- native: its bars are drawn above the editor's dimmed screen (SetLayer), which would put them over the radial.
function Display:NeedsNativeView(bars, unit, editing)
    return editing and self:IsFlyoutOpen(bars, unit) or false
end

function Display:GetDragAction(slot)
    if InCombatLockdown() or self.barEditing then return end
    -- Resolve the current page/override before a hardware-driven edit.
    Addon:Refresh()
    if not Addon.classicVisible then return end
    if slot.keyboardSlot then
        -- A spare slot mirroring the keyboard bar: plain action-bar storage, even when empty.
        local action = ActionOf(slot, slot.keyboardSource or slot.template)
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
    if slot.SlotArt:IsShown() then slot.SlotArt:Hide() end
    if slot.Background:IsShown() then slot.Background:Hide() end
    if not slot.iconAnchored then
        if slot.Mask then slot.Icon:RemoveMaskTexture(slot.Mask) end
        slot.Icon:ClearAllPoints()
        slot.Icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 3, -3)
        slot.Icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -3, 3)
        slot.Cooldown:ClearAllPoints()
        slot.Cooldown:SetAllPoints(slot.Icon)
        slot.iconAnchored = true
    end
end

-- A unit portrait (party members, the player, the pet, the assist target, the focus on the targeting bars) is not a file
-- or an atlas: the game fills the stock texture with SetPortraitTexture, and a texture copy cannot carry it over. So the
-- slot asks for the same portrait itself, through a round mask like the game's.
local function PortraitUnit(source, icon)
    if not source.SpecialActionIcon or icon ~= source.SpecialActionIcon or not source.GetAttribute then return end
    if source:GetAttribute("type") ~= "target" then return end
    local unit = source:GetAttribute("unit")
    if type(unit) == "string" and Readable(unit) and unit ~= "" then return unit end
end

local function SetPortrait(slot, unit)
    if not slot.PortraitMask then
        slot.PortraitMask = slot:CreateMaskTexture(nil, "ARTWORK")
        slot.PortraitMask:SetAtlas("CircleMask")
        slot.PortraitMask:SetAllPoints(slot.Icon)
    end
    if not slot.portrait then
        slot.Icon:AddMaskTexture(slot.PortraitMask)
        slot.portrait = true
    end
    slot.Icon._cgpTex = nil
    slot.Icon:SetTexCoord(0, 1, 0, 1)
    SetPortraitTexture(slot.Icon, unit)
end

local function ClearPortrait(slot)
    if not slot.portrait then return end
    slot.Icon:RemoveMaskTexture(slot.PortraitMask)
    slot.portrait = nil
end

local function PresentEmptySlot(slot)
    ClearPortrait(slot)
    HideTexture(slot.Icon)
    if slot.SlotArt:IsShown() then slot.SlotArt:Hide() end
    if not slot.Background:IsShown() then slot.Background:Show() end
end

-- A stock empty slot plate, so the 12-slot main row has no gaps.
function Display:ShowPlaceholder(slot)
    self:UpdateSlot(slot, nil)
    if not slot.Background:IsShown() then slot.Background:Show() end
end

-- Extended layout: a main-row position without a native gamepad action (the second
-- class action, and the two spare slots) shows the keyboard bar's button at the same
-- position. Its key (9, 0, -, =) uses that action, so the key works on the classic bar.
function Display:ShowKeyboardSlot(slot)
    local source = slot.template
    local action = ActionOf(slot, source)
    if source and type(action) == "number" and action > 0 and C_ActionBar.HasAction(action) then
        self:UpdateSlot(slot, source, nil, false)
        HideTexture(slot.Prompt)
        HideTexture(slot.Modifiers[1])
        HideTexture(slot.Modifiers[2])
    else
        self:ShowPlaceholder(slot)
    end
end

-- Other addons draw on the native action buttons: SpellDamageInfo's damage and healing numbers, bar addons' labels.
-- Those buttons are faded while the classic bars show, so their text is copied onto the slot. The button's own texts
-- (key, count, macro name) are drawn by the slot already, and named regions belong to Blizzard's template.
local BLIZZARD_TEXT_KEYS = { "HotKey", "Count", "Name", "RangeIndicator" }

local function IsForeignText(region, source)
    -- RangeIndicator is the gamepad button's own unnamed dot (tinted red when out of range), not another addon's text.
    for i = 1, #BLIZZARD_TEXT_KEYS do
        if region == source[BLIZZARD_TEXT_KEYS[i]] then return false end
    end
    if type(region.GetObjectType) ~= "function" or region:GetObjectType() ~= "FontString" then return false end
    return region:GetName() == nil
end

local function CopyForeignText(mirror, region, slot, now)
    local c = mirror._cgpText
    if not c then c = {}; mirror._cgpText = c end
    local text = region:GetText()
    local shown = region:IsShown()
    if not Readable(text) or not Readable(shown) or type(text) ~= "string" or text == "" or not shown then
        if c.shown ~= false then
            c.shown = false
            mirror:Hide()
        end
        return
    end
    local rev = Display.layoutRevision
    if c.shown == true and c.text == text and c.region == region and c.slot == slot
        and c.rev == rev and c.styleAt and (now - c.styleAt) < 1.0 then
        local r, g, b, a = region:GetTextColor()
        if not (Readable(r) and Readable(g) and Readable(b) and Readable(a)) then
            c.r = nil
            mirror:SetTextColor(r, g, b, a)
        elseif c.r ~= r or c.g ~= g or c.b ~= b or c.a ~= a then
            c.r, c.g, c.b, c.a = r, g, b, a
            mirror:SetTextColor(r, g, b, a)
        end
        return
    end
    -- Preserve the native text's relative size while letting it follow the classic slot's scale.
    local ratio = 1
    local regionScale, mirrorScale = region:GetEffectiveScale(), mirror:GetEffectiveScale()
    if Readable(regionScale) and Readable(mirrorScale) and regionScale and mirrorScale and mirrorScale > 0 then
        ratio = regionScale / mirrorScale * slot:GetScale()
    end
    if ratio <= 0 then ratio = 1 end
    local font, size, flags = region:GetFont()
    if font and Readable(font) and Readable(size) then
        local scaled = size * ratio
        if c.font ~= font or c.size ~= scaled or c.flags ~= flags then
            c.font, c.size, c.flags = font, scaled, flags
            mirror:SetFont(font, scaled, flags)
        end
    end
    local r, g, b, a = region:GetTextColor()
    if not (Readable(r) and Readable(g) and Readable(b) and Readable(a)) then
        c.r = nil
        mirror:SetTextColor(r, g, b, a)
    elseif c.r ~= r or c.g ~= g or c.b ~= b or c.a ~= a then
        c.r, c.g, c.b, c.a = r, g, b, a
        mirror:SetTextColor(r, g, b, a)
    end
    local jh = region:GetJustifyH()
    if not Readable(jh) or c.jh ~= jh then
        c.jh = Readable(jh) and jh or nil
        mirror:SetJustifyH(jh)
    end
    local jv = region:GetJustifyV()
    if not Readable(jv) or c.jv ~= jv then
        c.jv = Readable(jv) and jv or nil
        mirror:SetJustifyV(jv)
    end
    local alpha = region:GetAlpha()
    if not Readable(alpha) or c.alpha ~= alpha then
        c.alpha = Readable(alpha) and alpha or nil
        mirror:SetAlpha(alpha)
    end
    local point, _, relativePoint, x, y = region:GetPoint(1)
    local pt, relPt, px, py
    if point then
        pt, relPt, px, py = point, relativePoint or point, (x or 0) * ratio, (y or 0) * ratio
    else
        pt, relPt, px, py = "CENTER", "CENTER", 0, 0
    end
    if c.pt ~= pt or c.relPt ~= relPt or c.px ~= px or c.py ~= py or c.slot ~= slot then
        c.pt, c.relPt, c.px, c.py, c.slot = pt, relPt, px, py, slot
        mirror:ClearAllPoints()
        mirror:SetPoint(pt, slot, relPt, px, py)
    end
    if c.text ~= text then
        c.text = text
        mirror:SetText(text)
    end
    c.region, c.rev, c.styleAt = region, rev, now
    if c.shown ~= true then
        c.shown = true
        mirror:Show()
    end
end

-- The regions of the button being looked at, in one table that is reused. Asking for them used to make a closure and a
-- table for every slot on every refresh.
local regionList, regionCount = {}, 0
local foreignRegionsCache = setmetatable({}, { __mode = "k" })

local function RegionsOf(source) return source:GetRegions() end

local function PackRegions(ok, ...)
    local count = ok and select("#", ...) or 0
    for i = 1, count do regionList[i] = (select(i, ...)) end
    for i = count + 1, regionCount do regionList[i] = nil end
    regionCount = count
    return count
end

function Display:MirrorForeignText(slot, source)
    local mirrors = slot.Foreign
    if not mirrors then mirrors = {}; slot.Foreign = mirrors end
    local used = 0
    if source then
        local now = GetTime()
        local entry = foreignRegionsCache[source]
        if not entry or (now - entry.at) >= 2.0 then
            local list = entry and entry.list or {}
            local n = 0
            for i = 1, PackRegions(pcall(RegionsOf, source)) do
                local region = regionList[i]
                if region and IsForeignText(region, source) then
                    n = n + 1
                    list[n] = region
                end
            end
            for i = n + 1, #list do list[i] = nil end
            if not entry then
                entry = { list = list, at = now }
                foreignRegionsCache[source] = entry
            else
                entry.at = now
            end
        end
        local list = entry.list
        for i = 1, #list do
            used = used + 1
            local mirror = mirrors[used]
            if not mirror then
                mirror = slot.Labels:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                mirrors[used] = mirror
            end
            CopyForeignText(mirror, list[i], slot, now)
        end
    end
    for i = used + 1, #mirrors do
        local m = mirrors[i]
        local c = m._cgpText
        if not c or c.shown ~= false then
            if c then c.shown = false end
            m:Hide()
        end
    end
end

local flyoutActionCache = {}
function Display:InvalidateFlyoutCache()
    wipe(flyoutActionCache)
end

local function ActionIsFlyout(action)
    if not action or not Readable(action) or type(action) ~= "number" or action <= 0 or not GetActionInfo then
        return false
    end
    local cached = flyoutActionCache[action]
    if cached ~= nil then return cached end
    local ok, kind = pcall(GetActionInfo, action)
    local result = ok and kind == "flyout" and true or false
    flyoutActionCache[action] = result
    return result
end

local function SetSlotShown(region, shown)
    if region:IsShown() == shown then return end
    region:SetShown(shown)
end

function Display:UpdateSlot(slot, source, bar, active, buttonIndex)
    if not slot:IsShown() then slot:Show() end
    if slot.Key then
        local showKey = Addon.db.showKeyboardHints and true or false
        if slot._cgpKeyShown ~= showKey then
            slot._cgpKeyShown = showKey
            slot.Key:SetShown(showKey)
        end
        if slot.Key.SetTextColor and slot._cgpKeyColor ~= 1 then
            slot._cgpKeyColor = 1
            slot.Key:SetTextColor(1, 1, 1)
        end
    end
    if not source then
        if slot._cgpAlpha ~= 1 then slot._cgpAlpha = 1; slot:SetAlpha(1) end
        slot.source, slot.action = nil, nil
        HideTexture(slot.Icon)
        slot.SlotArt:Hide()
        slot.Background:Hide()
        if slot._cgpCountText ~= "" then slot._cgpCountText = ""; slot.Count:SetText("") end
        HideTexture(slot.Prompt)
        SetSlotShown(slot.Checked, false)
        SetSlotShown(slot.Pushed, false)
        SetSlotShown(slot.Glow, false)
        if slot.FlyoutArrow then SetSlotShown(slot.FlyoutArrow, false) end
        if slot._cgpHasCooldown ~= false then slot._cgpHasCooldown = false; slot.Cooldown:Clear() end
        if slot.Overlay then HideTexture(slot.Overlay) end
        HideTexture(slot.Modifiers[1])
        HideTexture(slot.Modifiers[2])
        if slot.Foreign and #slot.Foreign > 0 then pcall(self.MirrorForeignText, self, slot, nil) end
        return
    end
    local srcAlpha = source:GetAlpha()
    if not Readable(srcAlpha) or slot._cgpAlpha ~= srcAlpha then
        slot._cgpAlpha = Readable(srcAlpha) and srcAlpha or nil
        slot:SetAlpha(srcAlpha)
    end
    local action = ActionOf(slot, source)
    if slot.source ~= source or (Readable(action) and slot.action ~= action) then
        slot.source, slot.action = source, Readable(action) and action or nil
        slot._cgpHasCooldown = true
        self:HookSource(source, bar)
        self:MirrorCooldown(slot, source, bar)
    end
    self.slotBySource[source] = slot
    local actionFlyout = ActionIsFlyout(action)
    local icon = source.icon or source.Icon
    if source.SpecialActionIcon and RegionShown(source.SpecialActionIcon) then icon = source.SpecialActionIcon end
    if RegionShown(icon) then
        PresentActionIcon(slot, icon)
        if not self.barEditing and icon == source.icon and not source.isFlyoutAction
            and (slot.keyboardSlot or (bar and not bar.isGamepadPossessBar and source.GetGamepadPageUnitSlotID))
            and Readable(action) and type(action) == "number" and action > 0
            and C_ActionBar and C_ActionBar.IsUsableAction then
            local isFlyout = slot.keyboardSlot and actionFlyout or false
            if not isFlyout then
                local outOfRange = false
                if slot.keyboardSlot and C_ActionBar.IsActionInRange then
                    local inRange = C_ActionBar.IsActionInRange(action)
                    if Readable(inRange) and inRange == false then outOfRange = true end
                end
                if outOfRange and slot.Key and slot.Key.SetTextColor and slot._cgpKeyColor ~= 2 then
                    slot._cgpKeyColor = 2
                    slot.Key:SetTextColor(1, 0.2, 0.2)
                end
                local usable, lacking = C_ActionBar.IsUsableAction(action)
                if Readable(usable) and Readable(lacking) then
                    if usable == true then
                        local keyShown = slot.Key and Addon.db.showKeyboardHints and slot.Key.GetText and (slot.Key:GetText() or "") ~= ""
                        if outOfRange and not keyShown then
                            SetCachedVertexColor(slot.Icon, 1, 0.35, 0.35)
                        elseif slot.keyboardSlot or not source.icon.GetVertexColor then
                            -- Hidden keyboard buttons stop receiving Blizzard's UpdateUsable events,
                            -- so clear any stale OOM/unusable vertex color copied from source.icon.
                            SetCachedVertexColor(slot.Icon, 1, 1, 1)
                        end
                    elseif lacking == true then
                        SetCachedVertexColor(slot.Icon, 0.5, 0.5, 1)
                    elseif slot.keyboardSlot then
                        SetCachedVertexColor(slot.Icon, 0.4, 0.4, 0.4)
                    end
                end
            end
        end
        local unit = PortraitUnit(source, icon)
        if unit then
            -- Never let a portrait failure switch the classic bars off.
            if not pcall(SetPortrait, slot, unit) then ClearPortrait(slot) end
        else
            ClearPortrait(slot)
        end
    else
        PresentEmptySlot(slot)
    end
    CopyGlyph(slot.Prompt, source.ButtonIcon)
    BindingPrompt(slot, buttonIndex)
    if source.Count then
        local countText = source.Count:GetText()
        if not Readable(countText) then
            slot._cgpCountText = nil
            slot.Count:SetText(countText)
        elseif slot._cgpCountText ~= countText then
            slot._cgpCountText = countText
            slot.Count:SetText(countText)
        end
        local countShown = source.Count:IsShown()
        local showCount = (not Readable(countShown) or countShown == true) and true or false
        if slot._cgpCountShown ~= showCount then
            slot._cgpCountShown = showCount
            slot.Count:SetShown(showCount)
        end
    elseif slot._cgpCountText ~= "" then
        slot._cgpCountText = ""
        slot.Count:SetText("")
    end
    local checked = source.CheckedTexture or (source.GetCheckedTexture and source:GetCheckedTexture())
    local shown = checked and checked:IsShown()
    SetSlotShown(slot.Checked, Readable(shown) and shown == true)
    SetSlotShown(slot.Pushed, (slot.inputButton and slot.inputButton:GetAttribute("cgppressed") == true) or self.pressed[source] == true
        or (source.GetButtonState and source:GetButtonState() == "PUSHED") or false)
    SetSlotShown(slot.Glow, ((active and Addon.db.highlightActive) or slot.bindingHighlight == true) and true or false)
    if slot.FlyoutArrow then
        local isFlyout = (source.Arrow and RegionShown(source.Arrow)) or actionFlyout
        SetSlotShown(slot.FlyoutArrow, isFlyout)
        if isFlyout and SetClampedTextureRotation then
            local open = (source.IsPopupOpen and source:IsPopupOpen()) or false
            local rot = open and 180 or 0
            if slot._cgpFlyoutRot ~= rot then
                slot._cgpFlyoutRot = rot
                SetClampedTextureRotation(slot.FlyoutArrow, rot)
            end
        end
    end
    -- Contextual bars can add a second icon (e.g. a mark over a target portrait).
    if source.IconOverlay and source.IconOverlay:IsShown() then
        if not slot.Overlay then slot.Overlay = Texture(slot.Labels, "ARTWORK"); slot.Overlay:SetAllPoints(slot.Icon) end
        CopyTexture(slot.Overlay, source.IconOverlay)
    elseif slot.Overlay then HideTexture(slot.Overlay) end
    -- An extra, cosmetic copy: a failure here must not switch the classic bars off.
    pcall(self.MirrorForeignText, self, slot, source)
end

-- Two modifier glyphs (LT + RT) fill the top row, so a third glyph, the button itself, drops to a second row.
function Display:PlacePrompt(slot)
    local low = slot.Prompt:IsShown() and slot.Modifiers[2]:IsShown() or false
    if slot.promptLow == low then return end
    slot.promptLow = low
    local promptScale, modifierScale = Addon.db.promptScale, Addon.db.modifierScale
    local drop = low and 17 * modifierScale or 0
    slot.Prompt:ClearAllPoints()
    slot.Prompt:SetPoint("TOPRIGHT", 4 * promptScale, 4 * promptScale - drop)
end

local updateSelected, updateStandard, updateAnchors, suppressKeep, singleNative = {}, {}, {}, {}, {}
local SHOULDER_KEYS = { "LeftShoulderIcon", "RightShoulderIcon" }
local OVERRIDE_BAR_KEYS = { "FriendlyTargetingActionBar", "HostileTargetingActionBar", "ShortcutsActionBar" }
local COMPACT_SPARE_FIRSTS = { 21, 33 }

function Display:Update(unit)
    if self.slotBySource then wipe(self.slotBySource) else self.slotBySource = {} end
    for i = 1, 2 do
        local slot = self.slots[36 + i]
        if not slot._cgpShoulderInit then
            self:UpdateSlot(slot, nil)
            slot._cgpShoulderInit = true
        elseif not slot:IsShown() then
            slot:Show()
        end
        CopyTexture(slot.Icon, unit[SHOULDER_KEYS[i]])
        BindingGlyphs(slot, i == 1 and "GAMEPADLEFTTARGETMODIFIER" or "GAMEPADRIGHTTARGETMODIFIER")
        local highlight = i == 1 and unit.LeftShoulderHighlight or unit.RightShoulderHighlight
        SetSlotShown(slot.Glow, (Addon.db.highlightActive and highlight and highlight:IsShown()) and true or false)
    end
    local base = unit.actionBars
    local page = unit:GetCurrentPage()
    local selected = wipe(updateSelected)
    if page <= Constants.GamepadActionBarConstants.NUM_STANDARD_PAGES_PER_GAMEPAD_ACTION_BAR_PAGE_UNIT then
        selected[1], selected[2], selected[3], selected[4] = base.topBar, base.leftBar, base.rightBar, base.bottomBar
    end
    updateAnchors[1] = unit.TopCenteredAnchor
    updateAnchors[2] = unit.LeftCenteredAnchor
    updateAnchors[3] = unit.RightCenteredAnchor
    updateAnchors[4] = unit.BottomCenteredAnchor
    for b = 1, 2 do
        local bar = b == 1 and base.possessBar or base.stanceBar
        if bar and bar:IsShown() then
            local parent = bar:GetParent()
            for i = 1, 4 do if parent == updateAnchors[i] then selected[i] = bar end end
        end
    end
    for i = 1, #OVERRIDE_BAR_KEYS do
        local bar = unit[OVERRIDE_BAR_KEYS[i]]
        if bar and bar:IsShown() then selected[1] = bar end
    end
    local activeBar = unit:GetActiveBar()
    -- Setting "padKeyboard": a slot of the four standard bars shows the keyboard bar's button at its place (Input.lua
    -- presses the same button); the game's own four (interact, target menu, back, jump) stay.
    -- Not in the action editor: it writes the game's own gamepad storage, which the keyboard bars do not show.
    local standard = wipe(updateStandard)
    if Addon.db.padKeyboard == true and not self.barEditing then
        if base.topBar then standard[base.topBar] = true end
        if base.leftBar then standard[base.leftBar] = true end
        if base.rightBar then standard[base.rightBar] = true end
        if base.bottomBar then standard[base.bottomBar] = true end
    end
    local function KeyboardButton(bar, index, native)
        local source = bar and standard[bar] and bar.actionButtons[native]
        if not source then return end
        local pageSlot = source.GetGamepadPageUnitSlotID and source:GetGamepadPageUnitSlotID()
        if not pageSlot or GamepadActionBarBindingUtil.IsReservedPageUnitSlotID(pageSlot) then return end
        local place = Addon.Input.PadSlot(index, native)
        return place and self.slots[place] and self.slots[place].template
    end
    local function PaintGroup(index, firstSlot, firstButton, count)
        local bar = selected[index]
        local active = bar ~= nil and bar == activeBar
        if not bar or (bar.IsActionBarUsable and not bar:IsActionBarUsable()) then active = false end
        for j = 0, count - 1 do
            local slot = self.slots[firstSlot + j]
            local keyboard = KeyboardButton(bar, index, firstButton + j)
            slot.keyboardSource, slot.keyboardSlot = keyboard, keyboard ~= nil
            if keyboard then
                local action = ActionOf(slot, keyboard)
                if type(action) == "number" and action > 0 and C_ActionBar.HasAction(action) then
                    self:UpdateSlot(slot, keyboard, nil, active, firstButton + j)
                else
                    self:ShowPlaceholder(slot)
                    SetSlotShown(slot.Glow, (active and Addon.db.highlightActive) and true or false)
                end
                CopyGlyph(slot.Prompt, bar.actionButtons[firstButton + j].ButtonIcon)
                BindingPrompt(slot, firstButton + j)
            else
                self:UpdateSlot(slot, bar and bar.actionButtons[firstButton + j], bar, active, firstButton + j)
            end
            if bar and bar == unit.ShortcutsActionBar then
                CopyTexture(slot.Modifiers[1], self.slots[37].Prompt)
                CopyTexture(slot.Modifiers[2], self.slots[38].Prompt)
            elseif bar and (bar == unit.FriendlyTargetingActionBar or bar == unit.HostileTargetingActionBar) then
                local flag = bar == unit.FriendlyTargetingActionBar and GamepadTargetingState.FRIENDLY or GamepadTargetingState.HOSTILE
                local shoulder = GamepadMode.GetLeftTargetModifierFlag() == flag and 37 or 38
                CopyTexture(slot.Modifiers[1], self.slots[shoulder].Prompt)
                HideTexture(slot.Modifiers[2])
            else
                CopyGlyph(slot.Modifiers[1], (index == 2 or index == 4) and unit.LeftIcon or (index == 3 and unit.RightIcon or nil))
                CopyGlyph(slot.Modifiers[2], index == 4 and unit.RightIcon or nil)
            end
        end
    end
    local compact = Addon.Layout.compact
    local mainIndex = compact and selected[4] and activeBar == selected[4] and 4 or 1
    local function PaintRow(index, firstSlot)
        PaintGroup(index, firstSlot, Addon.Layout.RowStart(false), 4)
        PaintGroup(index, firstSlot + 4, Addon.Layout.RowStart(true), 4)
    end
    PaintRow(mainIndex, 1)
    PaintRow(2, 13)
    PaintRow(3, 25)
    if compact then
        for k = 1, #COMPACT_SPARE_FIRSTS do
            local first = COMPACT_SPARE_FIRSTS[k]
            for i = first, first + 3 do
                self:UpdateSlot(self.slots[i], nil)
                self.slots[i]:Hide()
            end
        end
    else
        -- Split the combined layer across the extended trigger sections.
        PaintGroup(4, 21, Addon.Layout.RowStart(false), 4)
        PaintGroup(4, 33, Addon.Layout.RowStart(true), 4)
    end
    for i = 11, 12 do
        local slot = self.slots[i]
        slot.keyboardSlot = not compact
        if compact then slot:Hide() else self:ShowKeyboardSlot(slot) end
    end
    for i = 1, #CLASS_ACTION_KEYS do
        local source = unit[CLASS_ACTION_KEYS[i]]
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
            HideTexture(slot.Modifiers[2])
        end
    end
    for i = 1, 36 do
        if self.slots[i] then self:PlacePrompt(self.slots[i]) end
    end
end

-- Fade native frames instead of hiding them: their own code keeps running and
-- no protected visibility is changed from addon code.
function Display:SuppressNative(frames)
    if not self.suppressed then Addon:Trace("Display:SuppressNative") end
    self.suppressed = self.suppressed or {}
    local keep = wipe(suppressKeep)
    for i = 1, #frames do
        local frame = frames[i]
        keep[frame] = true
        if self.suppressed[frame] == nil then self.suppressed[frame] = frame:GetAlpha() end
        local alpha = frame:GetAlpha()
        if not Readable(alpha) or alpha ~= 0 then frame:SetAlpha(0) end
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
    if self.root then self:SetLayer(false); self.root:SetAlpha(1); self.root:Hide() end
end

local function SetStrata(frame, strata)
    frame:SetFrameStrata(strata)
    for _, child in ipairs({ frame:GetChildren() }) do SetStrata(child, strata) end
end

-- The editor dims the screen with a HIGH-strata background. Draw above it while
-- the editor is open, and return to the ordinary layer afterwards.
local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }

local function StrataAbove(strata)
    for i, name in ipairs(STRATA) do
        if name == strata then return STRATA[math.min(i + 1, #STRATA)] end
    end
    return "FULLSCREEN_DIALOG"
end

-- The editor dims the screen with a background in its own strata, and it raises itself above
-- every sibling in that strata, so no frame level beats it. Draw one strata higher instead:
-- the bars sit away from the editor's dialogs, so nothing of theirs is covered.
function Display:SetLayer(editing)
    local root = self.root
    if not root then return end
    local strata = "LOW"
    if editing and GamepadActionBarEditFrame then
        strata = StrataAbove(GamepadActionBarEditFrame:GetFrameStrata())
    end
    if self.layerStrata == strata then return end
    self.layerStrata = strata
    SetStrata(root, strata)
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
        Reveal(store, MainActionBar.BorderArt)
        Reveal(store, caps)
        -- Showing the bar re-hides the caps while the gamepad UI is active.
        Reveal(store, caps)
        Reveal(store, caps and caps.LeftEndCap)
        Reveal(store, caps and caps.LeftEndCap and caps.LeftEndCap.Texture)
        Reveal(store, caps and caps.RightEndCap)
        Reveal(store, caps and caps.RightEndCap and caps.RightEndCap.Texture)
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
    if self:NeedsNativeView(bars, unit, editing) then
        self.reason = "editor flyout"
        self:RestoreNative()
        return false
    end
    -- Initial setup and secure input geometry wait for combat to end.
    if InCombatLockdown() and not self.native and not self.mouseState then
        self.reason = "combat"
        return false
    end
    local needsGeometry = not self.root or Addon.Layout.dirty
        or self.layoutRevision ~= Addon.Layout.revision
    if needsGeometry then
        self:RevealTemplates()
        -- The layout measures stock panels at their own sizes.
        self:ResetStockScales()
    end
    local prepared = Addon.Layout:Prepare()
    if not prepared then self:HideTemplates(); self.reason = "layout"; return false end
    self:Create()
    local geometryOK = self:RefreshGeometry()
    self:HideTemplates()
    if not geometryOK then self.reason = "geometry"; self:RestoreNative(); return false end
    self.reason = editing and "shown (action editor)" or "shown"
    self.barEditing = editing
    -- The editor fills the game's controller storage; with "padKeyboard" the bars show the keyboard bars, so what the
    -- editor changed is put on the keyboard bars when it closes (SyncEditor). Said once per visit.
    if editing and Addon.db.padKeyboard == true then
        if not self.editorNoted then
            self.editorNoted = true
            Addon:Print(Addon.L.editorPadNote)
            pcall(self.SnapshotEditor, self)
        end
    else
        self.editorNoted = nil
        if self.editorSnapshot and not editing then
            local ok, err = pcall(self.SyncEditor, self)
            if not ok then self.editorSnapshot = nil; Addon:Note("Display:SyncEditor", err) end
        end
    end
    self:Update(unit)
    self:AvoidDefaultStatusOverlap()
    -- Like the game's own bars, everything but the radial fades while one is open.
    self.root:SetAlpha(self:IsFlyoutOpen(bars, unit) and FLYOUT_ALPHA or 1)
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
        singleNative[1] = native
        self:SuppressNative(singleNative)
    end
    self:SetLayer(editing)
    self.root:Show()
    if Addon.Input.disabled then Addon.Input:RestoreAfterError(); return true end
    if editing or self:IsEditing() then
        -- Slots only mirror the editor; its own input groups own every button. In Edit Mode the pad drives the editor,
        -- so the classic click layer is off there too.
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
