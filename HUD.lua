local _, Addon = ...
local HUD = { originals = {} }
Addon.HUD = HUD

local function Snapshot(frame, named)
    local points = {}
    for i = 1, frame:GetNumPoints() do
        local point, relative, relativePoint, x, y = frame:GetPoint(i)
        if named then
            relative = relative and relative:GetName() or "UIParent"
            if not relative then return end
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
    frame:ClearAllPoints()
    for _, point in ipairs(layout.points) do
        frame:SetPoint(point[1], type(point[2]) == "string" and _G[point[2]] or point[2], point[3], point[4], point[5])
    end
    frame:SetScale(layout.scale or 1)
end

function HUD:GetFrames()
    return { PlayerFrame, TargetFrame, FocusFrame }
end

function HUD:CaptureKeyboardLayout()
    if InCombatLockdown() then return end
    for _, frame in ipairs(self:GetFrames()) do
        if frame and not self.originals[frame] then
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

function HUD:Refresh(wanted, changedMode)
    if changedMode then
        -- The game just applied a different layout. Never restore the old mode's anchors over it.
        self.originals = {}
        self.applied = false
        self.restoreKeyboard = not Addon:IsGamepadMode()
    end
    if InCombatLockdown() then self.pending = true; return end
    self.pending = false
    for _, frame in ipairs(self:GetFrames()) do
        if frame then
            if self.restoreKeyboard then Apply(frame, Addon.db.keyboardHUD[frame:GetName()]) end
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
    self.applied = wanted
    self.restoreKeyboard = false
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
