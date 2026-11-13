local _, Addon = ...
local HUD = { originals = {}, moves = {} }
Addon.HUD = HUD

local Snapshot, Apply = Addon.Layout.Snapshot, Addon.Layout.Apply

function HUD:GetFrames()
    return { PlayerFrame, TargetFrame, FocusFrame }
end

-- A hidden frame that Edit Mode has not anchored yet still carries its XML placeholder.
local function IsPlaceholder(snapshot)
    local point = snapshot.points[1]
    return #snapshot.points == 1 and point[1] == "TOPLEFT" and point[2] == "UIParent" and point[3] == "TOPLEFT"
        and (point[4] or 0) == 0 and (point[5] or 0) == 0
end

function HUD:CaptureKeyboardLayout()
    if not Addon.Layout:CanCaptureKeyboard() then return end
    for _, frame in ipairs(self:GetFrames()) do
        if frame and not self.originals[frame] then
            -- The target and focus frames are hidden most of the time; Edit Mode anchors them all the same.
            local snapshot = Snapshot(frame, true)
            if snapshot and (frame:IsVisible() or not IsPlaceholder(snapshot)) then
                Addon.db.keyboardHUD[frame:GetName()] = snapshot
            end
        end
    end
end

-- Where the classic HUD puts a unit frame: the place the player dragged it to in Edit Mode while in
-- Gamepad Mode, else its place in the keyboard/mouse layout, else the client's classic preset.
function HUD:GetClassicLayout(frame)
    local name = frame:GetName()
    local saved = self.moves[name] or Addon.db.gamepadHUD[name] or Addon.db.keyboardHUD[name]
    if saved then return saved end
    local map = EDIT_MODE_CLASSIC_SYSTEM_MAP
    local system = map and frame.system and map[frame.system]
    local info = system and (frame.systemIndex and system[frame.systemIndex] or system)
    local anchor = info and info.anchorInfo
    if anchor then
        return { points = { { anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.offsetX, anchor.offsetY } }, scale = 1 }
    end
end

-- A frame's place as one anchor to UIParent, for when it is anchored to a frame without a name.
local function ScreenSnapshot(frame)
    local left, top = frame:GetLeft(), frame:GetTop()
    if not left or not top then return end
    local ratio = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    return { points = { { "TOPLEFT", "UIParent", "TOPLEFT",
        left - (UIParent:GetLeft() or 0) * ratio, top - (UIParent:GetTop() or 0) * ratio } }, scale = frame:GetScale() }
end

-- The player moved a unit frame in Edit Mode while the classic HUD had placed it. The new place is kept
-- once the layout is saved; leaving Edit Mode without saving drops it, like every other unsaved change.
function HUD:OnUserMove(frame)
    if not self.applied or not frame or not Addon:IsGamepadMode() then return end
    for _, known in ipairs(self:GetFrames()) do
        if known == frame then
            self.moves[frame:GetName()] = Snapshot(frame, true) or ScreenSnapshot(frame)
            Addon:Trace("HUD:OnUserMove " .. frame:GetName())
            return
        end
    end
end

function HUD:CommitMoves()
    for _, moves in ipairs({ self.reverted or {}, self.moves }) do
        for name, snapshot in pairs(moves) do Addon.db.gamepadHUD[name] = snapshot end
    end
    self.moves, self.reverted = {}, nil
end

-- Saving a preset as a new layout reverts first and saves right after, in the same call:
-- the moves stay available until the end of this frame.
function HUD:DropMoves()
    if not next(self.moves) then return end
    self.reverted, self.moves = self.moves, {}
    C_Timer.After(0, function() self.reverted = nil end)
end

function HUD:ResetFrames()
    Addon.db.gamepadHUD, self.moves, self.reverted = {}, {}, nil
    self.applied = false
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

-- Where the player dragged the legend in Edit Mode (EditMode.lua): its top-left corner, in UIParent points from the
-- screen's top-left corner (y is negative), so it keeps its distance from the top on any screen height. It wins over
-- moveLegend; nil leaves the legend to moveLegend or to its native place.
-- With spot.anchor == "bottom" (legendGrowUp, "Grow upwards" in Edit Mode) y is the bottom edge of the hints instead:
-- the legend is moved so whatever hints show end there, and more hints grow it upwards.
function HUD:SavedLegendSpot()
    local spot = Addon.db.legendSpot
    if type(spot) == "table" and type(spot.x) == "number" and type(spot.y) == "number" then return spot end
end

local function GrowsUp(spot)
    return spot and spot.anchor == "bottom"
end

-- The hints showing right now (the shown children only, unlike LegendExtent): how far below the legend frame's top
-- they start and how high they are, in UIParent points. nil while nothing shown has a size.
function HUD:LegendContent(legend)
    local _, _, _, legendTop = Bounds(legend)
    if not legendTop then return end
    local bottom, top
    for _, child in ipairs({ legend:GetChildren() }) do
        if child:IsShown() then
            local _, b, _, t = Bounds(child)
            if b then bottom, top = math.min(bottom or b, b), math.max(top or t, t) end
        end
    end
    if not bottom then return end
    return legendTop - top, top - bottom
end

-- The legend frame's top-left corner, in UIParent points from the bottom-left.
function HUD:LegendCorner()
    local legend = GamepadPersistentInputLegend
    if not legend then return end
    local left, _, _, top = Bounds(legend)
    return left, top
end

-- The rectangle the legend covers (LegendExtent), in UIParent points: left, bottom, right, top.
function HUD:LegendBounds()
    local legend = GamepadPersistentInputLegend
    if not legend or not legend:IsVisible() then return end
    local left, top = self:LegendCorner()
    if not left then return end
    local dx, dy, width, height = self:LegendExtent(legend)
    if not dx or width <= 0 or height <= 0 then return end
    if GrowsUp(self:SavedLegendSpot()) then
        -- The largest set of hints, standing on the bottom edge of the ones showing.
        local below, high = self:LegendContent(legend)
        if below then
            local bottom = top - below - high
            return left + dx, bottom, left + dx + width, bottom + height
        end
    end
    return left + dx, top - dy - height, left + dx + width, top - dy
end

-- Puts the legend's top-left corner at x, top (UIParent points from the bottom-left). The first move keeps its native
-- anchor to go back to. In combat only while the legend is not protected (growing upwards follows its hints there).
function HUD:PlaceLegend(x, top)
    local legend = GamepadPersistentInputLegend
    if not legend or (InCombatLockdown() and legend:IsProtected()) then return end
    self.legendOriginal = self.legendOriginal or Snapshot(legend)
    local ratio = legend:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if not ratio or ratio <= 0 then ratio = 1 end
    legend:ClearAllPoints()
    legend:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / ratio, top / ratio)
    self.legendTop, self.legendX = top, x
end

-- Keeps the legend with its frame's top-left corner at x, top: as that corner, or, growing upwards, as the bottom edge
-- of the hints showing there.
function HUD:SaveLegendSpot(x, top)
    x, top = math.floor(x + 0.5), math.floor(top + 0.5)
    local screenTop = math.floor(UIParent:GetHeight() + 0.5)
    local spot = { x = x, y = top - screenTop }
    local legend = GamepadPersistentInputLegend
    if Addon.db.legendGrowUp and legend then
        local below, high = self:LegendContent(legend)
        if not below then
            -- Nothing showing: the bottom of the largest set seen.
            local _, dy, _, height = self:LegendExtent(legend)
            below, high = dy or 0, height or 0
        end
        spot.y, spot.anchor = math.floor(top - below - high + 0.5) - screenTop, "bottom"
    end
    Addon.db.legendSpot = spot
    Addon:Trace("HUD:SaveLegendSpot")
    self:PlaceLegend(x, top)
    Addon:QueueRefresh(true)
end

-- legendGrowUp was switched: the saved place is converted where the legend stands, so nothing jumps.
function HUD:SetLegendGrowUp()
    local x, top = self:LegendCorner()
    if x and not InCombatLockdown() then self:SaveLegendSpot(x, top) end
end

function HUD:ResetLegendSpot()
    Addon.db.legendSpot, Addon.db.legendGrowUp = nil, false
    self.legendTop, self.legendX = nil, nil
    Addon:QueueRefresh(true)
end

function HUD:RefreshLegend(wanted)
    -- An Edit Mode drag places the legend itself until it ends.
    if self.legendDragging then return end
    local legend = GamepadPersistentInputLegend
    if not legend then return end
    local spot = wanted and self:SavedLegendSpot()
    wanted = wanted and (spot or Addon.db.moveLegend)
    if not wanted then
        if self.legendOriginal then Apply(legend, self.legendOriginal) end
        self.legendOriginal, self.legendTop, self.legendX, self.legendArea = nil, nil, nil, nil
        return
    end
    local x, top
    if GrowsUp(spot) then
        local below, high = self:LegendContent(legend)
        -- Nothing showing: it stays where it is until hints come back.
        if not below then return end
        x, top = spot.x, UIParent:GetHeight() + spot.y + below + high
        -- Sub-point drift from re-measuring must not move it every frame.
        if self.legendTop and math.abs(self.legendTop - top) < 0.5 and self.legendX == x then return end
    elseif spot then
        x, top = spot.x, UIParent:GetHeight() + spot.y
    else
        local bottom = PlayerFrame and PlayerFrame:GetBottom()
        if not bottom then return end
        top = bottom * PlayerFrame:GetEffectiveScale() / UIParent:GetEffectiveScale() - Addon.db.legendGap
        x = Addon.db.legendX
        x, top = self:LegendSpot(legend, x, top)
    end
    if self.legendTop == top and self.legendX == x then return end
    -- Its native top-left anchor overlaps the restored classic player frame.
    self:PlaceLegend(x, top)
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

function HUD:Refresh(wanted, changedMode, editing)
    if changedMode then
        -- The game just applied a different layout. Never restore the old mode's anchors over it.
        self.originals = {}
        self.applied = false
        self.moves, self.reverted = {}, nil
        self.legendOriginal, self.legendTop, self.legendX, self.legendArea = nil, nil, nil, nil
    end
    if InCombatLockdown() then self.pending = true; return end
    self.pending = false
    -- The unit frames keep their classic places in Edit Mode, so they can be dragged from there.
    local frames = wanted and Addon.db.moveUnitFrames or false
    if frames ~= self.applied then Addon:Trace("HUD:Refresh " .. tostring(frames)) end
    for _, frame in ipairs(self:GetFrames()) do
        if frame then
            if frames then
                if not self.originals[frame] then self.originals[frame] = Snapshot(frame) end
                local layout = self:GetClassicLayout(frame)
                if layout and not self.applied then Apply(frame, layout) end
            elseif self.originals[frame] then
                Apply(frame, self.originals[frame])
                self.originals[frame] = nil
            end
        end
    end
    -- In Edit Mode the legend keeps a place the player dragged it to there, so it can be dragged again.
    self.legendWanted = wanted and (not editing or self:SavedLegendSpot() ~= nil) or false
    self:RefreshLegend(self.legendWanted)
    -- The frame and shade options hold wherever the legend is, Edit Mode included.
    self.legendStyleWanted = wanted and true or false
    self:ApplyLegendStyle()
    self.applied = frames
end

-- The legend's own art: its gold frame and its dark shade (legendFrame, legendShade). The legend is the game's, built
-- from templates this addon cannot read, so its art is found by the names the templates give their pieces: the corners
-- and edges of a nine-slice or anything called a border are the frame, a nine-slice's Center or anything called a
-- background, backdrop or shade is the shade. Named pieces must be large enough to be a frame or a shade, so the small
-- glyphs of the hints are never touched; the unnamed pieces of a frame named like that take its kind. Only alpha
-- changes (textures are never protected, so in combat too), from the alpha each piece had when it was found, and every
-- piece gets that alpha back when the options return to their defaults. /cgp legend lists what was found.
local NINE_SLICE = { TopLeftCorner = true, TopRightCorner = true, BottomLeftCorner = true, BottomRightCorner = true,
    TopEdge = true, BottomEdge = true, LeftEdge = true, RightEdge = true }

-- A widget's table carries its userdata at [0]; mixin tables without one can throw on a missing method.
local function IsWidget(value)
    return type(value) == "table" and type(rawget(value, 0)) == "userdata"
end

local function ArtKind(key, region)
    if NINE_SLICE[key] then return "border" end
    if key == "Center" then return "shade" end
    local lower = key:lower()
    local width, height = region:GetWidth() or 0, region:GetHeight() or 0
    if lower:find("border") then return (width >= 60 or height >= 60) and "border" or nil end
    if lower:find("background") or lower:find("backdrop") or lower:find("shade") or lower == "bg" or key:find("^Bg%u") then
        return (width >= 60 and height >= 40) and "shade" or nil
    end
end

local function FrameKind(key)
    local lower = key:lower()
    if key == "NineSlice" or lower:find("border") then return "border" end
    if lower:find("background") or lower:find("backdrop") or lower:find("shade") then return "shade" end
end

-- Records the art under frame into art (texture -> { kind, alpha, name }); log, when given, gets every texture seen.
local function WalkLegend(frame, inherited, art, seen, depth, path, log)
    if seen[frame] or depth > 6 then return end
    seen[frame] = true
    local named, frames = {}, {}
    for key, value in pairs(frame) do
        if type(key) == "string" and value ~= frame and IsWidget(value) then
            if value:IsObjectType("Texture") then
                named[value] = key
                local kind = ArtKind(key, value)
                if kind and not art[value] then
                    art[value] = { kind = kind, alpha = value:GetAlpha(), name = path .. "." .. key }
                end
            elseif value:IsObjectType("Frame") then
                frames[value] = key
            end
        end
    end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") then
            if inherited and not named[region] and not art[region] then
                art[region] = { kind = inherited, alpha = region:GetAlpha(), name = path .. ".?" }
            end
            if log then
                local info = art[region]
                log[#log + 1] = string.format("%s.%s %dx%d %s%s", path, named[region] or "?",
                    math.floor((region:GetWidth() or 0) + 0.5), math.floor((region:GetHeight() or 0) + 0.5),
                    info and info.kind or "-", region:IsVisible() and "" or " (hidden)")
            end
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        local key = frames[child]
        WalkLegend(child, key and FrameKind(key) or inherited, art, seen, depth + 1, path .. "." .. (key or "?"), log)
    end
end

function HUD:ScanLegendArt()
    local legend = GamepadPersistentInputLegend
    if not legend then return end
    self.legendArt = self.legendArt or setmetatable({}, { __mode = "k" })
    self.legendScanned = self.legendScanned or setmetatable({}, { __mode = "k" })
    -- Marked first: a scan that fails is not tried again every frame.
    for _, child in ipairs({ legend:GetChildren() }) do
        if child:IsShown() and (child:GetWidth() or 0) > 0 then self.legendScanned[child] = true end
    end
    WalkLegend(legend, nil, self.legendArt, {}, 0, "legend")
end

local function LegendStyleDefault()
    return Addon.db.legendFrame ~= false and (Addon.db.legendShade or 1) >= 1
end

-- Puts the frame and shade options on the legend's art. A set of hints showing for the first time is scanned first.
function HUD:ApplyLegendStyle()
    local styled = self.legendStyleWanted and not LegendStyleDefault()
    if not styled then
        if self.legendStyled then
            for region, info in pairs(self.legendArt or {}) do region:SetAlpha(info.alpha) end
            self.legendArt, self.legendScanned = nil, nil
            Addon:Trace("HUD:ApplyLegendStyle restore")
        end
        self.legendStyled = false
        return
    end
    local legend = GamepadPersistentInputLegend
    if not legend then return end
    local fresh = not self.legendArt
    if not fresh then
        for _, child in ipairs({ legend:GetChildren() }) do
            if child:IsShown() and not self.legendScanned[child] then fresh = true; break end
        end
    end
    if fresh then
        local ok, err = pcall(self.ScanLegendArt, self)
        if not ok then Addon:Note("HUD:ScanLegendArt", err) end
    end
    local frameAlpha = Addon.db.legendFrame ~= false and 1 or 0
    local shade = math.max(0, math.min(1, Addon.db.legendShade or 1))
    for region, info in pairs(self.legendArt or {}) do
        local target = info.alpha * (info.kind == "border" and frameAlpha or shade)
        if math.abs(region:GetAlpha() - target) > 0.001 then region:SetAlpha(target) end
    end
    self.legendStyled = true
end

-- /cgp legend: every texture of the legend, with the kind given to it (border, shade or -), for when the options miss.
function HUD:DescribeLegend()
    local legend = GamepadPersistentInputLegend
    if not legend then return { "no GamepadPersistentInputLegend" } end
    local log = {}
    local ok, err = pcall(WalkLegend, legend, nil, {}, {}, 0, "legend", log)
    if not ok then log[#log + 1] = "error: " .. tostring(err) end
    return log
end

-- Growing upwards, the legend moves as soon as its hints change (a new set shows in the same frame as the event that
-- brings it, before the screen is drawn), in combat too. Cheap: a handful of child rectangles per frame, and only then.
function HUD:WatchLegend()
    local watcher = CreateFrame("Frame")
    watcher:SetScript("OnUpdate", function()
        if self.legendWanted and not self.legendDragging and GrowsUp(self:SavedLegendSpot()) then
            self:RefreshLegend(true)
        end
        -- A new set of hints shows with the game's art: it gets the frame and shade options before it is drawn.
        if self.legendStyled then self:ApplyLegendStyle() end
    end)
end

function HUD:Observe()
    self:WatchLegend()
    for _, frame in ipairs(self:GetFrames()) do
        if frame and frame.ApplySystemAnchor then
            hooksecurefunc(frame, "ApplySystemAnchor", function()
                -- The game put the frame back where its own layout has it: that is the place to
                -- return to, and the classic place goes on top of it again.
                self.originals[frame] = nil
                self.applied = false
                Addon:QueueRefresh(true)
            end)
        end
    end
    local manager = EditModeManagerFrame
    if not manager then return end
    if manager.OnSystemPositionChange then
        hooksecurefunc(manager, "OnSystemPositionChange", function(_, frame) self:OnUserMove(frame) end)
    end
    if manager.SaveLayouts then hooksecurefunc(manager, "SaveLayouts", function() self:CommitMoves() end) end
    if manager.RevertAllChanges then hooksecurefunc(manager, "RevertAllChanges", function() self:DropMoves() end) end
end
