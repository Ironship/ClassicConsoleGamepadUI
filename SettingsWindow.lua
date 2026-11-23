local _, Addon = ...
-- The settings window (/cgp): a window of its own with a tab per task, instead of one long list in the game's
-- Settings panel. It is made of plain frames only (no secure templates, no protected calls), so it opens in
-- combat and in Gamepad Mode without touching the game's own panels; Options > AddOns has a button that opens it.
-- Layout (the same as the settings of UsefulPlatesAndTooltips): a switch for the whole addon above the tabs, a black
-- panel with the rows (label on the left, control in a column on the right, a gold heading and a line about what the
-- group is for), a help line under it that shows what the row under the mouse or the pad does, and the language and the
-- reset where they are always at hand.
-- In Gamepad Mode the window takes the pad: D-pad up/down select, left/right adjust, A activates, LB/RB switch
-- tabs, B closes. Pad input is switched on out of combat only (the calls are protected in combat).
local Window = {}
Addon.SettingsWindow = Window
local Fonts = Addon.Fonts

local WHITE = "Interface\\Buttons\\WHITE8X8"
local WIDTH, BODY_HEIGHT = 660, 302
local HEADER, TAB_HEIGHT, MARGIN, SCROLL_WIDTH = 40, 26, 10, 16
local SWITCH_HEIGHT, HELP_HEIGHT, FOOT_HEIGHT = 54, 90, 34 -- the help line holds four lines: the longest descriptions run to that
local PANEL_PAD = 6
local ROW_WIDTH = WIDTH - 2 * MARGIN - 2 * PANEL_PAD - SCROLL_WIDTH
local LABEL_WIDTH, CONTROL_X = 330, 344
local CONTROL_WIDTH = ROW_WIDTH - CONTROL_X - 8

-- The text of a key in the language in use (Locales/).
local function Text(key)
    return Addon.L[key]
end

local function Control(key)
    for _, info in ipairs(Addon.Options.controls) do
        if info.key == key then return info end
    end
end

-- Rows that only mean something while another setting is in a state (the ones with a "parent" in Options.lua are dimmed
-- while their check box is off; these are dimmed while the condition is true).
local DIM = {
    groupBoth = function(db) return db.compact end,
    placeMenu = function(db) return db.hideMenu end,
    menuRight = function(db) return db.hideMenu end,
    menuBottom = function(db) return db.hideMenu end,
}

local function SetEnabled(frame, enabled)
    if frame.SetEnabled then frame:SetEnabled(enabled)
    elseif enabled and frame.Enable then frame:Enable()
    elseif frame.Disable then frame:Disable() end
end

-- A black panel like the game's tooltips and the settings of UsefulPlatesAndTooltips.
local function Panel(frame, alpha)
    if frame.SetBackdrop then
        frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        frame:SetBackdropColor(0, 0, 0, alpha or 1)
        frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end
end

-- ---------------------------------------------------------------------------------------------
-- The help line: what the row under the mouse (or under the pad's selection) does. It is the place for the long text,
-- it works with a controller and it uses the addon's fonts, so the letters of every language are there (Fonts.lua).
-- ---------------------------------------------------------------------------------------------

local function ShowHelp(title, body)
    local help = Window.help
    if not help then return end
    help.title:SetText(title or "")
    help.body:SetText(body or "")
end

local function AddHelp(frame, title, body)
    frame:SetScript("OnEnter", function() ShowHelp(title, body) end)
end

-- ---------------------------------------------------------------------------------------------
-- The list a choice opens (the languages, the keyboard layouts): one list for the whole window.
-- ---------------------------------------------------------------------------------------------

local LIST_ROW = 22

local function CloseList()
    if Window.list then Window.list:Hide() end
    if Window.listCatcher then Window.listCatcher:Hide() end
end

local function EnsureList()
    if Window.list then return end
    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:SetScript("OnClick", CloseList)
    catcher:Hide()
    local list = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:SetFrameLevel(catcher:GetFrameLevel() + 2)
    list:SetClampedToScreen(true)
    list:EnableMouse(true)
    Panel(list, 1)
    list:Hide()
    list.rows = {}
    Window.list, Window.listCatcher = list, catcher
end

-- entries: { { value, label }, ... }; pick(value) is called with the one clicked.
local function OpenList(owner, entries, current, pick)
    EnsureList()
    local list = Window.list
    if list:IsShown() and list.owner == owner then CloseList() return end
    list.owner = owner
    list:SetParent(UIParent)
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    local width = math.max(owner:GetWidth() or 200, 160)
    list:SetHeight(#entries * LIST_ROW + 8)
    for i, entry in ipairs(entries) do
        local row = list.rows[i]
        if not row then
            row = CreateFrame("Button", nil, list)
            row:SetHeight(LIST_ROW)
            row.label = Fonts:String(row, "OVERLAY", "Highlight")
            row.label:SetPoint("LEFT", 8, 0)
            row.mark = row:CreateTexture(nil, "BACKGROUND")
            row.mark:SetAllPoints()
            row.mark:SetTexture(WHITE)
            row.mark:SetVertexColor(1, 0.82, 0, 0.18)
            local highlight = row:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetTexture(WHITE)
            highlight:SetVertexColor(1, 1, 1, 0.12)
            list.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 4, -4 - (i - 1) * LIST_ROW)
        row:SetPoint("RIGHT", list, "RIGHT", -4, 0)
        row.label:SetText(entry[2])
        local labelWidth = tonumber(row.label:GetStringWidth()) or 0
        if labelWidth + 28 > width then width = math.ceil(labelWidth) + 28 end
        row.mark:SetShown(entry[1] == current)
        row:SetScript("OnClick", function()
            CloseList()
            pick(entry[1])
        end)
        row:Show()
    end
    list:SetWidth(width)
    for i = #entries + 1, #list.rows do list.rows[i]:Hide() end
    Window.listCatcher:Show()
    list:Show()
end

-- A destructive button asks twice: the first click changes its label, a second one within four seconds does it.
local function Confirmed(action)
    local armed
    return function(button)
        local now = GetTime()
        if armed and now - armed < 4 then
            armed = nil
            button:SetText(button.baseText)
            action()
            return
        end
        armed = now
        button:SetText(Text("confirmAgain"))
        C_Timer.After(4, function()
            if armed == now then
                armed = nil
                button:SetText(button.baseText)
            end
        end)
    end
end

-- ---------------------------------------------------------------------------------------------
-- What the tabs hold, by task. {"header", text key, note key}, {"control", key} (a check box or a slider, by its entry in
-- the options), {"choice", key[, parent]}, {"button", label key, button text key, tip key, function[, parent[, literal
-- label]]}, {"status", function that returns a text[, parent]} (a line that is kept up to date while the window is
-- open). A row with a parent (the key of a check box) is dimmed while that box is off. A tab with `master` is dimmed
-- while the classic interface is switched off.
-- ---------------------------------------------------------------------------------------------

local function Tabs()
    local options = Addon.Options
    return {
        { id = "bars", label = Text("tabBars"), master = true, items = {
            { "header", "secLayout", "secLayoutNote" },
            { "control", "compact" }, { "control", "groupBoth" }, { "control", "crossFirst" },
            { "control", "barScale" }, { "control", "contextGap" },
            { "header", "secGryphons", "secGryphonsNote" },
            { "control", "showLeftCap" }, { "control", "showRightCap" },
            { "header", "secFrames", "secFramesNote" },
            { "control", "moveUnitFrames" }, { "control", "placeBags" }, { "control", "placeStatusBars" },
            { "control", "placeTotemBar" },
        } },
        { id = "controls", label = Text("tabControls"), items = {
            { "header", "secKeys", "secKeysNote" },
            { "control", "padKeyboard" }, { "control", "attackStart" },
            { "button", "keymapOpen", "btnOpen", "keymapOpenTip", function() Addon.KeyMap:Open() end },
            { "header", "secWheels", "secWheelsNote" },
            { "control", "wheels" }, { "control", "wheelScale" }, { "control", "wheelSlotScale" },
            { "control", "wheelX" }, { "control", "wheelY" }, { "control", "wheelAlpha" },
            { "control", "wheelWedges" }, { "control", "wheelToggle" },
            { "control", "wheelNames" }, { "control", "wheelHints" }, { "control", "wheelNumbers" }, { "control", "wheelKeep" }, { "control", "wheelsDock" }, { "control", "wheelsDockAlways" }, { "control", "wheelsDockFocus" },
            { "control", "wheelCombos" },
            { "control", "wheelCameraOnly" }, { "choice", "wheelBlock", "wheels" },
            { "wheelkey", 1 }, { "wheelkey", 2 }, { "wheelkey", 3 }, { "wheelkey", 4 }, { "wheelkey", 5 },
            { "control", "wheelDynamic" },
            { "choice", "wheelDynFood", "wheelDynamic" }, { "choice", "wheelDynUse", "wheelDynamic" }, { "choice", "wheelDynProf", "wheelDynamic" }, { "choice", "wheelDynPet", "wheelDynamic" },
            { "control", "quietDynamic" },
            { "button", "wheelsEdit", "btnOpen", "wheelsEditTip", function() Addon.Wheels:Toggle() end, "wheels" },
            { "button", "wheelsClear", "btnReset", "wheelsClearTip", Confirmed(function() Addon.Wheels:ClearAll() end), "wheels" },
            { "header", "secAssign", "secAssignNote" },
            { "button", "bind", "btnStart", "bindTip", function() options:BindFromBars() end },
            { "header", "secGame", "secGameNote" },
            { "button", "", "btnOpen", "bindingsTip", function() options:OpenBindings() end, nil, SETTINGS_KEYBINDINGS_LABEL },
            { "button", "actions", "btnOpen", "actionsTip", function() options:EditActions() end },
            { "button", "", "btnOpen", "controlsTip", function() options:OpenGamepad() end, nil, GAMEPAD_LABEL },
        } },
        { id = "prompts", label = Text("tabPrompts"), master = true, items = {
            { "header", "secPrompts", "secPromptsNote" },
            { "control", "promptScale" }, { "control", "modifierScale" }, { "control", "showKeyboardHints" },
            { "control", "showMenuHints" }, { "control", "highlightActive" },
            { "header", "legend", "secLegendNote" },
            { "control", "legendFrame" }, { "control", "legendShade" },
            { "control", "moveLegend" }, { "control", "legendX" }, { "control", "legendGap" },
        } },
        { id = "interface", label = Text("tabInterface"), items = {
            { "header", "languageHeader", "secLanguageNote" },
            { "choice", "language" },
            { "header", "menu", "menuNote" },
            { "control", "hideMenu" }, { "control", "placeMenu" }, { "control", "menuRight" }, { "control", "menuBottom" },
            { "header", "chat", "chatNote" },
            { "control", "raiseChat" }, { "control", "chatGap" },
            { "control", "anchorChat" }, { "control", "chatLeft" }, { "control", "chatBottom" },
            { "header", "items" },
            { "control", "easyDelete" }, { "control", "muteItemSounds" },
        } },
        { id = "keyboard", label = Text("tabKeyboard"), items = {
            { "header", "keyboard", "keyboardNote" },
            { "control", "keyboardEnabled" },
            { "control", "autoKeyboard" },
            { "choice", "keyboardLanguage", "keyboardEnabled" }, { "choice", "keyboardMode", "keyboardEnabled" },
            { "control", "keyboardTransparency" },
            { "button", "keyboardShow", "btnShow", "keyboardTip", function() Addon.Keyboard:Toggle() end, "keyboardEnabled" },
            { "header", "secWords", "secWordsNote" },
            { "control", "wordHunter" },
            { "status", function() return Addon.WordSources:Status() end, "wordHunter" },
            { "status", function() return Addon.Words:Summary() end },
            { "button", "forgetWords", "btnReset", "forgetWordsTip", Confirmed(function()
                Addon.Words:Forget()
                Addon:Print(Text("wordsForgotten"))
            end) },
        } },
    }
end

-- ---------------------------------------------------------------------------------------------
-- Rows
-- ---------------------------------------------------------------------------------------------

-- A change reaches the rest of the addon a moment after the last one, so dragging a slider does not rebuild
-- the interface at every step.
local pending = {}
local function Changed(key)
    if key == "language" then
        pending[key] = nil
        Addon.Options:Changed(key)
        return
    end
    if pending[key] then return end
    pending[key] = true
    C_Timer.After(0.15, function()
        pending[key] = nil
        Addon.Options:Changed(key)
    end)
end

-- A gold heading with a line, and under it what the group is for.
local function Header(page, y, key, noteKey)
    local row = CreateFrame("Frame", nil, page.content)
    row:SetPoint("TOPLEFT", page.content, "TOPLEFT", 6, -y - 6)
    row:SetSize(ROW_WIDTH, 18)
    local label = Fonts:String(row, "OVERLAY", "NormalSmall")
    label:SetPoint("LEFT", 0, 0)
    label:SetText(Text(key))
    local rule = row:CreateTexture(nil, "ARTWORK")
    rule:SetTexture(WHITE)
    rule:SetVertexColor(1, 0.82, 0, 0.2)
    rule:SetHeight(1)
    rule:SetPoint("LEFT", label, "RIGHT", 8, 0)
    rule:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    y = y + 28
    if noteKey then
        local note = Fonts:String(page.content, "OVERLAY", "DisableSmall")
        note:SetPoint("TOPLEFT", page.content, "TOPLEFT", 8, -y)
        note:SetWidth(ROW_WIDTH - 4)
        note:SetJustifyH("LEFT")
        note:SetText(Text(noteKey))
        y = y + math.max(14, math.ceil(tonumber(note:GetStringHeight()) or 14)) + 6
    end
    return y
end

-- Registers a row's node for navigation and refresh. The row is dimmed (and the node skipped by the pad) while its parent
-- box is off, while its own condition (DIM) holds, or - on a tab of the classic interface - while that is switched off.
local function Register(page, row, node, y, height, refresh, parent, key)
    node.rowTop, node.rowHeight = y, height
    page.nodes[#page.nodes + 1] = node
    page.refresh[#page.refresh + 1] = function()
        refresh()
        local db = Addon.db
        local dimmed = (parent and not db[parent]) or (key and DIM[key] and DIM[key](db)) or (page.master and not db.enabled) or false
        row:SetAlpha(dimmed and 0.45 or 1)
        SetEnabled(node, not dimmed)
        node.dimmed = dimmed
    end
end

-- A line the window keeps up to date by itself (once a second while it is open), for what changes without the player.
local STATUS_HEIGHT = 32

local function Status(page, y, fn, parent)
    local indent = 22
    local label = Fonts:String(page.content, "OVERLAY", "DisableSmall")
    label:SetPoint("TOPLEFT", page.content, "TOPLEFT", 8 + indent, -y)
    label:SetWidth(ROW_WIDTH - 4 - indent)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    local function Update()
        label:SetText(fn() or "")
        local dimmed = parent and not Addon.db[parent] or false
        label:SetAlpha(dimmed and 0.45 or 1)
    end
    page.refresh[#page.refresh + 1] = Update
    page.live[#page.live + 1] = Update
    Update()
    return y + STATUS_HEIGHT
end

-- The label on the left, the control in its column on the right: the same grid in every row.
local function RowLabel(row, text, indent)
    local label = Fonts:String(row, "OVERLAY", "Highlight")
    label:SetPoint("LEFT", 2, 0)
    label:SetWidth(LABEL_WIDTH - indent - 6)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

local function NewRow(page, y, indent, height)
    local row = CreateFrame("Frame", nil, page.content)
    row:SetPoint("TOPLEFT", page.content, "TOPLEFT", 6 + indent, -y)
    row:SetSize(ROW_WIDTH - indent, height)
    row:EnableMouse(true)
    return row
end

local function Check(page, y, info)
    local key, indent = info.key, info.parent and 22 or 0
    local row = NewRow(page, y, indent, 30)
    local label = RowLabel(row, Text(key), indent)
    local height = math.max(30, math.ceil(tonumber(label:GetStringHeight()) or 14) + 12)
    row:SetHeight(height)
    local box = CreateFrame("CheckButton", nil, row)
    box:SetSize(24, 24)
    box:SetPoint("LEFT", row, "LEFT", CONTROL_X - indent, 0)
    box:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    box:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    box:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    box:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    -- The label is part of the check box for the mouse.
    box:SetHitRectInsets(-(CONTROL_X - indent), 0, 0, 0)
    local tip = Text(info.tip or (key .. "Tip"))
    AddHelp(box, Text(key), tip)
    AddHelp(row, Text(key), tip)
    box:SetScript("OnClick", function(self)
        Addon.db[key] = self:GetChecked() and true or false
        Changed(key)
        page.Refresh()
    end)
    Register(page, row, box, y, height, function() box:SetChecked(Addon.db[key] and true or false) end, info.parent, key)
    return y + height
end

local function Slider(page, y, info)
    local key, indent = info.key, info.parent and 22 or 0
    local row = NewRow(page, y, indent, 30)
    local label = RowLabel(row, Text(key), indent)
    local height = math.max(30, math.ceil(tonumber(label:GetStringHeight()) or 14) + 12)
    row:SetHeight(height)
    local bar = CreateFrame("Slider", nil, row)
    bar:SetOrientation("HORIZONTAL")
    bar:SetSize(CONTROL_WIDTH - 54, 16)
    bar:SetPoint("LEFT", row, "LEFT", CONTROL_X - indent + 2, 0)
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
    local value = Fonts:String(row, "OVERLAY", "HighlightSmall")
    value:SetPoint("LEFT", bar, "RIGHT", 8, 0)
    local percent = info.max <= 3
    local function Show(v) value:SetText(percent and (math.floor(v * 100 + 0.5) .. "%") or tostring(math.floor(v + 0.5))) end
    bar:SetScript("OnValueChanged", function(_, v)
        v = tonumber(string.format("%.4f", math.floor(v / info.step + 0.5) * info.step))
        Show(v)
        if bar.syncing or Addon.db[key] == v then return end
        Addon.db[key] = v
        Changed(key)
    end)
    local tip = Text(info.tip or (key .. "Tip"))
    AddHelp(bar, Text(key), tip)
    AddHelp(row, Text(key), tip)
    Register(page, row, bar, y, height, function()
        bar.syncing = true
        bar:SetValue(Addon.db[key])
        Show(Addon.db[key])
        bar.syncing = false
    end, info.parent, key)
    return y + height
end

-- The name of a choice: it names itself ({ value, name }) or has the key of a text ({ value, nil, key }).
local function ChoiceName(choice)
    return choice[3] and Text(choice[3]) or choice[2]
end

local function ChoiceEntries(choices)
    local entries = {}
    for i, choice in ipairs(choices) do entries[i] = { choice[1], ChoiceName(choice) } end
    return entries
end

-- A drop-down: the button shows the choice, a click opens the list of all of them (right click and D-pad left/right step
-- through them without opening it).
local function Choice(page, y, key, parent)
    local choices = Addon.Options.choices[key]
    local row = NewRow(page, y, 0, 34)
    RowLabel(row, Text(key), 0)
    local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    Fonts:Button(button)
    button:SetSize(CONTROL_WIDTH, 24)
    button:SetPoint("LEFT", row, "LEFT", CONTROL_X, 0)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local arrow = Fonts:String(button, "OVERLAY", "Highlight")
    arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetText("v")
    local buttonText = button.GetFontString and button:GetFontString()
    if buttonText then
        buttonText:ClearAllPoints()
        buttonText:SetPoint("LEFT", 10, 0)
        buttonText:SetPoint("RIGHT", -22, 0)
        buttonText:SetJustifyH("CENTER")
        buttonText:SetWordWrap(false)
    end
    local function Name()
        for _, choice in ipairs(choices) do
            if choice[1] == Addon.db[key] then return ChoiceName(choice) end
        end
        return tostring(Addon.db[key])
    end
    local function Pick(value)
        Addon.db[key] = value
        button:SetText(Name())
        Changed(key)
        page.Refresh()
    end
    -- Step to the next choice (or the previous one: right click, D-pad left).
    function button.StepChoice(direction)
        local index = 1
        for i, choice in ipairs(choices) do
            if choice[1] == Addon.db[key] then index = i end
        end
        Pick(choices[(index - 1 + direction) % #choices + 1][1])
    end
    button:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then button.StepChoice(-1) return end
        OpenList(button, ChoiceEntries(choices), Addon.db[key], Pick)
    end)
    local tip = Text(key .. "Tip")
    AddHelp(button, Text(key), tip)
    AddHelp(row, Text(key), tip)
    Register(page, row, button, y, 34, function() button:SetText(Name()) end, parent)
    return y + 36
end

-- A row with an action: what it does on the left, the button on the right.
local function Button(page, y, label, buttonText, tip, action, parent)
    local row = NewRow(page, y, 0, 34)
    RowLabel(row, label, 0)
    local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    Fonts:Button(button)
    button:SetSize(CONTROL_WIDTH, 24)
    button:SetPoint("LEFT", row, "LEFT", CONTROL_X, 0)
    button:SetText(buttonText)
    button.baseText = buttonText
    button:SetScript("OnClick", action)
    AddHelp(button, label, tip)
    AddHelp(row, label, tip)
    Register(page, row, button, y, 34, function() end, parent)
    return y + 36
end

-- A row for the key of a wheel: the button shows the key (a click waits for the next key to press, a right click takes it off).
local function WheelKey(page, y, wheel)
    local label = string.format(Text("wheelKeyLabel"), wheel, Addon.Wheels.Label(wheel))
    local row = NewRow(page, y, 0, 34)
    RowLabel(row, label, 0)
    local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    Fonts:Button(button)
    button:SetSize(CONTROL_WIDTH, 24)
    button:SetPoint("LEFT", row, "LEFT", CONTROL_X, 0)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local function Show() button:SetText(Addon.Wheels:KeyText(wheel)) end
    button:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then
            if Addon.Wheels:KeyOf(wheel) then Addon.Wheels:SetKey(wheel, nil) end
            Show()
        else
            Addon.Wheels:CaptureKey(wheel, Show)
        end
    end)
    local tip = Text("wheelKeyTip")
    AddHelp(button, label, tip)
    AddHelp(row, label, tip)
    Register(page, row, button, y, 34, Show, "wheels")
    return y + 36
end

-- ---------------------------------------------------------------------------------------------
-- Pages: a scrolling column per tab, built the first time the tab is shown
-- ---------------------------------------------------------------------------------------------

local function BuildPage(window, tab)
    local page = CreateFrame("Frame", nil, window, "BackdropTemplate")
    page:SetPoint("TOPLEFT", MARGIN, -(HEADER + TAB_HEIGHT + SWITCH_HEIGHT))
    page:SetPoint("BOTTOMRIGHT", -MARGIN, MARGIN + FOOT_HEIGHT + HELP_HEIGHT)
    Panel(page, 1)
    page:Hide()
    page.nodes, page.refresh, page.live, page.master = {}, {}, {}, tab.master and true or false
    local scroll = CreateFrame("ScrollFrame", nil, page)
    scroll:SetPoint("TOPLEFT", PANEL_PAD, -PANEL_PAD)
    scroll:SetPoint("BOTTOMRIGHT", -PANEL_PAD - SCROLL_WIDTH, PANEL_PAD)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(ROW_WIDTH + 12, 1)
    scroll:SetScrollChild(content)
    local bar = CreateFrame("Slider", nil, page)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(12)
    bar:SetPoint("TOPRIGHT", -PANEL_PAD, -PANEL_PAD)
    bar:SetPoint("BOTTOMRIGHT", -PANEL_PAD, PANEL_PAD)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Vertical")
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(WHITE)
    track:SetVertexColor(0.1, 0.1, 0.1, 1)
    track:SetPoint("TOP")
    track:SetPoint("BOTTOM")
    track:SetWidth(6)
    page.scroll, page.content, page.bar = scroll, content, bar

    local function Range()
        return math.max(0, (content:GetHeight() or 0) - (scroll:GetHeight() or 0))
    end
    function page.ScrollTo(offset)
        offset = math.min(math.max(offset, 0), Range())
        scroll:SetVerticalScroll(offset)
        bar.syncing = true
        bar:SetValue(offset)
        bar.syncing = false
    end
    function page.SyncBar()
        bar.syncing = true
        bar:SetMinMaxValues(0, math.max(Range(), 0.001))
        bar:SetShown(Range() > 0)
        bar.syncing = false
        page.ScrollTo(scroll:GetVerticalScroll() or 0)
    end
    scroll:SetScript("OnMouseWheel", function(_, delta) page.ScrollTo((scroll:GetVerticalScroll() or 0) - delta * 30) end)
    bar:SetScript("OnValueChanged", function(_, value)
        if bar.syncing then return end
        scroll:SetVerticalScroll(value)
    end)
    -- A node in view: used by the pad when it moves the selection.
    function page.Reveal(node)
        local top, height = node.rowTop or 0, node.rowHeight or 30
        local offset, view = scroll:GetVerticalScroll() or 0, scroll:GetHeight() or 0
        if top < offset then page.ScrollTo(top - 4)
        elseif top + height > offset + view then page.ScrollTo(top + height - view + 4) end
    end
    function page.Refresh()
        for _, refresh in ipairs(page.refresh) do refresh() end
    end

    local y = 0
    for _, item in ipairs(tab.items) do
        local kind = item[1]
        if kind == "header" then y = Header(page, y, item[2], item[3])
        elseif kind == "choice" then y = Choice(page, y, item[2], item[3])
        elseif kind == "status" then y = Status(page, y, item[2], item[3])
        elseif kind == "wheelkey" then y = WheelKey(page, y, item[2])
        elseif kind == "button" then
            local label = item[7] or Text(item[2])
            y = Button(page, y, label, Text(item[3]), Text(item[4]), item[5], item[6])
        else
            local info = Control(item[2])
            if info then y = (info.min and Slider or Check)(page, y, info) end
        end
    end
    content:SetHeight(y + 8)
    page.Refresh()
    page.SyncBar()
    return page
end

-- ---------------------------------------------------------------------------------------------
-- Pad navigation
-- ---------------------------------------------------------------------------------------------

local function Key(key)
    local ok, text = pcall(function() return Addon.MenuHints:KeyText(key) end)
    if ok and type(text) == "string" then return text end
    return GetBindingText and GetBindingText(key, 1) or key
end

function Window:Mark(node)
    if self.selected and self.selected ~= node then
        local leave = self.selected:GetScript("OnLeave")
        if leave then leave(self.selected) end
    end
    self.selected = node
    if not self.mark then
        local mark = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
        mark:EnableMouse(false)
        if mark.SetBackdrop then
            mark:SetBackdrop({ edgeFile = WHITE, edgeSize = 2 })
            mark:SetBackdropBorderColor(1, 0.82, 0, 1)
        end
        self.mark = mark
    end
    if not node then
        self.mark:Hide()
        return
    end
    self.mark:SetParent(node)
    self.mark:ClearAllPoints()
    self.mark:SetPoint("TOPLEFT", node, "TOPLEFT", -2, 2)
    self.mark:SetPoint("BOTTOMRIGHT", node, "BOTTOMRIGHT", 2, -2)
    self.mark:SetFrameLevel(node:GetFrameLevel() + 5)
    self.mark:Show()
    -- The window's own controls (the switch, the language, the reset) are outside the scrolling page.
    if type(node.rowTop) == "number" then self.page.Reveal(node) end
    local enter = node:GetScript("OnEnter")
    if enter then enter(node) end
end

-- What the pad can select, in order: the switch of the whole addon, the rows of the page, then the language and the reset.
function Window:Nodes()
    local nodes = { self.switchBox }
    for _, node in ipairs(self.page and self.page.nodes or {}) do
        if not node.dimmed then nodes[#nodes + 1] = node end
    end
    nodes[#nodes + 1] = self.languageButton
    nodes[#nodes + 1] = self.resetButton
    return nodes
end

-- Moves, adjusts or activates on a pad button; true when the window used the button.
function Window:PadButton(key)
    -- The keyboard owns the pad while it is shown; both reacting to one press would move two selections.
    local keyboard = Addon.Keyboard and Addon.Keyboard.frame
    if keyboard and keyboard:IsShown() and Addon:IsGamepadMode() then return false end
    -- The keyboard layout window is in front and has the pad.
    local keyMap = Addon.KeyMap and Addon.KeyMap.frame
    if keyMap and keyMap:IsShown() then Addon.KeyMap:PadButton(key); return true end
    if key == "PAD2" then
        if Window.list and Window.list:IsShown() then CloseList() return true end
        self:Hide()
        return true
    elseif key == "PADLSHOULDER" or key == "PADRSHOULDER" then
        self:SelectTab((self.index - 1 + (key == "PADLSHOULDER" and -1 or 1)) % #self.tabs + 1)
        return true
    end
    local step = ({ PADDUP = -1, PADDDOWN = 1 })[key]
    local nodes = self:Nodes()
    local index
    for i, node in ipairs(nodes) do
        if node == self.selected then index = i end
    end
    if step then
        self:Mark(nodes[index and math.max(1, math.min(#nodes, index + step)) or 1])
        return true
    elseif key == "PADDLEFT" or key == "PADDRIGHT" then
        local node, direction = nodes[index], key == "PADDLEFT" and -1 or 1
        if not node then self:Mark(nodes[1]) return true end
        if node.StepChoice then
            node.StepChoice(direction)
        elseif node.GetObjectType and node:GetObjectType() == "Slider" then
            local low, high = node:GetMinMaxValues()
            node:SetValue(math.max(low, math.min(high, node:GetValue() + direction * node:GetValueStep())))
        end
        return true
    elseif key == "PAD1" then
        local node = nodes[index]
        if not node then self:Mark(nodes[1]) return true end
        -- A choice opens a list for the mouse; the pad steps through it instead.
        if node.StepChoice then node.StepChoice(1)
        elseif node.Click and not (node.GetObjectType and node:GetObjectType() == "Slider") then node:Click("LeftButton") end
        return true
    end
    return false
end

-- Pad input for the window is switched on out of combat only.
function Window:EnablePad()
    local frame = self.frame
    if not frame or not frame:IsShown() or InCombatLockdown() or not frame.EnableGamePadButton then return end
    frame:EnableGamePadButton(true)
    frame:SetPropagateKeyboardInput(true)
    if self.padOn then return end
    self.padOn = true
    frame:SetScript("OnGamePadButtonDown", function(self_, key)
        if InCombatLockdown() then return end
        self_:SetPropagateKeyboardInput(not self:PadButton(key))
    end)
end

-- ---------------------------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------------------------

-- The tab buttons with the labels of the language in use, side by side.
function Window:LayoutTabs()
    local x = MARGIN + 2
    for index, tab in ipairs(self.tabs) do
        local button = self.tabButtons[index]
        button:SetText(tab.label)
        local label = button.GetFontString and button:GetFontString()
        local width = label and tonumber(label:GetStringWidth()) or 60
        button:SetSize(math.max(64, math.ceil(width) + 24), TAB_HEIGHT - 2)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", x, -HEADER)
        x = x + button:GetWidth() + 4
    end
end

function Window:UpdateHint()
    self.hint:SetText(Addon:IsGamepadMode() and string.format(Text("padHint"), Key("PADDUP"), Key("PADDDOWN"),
        Key("PADDLEFT"), Key("PADDRIGHT"), Key("PAD1"), Key("PAD2"), Key("PADLSHOULDER"), Key("PADRSHOULDER")) or "")
end

-- The name of the language in use. The word "Language" is the same in every language on purpose: whoever lands in a
-- language they cannot read must still find the button.
local function LanguageName()
    for _, choice in ipairs(Addon.Options.choices.language) do
        if choice[1] == Addon.db.language then return ChoiceName(choice) end
    end
    return tostring(Addon.db.language)
end

-- A button as wide as its text needs (a long translation would be cut off), never narrower than `least`.
local function FitButton(button, least, extra)
    local label = button.GetFontString and button:GetFontString()
    local width = label and tonumber(label:GetStringWidth()) or 0
    button:SetWidth(math.max(least, math.ceil(width) + (extra or 28)))
end

-- The texts that are not on the pages: the switch, the help line, the footer, the language button.
function Window:UpdateTexts()
    self.switchLabel:SetText(Text("enabled"))
    self.switchNote:SetText(Text("switchNote"))
    self.resetButton:SetText(Text("resetSettings"))
    self.resetButton.baseText = Text("resetSettings")
    self.languageButton:SetText("Language: " .. LanguageName())
    FitButton(self.resetButton, 190)
    FitButton(self.languageButton, 170, 42)
    local tip = Text("enabledTip")
    AddHelp(self.switchBox, Text("enabled"), tip)
    AddHelp(self.switchRow, Text("enabled"), tip)
    AddHelp(self.resetButton, Text("resetSettings"), Text("resetSettingsTip"))
    AddHelp(self.languageButton, Text("languageHeader"), Text("languageTip"))
    ShowHelp("", Text("helpDefault"))
end

-- A new language: every label, tip and row is made again from the texts of the language now in use. The pages are
-- built from scratch (their rows have the old texts and sizes), the selection on the pad stays on the same row.
-- Every page built so far shows the values in the database again (after "Reset all settings").
function Window:RefreshPages()
    for _, page in pairs(self.pages or {}) do page.Refresh() end
    if self.switchBox then self.switchBox:SetChecked(Addon.db.enabled and true or false) end
end

function Window:Relocalize()
    if not self.frame then return end
    local wasLanguage = self.selected == self.languageButton
    local selected
    for i, node in ipairs(self.page and self.page.nodes or {}) do
        if node == self.selected then selected = i end
    end
    CloseList()
    for _, page in pairs(self.pages) do page:Hide() end
    self.tabs, self.pages = Tabs(), {}
    self:LayoutTabs()
    self:UpdateHint()
    self:UpdateTexts()
    self:SelectTab(self.index or 1)
    if self.frame:IsShown() then
        local nodes = self.page and self.page.nodes
        if wasLanguage then self:Mark(self.languageButton)
        elseif selected and nodes and nodes[selected] then self:Mark(nodes[selected]) end
    end
end

-- The tab labels are gold, the selected one white (the tabs of UsefulPlatesAndTooltips).
local function PaintTab(button, selected, hover)
    local label = button.GetFontString and button:GetFontString()
    if not label then return end
    if selected or hover then label:SetTextColor(1, 1, 1) else label:SetTextColor(1, 0.82, 0) end
end

function Window:SelectTab(index)
    local tab = self.tabs[index]
    if not tab then return end
    self.index = index
    CloseList()
    if not self.pages[tab.id] then self.pages[tab.id] = BuildPage(self.frame, tab) end
    for id, page in pairs(self.pages) do page:SetShown(id == tab.id) end
    self.page = self.pages[tab.id]
    self.page.Refresh()
    self.page.SyncBar()
    for i, button in ipairs(self.tabButtons) do
        local select, deselect = PanelTemplates_SelectTab, PanelTemplates_DeselectTab
        if not (select and pcall(i == index and select or deselect, button)) then
            if i == index then button:Disable() else button:Enable() end
        end
        -- The template sets its own fonts when a tab is selected.
        Fonts:Button(button, true)
        button.selectedTab = i == index
        PaintTab(button, i == index, false)
    end
    self:Mark(nil)
end

local function SavePosition(frame)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if type(point) == "string" and type(x) == "number" and type(y) == "number" then
        Addon.db.settingsPos = { point, relativePoint, x, y }
    end
end

local POINTS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }

function Window:Create()
    local ok, frame = pcall(CreateFrame, "Frame", "ClassicConsoleGamepadUISettings", UIParent, "ButtonFrameTemplate")
    if not ok then frame = CreateFrame("Frame", "ClassicConsoleGamepadUISettings", UIParent, "BackdropTemplate") end
    self.frame = frame
    if ButtonFrameTemplate_HidePortrait then pcall(ButtonFrameTemplate_HidePortrait, frame) end
    if type(frame.Inset) == "table" and frame.Inset.Hide then frame.Inset:Hide() end
    frame:Hide()
    frame:SetSize(WIDTH, HEADER + TAB_HEIGHT + SWITCH_HEIGHT + BODY_HEIGHT + HELP_HEIGHT + FOOT_HEIGHT + MARGIN)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        SavePosition(f)
    end)
    local saved = Addon.db.settingsPos
    frame:ClearAllPoints()
    if type(saved) == "table" and POINTS[saved[1]] and type(saved[3]) == "number" and type(saved[4]) == "number" then
        frame:SetPoint(saved[1], UIParent, POINTS[saved[2]] and saved[2] or saved[1], saved[3], saved[4])
    else
        frame:SetPoint("CENTER")
    end
    if frame.SetTitle then frame:SetTitle("ClassicConsoleGamepadUI")
    elseif frame.TitleText then frame.TitleText:SetText("ClassicConsoleGamepadUI") end
    if frame.CloseButton then frame.CloseButton:SetScript("OnClick", function() self:Hide() end) end
    tinsert(UISpecialFrames, "ClassicConsoleGamepadUISettings")

    self.tabs, self.pages, self.tabButtons = Tabs(), {}, {}
    for index in ipairs(self.tabs) do
        local created, button = pcall(CreateFrame, "Button", nil, frame, "PanelTopTabButtonTemplate")
        if not created then button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate") end
        Fonts:Button(button, true)
        button:SetScript("OnClick", function() self:SelectTab(index) end)
        button:HookScript("OnEnter", function(b) PaintTab(b, b.selectedTab, true) end)
        button:HookScript("OnLeave", function(b) PaintTab(b, b.selectedTab, false) end)
        self.tabButtons[index] = button
    end
    self:LayoutTabs()

    -- The switch of the whole addon, above the pages (like "Enable" in UsefulPlatesAndTooltips).
    local row = CreateFrame("Frame", nil, frame)
    row:SetPoint("TOPLEFT", MARGIN + 4, -(HEADER + TAB_HEIGHT + 4))
    row:SetPoint("RIGHT", frame, "RIGHT", -MARGIN - 4, 0)
    row:SetHeight(SWITCH_HEIGHT - 8)
    row:EnableMouse(true)
    local box = CreateFrame("CheckButton", nil, row)
    box:SetSize(26, 26)
    box:SetPoint("TOPLEFT", 0, -2)
    box:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    box:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    box:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    box:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    box:SetHitRectInsets(0, -400, 0, 0)
    box:SetScript("OnClick", function(b)
        Addon.db.enabled = b:GetChecked() and true or false
        Changed("enabled")
        for _, page in pairs(self.pages) do page.Refresh() end
    end)
    self.switchLabel = Fonts:String(row, "OVERLAY", "Normal")
    self.switchLabel:SetPoint("TOPLEFT", box, "TOPRIGHT", 6, -2)
    self.switchNote = Fonts:String(row, "OVERLAY", "DisableSmall")
    self.switchNote:SetPoint("TOPLEFT", self.switchLabel, "BOTTOMLEFT", 0, -2)
    self.switchNote:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    self.switchNote:SetJustifyH("LEFT")
    self.switchBox, self.switchRow = box, row
    box:SetChecked(Addon.db.enabled and true or false)

    -- The language, beside the close button (the same place as in UsefulPlatesAndTooltips).
    local language = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    Fonts:Button(language)
    language:SetSize(170, 20)
    if frame.CloseButton then language:SetPoint("TOPRIGHT", frame.CloseButton, "TOPLEFT", -4, -3)
    else language:SetPoint("TOPRIGHT", -34, -8) end
    -- Stay above ButtonFrameTemplate's NineSlice/TitleContainer so it is always visible and clickable.
    local level = (frame:GetFrameLevel() or 0) + 10
    if frame.CloseButton and frame.CloseButton.GetFrameLevel then
        level = math.max(level, frame.CloseButton:GetFrameLevel() + 1)
    end
    if frame.TitleContainer and frame.TitleContainer.GetFrameLevel then
        level = math.max(level, frame.TitleContainer:GetFrameLevel() + 1)
    end
    language:SetFrameLevel(level)
    local langArrow = Fonts:String(language, "OVERLAY", "Highlight")
    langArrow:SetPoint("RIGHT", -8, 0)
    langArrow:SetText("v")
    local langText = language.GetFontString and language:GetFontString()
    if langText then
        langText:ClearAllPoints()
        langText:SetPoint("LEFT", 10, 0)
        langText:SetPoint("RIGHT", -22, 0)
        langText:SetJustifyH("LEFT")
        langText:SetWordWrap(false)
    end
    language:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local function PickLanguage(value)
        Addon.db.language = value
        Changed("language")
        language:SetText("Language: " .. LanguageName())
        FitButton(language, 170, 42)
    end
    function language.StepChoice(direction)
        local choices, index = Addon.Options.choices.language, 1
        for i, choice in ipairs(choices) do
            if choice[1] == Addon.db.language then index = i end
        end
        PickLanguage(choices[(index - 1 + direction) % #choices + 1][1])
    end
    language:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then language.StepChoice(-1) return end
        OpenList(language, ChoiceEntries(Addon.Options.choices.language), Addon.db.language, PickLanguage)
    end)
    self.languageButton = language

    -- The help line: what the row under the mouse or the pad does.
    local help = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    help:SetPoint("BOTTOMLEFT", MARGIN, MARGIN + FOOT_HEIGHT)
    help:SetPoint("BOTTOMRIGHT", -MARGIN, MARGIN + FOOT_HEIGHT)
    help:SetHeight(HELP_HEIGHT - 4)
    Panel(help, 0.9)
    help.title = Fonts:String(help, "OVERLAY", "Normal")
    help.title:SetPoint("TOPLEFT", 10, -7)
    help.title:SetPoint("RIGHT", -10, 0)
    help.title:SetJustifyH("LEFT")
    help.body = Fonts:String(help, "OVERLAY", "HighlightSmall")
    help.body:SetPoint("TOPLEFT", help.title, "BOTTOMLEFT", 0, -3)
    help.body:SetPoint("RIGHT", -10, 0)
    help.body:SetJustifyH("LEFT")
    help.body:SetJustifyV("TOP")
    self.help = help

    -- The foot: the reset (it asks twice) and the pad hint under the pages, only while a controller is in use.
    local reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    Fonts:Button(reset)
    reset:SetSize(190, 22)
    reset:SetPoint("BOTTOMLEFT", MARGIN + 2, MARGIN + 6)
    reset:SetScript("OnClick", Confirmed(function()
        if Addon.Options:ResetAll() then Window:RefreshPages() end
    end))
    self.resetButton = reset
    self.hint = Fonts:String(frame, "OVERLAY", "NormalSmall")
    self.hint:SetPoint("LEFT", reset, "RIGHT", 12, 0)
    self.hint:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
    self.hint:SetJustifyH("LEFT")
    self:UpdateTexts()

    frame:HookScript("OnShow", function()
        self:UpdateHint()
        self.switchBox:SetChecked(Addon.db.enabled and true or false)
        if self.page then
            self.page.Refresh()
            self.page.SyncBar()
        end
        self:EnablePad()
    end)
    frame:HookScript("OnHide", function()
        self:Mark(nil)
        CloseList()

    end)
    -- Lines that follow something outside the window (the word lists being read) are looked at once a second.
    local sinceLive = 0
    frame:HookScript("OnUpdate", function(_, elapsed)
        sinceLive = sinceLive + elapsed
        if sinceLive < 1 then return end
        sinceLive = 0
        local page = self.page
        if page and page.live then
            for _, update in ipairs(page.live) do update() end
        end
    end)
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function() self:EnablePad() end)
    self:SelectTab(1)
end

function Window:Open(tabId)
    if not self.frame then self:Create() end
    if tabId then
        for index, tab in ipairs(self.tabs) do
            if tab.id == tabId then self:SelectTab(index) end
        end
    end
    self.frame:Show()
end

function Window:Hide()
    if self.frame then self.frame:Hide() end
end

function Window:IsShown()
    return self.frame and self.frame:IsShown() or false
end

function Window:Toggle()
    if self:IsShown() then self:Hide() else self:Open() end
end
