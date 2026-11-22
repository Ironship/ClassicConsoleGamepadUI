local _, Addon = ...
-- The eight buttons of the gamepad action bars (the D-pad and the face buttons X, Y, B, A) are fixed by the game: slot 1-8 of
-- every bar is the binding GAMEPADACTIONBUTTON1-8 (Blizzard_GamepadActionBars/Bindings.xml), and the game hides these bindings
-- from its key bindings list. This lets the player move the eight keys among the slots: "X first", "D-pad last", any order.
-- Only the eight keys the game gives them are used, so a key can never be taken from another action: choosing a key that
-- another slot holds swaps the two. The change is made with SetBinding in the binding context the game itself uses and
-- saved like any key binding; the bars draw the glyph of the key a slot really has (Display.lua).
local Buttons = { keyCache = {} }
Addon.ButtonBindings = Buttons

local COMMAND = "GAMEPADACTIONBUTTON"
local COUNT = 8

-- What the game gives the eight slots: D-pad left, up, right, down; then X (left), Y (top), B (right), A (bottom).
Buttons.DEFAULT = { "PADDLEFT", "PADDUP", "PADDRIGHT", "PADDDOWN", "PAD3", "PAD4", "PAD2", "PAD1" }
Buttons.COUNT = COUNT

local function Command(slot)
    return COMMAND .. slot
end

local function Context(slot)
    if C_KeyBindings and C_KeyBindings.GetBindingContextForAction then
        local ok, context = pcall(C_KeyBindings.GetBindingContextForAction, Command(slot))
        if ok then return context end
    end
end

function Buttons:Invalidate()
    wipe(self.keyCache)
end

-- The key a slot has now (its first binding), or nil. Cached until bindings change.
function Buttons:Key(slot)
    if type(GetBindingKey) ~= "function" then return nil end
    local cached = self.keyCache[slot]
    if cached ~= nil then return cached ~= false and cached or nil end
    local ok, key = pcall(GetBindingKey, Command(slot), nil, Context(slot))
    local value = ok and type(key) == "string" and key ~= "" and key or false
    self.keyCache[slot] = value
    return value ~= false and value or nil
end

-- The glyph key of a slot when it is not the game's own, or nil (the game's own glyph is then drawn as before).
function Buttons:CustomKey(slot)
    local key = self:Key(slot)
    if key and key ~= self.DEFAULT[slot] then return key end
end

-- True when any slot has a key other than the game's.
function Buttons:IsCustom()
    for slot = 1, COUNT do
        if self:CustomKey(slot) then return true end
    end
    return false
end

local function Save()
    if SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
end

-- The slot that has the key, or nil.
function Buttons:Holder(key)
    for slot = 1, COUNT do
        if self:Key(slot) == key then return slot end
    end
end

-- Give a slot a key from the eight; the slot that had that key gets the slot's old key. Outside combat only.
function Buttons:Assign(slot, key, done)
    if InCombatLockdown() then return false, "combat" end
    local valid
    for _, own in ipairs(self.DEFAULT) do if own == key then valid = true end end
    if not valid then return false, "key" end
    local old, other = self:Key(slot), self:Holder(key)
    if other == slot then return true end
    local context = Context(slot)
    if old then SetBinding(old, nil, context) end
    SetBinding(key, nil, context)
    local ok = SetBinding(key, Command(slot), context)
    if other and old then SetBinding(old, Command(other), context) end
    Save()
    self:Invalidate()
    -- the game may take a moment to answer: what the key has later decides, and the change is taken back when it did not hold
    local function verify()
        self:Invalidate()
        local now = self:Key(slot)
        if ok and now == key then
            if done then done(true) end
            return
        end
        if old then SetBinding(old, Command(slot), context) end
        if other then SetBinding(key, Command(other), context) end
        Save()
        self:Invalidate()
        if done then
            done(false, "failed", string.format("SetBinding=%s context=%s now=%s", tostring(ok), tostring(context), tostring(now)))
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.4, verify) else verify() end
    return true, "pending"
end

-- The next key in the order of the eight (D-pad left, up, right, down, X, Y, B, A), or the previous one.
-- A line for the chat about what Step did (the player cannot see a binding change on its own).
function Buttons:Report(slot, ok, why, detail)
    local name = self:Name(self.DEFAULT[slot])
    if ok then
        Addon:Print(string.format(Addon.L.buttonsMoved, name, self:Name(self:Key(slot))))
    elseif why == "combat" then
        Addon:Print(Addon.L.buttonsCombat)
    else
        Addon:Print(string.format(Addon.L.buttonsFailed, name, tostring(why) .. (detail and (" (" .. detail .. ")") or "")))
    end
end

function Buttons:Step(slot, direction, done)
    local current = self:Key(slot)
    local index = 0
    for i, key in ipairs(self.DEFAULT) do if key == current then index = i end end
    if index == 0 then index = slot end
    local nextKey = self.DEFAULT[(index - 1 + direction) % COUNT + 1]
    return self:Assign(slot, nextKey, done)
end

-- /cgp bindtest: what the game does with SetBinding on these bindings, step by step, for a report (slot 7, B, borrows slot 8's key A
-- for half a second and gives it back).
function Buttons:Diagnose()
    if InCombatLockdown() then Addon:Print(Addon.L.buttonsCombat); return end
    local function say(text, ...) Addon:Print("bindtest: " .. string.format(text, ...)) end
    local context = Context(7)
    local active = C_KeyBindings and C_KeyBindings.IsBindingContextActive and select(2, pcall(C_KeyBindings.IsBindingContextActive, context))
    say("context=%s active=%s gamepadMode=%s", tostring(context), tostring(active), tostring(Addon:IsGamepadMode()))
    local function dump(tag)
        self:Invalidate()
        local function action(key, withContext)
            local ok, value = pcall(GetBindingAction, key, nil, withContext and context or nil)
            return ok and tostring(value) or "error"
        end
        say("%s: slot7=%s slot8=%s | action(PAD1)=%s action(PAD2)=%s | no context: slot7=%s", tag, tostring(self:Key(7)), tostring(self:Key(8)),
            action("PAD1", true), action("PAD2", true), tostring((GetBindingKey(Command(7)))))
    end
    dump("before")
    local first = SetBinding("PAD1", nil, context)
    local second = SetBinding("PAD1", Command(7), context)
    say("SetBinding(PAD1, nil)=%s SetBinding(PAD1, slot7)=%s", tostring(first), tostring(second))
    dump("right after")
    C_Timer.After(0.5, function()
        dump("after 0.5 s")
        SetBinding("PAD1", nil, context)
        SetBinding("PAD1", Command(8), context)
        dump("given back")
        Save()
    end)
end

-- Every slot back to the game's key.
function Buttons:Reset()
    if InCombatLockdown() then return false, "combat" end
    for slot = 1, COUNT do
        local key = self:Key(slot)
        if key then SetBinding(key, nil, Context(slot)) end
    end
    for slot = 1, COUNT do
        SetBinding(self.DEFAULT[slot], nil, Context(slot))
    end
    for slot = 1, COUNT do
        SetBinding(self.DEFAULT[slot], Command(slot), Context(slot))
    end
    Save()
    self:Invalidate()
    return true
end

-- /cgp padtest: can an override binding of ours take a pad button away from the game's own forced binding? For a minute:
--   X, LT+X, RT+X, LT+RT+X  click a test button that only prints what arrived (no action is used);
--   Y                        presses the keyboard bar's slot 2 (ACTIONBUTTON2), the real thing.
-- A second /cgp padtest ends it early. Outside combat only (override bindings are protected in combat).
function Buttons:PadTest()
    local function say(text, ...) Addon:Print("padtest: " .. string.format(text, ...)) end
    if InCombatLockdown() then Addon:Print(Addon.L.buttonsCombat); return end
    if not self.testOwner then
        self.testOwner = CreateFrame("Frame", "ClassicConsoleGamepadUIPadTestOwner", UIParent)
        local button = CreateFrame("Button", "ClassicConsoleGamepadUIPadTestButton", UIParent)
        button:RegisterForClicks("AnyDown", "AnyUp")
        button:SetScript("OnClick", function(_, which, down)
            if down then say("ARRIVED: %s", tostring(which)) end
        end)
        self.testOwner:SetScript("OnEvent", function(owner)
            if self.testEnding then
                self.testEnding = nil
                ClearOverrideBindings(owner)
                say("ended (after combat)")
            end
        end)
        self.testOwner:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
    local owner = self.testOwner
    local function stop()
        if not self.testing then return end
        self.testing = nil
        if InCombatLockdown() then self.testEnding = true; return end
        ClearOverrideBindings(owner)
        say("ended: the pad is as before")
    end
    if self.testing then stop(); return end
    self.testing = true
    local name = "ClassicConsoleGamepadUIPadTestButton"
    SetOverrideBindingClick(owner, true, "PAD3", name, "X")
    SetOverrideBindingClick(owner, true, "SHIFT-PAD3", name, "LT+X")
    SetOverrideBindingClick(owner, true, "CTRL-PAD3", name, "RT+X")
    SetOverrideBindingClick(owner, true, "CTRL-SHIFT-PAD3", name, "LT+RT+X")
    SetOverrideBinding(owner, true, "PAD4", "ACTIONBUTTON2")
    local function action(key)
        local ok, value = pcall(GetBindingAction, key, true)
        return ok and tostring(value) or "error"
    end
    say("gamepadMode=%s | PAD3 -> %s | SHIFT-PAD3 -> %s | PAD4 -> %s", tostring(Addon:IsGamepadMode()), action("PAD3"),
        action("SHIFT-PAD3"), action("PAD4"))
    say("for 60 s: press X, LT+X, RT+X, LT+RT+X (each should print ARRIVED), then Y (should use keyboard slot 2)")
    C_Timer.After(60, stop)
end

-- The words for a key in the language in use ("X", "D-pad left"); Locales: padKey<KEY>.
function Buttons:Name(key)
    if not key then return Addon.L.padKeyNone end
    local name = Addon.L["padKey" .. key]
    if name == "padKey" .. key then return key end
    return name
end
