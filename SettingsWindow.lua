local _, Addon = ...
-- The settings window (/cgp): a window of its own with a tab per topic, instead of one long list in the game's
-- Settings panel. It is made of plain frames only (no secure templates, no protected calls), so it opens in
-- combat and in Gamepad Mode without touching the game's own panels; Options > AddOns has a button that opens it.
-- In Gamepad Mode the window takes the pad: D-pad up/down select, left/right adjust, A activates, LB/RB switch
-- tabs, B closes. Pad input is switched on out of combat only (the calls are protected in combat).
local Window = {}
Addon.SettingsWindow = Window

local WHITE = "Interface\\Buttons\\WHITE8X8"
local WIDTH, BODY_HEIGHT = 640, 430
local HEADER, TAB_HEIGHT, MARGIN, SCROLL_WIDTH, HINT_HEIGHT = 40, 26, 10, 16, 30
local ROW_WIDTH = WIDTH - 2 * MARGIN - SCROLL_WIDTH - 12

local function Text(key)
    local texts = Addon.Options and Addon.Options.text
    return texts and texts[key] or key
end

local function Control(key)
    for _, info in ipairs(Addon.Options.controls) do
        if info.key == key then return info end
    end
end

local function Tooltip(frame, title, body)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 0.82, 0)
    if body and body ~= "" then GameTooltip:AddLine(body, 1, 1, 1, true) end
    GameTooltip:Show()
end

local function AddTooltip(frame, title, body)
    frame:SetScript("OnEnter", function(self) Tooltip(self, title, body) end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function SetEnabled(frame, enabled)
    if frame.SetEnabled then frame:SetEnabled(enabled)
    elseif enabled and frame.Enable then frame:Enable()
    elseif frame.Disable then frame:Disable() end
end

-- ---------------------------------------------------------------------------------------------
-- What the tabs hold. {"header", text}, {"control", key} (a check box or a slider, by its entry in the
-- options), {"choice", key[, parent]}, {"button", label, tooltip, function[, parent]}, {"note", text}. A row with a
-- parent (the key of a check box) is dimmed while that box is off.
-- ---------------------------------------------------------------------------------------------

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

local function Tabs()
    local options = Addon.Options
    return {
        { id = "general", label = Text("tabGeneral"), items = {
            { "header", "layout" },
            { "control", "enabled" }, { "control", "compact" }, { "control", "moveUnitFrames" },
            { "control", "contextGap" },
            { "header", "menu" },
            { "control", "menuRight" }, { "control", "menuBottom" },
        } },
        { id = "hints", label = Text("tabHints"), items = {
            { "header", "hints" },
            { "control", "promptScale" }, { "control", "modifierScale" }, { "control", "showKeyboardHints" },
            { "control", "showMenuHints" }, { "control", "highlightActive" },
            { "header", "legend" },
            { "control", "moveLegend" }, { "control", "legendX" }, { "control", "legendGap" },
        } },
        { id = "chat", label = Text("chat"), items = {
            { "header", "chat" },
            { "control", "raiseChat" }, { "control", "chatGap" },
            { "control", "anchorChat" }, { "control", "chatLeft" }, { "control", "chatBottom" },
        } },
        { id = "keyboard", label = Text("tabKeyboard"), items = {
            { "header", "keyboard" },
            { "control", "keyboardEnabled" },
            { "control", "autoKeyboard" },
            { "choice", "keyboardLanguage", "keyboardEnabled" }, { "choice", "keyboardPhone", "keyboardEnabled" },
            { "button", Text("keyboard"), Text("keyboardTip"), function() Addon.Keyboard:Toggle() end, "keyboardEnabled" },
            { "button", Text("forgetWords"), Text("forgetWordsTip"), Confirmed(function()
                Addon.Words:Forget()
                Addon:Print(Text("wordsForgotten"))
            end) },
        } },
        { id = "tools", label = Text("tabTools"), items = {
            { "header", "items" },
            { "control", "easyDelete" },
            { "header", "tabTools" },
            { "button", Text("bind"), Text("bindTip"), function() options:BindFromBars() end },
            { "button", SETTINGS_KEYBINDINGS_LABEL, Text("bindingsTip"), function() options:OpenBindings() end },
            { "button", Text("actions"), Text("actionsTip"), function() options:EditActions() end },
            { "button", GAMEPAD_LABEL, Text("controlsTip"), function() options:OpenGamepad() end },
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
    if pending[key] then return end
    pending[key] = true
    C_Timer.After(0.15, function()
        pending[key] = nil
        Addon.Options:Changed(key)
    end)
end

local function Header(page, y, key)
    local row = CreateFrame("Frame", nil, page.content)
    row:SetPoint("TOPLEFT", page.content, "TOPLEFT", 6, -y - 6)
    row:SetSize(ROW_WIDTH, 18)
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", 0, 0)
    label:SetText(Text(key))
    local rule = row:CreateTexture(nil, "ARTWORK")
    rule:SetTexture(WHITE)
    rule:SetVertexColor(1, 0.82, 0, 0.2)
    rule:SetHeight(1)
    rule:SetPoint("LEFT", label, "RIGHT", 8, 0)
    rule:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    return y + 30
end

local function Note(page, y, key)
    local label = page.content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    label:SetPoint("TOPLEFT", page.content, "TOPLEFT", 8, -y)
    label:SetWidth(ROW_WIDTH - 4)
    label:SetJustifyH("LEFT")
    label:SetText(Text(key))
    return y + math.max(14, math.ceil(tonumber(label:GetStringHeight()) or 14)) + 8
end

-- Registers a row's node for navigation and refresh.
local function Register(page, row, node, y, height, refresh, parent)
    node.rowTop, node.rowHeight = y, height
    page.nodes[#page.nodes + 1] = node
    page.refresh[#page.refresh + 1] = function()
        refresh()
        local dimmed = parent and not Addon.db[parent] or false
        row:SetAlpha(dimmed and 0.45 or 1)
        SetEnabled(node, not dimmed)
        node.dimmed = dimmed
    end
end

local function Check(page, y, info)
    local key, indent = info.key, info.parent and 22 or 0
    local row = CreateFrame("Frame", nil, page.content)
    row:SetPoint("TOPLEFT", page.content, "TOPLEFT", 6 + indent, -y)
    local box = CreateFrame("CheckButton", nil, row)
    box:SetSize(24, 24)
    box:SetPoint("TOPLEFT", 0, -2)
    box:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    box:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    box:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    box:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", box, "RIGHT", 4, 0)
    local labelWidth = ROW_WIDTH - 34 - indent
    label:SetWidth(labelWidth)
    label:SetJustifyH("LEFT")
    label:SetText(Text(key))
    local height = math.max(30, math.ceil(tonumber(label:GetStringHeight()) or 14) + 10)
    row:SetSize(ROW_WIDTH - indent, height)
    -- The label is part of the check box for the mouse.
    box:SetHitRectInsets(0, -labelWidth, 0, 0)
    AddTooltip(box, Text(key), Text(info.tip or (key .. "Tip")))
    box:SetScript("OnClick", function(self)
        Addon.db[key] = self:GetChecked() and true or false
        Changed(key)
        page.Refresh()
    end)
    Register(page, row, box, y, height, function() box:SetChecked(Addon.db[key] and true or false) end, info.parent)
    return y + height
end

local function Slider(page, y, info)
    local key, indent = info.key, info.parent and 22 or 0
    local row = CreateFrame("Frame", nil, page.content)
    row:SetPoint("TOPLEFT", page.content, "TOPLEFT", 6 + indent, -y)
    row:SetSize(ROW_WIDTH - indent, 48)
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 0, -2)
    label:SetText(Text(key))
    local bar = CreateFrame("Slider", nil, row)
    bar:SetOrientation("HORIZONTAL")
    bar:SetSize(260, 16)
    bar:SetPoint("TOPLEFT", 0, -24)
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
    local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    value:SetPoint("LEFT", bar, "RIGHT", 10, 0)
    local percent = info.max <= 3
    local function Show(v) value:SetText(percent and (math.floor(v * 100 + 0.5) .. "%") or tostring(math.floor(v + 0.5))) end
    bar:SetScript("OnValueChanged", function(_, v)
        v = tonumber(string.format("%.4f", math.floor(v / info.step + 0.5) * info.step))
        Show(v)
        if bar.syncing or Addon.db[key] == v then return end
        Addon.db[key] = v
        Changed(key)
    end)
    AddTooltip(bar, Text(key), Text(info.tip or (key .. "Tip")))
    AddTooltip(row, Text(key), Text(info.tip or (key .. "Tip")))
    Register(page, row, bar, y, 48, function()
        bar.syncing = true
        bar:SetValue(Addon.db[key])
        Show(Addon.db[key])
        bar.syncing = false
    end, info.parent)
    return y + 50
end

local function Choice(page, y, key, parent)
    local choices = Addon.Options.choices[key]
    local row = CreateFrame("Frame", nil, page.content)
    row:SetPoint("TOPLEFT", page.content, "TOPLEFT", 6, -y)
    row:SetSize(ROW_WIDTH, 34)
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", 2, 0)
    label:SetText(Text(key))
    local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    button:SetSize(230, 24)
    button:SetPoint("LEFT", row, "LEFT", 300, 0)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local function Name()
        for _, choice in ipairs(choices) do
            if choice[1] == Addon.db[key] then return choice[2] end
        end
        return tostring(Addon.db[key])
    end
    -- Step to the next choice (or the previous one: right click, D-pad left).
    function button.StepChoice(direction)
        local index = 1
        for i, choice in ipairs(choices) do
            if choice[1] == Addon.db[key] then index = i end
        end
        Addon.db[key] = choices[(index - 1 + direction) % #choices + 1][1]
        button:SetText(Name())
        Changed(key)
    end
    button:SetScript("OnClick", function(_, mouse) button.StepChoice(mouse == "RightButton" and -1 or 1) end)
    AddTooltip(button, Text(key), Text(key .. "Tip"))
    Register(page, row, button, y, 34, function() button:SetText(Name()) end, parent)
    return y + 36
end

local function Button(page, y, label, tip, action, parent)
    local row = CreateFrame("Frame", nil, page.content)
    row:SetPoint("TOPLEFT", page.content, "TOPLEFT", 6, -y)
    row:SetSize(ROW_WIDTH, 34)
    local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    button:SetSize(300, 24)
    button:SetPoint("LEFT", 2, 0)
    button:SetText(label)
    button.baseText = label
    button:SetScript("OnClick", action)
    AddTooltip(button, label, tip)
    Register(page, row, button, y, 34, function() end, parent)
    return y + 36
end

-- ---------------------------------------------------------------------------------------------
-- Pages: a scrolling column per tab, built the first time the tab is shown
-- ---------------------------------------------------------------------------------------------

local function BuildPage(window, tab)
    local page = CreateFrame("Frame", nil, window)
    page:SetPoint("TOPLEFT", MARGIN, -(HEADER + TAB_HEIGHT + 4))
    page:SetPoint("BOTTOMRIGHT", -MARGIN, MARGIN + HINT_HEIGHT)
    page:Hide()
    page.nodes, page.refresh = {}, {}
    local scroll = CreateFrame("ScrollFrame", nil, page)
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -SCROLL_WIDTH, 0)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(ROW_WIDTH + 12, 1)
    scroll:SetScrollChild(content)
    local bar = CreateFrame("Slider", nil, page)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(12)
    bar:SetPoint("TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", 0, 0)
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

    local y = 4
    for _, item in ipairs(tab.items) do
        local kind = item[1]
        if kind == "header" then y = Header(page, y, item[2])
        elseif kind == "note" then y = Note(page, y, item[2])
        elseif kind == "choice" then y = Choice(page, y, item[2], item[3])
        elseif kind == "button" then y = Button(page, y, item[2], item[3], item[4], item[5])
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
    self.page.Reveal(node)
    local enter = node:GetScript("OnEnter")
    if enter then enter(node) end
end

function Window:Nodes()
    local nodes = {}
    for _, node in ipairs(self.page and self.page.nodes or {}) do
        if not node.dimmed then nodes[#nodes + 1] = node end
    end
    return nodes
end

-- Moves, adjusts or activates on a pad button; true when the window used the button.
function Window:PadButton(key)
    -- The keyboard owns the pad while it is shown; both reacting to one press would move two selections.
    local keyboard = Addon.Keyboard and Addon.Keyboard.frame
    if keyboard and keyboard:IsShown() and Addon:IsGamepadMode() then return false end
    if key == "PAD2" then
        self:Hide()
        return true
    elseif key == "PADLSHOULDER" or key == "PADRSHOULDER" then
        self:SelectTab((self.index - 1 + (key == "PADLSHOULDER" and -1 or 1)) % #self.tabs + 1)
        return true
    end
    local step = ({ PADDUP = -1, PADDDOWN = 1 })[key]
    local nodes = self:Nodes()
    if #nodes == 0 then return key == "PAD1" or step ~= nil or key == "PADDLEFT" or key == "PADDRIGHT" end
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
        if node.Click and not (node.GetObjectType and node:GetObjectType() == "Slider") then node:Click("LeftButton") end
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

function Window:SelectTab(index)
    local tab = self.tabs[index]
    if not tab then return end
    self.index = index
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
    frame:SetSize(WIDTH, HEADER + TAB_HEIGHT + BODY_HEIGHT + MARGIN + HINT_HEIGHT)
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
    local x = MARGIN + 2
    for index, tab in ipairs(self.tabs) do
        local created, button = pcall(CreateFrame, "Button", nil, frame, "PanelTopTabButtonTemplate")
        if not created then button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate") end
        button:SetText(tab.label)
        local label = button.GetFontString and button:GetFontString()
        local width = label and tonumber(label:GetStringWidth()) or 60
        button:SetSize(math.max(64, math.ceil(width) + 24), TAB_HEIGHT - 2)
        button:SetPoint("TOPLEFT", x, -HEADER)
        button:SetScript("OnClick", function() self:SelectTab(index) end)
        x = x + button:GetWidth() + 4
        self.tabButtons[index] = button
    end

    -- The pad hint under the pages, only while a controller is in use.
    self.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.hint:SetPoint("BOTTOMLEFT", 14, 10)
    self.hint:SetPoint("BOTTOMRIGHT", -14, 10)
    self.hint:SetJustifyH("LEFT")
    frame:HookScript("OnShow", function()
        self.hint:SetText(Addon:IsGamepadMode() and string.format(Text("padHint"), Key("PADDUP"), Key("PADDDOWN"),
            Key("PADDLEFT"), Key("PADDRIGHT"), Key("PAD1"), Key("PAD2"), Key("PADLSHOULDER"), Key("PADRSHOULDER")) or "")
        if self.page then
            self.page.Refresh()
            self.page.SyncBar()
        end
        self:EnablePad()
    end)
    frame:HookScript("OnHide", function() self:Mark(nil) end)
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
