local _, Addon = ...
-- A keyboard on the screen next to the slots of the classic bars. The slots are the ones the bars draw (Display.lua), each with the
-- pad's trigger and button on it, and each has a keyboard action behind it (slot.bindingAction): the key works the same on the
-- keyboard bar and, in Gamepad Mode, on the bar with the pad's action in it (Input.lua). Two ways to give a slot a key:
--   * click a key on the screen keyboard, then the slot (click the slot again to take the key away);
--   * click a slot, then press the key on the real keyboard (with Shift, Ctrl or Alt held where it should be a chord).
-- A slot and the key it has share a colour (no trigger, LT, RT, LT+RT), so "M is LT+X" is seen at a glance. Plain frames, no secure
-- templates; a change is an ordinary key binding (SetBinding, saved like the game's own), outside combat only.
local KeyMap = {}
Addon.KeyMap = KeyMap
local Fonts = Addon.Fonts

local WHITE = "Interface\\Buttons\\WHITE8X8"
local CELL_W, CELL_H, GAP = 72, 58, 4
local KEY_W, KEY_H = 52, 46
local ROW_LABEL = 84
local WIDTH = 16 + ROW_LABEL + 12 * (CELL_W + GAP) + 16
local HEIGHT = 700

local function Text(key) return Addon.L[key] end

-- The key names the game uses, by the keyboard's layout (the game names a key by the letter it types).
local LAYOUTS = {
    QWERTY = { { "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]" },
        { "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'" },
        { "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/" } },
    QWERTZ = { { "Q", "W", "E", "R", "T", "Z", "U", "I", "O", "P" },
        { "A", "S", "D", "F", "G", "H", "J", "K", "L" },
        { "Y", "X", "C", "V", "B", "N", "M", ",", ".", "-" } },
    AZERTY = { { "A", "Z", "E", "R", "T", "Y", "U", "I", "O", "P" },
        { "Q", "S", "D", "F", "G", "H", "J", "K", "L", "M" },
        { "W", "X", "C", "V", "B", "N", ",", ";", ":", "!" } },
}
local LAYOUT_BY_LOCALE = { deDE = "QWERTZ", frFR = "AZERTY" }

local function KeyRows()
    local letters = LAYOUTS[LAYOUT_BY_LOCALE[GetLocale and GetLocale() or ""] or "QWERTY"]
    return {
        { "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12" },
        { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
        letters[1], letters[2], letters[3],
        { "SPACE", "TAB", "BUTTON3", "BUTTON4", "BUTTON5", "MOUSEWHEELUP", "MOUSEWHEELDOWN" },
    }
end

local SHORT = { SPACE = "Space", TAB = "Tab", BUTTON3 = "Mouse3", BUTTON4 = "Mouse4", BUTTON5 = "Mouse5", MOUSEWHEELUP = "Wheel+",
    MOUSEWHEELDOWN = "Wheel-" }
local MODIFIER_LABELS = { SHIFT = "S", CTRL = "C", ALT = "A" }

local function KeyLabel(key)
    local prefix, base = "", key
    while true do
        local modifier, rest = base:match("^(%u+)%-(.+)$")
        if not modifier or not MODIFIER_LABELS[modifier] then break end
        prefix, base = prefix .. MODIFIER_LABELS[modifier] .. "-", rest
    end
    return prefix .. (SHORT[base] or base)
end

local function BindingContext(action)
    if C_KeyBindings and C_KeyBindings.GetBindingContextForAction then
        local ok, context = pcall(C_KeyBindings.GetBindingContextForAction, action)
        if ok then return context end
    end
end

-- The keyboard keys (not the pad's) bound to an action.
local function KeysOf(action)
    local keys = {}
    local ok, list = pcall(function() return { GetBindingKey(action, nil, BindingContext(action)) } end)
    for _, key in ipairs(ok and list or {}) do
        if not (IsBindingForGamePad and IsBindingForGamePad(key)) then keys[#keys + 1] = key end
    end
    return keys
end

local function ActionOfKey(chord)
    local ok, action = pcall(GetBindingAction, chord, true)
    if ok and type(action) == "string" and action ~= "" then return action end
end

local function ActionName(action)
    local ok, name = pcall(GetBindingName, action)
    if ok and type(name) == "string" and name ~= "" and name ~= action then return name end
    return action
end

-- ---------------------------------------------------------------------------------------------
-- The pad's glyphs: the game's own icons for the buttons, so a slot looks like it does on the bars
-- ---------------------------------------------------------------------------------------------

local FALLBACK = { PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y", PADDLEFT = "D-L", PADDUP = "D-U", PADDRIGHT = "D-R",
    PADDDOWN = "D-D", PADLTRIGGER = "LT", PADRTRIGGER = "RT", PADLSHOULDER = "LB", PADRSHOULDER = "RB" }

local function GlyphAtlas(key)
    local util = InputIconTextureSetUtility
    if not util or not util.GetNormalActiveInputIconButtonTexture then return nil end
    local ok, atlas = pcall(util.GetNormalActiveInputIconButtonTexture, key)
    if ok and type(atlas) == "string" and atlas ~= "" then return atlas end
end

-- Up to three glyphs side by side in a holder frame, centred; the letters where the game has no icon.
local function SetGlyphs(holder, keys, size)
    holder.tex, holder.txt = holder.tex or {}, holder.txt or {}
    local count = #keys
    local total = count * size + math.max(0, count - 1) * 2
    for i = 1, 3 do
        local tex, txt = holder.tex[i], holder.txt[i]
        if not tex then
            tex = holder:CreateTexture(nil, "ARTWORK")
            txt = Fonts:String(holder, "OVERLAY", "NormalSmall")
            holder.tex[i], holder.txt[i] = tex, txt
        end
        local key = keys[i]
        if not key then
            tex:Hide()
            txt:Hide()
        else
            local x = -total / 2 + size / 2 + (i - 1) * (size + 2)
            local atlas = GlyphAtlas(key)
            tex:ClearAllPoints()
            tex:SetPoint("CENTER", holder, "CENTER", x, 0)
            tex:SetSize(size, size)
            txt:ClearAllPoints()
            txt:SetPoint("CENTER", holder, "CENTER", x, 0)
            if atlas then
                tex:SetAtlas(atlas)
                tex:Show()
                txt:Hide()
            else
                tex:Hide()
                txt:SetText(FALLBACK[key] or key)
                txt:Show()
            end
        end
    end
end

-- The colours of the four groups (no trigger, LT, RT, LT+RT) and of what belongs to none.
local COLORS = {
    [1] = { 0.16, 0.34, 0.20 },
    [2] = { 0.14, 0.30, 0.55 },
    [3] = { 0.58, 0.34, 0.08 },
    [4] = { 0.42, 0.20, 0.55 },
    other = { 0.28, 0.28, 0.30 },
}
local TRIGGERS = { [1] = {}, [2] = { "PADLTRIGGER" }, [3] = { "PADRTRIGGER" }, [4] = { "PADLTRIGGER", "PADRTRIGGER" } }

-- What a slot is: its group (1 no trigger, 2 LT, 3 RT, 4 LT+RT, "other"), the glyph keys that draw it, and its words.
function KeyMap:SlotInfo(index)
    local Input, Buttons = Addon.Input, Addon.ButtonBindings
    local bar, native = Input.SlotAction(index)
    if bar == 0 then
        local key = index == 9 and "PADLSHOULDER" or "PADRSHOULDER"
        return "other", { key }, FALLBACK[key]
    end
    if bar == 5 or not native or not TRIGGERS[bar] then
        return "other", {}, Text("keymapKeyBar") .. " " .. index
    end
    local pad = Buttons:Key(native) or Buttons.DEFAULT[native]
    local keys = {}
    for _, trigger in ipairs(TRIGGERS[bar]) do keys[#keys + 1] = trigger end
    keys[#keys + 1] = pad
    local words = {}
    for _, key in ipairs(keys) do words[#words + 1] = Buttons:Name(key) ~= "padKey" .. key and Buttons:Name(key) or key end
    return bar, keys, table.concat(words, "+")
end

-- The slots of each row on the screen, left to right, as the current layout has them.
function KeyMap:Rows()
    local compact = Addon.db.compact
    local rows = {
        { name = "keymapRowMain", first = 1, last = compact and 10 or 12 },
        { name = "keymapRowLeft", first = 13, last = compact and 20 or 24 },
        { name = "keymapRowRight", first = 25, last = compact and 32 or 36 },
    }
    for _, row in ipairs(rows) do
        row.slots = {}
        for i = row.first, row.last do
            if Addon.Display.slots[i] and Addon.Display.slots[i].bindingAction then row.slots[#row.slots + 1] = i end
        end
        -- left to right on the screen where the bars have a place; the index order otherwise
        local lefts, all = {}, true
        for _, i in ipairs(row.slots) do
            local left = Addon.Display.slots[i]:GetLeft()
            if type(left) ~= "number" then all = false end
            lefts[i] = left
        end
        if all and #row.slots > 1 then table.sort(row.slots, function(a, b) return lefts[a] < lefts[b] end) end
    end
    return rows
end

local function Print(text) Addon:Print(text) end

function KeyMap:Chord()
    if not self.selected then return nil end
    local chord = self.selected
    if self.mods.SHIFT then chord = "SHIFT-" .. chord end
    if self.mods.CTRL then chord = "CTRL-" .. chord end
    if self.mods.ALT then chord = "ALT-" .. chord end
    return chord
end

local function Save()
    if SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
    if Addon.Input then Addon.Input.dirty = true end
    Addon:QueueRefresh(true)
end

function KeyMap:Say(text)
    if self.status then self.status:SetText(text or "") end
end

-- Give the slot a key (a chord such as "SHIFT-M"), or take it away again when the slot already has it. A key the game uses for
-- something else is replaced only after a second click on the slot.
function KeyMap:Bind(index, chord)
    if InCombatLockdown() then Print(Text("buttonsCombat")); return end
    local slot = Addon.Display.slots[index]
    local action = slot and slot.bindingAction
    if not action or not chord then return end
    local context = BindingContext(action)
    local old = ActionOfKey(chord)
    local _, _, words = self:SlotInfo(index)
    if old == action then
        SetBinding(chord, nil, context)
        Save()
        self:Say(string.format(Text("keymapUnbound"), KeyLabel(chord)))
    else
        if old and not self.slotOfAction[old] then
            local now = GetTime()
            if not (self.armed and self.armed.chord == chord and self.armed.index == index and now - self.armed.at < 5) then
                self.armed = { chord = chord, index = index, at = now }
                self:Say(string.format(Text("keymapReplace"), KeyLabel(chord), ActionName(old)))
                return
            end
        end
        self.armed = nil
        if SetBinding(chord, action, context) then
            Save()
            self:Say(string.format(Text("keymapSet"), KeyLabel(chord), words))
        else
            self:Say(string.format(Text("buttonsFailed"), words, "SetBinding"))
        end
    end
    self:Refresh()
end

function KeyMap:Clear(index)
    if InCombatLockdown() then Print(Text("buttonsCombat")); return end
    local slot = Addon.Display.slots[index]
    local action = slot and slot.bindingAction
    if not action then return end
    local context = BindingContext(action)
    for _, key in ipairs(KeysOf(action)) do SetBinding(key, nil, context) end
    Save()
    local _, _, words = self:SlotInfo(index)
    self:Say(string.format(Text("keymapCleared"), words))
    self:Refresh()
end

-- A click on a slot: with a key picked on the screen keyboard it gets that key; without one, the next key pressed on the real
-- keyboard is for it.
function KeyMap:ClickSlot(index)
    local chord = self:Chord()
    if chord then
        self:Bind(index, chord)
        return
    end
    if InCombatLockdown() then Print(Text("buttonsCombat")); return end
    if self.byPad then
        self:Say(Text("keymapPickFirst"))
        return
    end
    self.listening = index
    local _, _, words = self:SlotInfo(index)
    self:Say(string.format(Text("keymapListen"), words))
    self.frame:EnableKeyboard(true)
    self:Refresh()
end

function KeyMap:StopListening()
    self.listening = nil
    if self.frame then self.frame:EnableKeyboard(false) end
end

-- A key pressed on the real keyboard while a slot waits for one.
function KeyMap:OnKey(key)
    if not self.listening then return false end
    if key == "ESCAPE" then
        self:StopListening()
        self:Say(Text("keymapCancelled"))
        self:Refresh()
        return true
    end
    if IsKeyPressIgnoredForBinding and IsKeyPressIgnoredForBinding(key) then return true end
    local converted = GetConvertedKeyOrButton and GetConvertedKeyOrButton(key) or key
    local chord = CreateKeyChordStringUsingMetaKeyState and CreateKeyChordStringUsingMetaKeyState(converted) or converted
    local index = self.listening
    self:StopListening()
    self:Bind(index, chord)
    return true
end

local function Fill(frame, color, alpha)
    if not frame.fill then
        frame.fill = frame:CreateTexture(nil, "BACKGROUND")
        frame.fill:SetTexture(WHITE)
        frame.fill:SetAllPoints()
    end
    frame.fill:SetVertexColor(color[1], color[2], color[3], alpha or 1)
end

local function Border(frame, on)
    if not frame.border then
        frame.border = {}
        for i = 1, 4 do
            local line = frame:CreateTexture(nil, "OVERLAY")
            line:SetTexture(WHITE)
            line:SetVertexColor(1, 0.82, 0, 1)
            frame.border[i] = line
        end
        frame.border[1]:SetPoint("TOPLEFT"); frame.border[1]:SetPoint("TOPRIGHT"); frame.border[1]:SetHeight(2)
        frame.border[2]:SetPoint("BOTTOMLEFT"); frame.border[2]:SetPoint("BOTTOMRIGHT"); frame.border[2]:SetHeight(2)
        frame.border[3]:SetPoint("TOPLEFT"); frame.border[3]:SetPoint("BOTTOMLEFT"); frame.border[3]:SetWidth(2)
        frame.border[4]:SetPoint("TOPRIGHT"); frame.border[4]:SetPoint("BOTTOMRIGHT"); frame.border[4]:SetWidth(2)
    end
    for i = 1, 4 do frame.border[i]:SetShown(on and true or false) end
end

-- Where the pad is: a white outline outside the yellow one.
local function Focus(frame, on)
    if not frame.focus then
        frame.focus = {}
        for i = 1, 4 do
            local line = frame:CreateTexture(nil, "OVERLAY", nil, 7)
            line:SetTexture(WHITE)
            line:SetVertexColor(1, 1, 1, 1)
            frame.focus[i] = line
        end
        local f = frame.focus
        f[1]:SetPoint("TOPLEFT", -3, 3); f[1]:SetPoint("TOPRIGHT", 3, 3); f[1]:SetHeight(3)
        f[2]:SetPoint("BOTTOMLEFT", -3, -3); f[2]:SetPoint("BOTTOMRIGHT", 3, -3); f[2]:SetHeight(3)
        f[3]:SetPoint("TOPLEFT", -3, 3); f[3]:SetPoint("BOTTOMLEFT", -3, -3); f[3]:SetWidth(3)
        f[4]:SetPoint("TOPRIGHT", 3, 3); f[4]:SetPoint("BOTTOMRIGHT", 3, -3); f[4]:SetWidth(3)
    end
    for i = 1, 4 do frame.focus[i]:SetShown(on and true or false) end
end

local function MakeCell(parent, w, h)
    local cell = CreateFrame("Button", nil, parent)
    cell:SetSize(w, h)
    cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    cell.glyphs = CreateFrame("Frame", nil, cell)
    cell.glyphs:SetSize(w, 26)
    cell.text = Fonts:String(cell, "OVERLAY", "HighlightSmall")
    cell.text:SetWidth(w - 4)
    cell.text:SetWordWrap(false)
    return cell
end

function KeyMap:Create()
    local ok, frame = pcall(CreateFrame, "Frame", "ClassicConsoleGamepadUIKeyMap", UIParent, "ButtonFrameTemplate")
    if not ok then frame = CreateFrame("Frame", "ClassicConsoleGamepadUIKeyMap", UIParent, "BackdropTemplate") end
    self.frame = frame
    if ButtonFrameTemplate_HidePortrait then pcall(ButtonFrameTemplate_HidePortrait, frame) end
    if type(frame.Inset) == "table" and frame.Inset.Hide then frame.Inset:Hide() end
    frame:Hide()
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetPoint("CENTER")
    if frame.SetTitle then frame:SetTitle(Text("keymapTitle")) elseif frame.TitleText then frame.TitleText:SetText(Text("keymapTitle")) end
    if frame.CloseButton then frame.CloseButton:SetScript("OnClick", function() self:Hide() end) end
    tinsert(UISpecialFrames, "ClassicConsoleGamepadUIKeyMap")
    frame:SetScript("OnKeyDown", function(f, key)
        local used = self:OnKey(key)
        if f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(not used) end
    end)
    frame:SetScript("OnHide", function() self:StopListening() end)
    self.mods, self.cells, self.keys, self.slotOfAction, self.keyRows = {}, {}, {}, {}, {}

    local hint = Fonts:String(frame, "OVERLAY", "DisableSmall")
    hint:SetPoint("TOPLEFT", 16, -34)
    hint:SetWidth(WIDTH - 32)
    hint:SetJustifyH("LEFT")
    hint:SetText(Text("keymapHint"))
    self.hint = hint

    -- the slots
    local slotsTitle = Fonts:String(frame, "OVERLAY", "Normal")
    slotsTitle:SetPoint("TOPLEFT", 16, -84)
    slotsTitle:SetText(Text("keymapSlots"))
    self.rowLabels = {}
    local slotsTop = -108
    for r = 1, 3 do
        local label = Fonts:String(frame, "OVERLAY", "NormalSmall")
        label:SetPoint("TOPLEFT", 16, slotsTop - (r - 1) * (CELL_H + GAP) - CELL_H / 2 + 6)
        label:SetWidth(ROW_LABEL - 8)
        label:SetJustifyH("LEFT")
        self.rowLabels[r] = label
        self.cells[r] = {}
        for c = 1, 12 do
            local cell = MakeCell(frame, CELL_W, CELL_H)
            cell:SetPoint("TOPLEFT", 16 + ROW_LABEL + (c - 1) * (CELL_W + GAP), slotsTop - (r - 1) * (CELL_H + GAP))
            cell.glyphs:SetPoint("TOP", cell, "TOP", 0, -5)
            cell.text:SetPoint("BOTTOM", cell, "BOTTOM", 0, 6)
            cell:SetScript("OnMouseDown", function() self.byPad = nil; self:ShowFocus() end)
            cell:SetScript("OnClick", function(_, mouse)
                if not cell.slotIndex then return end
                if mouse == "RightButton" then self:Clear(cell.slotIndex) else self:ClickSlot(cell.slotIndex) end
            end)
            cell:SetScript("OnEnter", function()
                if not cell.slotIndex then return end
                local _, _, words = self:SlotInfo(cell.slotIndex)
                local keys = {}
                for _, key in ipairs(KeysOf(Addon.Display.slots[cell.slotIndex].bindingAction)) do keys[#keys + 1] = KeyLabel(key) end
                self:Say(string.format(Text("keymapSlotInfo"), words, #keys > 0 and table.concat(keys, ", ") or Text("keymapNoKey")))
            end)
            self.cells[r][c] = cell
        end
    end

    -- what is picked, and the modifiers
    local modsTop = slotsTop - 3 * (CELL_H + GAP) - 16
    local keysTitle = Fonts:String(frame, "OVERLAY", "Normal")
    keysTitle:SetPoint("TOPLEFT", 16, modsTop)
    keysTitle:SetText(Text("keymapKeys"))
    self.picked = Fonts:String(frame, "OVERLAY", "Highlight")
    self.picked:SetPoint("TOPRIGHT", -16, modsTop)
    self.picked:SetJustifyH("RIGHT")
    self.modButtons = {}
    for i, mod in ipairs({ "SHIFT", "CTRL", "ALT" }) do
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        Fonts:Button(button)
        button:SetSize(86, 22)
        button:SetPoint("TOPLEFT", 16 + 120 + (i - 1) * 90, modsTop + 3)
        button:SetText(mod == "SHIFT" and (SHIFT_KEY_TEXT or "Shift") or mod == "CTRL" and (CTRL_KEY_TEXT or "Ctrl") or (ALT_KEY_TEXT or "Alt"))
        button:SetScript("OnClick", function()
            self.mods[mod] = not self.mods[mod]
            self.armed = nil
            self:Refresh()
        end)
        self.modButtons[mod] = button
    end

    -- the keys
    local rows = KeyRows()
    local keysTop = modsTop - 32
    for r, row in ipairs(rows) do
        local x = 16 + (r == 3 and 14 or r == 4 and 26 or r == 5 and 42 or 0)
        self.keyRows[r] = {}
        for _, key in ipairs(row) do
            local wide = (key == "SPACE" or key == "MOUSEWHEELUP" or key == "MOUSEWHEELDOWN") and 76 or KEY_W
            local button = MakeCell(frame, wide, KEY_H)
            button:SetPoint("TOPLEFT", x, keysTop - (r - 1) * (KEY_H + GAP))
            x = x + wide + GAP
            button.key = key
            button.glyphs:SetSize(wide, 18)
            button.glyphs:SetPoint("BOTTOM", button, "BOTTOM", 0, 3)
            button.text:SetPoint("TOP", button, "TOP", 0, -5)
            button.text:SetText(SHORT[key] or key)
            button:SetScript("OnClick", function()
                self.selected = (self.selected ~= key) and key or nil
                self.armed = nil
                self:StopListening()
                self:Refresh()
                if self.selected then self:Say(string.format(Text("keymapPicked"), KeyLabel(self:Chord()))) end
            end)
            button:SetScript("OnEnter", function()
                local saved = self.selected
                self.selected = key
                local chord = self:Chord()
                self.selected = saved
                local action = ActionOfKey(chord)
                local slotIndex = action and self.slotOfAction[action]
                if slotIndex then
                    local _, _, words = self:SlotInfo(slotIndex)
                    self:Say(string.format(Text("keymapKeySlot"), KeyLabel(chord), words))
                elseif action then
                    self:Say(string.format(Text("keymapKeyUsed"), KeyLabel(chord), ActionName(action)))
                else
                    self:Say(string.format(Text("keymapKeyFree"), KeyLabel(chord)))
                end
            end)
            self.keys[#self.keys + 1] = button
            self.keyRows[r][#self.keyRows[r] + 1] = button
        end
    end

    -- the legend of the colours
    local legendY = keysTop - 6 * (KEY_H + GAP) - 6
    local x = 16
    for _, group in ipairs({ 1, 2, 3, 4 }) do
        local swatch = CreateFrame("Frame", nil, frame)
        swatch:SetSize(14, 14)
        swatch:SetPoint("TOPLEFT", x, legendY)
        Fill(swatch, COLORS[group])
        local label = Fonts:String(frame, "OVERLAY", "DisableSmall")
        label:SetPoint("LEFT", swatch, "RIGHT", 6, 0)
        label:SetText(Text(({ "keymapRowMain", "keymapRowLeft", "keymapRowRight", "keymapRowBoth" })[group]))
        x = x + 150
    end

    self.status = Fonts:String(frame, "OVERLAY", "Highlight")
    self.status:SetPoint("BOTTOMLEFT", 16, 16)
    self.status:SetWidth(WIDTH - 32)
    self.status:SetJustifyH("LEFT")

    frame:HookScript("OnShow", function()
        self.byPad = nil
        self:EnablePad()
        self:Refresh()
    end)
    local events = CreateFrame("Frame")
    events:RegisterEvent("UPDATE_BINDINGS")
    events:SetScript("OnEvent", function() if frame:IsShown() then self:Refresh() end end)
end

-- Redraw what the slots and the keys have now.
function KeyMap:Refresh()
    if not self.frame or not Addon.Display.slots then return end
    self.slotOfAction = {}
    local rows = self:Rows()
    local groupOf = {}
    for r = 1, 3 do
        local row = rows[r]
        self.rowLabels[r]:SetText(Text(row.name))
        for c = 1, 12 do
            local cell, index = self.cells[r][c], row.slots[c]
            cell.slotIndex = index
            if index then
                local slot = Addon.Display.slots[index]
                self.slotOfAction[slot.bindingAction] = index
                local group, glyphs, words = self:SlotInfo(index)
                groupOf[index] = group
                cell.group = group
                SetGlyphs(cell.glyphs, glyphs, 22)
                local labels = {}
                for _, key in ipairs(KeysOf(slot.bindingAction)) do labels[#labels + 1] = KeyLabel(key) end
                cell.text:SetText(#labels > 0 and table.concat(labels, " ") or "")
                if #glyphs == 0 then
                    cell.glyphs:Hide()
                    cell.fallback = cell.fallback or Fonts:String(cell, "OVERLAY", "NormalSmall")
                    cell.fallback:SetPoint("TOP", cell, "TOP", 0, -8)
                    cell.fallback:SetText(words)
                    cell.fallback:Show()
                else
                    cell.glyphs:Show()
                    if cell.fallback then cell.fallback:Hide() end
                end
                Fill(cell, COLORS[group] or COLORS.other, #labels > 0 and 0.95 or 0.55)
                Border(cell, self.listening == index)
                cell:Show()
            else
                cell:Hide()
            end
        end
    end
    local chord = self:Chord()
    self.picked:SetText(chord and string.format(Text("keymapPickedNow"), KeyLabel(chord)) or Text("keymapNothingPicked"))
    for _, button in ipairs(self.keys) do
        local saved = self.selected
        self.selected = button.key
        local keyChord = self:Chord()
        self.selected = saved
        local action = ActionOfKey(keyChord)
        local slotIndex = action and self.slotOfAction[action]
        local active = self.selected == button.key
        if slotIndex then
            local group, glyphs = self:SlotInfo(slotIndex)
            SetGlyphs(button.glyphs, glyphs, 14)
            button.glyphs:Show()
            Fill(button, COLORS[group] or COLORS.other, 0.95)
        elseif action then
            SetGlyphs(button.glyphs, {}, 14)
            button.glyphs:Show()
            Fill(button, COLORS.other, 0.8)
        else
            SetGlyphs(button.glyphs, {}, 14)
            Fill(button, { 0.1, 0.1, 0.12 }, 0.9)
        end
        Border(button, active)
    end
    for mod, button in pairs(self.modButtons) do
        button:SetAlpha(self.mods[mod] and 1 or 0.5)
    end
    self.hint:SetText(Text(Addon:IsGamepadMode() and "keymapPadHint" or "keymapHint"))
    self:ShowFocus()
end

-- ---------------------------------------------------------------------------------------------
-- The pad: the D-pad moves over the slots and the keys, A is a click, X clears a slot, B goes back
-- ---------------------------------------------------------------------------------------------

-- The rows the pad moves over, top to bottom: the slots, the modifiers, the keys.
function KeyMap:PadRows()
    local rows = {}
    for r = 1, 3 do
        local row = {}
        for c = 1, 12 do
            if self.cells[r][c]:IsShown() then row[#row + 1] = self.cells[r][c] end
        end
        if #row > 0 then rows[#rows + 1] = row end
    end
    rows[#rows + 1] = { self.modButtons.SHIFT, self.modButtons.CTRL, self.modButtons.ALT }
    for _, row in ipairs(self.keyRows) do rows[#rows + 1] = row end
    return rows
end

function KeyMap:ShowFocus()
    for _, row in ipairs(self:PadRows()) do
        for _, button in ipairs(row) do
            if button.focus or button == self.focused then Focus(button, self.byPad and button == self.focused) end
        end
    end
end

-- True when the window used the button.
function KeyMap:PadButton(key)
    -- The settings window behind hands its presses on, and the game may give this window the same press itself.
    local now = GetTime()
    if self.lastPad == key and self.lastPadAt == now then return true end
    self.lastPad, self.lastPadAt = key, now
    self.byPad = true
    if key == "PAD2" then
        if self.listening then self:StopListening()
        elseif self.selected then self.selected, self.armed = nil, nil
        else self:Hide(); return true end
        self:Say("")
        self:Refresh()
        return true
    end
    local rows = self:PadRows()
    local rowIndex, column
    for r, row in ipairs(rows) do
        for c, button in ipairs(row) do
            if button == self.focused then rowIndex, column = r, c end
        end
    end
    if not rowIndex then
        -- first press: the first key of the digit row, the usual start of a keyboard player's bar
        rowIndex, column = math.min(#rows, #rows - #self.keyRows + 2), 1
        self.focused = rows[rowIndex][column]
        self:ShowFocus()
        return key ~= "PAD3"
    end
    local row = rows[rowIndex]
    if key == "PADDLEFT" or key == "PADDRIGHT" then
        column = (column - 1 + (key == "PADDLEFT" and -1 or 1)) % #row + 1
        self.focused = row[column]
    elseif key == "PADDUP" or key == "PADDDOWN" then
        local target = rows[(rowIndex - 1 + (key == "PADDUP" and -1 or 1)) % #rows + 1]
        local x = self.focused:GetCenter()
        local best, distance
        for _, button in ipairs(target) do
            local bx = button:GetCenter()
            local d = (type(x) == "number" and type(bx) == "number") and math.abs(bx - x) or 0
            if not distance or d < distance then best, distance = button, d end
        end
        self.focused = best
    elseif key == "PAD1" then
        self.focused:Click("LeftButton")
    elseif key == "PAD3" then
        if self.focused.slotIndex then self:Clear(self.focused.slotIndex) end
    else
        return false
    end
    self:ShowFocus()
    local enter = self.focused:GetScript("OnEnter")
    if enter and (self.focused.key or self.focused.slotIndex) and key ~= "PAD1" and key ~= "PAD3" then enter(self.focused) end
    return true
end

-- Pad input is switched on out of combat only, like the settings window's.
function KeyMap:EnablePad()
    local frame = self.frame
    if not frame or InCombatLockdown() or not frame.EnableGamePadButton then return end
    frame:EnableGamePadButton(true)
    if self.padOn then return end
    self.padOn = true
    frame:SetScript("OnGamePadButtonDown", function(_, key)
        if InCombatLockdown() then return end
        self:PadButton(key)
    end)
end

function KeyMap:Open()
    if not self.frame then self:Create() end
    self.frame:Show()
end

function KeyMap:Hide()
    if self.frame then self.frame:Hide() end
end

function KeyMap:Toggle()
    if self.frame and self.frame:IsShown() then self:Hide() else self:Open() end
end
