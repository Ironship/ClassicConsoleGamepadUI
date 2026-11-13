local _, Addon = ...
-- This addon's frames in the game's Edit Mode. The classic bars are this addon's own frames, not an Edit Mode system, so
-- the game's editor knows nothing about them, and the gamepad bar they stand in for is faded out, its selection box with
-- it. The gamepad legend is the game's, but no Edit Mode system either. While Edit Mode is open each gets a selection box
-- of the game's kind: drag it, or nudge it from its panel, to move it. A place is saved at once in this addon's saved
-- variables, the same for every Edit Mode layout; the panel's reset button (or /cgp resetbars, /cgp resetlegend) puts it
-- back.
--
-- Nothing here calls into Edit Mode: its tables stay untouched, so saving or reverting a layout is never tainted. The game
-- selecting one of its own systems is only observed (hooksecurefunc), to drop this selection.
local Mover = { list = {} }
Addon.Mover = Mover

local Fonts = Addon.Fonts
local WHITE = "Interface\\Buttons\\WHITE8X8"
local HIGHLIGHT = { 0.25, 0.65, 1 }
local SELECTED = { 1, 0.82, 0 }
-- Room around what a box covers, like the game's selection boxes.
local PAD = 4
local LIMIT = 4000

local function Text(key)
    return Addon.L[key]
end

local function Round(value)
    return math.floor(value + 0.5)
end

local function Clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

-- The cursor in UIParent points.
local function Cursor()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    return x / scale, y / scale
end

-- How far something covering left, bottom, right, top may move and stay on screen. Past an edge already, it may stay.
local function Room(left, bottom, right, top)
    return math.min(0, -left), math.max(0, UIParent:GetWidth() - right),
        math.min(0, -bottom), math.max(0, UIParent:GetHeight() - top)
end

local function Edge(frame, first, second, width, height)
    local edge = frame:CreateTexture(nil, "BORDER")
    edge:SetTexture(WHITE)
    edge:SetPoint(first)
    edge:SetPoint(second)
    if width then edge:SetWidth(width) else edge:SetHeight(height) end
    return edge
end

-- One selection box. Its spec says what it moves:
--   id, frameName, label, hint     names and text keys
--   checks                         setting keys shown as check boxes on its panel (optional)
--   Visible()                      whether the thing is up for Edit Mode at all
--   Bounds()                       left, bottom, right, top in UIParent points (nil while it has no size)
--   BeginDrag(), Drag(dx, dy), EndDrag(keep, dx, dy)   a drag, dx, dy from where it began
--   Nudge(dx, dy), Reset(), Position()                  the panel's arrows, reset button and position line
local Box = {}
Box.__index = Box

function Mover:Add(spec)
    local box = setmetatable({ spec = spec }, Box)
    self.list[#self.list + 1] = box
    self[spec.id] = box
    return box
end

function Box:Build()
    local frame = CreateFrame("Frame", self.spec.frameName, UIParent)
    -- Above the faded gamepad bar, whose own (invisible) selection box would otherwise take the clicks.
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame.fill = frame:CreateTexture(nil, "BACKGROUND")
    frame.fill:SetAllPoints()
    frame.fill:SetTexture(WHITE)
    frame.edges = {
        Edge(frame, "TOPLEFT", "TOPRIGHT", nil, 2), Edge(frame, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 2),
        Edge(frame, "TOPLEFT", "BOTTOMLEFT", 2), Edge(frame, "TOPRIGHT", "BOTTOMRIGHT", 2),
    }
    frame.label = Fonts:String(frame, "OVERLAY", "HighlightLarge")
    frame.label:SetPoint("CENTER")
    frame:SetScript("OnEnter", function() self.hover = true; self:Paint() end)
    frame:SetScript("OnLeave", function() self.hover = false; self:Paint() end)
    frame:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and not self.dragging then self:Select() end
    end)
    frame:SetScript("OnDragStart", function() self:StartDrag() end)
    frame:SetScript("OnDragStop", function() self:StopDrag(true) end)
    frame:Hide()
    self.frame = frame
    return frame
end

local ARROWS = {
    { -1, 0, "Interface\\Buttons\\UI-SpellbookIcon-PrevPage" },
    { 0, 1, "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp" },
    { 0, -1, "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown" },
    { 1, 0, "Interface\\Buttons\\UI-SpellbookIcon-NextPage" },
}

function Box:CreatePanel()
    local checks = self.spec.checks or {}
    local panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    panel:SetFrameStrata("DIALOG")
    panel:SetToplevel(true)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    local sliders = self.spec.sliders or {}
    -- Arrows and hint, then the check boxes two to a row, then the sliders, then the reset button.
    local y = -100 - math.ceil(#checks / 2) * 30
    panel:SetSize(270, 32 - y + #sliders * 44)
    if panel.SetBackdrop then
        panel:SetBackdrop({ bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        panel:SetBackdropColor(0.03, 0.03, 0.05, 0.94)
        panel:SetBackdropBorderColor(SELECTED[1], SELECTED[2], SELECTED[3], 1)
    end
    panel.title = Fonts:String(panel, "OVERLAY", "Normal")
    panel.title:SetPoint("TOP", 0, -12)
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() self:Deselect() end)
    panel.position = Fonts:String(panel, "OVERLAY", "HighlightSmall")
    panel.position:SetPoint("TOP", panel.title, "BOTTOM", 0, -6)
    for index, arrow in ipairs(ARROWS) do
        local button = CreateFrame("Button", nil, panel)
        button:SetSize(28, 28)
        button:SetPoint("TOP", panel, "TOP", (index - 2.5) * 32, -50)
        button:SetNormalTexture(arrow[3] .. "-Up")
        button:SetPushedTexture(arrow[3] .. "-Down")
        button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        button:SetScript("OnClick", function()
            local step = IsShiftKeyDown() and 10 or 1
            self:Nudge(arrow[1] * step, arrow[2] * step)
        end)
    end
    panel.hint = Fonts:String(panel, "OVERLAY", "DisableSmall")
    panel.hint:SetPoint("TOP", panel, "TOP", 0, -82)
    panel.hint:SetWidth(250)
    panel.checks = {}
    for index, key in ipairs(checks) do
        local check = CreateFrame("CheckButton", nil, panel)
        check:SetSize(24, 24)
        check:SetPoint("TOPLEFT", panel, "TOPLEFT", 16 + (index - 1) % 2 * 125, -100 - math.floor((index - 1) / 2) * 30)
        check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        check:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        check:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
        check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
        check.label = Fonts:String(check, "OVERLAY", "HighlightSmall")
        check.label:SetPoint("LEFT", check, "RIGHT", 2, 0)
        check.label:SetWidth(95)
        check.label:SetJustifyH("LEFT")
        -- The label is part of the check box for the mouse.
        check:SetHitRectInsets(0, -95, 0, 0)
        check:SetScript("OnClick", function(button)
            Addon.db[key] = button:GetChecked() and true or false
            Addon.Options:Changed(key)
        end)
        check.key = key
        panel.checks[index] = check
    end
    -- Sliders for settings with a range (Options.controls), shown as percents like the settings window's.
    panel.sliders = {}
    for _, key in ipairs(sliders) do
        local info
        for _, control in ipairs(Addon.Options.controls) do
            if control.key == key then info = control end
        end
        local label = Fonts:String(panel, "OVERLAY", "HighlightSmall")
        label:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, y - 2)
        local bar = CreateFrame("Slider", nil, panel)
        bar:SetOrientation("HORIZONTAL")
        bar:SetSize(190, 16)
        bar:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, y - 18)
        bar:SetMinMaxValues(info.min, info.max)
        bar:SetValueStep(info.step)
        if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(true) end
        bar:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        local track = bar:CreateTexture(nil, "BACKGROUND")
        track:SetTexture(WHITE)
        track:SetVertexColor(0.1, 0.1, 0.1, 1)
        track:SetPoint("LEFT")
        track:SetPoint("RIGHT")
        track:SetHeight(6)
        local value = Fonts:String(panel, "OVERLAY", "HighlightSmall")
        value:SetPoint("LEFT", bar, "RIGHT", 10, 0)
        local entry = { key = key, label = label, bar = bar }
        function entry.Show(v)
            value:SetText(math.floor(v * 100 + 0.5) .. "%")
        end
        bar:SetScript("OnValueChanged", function(_, v)
            v = tonumber(string.format("%.4f", math.floor(v / info.step + 0.5) * info.step))
            entry.Show(v)
            if entry.syncing or Addon.db[key] == v then return end
            Addon.db[key] = v
            Addon.Options:Changed(key)
        end)
        panel.sliders[#panel.sliders + 1] = entry
        y = y - 44
    end
    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(170, 22)
    reset:SetPoint("BOTTOM", 0, 10)
    Fonts:Button(reset)
    reset:SetScript("OnClick", function() self:Reset() end)
    panel.reset = reset
    panel:Hide()
    self.panel = panel
    return panel
end

-- The game's own colors: blue while Edit Mode is open, yellow once selected.
function Box:Paint()
    local frame = self.frame
    if not frame then return end
    local color = self.selected and SELECTED or HIGHLIGHT
    frame.fill:SetVertexColor(color[1], color[2], color[3], (self.hover or self.dragging) and 0.35 or 0.2)
    for _, edge in ipairs(frame.edges) do edge:SetVertexColor(color[1], color[2], color[3], 1) end
    frame.label:SetText(Text(self.spec.label))
end

function Box:UpdatePanel()
    local panel = self.panel
    if not panel or not panel:IsShown() then return end
    panel.title:SetText(Text(self.spec.label))
    panel.position:SetText(self.spec.Position())
    panel.hint:SetText(Text(self.spec.hint))
    panel.reset:SetText(Text("barsReset"))
    for _, check in ipairs(panel.checks) do
        check:SetChecked(Addon.db[check.key] and true or false)
        check.label:SetText(Text(check.key))
    end
    for _, entry in ipairs(panel.sliders) do
        entry.label:SetText(Text(entry.key))
        entry.syncing = true
        entry.bar:SetValue(Addon.db[entry.key])
        entry.Show(Addon.db[entry.key])
        entry.syncing = false
    end
    -- Above the box while there is room, else below it.
    panel:ClearAllPoints()
    local top = self.frame:GetTop()
    if top and top + panel:GetHeight() + 8 < UIParent:GetHeight() then
        panel:SetPoint("BOTTOM", self.frame, "TOP", 0, 8)
    else
        panel:SetPoint("TOP", self.frame, "BOTTOM", 0, -8)
    end
end

function Box:Select()
    -- One thing selected at a time.
    for _, other in ipairs(Mover.list) do
        if other ~= self and other.selected then other:Deselect() end
    end
    self.selected = true
    self.panel = self.panel or self:CreatePanel()
    self.panel:Show()
    self:Paint()
    self:UpdatePanel()
end

function Box:Deselect()
    self.selected = false
    if self.panel then self.panel:Hide() end
    self:Paint()
end

-- The box follows the cursor by hand rather than with StartMoving: the game's dragging clamps a frame to the screen, and
-- the bars sit flush with its bottom edge, so the box (a few points bigger) would jump as soon as it was picked up.
function Box:StartDrag()
    if InCombatLockdown() or self.dragging then return end
    local left, bottom, right, top = self.spec.Bounds()
    if not left then return end
    self:Select()
    self.startBounds = { left, bottom, right, top }
    self.startX, self.startY = Cursor()
    self.dx, self.dy = 0, 0
    self.dragging = true
    self.spec.BeginDrag()
    self:Paint()
    self.frame:SetScript("OnUpdate", function() self:Follow() end)
end

function Box:Follow()
    local bounds = self.startBounds
    local x, y = Cursor()
    local minX, maxX, minY, maxY = Room(bounds[1], bounds[2], bounds[3], bounds[4])
    self.dx, self.dy = Clamp(x - self.startX, minX, maxX), Clamp(y - self.startY, minY, maxY)
    self.spec.Drag(self.dx, self.dy)
    self.frame:ClearAllPoints()
    self.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", bounds[1] + self.dx - PAD, bounds[2] + self.dy - PAD)
    self:UpdatePanel()
end

-- keep: it stays where it was dragged (else it goes back to where the drag began).
function Box:StopDrag(keep)
    if not self.dragging then return end
    self.frame:SetScript("OnUpdate", nil)
    self.dragging, self.placed = false, nil
    self.spec.EndDrag(keep, self.dx or 0, self.dy or 0)
    self:Paint()
    self:UpdatePanel()
end

-- Moves it by dx, dy points, never past the edge of the screen.
function Box:Nudge(dx, dy)
    if InCombatLockdown() then Addon:Print(Text("notInCombat")); return end
    local left, bottom, right, top = self.spec.Bounds()
    if left then
        local minX, maxX, minY, maxY = Room(left, bottom, right, top)
        dx, dy = Clamp(dx, minX, maxX), Clamp(dy, minY, maxY)
    end
    self.spec.Nudge(dx, dy)
    self.placed = nil
    self:UpdatePanel()
end

function Box:Reset()
    if InCombatLockdown() then Addon:Print(Text("notInCombat")); return false end
    self:StopDrag(false)
    self.spec.Reset()
    self.placed = nil
    self:UpdatePanel()
    return true
end

function Box:Hide()
    if not self.frame or not self.frame:IsShown() then return end
    self:StopDrag(true)
    self:Deselect()
    self.hover, self.placed = false, nil
    self.frame:Hide()
end

function Box:Refresh(editing)
    if not editing or not self.spec.Visible() then self:Hide(); return end
    local frame = self.frame or self:Build()
    if not self.dragging then
        local left, bottom, right, top = self.spec.Bounds()
        if not left then self:Hide(); return end
        local place = Round(left) .. ":" .. Round(bottom) .. ":" .. Round(right) .. ":" .. Round(top)
        if self.placed ~= place then
            self.placed = place
            frame:ClearAllPoints()
            frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left - PAD, bottom - PAD)
            frame:SetSize(right - left + PAD * 2, top - bottom + PAD * 2)
            self:UpdatePanel()
        end
    end
    if not frame:IsShown() then
        frame:Show()
        self:Paint()
    end
end

-- Called after every refresh: the boxes are up while Edit Mode is open.
function Mover:Refresh()
    local editing = Addon.Display:IsEditing() and not InCombatLockdown()
    for _, box in ipairs(self.list) do box:Refresh(editing) end
end

function Mover:Observe()
    local manager = EditModeManagerFrame
    -- The game selected one of its own frames: only one thing is selected at a time.
    if manager and manager.SelectSystem then
        hooksecurefunc(manager, "SelectSystem", function()
            for _, box in ipairs(self.list) do
                if box.selected then box:Deselect() end
            end
        end)
    end
end

-- The classic bars: an offset (barX, barY) from the place Display computes for them. A drag moves them live
-- (Display:FollowOffset) and the rebuild after it moves chat and the totem bar along.
local function SetBarOffset(x, y)
    x, y = Clamp(Round(x), -LIMIT, LIMIT), Clamp(Round(y), -LIMIT, LIMIT)
    if x == Addon.db.barX and y == Addon.db.barY then return end
    Addon:Trace("Mover: bars")
    Addon.db.barX, Addon.db.barY = x, y
    Addon.Display:FollowOffset()
    Addon.Layout.dirty = true
    Addon:QueueRefresh(true)
end

Mover:Add({
    id = "bars", frameName = "ClassicConsoleGamepadUIMover", label = "barsEditLabel", hint = "barsNudgeHint",
    -- The gryphons, like the end caps setting of the game's own action bar.
    checks = { "showLeftCap", "showRightCap" },
    sliders = { "barScale" },
    Visible = function() return Addon.classicVisible and not Addon.Display.barEditing end,
    Bounds = function() return Addon.Display:Bounds() end,
    BeginDrag = function() end,
    Drag = function(dx, dy)
        local display = Addon.Display
        display.dragX, display.dragY = dx, dy
        display:FollowOffset()
    end,
    EndDrag = function(keep, dx, dy)
        local display = Addon.Display
        display.dragX, display.dragY = nil, nil
        if keep then SetBarOffset(Addon.db.barX + dx, Addon.db.barY + dy) else display:FollowOffset() end
    end,
    Nudge = function(dx, dy) SetBarOffset(Addon.db.barX + dx, Addon.db.barY + dy) end,
    Reset = function() SetBarOffset(0, 0) end,
    Position = function()
        local x, y = Addon.Display:GetOffset()
        return Text("barsPosition"):format(Round(x), Round(y))
    end,
})

-- The gamepad legend (GamepadPersistentInputLegend): a place of its own (legendSpot), kept by HUD:RefreshLegend.
local legendStart

Mover:Add({
    id = "legend", frameName = "ClassicConsoleGamepadUILegendMover", label = "legendEditLabel", hint = "legendNudgeHint",
    -- More hints grow it upwards from a fixed bottom edge instead of downwards from a fixed top (HUD:SaveLegendSpot).
    checks = { "legendGrowUp", "legendFrame" },
    sliders = { "legendShade" },
    Visible = function() return Addon.wanted and true or false end,
    Bounds = function() return Addon.HUD:LegendBounds() end,
    BeginDrag = function()
        legendStart = { Addon.HUD:LegendCorner() }
        Addon.HUD.legendDragging = true
    end,
    Drag = function(dx, dy)
        if legendStart and legendStart[1] then Addon.HUD:PlaceLegend(legendStart[1] + dx, legendStart[2] + dy) end
    end,
    EndDrag = function(keep, dx, dy)
        local HUD = Addon.HUD
        HUD.legendDragging = nil
        if keep and legendStart and legendStart[1] then
            HUD:SaveLegendSpot(legendStart[1] + dx, legendStart[2] + dy)
        else
            -- Back where it was: the next refresh places it again (or restores its native anchor).
            HUD.legendTop, HUD.legendX = nil, nil
            Addon:QueueRefresh(true)
        end
        legendStart = nil
    end,
    Nudge = function(dx, dy)
        local x, top = Addon.HUD:LegendCorner()
        if x then Addon.HUD:SaveLegendSpot(x + dx, top + dy) end
    end,
    Reset = function() Addon.HUD:ResetLegendSpot() end,
    Position = function()
        local spot = Addon.HUD:SavedLegendSpot()
        if not spot then return Text("legendDefaultPlace") end
        return Text(spot.anchor == "bottom" and "legendPositionUp" or "legendPosition"):format(spot.x, -spot.y)
    end,
})
