local _, Addon = ...
-- Diagnostics for the wheels (/cgp wheels diag | sticks | focus | pet | cd).
-- Split out of Wheels.lua so runtime wheel code stays focused and WatchFocus only hooks on demand.
local Wheels = Addon.Wheels
if not Wheels then return end

local function Readable(value)
    return not issecretvalue or not issecretvalue(value)
end

local function UsableOf(ok, isUsable, lacking)
    if ok and isUsable ~= nil and Readable(isUsable) and Readable(lacking) then return isUsable == true, lacking == true end
    return true, false
end

-- /cgp wheels sticks: for six seconds a listener (it never takes anything) counts what the game sends for each stick: the names,
-- how many events and the largest push, and says how the game's own list of sticks is named. Push both sticks about while it runs.
function Wheels:ProbeSticks()
    if self.probing then return end
    self.probing = true
    local seen = {}
    local frame = CreateFrame("Frame")
    frame:SetSize(1, 1)
    frame:SetPoint("CENTER")
    if frame.SetPropagateKeyboardInput and not InCombatLockdown() then pcall(frame.SetPropagateKeyboardInput, frame, true) end
    frame:SetScript("OnGamePadStick", function(_, stick, x, y)
        local entry = seen[tostring(stick)]
        if not entry then entry = { n = 0, best = 0, x = 0, y = 0 }; seen[tostring(stick)] = entry end
        entry.n = entry.n + 1
        local len = math.sqrt((x or 0) * (x or 0) + (y or 0) * (y or 0))
        if len > entry.best then entry.best, entry.x, entry.y = len, x or 0, y or 0 end
        return true
    end)
    local ok = frame.EnableGamePadStick and pcall(frame.EnableGamePadStick, frame, true)
    Addon:Print(ok and "wheels sticks: listening for 6 seconds, push both sticks about (nothing is taken)" or "wheels sticks: the game does not allow a stick listener here")
    C_Timer.After(6, function()
        if frame.EnableGamePadStick then pcall(frame.EnableGamePadStick, frame, false) end
        frame:SetScript("OnGamePadStick", nil)
        local any = false
        for name, entry in pairs(seen) do
            any = true
            Addon:Print(string.format("wheels sticks: event name %q: %d events, largest push %.2f (x %.2f, y %.2f)", name, entry.n, entry.best, entry.x, entry.y))
        end
        if not any then Addon:Print("wheels sticks: no stick event arrived") end
        local okState, state = pcall(C_GamePad.GetDeviceMappedState)
        if okState and type(state) == "table" then
            for index = 1, tonumber(state.stickCount) or 0 do
                local okName, name = pcall(C_GamePad.StickIndexToConfigName, index - 1)
                Addon:Print(string.format("wheels sticks: list entry %d is %q", index, tostring(okName and name)))
            end
        end
        self.probing = nil
    end)
end

-- What the game's window focus did since watching started, for finding out who focuses the interface.
-- Post-hooks only (they leave the game's code secure); opt-in via /cgp debug or /cgp wheels focus.
function Wheels:WatchFocus()
    if self.focusWatched then return end
    local mode = GamepadMode
    local manager = type(mode) == "table" and mode.FrameControlsManager or nil
    if type(manager) ~= "table" or type(hooksecurefunc) ~= "function" then return end
    self.focusWatched = true
    local log, started = {}, GetTime()
    self.focusLog = log
    if Addon.db then Addon.db.wheelFocusLog = log end
    local function Add(what, frame)
        if #log >= 30 then return end
        local name
        if frame ~= nil then
            local ok, value = pcall(function() return frame.GetName and frame:GetName() end)
            name = ok and value or tostring(frame)
        end
        log[#log + 1] = { at = string.format("%.1f", GetTime() - started), what = what, window = name, focused = tostring(manager.isUIFocused),
            stack = debugstack and debugstack(3, 8, 0) or nil }
    end
    pcall(hooksecurefunc, manager, "FrameShown", function(_, frame) Add("FrameShown", frame) end)
    pcall(hooksecurefunc, manager, "FrameHidden", function(_, frame) Add("FrameHidden", frame) end)
    pcall(hooksecurefunc, manager, "SetUIFocusState", function(_, on) Add("SetUIFocusState " .. tostring(on)) end)
end

function Wheels:PrintFocus()
    local manager = type(GamepadMode) == "table" and GamepadMode.FrameControlsManager or nil
    Addon:Print(string.format("wheels focus: interface focused now = %s, windows listed = %s", tostring(type(manager) == "table" and manager.isUIFocused),
        tostring(type(manager) == "table" and type(manager.shownFrames) == "table" and #manager.shownFrames)))
    if not self.focusWatched then
        self:WatchFocus()
        Addon:Print("wheels focus: focus logging started now (reproduce the issue, then run /cgp wheels focus again)")
        return
    end
    local log = self.focusLog
    if not log or #log == 0 then Addon:Print("wheels focus: no focus call seen since logging started"); return end
    for _, entry in ipairs(log) do
        Addon:Print(string.format("wheels focus: +%ss %s %s (interface focused after: %s)", entry.at, entry.what, tostring(entry.window or ""), entry.focused))
    end
end

-- /cgp wheels pet: what the pet wheel sees (the pet bar, the entries, what the secure layer was told, the last release).
function Wheels:PetDiagnose()
    local COUNT, SLOTS = Wheels.COUNT, Wheels.SLOTS
    local say = function(...) Addon:Print(string.format(...)) end
    local db = Addon.db
    local dynamic = Addon.Dynamic
    say("pet wheel: dynamic wheels=%s, pet goes to wheel %s, wheel kinds: %s", tostring(db.wheelDynamic == true), tostring(db.wheelDynPet),
        (function()
            local kinds = {}
            for wheel = 1, COUNT do kinds[#kinds + 1] = wheel .. "=" .. tostring(dynamic and dynamic:CategoryOf(wheel) or "-") end
            return table.concat(kinds, " ")
        end)())
    say("pet wheel: PetHasActionBar=%s, UnitExists(pet)=%s, pet slots=%s", tostring(type(PetHasActionBar) == "function" and PetHasActionBar()),
        tostring(UnitExists and UnitExists("pet")), tostring(NUM_PET_ACTION_SLOTS))
    for index = 1, (type(NUM_PET_ACTION_SLOTS) == "number" and NUM_PET_ACTION_SLOTS or 10) do
        local ok, name, texture, isToken, isActive, _, _, spellID = pcall(GetPetActionInfo, index)
        if ok and name then
            say("  pet bar %d: %s token=%s active=%s spell=%s", index, tostring(name), tostring(isToken), tostring(isActive), tostring(spellID))
        end
    end
    local entries = dynamic and dynamic.PetEntries and dynamic.PetEntries() or {}
    say("pet wheel: %d entries", #entries)
    for slot, entry in ipairs(entries) do
        say("  entry %d: %s %s", slot, tostring(entry.kind), tostring(entry.name))
    end
    local layer = self.layer
    if not layer then say("pet wheel: the secure layer does not exist yet"); return end
    for wheel = 1, COUNT do
        if layer:GetAttribute("petmode" .. wheel) then
            local told = {}
            for slot = 1, SLOTS do
                local act, spell = layer:GetAttribute("petact" .. wheel .. "_" .. slot), layer:GetAttribute("petspell" .. wheel .. "_" .. slot)
                if act or spell then told[#told + 1] = slot .. "=" .. (act and ("pet:" .. act) or ("spell:" .. tostring(spell))) end
            end
            say("pet wheel: the secure layer knows wheel %d as the pet wheel: %s", wheel, #told > 0 and table.concat(told, " ") or "nothing in it")
            local mod = self.mods and (wheel <= 4 and self.mods[1] or self.mods[2])
            say("pet wheel: last release of its button: %s", tostring(mod and mod:GetAttribute("diag") or "none yet"))
        end
    end
    say("pet wheel: pet attributes are only written outside combat; the last release says 'pet: slot=.. act=..' when the pet branch ran")
end

-- /cgp wheels diag: what the secure code made of the last release, and whether the layer is bound.
function Wheels:Diagnose()
    local COUNT, SLOTS, GROUPS, CAMERA_CVARS = Wheels.COUNT, Wheels.SLOTS, Wheels.GROUPS, Wheels.CAMERA_CVARS
    local say = function(...) Addon:Print(string.format(...)) end
    if not self.layer then say("wheels: not created yet (turn them on in the settings, Controls tab, in Gamepad Mode)"); return end
    say("wheels: layer shown=%s enabled=%s", tostring(self.layer:IsShown()), tostring(self.layer:GetAttribute("enabled")))
    for g, group in ipairs(GROUPS) do
        local ok, action = pcall(GetBindingAction, group.modifier, true)
        say("%s (%s) -> %s | last release in the secure code: %s", group.letter, group.modifier, tostring(ok and action),
            tostring(self.mods[g]:GetAttribute("diag") or "none yet (hold it, press a button, push a stick, let go)"))
    end
    local manager = type(GamepadMode) == "table" and GamepadMode.FrameControlsManager or nil
    say("the game's window focus: interface focused=%s, windows listed=%s, the small wheels joined=%s",
        tostring(type(manager) == "table" and manager.isUIFocused), tostring(type(manager) == "table" and type(manager.shownFrames) == "table" and #manager.shownFrames),
        tostring(self.joined))
    if type(manager) == "table" and type(manager.shownFrames) == "table" then
        for index, frame in ipairs(manager.shownFrames) do
            local okName, name = pcall(function() return frame.GetName and frame:GetName() end)
            local okType, kind = pcall(function() return frame.GetObjectType and frame:GetObjectType() end)
            local okShown, shown = pcall(function() return frame.IsShown and frame:IsShown() end)
            say("  listed window %d: %s (%s), shown=%s%s", index, tostring(okName and name or "no name"), tostring(okType and kind), tostring(okShown and shown),
                manager.focusedFrame == frame and ", has the focus" or "")
        end
    end
    local pad = Addon.Input and Addon.Input.PadFree
    say("the pad is free for the wheels: %s (the wheels are off while the game's interface bindings are active)", tostring(pad and pad() or "unknown"))
    local yaw, pitch = GetCVar and GetCVar(CAMERA_CVARS[1]), GetCVar and GetCVar(CAMERA_CVARS[2])
    local db = Addon.db
    say("parts that reach into the pad, camera or focus: R3/L3 combos=%s (they take the stick clicks), stick stopping=%s, window-list entry=%s, toggle mode=%s, dynamic wheels=%s, numbers=%s",
        tostring(db.wheelCombos == true), self:BlockMode(), tostring(db.wheelsDockFocus == true), tostring(db.wheelToggle == true),
        tostring(db.wheelDynamic == true), tostring(db.wheelNumbers ~= false))
    for _, key in ipairs({ "PADLSTICK", "PADRSTICK" }) do
        local okAction, action = pcall(GetBindingAction, key)
        local okOverride, override = pcall(GetBindingAction, key, true)
        say("the game's action on %s: %s%s", key, tostring(okAction and action ~= "" and action or "none"),
            (okOverride and override ~= "" and override ~= action) and (" (overridden now by: " .. tostring(override) .. ")") or "")
    end
    say("while a wheel button is held: stopping method = %s, choosing with %s | stick listener=%s holding=%s camera held=%s (speeds now yaw=%s pitch=%s, saved=%s)",
        self:BlockMode(), self:CameraOnly() and "the camera stick only" or "both sticks",
        tostring(self.sticksOn), tostring(self.holding), tostring(self.cameraHeld), tostring(yaw), tostring(pitch),
        Addon.db.wheelSavedCamera and "yes" or "no")
    say("sticks: movement=%s camera=%s | pushed now: %s", tostring(self.stickMove), tostring(self.stickCamera),
        string.format("%.2f %.2f %.2f", self:Stick()))
    for wheel = 1, COUNT do
        local filled = 0
        for slot = 1, SLOTS do if self:Get(wheel, slot) then filled = filled + 1 end end
        say("%s = action bar %d (action slots %d-%d): %d of %d slots filled, own key: %s", Wheels.Label(wheel), wheel + 3,
            Wheels.ActionOf(wheel, 1), Wheels.ActionOf(wheel, SLOTS), filled, SLOTS, tostring(self:KeyText(wheel)))
    end
end

-- /cgp wheels cd: what the game says about the cooldown and the usability of what is on the five wheels (every slot that has a running
-- cooldown, cannot be used, or holds an item; the rest are counted), and what the slots on the screen made of it.
function Wheels:CooldownDiagnose()
    local COUNT, SLOTS = Wheels.COUNT, Wheels.SLOTS
    local say = function(...) Addon:Print(string.format(...)) end
    local function Show(value)
        if value == nil then return "nil" end
        if not Readable(value) then return "secret" end
        return tostring(value)
    end
    local bar, spell = C_ActionBar, C_Spell
    local secrets = C_Secrets
    local function Ask(name, ...)
        if type(secrets) ~= "table" or type(secrets[name]) ~= "function" then return "unknown" end
        local ok, answer = pcall(secrets[name], ...)
        return ok and Show(answer) or "error"
    end
    say("wheels cd: GetActionCooldown=%s GetActionCooldownDuration=%s IsUsableAction=%s | C_Spell.GetSpellCooldown=%s GetSpellCooldownDuration=%s IsSpellUsable=%s | issecretvalue=%s | secret restrictions in this client: %s, cooldowns hidden now: %s | last error: %s",
        tostring(bar and bar.GetActionCooldown ~= nil), tostring(bar and bar.GetActionCooldownDuration ~= nil), tostring(bar and bar.IsUsableAction ~= nil),
        tostring(spell and spell.GetSpellCooldown ~= nil), tostring(spell and spell.GetSpellCooldownDuration ~= nil), tostring(spell and spell.IsSpellUsable ~= nil),
        tostring(issecretvalue ~= nil), Ask("HasSecretRestrictions"), Ask("ShouldCooldownsBeSecret"), tostring(self.stateError or "none"))
    local filled, quiet = 0, 0
    for wheel = 1, COUNT do
        for slot = 1, SLOTS do
            local action = self:Get(wheel, slot)
            if action then
                filled = filled + 1
                local okInfo, info = pcall(bar.GetActionCooldown, action)
                local usable, lacking = UsableOf(pcall(bar.IsUsableAction, action))
                local okKind, kind, id = pcall(GetActionInfo, action)
                local active = okInfo and type(info) == "table" and info.isActive and true or false
                if active or not usable or (okKind and kind == "item") then
                    if okInfo and type(info) == "table" then
                        say("  wheel %d slot %d (action %d, %s %s): active=%s onGCD=%s start=%s duration=%s rate=%s secret=%s | usable=%s noMana=%s", wheel, slot, action,
                            Show(okKind and kind or nil), Show(okKind and id or nil), Show(info.isActive), Show(info.isOnGCD), Show(info.startTime),
                            Show(info.duration), Show(info.modRate), Ask("ShouldActionCooldownBeSecret", action), tostring(usable), tostring(lacking))
                    else
                        say("  wheel %d slot %d (action %d, %s %s): GetActionCooldown gave %s | usable=%s noMana=%s", wheel, slot, action,
                            Show(okKind and kind or nil), Show(okKind and id or nil), Show(info), tostring(usable), tostring(lacking))
                    end
                else
                    quiet = quiet + 1
                end
            end
        end
    end
    say("wheels cd: %d slots filled, %d without a cooldown and usable (not listed)", filled, quiet)
    local hud = self.hud
    if hud and hud:IsShown() and self.open then
        local running, grey = 0, 0
        for _, frame in ipairs(hud.slots) do
            if frame.Cooldown and frame.Cooldown:IsShown() then running = running + 1 end
            if frame.cdLong then grey = grey + 1 end
        end
        say("wheels cd: the wheel on the screen (wheel %s): %d slots with a cooldown frame showing, %d grey", tostring(self.open), running, grey)
    else
        say("wheels cd: no wheel is on the screen; type /cgp wheels first (a wheel stays up while the wheels are filled), then this again, to see what its slots show")
    end
end
