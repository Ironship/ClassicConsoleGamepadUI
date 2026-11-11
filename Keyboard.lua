local _, Addon = ...
-- An on-screen keyboard for typing in chat. The game has none in Gamepad Mode and an addon cannot open the
-- system's. The keys act on the active chat edit box with plain edit box calls (Insert, SetText, SendMessage);
-- nothing native is replaced and no protected frame is touched, so it is also safe to leave open in combat.
-- Layouts: "abc" (full keyboard), "t9" (phone keypad, multi-tap) and "t9p" (phone keypad with word suggestions).
local Keyboard = {}
Addon.Keyboard = Keyboard

local KEY, GAP, PAD = 40, 3, 10

-- Saved with every blocked-action report, so the report shows what the keyboard did just before.
local function Trace(message)
    if Addon.Trace then Addon:Trace(message) end
end

local SHIFTED = {
    ["`"] = "~", ["1"] = "!", ["2"] = "@", ["3"] = "#", ["4"] = "$", ["5"] = "%", ["6"] = "^", ["7"] = "&",
    ["8"] = "*", ["9"] = "(", ["0"] = ")", ["-"] = "_", ["="] = "+", ["["] = "{", ["]"] = "}", ["\\"] = "|",
    [";"] = ":", ["'"] = "\"", [","] = "<", ["."] = ">", ["/"] = "?",
    ["ä"] = "Ä", ["ö"] = "Ö", ["ü"] = "Ü", ["ß"] = "ß",
}

-- A key of the phone layouts: the digit, and the characters its presses cycle through.
local function T(digit, chars) return { digit = digit, chars = chars, width = 110, height = 48 } end
local function Special(name, width) return { name, width, height = 48 } end

local function Rows(mode)
    local de = GetLocale() == "deDE"
    if mode == "t9" or mode == "t9p" then
        local rows = {
            { T("1", { ".", ",", "'", "?", "!", "-", "/", "@", "1" }),
                T("2", de and { "a", "b", "c", "ä", "2" } or { "a", "b", "c", "2" }), T("3", { "d", "e", "f", "3" }) },
            { T("4", { "g", "h", "i", "4" }), T("5", { "j", "k", "l", "5" }),
                T("6", de and { "m", "n", "o", "ö", "6" } or { "m", "n", "o", "6" }) },
            { T("7", de and { "p", "q", "r", "s", "ß", "7" } or { "p", "q", "r", "s", "7" }),
                T("8", de and { "t", "u", "v", "ü", "8" } or { "t", "u", "v", "8" }), T("9", { "w", "x", "y", "z", "9" }) },
            { Special("shift", 110), T("0", { " ", "0" }), Special("back", 110) },
            { Special("close", 80), Special("clear", 80), Special("mode", 80), Special("predict", 80), Special("enter", 110) },
        }
        if mode == "t9p" then
            local suggestions = {}
            for i = 1, 5 do suggestions[i] = { cand = i, width = 100, height = KEY } end
            table.insert(rows, 1, suggestions)
        end
        return rows, { 0, 0, 0, 0, 0, 0 }
    end
    local rows = {
        { "`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", { "back", 80 } },
        { "q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "[", "]", "\\" },
        { "a", "s", "d", "f", "g", "h", "j", "k", "l", ";", "'" },
        { { "shift", 80 }, "z", "x", "c", "v", "b", "n", "m", ",", ".", "/" },
        { { "close", 70 }, { "clear", 70 }, { "mode", 60 }, { "space", 220 }, { "enter", 100 } },
    }
    if de then
        rows[2][6], rows[4][2] = "z", "y"
        table.insert(rows[3], "ä"); table.insert(rows[3], "ö")
        table.insert(rows[4], "ü"); table.insert(rows[4], "ß")
    end
    return rows, { 0, 20, 30, 0, 0 }
end

local MIN_WIDTH, LEGEND_HEIGHT = 560, 58
local LEGENDS = {
    abc = "D-pad: move   A: key   B: close   X: send   Y: space   LT: shift   RT: delete   Start: done",
    t9 = "D-pad: move   A: press (again: next letter)   B: close   X: send   Y: space   LT: shift   RT: delete   Start: done",
    t9p = "D-pad: move   A: key   Y: accept word   LB/RB: other word   RT: delete   X: send   B: close   LT: capital   Start: done",
}

-- Controller: while the keyboard is open in Gamepad Mode a secure header binds these buttons, the way the
-- item deletion helper does (see ItemDelete.lua), and tells this file which one was pressed. It removes its
-- bindings in combat, when addons may not change them; the bindings come back once combat ends.
local PAD_TOKENS = {
    [GAMEPAD_DPAD_TOP or "PADDUP"] = "up", [GAMEPAD_DPAD_BOTTOM or "PADDDOWN"] = "down",
    [GAMEPAD_DPAD_LEFT or "PADDLEFT"] = "left", [GAMEPAD_DPAD_RIGHT or "PADDRIGHT"] = "right",
    [GAMEPAD_FACE_BOTTOM or "PAD1"] = "a", [GAMEPAD_FACE_RIGHT or "PAD2"] = "b",
    [GAMEPAD_FACE_LEFT or "PAD3"] = "x", [GAMEPAD_FACE_TOP or "PAD4"] = "y",
    [GAMEPAD_MENU_RIGHT or "PADFORWARD"] = "start", [GAMEPAD_MENU_LEFT or "PADBACK"] = "select",
    [GAMEPAD_SHOULDER_LEFT or "PADLSHOULDER"] = "previous", [GAMEPAD_SHOULDER_RIGHT or "PADRSHOULDER"] = "next",
    [GAMEPAD_TRIGGER_LEFT or "PADLTRIGGER"] = "shift", [GAMEPAD_TRIGGER_RIGHT or "PADRTRIGGER"] = "delete",
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

-- The edit box that has the chat line open. Opening, focusing or sending the chat line from here would run
-- the game's chat focus and gamepad binding code inside this addon's call, and the bindings it sets up would
-- be tainted: opening the game menu in combat is then blocked. The player opens and sends the line natively.
local function FindEditBox()
    local active = ChatFunction("GetActiveWindow", "ChatEdit_GetActiveWindow")
    local box = active and active()
    if box then return box end
    -- The game may not report its chat line as the active one in Gamepad Mode: take any open one.
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local candidate = _G["ChatFrame" .. i .. "EditBox"]
        if candidate and candidate:IsShown() and candidate.HasFocus and candidate:HasFocus() then return candidate end
    end
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local candidate = _G["ChatFrame" .. i .. "EditBox"]
        if candidate and candidate:IsShown() then return candidate end
    end
end

local function EditBox()
    local box = FindEditBox()
    if not box then
        Trace("Keyboard: no open chat line")
        Keyboard:UpdateStatus()
        local now = GetTime()
        if not Keyboard.noticeTime or now - Keyboard.noticeTime > 3 then
            Keyboard.noticeTime = now
            Addon:Print("Open the chat line first (Enter or the chat button), then use the keyboard.")
        end
    end
    return box
end

-- A line on the keyboard itself that tells whether there is a chat line to type into.
function Keyboard:UpdateStatus()
    if not self.status then return end
    local open = FindEditBox()
    -- A keyboard that opened by itself with the chat line goes away with it.
    if not open and self.auto and self.frame and self.frame:IsShown() and GetTime() - (self.shownAt or 0) > 1 then
        self:Hide()
        return
    end
    if open then
        self.status:SetText("")
    else
        self.status:SetText("No chat line is open: open it first (Enter or the chat button)")
    end
end

local function Upper(text)
    return (text:upper():gsub("ä", "Ä"):gsub("ö", "Ö"):gsub("ü", "Ü"):gsub("ą", "Ą"):gsub("ć", "Ć"):gsub("ę", "Ę")
        :gsub("ł", "Ł"):gsub("ń", "Ń"):gsub("ó", "Ó"):gsub("ś", "Ś"):gsub("ź", "Ź"):gsub("ż", "Ż"))
end

local function CapitalizeFirst(text)
    local first = text:match("^[%z\1-\127\194-\244][\128-\191]*")
    if not first then return text end
    return Upper(first) .. text:sub(#first + 1)
end

local function WithoutLastCharacter(text)
    -- One whole UTF-8 character.
    return (text:gsub("[%z\1-\127\194-\244][\128-\191]*$", ""))
end

local SPECIAL_LABELS = { back = "<-", shift = "Shift", close = "X", clear = "Clear", space = "Space", enter = "Done" }

function Keyboard:Label(key)
    if key.cand then
        local pred = self.pred
        local word = pred and pred.cands[key.cand]
        return word and (pred.cap and CapitalizeFirst(word) or word) or ""
    end
    if key.special == "mode" then return self.mode == "abc" and "T9" or "ABC" end
    if key.special == "predict" then return self.mode == "t9p" and "Tap" or "Smart" end
    if key.special then return SPECIAL_LABELS[key.special] end
    if key.chars then return key.digit .. "\n" .. (self.shift and Upper(key.hint) or key.hint) end
    if not self.shift then return key.base end
    return SHIFTED[key.base] or key.base:upper()
end

function Keyboard:Refresh()
    local pred = self.pred
    for _, key in ipairs(self.keys) do
        key.text:SetText(self:Label(key))
        key.active = (key.special == "shift" and (self.shift or (pred and pred.cap))) or
            (key.cand and pred and pred.idx == key.cand) or false
        self:Paint(key)
    end
end

function Keyboard:Paint(key, pressed)
    local c = (pressed and { 0.45, 0.35, 0.1 }) or (key == self.sel and self.showSel and { 0.15, 0.45, 0.65 })
        or (key.active and { 0.55, 0.42, 0.1 })
        or (key.hover and { 0.28, 0.28, 0.3 }) or { 0.12, 0.12, 0.14 }
    key.bg:SetColorTexture(c[1], c[2], c[3], 0.95)
end

-- Multi-tap: a key's characters take turns while it is pressed again within a second; any other key
-- or a pause starts the next character.
local TAP_SECONDS = 1.0
function Keyboard:Tap(box, key)
    local now, text, tap = GetTime(), box:GetText() or "", self.tap
    local chars = key.chars
    local index, upper, base
    if tap and tap.key == key and now - tap.time < TAP_SECONDS and text == tap.text then
        index, upper, base = tap.index % #chars + 1, tap.upper, WithoutLastCharacter(text)
    else
        index, upper, base = 1, self.shift, text
        if self.shift then self.shift = false; self:Refresh() end
    end
    local character = chars[index]
    if upper then character = Upper(character) end
    box:SetText(base .. character)
    self.tap = { key = key, index = index, upper = upper, time = now, text = box:GetText() or "" }
end

-- Suggestions: the keys pressed so far stand for a word, shown in the chat line as the best match. The
-- other matches are in the top row; LB/RB or a click picks one. A space, a punctuation key, Enter or a
-- chosen suggestion accepts the word and teaches it to the word list.
function Keyboard:ShowWord(box)
    local pred = self.pred
    local word = pred.cands[pred.idx] or ""
    if pred.cap then word = CapitalizeFirst(word) end
    pred.shown = word
    box:SetText(pred.prefix .. word)
    self:Refresh()
end

function Keyboard:Commit()
    local pred = self.pred
    if not pred then return end
    self.pred = nil
    if not pred.fallback and pred.shown and pred.shown ~= "" then Addon.Words:Learn(pred.shown, 1) end
    self:Refresh()
end

function Keyboard:Lookup(pred)
    pred.cands = Addon.Words:Lookup(pred.digits, 5)
    pred.fallback = #pred.cands == 0
    if pred.fallback then pred.cands = { Addon.Words.Fallback(pred.digits) } end
    pred.idx = 1
end

function Keyboard:Predict(box, key)
    local text, pred = box:GetText() or "", self.pred
    -- The line changed behind our back (typed on a keyboard, sent, cleared): a new word starts here.
    if pred and text ~= pred.prefix .. pred.shown then pred = nil end
    if not pred then
        pred = { prefix = text, digits = "", idx = 1, shown = "", cands = {}, cap = self.shift }
        if self.shift then self.shift = false end
        self.pred = pred
    end
    pred.digits = pred.digits .. key.digit
    self:Lookup(pred)
    self:ShowWord(box)
end

function Keyboard:Cycle(step)
    local pred = self.pred
    if not pred or #pred.cands < 2 then return end
    local box = EditBox()
    if not box then return end
    pred.idx = (pred.idx - 1 + step) % #pred.cands + 1
    self:ShowWord(box)
end

function Keyboard:Choose(index)
    local pred = self.pred
    if not pred or not pred.cands[index] then return end
    local box = EditBox()
    if not box then return end
    pred.idx = index
    self:ShowWord(box)
    self:Commit()
    box:Insert(" ")
end

-- Delete: one pressed key of the word in progress, else one character of the line.
function Keyboard:Delete(box)
    local pred = self.pred
    if pred and (box:GetText() or "") == pred.prefix .. pred.shown then
        if #pred.digits > 1 then
            pred.digits = pred.digits:sub(1, -2)
            self:Lookup(pred)
            self:ShowWord(box)
        else
            box:SetText(pred.prefix)
            self.pred = nil
            self:Refresh()
        end
        return
    end
    self.pred = nil
    box:SetText(WithoutLastCharacter(box:GetText() or ""))
end

function Keyboard:Press(key)
    local special = key.special
    Trace("Keyboard:Press " .. tostring(special or key.base or key.digit or key.cand))
    if special == "shift" then
        local pred = self.pred
        if pred then
            -- A word in progress: capital letter or not.
            pred.cap = not pred.cap
            local box = EditBox()
            if box then self:ShowWord(box) end
        else
            self.shift = not self.shift
            self:Refresh()
        end
        return
    elseif special == "close" then
        self:Hide()
        return
    elseif special == "mode" then
        self:SetMode(self.mode == "abc" and (Addon.db.keyboardPhone or "t9") or "abc")
        return
    elseif special == "predict" then
        self:SetMode(self.mode == "t9p" and "t9" or "t9p")
        return
    elseif key.cand then
        self:Choose(key.cand)
        return
    end
    local box = EditBox()
    if not box then return end
    if self.mode == "t9p" and key.digit then
        local digit = key.digit
        if digit == "0" then
            self:Commit()
            self.tap = nil
            box:Insert(" ")
        elseif digit == "1" then
            self:Commit()
            self:Tap(box, key)
        else
            self.tap = nil
            self:Predict(box, key)
        end
        return
    end
    if key.chars then
        self:Tap(box, key)
        return
    end
    self.tap = nil
    if special == "back" then
        self:Delete(box)
        return
    end
    self:Commit()
    if special == "clear" then
        box:SetText("")
    elseif special == "space" then
        box:Insert(" ")
    elseif special == "enter" then
        -- Done typing: the game's own send button (A, or Enter) sends the line.
        self:Hide()
        return
    else
        box:Insert(self:Label(key))
    end
    if self.shift and not special then
        self.shift = false
        self:Refresh()
    end
end

-- The buttons of one layout, built once and shown or hidden when the mode changes.
function Keyboard:Build(mode)
    local frame = self.frame
    local rows, offsets = Rows(mode)
    local phone = mode ~= "abc"
    local set = { keys = {}, special = {} }
    local widths, total = {}, 0
    for r, row in ipairs(rows) do
        local w = -GAP
        for _, entry in ipairs(row) do w = w + (type(entry) == "table" and (entry.width or entry[2]) or KEY) + GAP end
        widths[r] = w
    end
    local widest = 0
    for _, w in ipairs(widths) do widest = math.max(widest, w) end
    local width = math.max(MIN_WIDTH, widest + PAD * 2)
    local y = PAD
    for r, row in ipairs(rows) do
        local x = phone and (width - widths[r]) / 2 or (PAD + offsets[r])
        local rowHeight = KEY
        for _, entry in ipairs(row) do
            local isTable = type(entry) == "table"
            local special = isTable and not entry.chars and not entry.cand and entry[1] or nil
            local size = isTable and (entry.width or entry[2]) or KEY
            local height = isTable and entry.height or KEY
            rowHeight = math.max(rowHeight, height)
            local button = CreateFrame("Button", nil, frame)
            button:SetSize(size, height)
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
            button.bg = button:CreateTexture(nil, "BACKGROUND")
            button.bg:SetAllPoints()
            button.text = button:CreateFontString(nil, "OVERLAY",
                (isTable and (entry.chars or entry.cand)) and "GameFontHighlight" or "GameFontHighlightLarge")
            button.text:SetPoint("CENTER")
            button.special = special
            if isTable and entry.chars then
                button.chars, button.digit = entry.chars, entry.digit
                local hint = {}
                for _, c in ipairs(entry.chars) do
                    if c ~= entry.digit then hint[#hint + 1] = c == " " and "space" or c end
                end
                button.hint = table.concat(hint)
            elseif isTable and entry.cand then
                button.cand = entry.cand
            elseif not special then
                button.base = entry
            end
            button.row, button.cx = r, x + size / 2
            if special then set.special[special] = button end
            button:SetScript("OnEnter", function() button.hover = true; self:Paint(button) end)
            button:SetScript("OnLeave", function() button.hover = false; self:Paint(button) end)
            button:SetScript("OnMouseDown", function() self:Paint(button, true) end)
            button:SetScript("OnMouseUp", function() self:Paint(button) end)
            button:SetScript("OnClick", function() self:Press(button) end)
            button:Hide()
            set.keys[#set.keys + 1] = button
            if (phone and button.digit == "5") or button.base == "h" then set.home = button end
            x = x + size + GAP
        end
        total = total + rowHeight + GAP
        y = y + rowHeight + GAP
    end
    set.width, set.height = width, PAD * 2 + total - GAP + LEGEND_HEIGHT
    set.home = set.home or set.keys[1]
    return set
end

function Keyboard:Apply(mode)
    self:Commit()
    self.mode = mode
    self.sets = self.sets or {}
    for _, set in pairs(self.sets) do
        for _, key in ipairs(set.keys) do key:Hide() end
    end
    local set = self.sets[mode]
    if not set then
        set = self:Build(mode)
        self.sets[mode] = set
    end
    self.keys, self.special, self.sel, self.tap, self.pred, self.shift = set.keys, set.special, set.home, nil, nil, false
    for _, key in ipairs(set.keys) do key:Show() end
    self.frame:SetSize(set.width, set.height)
    self.legend:SetWidth(set.width - PAD * 2)
    self.legend:SetText(LEGENDS[mode])
    self:Refresh()
end

function Keyboard:SetMode(mode)
    if mode ~= "t9" and mode ~= "t9p" then mode = "abc" end
    Addon.db.keyboardMode = mode
    -- The phone layout to come back to from the full keyboard.
    if mode ~= "abc" then Addon.db.keyboardPhone = mode end
    if self.frame then self:Apply(mode) end
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
    self.frame = frame
    self.legend = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.legend:SetPoint("BOTTOM", frame, "BOTTOM", 0, 8)
    self.legend:SetJustifyH("CENTER")
    self.status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.status:SetPoint("BOTTOM", frame, "BOTTOM", 0, 36)
    self.status:SetTextColor(1, 0.35, 0.3)
    frame:SetScript("OnUpdate", function(_, elapsed)
        self.idle = (self.idle or 0) + elapsed
        if self.idle >= 0.25 then self.idle = 0; self:SyncPad(); self:UpdateStatus() end
    end)
    local saved = Addon.db.keyboardPos
    frame:ClearAllPoints()
    if type(saved) == "table" and saved[1] then
        frame:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
    else
        frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 260)
    end
    frame:Hide()
    local mode = Addon.db.keyboardMode
    self:Apply((mode == "t9" or mode == "t9p") and mode or "abc")
end

function Keyboard:Show(auto)
    Trace("Keyboard:Show")
    if not self.frame then self:Create() end
    self.auto = auto and true or false
    self.shownAt = GetTime()
    self.shift, self.tap, self.pred = false, nil, nil
    self.frame:Show()
    self:SyncPad()
    self:UpdateStatus()
    self:Refresh()
end

function Keyboard:Hide()
    Trace("Keyboard:Hide")
    self.pred = nil
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
    if wanted and not self.pad:IsShown() then Trace("Keyboard pad on"); self.pad:Show()
    elseif not wanted and self.pad:IsShown() then Trace("Keyboard pad off"); self.pad:Hide() end
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

-- Send the line with the chat's own send function, called through securecallfunction so that the game's
-- chat code (it closes the line and rewires the pad bindings) does not run with this addon's taint.
function Keyboard:Send()
    local box = EditBox()
    if not box then return end
    self:Commit()
    self.tap = nil
    Trace("Keyboard:Send")
    if box.SendMessage then
        if securecallfunction then securecallfunction(box.SendMessage, box) else box:SendMessage() end
    end
    self:Hide()
end

function Keyboard:ZeroKey()
    for _, key in ipairs(self.keys) do
        if key.digit == "0" then return key end
    end
end

function Keyboard:PadPress(token)
    if not (self.frame and self.frame:IsShown()) then return end
    if token == "up" or token == "down" or token == "left" or token == "right" then
        self:Move(token)
    elseif token == "a" then
        if self.sel then self:Press(self.sel) end
    elseif token == "b" or token == "select" then
        self:Hide()
    elseif token == "x" then
        self:Send()
    elseif token == "delete" then
        self:Press(self.special.back)
    elseif token == "y" then
        -- Smart T9: take the word shown (and add the space). Elsewhere: a space; the phone layouts spell it with 0.
        if self.mode == "t9p" and self.pred and self.pred.cands[self.pred.idx] then
            self:Choose(self.pred.idx)
        elseif self.special.space then
            self:Press(self.special.space)
        elseif self.mode == "t9p" then
            self:Press(self:ZeroKey())
        else
            local box = EditBox()
            if box then self.tap = nil; box:Insert(" ") end
        end
    elseif token == "shift" then
        self:Press(self.special.shift)
    elseif token == "start" then
        self:Press(self.special.enter)
    elseif token == "previous" then
        self:Cycle(-1)
    elseif token == "next" then
        self:Cycle(1)
    end
end

function Keyboard:Toggle()
    if self.frame and self.frame:IsShown() then self:Hide() else self:Show(false) end
end

-- Optionally open with the chat line, only in Gamepad Mode where there is no other way to type. Not while the
-- game is still loading in: the chat line is set up (and may report focus) at login without the player.
function Keyboard:Observe()
    if not EventRegistry or not EventRegistry.RegisterCallback then return end
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_ENTERING_WORLD")
    loader:SetScript("OnEvent", function() self.worldTime = GetTime() end)
    EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusGained", function()
        if not (Addon.db.autoKeyboard and Addon:IsGamepadMode()) then return end
        if not self.worldTime or GetTime() - self.worldTime < 5 then return end
        if self.frame and self.frame:IsShown() then return end
        if FindEditBox() then self:Show(true) end
    end, self)
end
