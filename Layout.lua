local _, Addon = ...
local Layout = { originals = {}, dirty = true }
Addon.Layout = Layout

local function Frames()
    local caps = MainActionBar and MainActionBar.EndCaps
    return {
        { "MicroMenuContainer", MicroMenuContainer }, { "BagsBar", BagsBar },
        { "MainActionBar", MainActionBar },
        { "SecondaryStatusTrackingBarContainer", SecondaryStatusTrackingBarContainer },
        { "MainStatusTrackingBarContainer", MainStatusTrackingBarContainer },
        { "MultiBarBottomRight", MultiBarBottomRight }, { "MultiBarBottomLeft", MultiBarBottomLeft },
        { "LeftEndCap", caps and caps.LeftEndCap }, { "RightEndCap", caps and caps.RightEndCap },
    }
end

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
    if #points > 0 then
        return { points = points, scale = frame:GetScale(), width = frame:GetWidth() }
    end
end

local function Anchor(frame, point, relative, relativePoint, x, y)
    -- Bypass Edit Mode's Lua snapping setters; do not taint its saved layout tables.
    (frame.ClearAllPointsBase or frame.ClearAllPoints)(frame);
    (frame.SetPointBase or frame.SetPoint)(frame, point, relative, relativePoint, x, y)
end

local function Apply(frame, layout)
    if not layout then return false end
    for _, point in ipairs(layout.points) do
        if type(point[2]) == "string" and not _G[point[2]] then return false end
    end
    (frame.ClearAllPointsBase or frame.ClearAllPoints)(frame)
    for _, point in ipairs(layout.points) do
        (frame.SetPointBase or frame.SetPoint)(frame, point[1],
            type(point[2]) == "string" and _G[point[2]] or point[2], point[3], point[4], point[5])
    end
    (frame.SetScaleBase or frame.SetScale)(frame, layout.scale or 1)
    return true
end

function Layout:Capture()
    if InCombatLockdown() then return end
    for _, entry in ipairs(Frames()) do
        local key, frame = entry[1], entry[2]
        if frame and not self.active then
            local snapshot = Snapshot(frame, true)
            if snapshot then Addon.db.keyboardBars[key] = snapshot end
        end
    end
end

function Layout:ApplyStockAnchor(key, frame)
    if Apply(frame, Addon.db.keyboardBars[key]) then return true end
    local map = EDIT_MODE_CLASSIC_SYSTEM_MAP
    local system = map and frame.system and map[frame.system]
    local info = system and (frame.systemIndex and system[frame.systemIndex] or system)
    local anchor = info and info.anchorInfo
    local relative = anchor and _G[anchor.relativeTo]
    if relative then
        Anchor(frame, anchor.point, relative, anchor.relativePoint, anchor.offsetX, anchor.offsetY)
        return true
    end
    return false
end

local function ResizeStatus(frame, width, segments)
    frame:SetWidth(width)
    if frame.ResizeContainerBars then frame:ResizeContainerBars() end
    if frame.UpdateDividers then frame:UpdateDividers(segments) end
end

function Layout:Prepare()
    if self.active and not self.dirty then return true end
    if InCombatLockdown() then return self.active end
    if not MainActionBar or not MicroMenu or not BagsBar then return false end
    for _, entry in ipairs(Frames()) do
        local frame = entry[2]
        if frame and not self.originals[frame] then self.originals[frame] = Snapshot(frame) end
    end
    if not self.visibility then
        self.visibility = { [MicroMenu] = MicroMenu:IsShown(), [BagsBar] = BagsBar:IsShown() }
    end
    self:ApplyStockAnchor("MicroMenuContainer", MicroMenuContainer)
    self:ApplyStockAnchor("BagsBar", BagsBar)
    self:ApplyStockAnchor("MainActionBar", MainActionBar)
    MicroMenu:Show()
    BagsBar:Show()

    -- The same bottom-stack order and offsets as Camelot/EditModeUtil.lua.
    local y = MainActionBar:GetHeight() + BOTTOM_ACTION_BARS_SPACER_Y
    for _, entry in ipairs({
        { "SecondaryStatusTrackingBarContainer", SecondaryStatusTrackingBarContainer },
        { "MainStatusTrackingBarContainer", MainStatusTrackingBarContainer },
    }) do
        local key, frame = entry[1], entry[2]
        if frame then
            if not Apply(frame, Addon.db.keyboardBars[key]) then
                Anchor(frame, "BOTTOMLEFT", MainActionBar, "BOTTOMLEFT", 0, y)
            end
            ResizeStatus(frame, STATUS_BAR_CONTAINER_WIDTH, STATUS_BAR_NUM_SEGMENTS)
            if frame:IsShown() then
                local gap = frame == SecondaryStatusTrackingBarContainer and MainStatusTrackingBarContainer:IsShown()
                    and PRIMARY_AND_SECONDARY_STATUS_TRACKING_BAR_SPACER_Y or BOTTOM_ACTION_BARS_SPACER_Y
                y = y + frame:GetHeight() + gap
            end
        end
    end
    if not Apply(MultiBarBottomRight, Addon.db.keyboardBars.MultiBarBottomRight) then
        Anchor(MultiBarBottomRight, "BOTTOMLEFT", MainActionBar, "BOTTOMLEFT", ACTION_BAR_3_BOTTOM_BAR_OFFSET_X, y)
    end
    if not Apply(MultiBarBottomLeft, Addon.db.keyboardBars.MultiBarBottomLeft) then
        Anchor(MultiBarBottomLeft, "BOTTOMLEFT", MainActionBar, "BOTTOMLEFT", ACTION_BAR_2_BOTTOM_BAR_OFFSET_X, y)
    end
    local caps = MainActionBar.EndCaps
    if caps then
        self:ApplyStockAnchor("LeftEndCap", caps.LeftEndCap)
        self:ApplyStockAnchor("RightEndCap", caps.RightEndCap)
    end
    self.active, self.dirty = true, false
    self.revision = (self.revision or 0) + 1
    return true
end

function Layout:Restore(changedMode)
    if changedMode then
        -- The client has already switched layouts; discard snapshots of the old mode.
        self.originals, self.visibility, self.active, self.dirty = {}, nil, false, true
        if not Addon:IsGamepadMode() then self.restoreKeyboard = true end
    end
    if InCombatLockdown() then return end
    if self.restoreKeyboard then
        for _, entry in ipairs(Frames()) do
            if entry[2] then Apply(entry[2], Addon.db.keyboardBars[entry[1]]) end
        end
        self.restoreKeyboard = nil
    end
    if not self.active then return end
    for frame, snapshot in pairs(self.originals) do
        Apply(frame, snapshot)
        if frame == MainStatusTrackingBarContainer or frame == SecondaryStatusTrackingBarContainer then
            ResizeStatus(frame, snapshot.width, STATUS_BAR_NUM_SEGMENTS_GAMEPAD)
        end
    end
    for frame, shown in pairs(self.visibility or {}) do
        (frame.SetShownBase or frame.SetShown)(frame, shown)
    end
    self.originals, self.visibility, self.active, self.dirty = {}, nil, false, true
end

function Layout:GetButtons()
    local buttons = {}
    for _, bar in ipairs({ MainActionBar, MultiBarBottomLeft, MultiBarBottomRight }) do
        for _, button in ipairs(bar.actionButtons) do buttons[#buttons + 1] = button end
    end
    return buttons
end

function Layout:Observe()
    local function Invalidate()
        self.dirty = true
        Addon:QueueRefresh(true)
    end
    for _, entry in ipairs(Frames()) do
        if entry[2] and entry[2].ApplySystemAnchor then hooksecurefunc(entry[2], "ApplySystemAnchor", Invalidate) end
    end
    if StatusTrackingBarManager then
        hooksecurefunc(StatusTrackingBarManager, "UpdateBarsShown", Invalidate)
        hooksecurefunc(StatusTrackingBarManager, "CheckForLayoutChange", Invalidate)
    end
end

-- Convert stock geometry into UIParent coordinates; display frames never anchor to protected buttons.
function Layout:Place(target, source, owner, fallback)
    if not source then return false end
    local x, y, w, h = source:GetRect()
    if not x or not y or not w or not h or w <= 0 or h <= 0 then
        if fallback then return self:Place(target, fallback, owner) end
        return false
    end
    local scale = source:GetEffectiveScale() / UIParent:GetEffectiveScale()
    target:ClearAllPoints()
    if owner then
        local ox, oy = owner:GetLeft(), owner:GetBottom()
        local os = owner:GetEffectiveScale() / UIParent:GetEffectiveScale()
        target:SetPoint("BOTTOMLEFT", target:GetParent(), "BOTTOMLEFT", x * scale - ox * os, y * scale - oy * os)
        target:SetSize(w * scale, h * scale)
    else
        target:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x * scale, y * scale)
        target:SetSize(w * scale, h * scale)
    end
    return true
end
