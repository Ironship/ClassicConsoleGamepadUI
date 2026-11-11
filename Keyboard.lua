local _, Addon = ...
-- An on-screen keyboard for typing in chat. The game has none in Gamepad Mode and an addon cannot open the
-- system's. The keys act on the active chat edit box with plain edit box calls (Insert, SetText, SendMessage);
-- nothing native is replaced and no protected frame is touched, so it is also safe to leave open in combat.
local Keyboard = {}
Addon.Keyboard = Keyboard

local KEY, GAP, PAD = 40, 3, 10

local SHIFTED = {
    ["`"] = "~", ["1"] = "!", ["2"] = "@", ["3"] = "#", ["4"] = "$", ["5"] = "%", ["6"] = "^", ["7"] = "&",
    ["8"] = "*", ["9"] = "(", ["0"] = ")", ["-"] = "_", ["="] = "+", ["["] = "{", ["]"] = "}", ["\\"] = "|",
    [";"] = ":", ["'"] = "\"", [","] = "<", ["."] = ">", ["/"] = "?",
    ["ä"] = "Ä", ["ö"] = "Ö", ["ü"] = "Ü", ["ß"] = "ß",
}

local function Rows()
    local rows = {
        { "`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", { "back", 80 } },
        { "q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "[", "]", "\\" },
        { "a", "s", "d", "f", "g", "h", "j", "k", "l", ";", "'" },
        { { "shift", 80 }, "z", "x", "c", "v", "b", "n", "m", ",", ".", "/" },
        { { "close", 70 }, { "clear", 70 }, { "space", 280 }, { "enter", 100 } },
    }
    if GetLocale() == "deDE" then
        rows[2][6], rows[4][2] = "z", "y"
        table.insert(rows[3], "ä"); table.insert(rows[3], "ö")
        table.insert(rows[4], "ü"); table.insert(rows[4], "ß")
    end
    return rows
end

local OFFSETS = { 0, 20, 30, 0, 0 }

local function ChatFunction(name, legacy)
    local namespace = _G.ChatFrameUtil
    return (namespace and namespace[name]) or _G[legacy]
end

-- The edit box that has the chat line open, opening chat when none is.
local function EditBox()
    local active = ChatFunction("GetActiveWindow", "ChatEdit_GetActiveWindow")
    local box = active and active()
    if not box then
        local open = ChatFunction("OpenChat", "ChatFrame_OpenChat")
        if open then open("") end
        box = active and active()
    end
    if box and not box:HasFocus() then box:SetFocus() end
    return box
end

function Keyboard:Label(key)
    if key.special then return key.label end
    if not self.shift then return key.base end
    return SHIFTED[key.base] or key.base:upper()
end

function Keyboard:Refresh()
    for _, key in ipairs(self.keys) do
        key.text:SetText(self:Label(key))
        key.active = key.special == "shift" and self.shift or false
        self:Paint(key)
    end
end

function Keyboard:Paint(key, pressed)
    local c = (pressed and { 0.45, 0.35, 0.1 }) or (key.active and { 0.55, 0.42, 0.1 })
        or (key.hover and { 0.28, 0.28, 0.3 }) or { 0.12, 0.12, 0.14 }
    key.bg:SetColorTexture(c[1], c[2], c[3], 0.95)
end

function Keyboard:Press(key)
    local special = key.special
    if special == "shift" then
        self.shift = not self.shift
        self:Refresh()
        return
    elseif special == "close" then
        self:Hide()
        return
    end
    local box = EditBox()
    if not box then return end
    if special == "back" then
        local text = box:GetText() or ""
        -- Remove one whole UTF-8 character.
        box:SetText((text:gsub("[%z\1-\127\194-\244][\128-\191]*$", "")))
    elseif special == "clear" then
        box:SetText("")
    elseif special == "space" then
        box:Insert(" ")
    elseif special == "enter" then
        if box.SendMessage then box:SendMessage() end
        if self.auto then self:Hide() end
        return
    else
        box:Insert(self:Label(key))
    end
    if self.shift and not special then
        self.shift = false
        self:Refresh()
    end
end

function Keyboard:Create()
    local frame = CreateFrame("Frame", "ClassicConsoleGamepadUIKeyboard", UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local point, _, relativePoint, x, y = f:GetPoint(1)
        Addon.db.keyboardPos = { point, relativePoint, x, y }
    end)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.8)
    self.frame, self.keys = frame, {}

    local rows, width = Rows(), 0
    for r, row in ipairs(rows) do
        local x = PAD + OFFSETS[r]
        for _, entry in ipairs(row) do
            local special = type(entry) == "table" and entry[1] or nil
            local size = special and entry[2] or KEY
            local button = CreateFrame("Button", nil, frame)
            button:SetSize(size, KEY)
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -(PAD + (r - 1) * (KEY + GAP)))
            button.bg = button:CreateTexture(nil, "BACKGROUND")
            button.bg:SetAllPoints()
            button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
            button.text:SetPoint("CENTER")
            button.special, button.base = special, not special and entry or nil
            if special then
                button.label = ({ back = "<-", shift = "Shift", close = "X", clear = "Clear", space = "Space",
                    enter = "Enter" })[special]
            end
            button:SetScript("OnEnter", function() button.hover = true; self:Paint(button) end)
            button:SetScript("OnLeave", function() button.hover = false; self:Paint(button) end)
            button:SetScript("OnMouseDown", function() self:Paint(button, true) end)
            button:SetScript("OnMouseUp", function() self:Paint(button) end)
            button:SetScript("OnClick", function() self:Press(button) end)
            self.keys[#self.keys + 1] = button
            x = x + size + GAP
        end
        width = math.max(width, x - GAP + PAD)
    end
    frame:SetSize(width, PAD * 2 + #rows * KEY + (#rows - 1) * GAP)
    local saved = Addon.db.keyboardPos
    frame:ClearAllPoints()
    if type(saved) == "table" and saved[1] then
        frame:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
    else
        frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 260)
    end
    frame:Hide()
    self:Refresh()
end

function Keyboard:Show(auto)
    if not self.frame then self:Create() end
    self.auto = auto and true or false
    self.shift = false
    self:Refresh()
    self.frame:Show()
end

function Keyboard:Hide()
    if self.frame then self.frame:Hide() end
end

function Keyboard:Toggle()
    if self.frame and self.frame:IsShown() then self:Hide() else self:Show(false) end
end

-- Optionally open with the chat line, only in Gamepad Mode where there is no other way to type.
function Keyboard:Observe()
    if not EventRegistry or not EventRegistry.RegisterCallback then return end
    EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusGained", function()
        if Addon.db.autoKeyboard and Addon:IsGamepadMode()
            and not (self.frame and self.frame:IsShown()) then
            self:Show(true)
        end
    end, self)
end
