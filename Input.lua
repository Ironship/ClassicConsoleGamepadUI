local _, Addon = ...
local Input = { dirty = true, activeBarFrameLevel = 5, state = "idle" }
Addon.Input = Input

local SETUP = [[
    bars, anchors, sources, delegates, owners = newtable(), newtable(), newtable(), newtable(), newtable()
    mouseFrames = newtable()
    for i = 1, 9 do
        bars[i] = self:GetFrameRef("bar" .. i)
        sources[i], delegates[i] = newtable(), newtable()
        for j = 1, 8 do
            sources[i][j] = self:GetFrameRef("source" .. i .. "-" .. j)
            delegates[i][j] = self:GetAttribute("delegate" .. i .. "-" .. j)
        end
    end
    for i = 1, 4 do anchors[i] = self:GetFrameRef("anchor" .. i) end
]]

-- Secure handlers reject the function keyword and table constructors.
-- pickbar runs with (self, index) and reads the tables built above.
local PICK_BAR = [[
    local index = ...
    local key
    for i = 1, 4 do
        if bars[i]:IsShown() then key = index; break end
    end
    for i = 5, 6 do
        if bars[i] and bars[i]:IsShown() and bars[i]:GetParent() == anchors[index] then key = i end
    end
    if index == 1 then
        for i = 7, 9 do
            if bars[i] and bars[i]:IsShown() then key = i end
        end
    end
    return key
]]

-- /cgp clicks: every click of a hitbox is printed after it ran, with what the secure code made of it (type, action, what
-- the action is, macro text of a delegated click). A post-click script of the addon, so nothing protected is touched.
local function TraceClick(self, _, down)
    if not Addon.traceClicks then return end
    local kind, action = self:GetAttribute("type"), self:GetAttribute("action")
    local info, id
    if type(action) == "number" then
        local ok, first, second = pcall(GetActionInfo, action)
        if ok then info, id = first, second end
    end
    Addon:Print(string.format("click %s %s: type=%s action=%s is=%s %s macrotext=%s", tostring(self:GetName()),
        down and "down" or "up", tostring(kind), tostring(action), tostring(info), tostring(id),
        tostring(self:GetAttribute("macrotext") or "-")))
end

local PRE_CLICK = [[
    self:SetAttribute("type", nil)
    if not down then self:SetAttribute("cgppressed", nil) end
    if self:GetAttribute("cgpplaced") then
        self:SetAttribute("cgpplaced", nil)
        owners[self] = nil
        self:SetAttribute("cgppressed", nil)
        return false
    end
    local keyboard = button == "Keybind"
    if (button ~= "LeftButton" and not keyboard) or not control:GetAttribute("enabled") then return false end
    local source, kind, place, act
    if down then
        self:SetAttribute("cgppressed", true)
        local group, index = self:GetAttribute("group"), self:GetAttribute("index")
        if group == 0 then
            source, kind = control:GetFrameRef("class" .. index), "delegate"
            if not source or not source:IsShown() then
                -- No class action: the keyboard bar's button at this position (9 or 10).
                place = index + 8
                source, kind = control:GetFrameRef("kbd" .. place), "kbd"
                if not source then return false end
            end
        elseif group == 5 then
            -- Spare main-row slots: the keyboard bar's button at the same position.
            place = index
            source, kind = control:GetFrameRef("kbd" .. place), "kbd"
            if not source then return false end
        else
            if group == 6 then
                -- A pad button (setting "padKeyboard"): the row in use decides, which is the game's active bar.
                group = 1
                for i = 2, 4 do
                    local shown = control:RunAttribute("pickbar", i)
                    if shown and bars[shown]:GetFrameLevel() == control:GetAttribute("activelevel") then group = i end
                end
            elseif group == 1 and control:GetAttribute("compact") then
                local combined = control:RunAttribute("pickbar", 4)
                if combined and bars[combined]:GetFrameLevel() == control:GetAttribute("activelevel") then group = 4 end
            end
            local key = control:RunAttribute("pickbar", group)
            if not key then return false end
            source = sources[key][index]
            kind = key == 5 and "pet" or (delegates[key][index] and "delegate" or "action")
            if control:GetAttribute("padkeyboard") and key <= 4 and not delegates[key][index] then
                -- The keyboard bar's button at the slot's place stands in for the pad's own action. The game's own
                -- four (interact, target menu, back, jump) and the bars that take a row over stay as they are.
                place = control:GetAttribute("padslot" .. group .. "-" .. index)
                local keyboardButton = place and control:GetFrameRef("kbd" .. place)
                if keyboardButton then source, kind = keyboardButton, "kbd" end
            end
            if kind == "action" then
                local action = source:GetID()
                if not action or action <= 0 then return false end
                local actionType = GetActionInfo(action)
                if actionType == "flyout" then kind = "flyout" end
            end
        end
        if kind == "kbd" then
            -- A keyboard bar's button: its action slot is worked out here (the button's position plus its bar's page, the
            -- way the game does it) and used like the controller's own action. Clicking the button instead, as macro text
            -- ("/click") or as a click type, does not do for macros: the game does not run a macro from within a macro,
            -- and the "click" type needs a real frame in an attribute, which a secure snippet cannot set.
            local page = control:GetAttribute("kbdpage" .. place)
            if not page then
                -- Only the main bar (places 1-12) has a page that changes; for the others it is set from outside combat.
                if place > 12 then return false end
                -- The main bar: the page the game's action bar controller puts on it.
                if HasVehicleActionBar() then page = GetVehicleBarIndex()
                elseif HasOverrideActionBar() then page = GetOverrideBarIndex()
                elseif HasTempShapeshiftActionBar() then page = GetTempShapeshiftBarIndex()
                elseif HasBonusActionBar() and GetActionBarPage() == 1 then page = GetBonusBarIndex()
                else page = GetActionBarPage() end
            end
            act = source:GetID() + (page - 1) * 12
            local kbdType, kbdId = GetActionInfo(act)
            if kbdType == "flyout" then
                local single = control:GetAttribute("kbdflyspell" .. place)
                if single then
                    kind, act = "spell", single
                elseif not PlayerInCombat() then
                    kind, act = "kbdflyout", place .. ":" .. tostring(kbdId or 0)
                else
                    kind = "delegate"
                end
            else
                kind = "action"
            end
        end
        local owner = newtable()
        owner[1], owner[2], owner[3] = source, kind, act
        owners[self] = owner
    else
        local owner = owners[self]
        owners[self] = nil
        if not owner then return false end
        source, kind, act = owner[1], owner[2], owner[3]
    end
    if kind == "kbdflyout" then
        if down and not keyboard then return false end
        if down or not keyboard then control:SetAttribute("kbdflyout", act) end
        return false
    elseif kind == "flyout" then
        if down and not keyboard then return false end
        if not down and keyboard then return false end
        self:SetAttribute("type", "macro")
        self:SetAttribute("useOnKeyDown", down)
        self:SetAttribute("macrotext", "/click " .. source:GetName() .. " LeftButton 1")
    elseif kind == "delegate" then
        self:SetAttribute("type", "macro")
        self:SetAttribute("useOnKeyDown", down)
        self:SetAttribute("macrotext", "/click " .. source:GetName() .. " LeftButton " .. (down and "1" or "0"))
    elseif down and not keyboard then
        return false
    elseif kind == "spell" then
        if keyboard then self:SetAttribute("useOnKeyDown", nil)
        else self:SetAttribute("useOnKeyDown", false) end
        self:SetAttribute("type", "spell")
        self:SetAttribute("spell", act)
    else
        local action = act or source:GetID()
        if not action or action <= 0 then return false end
        if keyboard then self:SetAttribute("useOnKeyDown", nil)
        else self:SetAttribute("useOnKeyDown", false) end
        local attack
        if kind == "action" and control:GetAttribute("attackstart") then
            -- Setting "attackStart": the Auto Attack action only starts the attack. The action itself is a toggle, so a second
            -- press would stop it, which a /startattack does not.
            local actionType, actionId = GetActionInfo(action)
            attack = actionType == "spell" and actionId == 6603
        end
        if attack then
            self:SetAttribute("type", "macro")
            self:SetAttribute("macrotext", "/startattack")
        else
            self:SetAttribute("type", kind)
            self:SetAttribute("action", action)
        end
    end
    return "LeftButton"
]]

local APPLY_BINDINGS = [[
    self:ClearBindings()
    if self:GetAttribute("enabled") then
        for i = 1, self:GetAttribute("bindingcount") or 0 do
            self:SetBindingClick(true, self:GetAttribute("key" .. i), self:GetAttribute("button" .. i), "Keybind")
        end
    end
]]

-- Runs inside the secure header so EnableMouse does not taint the native buttons.
-- A tainted action button makes the client's later SetPreferredGamepadInteractTarget fail.
local SUPPRESS_MOUSE = [[
    local restore = self:GetAttribute("mouserestore")
    for i = 1, self:GetAttribute("mousecount") do
        if not self:GetAttribute("mouseblocked" .. i) then
            local frame = self:GetFrameRef("mouse" .. i)
            if restore then
                if mouseFrames[frame] then
                    frame:EnableMouse(true)
                    mouseFrames[frame] = nil
                end
            elseif frame:IsMouseEnabled() then
                mouseFrames[frame] = true
                frame:EnableMouse(false)
            end
        end
    end
    self:SetAttribute("mousecomplete", true)
]]

-- Runs inside the secure header so anchoring the native flyout radial and its attached
-- button above the classic slot does not taint either protected frame.
local PLACE_FLYOUT = [[
    local fly = self:GetFrameRef("flyout")
    local btn = self:GetFrameRef("flybutton")
    local x, y = self:GetAttribute("flyx"), self:GetAttribute("flyy")
    if fly and x and y then
        fly:ClearAllPoints()
        fly:SetPoint("CENTER", "$parent", "BOTTOMLEFT", x, y)
    end
    if btn and fly then
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", fly, "CENTER", 0, 0)
    end
]]

local RESTORE_FLYOUT_BUTTON = [[
    local btn = self:GetFrameRef("flybutton")
    if not btn then return end
    btn:ClearAllPoints()
    for i = 1, self:GetAttribute("flyptcount") or 0 do
        local rel = self:GetAttribute("flypt" .. i .. "parent") and "$parent" or self:GetFrameRef("flypt" .. i .. "r")
        if rel then
            btn:SetPoint(
                self:GetAttribute("flypt" .. i .. "a"),
                rel,
                self:GetAttribute("flypt" .. i .. "b"),
                self:GetAttribute("flypt" .. i .. "x") or 0,
                self:GetAttribute("flypt" .. i .. "y") or 0
            )
        end
    end
]]

local RESUME = [[
    if control:GetAttribute("enabled") and control:GetFrameRef("native"):IsShown() then
        for i = 1, control:GetAttribute("blockercount") or 0 do
            if control:GetFrameRef("blocker" .. i):IsShown() then return end
        end
        control:Show()
    end
]]

-- Face buttons (native 5-8, X Y B A) sit on the left of each row of eight and the cross (native 1-4) on the right,
-- or the other way round with the setting "crossFirst" (Layout.RowStart).
local function RowIndex(offset)
    if offset <= 4 then return Addon.Layout.RowStart(false) + offset - 1 end
    return Addon.Layout.RowStart(true) + offset - 5
end

local function SlotAction(i)
    if i <= 8 then return 1, RowIndex(i) end
    if i <= 10 then return 0, i - 8 end
    if i <= 12 then return 5, i end
    if i >= 13 and i <= 20 then return 2, RowIndex(i - 12) end
    if i >= 21 and i <= 24 then return 4, Addon.Layout.RowStart(false) + i - 21 end
    if i >= 25 and i <= 32 then return 3, RowIndex(i - 24) end
    if i >= 33 and i <= 36 then return 4, Addon.Layout.RowStart(true) + i - 33 end
end

-- The bar and the native button (1-8) a slot stands for, for the key map window (KeyMap.lua).
Input.SlotAction = SlotAction

-- The slot (1-36) that shows the native button (1-8) of a row (1 no trigger, 2 LT, 3 RT, 4 both).
function Input.PadSlot(group, native)
    for i = 1, 36 do
        local slotGroup, slotNative = SlotAction(i)
        if slotGroup == group and slotNative == native then return i end
    end
end

-- Setting "padKeyboard": the pad's eight bar buttons press the keyboard bars' buttons, so an action sits in the same
-- place with the keyboard and with the pad. The game binds the eight with priority override bindings of UIParent
-- (Blizzard_GamepadSharedUtility, InputBindingStack); the same kind of binding of our header takes their place, which
-- /cgp padtest showed in game. While a menu or a window owns the pad (a binding set above the game's core set) the eight
-- are left alone.
local function PadFree()
    local manager = GamepadSharedUtility and GamepadSharedUtility.InputBindingManager
    if not manager or not manager.IsOnlyCoreBindingSetActive then return true end
    local ok, core = pcall(manager.IsOnlyCoreBindingSetActive, manager)
    return not ok or core == true
end

-- Wheels.lua leaves the pad alone in the same cases.
Input.PadFree = PadFree

function Input:PadWanted()
    return Addon.db.padKeyboard == true and self.padButtons ~= nil and PadFree()
end

function Input:SyncNativeMouse(restore)
    local header = self.header
    if not header or (self.disabled and not restore) or InCombatLockdown() then return end
    -- Snippets are not vararg functions, so the flag travels as an attribute.
    -- Skip repeat walks; refresh runs several times a second.
    local want = restore and true or false
    if self.mouseRestored == want then return end
    Addon:Trace("Input:SyncNativeMouse " .. tostring(want))
    local ok, err = pcall(function()
        if not want then
            -- Read the tree before changing mouse state; keep these exact frames for restoration.
            if self.nativeMouseRoot:IsForbidden() then error("Native mouse root is forbidden") end
            local frames = { self.nativeMouseRoot }
            local i = 1
            while i <= #frames do
                local frame = frames[i]
                if not frame:IsForbidden() then
                    for _, child in ipairs({ frame:GetChildren() }) do
                        if not child:IsForbidden() then frames[#frames + 1] = child end
                    end
                end
                i = i + 1
            end
            self.mouseFrames = frames
            for index, frame in ipairs(frames) do
                if not frame:IsForbidden() then header:SetFrameRef("mouse" .. index, frame) end
            end
            header:SetAttribute("mousecount", #frames)
        end
        local blocked = 0
        for index, frame in ipairs(self.mouseFrames or {}) do
            local forbidden = frame:IsForbidden()
            header:SetAttribute("mouseblocked" .. index, forbidden)
            if forbidden then blocked = blocked + 1 end
        end
        header:SetAttribute("mousecomplete", nil)
        header:SetAttribute("mouserestore", want)
        header:Execute(SUPPRESS_MOUSE)
        if header:GetAttribute("mousecomplete") ~= true then
            error("Native mouse snippet did not complete; see the client's Lua error report")
        end
        if want and blocked > 0 then
            error("Native mouse restoration skipped " .. blocked .. " forbidden frames")
        end
    end)
    if ok then
        self.mouseRestored = want
        self.mouseRestoreError = nil
    else
        -- A partial walk changed mouse state; restoration must not use the old cache.
        self.mouseRestored = nil
        if restore then
            err = tostring(err)
            if self.mouseRestoreError ~= err then
                Addon:Print("Native mouse restoration failed: " .. err .. ". Reload the UI if controls remain blocked.")
            end
            self.mouseRestoreError = err
        else
            self:Disable(err)
        end
    end
end

function Input:IsEnabled()
    return not self.disabled and self.header and self.header:GetAttribute("enabled")
end

function Input:RefreshTooltip()
    local button, slot = self.tooltipButton, self.tooltipSlot
    if not button or GameTooltip:GetOwner() ~= button then return end
    local source = slot.source
    if not source then GameTooltip:Hide(); return end
    -- Native SetTooltip writes UpdateTooltip onto the Blizzard button.
    local action = source:GetID()
    -- A keyboard bar button: GetID is its position, .action the action it holds.
    if slot.keyboardSlot and type(source.action) == "number" and (not issecretvalue or not issecretvalue(source.action)) then
        action = source.action
    end
    local spellID = source.GetSingleSpellID and source:GetSingleSpellID()
    local bar = source.parentActionBar
    if bar and bar.faceLeftButton == source then spellID = bar.rangedSpellID or spellID end
    if spellID then
        GameTooltip:SetSpellByID(spellID)
    elseif source.isGamepadPossessBarButton then
        GameTooltip:SetPetAction(action)
    elseif action and action > 0 then
        if not GameTooltip:SetAction(action) then GameTooltip:Hide() end
    else
        GameTooltip:Hide()
    end
end

function Input:IsBlocked()
    if self.disabled then return false end
    if not InCombatLockdown() and SettingsPanel and SettingsPanel:IsShown() then
        self.blockedBy = "SettingsPanel"
        return true
    end
    for frame in pairs(self.blockers or {}) do
        if frame:IsShown() then
            self.blockedBy = frame:GetName() or "unnamed"
            return true
        end
    end
    self.blockedBy = nil
    return false
end

function Input:Disable(err)
    if self.disabled then return end
    self.disabled = true
    self.lastError = tostring(err or "unknown error")
    self.state = "error"
    Addon:Print("Mouse/keyboard layer disabled: " .. self.lastError)
    self:RestoreAfterError()
end

function Input:RestoreAfterError()
    if not self.header or InCombatLockdown() then return end
    local ok, err = pcall(function()
        if self.header:GetAttribute("enabled") then self.header:SetAttribute("enabled", false) end
        if self.header:IsShown() then self.header:Hide() end
    end)
    if not ok then
        err = tostring(err)
        if self.cleanupError ~= err then Addon:Print("Input cleanup failed: " .. err) end
        self.cleanupError = err
    else
        self.cleanupError = nil
    end
    -- Restore known changed frames, even if hiding the click layer failed.
    self:SyncNativeMouse(true)
end

local function SetRef(header, label, frame)
    if frame then pcall(header.SetFrameRef, header, label, frame) end
end

-- The page of each keyboard bar that has a fixed one (the two lower bars; the main bar's page changes and is worked out in
-- PRE_CLICK). Taken from what the button holds: its action slot is its position plus (page - 1) * 12. (The buttons hang off a
-- container of the bar, not off the bar, so the bar's own "actionpage" attribute is not at hand.) Outside combat; true when
-- every place has its page.
function Input:SetKeyboardPages()
    local header = self.header
    if not header or InCombatLockdown() then return false end
    local complete = true
    for i = 13, 36 do
        local slot = Addon.Display.slots[i]
        local template = slot and slot.template
        local action, id = template and template.action, template and template:GetID()
        local page
        if type(action) == "number" and type(id) == "number" and id > 0 and (not issecretvalue or not issecretvalue(action))
            and (action - id) % 12 == 0 and action - id >= 12 then
            page = (action - id) / 12 + 1
        end
        if page then
            if header:GetAttribute("kbdpage" .. i) ~= page then header:SetAttribute("kbdpage" .. i, page) end
        else
            complete = false
        end
    end
    self.pagesSet = complete
    self:SyncKeyboardFlyouts()
    return complete
end

-- Resolves single-spell flyouts on keyboard-backed slots so PRE_CLICK casts them directly in and out of combat.
function Input:SyncKeyboardFlyouts()
    local header = self.header
    if not header or InCombatLockdown() or not Addon.FlyoutSpells then return end
    for i = 1, 36 do
        local slot = Addon.Display.slots[i]
        local template = slot and slot.template
        local action = template and template.action
        local single
        if type(action) == "number" and action > 0 and (not issecretvalue or not issecretvalue(action)) then
            local ok, kind, id = pcall(GetActionInfo, action)
            if ok and kind == "flyout" and id then
                local _, s = Addon.FlyoutSpells(id)
                single = s
            end
        end
        if header:GetAttribute("kbdflyspell" .. i) ~= single then
            header:SetAttribute("kbdflyspell" .. i, single)
        end
    end
end

function Input:HideKbdFlyout()
    if self.kbdFlyout and not InCombatLockdown() and self.kbdFlyout:IsShown() then
        self.kbdFlyout:Hide()
    end
    self.kbdFlyoutKey = nil
end

-- Addon-owned secure flyout bar for multi-spell flyouts on keyboard-backed slots (hidden Blizzard bars cannot show SpellFlyout).
function Input:ToggleKbdFlyout(spec)
    if InCombatLockdown() or type(spec) ~= "string" then return end
    if self.header then self.header:SetAttribute("kbdflyout", nil) end
    local placeStr, idStr = spec:match("^(%d+):(%d+)$")
    local place, flyoutID = tonumber(placeStr), tonumber(idStr)
    if not place or not flyoutID or flyoutID <= 0 then self:HideKbdFlyout(); return end
    if self.kbdFlyout and self.kbdFlyout:IsShown() and self.kbdFlyoutKey == spec then
        self:HideKbdFlyout()
        return
    end
    local spells = Addon.FlyoutSpells and Addon.FlyoutSpells(flyoutID) or {}
    if #spells == 0 then self:HideKbdFlyout(); return end
    local anchor = self.buttons[place] or (Addon.Display.slots[place])
    if not anchor then return end
    if not self.kbdFlyout then
        local popup = CreateFrame("Frame", "ClassicConsoleGamepadUIFlyout", UIParent, "BackdropTemplate")
        popup:SetFrameStrata("DIALOG")
        popup:SetFrameLevel(20)
        popup:EnableMouse(true)
        popup:SetClampedToScreen(true)
        popup:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        popup:SetBackdropColor(0.06, 0.06, 0.08, 0.92)
        popup:SetBackdropBorderColor(0.55, 0.45, 0.25, 0.95)
        popup.buttons = {}
        for i = 1, 12 do
            local btn = CreateFrame("Button", "ClassicConsoleGamepadUIFlyoutButton" .. i, popup, "SecureActionButtonTemplate")
            btn:SetSize(36, 36)
            btn:RegisterForClicks("AnyUp")
            btn:SetAttribute("type", "spell")
            btn.Icon = btn:CreateTexture(nil, "ARTWORK")
            btn.Icon:SetAllPoints()
            btn.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.25)
            btn:SetScript("PostClick", function() Input:HideKbdFlyout() end)
            btn:SetScript("OnEnter", function(s)
                if s.spellID then
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    GameTooltip:SetSpellByID(s.spellID)
                end
            end)
            btn:SetScript("OnLeave", function(s)
                if GameTooltip:GetOwner() == s then GameTooltip:Hide() end
            end)
            popup.buttons[i] = btn
        end
        popup:RegisterEvent("PLAYER_REGEN_DISABLED")
        popup:SetScript("OnEvent", function() Input:HideKbdFlyout() end)
        self.kbdFlyout = popup
    end
    local popup = self.kbdFlyout
    local count = math.min(#spells, #popup.buttons)
    local size, gap, pad = 36, 4, 6
    popup:SetSize(size + pad * 2, count * size + (count - 1) * gap + pad * 2)
    popup:ClearAllPoints()
    popup:SetPoint("BOTTOM", anchor, "TOP", 0, 6)
    for i, btn in ipairs(popup.buttons) do
        local entry = i <= count and spells[i] or nil
        if entry then
            btn.spellID = entry.id
            btn:SetAttribute("spell", entry.id)
            local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(entry.id)
            btn.Icon:SetTexture(tex)
            btn:ClearAllPoints()
            btn:SetPoint("BOTTOM", popup, "BOTTOM", 0, pad + (i - 1) * (size + gap))
            btn:Show()
        else
            btn.spellID = nil
            btn:SetAttribute("spell", nil)
            btn:Hide()
        end
    end
    self.kbdFlyoutKey = spec
    popup:Show()
end

function Input:Create(native, unit, bars)
    local header = CreateFrame("Frame", "ClassicConsoleGamepadUIInput", UIParent, "SecureHandlerShowHideTemplate")
    header:SetFrameStrata(Addon.Display.root:GetFrameStrata())
    header:SetFrameLevel(Addon.Display.root:GetFrameLevel() + 5)
    header:Hide()
    self.header, self.buttons, self.blockers = header, {}, {}
    self.nativeMouseRoot = native
    self.mouseRestored = true
    header:SetAttribute("mousecount", 0)
    header:SetFrameRef("native", native)
    header:SetAttribute("_onshow", APPLY_BINDINGS)
    header:SetAttribute("_onhide", "self:ClearBindings()")
    header:SetAttribute("activelevel", self.activeBarFrameLevel)
    header:SetAttribute("pickbar", PICK_BAR)
    header:HookScript("OnAttributeChanged", function(_, name, value)
        if name == "kbdflyout" and value then self:ToggleKbdFlyout(value) end
    end)
    pcall(SecureHandlerWrapScript, native, "OnHide", header, [[control:SetAttribute("enabled", false); control:Hide()]])
    for i, key in ipairs({ "topBar", "leftBar", "rightBar", "bottomBar", "possessBar", "stanceBar",
        "FriendlyTargetingActionBar", "HostileTargetingActionBar", "ShortcutsActionBar" }) do
        local bar = i <= 6 and unit.actionBars[key] or unit[key]
        if bar then
            SetRef(header, "bar" .. i, bar)
            for j, source in ipairs(bar.actionButtons) do
                SetRef(header, "source" .. i .. "-" .. j, source)
                local pageSlot = source.GetGamepadPageUnitSlotID and source:GetGamepadPageUnitSlotID()
                local reserved = pageSlot and GamepadActionBarBindingUtil.IsReservedPageUnitSlotID(pageSlot)
                header:SetAttribute("delegate" .. i .. "-" .. j, i >= 7 or reserved or false)
            end
        end
    end
    for i, anchor in ipairs({ unit.TopCenteredAnchor, unit.LeftCenteredAnchor, unit.RightCenteredAnchor, unit.BottomCenteredAnchor }) do
        SetRef(header, "anchor" .. i, anchor)
    end
    SetRef(header, "class1", unit.LeftClassAction)
    SetRef(header, "class2", unit.RightClassAction)
    -- The keyboard bar's buttons 9-12 serve the main-row positions without a gamepad action.
    for position = 9, 12 do
        SetRef(header, "kbd" .. position, MainActionBar and MainActionBar.actionButtons[position])
    end
    -- Setting "padKeyboard": every slot's keyboard bar button, and one hitbox for each of the pad's eight bar buttons.
    for i = 1, 36 do
        local slot = Addon.Display.slots[i]
        if slot and slot.template and (i < 9 or i > 12) then SetRef(header, "kbd" .. i, slot.template) end
    end
    self.padButtons = {}
    for native = 1, 8 do
        local button = CreateFrame("Button", "ClassicConsoleGamepadUIPadButton" .. native, header, "SecureActionButtonTemplate")
        button:SetID(0)
        button:SetAttribute("group", 6)
        button:SetAttribute("index", native)
        button:SetAttribute("checkselfcast", true)
        button:SetAttribute("checkfocuscast", true)
        button:RegisterForClicks("AnyDown", "AnyUp")
        SecureHandlerWrapScript(button, "OnClick", header, PRE_CLICK)
        button:HookScript("PostClick", TraceClick)
        SecureHandlerWrapScript(button, "OnHide", header, [[owners[self] = nil; self:SetAttribute("cgppressed", nil)]])
        button:SetScript("OnAttributeChanged", function(_, name)
            if name == "cgppressed" then Addon:QueueRefresh() end
        end)
        self.padButtons[native] = button
    end
    header:Execute(SETUP)
    self:SetKeyboardPages()
    for i, slot in ipairs(Addon.Display.slots) do
        local group, index = SlotAction(i)
        if group then
            -- Protected hitboxes are separate from the freely refreshed visual frames.
            local button = CreateFrame("Button", "ClassicConsoleGamepadUIInputButton" .. i, header, "SecureActionButtonTemplate")
            button:SetID(0)
            button:SetAttribute("group", group)
            button:SetAttribute("index", index)
            button:SetAttribute("checkselfcast", true)
            button:SetAttribute("checkfocuscast", true)
            button:SetAttribute("checkmouseovercast", true)
            button:RegisterForClicks("AnyDown", "AnyUp")
            button:RegisterForDrag("LeftButton")
            button:SetScript("PreClick", function(self, btn, down)
                if InCombatLockdown() or btn ~= "LeftButton" or not GetCursorInfo() then return end
                if not down then Addon.Display:ReceiveSlot(slot) end
                self:SetAttribute("cgpplaced", true)
            end)
            SecureHandlerWrapScript(button, "OnClick", header, PRE_CLICK)
            button:HookScript("PostClick", TraceClick)
            button:SetScript("OnDragStart", function() Addon.Display:PickupSlot(slot) end)
            SecureHandlerWrapScript(button, "OnDragStart", header, [[owners[self] = nil; self:SetAttribute("type", nil); self:SetAttribute("cgppressed", nil)]])
            SecureHandlerWrapScript(button, "OnHide", header, [[owners[self] = nil; self:SetAttribute("cgppressed", nil)]])
            button:SetScript("OnReceiveDrag", function() Addon.Display:ReceiveSlot(slot) end)
            button:SetScript("OnAttributeChanged", function(_, name, value)
                if name == "cgppressed" then
                    slot.Pushed:SetShown(value == true)
                    Addon:QueueRefresh()
                end
            end)
            slot.inputButton = button
            button:SetScript("OnEnter", function()
                self.tooltipButton, self.tooltipSlot = button, slot
                GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                self:RefreshTooltip()
            end)
            button:SetScript("OnLeave", function()
                if GameTooltip:GetOwner() == button then GameTooltip:Hide() end
                self.tooltipButton, self.tooltipSlot = nil, nil
            end)
            slot.Key = slot.Labels:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            slot.Key:SetPoint("BOTTOMLEFT", 5, 5)
            slot.Key:SetPoint("BOTTOMRIGHT", -5, 5)
            slot.Key:SetJustifyH("LEFT")
            slot.Key:SetWordWrap(false)
            slot:EnableMouse(false)
            self.buttons[i] = button
        end
    end
    self:ObserveBlockers(bars, unit)
end

function Input:HookFlyoutPosition(frame)
    self.hookedFlyouts = self.hookedFlyouts or {}
    if self.hookedFlyouts[frame] or type(frame.AttachToButton) ~= "function" then return end
    local detachName = type(frame.DetatchFromButton) == "function" and "DetatchFromButton"
        or (type(frame.DetachFromButton) == "function" and "DetachFromButton")
    if not detachName then return end
    self.hookedFlyouts[frame] = true
    self.attachedFlyoutButton = self.attachedFlyoutButton or {}
    self.savedFlyoutPoints = self.savedFlyoutPoints or {}
    self.pendingFlyoutRestore = self.pendingFlyoutRestore or {}
    hooksecurefunc(frame, "AttachToButton", function(flyout, button)
        self:PlaceFlyout(flyout, button)
    end)
    hooksecurefunc(frame, detachName, function(flyout)
        local button = self.attachedFlyoutButton[flyout]
        self.attachedFlyoutButton[flyout] = nil
        if button then self:RestoreFlyoutButton(button) end
    end)
end

function Input:PlaceFlyout(flyout, button)
    if not flyout or not button or self.disabled or not self.header or InCombatLockdown() then return end
    if Addon.nativeView then return end
    if (GamepadActionBarEditFrame and GamepadActionBarEditFrame:IsShown())
        or (EditModeManagerFrame and EditModeManagerFrame:IsShown()) then return end
    local root = Addon.Display and Addon.Display.root
    if not root or not root:IsShown() then return end
    local slot = Addon.Display.slotBySource and Addon.Display.slotBySource[button]
    if not slot or not slot:IsShown() then return end

    local sx, sy = slot:GetCenter()
    if not sx or not sy then return end
    local st = slot:GetTop() or sy
    local sScale = (slot.GetEffectiveScale and slot:GetEffectiveScale()) or 1
    local fScale = (flyout.GetEffectiveScale and flyout:GetEffectiveScale()) or 1
    local uScale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    if fScale <= 0 then fScale = 1 end
    local fw = (flyout.GetWidth and flyout:GetWidth()) or 200
    local fh = (flyout.GetHeight and flyout:GetHeight()) or 200
    if fw <= 0 then fw = 200 end
    if fh <= 0 then fh = 200 end

    local cx = sx * sScale / fScale
    local cy = (st * sScale / fScale) + fh * 0.5 + 10
    local sw = ((UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1280) * uScale / fScale
    local sh = ((UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 720) * uScale / fScale
    local pad = 12
    local minX, maxX = fw * 0.5 + pad, sw - fw * 0.5 - pad
    local minY, maxY = fh * 0.5 + pad, sh - fh * 0.5 - pad
    if maxX >= minX then cx = math.max(minX, math.min(maxX, cx)) end
    if maxY >= minY then cy = math.max(minY, math.min(maxY, cy)) end

    local prev = self.attachedFlyoutButton[flyout]
    if prev and prev ~= button then self:RestoreFlyoutButton(prev) end

    if not self.savedFlyoutPoints[button] then
        local pts = {}
        local n = (button.GetNumPoints and button:GetNumPoints()) or 0
        local origParent = flyout.prevButtonParent
        local fallback = false
        for i = 1, n do
            local a, rel, b, x, y = button:GetPoint(i)
            if not a then return end
            local useParent = (rel == nil) or (origParent ~= nil and rel == origParent)
            if not useParent then
                local okProt, _, explicit = pcall(function()
                    if rel.IsProtected then return rel:IsProtected() end
                end)
                if not okProt or not explicit then
                    fallback = true
                    break
                end
            end
            pts[#pts + 1] = { a, useParent and nil or rel, b or a, x or 0, y or 0, useParent }
        end
        if fallback then
            local bx, by, px, py
            if button.GetCenter then bx, by = button:GetCenter() end
            if origParent and origParent.GetCenter then px, py = origParent:GetCenter() end
            if not (bx and by and px and py) then return end
            local bScale = (button.GetEffectiveScale and button:GetEffectiveScale()) or 1
            local pScale = (origParent.GetEffectiveScale and origParent:GetEffectiveScale()) or 1
            if bScale <= 0 then bScale = 1 end
            pts = { { "CENTER", nil, "CENTER", bx - (px * pScale / bScale), by - (py * pScale / bScale), true } }
        end
        if #pts == 0 then return end
        self.savedFlyoutPoints[button] = pts
    end

    local header = self.header
    local ok = pcall(function()
        header:SetFrameRef("flyout", flyout)
        header:SetFrameRef("flybutton", button)
        header:SetAttribute("flyx", cx)
        header:SetAttribute("flyy", cy)
        header:Execute(PLACE_FLYOUT)
    end)
    if ok then
        self.attachedFlyoutButton[flyout] = button
        self.pendingFlyoutRestore[button] = nil
    else
        self.savedFlyoutPoints[button] = nil
    end
end

function Input:RestoreFlyoutButton(button)
    local pts = self.savedFlyoutPoints and self.savedFlyoutPoints[button]
    if not pts then return end
    if InCombatLockdown() or not self.header then
        self.pendingFlyoutRestore[button] = true
        return
    end
    local header = self.header
    pcall(function()
        header:SetFrameRef("flybutton", button)
        header:SetAttribute("flyptcount", #pts)
        for i, p in ipairs(pts) do
            header:SetAttribute("flypt" .. i .. "a", p[1])
            header:SetAttribute("flypt" .. i .. "parent", p[6] or false)
            if not p[6] then header:SetFrameRef("flypt" .. i .. "r", p[2]) end
            header:SetAttribute("flypt" .. i .. "b", p[3])
            header:SetAttribute("flypt" .. i .. "x", p[4])
            header:SetAttribute("flypt" .. i .. "y", p[5])
        end
        header:Execute(RESTORE_FLYOUT_BUTTON)
    end)
    self.savedFlyoutPoints[button] = nil
    self.pendingFlyoutRestore[button] = nil
end

function Input:RestorePendingFlyoutButtons()
    if InCombatLockdown() or not self.pendingFlyoutRestore then return end
    local pending = {}
    for button in pairs(self.pendingFlyoutRestore) do pending[#pending + 1] = button end
    for _, button in ipairs(pending) do self:RestoreFlyoutButton(button) end
end

function Input:ObserveBlockers(bars, unit)
    local function Add(frame)
        -- Never hide our hitboxes when Blizzard's SpellFlyout opens (e.g. from the SpellBook),
        -- otherwise spells inside an open SpellBook flyout cannot be dragged onto the action bar.
        if not frame or frame == SpellFlyout then return end
        self:HookFlyoutPosition(frame)
        if self.blockers[frame] then return end
        local ok, protected = pcall(function() return frame:IsProtected() end)
        if not ok or not protected then return end
        local ok = pcall(SecureHandlerWrapScript, frame, "OnShow", self.header, "control:Hide()")
        if not ok then return end
        pcall(SecureHandlerWrapScript, frame, "OnHide", self.header, RESUME)
        self.blockers[frame] = true
        local header = self.header
        local count = (header:GetAttribute("blockercount") or 0) + 1
        header:SetAttribute("blockercount", count)
        SetRef(header, "blocker" .. count, frame)
    end
    Add(GamepadActionBarEditFrame)
    Add(EditModeManagerFrame)
    for _, frame in pairs({ GamepadSpellFlyout, GamepadPetActionFlyout, GamepadPetSpellFlyout }) do Add(frame) end
    for _, bar in ipairs(bars) do
        for _, source in ipairs(bar.actionButtons) do Add(source.popup) end
    end
    Add(unit.LeftClassAction and unit.LeftClassAction.popup)
    Add(unit.RightClassAction and unit.RightClassAction.popup)
end

function Input:SetBindingMode(active)
    self.bindingMode = active and true or nil
    self.dirty = true
    if not active or InCombatLockdown() or not self.header then return end
    for _, button in pairs(self.buttons) do button:SetAttribute("cgppressed", nil) end
    pcall(function()
        self.header:SetAttribute("enabled", false)
        self.header:Execute(APPLY_BINDINGS)
    end)
end

-- Short slot label: mouse buttons and modifiers would otherwise spill over the neighbouring slots.
local MODIFIER_LABELS = { SHIFT = "S", CTRL = "C", ALT = "A", META = "M" }
local function ShortKeyLabel(key)
    local prefix, base = "", key
    while true do
        local modifier, rest = base:match("^(%u+)%-(.+)$")
        if not modifier or not MODIFIER_LABELS[modifier] then break end
        prefix, base = prefix .. MODIFIER_LABELS[modifier] .. "-", rest
    end
    local button = base:match("^BUTTON(%d+)$")
    if button then return prefix .. "Mouse" .. button end
    if base == "MOUSEWHEELUP" then return prefix .. "Wheel+" end
    if base == "MOUSEWHEELDOWN" then return prefix .. "Wheel-" end
    return GetBindingText(key, 1)
end

-- Collect the keyboard keys of every visible slot's classic bar position.
-- The secure header applies them only while the click layer is enabled.
function Input:UpdateBindings()
    local header, count = self.header, 0
    self.labelShown = {}
    -- The pad's eight come first: BindingsLost watches the first key, and the game puts its own back on them.
    self.padBound = self:PadWanted()
    if self.padBound then
        for native, button in ipairs(self.padButtons) do
            local key = Addon.ButtonBindings:Key(native) or Addon.ButtonBindings.DEFAULT[native]
            if key and IsBindingForGamePad(key) then
                count = count + 1
                header:SetAttribute("key" .. count, key)
                header:SetAttribute("button" .. count, button:GetName())
            end
        end
    end
    for i, button in pairs(self.buttons) do
        local slot = Addon.Display.slots[i]
        slot.Key:SetText("")
        self.labelShown[i] = slot:IsShown()
        if slot:IsShown() then
            local label
            pcall(function()
                local action = slot.bindingAction
                if not action then return end
                local context = C_KeyBindings.GetBindingContextForAction(action)
                for _, key in ipairs({ GetBindingKey(action, nil, context) }) do
                    if not IsBindingForGamePad(key) then
                        count = count + 1
                        header:SetAttribute("key" .. count, key)
                        header:SetAttribute("button" .. count, button:GetName())
                        label = label or ShortKeyLabel(key)
                    end
                end
            end)
            slot.Key:SetText(label or "")
        end
    end
    header:SetAttribute("bindingcount", count)
    self.dirty, self.bindingsPending = false, true
    self.labelRevision = Addon.Layout.revision
end

-- True when the first key this layer should own is no longer bound to its hitbox.
-- Checked at most once a second; another addon owning the same key retries at that pace only.
function Input:BindingsLost()
    local now = GetTime()
    if self.bindingCheck and now - self.bindingCheck < 1 then return false end
    self.bindingCheck = now
    local header = self.header
    if (header:GetAttribute("bindingcount") or 0) == 0 then return false end
    local key, button = header:GetAttribute("key1"), header:GetAttribute("button1")
    if not key or not button then return false end
    local ok, action = pcall(GetBindingAction, key, true)
    return ok and action ~= "CLICK " .. button .. ":Keybind"
end

-- True when a slot appeared or disappeared since the labels were collected.
function Input:SlotsChanged()
    if not self.labelShown then return true end
    for i in pairs(self.buttons) do
        if self.labelShown[i] ~= Addon.Display.slots[i]:IsShown() then return true end
    end
    return false
end

function Input:Refresh(wanted, native, unit, bars)
    if self.disabled then self:RestoreAfterError(); return false end
    if InCombatLockdown() then return self:IsEnabled() end
    self:RestorePendingFlyoutButtons()
    if not self.header then
        if not wanted then return false end
        self:Create(native, unit, bars)
    end
    local header = self.header
    if not self.pagesSet then self:SetKeyboardPages()
    else self:SyncKeyboardFlyouts() end
    if not wanted then
        self:HideKbdFlyout()
        if header:IsShown() then Addon:Trace("Input off") end
        self:SyncNativeMouse(true)
        header:SetAttribute("enabled", false)
        header:Hide()
        self.state = "off"
        return false
    end
    -- Labels follow the visible slots even while Settings or a flyout pauses
    -- the click layer, e.g. right after switching between 8 and 12 slots.
    local padKeyboard = Addon.db.padKeyboard == true
    if header:GetAttribute("padkeyboard") ~= padKeyboard then header:SetAttribute("padkeyboard", padKeyboard) end
    local attackStart = Addon.db.attackStart == true
    if header:GetAttribute("attackstart") ~= attackStart then header:SetAttribute("attackstart", attackStart) end
    if self.padRevision ~= Addon.Layout.revision then
        -- The order within a row is a setting ("crossFirst"), so the places are told again with the geometry.
        for group = 1, 4 do
            for native = 1, 8 do
                header:SetAttribute("padslot" .. group .. "-" .. native, Input.PadSlot(group, native))
            end
        end
        self.padRevision = Addon.Layout.revision
    end
    if self:PadWanted() ~= (self.padBound == true) then self.dirty = true end
    local bindingsDirty = self.dirty
    if bindingsDirty or self.labelRevision ~= Addon.Layout.revision or self:SlotsChanged() then
        self:UpdateBindings()
    end
    if self.bindingMode then
        -- Keep the slot hitboxes shown so they can be hovered, but drop the
        -- temporary key overrides so the pressed key reaches the binder.
        header:SetAttribute("enabled", false)
        header:Execute(APPLY_BINDINGS)
        self.state = "binding"
        return false
    end
    local geometryChanged = self.layoutRevision ~= Addon.Layout.revision
    if bindingsDirty or geometryChanged then self:ObserveBlockers(bars, unit) end
    if self:IsBlocked() then
        header:SetAttribute("enabled", false)
        header:Hide()
        self.state = "blocked"
        return false
    end
    if geometryChanged then
        header:SetAttribute("compact", Addon.Layout.compact)
        for i, button in pairs(self.buttons) do
            local slot = Addon.Display.slots[i]
            if not Addon.Layout:Place(button, slot) then
                header:SetAttribute("enabled", false)
                header:Hide()
                self.state = "blocked"
                return false
            end
            local _, index = SlotAction(i)
            if index then button:SetAttribute("index", index) end
            button:SetShown(slot:IsShown())
        end
        self.layoutRevision = Addon.Layout.revision
    end
    if self.layoutRevision == Addon.Layout.revision then
        for i, button in pairs(self.buttons) do
            local slot = Addon.Display.slots[i]
            if slot then
                local shown = slot:IsShown()
                if button:IsShown() ~= shown then button:SetShown(shown) end
                if not shown then slot.Key:SetText("") end
            end
        end
    end
    if not header:GetAttribute("enabled") then header:SetAttribute("enabled", true) end
    if not header:IsShown() then Addon:Trace("Input on"); header:Show()
    elseif self.bindingsPending then header:Execute(APPLY_BINDINGS)
    elseif self:BindingsLost() then
        -- The client dropped the override bindings while the layer stayed shown (e.g. after the Settings
        -- panel closed); applying them again restores the keyboard without a UI reload.
        Addon:Trace("Input:BindingsLost")
        self.rebound = (self.rebound or 0) + 1
        header:Execute(APPLY_BINDINGS)
    end
    self.bindingsPending = nil
    self:SyncNativeMouse(false)
    if self.disabled then return false end
    self:RefreshTooltip()
    self.state = "on"
    return true
end
