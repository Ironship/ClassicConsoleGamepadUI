local _, Addon = ...
local HUD = { originals = {} }
Addon.HUD = HUD

local function Snapshot(frame, named)
    local points = {}
    for i = 1, frame:GetNumPoints() do
        local point, relative, relativePoint, x, y = frame:GetPoint(i)
        if named then
            if relative then
                relative = relative:GetName()
                if not relative then return end
            else
                relative = "UIParent"
            end
        end
        points[#points + 1] = { point, relative, relativePoint, x, y }
    end
    if #points > 0 then return { points = points, scale = frame:GetScale() } end
end

local function Apply(frame, layout)
    if not layout then return end
    for _, point in ipairs(layout.points) do
        if type(point[2]) == "string" and not _G[point[2]] then return end
    end
    (frame.ClearAllPointsBase or frame.ClearAllPoints)(frame)
    for _, point in ipairs(layout.points) do
        (frame.SetPointBase or frame.SetPoint)(frame, point[1], type(point[2]) == "string" and _G[point[2]] or point[2], point[3], point[4], point[5])
    end
    (frame.SetScaleBase or frame.SetScale)(frame, layout.scale or 1)
end

function HUD:GetFrames()
    return { PlayerFrame, TargetFrame, FocusFrame }
end

function HUD:CaptureKeyboardLayout()
    if not Addon.Layout:CanCaptureKeyboard() then return end
    for _, frame in ipairs(self:GetFrames()) do
        if frame and frame:IsVisible() and not self.originals[frame] then
            local snapshot = Snapshot(frame, true)
            if snapshot then Addon.db.keyboardHUD[frame:GetName()] = snapshot end
        end
    end
end

function HUD:GetClassicLayout(frame)
    local saved = Addon.db.keyboardHUD[frame:GetName()]
    if saved then return saved end
    local map = EDIT_MODE_CLASSIC_SYSTEM_MAP
    local system = map and frame.system and map[frame.system]
    local info = system and (frame.systemIndex and system[frame.systemIndex] or system)
    local anchor = info and info.anchorInfo
    if anchor then
        return { points = { { anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.offsetX, anchor.offsetY } }, scale = 1 }
    end
end

-- The rectangle a frame takes up, in UIParent points: left, bottom, right, top (nil while it has no size on screen).
local function Bounds(frame)
    if not frame or type(frame.GetRect) ~= "function" or type(frame.GetEffectiveScale) ~= "function" then return end
    local x, y, width, height = frame:GetRect()
    if not x or not y or not width or not height or width <= 0 or height <= 0 then return end
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return x * scale, y * scale, (x + width) * scale, (y + height) * scale
end

local function Overlaps(a, b)
    if not a or not a[1] or not b or not b[1] then return false end
    return a[1] < b[3] and a[3] > b[1] and a[2] < b[4] and a[4] > b[2]
end

-- Everything chat covers: the selected window, its tabs and the edit box.
function HUD:ChatBounds()
    local chat = GENERAL_CHAT_DOCK and GENERAL_CHAT_DOCK.primary or ChatFrame1
    if not chat or not chat:IsShown() then return end
    local selected = GENERAL_CHAT_DOCK and FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK) or chat
    selected = selected or chat
    local rect
    for _, frame in ipairs({ chat, selected, selected.Background, selected.editBox, selected.buttonFrame, selected.dock }) do
        local left, bottom, right, top = Bounds(frame)
        if left then
            if rect then
                rect = { math.min(rect[1], left), math.min(rect[2], bottom), math.max(rect[3], right), math.max(rect[4], top) }
            else
                rect = { left, bottom, right, top }
            end
        end
    end
    return rect
end

-- What the legend can cover. The legend frame itself is a 10 by 10 anchor; its backgrounds and entries are children
-- hanging down and right from its top-left corner, and only one group of them is shown at a time (gameplay, menu,
-- targeting, modifiers: 320 to 620 wide, 130 to 188 high). The area is sized for the largest group seen so far, shown
-- or not, so the legend keeps one place instead of jumping each time another group appears, and stays put in combat
-- when it is not placed again. Returns the offsets of that area from the legend's top-left corner (right, down)
-- and its width and height, in UIParent points; nil while no child has a size.
function HUD:LegendExtent(legend)
    local legendLeft, _, _, legendTop = Bounds(legend)
    if not legendLeft then return end
    local known = self.legendArea
    local left, bottom, right, top
    if known then left, bottom, right, top = known[1], known[2], known[3], known[4] end
    for _, child in ipairs({ legend:GetChildren() }) do
        local l, b, r, t = Bounds(child)
        if l then
            l, b, r, t = l - legendLeft, b - legendTop, r - legendLeft, t - legendTop
            left, bottom = math.min(left or l, l), math.min(bottom or b, b)
            right, top = math.max(right or r, r), math.max(top or t, t)
        end
    end
    if not left then return end
    self.legendArea = { left, bottom, right, top }
    return left, -top, right - left, top - bottom
end

-- Under the player frame, as set up; when that lands on chat, above chat, then beside it, wherever the legend fits
-- on screen without covering the player, target or focus frame.
function HUD:LegendSpot(legend, x, top)
    local dx, dy, width, height = self:LegendExtent(legend)
    local chat = self:ChatBounds()
    if not dx or not chat or width <= 0 or height <= 0
        or not Overlaps({ x + dx, top - dy - height, x + dx + width, top - dy }, chat) then return x, top end
    local gap = Addon.db.legendGap
    local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
    -- left/bottom: where the covered area would start.
    local function Free(left, bottom)
        if left < 0 or bottom < 0 or left + width > screenWidth or bottom + height > screenHeight then return false end
        local rect = { left, bottom, left + width, bottom + height }
        if Overlaps(rect, chat) then return false end
        for _, frame in ipairs(self:GetFrames()) do
            if frame and frame:IsShown() and Overlaps(rect, { Bounds(frame) }) then return false end
        end
        return true
    end
    if Free(x + dx, chat[4] + gap) then return x, chat[4] + gap + height + dy end
    if Free(chat[3] + gap, top - dy - height) then return chat[3] + gap - dx, top end
    return x, top
end

function HUD:RefreshLegend(wanted)
    wanted = wanted and Addon.db.moveLegend
    local legend = GamepadPersistentInputLegend
    if not legend then return end
    if not wanted then
        if self.legendOriginal then Apply(legend, self.legendOriginal) end
        self.legendOriginal, self.legendTop, self.legendX, self.legendArea = nil, nil, nil, nil
        return
    end
    local bottom = PlayerFrame and PlayerFrame:GetBottom()
    if not bottom then return end
    local top = bottom * PlayerFrame:GetEffectiveScale() / UIParent:GetEffectiveScale() - Addon.db.legendGap
    local x = Addon.db.legendX
    x, top = self:LegendSpot(legend, x, top)
    if self.legendTop == top and self.legendX == x then return end
    self.legendOriginal = self.legendOriginal or Snapshot(legend)
    -- Its native top-left anchor overlaps the restored classic player frame.
    legend:ClearAllPoints()
    legend:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, top)
    self.legendTop, self.legendX = top, x
end

function HUD:ResetChat(changedMode)
    if self.chatOriginal and not changedMode then Apply(self.chatFrame, self.chatOriginal) end
    self.chatFrame, self.chatOriginal, self.chatBaseX, self.chatBaseY = nil, nil, nil, nil
end

function HUD:RefreshChat(wanted, changedMode)
    wanted = wanted and (Addon.db.raiseChat or Addon.db.anchorChat)
    if changedMode then self:ResetChat(true) end
    if InCombatLockdown() then return end
    -- The target is always computed from the saved base position, so a bar
    -- rebuild needs no reset; resetting made chat jump on every slider step.
    if not wanted then
        self:ResetChat()
        return
    end
    local chat = GENERAL_CHAT_DOCK and GENERAL_CHAT_DOCK.primary or ChatFrame1
    if not chat then return end
    -- Let native dragging establish a new position before applying offsets again.
    if MOVING_CHATFRAME or (chat.ResizeButton and chat.ResizeButton:GetButtonState() == "PUSHED") then
        self:ResetChat(true)
        return
    end
    if self.chatFrame and self.chatFrame ~= chat then self:ResetChat() end
    local x, y, width, height = chat:GetRect()
    if not x or not y or not width or not height or width <= 0 or height <= 0 then return end
    local uiScale = UIParent:GetEffectiveScale()
    local scale = chat:GetEffectiveScale() / uiScale
    local frameLeft, frameBottom = x * scale, y * scale
    local left, right, lowest, top = frameLeft, (x + width) * scale, frameBottom, (y + height) * scale
    if not self.chatOriginal then
        local original = Snapshot(chat)
        if not original then return end
        self.chatFrame, self.chatOriginal = chat, original
        self.chatBaseX, self.chatBaseY = frameLeft, frameBottom
    end
    local selected = GENERAL_CHAT_DOCK and FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK) or chat
    selected = selected or chat
    local function IncludeWidget(region, visibleOnly)
        -- Only real widgets. The controller footer is a mixin table: reading a
        -- missing method runs its metatable and throws "attempt to call a nil value".
        if region == nil or type(region.GetObjectType) ~= "function"
            or type(region.GetRect) ~= "function" or type(region.GetEffectiveScale) ~= "function" then return end
        if visibleOnly and not region:IsShown() then return end
        local wx, wy, ww, wh = region:GetRect()
        if not wx or not wy or not ww or not wh then return end
        local ws = region:GetEffectiveScale() / uiScale
        left, right = math.min(left, wx * ws), math.max(right, (wx + ww) * ws)
        lowest, top = math.min(lowest, wy * ws), math.max(top, (wy + wh) * ws)
    end
    -- Reserve the edit box and controller prompt row even before the player starts typing.
    -- CreatePromptedBindingFooter stores that row on the chat frame, not as a widget footer.
    IncludeWidget(selected.Background)
    IncludeWidget(selected.editBox)
    IncludeWidget(selected.buttonFrame, true)
    IncludeWidget(selected.ScrollBar, true)
    IncludeWidget(selected.FloatingChatFrameinputLegend)
    if selected.dock then
        IncludeWidget(selected.dock)
        IncludeWidget(selected.dock.FloatingChatFrameDockinputLegend)
    end
    local leftInset, bottomInset = frameLeft - left, frameBottom - lowest
    local targetX, targetY = self.chatBaseX, self.chatBaseY
    if Addon.db.anchorChat then
        targetX, targetY = Addon.db.chatLeft + leftInset, Addon.db.chatBottom + bottomInset
    end
    targetX = math.max(leftInset, math.min(targetX, UIParent:GetWidth() - (right - frameLeft)))
    local shiftX = targetX - frameLeft
    left, right = left + shiftX, right + shiftX
    local barTop = 0
    local function IncludeBar(region)
        if not region:IsShown() then return end
        local bx, by, bw, bh = region:GetRect()
        if not bx or not by or not bw or not bh then return end
        local bs = region:GetEffectiveScale() / uiScale
        if bx * bs < right and (bx + bw) * bs > left then
            barTop = math.max(barTop, (by + bh) * bs)
        end
    end
    if Addon.db.raiseChat then
        for _, slot in ipairs(Addon.Display.slots or {}) do IncludeBar(slot) end
        for _, art in ipairs(Addon.Display.art or {}) do IncludeBar(art.texture) end
        if barTop > 0 then targetY = math.max(targetY, barTop + Addon.db.chatGap + bottomInset) end
    end
    targetY = math.max(bottomInset, math.min(targetY, UIParent:GetHeight() - (top - frameBottom)))
    if math.abs(frameLeft - targetX) <= 0.5 and math.abs(frameBottom - targetY) <= 0.5 then return end
    Addon:Trace("HUD:RefreshChat move")
    Apply(chat, { points = { { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", targetX / scale, targetY / scale } }, scale = chat:GetScale() })
end

function HUD:Refresh(wanted, changedMode)
    if changedMode then
        -- The game just applied a different layout. Never restore the old mode's anchors over it.
        self.originals = {}
        self.applied = false
        self.legendOriginal, self.legendTop, self.legendX, self.legendArea = nil, nil, nil, nil
    end
    if InCombatLockdown() then self.pending = true; return end
    self.pending = false
    if wanted ~= self.applied then Addon:Trace("HUD:Refresh " .. tostring(wanted)) end
    for _, frame in ipairs(self:GetFrames()) do
        if frame then
            if wanted then
                if not self.originals[frame] then self.originals[frame] = Snapshot(frame) end
                local layout = self:GetClassicLayout(frame)
                if layout and not self.applied then Apply(frame, layout) end
            elseif self.originals[frame] then
                Apply(frame, self.originals[frame])
                self.originals[frame] = nil
            end
        end
    end
    self:RefreshLegend(wanted)
    self.applied = wanted
end

function HUD:Observe()
    for _, frame in ipairs(self:GetFrames()) do
        if frame and frame.ApplySystemAnchor then
            hooksecurefunc(frame, "ApplySystemAnchor", function()
                self.applied = false
                Addon:QueueRefresh(true)
            end)
        end
    end
end
