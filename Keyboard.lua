local _, Addon = ...
-- An on-screen keyboard for typing in chat. The game has none in Gamepad Mode and an addon cannot open the
-- system's. The keys act on the active chat edit box with plain edit box calls (Insert, SetText, SendMessage);
-- nothing native is replaced and no protected frame is touched, so it is also safe to leave open in combat.
-- Layouts: "abc" (full keyboard) and the phone keypad: "t9" (multi-tap), "t9p" (smart: one press per key, words
-- suggested) and "t9h" (hybrid: multi-tap letters, suggestions complete the word).
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

-- Keyboard languages: the full layout (QWERTY, QWERTZ for German) and the letters under the phone keys.
local LANGUAGES = { "EN", "DE", "PL" }

local PHONE_LETTERS = {
    EN = { ["2"] = "abc", ["3"] = "def", ["4"] = "ghi", ["5"] = "jkl", ["6"] = "mno", ["7"] = "pqrs", ["8"] = "tuv",
        ["9"] = "wxyz" },
    DE = { ["2"] = { "a", "b", "c", "ä" }, ["3"] = "def", ["4"] = "ghi", ["5"] = "jkl", ["6"] = { "m", "n", "o", "ö" },
        ["7"] = { "p", "q", "r", "s", "ß" }, ["8"] = { "t", "u", "v", "ü" }, ["9"] = "wxyz" },
    PL = { ["2"] = { "a", "ą", "b", "c", "ć" }, ["3"] = { "d", "e", "ę", "f" }, ["4"] = "ghi",
        ["5"] = { "j", "k", "l", "ł" }, ["6"] = { "m", "n", "ń", "o", "ó" }, ["7"] = { "p", "q", "r", "s", "ś" },
        ["8"] = "tuv", ["9"] = { "w", "x", "y", "z", "ź", "ż" } },
}

-- The letters of a phone key as a list of characters, ending with its digit.
local function Letters(language, digit)
    local letters = PHONE_LETTERS[language][digit]
    local chars = {}
    if type(letters) == "string" then
        for letter in letters:gmatch(".") do chars[#chars + 1] = letter end
    else
        for _, letter in ipairs(letters) do chars[#chars + 1] = letter end
    end
    chars[#chars + 1] = digit
    return chars
end

local function Rows(mode, language)
    if mode ~= "abc" then
        local rows = {
            { T("1", { ".", ",", "'", "?", "!", "-", "/", "@", "1" }), T("2", Letters(language, "2")),
                T("3", Letters(language, "3")) },
            { T("4", Letters(language, "4")), T("5", Letters(language, "5")), T("6", Letters(language, "6")) },
            { T("7", Letters(language, "7")), T("8", Letters(language, "8")), T("9", Letters(language, "9")) },
            { Special("shift", 110), T("0", { " ", "0" }), Special("back", 110) },
            { Special("close", 80), Special("clear", 80), Special("mode", 80), Special("enter", 110) },
        }
        if mode ~= "t9" then
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
    local offsets = { 0, 20, 30, 0, 0 }
    if language == "DE" then
        rows[2][6], rows[4][2] = "z", "y"
        table.insert(rows[3], "ä"); table.insert(rows[3], "ö")
        table.insert(rows[4], "ü"); table.insert(rows[4], "ß")
    elseif language == "PL" then
        table.insert(rows, 5, { "ą", "ć", "ę", "ł", "ń", "ó", "ś", "ź", "ż" })
        offsets = { 0, 20, 30, 0, 40, 0 }
    end
    return rows, offsets
end

function Keyboard:Language()
    local saved = Addon.db and Addon.db.keyboardLanguage
    for _, language in ipairs(LANGUAGES) do
        if saved == language then return language end
    end
    return "EN"
end

function Keyboard:SetLanguage(language)
    if not PHONE_LETTERS[language] then return end
    Addon.db.keyboardLanguage = language
    if self.frame then self:Apply(self.mode) end
end

function Keyboard:NextLanguage()
    local current = self:Language()
    for i, language in ipairs(LANGUAGES) do
        if language == current then
            self:SetLanguage(LANGUAGES[i % #LANGUAGES + 1])
            return
        end
    end
end

local MIN_WIDTH, STATUS_HEIGHT, LEGEND_ROW, PREVIEW_HEIGHT = 560, 16, 24, 28

-- The button prompts under the keys: an icon of the pad button and what it does.
local LEGENDS = {
    abc = { { "dpad", "Move" }, { "A", "Key" }, { "X", "Send" }, { "B", "Close" }, { "Y", "Space" },
        { "LT", "Shift" }, { "RT", "Delete" }, { "Start", "Done" } },
    t9 = { { "dpad", "Move" }, { "A", "Press (again: next letter)" }, { "RB", "Next letter" },
        { "Y", "Accept word" }, { "X", "Send" }, { "B", "Close" }, { "LT", "Shift" }, { "RT", "Delete" },
        { "Start", "Done" } },
    t9h = { { "dpad", "Move" }, { "A", "Letter (again: next)" }, { "Y", "Accept" }, { "LB", "Previous word" },
        { "RB", "Next word" }, { "X", "Send" }, { "B", "Close" }, { "LT", "Shift" }, { "RT", "Delete" },
        { "Start", "Done" } },
    t9p = { { "dpad", "Move" }, { "A", "Key" }, { "Y", "Accept word" }, { "LB", "Previous word" },
        { "RB", "Next word" }, { "X", "Send" }, { "B", "Close" }, { "LT", "Capital" }, { "RT", "Delete" },
        { "Start", "Done" } },
}

local WHITE = "Interface\\Buttons\\WHITE8X8"
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local FACE = {
    A = { 0.4, 0.85, 0.4 }, B = { 1, 0.4, 0.35 }, X = { 0.45, 0.65, 1 }, Y = { 1, 0.85, 0.25 },
}

local function Circle(frame, size, r, g, b)
    local texture = frame:CreateTexture(nil, "ARTWORK")
    texture:SetSize(size, size)
    texture:SetPoint("CENTER")
    texture:SetTexture(WHITE)
    texture:SetVertexColor(r, g, b)
    if frame.CreateMaskTexture and texture.AddMaskTexture then
        local mask = frame:CreateMaskTexture()
        mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(texture)
        texture:AddMaskTexture(mask)
    end
    return texture
end

-- An icon for a pad button: a round face button, the D-pad cross, or a small plate for shoulders, triggers and
-- Start. Returns the icon frame and its width.
local function Icon(parent, name)
    local icon = CreateFrame("Frame", nil, parent)
    local width = 22
    if FACE[name] then
        Circle(icon, 22, 0.6, 0.6, 0.62)
        Circle(icon, 19, 0.07, 0.07, 0.08)
        local text = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("CENTER", 0, 0)
        text:SetText(name)
        text:SetTextColor(FACE[name][1], FACE[name][2], FACE[name][3])
    elseif name == "dpad" then
        for _, size in ipairs({ { 18, 7 }, { 7, 18 } }) do
            local bar = icon:CreateTexture(nil, "ARTWORK")
            bar:SetSize(size[1], size[2])
            bar:SetPoint("CENTER")
            bar:SetTexture(WHITE)
            bar:SetVertexColor(0.7, 0.7, 0.72)
        end
        local dot = icon:CreateTexture(nil, "OVERLAY")
        dot:SetSize(3, 3)
        dot:SetPoint("CENTER")
        dot:SetTexture(WHITE)
        dot:SetVertexColor(0.1, 0.1, 0.1)
    else
        width = name == "Start" and 38 or 28
        local edge = icon:CreateTexture(nil, "BACKGROUND")
        edge:SetAllPoints()
        edge:SetTexture(WHITE)
        edge:SetVertexColor(0.6, 0.6, 0.62)
        local inner = icon:CreateTexture(nil, "ARTWORK")
        inner:SetPoint("TOPLEFT", 1, -1)
        inner:SetPoint("BOTTOMRIGHT", -1, 1)
        inner:SetTexture(WHITE)
        inner:SetVertexColor(0.07, 0.07, 0.08)
        local text = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("CENTER", 0, 0)
        text:SetText(name)
        text:SetTextColor(0.9, 0.9, 0.9)
    end
    icon:SetSize(width, (name == "dpad" or FACE[name]) and 22 or 16)
    return icon, width
end

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
        local cands, _, cap = self:Candidates()
        local word = cands[key.cand]
        return word and (cap and CapitalizeFirst(word) or word) or ""
    end
    if key.special == "mode" then return self.mode == "abc" and "T9" or "ABC" end
    if key.special then return SPECIAL_LABELS[key.special] end
    if key.chars then return key.digit .. "\n" .. (self.shift and Upper(key.hint) or key.hint) end
    if not self.shift then return key.base end
    return SHIFTED[key.base] or Upper(key.base)
end

function Keyboard:Refresh()
    local pred = self.pred
    for _, key in ipairs(self.keys) do
        key.text:SetText(self:Label(key))
        key.active = (key.special == "shift" and (self.shift or (pred and pred.cap))) or
            (key.cand and select(2, self:Candidates()) == key.cand) or false
        self:Paint(key)
    end
end

-- Gold edge on the selected key, brown fill when pressed or switched on.
function Keyboard:Paint(key, pressed)
    local selected = key == self.sel and self.showSel
    local bg, edge = { 0.1, 0.08, 0.06 }, { 0.5, 0.45, 0.35 }
    if pressed then bg, edge = { 0.45, 0.33, 0.08 }, { 1, 0.82, 0 }
    elseif selected then bg, edge = { 0.3, 0.22, 0.05 }, { 1, 0.82, 0 }
    elseif key.active then bg, edge = { 0.38, 0.28, 0.05 }, { 0.9, 0.72, 0.1 }
    elseif key.hover then bg, edge = { 0.2, 0.17, 0.12 }, { 0.8, 0.7, 0.45 } end
    if key.SetBackdropColor then
        key:SetBackdropColor(bg[1], bg[2], bg[3], 0.95)
        key:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
    elseif key.bg then
        key.bg:SetColorTexture(bg[1], bg[2], bg[3], 0.95)
    end
end

-- The phone layouts compose a word in a buffer of their own, shown in the strip above the keys. Nothing
-- reaches the chat line until the word is accepted (Y, the 0 key, X to send, Done), so the chat never sees
-- half-typed letters.
-- The suggestion buttons: the matches of the smart layout, or of the hybrid layout's typed letters; which one
-- is chosen (0: none, the typed letters stay); whether the word is capitalised.
function Keyboard:Candidates()
    local pred, hints = self.pred, self.hints
    if pred then return pred.cands, pred.idx, pred.cap end
    if hints then return hints.cands, hints.idx, hints.cap end
    return {}, 0, false
end

function Keyboard:Pending()
    local pred, hints = self.pred, self.hints
    if pred then return pred.shown or "" end
    if hints and hints.idx > 0 then
        local word = hints.cands[hints.idx]
        return hints.cap and CapitalizeFirst(word) or word
    end
    return self.buffer or ""
end

-- Hybrid layout: matches for the letters typed so far.
function Keyboard:UpdateHints()
    local hints = { cands = {}, idx = 0, cap = false }
    local buffer = self.buffer or ""
    if self.mode == "t9h" and buffer ~= "" then
        hints.cands = Addon.Words:Prefix(buffer, 5)
        local first = buffer:match("^[%z\1-\127\194-\244][\128-\191]*")
        hints.cap = first ~= nil and first ~= first:lower() and Upper(first) == first
    end
    self.hints = hints
    if self.keys then self:Refresh() end
    self:ShowPreview()
end

function Keyboard:ShowPreview()
    if not self.preview then return end
    local text = self:Pending()
    if text == "" then
        if self.mode == "t9p" then
            self.preview:SetText("|cff888888Smart: press each key once, LB/RB changes the word, Y accepts|r")
        elseif self.mode == "t9h" then
            self.preview:SetText("|cff888888Hybrid: tap the letters, LB/RB picks a suggestion, Y accepts|r")
        else
            self.preview:SetText("|cff888888Tap: press a key again for its next letter, RB ends a letter, Y accepts|r")
        end
    elseif self.pred and self.pred.fallback then
        self.preview:SetText(text .. "|cffffd100_|r  |cffff9933no word matches: the Smart key switches to Tap|r")
    else
        self.preview:SetText(text .. "|cffffd100_|r")
    end
end

-- Multi-tap: a key's characters take turns while it is pressed again within a moment; a move to another key,
-- another key or a pause starts the next character.
local TAP_SECONDS = 1.5
function Keyboard:Tap(key)
    local now, tap = GetTime(), self.tap
    local buffer, chars = self.buffer or "", key.chars
    local index, upper, base
    if tap and tap.key == key and now - tap.time < TAP_SECONDS and buffer ~= "" then
        index, upper, base = tap.index % #chars + 1, tap.upper, WithoutLastCharacter(buffer)
    else
        index, upper, base = 1, self.shift, buffer
        if self.shift then self.shift = false; self:Refresh() end
    end
    local character = chars[index]
    if upper then character = Upper(character) end
    self.buffer = base .. character
    self.tap = { key = key, index = index, upper = upper, time = now }
    self:UpdateHints()
end

-- Suggestions: the keys pressed so far stand for a word, shown in the strip as the best match. The other
-- matches are in the top row; LB/RB or a click picks one. Accepting teaches the word to the word list.
function Keyboard:ShowWord()
    local pred = self.pred
    local word = pred.cands[pred.idx] or ""
    if pred.cap then word = CapitalizeFirst(word) end
    pred.shown = word
    self:ShowPreview()
    self:Refresh()
end

-- Put the word in progress into the chat line, with a space after it if wanted. Without a word, the space alone.
-- False when there is no chat line to put it in (the word stays in the buffer).
function Keyboard:Flush(space)
    local text = self:Pending()
    if text == "" and not space then return true end
    local box = EditBox()
    if not box then return false end
    local pred = self.pred
    if pred then
        if not pred.fallback and pred.shown ~= "" then Addon.Words:Learn(pred.shown, 1) end
    elseif text:find("%a") then
        Addon.Words:Learn(text, 1)
    end
    self.pred, self.buffer, self.tap = nil, "", nil
    box:Insert(text .. (space and " " or ""))
    self:UpdateHints()
    return true
end

function Keyboard:Discard()
    self.pred, self.buffer, self.tap = nil, "", nil
    self:UpdateHints()
end

function Keyboard:Lookup(pred)
    pred.cands = Addon.Words:Lookup(pred.digits, 5)
    pred.fallback = #pred.cands == 0
    if pred.fallback then pred.cands = { Addon.Words.Fallback(pred.digits) } end
    pred.idx = 1
end

function Keyboard:Predict(key)
    local pred = self.pred
    if not pred then
        pred = { digits = "", idx = 1, shown = "", cands = {}, cap = self.shift }
        if self.shift then self.shift = false end
        self.pred = pred
    end
    pred.digits = pred.digits .. key.digit
    self:Lookup(pred)
    self:ShowWord()
end

function Keyboard:Cycle(step)
    local pred, hints = self.pred, self.hints
    if pred then
        if #pred.cands < 2 then return end
        pred.idx = (pred.idx - 1 + step) % #pred.cands + 1
        self:ShowWord()
    elseif hints and #hints.cands > 0 then
        -- 0 is the letters as typed, then the suggestions.
        hints.idx = (hints.idx + step) % (#hints.cands + 1)
        self:ShowPreview()
        self:Refresh()
    end
end

function Keyboard:Choose(index)
    local cands = self:Candidates()
    if not cands[index] then return end
    if self.pred then
        self.pred.idx = index
        self:ShowWord()
    else
        self.hints.idx = index
    end
    self:Flush(true)
end

-- Delete: one pressed key of the word in progress, else one character of the buffer, else of the chat line.
function Keyboard:Delete()
    local pred = self.pred
    if pred then
        if #pred.digits > 1 then
            pred.digits = pred.digits:sub(1, -2)
            self:Lookup(pred)
            self:ShowWord()
        else
            self.pred = nil
            self:ShowPreview()
            self:Refresh()
        end
        return
    end
    self.tap = nil
    if (self.buffer or "") ~= "" then
        self.buffer = WithoutLastCharacter(self.buffer)
        self:UpdateHints()
        return
    end
    local box = EditBox()
    if box then box:SetText(WithoutLastCharacter(box:GetText() or "")) end
end

function Keyboard:Press(key)
    local special = key.special
    Trace("Keyboard:Press " .. tostring(special or key.base or key.digit or key.cand))
    if special == "shift" then
        local pred = self.pred
        if pred then
            -- A word in progress: capital letter or not.
            pred.cap = not pred.cap
            self:ShowWord()
        else
            self.shift = not self.shift
            self:Refresh()
        end
        return
    elseif special == "close" then
        self:Hide()
        return
    elseif special == "mode" then
        self:SetMode(self.mode == "abc" and (Addon.db.keyboardPhone or "t9h") or "abc")
        return

    elseif key.cand then
        self:Choose(key.cand)
        return
    elseif special == "back" then
        self:Delete()
        return
    elseif special == "clear" then
        local had = self:Pending() ~= ""
        self:Discard()
        self:Refresh()
        if not had then
            local box = EditBox()
            if box then box:SetText("") end
        end
        return
    elseif special == "enter" then
        -- Done typing: the word goes to the chat line, the game's own send button (A, or Enter) sends it.
        if self:Flush(false) then self:Hide() end
        return
    end
    if self.mode ~= "abc" and key.digit then
        if self.mode == "t9p" and key.digit == "0" then
            self:Flush(true)
        elseif self.mode == "t9p" and key.digit ~= "1" then
            self.tap = nil
            if (self.buffer or "") ~= "" and not self:Flush(false) then return end
            self:Predict(key)
        else
            -- Multi-tap (and the punctuation key of the smart layout): a word in progress goes to the chat first.
            if self.pred and not self:Flush(false) then return end
            self:Tap(key)
        end
        return
    end
    local box = EditBox()
    if not box then return end
    if special == "space" then
        box:Insert(" ")
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
    local rows, offsets = Rows(mode, self:Language())
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
    local y = PAD + (phone and PREVIEW_HEIGHT + GAP or 0)
    for r, row in ipairs(rows) do
        local x = phone and (width - widths[r]) / 2 or (PAD + offsets[r])
        local rowHeight = KEY
        for _, entry in ipairs(row) do
            local isTable = type(entry) == "table"
            local special = isTable and not entry.chars and not entry.cand and entry[1] or nil
            local size = isTable and (entry.width or entry[2]) or KEY
            local height = isTable and entry.height or KEY
            rowHeight = math.max(rowHeight, height)
            local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
            button:SetSize(size, height)
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
            if button.SetBackdrop then
                button:SetBackdrop({ bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
                    insets = { left = 2, right = 2, top = 2, bottom = 2 } })
            else
                button.bg = button:CreateTexture(nil, "BACKGROUND")
                button.bg:SetAllPoints()
            end
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
    -- Button prompts, in as many rows as the width needs, each row centred.
    local legend = CreateFrame("Frame", nil, frame)
    local rowsOfEntries, row, used, available = {}, {}, 0, width - PAD * 2
    for _, entry in ipairs(LEGENDS[mode]) do
        local icon, iconWidth = Icon(legend, entry[1])
        local label = legend:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetText(entry[2])
        local labelWidth = tonumber(label:GetStringWidth()) or 60
        local item = { icon = icon, label = label, width = iconWidth + 4 + labelWidth }
        if used > 0 and used + 14 + item.width > available then
            rowsOfEntries[#rowsOfEntries + 1] = row
            row, used = {}, 0
        end
        used = used + (used > 0 and 14 or 0) + item.width
        row[#row + 1] = item
    end
    rowsOfEntries[#rowsOfEntries + 1] = row
    for r, items in ipairs(rowsOfEntries) do
        local rowWidth = -14
        for _, item in ipairs(items) do rowWidth = rowWidth + item.width + 14 end
        local left = (width - rowWidth) / 2
        local rowY = PAD + 4 + (#rowsOfEntries - r) * LEGEND_ROW + LEGEND_ROW / 2
        for _, item in ipairs(items) do
            item.icon:SetPoint("LEFT", frame, "BOTTOMLEFT", left, rowY)
            item.label:SetPoint("LEFT", item.icon, "RIGHT", 4, 0)
            left = left + item.width + 14
        end
    end
    legend:Hide()
    set.legend, set.legendHeight = legend, #rowsOfEntries * LEGEND_ROW
    set.phone = phone
    set.width, set.height = width, PAD * 2 + total - GAP + (phone and PREVIEW_HEIGHT + GAP or 0) + STATUS_HEIGHT
        + set.legendHeight + 4
    set.home = set.home or set.keys[1]
    return set
end

function Keyboard:Apply(mode)
    -- Switching layouts: a word in progress goes to the chat line if there is one, else it is dropped.
    if self.frame and self:Pending() ~= "" and not (FindEditBox() and self:Flush(false)) then self:Discard() end
    self.mode = mode
    self.sets = self.sets or {}
    for _, set in pairs(self.sets) do
        for _, key in ipairs(set.keys) do key:Hide() end
        set.legend:Hide()
    end
    local id = mode .. "/" .. self:Language()
    local set = self.sets[id]
    if not set then
        set = self:Build(mode)
        self.sets[id] = set
    end
    self.keys, self.special, self.sel, self.tap, self.pred, self.shift = set.keys, set.special, set.home, nil, nil, false
    self.buffer = ""
    self:UpdateHints()
    for _, key in ipairs(set.keys) do key:Show() end
    self.frame:SetSize(set.width, set.height)
    set.legend:Show()
    self.previewFrame:SetShown(set.phone)
    self:ShowPreview()
    self.status:ClearAllPoints()
    self.status:SetPoint("BOTTOM", self.frame, "BOTTOM", 0, PAD + 4 + set.legendHeight)
    self:Refresh()
end

function Keyboard:SetMode(mode)
    if mode ~= "t9" and mode ~= "t9p" and mode ~= "t9h" then mode = "abc" end
    Addon.db.keyboardMode = mode
    -- The phone layout to come back to from the full keyboard.
    if mode ~= "abc" then Addon.db.keyboardPhone = mode end
    if self.frame then self:Apply(mode) end
end

function Keyboard:Create()
    local frame = CreateFrame("Frame", "ClassicConsoleGamepadUIKeyboard", UIParent, "BackdropTemplate")
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
    if frame.SetBackdrop then
        frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        frame:SetBackdropColor(1, 1, 1, 0.95)
    else
        local background = frame:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0, 0, 0, 0.8)
    end
    self.frame = frame
    local strip = CreateFrame("Frame", nil, frame)
    strip:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
    strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -PAD)
    strip:SetHeight(PREVIEW_HEIGHT)
    local stripBackground = strip:CreateTexture(nil, "BACKGROUND")
    stripBackground:SetAllPoints()
    stripBackground:SetTexture(WHITE)
    stripBackground:SetVertexColor(0.02, 0.02, 0.02, 0.9)
    self.preview = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    self.preview:SetPoint("LEFT", strip, "LEFT", 8, 0)
    self.previewFrame = strip
    self.status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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
        frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 120)
    end
    frame:Hide()
    local mode = Addon.db.keyboardMode
    self:Apply((mode == "t9" or mode == "t9p" or mode == "t9h") and mode or "abc")
end

function Keyboard:Show(auto)
    Trace("Keyboard:Show")
    if not self.frame then self:Create() end
    self.auto = auto and true or false
    self.shownAt = GetTime()
    self.shift, self.tap, self.pred, self.buffer = false, nil, nil, ""
    self:UpdateHints()
    self.frame:Show()
    self:SyncPad()
    self:UpdateStatus()
    self:Refresh()
end

function Keyboard:Hide()
    Trace("Keyboard:Hide")
    self.pred, self.buffer, self.tap = nil, "", nil
    self.hints = nil
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
    elseif not wanted and self.pad:IsShown() then Trace("Keyboard pad off"); self.pad:Hide()
    elseif wanted then self:Reclaim() end
end

local function Expected(self, key)
    return "CLICK " .. self.pad:GetAttribute("button") .. ":" .. PAD_TOKENS[key]
end

-- The chat sets its own pad bindings when its line opens or changes, and the newest binding wins. When one of
-- ours has been taken over, bind ours again (at most once a second).
function Keyboard:Reclaim()
    if not (GetBindingAction and SecureHandlerExecute) then return end
    local now = GetTime()
    if self.reclaimed and now - self.reclaimed < 1 then return end
    for key in pairs(PAD_TOKENS) do
        local actual = GetBindingAction(key, true)
        if actual ~= Expected(self, key) then
            self.reclaimed = now
            self.reclaims = (self.reclaims or 0) + 1
            Trace("Keyboard: " .. key .. " was " .. tostring(actual) .. ", binding again")
            SecureHandlerExecute(self.pad, PAD_BIND)
            return
        end
    end
end

-- /cgp keyboard debug: what the pad buttons are bound to while the keyboard is up.
function Keyboard:Debug()
    Addon:Print(string.format("keyboard: shown=%s pad=%s gamepad=%s chat=%s reclaims=%s",
        tostring(self.frame and self.frame:IsShown()), tostring(self.pad and self.pad:IsShown()),
        tostring(Addon:IsGamepadMode()), tostring(FindEditBox() and FindEditBox():GetName()),
        tostring(self.reclaims or 0)))
    if not (GetBindingAction and self.pad) then return end
    for key, token in pairs(PAD_TOKENS) do
        Addon:Print(string.format("  %s (%s): %s", key, token, tostring(GetBindingAction(key, true))))
    end
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
    self.tap = nil
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
    if not self:Flush(false) then return end
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
        -- Accept the word and add a space. The full keyboard has a space key.
        if self.mode ~= "abc" then
            self:Flush(true)
        elseif self.special.space then
            self:Press(self.special.space)
        end
    elseif token == "shift" then
        self:Press(self.special.shift)
    elseif token == "start" then
        self:Press(self.special.enter)
    elseif token == "previous" then
        self:Cycle(-1)
    elseif token == "next" then
        if self.mode == "t9" then self.tap = nil else self:Cycle(1) end
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
        -- Not inside the game's own call stack that is opening the chat line: a frame later, on our own.
        C_Timer.After(0, function()
            if FindEditBox() and not (self.frame and self.frame:IsShown()) then self:Show(true) end
        end)
    end, self)
end
