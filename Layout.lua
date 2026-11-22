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
        -- Placed from the classic bars (PlaceTotemBar), so its keyboard place is not saved.
        { "MultiCastActionBarFrame", MultiCastActionBarFrame, true },
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

-- HUD.lua snapshots and restores the unit frames the same way.
Layout.Snapshot, Layout.Apply = Snapshot, Apply

function Layout:CanCaptureKeyboard()
    if InCombatLockdown() or self.active or Addon:IsGamepadMode() then return false end
    local manager = EditModeManagerFrame
    local info = manager and manager:GetActiveLayoutInfo()
    return info and info.interfaceStyle == Enum.InputDeviceInterfaceType.Mkb and not manager.layoutApplyInProgress
end

function Layout:Capture()
    if not self:CanCaptureKeyboard() then return end
    for _, entry in ipairs(Frames()) do
        local key, frame = entry[1], entry[2]
        -- Hidden bars can still carry their XML placeholder at TOPLEFT, 0, 0.
        if frame and not entry[3] and frame:IsVisible() then
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

-- The stock frames the classic layout places, each with the setting that lets it. With the setting off the frame is kept:
-- it stays where the gamepad layout's Edit Mode puts it, at the size Edit Mode gives it, so a player can make a layout of
-- their own. The settings alone decide: a layout that once moved a frame does not change the classic look.
local PLACED = {
    -- A hidden menu (hideMenu) is out of sight and is not kept anywhere.
    { "placeMenu", function() return Addon.db.hideMenu == true and {} or { MicroMenuContainer } end },
    { "placeBags", function() return { BagsBar } end },
    { "placeStatusBars", function() return { MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer } end },
}

local function KeptFrames()
    local kept = {}
    for _, entry in ipairs(PLACED) do
        if Addon.db[entry[1]] == false then
            for _, frame in ipairs(entry[2]()) do
                if frame then kept[frame] = true end
            end
        end
    end
    return kept
end

-- Whether the last layout left `frame` where Edit Mode put it (Display places nothing kept).
function Layout:Keeps(frame)
    return frame ~= nil and self.kept ~= nil and self.kept[frame] == true
end

-- A frame anchored to `from` is pinned where it is on screen, so it stays when `from` moves.
local function Unhook(frame, from)
    for i = 1, frame:GetNumPoints() do
        local _, relative = frame:GetPoint(i)
        if relative == from then
            local left, bottom = frame:GetLeft(), frame:GetBottom()
            if left and bottom then Anchor(frame, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom) end
            return
        end
    end
end

function Layout:UnhookFrom(frame)
    for _, entry in ipairs(Frames()) do
        if entry[2] and entry[2] ~= frame then Unhook(entry[2], frame) end
    end
end

local function ResizeStatus(frame, width, segments)
    frame:SetWidth(width)
    if frame.ResizeContainerBars then frame:ResizeContainerBars() end
    if frame.UpdateDividers then frame:UpdateDividers(segments) end
    if frame.UpdateBarTick then frame:UpdateBarTick() end
end

-- The key ring button of the bag bar shown with the classic bars opens the key ring as a single bag (ToggleBag_Individual),
-- which the gamepad interface does not support: ContainerFrameMixin:GetRows adds self.shownSlots, set only for the combined
-- bag, so a click ends in "attempt to perform arithmetic on field 'shownSlots'". The game's own gamepad bag bar has a key
-- ring button of its own; this one is left on screen, dimmed, and does not take clicks while the classic bars are up.
function Layout:BlockKeyRing(block)
    local button = KeyRingButton
    if not button or not button.SetMouseClickEnabled then return end
    if block then
        if self.keyRingAlpha == nil then self.keyRingAlpha = button:GetAlpha() end
        button:SetMouseClickEnabled(false)
        button:SetAlpha(0.4)
    elseif self.keyRingAlpha ~= nil then
        button:SetMouseClickEnabled(true)
        button:SetAlpha(self.keyRingAlpha)
        self.keyRingAlpha = nil
    end
end

function Layout:Prepare()
    if self.active and not self.dirty then return true end
    if InCombatLockdown() then return self.active end
    if not MainActionBar or not MicroMenu or not BagsBar then return false end
    -- A placement setting was switched: every frame goes back to its own place first, so a frame let go is measured
    -- where Edit Mode has it, not where the classic layout last put it.
    if self.releasePending then
        self.releasePending = false
        self:Restore()
    end
    -- A default status bar may have been moved out of the classic bars' way by Display. Start each rebuild from its
    -- Edit Mode position so that changing the classic layout can also remove that temporary adjustment.
    if self.active and Addon.db.placeStatusBars == false then
        for _, frame in pairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
            local snapshot = self.originals[frame]
            if frame.IsInDefaultPosition and frame:IsInDefaultPosition() and Apply(frame, snapshot) then
                ResizeStatus(frame, snapshot.width, STATUS_BAR_NUM_SEGMENTS_GAMEPAD)
            end
        end
    end
    Addon.Display.defaultStatusMoved = nil
    Addon:Trace("Layout:Prepare")
    local compact, cutWidth = Addon.db.compact, 0
    if compact then
        local buttons = MainActionBar.actionButtons
        local first, fifth = buttons[1]:GetLeft(), buttons[5]:GetLeft()
        local scale = MainActionBar:GetEffectiveScale() / UIParent:GetEffectiveScale()
        if first and fifth and fifth > first then
            cutWidth = (fifth - first) * scale
        else
            -- Gamepad mode hides the keyboard bar, so screen coordinates are unavailable.
            local width, padding = buttons[1]:GetWidth(), MainActionBar.buttonPadding
            if not width or width <= 0 then return false end
            padding = math.max(MainActionBar.minButtonPadding or 2, padding or 2)
            cutWidth = (width + padding) * 4 * scale
        end
    end
    for _, entry in ipairs(Frames()) do
        local frame = entry[2]
        if frame and not self.originals[frame] then self.originals[frame] = Snapshot(frame) end
    end
    -- Kept frames are measured before anything moves: an Edit Mode anchor can hang off a bar this rearranges.
    local kept, keptPlaces = KeptFrames(), {}
    for frame in pairs(kept) do
        local left, bottom = frame:GetLeft(), frame:GetBottom()
        if left and bottom then keptPlaces[frame] = { left, bottom, frame:GetScale(), frame:GetWidth() } end
    end
    self.kept = kept
    if not self.visibility then
        self.visibility = { [MicroMenu] = MicroMenu:IsShown(), [BagsBar] = BagsBar:IsShown() }
    end
    self:ApplyStockAnchor("MicroMenuContainer", MicroMenuContainer)
    self:ApplyStockAnchor("BagsBar", BagsBar)
    self:ApplyStockAnchor("MainActionBar", MainActionBar)
    for _, frame in ipairs({ MicroMenu, BagsBar }) do
        local show = frame.ShowBase or frame.Show
        show(frame)
    end
    self:BlockKeyRing(true)

    -- The same bottom-stack order and offsets as Camelot/EditModeUtil.lua.
    local uiScale = UIParent:GetEffectiveScale()
    local mainScale = MainActionBar:GetEffectiveScale() / uiScale
    if not mainScale or mainScale <= 0 then mainScale = 1 end
    local y = (MainActionBar:GetHeight() + BOTTOM_ACTION_BARS_SPACER_Y) * mainScale
    for _, entry in ipairs({
        { "SecondaryStatusTrackingBarContainer", SecondaryStatusTrackingBarContainer },
        { "MainStatusTrackingBarContainer", MainStatusTrackingBarContainer },
    }) do
        local frame = entry[2]
        if frame then
            -- Status bars enabled by placeStatusBars must follow the classic action bar, not a saved keyboard-layout
            -- position. A stored MKB anchor can leave the exp/reputation bar offset and narrower after layout changes.
            local frameScale = frame:GetEffectiveScale() / uiScale
            if not frameScale or frameScale <= 0 then frameScale = 1 end
            Anchor(frame, "BOTTOMLEFT", MainActionBar, "BOTTOMLEFT", 0, y / frameScale)
            ResizeStatus(frame, STATUS_BAR_CONTAINER_WIDTH * mainScale / frameScale, STATUS_BAR_NUM_SEGMENTS)
            -- A kept status bar is elsewhere: the bars above close the gap it would leave.
            if frame:IsShown() and not kept[frame] then
                local gap = frame == SecondaryStatusTrackingBarContainer
                    and MainStatusTrackingBarContainer and MainStatusTrackingBarContainer:IsShown()
                    and PRIMARY_AND_SECONDARY_STATUS_TRACKING_BAR_SPACER_Y or BOTTOM_ACTION_BARS_SPACER_Y
                y = y + frame:GetHeight() * frameScale + gap * mainScale
            end
        end
    end
    if not Apply(MultiBarBottomRight, Addon.db.keyboardBars.MultiBarBottomRight) then
        local barScale = MultiBarBottomRight:GetEffectiveScale() / uiScale
        if not barScale or barScale <= 0 then barScale = 1 end
        Anchor(MultiBarBottomRight, "BOTTOMLEFT", MainActionBar, "BOTTOMLEFT",
            ACTION_BAR_3_BOTTOM_BAR_OFFSET_X * mainScale / barScale, y / barScale)
    end
    if not Apply(MultiBarBottomLeft, Addon.db.keyboardBars.MultiBarBottomLeft) then
        local barScale = MultiBarBottomLeft:GetEffectiveScale() / uiScale
        if not barScale or barScale <= 0 then barScale = 1 end
        Anchor(MultiBarBottomLeft, "BOTTOMLEFT", MainActionBar, "BOTTOMLEFT",
            ACTION_BAR_2_BOTTOM_BAR_OFFSET_X * mainScale / barScale, y / barScale)
    end
    local caps = MainActionBar.EndCaps
    if caps then
        self:ApplyStockAnchor("LeftEndCap", caps.LeftEndCap)
        self:ApplyStockAnchor("RightEndCap", caps.RightEndCap)
    end
    if compact then
        -- Capture every stock position before moving frames that anchor to one another.
        local positions = {}
        for _, entry in ipairs({
            { MainActionBar, 1 }, { MicroMenuContainer, -1 }, { BagsBar, -1 },
            { MultiBarBottomLeft, 1 }, { MultiBarBottomRight, -1 },
            { caps and caps.LeftEndCap, 1 }, { caps and caps.RightEndCap, -1 },
            { MainStatusTrackingBarContainer, 1 }, { SecondaryStatusTrackingBarContainer, 1 },
        }) do
            local frame = entry[1]
            if frame then
                local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
                local x, bottom = frame:GetLeft(), frame:GetBottom()
                if x and bottom then
                    positions[#positions + 1] = { frame, x * scale + entry[2] * cutWidth / 2, bottom * scale }
                end
            end
        end
        for _, position in ipairs(positions) do
            local scale = position[1]:GetEffectiveScale() / UIParent:GetEffectiveScale()
            Anchor(position[1], "BOTTOMLEFT", UIParent, "BOTTOMLEFT", position[2] / scale, position[3] / scale)
        end
        for _, entry in ipairs({
            { MainStatusTrackingBarContainer }, { SecondaryStatusTrackingBarContainer },
        }) do
            local frame = entry[1]
            if frame then
                local frameScale = frame:GetEffectiveScale() / uiScale
                if not frameScale or frameScale <= 0 then frameScale = 1 end
                ResizeStatus(frame, (STATUS_BAR_CONTAINER_WIDTH * mainScale - cutWidth) / frameScale, STATUS_BAR_NUM_SEGMENTS)
            end
        end
    end
    -- Kept frames were placed from their stock anchors above like every other frame (bags can hang off the menu, so the
    -- others are measured from the classic places); now they go back where Edit Mode had them. A frame anchored to one
    -- is pinned first so it stays.
    for frame in pairs(keptPlaces) do
        for _, entry in ipairs(Frames()) do
            if entry[2] and not keptPlaces[entry[2]] then Unhook(entry[2], frame) end
        end
    end
    for frame, place in pairs(keptPlaces) do
        (frame.SetScaleBase or frame.SetScale)(frame, place[3])
        Anchor(frame, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", place[1], place[2])
        if frame == MainStatusTrackingBarContainer or frame == SecondaryStatusTrackingBarContainer then
            ResizeStatus(frame, place[4], STATUS_BAR_NUM_SEGMENTS_GAMEPAD)
        end
    end
    self.compact, self.cutWidth = compact, cutWidth
    self.active, self.dirty = true, false
    self.revision = (self.revision or 0) + 1
    return true
end

function Layout:Restore(changedMode)
    if self.active then Addon:Trace("Layout:Restore") end
    if changedMode then
        -- The client has already switched layouts; discard old-mode snapshots, but undo scales and
        -- visual/input overrides that Blizzard's layout transition does not reset.
        Addon.Display:ResetStockScales()
        if MicroMenuContainer then
            MicroMenuContainer:SetAlpha(1)
            if Addon.Display.menuUnclamped and not InCombatLockdown() then
                MicroMenuContainer:SetClampedToScreen(true)
                Addon.Display.menuUnclamped = nil
            end
        end
        if not InCombatLockdown() then
            Addon.Display:AnchorFramerate(false)
            self:BlockKeyRing(false)
        end
        self.originals, self.visibility, self.active, self.dirty = {}, nil, false, true
        Addon.Display.defaultStatusMoved = nil
        return
    end
    if InCombatLockdown() then return end
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
    -- Display:PlaceMicroMenuRight may have faded the micro menu out (setting "hideMenu").
    if MicroMenuContainer then
        MicroMenuContainer:SetAlpha(1)
        if Addon.Display.menuUnclamped then MicroMenuContainer:SetClampedToScreen(true); Addon.Display.menuUnclamped = nil end
    end
    Addon.Display:AnchorFramerate(false)
    self:BlockKeyRing(false)
    self.originals, self.visibility, self.active, self.dirty = {}, nil, false, true
    Addon.Display.stockScales = nil
    Addon.Display.defaultStatusMoved = nil
end

function Layout:SetBottomLeft(frame, x, y)
    Anchor(frame, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end

-- The Shaman's totem bar is a mouse bar that the game shows in Gamepad Mode too, in the place its gamepad layout gives
-- it (128 points up, just left of the middle), which is on top of the classic bars. The keyboard layout stacks it above
-- every other bottom bar, indented past the end cap (EditModeManager:UpdateBottomActionBarPositions); this puts it above
-- the classic bars the same way. left and top are the stack's left edge and top in UIParent points. A bar the player
-- moved in Edit Mode stays where it is; Restore puts the game's anchor back.
function Layout:PlaceTotemBar(left, top)
    local bar = MultiCastActionBarFrame
    if not bar or InCombatLockdown() or not left or not top or Addon.db.placeTotemBar == false then return end
    if type(bar.IsInDefaultPosition) ~= "function" or not bar:IsInDefaultPosition() then return end
    local ratio = UIParent:GetEffectiveScale()
    local scale = bar:GetEffectiveScale() / ratio
    if not scale or scale <= 0 then return end
    local unit = MainActionBar and MainActionBar:GetEffectiveScale() / ratio or 1
    local x = left + (BOTTOM_ACTION_BAR_DEFAULT_OFFSET_X or 30) * unit
    local y = top + (BOTTOM_ACTION_BARS_SPACER_Y or 4) * unit
    -- Never off the screen.
    x = math.max(0, math.min(x, UIParent:GetWidth() - bar:GetWidth() * scale))
    y = math.max(0, math.min(y, UIParent:GetHeight() - bar:GetHeight() * scale))
    Anchor(bar, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

function Layout:SetStatusWidth(frame, width)
    ResizeStatus(frame, width, STATUS_BAR_NUM_SEGMENTS)
end

function Layout:GetButtons()
    local buttons = {}
    for _, bar in ipairs({ MainActionBar, MultiBarBottomLeft, MultiBarBottomRight }) do
        for _, button in ipairs(bar.actionButtons) do buttons[#buttons + 1] = button end
    end
    return buttons
end

-- The first native button of each half of a row of eight. The stock order is the four face buttons (native 5-8: X, Y, B, A)
-- and then the cross (native 1-4); with the setting "crossFirst" the cross comes first. Display and Input both ask here, so a
-- slot always shows the button its click target presses.
function Layout.RowStart(secondHalf)
    local crossFirst = Addon.db and Addon.db.crossFirst == true
    if secondHalf then return crossFirst and 5 or 1 end
    return crossFirst and 1 or 5
end

function Layout:Observe()
    local function Invalidate()
        self.dirty = true
        Addon:QueueRefresh(true)
    end
    for _, entry in ipairs(Frames()) do
        local frame = entry[2]
        if frame and frame.ApplySystemAnchor then
            hooksecurefunc(frame, "ApplySystemAnchor", function()
                -- The game put the frame where its layout has it now (a saved Edit Mode move): the place to return to.
                self.originals[frame] = nil
                if Addon.Display and Addon.Display.defaultStatusMoved then
                    Addon.Display.defaultStatusMoved[frame] = nil
                end
                Invalidate()
            end)
        end
    end
    if StatusTrackingBarManager then
        hooksecurefunc(StatusTrackingBarManager, "UpdateBarsShown", Invalidate)
        hooksecurefunc(StatusTrackingBarManager, "CheckForLayoutChange", Invalidate)
    end
end

-- Convert stock geometry into UIParent coordinates; display frames never anchor to protected buttons.
function Layout:Place(target, source, owner, fallback, offsetX)
    if not source then return false end
    local x, y, w, h = source:GetRect()
    if not x or not y or not w or not h or w <= 0 or h <= 0 then
        if fallback then return self:Place(target, fallback, owner, nil, offsetX) end
        return false
    end
    local scale = source:GetEffectiveScale() / UIParent:GetEffectiveScale()
    target:ClearAllPoints()
    if owner then
        local ox, oy = owner:GetLeft(), owner:GetBottom()
        local os = owner:GetEffectiveScale() / UIParent:GetEffectiveScale()
        target:SetPoint("BOTTOMLEFT", target:GetParent(), "BOTTOMLEFT",
            x * scale - ox * os + (offsetX or 0), y * scale - oy * os)
        target:SetSize(w * scale, h * scale)
    else
        target:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x * scale + (offsetX or 0), y * scale)
        target:SetSize(w * scale, h * scale)
    end
    return true
end
