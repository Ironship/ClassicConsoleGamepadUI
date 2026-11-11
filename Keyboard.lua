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

-- Controller: while the keyboard is open in Gamepad Mode a secure header binds these buttons, the way the
-- item deletion helper does (see ItemDelete.lua), and tells this file which one was pressed. It removes its
-- bindings in combat, when addons may not change them; the bindings come back once combat ends.
local PAD_TOKENS = {
    [GAMEPAD_DPAD_TOP or "PADDUP"] = "up", [GAMEPAD_DPAD_BOTTOM or "PADDDOWN"] = "down",
    [GAMEPAD_DPAD_LEFT or "PADDLEFT"] = "left", [GAMEPAD_DPAD_RIGHT or "PADDRIGHT"] = "right",
    [GAMEPAD_FACE_BOTTOM or "PAD1"] = "a", [GAMEPAD_FACE_RIGHT or "PAD2"] = "b",
    [GAMEPAD_FACE_LEFT or "PAD3"] = "x", [GAMEPAD_FACE_TOP or "PAD4"] = "y",
    [GAMEPAD_MENU_RIGHT or "PADFORWARD"] = "start", [GAMEPAD_MENU_LEFT or "PADBACK"] = "select",
}

local PAD_BIND = [[
    self:ClearBindings()
    for i = 1, self:GetAttribute("keycount") do
        self:SetBindingClick(true, self:GetAttribute("key" .. i), self:GetAttribute("button"), self:GetAttribute("token" .. i))
    end
]]

local PAD_CLICK = [[
    self:SetAttribute("type", nil)
    if not down or control:GetAttribute("state-combat") == "1" then return false end
    control:SetAttribute("padtoken", button)
    control:SetAttribute("padcount", (control:GetAttribute("padcount") or 0) + 1)
    return false
]]

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
    local c = (pressed and { 0.45, 0.35, 0.1 }) or (key == self.sel and self.showSel and { 0.15, 0.45, 0.65 })
        or (key.active and { 0.55, 0.42, 0.1 })
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
    self.frame, self.keys, self.special = frame, {}, {}

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
            button.row, button.cx = r, x + size / 2
            if special then self.special[special] = button end
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
    frame:SetSize(width, PAD * 2 + #rows * KEY + (#rows - 1) * GAP + 24)
    local legend = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    legend:SetPoint("BOTTOM", frame, "BOTTOM", 0, 8)
    legend:SetText("D-pad: move   A: key   B: delete   X: space   Y: shift   Start: send   Back: close")
    frame:SetScript("OnUpdate", function(_, elapsed)
        self.idle = (self.idle or 0) + elapsed
        if self.idle >= 0.25 then self.idle = 0; self:SyncPad() end
    end)
    for _, key in ipairs(self.keys) do
        if key.base == "h" then self.sel = key end
    end
    self.sel = self.sel or self.keys[1]
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
    self.frame:Show()
    self:SyncPad()
    self:Refresh()
end

function Keyboard:Hide()
    if self.frame then self.frame:Hide() end
    if self.pad and self.pad:IsShown() and not InCombatLockdown() then self.pad:Hide() end
end

function Keyboard:CreatePad()
    local pad = CreateFrame("Frame", "ClassicConsoleGamepadUIKeyboardPad", UIParent,
        "SecureHandlerShowHideTemplate,SecureHandlerStateTemplate")
    pad:Hide()
    pad:SetAttribute("_onshow", PAD_BIND)
    pad:SetAttribute("_onhide", "self:ClearBindings()")
    pad:SetAttribute("_onstate-combat", [[if newstate == "1" then self:Hide() end]])
    RegisterStateDriver(pad, "combat", "[combat]1;0")
    local button = CreateFrame("Button", "ClassicConsoleGamepadUIKeyboardPadButton", pad, "SecureActionButtonTemplate")
    button:SetSize(1, 1)
    button:SetPoint("CENTER")
    button:EnableMouse(false)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("useOnKeyDown", true)
    SecureHandlerWrapScript(button, "OnClick", pad, PAD_CLICK)
    local count = 0
    for key, token in pairs(PAD_TOKENS) do
        for _, prefix in ipairs({ "", "SHIFT-", "CTRL-", "CTRL-SHIFT-" }) do
            count = count + 1
            pad:SetAttribute("key" .. count, prefix .. key)
            -- With a modifier held the press is swallowed, so it cannot reach the chat's own buttons.
            pad:SetAttribute("token" .. count, prefix == "" and token or "none")
        end
    end
    pad:SetAttribute("keycount", count)
    pad:SetAttribute("button", button:GetName())
    pad:HookScript("OnAttributeChanged", function(_, name)
        if name == "padcount" then self:PadPress(pad:GetAttribute("padtoken")) end
    end)
    self.pad = pad
end

-- Pad control follows the keyboard: on while it is shown in Gamepad Mode and out of combat.
function Keyboard:SyncPad()
    local wanted = self.frame and self.frame:IsShown() and Addon:IsGamepadMode() or false
    if wanted ~= (self.showSel or false) then
        self.showSel = wanted
        if self.sel then self:Paint(self.sel) end
    end
    if InCombatLockdown() then return end
    if wanted and not self.pad then self:CreatePad() end
    if not self.pad then return end
    if wanted and not self.pad:IsShown() then self.pad:Show()
    elseif not wanted and self.pad:IsShown() then self.pad:Hide() end
end

function Keyboard:Select(key)
    if not key then return end
    local old = self.sel
    self.sel = key
    if old then self:Paint(old) end
    self:Paint(key)
end

-- Move to the neighbouring key; up and down land on the key nearest in horizontal position.
function Keyboard:Move(direction)
    local sel = self.sel
    if not sel then return end
    if direction == "left" or direction == "right" then
        local rowKeys, index = {}, 1
        for _, key in ipairs(self.keys) do
            if key.row == sel.row then
                rowKeys[#rowKeys + 1] = key
                if key == sel then index = #rowKeys end
            end
        end
        index = index + (direction == "left" and -1 or 1)
        if index < 1 then index = #rowKeys elseif index > #rowKeys then index = 1 end
        self:Select(rowKeys[index])
        return
    end
    local rows = 0
    for _, key in ipairs(self.keys) do rows = math.max(rows, key.row) end
    local row = sel.row + (direction == "up" and -1 or 1)
    if row < 1 then row = rows elseif row > rows then row = 1 end
    local best, distance
    for _, key in ipairs(self.keys) do
        if key.row == row then
            local d = math.abs(key.cx - sel.cx)
            if not distance or d < distance then best, distance = key, d end
        end
    end
    self:Select(best)
end

function Keyboard:PadPress(token)
    if not (self.frame and self.frame:IsShown()) then return end
    if token == "up" or token == "down" or token == "left" or token == "right" then
        self:Move(token)
    elseif token == "a" then
        if self.sel then self:Press(self.sel) end
    elseif token == "b" then
        self:Press(self.special.back)
    elseif token == "x" then
        self:Press(self.special.space)
    elseif token == "y" then
        self:Press(self.special.shift)
    elseif token == "start" then
        self:Press(self.special.enter)
    elseif token == "select" then
        self:Hide()
    end
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
