local ADDON_NAME, Addon = ...
-- Wheels: hold R3 and press a D-pad direction, or hold L3 and press X, to open that button's wheel of twelve slots, push a stick
-- toward a slot and let go of the button to use it (five wheels).
--
-- A wheel is an action bar: wheel 1 to 5 are the action bars 4 to 8 (Right, Left, Multi-Bar 5, 6 and 7), the twelve buttons of a
-- bar are the twelve slots. So nothing of what is on the wheels is stored by this addon: it stays on those buttons when the
-- gamepad mode is off, the keyboard bars show it, and a spell, item, macro, mount or whatever else goes onto a slot with the
-- game's own PlaceAction, like onto any bar button. The small wheels beside the spellbook and the wheel in fill mode
-- (Wheels:Preview) are only places to drop things on.
--
-- Secure side (works in combat): a click layer owns R3 and L3 and, while one is held, its buttons with priority override
-- bindings of its own, the kind /cgp padtest showed the game gives way to. Pressing such a button only shows the wheel (an
-- attribute the insecure side reads). Letting go reads the stick in the secure snippet (GetGamePadState is part of the
-- restricted environment), works out the slot and makes the button a click of that action slot, so the cast is the button's own
-- secure click. The insecure side only draws: the wheel, the selection and the places to drop on.
--
-- Besides R3 and L3 a wheel opens with any key of the player's own (a keyboard key, with Shift/Ctrl/Alt, or an extra mouse
-- button): a controller that sends keyboard keys, such as a Steam Controller set up in Steam Input, can open a wheel from any
-- of its buttons. The key is the game's own binding "CLICK <wheel button>:LeftButton" (Wheels:SetKey), so the game keeps it,
-- and the wheel button does what it does for R3 + D-pad: hold the key, push a stick toward a slot, let go.
local Wheels = {}
Addon.Wheels = Wheels

local COUNT, SLOTS = 5, 12
local STEP = 360 / SLOTS
-- Two groups of buttons: R3 + the D-pad (wheels 1-4) and L3 + X (wheel 5; the game's key for X is PAD3). {group, button}
local GROUPS = {
    { modifier = "PADRSTICK", letter = "R3", keys = { "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT" } },
    { modifier = "PADLSTICK", letter = "L3", keys = { "PAD3" } },
}
local WHEEL_PLACE = { { 1, 1 }, { 1, 2 }, { 1, 3 }, { 1, 4 }, { 2, 1 } }
local function GroupOf(wheel) return WHEEL_PLACE[wheel][1] end
local FACE_NAME = "ClassicConsoleGamepadUIWheelFace"

-- The key held with a wheel's button, the button's key and the label "R3 + D-pad up".
local function WheelKeys(wheel)
    local place = WHEEL_PLACE[wheel]
    local group = GROUPS[place[1]]
    return group.modifier, group.keys[place[2]], group.letter
end

function Wheels.Label(wheel)
    local _, key, letter = WheelKeys(wheel)
    local name = Addon.L["padKey" .. key]
    return letter .. " + " .. (name == "padKey" .. key and key or name)
end
-- How far a stick must be pushed to choose a slot (0.35 catches short-throw sticks and gentle releases while staying above deadzone).
local THRESHOLD = 0.35
local RADIUS = 128
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local WHITE = "Interface\\Buttons\\WHITE8x8"
-- One wedge of 30 degrees (Textures/Wedge30.tga, made for the wheel of 360 points), turned for each slot. A texture file that is
-- new to the game is only found after a restart of the game, not after /reload.
local WEDGE_FILE = "Interface\\AddOns\\" .. tostring(ADDON_NAME) .. "\\Textures\\Wedge30.tga"

local function Text(key) return Addon.L[key] end

-- ---------------------------------------------------------------------------------------------
-- What the wheels hold
-- ---------------------------------------------------------------------------------------------

-- The action bar pages of the bars 4 to 8 (the game's own names for them; the numbers of the retail client when a name is missing).
local PAGE_NAMES = { "RIGHT_ACTIONBAR_PAGE", "LEFT_ACTIONBAR_PAGE", "MULTIBAR_5_ACTIONBAR_PAGE", "MULTIBAR_6_ACTIONBAR_PAGE", "MULTIBAR_7_ACTIONBAR_PAGE" }
local PAGE_FALLBACK = { 3, 4, 13, 14, 15 }
local PER_BAR = 12

-- The action slot just before the first button of a wheel's bar.
function Wheels.Base(wheel)
    local page = _G[PAGE_NAMES[wheel]]
    if type(page) ~= "number" then page = PAGE_FALLBACK[wheel] end
    return (page - 1) * PER_BAR
end

function Wheels.ActionOf(wheel, slot) return Wheels.Base(wheel) + slot end

-- Whether an action slot holds something (the answer may be unreadable in a fight: then it counts as empty).
local function Filled(action)
    local ok, has = pcall(C_ActionBar.HasAction, action)
    if not ok then return false end
    local readable, truth = pcall(function() return has == true end)
    return readable and truth or false
end

-- The action slot of a wheel's slot when it holds something (nil: empty).
function Wheels:Get(wheel, slot)
    local action = Wheels.ActionOf(wheel, slot)
    if Filled(action) then return action end
end

-- The name, icon and flyout flag of what an action slot holds.
local function Describe(action)
    if type(action) ~= "number" then return end
    local name, icon, isFlyout
    pcall(function()
        local kind, id = GetActionInfo(action)
        if kind == "spell" then
            local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
            name = type(info) == "table" and info.name or (GetSpellInfo and (GetSpellInfo(id)))
        elseif kind == "item" then
            name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
        elseif kind == "flyout" then
            isFlyout = true
            local spells, single, active, flyName
            if Addon.FlyoutSpells then spells, single, active, flyName = Addon.FlyoutSpells(id) end
            if single then
                local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(single)
                name = type(info) == "table" and info.name or (spells and spells[1] and spells[1].name) or flyName
            else
                name = flyName
            end
            local showID = single or active
            if showID and C_Spell and C_Spell.GetSpellTexture then
                icon = C_Spell.GetSpellTexture(showID)
            end
            if not icon and C_Flyout and C_Flyout.GetFlyoutTexture then
                icon = C_Flyout.GetFlyoutTexture(id)
            end
        end
        name = name or GetActionText(action) or (kind and tostring(kind))
    end)
    if not icon then
        local ok, tex = pcall(GetActionTexture, action)
        icon = ok and tex or 134400
    end
    return name or tostring(action), icon or 134400, isFlyout == true
end

-- DoesItDiePlus (UsefulPlatesAndTooltips) draws the damage of spells and the healing of consumables on action buttons. Its public
-- SpellDamageInfo API lets another bar ask for the same numbers on its own buttons: a slot here is registered with `.action`, the
-- action slot it shows, and the numbers follow it (the big wheel's slots change their slot when another wheel is shown).
local function NumbersApi()
    local root = UsefulPlatesAndTooltips_API
    if type(root) ~= "table" or type(root.Get) ~= "function" then return nil end
    local ok, api = pcall(root.Get, "SpellDamageInfo")
    if ok and type(api) == "table" and type(api.RegisterButton) == "function" then return api end
end

-- Registers (on) or releases (not on, or the setting is off) the numbers of a list of slot frames.
function Wheels:SetNumbers(frames, on)
    local api = NumbersApi()
    if not api or not frames then return end
    local want = on and Addon.db.wheelNumbers ~= false
    for _, frame in ipairs(frames) do
        if want then pcall(api.RegisterButton, frame) else pcall(api.UnregisterButton, frame) end
    end
end

-- Something changed on the bars (a drop here, a drag on a bar, the spellbook, the pet bar): the slots on the screen are drawn
-- again, and cached flyout / pet attributes on the secure layer are refreshed outside combat.
local watcher = CreateFrame("Frame")
for _, event in ipairs({ "ACTIONBAR_SLOT_CHANGED", "SPELLS_CHANGED", "SPELL_FLYOUT_UPDATE", "PLAYER_REGEN_ENABLED",
    "PET_BAR_UPDATE", "UNIT_PET", "PET_UI_UPDATE", "PET_BAR_UPDATE_USABLE" }) do
    pcall(watcher.RegisterEvent, watcher, event)
end
watcher:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_PET" and unit ~= "player" then return end
    Wheels.stale = true
    if event == "ACTIONBAR_SLOT_CHANGED" or event == "SPELLS_CHANGED" or event == "SPELL_FLYOUT_UPDATE" or event == "PLAYER_REGEN_ENABLED" then
        Wheels.flyoutsDirty = true
    end
    if event == "PET_BAR_UPDATE" or event == "UNIT_PET" or event == "PET_UI_UPDATE" or event == "SPELLS_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
        Wheels.petDirty = true
    end
    if not InCombatLockdown() then
        if Wheels.flyoutsDirty then Wheels:SyncFlyouts() end
        if Wheels.petDirty then Wheels:SyncPet() end
    end
end)

function Wheels:IsPetWheel(wheel)
    return wheel ~= nil and Addon.Dynamic ~= nil and Addon.Dynamic:CategoryOf(wheel) == "pet"
end

-- Live entry for one slot of a pet dynamic wheel. Reads the secure layer's exact petact/petspell mapping when present so HUD and
-- combat execution always stay in lockstep, even if a pet is summoned or dismissed mid-combat.
function Wheels:PetSlot(wheel, slot)
    if not self:IsPetWheel(wheel) then return nil end
    local dynamic = Addon.Dynamic
    if not dynamic then return nil end
    local layer = self.layer
    if layer and layer:GetAttribute("petmode" .. wheel) then
        local petAct = layer:GetAttribute("petact" .. wheel .. "_" .. slot)
        if petAct then return dynamic.PetActionEntry and dynamic.PetActionEntry(petAct) or nil end
        local petSpell = layer:GetAttribute("petspell" .. wheel .. "_" .. slot)
        if petSpell then
            if type(PetHasActionBar) == "function" and not PetHasActionBar() then return nil end
            local spellID = layer:GetAttribute("petspellid" .. wheel .. "_" .. slot)
            local icon
            if spellID and C_Spell and C_Spell.GetSpellTexture then
                local ok, tex = pcall(C_Spell.GetSpellTexture, spellID)
                if ok then icon = tex end
            end
            return { kind = "spell", id = spellID, name = petSpell, icon = icon, usable = true }
        end
        return nil
    end
    local entries = dynamic.PetEntries and dynamic.PetEntries()
    return entries and entries[slot] or nil
end

-- Populates petmode / petact / petspell attributes on the secure wheel layer so pet commands and extra pet spells execute in
-- combat with zero taint via SecureActionButtonTemplate's native "pet" (CastPetAction) and "spell" (CastSpellByName) types.
function Wheels:SyncPet()
    local layer = self.layer
    if not layer or InCombatLockdown() then
        self.petDirty = true
        return
    end
    local dynamic = Addon.Dynamic
    local petEntries
    local petSlots = (type(NUM_PET_ACTION_SLOTS) == "number" and NUM_PET_ACTION_SLOTS) or 10
    for wheel = 1, COUNT do
        local isPet = self:IsPetWheel(wheel)
        local wasPet = layer:GetAttribute("petmode" .. wheel) == true
        if isPet then
            if not wasPet then layer:SetAttribute("petmode" .. wheel, true) end
            if petEntries == nil then
                petEntries = dynamic and dynamic.PetEntries and dynamic.PetEntries() or {}
            end
            local hasEntries = #petEntries > 0
            for slot = 1, SLOTS do
                local key = wheel .. "_" .. slot
                local act, spell, spellID
                if hasEntries then
                    local entry = petEntries[slot]
                    if entry and entry.kind == "pet" then
                        act = entry.index
                    elseif entry and entry.kind == "spell" then
                        spell, spellID = entry.name, entry.id
                    end
                elseif slot <= petSlots then
                    -- Pre-seed 1..10 when no pet is out so summoning a pet mid-combat still works immediately.
                    act = slot
                end
                if layer:GetAttribute("petact" .. key) ~= act then layer:SetAttribute("petact" .. key, act) end
                if layer:GetAttribute("petspell" .. key) ~= spell then layer:SetAttribute("petspell" .. key, spell) end
                if layer:GetAttribute("petspellid" .. key) ~= spellID then layer:SetAttribute("petspellid" .. key, spellID) end
            end
        elseif wasPet then
            layer:SetAttribute("petmode" .. wheel, nil)
            for slot = 1, SLOTS do
                local key = wheel .. "_" .. slot
                if layer:GetAttribute("petact" .. key) ~= nil then layer:SetAttribute("petact" .. key, nil) end
                if layer:GetAttribute("petspell" .. key) ~= nil then layer:SetAttribute("petspell" .. key, nil) end
                if layer:GetAttribute("petspellid" .. key) ~= nil then layer:SetAttribute("petspellid" .. key, nil) end
            end
        end
    end
    self.petDirty = nil
end

-- Populates flyspell / flycount / fly* attributes on the secure wheel layer so flyouts work in and out of combat without taint.
function Wheels:SyncFlyouts()
    local layer = self.layer
    if not layer or InCombatLockdown() or not Addon.FlyoutSpells then return end
    for wheel = 1, COUNT do
        for slot = 1, SLOTS do
            local key = wheel .. "_" .. slot
            local action = Wheels.ActionOf(wheel, slot)
            local single, spells
            local ok, kind, id = pcall(GetActionInfo, action)
            if ok and kind == "flyout" and id then
                spells, single = Addon.FlyoutSpells(id)
            end
            local prevCount = layer:GetAttribute("flycount" .. key) or 0
            if single then
                if layer:GetAttribute("flyspell" .. key) ~= single then layer:SetAttribute("flyspell" .. key, single) end
                if prevCount > 0 then
                    layer:SetAttribute("flycount" .. key, nil)
                    for k = 1, prevCount do layer:SetAttribute("fly" .. key .. "_" .. k, nil) end
                end
            elseif spells and #spells >= 2 then
                local count = math.min(#spells, SLOTS)
                if layer:GetAttribute("flyspell" .. key) ~= nil then layer:SetAttribute("flyspell" .. key, nil) end
                if prevCount ~= count then layer:SetAttribute("flycount" .. key, count) end
                for k = 1, count do
                    local spellID = spells[k].id
                    if layer:GetAttribute("fly" .. key .. "_" .. k) ~= spellID then
                        layer:SetAttribute("fly" .. key .. "_" .. k, spellID)
                    end
                end
                for k = count + 1, prevCount do layer:SetAttribute("fly" .. key .. "_" .. k, nil) end
            else
                if layer:GetAttribute("flyspell" .. key) ~= nil then layer:SetAttribute("flyspell" .. key, nil) end
                if prevCount > 0 then
                    layer:SetAttribute("flycount" .. key, nil)
                    for k = 1, prevCount do layer:SetAttribute("fly" .. key .. "_" .. k, nil) end
                end
            end
        end
    end
    self.flyoutsDirty = nil
end

-- /cgp wheels trace: says in the chat what the wheel sees of the mouse while it is filled.
function Wheels:Trace(format, ...)
    if Addon.traceWheels then Addon:Print("wheels: " .. string.format(format, ...)) end
end

-- A spell, item, macro or whatever the cursor carries put on a slot, the way an action bar button takes it; what was there
-- goes onto the cursor.
function Wheels:Place(wheel, slot)
    if InCombatLockdown() then Addon:Print(Text("wheelCombat")); return end
    if self:IsPetWheel(wheel) then return end
    self.lastPlace = GetTime()
    local action = Wheels.ActionOf(wheel, slot)
    self:Trace("place on wheel %s slot %s (action %s), the cursor holds %s", tostring(wheel), tostring(slot), tostring(action), tostring((GetCursorInfo())))
    if not GetCursorInfo() then return end
    PlaceAction(action)
    self:SyncFlyouts()
    self:Redraw()
    Addon:QueueRefresh(true)
end

-- Takes what a slot holds off: onto the cursor (a drag out), or away (a right click).
function Wheels:Remove(wheel, slot, toCursor)
    if InCombatLockdown() then Addon:Print(Text("wheelCombat")); return end
    if self:IsPetWheel(wheel) then return end
    local action = Wheels.ActionOf(wheel, slot)
    if not Filled(action) then return end
    PickupAction(action)
    if not toCursor then ClearCursor() end
    self:SyncFlyouts()
    self:Redraw()
    Addon:QueueRefresh(true)
end

-- Empties the five bars (the wheels), outside combat.
function Wheels:ClearAll()
    if InCombatLockdown() then Addon:Print(Text("wheelCombat")); return end
    ClearCursor()
    for wheel = 1, COUNT do
        for slot = 1, SLOTS do
            local action = Wheels.ActionOf(wheel, slot)
            if Filled(action) then PickupAction(action); ClearCursor() end
        end
    end
    self:SyncFlyouts()
    self:Redraw()
    Addon:QueueRefresh(true)
end

-- ---------------------------------------------------------------------------------------------
-- Which slot a stick points at (the secure snippet below does the same sum)
-- ---------------------------------------------------------------------------------------------

-- Slot 1 is at the top and the rest follow clockwise, 30 degrees apart; x is right and y is up.
function Wheels.SlotOf(len, x, y)
    if not len or len <= THRESHOLD then return nil end
    local theta = math.deg((math.atan2 or math.atan)(x, y))
    if theta < 0 then theta = theta + 360 end
    return math.floor((theta + STEP / 2) / STEP) % SLOTS + 1
end

-- Setting "wheelCameraOnly" (on by default, like the game's own wheels): only the camera stick chooses a slot and is taken from
-- the game while a wheel button is held; the movement stick keeps walking. Off: both sticks choose and both are taken.
function Wheels:CameraOnly()
    return Addon.db.wheelCameraOnly ~= false
end

-- Which entries of the game's stick list are the movement and the camera stick.
function Wheels:FindSticks()
    local ok, state = pcall(C_GamePad.GetDeviceMappedState)
    local count = ok and type(state) == "table" and tonumber(state.stickCount) or 0
    local move, camera
    for index = 1, count do
        local named, name = pcall(C_GamePad.StickIndexToConfigName, index - 1)
        if named then
            if name == "Movement" then move = index elseif name == "Camera" then camera = index end
        end
    end
    self.stickMove, self.stickCamera = move or 1, camera or 2
end

-- The stick pushed furthest: its length and direction.
function Wheels:Stick()
    local ok, state = pcall(C_GamePad.GetDeviceMappedState)
    local best, bx, by = 0, 0, 0
    local camOnly = self:CameraOnly()
    if ok and type(state) == "table" and type(state.sticks) == "table" then
        for _, index in ipairs(camOnly and { self.stickCamera or 2 } or { self.stickMove or 1, self.stickCamera or 2 }) do
            local stick = state.sticks[index]
            if type(stick) == "table" and type(stick.len) == "number" and stick.len > best then
                best, bx, by = stick.len, stick.x or 0, stick.y or 0
            end
        end
    end
    local events = self.holding and self.stickEvents
    if events then
        for _, name in ipairs(camOnly and { "Camera" } or { "Movement", "Camera" }) do
            local event = events[name]
            if event then
                local len = math.sqrt(event.x * event.x + event.y * event.y)
                if len > best then best, bx, by = len, event.x, event.y end
            end
        end
    end
    return best, bx, by
end

-- ---------------------------------------------------------------------------------------------
-- Secure click layer
-- ---------------------------------------------------------------------------------------------

-- R3 or L3 down: its four buttons go to the wheel buttons below. Up: they go back to the game, unless a wheel button is still
-- held; then that button's own release does it after it has used the slot.
local MODIFIER_CLICK = [[
    local layer = self:GetFrameRef("layer")
    if down then
        if not layer:GetAttribute("enabled") then return end
        for i = 1, self:GetAttribute("faces") do
            self:SetBindingClick(true, self:GetAttribute("face" .. i), self:GetAttribute("button" .. i), "LeftButton")
        end
        self:SetAttribute("closeafter", nil)
    elseif self:GetAttribute("facedown") then
        self:SetAttribute("closeafter", true)
    else
        for i = 1, self:GetAttribute("faces") do self:ClearBinding(self:GetAttribute("face" .. i)) end
    end
]]

-- A face button, pressed: the wheel opens (the attribute is read by the drawing code). Released: the stick is read, the
-- slot worked out and the button becomes the click of that action slot. Pushed too little: nothing happens.
-- The sum is the one of Wheels.SlotOf. The state is a copy of the game's mapped state; sticks are listed by index.
-- "page" (on the layer) is the wheel that is shown: LB and RB change it while the wheel is open, and the slot is a button of
-- the shown wheel's bar (attributes base1..base5 on the layer), whichever wheel's button opened it.
-- The toggle mode (attribute "toggle" on the layer): the press that opens the wheel leaves it open when it is let go
-- ("openwheel" says which); the next press of a wheel button, or A (bound to the open wheel's button while it is open), uses the
-- slot and closes the wheel on the key going down; B (the cancel button) closes it without using anything.
local FACE_CLICK = [[
    self:SetAttribute("type", nil)
    local wheel = self:GetAttribute("wheel")
    local layer = control:GetFrameRef("layer")
    if not layer:GetAttribute("enabled") then
        control:SetAttribute("facedown", nil)
        self:SetAttribute("cgppressed", nil)
        return false
    end
    local toggle = layer:GetAttribute("toggle")
    local openwheel = layer:GetAttribute("openwheel")
    local activeFlyout = layer:GetAttribute("flyout")
    if down then
        if not activeFlyout and not (toggle and openwheel) then
            control:SetAttribute("facedown", wheel)
            self:SetAttribute("pickslot", nil)
            layer:SetAttribute("flyout", nil)
            layer:SetAttribute("flyoutid", nil)
            layer:SetAttribute("page", wheel)
            if toggle then layer:SetAttribute("openwheel", wheel) end
            layer:RunAttribute("openbind", wheel)
            self:SetAttribute("cgppressed", true)
            return false
        end
    elseif toggle or activeFlyout then
        -- Let go in toggle mode or while a flyout sub-wheel is open: the wheel stays open.
        control:SetAttribute("facedown", nil)
        if control:GetAttribute("closeafter") then
            control:SetAttribute("closeafter", nil)
            for i = 1, control:GetAttribute("faces") do control:ClearBinding(control:GetAttribute("face" .. i)) end
        end
        return false
    elseif not control:GetAttribute("facedown") then
        -- A stray release after a down-press already closed a flyout or cancelled.
        return false
    end
    -- Using the slot: on the button going up (held), or on the second press (toggle / flyout sub-wheel).
    local openface = (openwheel and layer:GetFrameRef("face" .. openwheel)) or self
    -- The slot the drawn wheel showed as chosen (set from outside combat while the stick moves).
    local pick = openface:GetAttribute("pickslot")
    control:SetAttribute("facedown", nil)
    local page = layer:GetAttribute("page") or wheel
    local x, y, best = 0, 0, 0
    local state = GetGamePadState()
    if state and state.sticks then
        for k = 1, 2 do
            -- With "camonly" the movement stick (the first) is not a chooser: walking goes on while a slot is chosen.
            local index = (k == 2 or not control:GetAttribute("camonly")) and control:GetAttribute(k == 1 and "stickmove" or "stickcamera")
            local stick = index and state.sticks[index]
            if stick and stick.len and stick.len > best then best, x, y = stick.len, stick.x, stick.y end
        end
    end
    local slot
    if best > 0.35 then
        local theta = deg(atan2(x, y))
        if theta < 0 then theta = theta + 360 end
        slot = floor((theta + 15) / 30) % 12 + 1
    end
    -- What the wheel shows as chosen is what the player sees, so it comes first; the stick read here is for when nothing was
    -- written (in combat, or the wheel never drew).
    if pick then slot = pick end
    if control:GetAttribute("closeafter") then
        control:SetAttribute("closeafter", nil)
        for i = 1, control:GetAttribute("faces") do control:ClearBinding(control:GetAttribute("face" .. i)) end
    end
    control:SetAttribute("diag", format("%s %.2f %.2f %.2f slot=%s wheel=%s page=%s pick=%s fly=%s", state and "state" or "nostate", best, x, y, tostring(slot), tostring(wheel), tostring(page), tostring(pick), tostring(activeFlyout)))
    if activeFlyout then
        local spell = slot and layer:GetAttribute("fly" .. activeFlyout .. "_" .. slot)
        layer:SetAttribute("flyout", nil)
        layer:SetAttribute("flyoutid", nil)
        layer:SetAttribute("openwheel", nil)
        layer:SetAttribute("page", nil)
        layer:RunAttribute("closebind")
        openface:SetAttribute("cgppressed", nil)
        self:SetAttribute("cgppressed", nil)
        if not spell then return false end
        self:SetAttribute("type", "spell")
        self:SetAttribute("spell", spell)
        self:SetAttribute("useOnKeyDown", down and true or false)
        return "LeftButton"
    end
    if layer:GetAttribute("petmode" .. page) then
        local petAct = slot and layer:GetAttribute("petact" .. page .. "_" .. slot)
        local petSpell = slot and not petAct and layer:GetAttribute("petspell" .. page .. "_" .. slot)
        layer:SetAttribute("openwheel", nil)
        layer:SetAttribute("page", nil)
        layer:RunAttribute("closebind")
        openface:SetAttribute("cgppressed", nil)
        self:SetAttribute("cgppressed", nil)
        if petAct then
            self:SetAttribute("type", "pet")
            self:SetAttribute("action", petAct)
            self:SetAttribute("useOnKeyDown", down and true or false)
            return "LeftButton"
        elseif petSpell then
            self:SetAttribute("type", "spell")
            self:SetAttribute("spell", petSpell)
            self:SetAttribute("useOnKeyDown", down and true or false)
            return "LeftButton"
        end
        return false
    end
    local base = layer:GetAttribute("base" .. page)
    local action = slot and base and (base + slot)
    local kind, id
    if action then kind, id = GetActionInfo(action) end
    if kind == "flyout" then
        local key = page .. "_" .. slot
        local single = layer:GetAttribute("flyspell" .. key)
        if single then
            layer:SetAttribute("openwheel", nil)
            layer:SetAttribute("page", nil)
            layer:RunAttribute("closebind")
            openface:SetAttribute("cgppressed", nil)
            self:SetAttribute("cgppressed", nil)
            self:SetAttribute("type", "spell")
            self:SetAttribute("spell", single)
            self:SetAttribute("useOnKeyDown", down and true or false)
            return "LeftButton"
        end
        local count = layer:GetAttribute("flycount" .. key)
        if count and count > 0 then
            -- Multi-spell flyout: open the flyout's known spells in this same wheel (works in combat with zero taint).
            local owner = openwheel or wheel
            local ownerFace = layer:GetFrameRef("face" .. owner) or openface
            layer:SetAttribute("flyout", key)
            layer:SetAttribute("flyoutid", id)
            layer:SetAttribute("openwheel", owner)
            layer:SetAttribute("page", page)
            ownerFace:SetAttribute("pickslot", nil)
            layer:RunAttribute("openbind", owner)
            ownerFace:SetAttribute("cgppressed", true)
            return false
        end
    end
    layer:SetAttribute("openwheel", nil)
    layer:SetAttribute("page", nil)
    layer:RunAttribute("closebind")
    openface:SetAttribute("cgppressed", nil)
    self:SetAttribute("cgppressed", nil)
    if not kind or kind == "flyout" then return false end
    self:SetAttribute("type", "action")
    self:SetAttribute("action", action)
    self:SetAttribute("useOnKeyDown", down and true or false)
    return "LeftButton"
]]

-- While a wheel is open (run on the layer, with the wheel as the argument): LB and RB page (except inside a flyout sub-wheel),
-- and in toggle mode or a flyout sub-wheel A uses the slot (a click on the open wheel's button) and B cancels.
local OPEN_BIND = [[
    local wheel = ...
    if self:GetAttribute("flyout") then
        self:ClearBinding("PADLSHOULDER")
        self:ClearBinding("PADRSHOULDER")
    else
        self:SetBindingClick(true, "PADLSHOULDER", self:GetAttribute("pageprev"), "LeftButton")
        self:SetBindingClick(true, "PADRSHOULDER", self:GetAttribute("pagenext"), "LeftButton")
    end
    if self:GetAttribute("toggle") or self:GetAttribute("flyout") then
        self:SetBindingClick(true, "PAD1", self:GetAttribute("facename" .. wheel), "LeftButton")
        self:SetBindingClick(true, "PAD2", self:GetAttribute("cancelname"), "LeftButton")
    end
]]
local CLOSE_BIND = [[
    self:ClearBinding("PADLSHOULDER")
    self:ClearBinding("PADRSHOULDER")
    self:ClearBinding("PAD1")
    self:ClearBinding("PAD2")
]]
-- Closes an open wheel without using anything (B in the toggle mode, the layer going away, the insecure side giving up on it).
local CLOSE_WHEEL = [[
    self:SetAttribute("flyout", nil)
    self:SetAttribute("flyoutid", nil)
    self:SetAttribute("openwheel", nil)
    self:SetAttribute("page", nil)
    self:RunAttribute("closebind")
    for w = 1, self:GetAttribute("pages") do
        local face = self:GetFrameRef("face" .. w)
        if face then face:SetAttribute("cgppressed", nil) end
    end
    for g = 1, 2 do
        local modifier = self:GetFrameRef("mod" .. g)
        if modifier then modifier:SetAttribute("facedown", nil) end
    end
]]
-- LB / RB while a wheel is open: the next or the previous wheel, round the ends like the game's own wheels do.
local PAGE_CLICK = [[
    if not down then return end
    local layer = self:GetFrameRef("layer")
    if layer:GetAttribute("flyout") then return end
    local page = layer:GetAttribute("page")
    if not page then return end
    page = page + self:GetAttribute("dir")
    local pages = layer:GetAttribute("pages")
    if page < 1 then page = pages elseif page > pages then page = 1 end
    layer:SetAttribute("page", page)
]]
local CANCEL_CLICK = [[
    if down then self:GetFrameRef("layer"):RunAttribute("closewheel") end
]]

-- The layer is shown while the wheels are wanted; showing it binds R3 and L3, hiding it frees every key.
local LAYER_SHOW = [[
    self:ClearBindings()
    if self:GetAttribute("enabled") and self:GetAttribute("combos") then
        for g = 1, 2 do
            self:SetBindingClick(true, self:GetAttribute("modkey" .. g), self:GetAttribute("modname" .. g), "LeftButton")
        end
    end
]]
local LAYER_HIDE = [[
    self:RunAttribute("closewheel")
    self:ClearBindings()
    for g = 1, 2 do
        local modifier = self:GetFrameRef("mod" .. g)
        modifier:ClearBindings()
        modifier:SetAttribute("facedown", nil)
        modifier:SetAttribute("closeafter", nil)
    end
]]

function Wheels:Create()
    if self.layer or InCombatLockdown() then return end
    self:NameBindings()
    self:CreateEater()
    local layer = CreateFrame("Frame", "ClassicConsoleGamepadUIWheels", UIParent, "SecureHandlerShowHideTemplate")
    layer:SetSize(1, 1)
    layer:SetPoint("CENTER")
    layer:Hide()
    self.layer, self.mods, self.faces = layer, {}, {}
    layer:SetAttribute("_onshow", LAYER_SHOW)
    layer:SetAttribute("_onhide", LAYER_HIDE)
    layer:SetAttribute("openbind", OPEN_BIND)
    layer:SetAttribute("closebind", CLOSE_BIND)
    layer:SetAttribute("closewheel", CLOSE_WHEEL)
    layer:SetAttribute("pages", COUNT)
    -- The page and flyout sub-wheel the secure code works out are drawn by the insecure side when they change.
    layer:HookScript("OnAttributeChanged", function(_, name, value)
        if name == "page" then self:SetPage(value)
        elseif name == "flyoutid" then self:SetFlyout(value) end
    end)
    local function Handler(name, snippet, dir)
        local button = CreateFrame("Button", name, layer, "SecureHandlerClickTemplate")
        button:SetSize(1, 1)
        button:SetPoint("CENTER")
        button:RegisterForClicks("AnyDown", "AnyUp")
        button:SetFrameRef("layer", layer)
        button:SetAttribute("_onclick", snippet)
        if dir then button:SetAttribute("dir", dir) end
        return button
    end
    layer:SetAttribute("pageprev", Handler("ClassicConsoleGamepadUIWheelPagePrev", PAGE_CLICK, -1):GetName())
    layer:SetAttribute("pagenext", Handler("ClassicConsoleGamepadUIWheelPageNext", PAGE_CLICK, 1):GetName())
    layer:SetAttribute("cancelname", Handler("ClassicConsoleGamepadUIWheelCancel", CANCEL_CLICK):GetName())
    self:FindSticks()
    local camOnly = self:CameraOnly()
    for g, group in ipairs(GROUPS) do
        local modifier = CreateFrame("Button", "ClassicConsoleGamepadUIWheelMod" .. g, layer, "SecureHandlerClickTemplate")
        modifier:SetSize(1, 1)
        modifier:SetPoint("CENTER")
        modifier:RegisterForClicks("AnyDown", "AnyUp")
        self.mods[g] = modifier
        layer:SetFrameRef("mod" .. g, modifier)
        modifier:SetFrameRef("layer", layer)
        layer:SetAttribute("modkey" .. g, group.modifier)
        layer:SetAttribute("modname" .. g, modifier:GetName())
        modifier:SetAttribute("_onclick", MODIFIER_CLICK)
        modifier:SetAttribute("faces", #group.keys)
        modifier:SetAttribute("stickmove", self.stickMove)
        modifier:SetAttribute("stickcamera", self.stickCamera)
        modifier:SetAttribute("camonly", camOnly)
    end
    for wheel = 1, COUNT do
        local g, n = WHEEL_PLACE[wheel][1], WHEEL_PLACE[wheel][2]
        local modifier = self.mods[g]
        local face = CreateFrame("Button", FACE_NAME .. wheel, layer, "SecureActionButtonTemplate")
        face:SetSize(1, 1)
        face:SetPoint("CENTER")
        face:SetAttribute("wheel", wheel)
        layer:SetFrameRef("face" .. wheel, face)
        layer:SetAttribute("facename" .. wheel, face:GetName())
        layer:SetAttribute("base" .. wheel, Wheels.Base(wheel))
        face:SetAttribute("checkselfcast", true)
        face:SetAttribute("checkfocuscast", true)
        face:SetAttribute("checkmouseovercast", true)
        face:RegisterForClicks("AnyDown", "AnyUp")
        SecureHandlerWrapScript(face, "OnClick", modifier, FACE_CLICK)
        SecureHandlerWrapScript(face, "OnHide", modifier, [[control:SetAttribute("facedown", nil); self:SetAttribute("cgppressed", nil)]])
        face:HookScript("PostClick", function(f, button, down)
            if not Addon.traceWheels then return end
            self:Trace("button of wheel %d %s %s: type=%s action=%s | %s", wheel, tostring(button), down and "down" or "up",
                tostring(f:GetAttribute("type")), tostring(f:GetAttribute("action")), tostring(modifier:GetAttribute("diag")))
        end)
        face:SetScript("OnAttributeChanged", function(_, name, value)
            if name == "cgppressed" then
                local held = value == true
                self:SetOpen(held and wheel or nil)
                -- While the button is held the sticks are the wheel's (Wheels:CreateEater): no camera, no walking.
                self.holding, self.holdingAt = held or nil, GetTime()
                self:SetSticks(held)
            end
        end)
        modifier:SetAttribute("face" .. n, GROUPS[g].keys[n])
        modifier:SetAttribute("button" .. n, face:GetName())
        self.faces[wheel] = face
    end
    self:SyncFlyouts()
    self:SyncPet()
end

-- True when the game took R3 or L3 back (checked at most once a second).
-- Gives up on a wheel the toggle mode left open (outside combat only; in combat B or the second press does it).
function Wheels:Cancel()
    if self.layer and not InCombatLockdown() then self.layer:Execute(CLOSE_WHEEL) end
end

function Wheels:BindingLost()
    if Addon.db.wheelCombos ~= true then return false end
    local now = GetTime()
    if self.bindingCheck and now - self.bindingCheck < 1 then return false end
    self.bindingCheck = now
    for g, group in ipairs(GROUPS) do
        local ok, action = pcall(GetBindingAction, group.modifier, true)
        if ok and action ~= "CLICK " .. self.mods[g]:GetName() .. ":LeftButton" then return true end
    end
    return false
end

-- The game moves the character ("Movement") and turns the camera ("Camera") with virtual sticks that fire each frame right after
-- their raw twins in fixed order: Left > Right > Gyro, then Movement > Camera > Look (a virtual twin fires only if its raw stick
-- fired that frame). For addon frames, propagation is controlled by SetPropagateKeyboardInput (not OnGamePadStick's return value),
-- and SetPropagateKeyboardInput cannot change in combat, whereas Show/Hide on plain frames can.
-- Therefore we use two plain frames created out of combat:
--   1. eater   (BACKGROUND, SetPropagateKeyboardInput(true))  — lets Movement pass through untouched so L3 walking keeps working.
--   2. blocker (TOOLTIP,    SetPropagateKeyboardInput(false)) — shown only for the exact virtual stick(s) to consume (Camera by
--      default), armed to wait until Movement has passed if Left also fired that frame, and hidden immediately after Camera is eaten.
local RAW_ORDER = { "Left", "Right", "Gyro" }
local VIRTUAL_STICK = { Left = "Movement", Right = "Camera", Gyro = "Look" }
local WANTED_CAMERA = { Right = true }
local WANTED_BOTH = { Left = true, Right = true }
local WALK_GRACE = 0.25    -- seconds after the movement stick was last pushed that still count as walking
local MAX_HOLD = 20

function Wheels:LowerBlocker()
    if self.stickPending then wipe(self.stickPending) end
    if self.blocker then self.blocker:Hide() end
end

function Wheels:OnStickFrameEnd()
    if self.stickSeen then wipe(self.stickSeen) end
    self.stickArmed = nil
    if self.blocker and self.blocker:IsShown() then
        self:LowerBlocker()
    end
end

function Wheels:RaiseBlocker(wanted, stick)
    self.stickPending[VIRTUAL_STICK[stick]] = true
    local waitFor
    for _, raw in ipairs(RAW_ORDER) do
        if raw == stick then break end
        if self.stickSeen[raw] and not wanted[raw] then
            waitFor = VIRTUAL_STICK[raw]
        end
    end
    if waitFor then
        self.stickArmed = waitFor
    elseif self.blocker then
        self.blocker:Show()
    end
end

function Wheels:OnStick(stick, x, y, len)
    x, y = x or 0, y or 0
    len = len or math.sqrt(x * x + y * y)
    local now = GetTime()
    if (stick == "Movement" or stick == "Left") and (x * x + y * y) > 0.01 then self.walkingAt = now end
    if self.holding then
        if stick == "Camera" or stick == "Right" then
            self.stickEvents.Camera = { x = x, y = y, t = now }
        elseif stick == "Movement" or stick == "Left" then
            self.stickEvents.Movement = { x = x, y = y, t = now }
        end
    end
    local virtual = VIRTUAL_STICK[stick]
    if not virtual then
        if stick == self.stickArmed then
            self.stickArmed = nil
            if self.blocker then self.blocker:Show() end
        end
        return
    end
    self.stickSeen[stick] = true
    if not self.holding or now - (self.holdingAt or 0) >= MAX_HOLD then return end
    local mode = self:BlockMode()
    if mode == "off" then return end
    if mode == "listener" and now - (self.walkingAt or -10) < WALK_GRACE then return end
    local wanted = mode == "both" and WANTED_BOTH or WANTED_CAMERA
    if not wanted[stick] then return end
    if len > 0 then
        self:RaiseBlocker(wanted, stick)
    end
end

function Wheels:OnBlockerStick(stick, x, y, len)
    if VIRTUAL_STICK[stick] then
        return self:OnStick(stick, x, y, len)
    end
    if self.holding and (stick == "Camera" or stick == "Movement") then
        self.stickEvents[stick] = { x = x or 0, y = y or 0, t = GetTime() }
    end
    self.stickPending[stick] = nil
    if not next(self.stickPending) and self.blocker then
        self.blocker:Hide()
    end
end

function Wheels:CreateEater()
    if self.eater then return end
    -- Keep the latest stick values from OnGamePadStick while holding (y is up, matching Blizzard's radial menu): if the game
    -- suppresses polled stick state for an eaten stick, Wheels:Stick still sees the steady held direction without expiring.
    self.stickEvents, self.stickSeen, self.stickPending, self.stickArmed = {}, {}, {}, nil
    local eater = CreateFrame("Frame", "ClassicConsoleGamepadUIWheelSticks", UIParent)
    eater:SetSize(1, 1)
    eater:SetPoint("CENTER")
    eater:SetFrameStrata("BACKGROUND")
    if eater.SetPropagateKeyboardInput and not InCombatLockdown() then pcall(eater.SetPropagateKeyboardInput, eater, true) end
    eater:RegisterEvent("PLAYER_LOGOUT")
    eater:SetScript("OnEvent", function() self:SuspendCamera(false) end)
    eater:SetScript("OnGamePadStick", function(_, stick, x, y, len)
        self:OnStick(stick, x, y, len)
    end)
    -- Setting OnGamePadStick auto-enables EnableGamePadStick(true) in the client engine; disable and hide immediately so the
    -- frame never swallows sticks on /reload before any wheel is opened. (OnEvent still fires while hidden.)
    if eater.EnableGamePadStick then pcall(eater.EnableGamePadStick, eater, false) end
    eater:Hide()
    local blocker = CreateFrame("Frame", "ClassicConsoleGamepadUIWheelStickBlocker", UIParent)
    blocker:SetSize(1, 1)
    blocker:SetPoint("CENTER")
    blocker:SetFrameStrata("TOOLTIP")
    if blocker.SetPropagateKeyboardInput and not InCombatLockdown() then pcall(blocker.SetPropagateKeyboardInput, blocker, false) end
    blocker:SetScript("OnGamePadStick", function(_, stick, x, y, len)
        self:OnBlockerStick(stick, x, y, len)
    end)
    if blocker.EnableGamePadStick then pcall(blocker.EnableGamePadStick, blocker, false) end
    blocker:Hide()
    self.sticksOn = false
    self.eater = eater
    self.blocker = blocker
end

-- The camera stick is stopped the plain way, with the game's own camera speeds of the pad: while a wheel button is held they are set to
-- 0 and the movement stick keeps walking (a stick listener, tried first, stopped the walking too: seen with L3 held). The speeds
-- the player had are kept in the saved variables while they are 0, so a crash or a logout never leaves the camera still.
local CAMERA_CVARS = { "GamePadCameraYawSpeed", "GamePadCameraPitchSpeed" }

function Wheels:SuspendCamera(on)
    local db = Addon.db
    if on then
        if self.cameraHeld or type(GetCVar) ~= "function" or type(SetCVar) ~= "function" then return end
        local saved, any = {}, false
        for _, name in ipairs(CAMERA_CVARS) do
            local ok, value = pcall(GetCVar, name)
            if ok and value ~= nil then saved[name] = tostring(value); any = true end
        end
        if not any then return end
        db.wheelSavedCamera = saved
        for name in pairs(saved) do pcall(SetCVar, name, "0") end
        self.cameraHeld = true
    elseif self.cameraHeld or db.wheelSavedCamera then
        local saved = db.wheelSavedCamera
        if type(saved) == "table" then
            for name, value in pairs(saved) do pcall(SetCVar, name, value) end
        end
        db.wheelSavedCamera = nil
        self.cameraHeld = nil
    end
end

-- Speeds left at 0 by a session that did not end properly are put back.
function Wheels:RestoreCamera()
    if not self.cameraHeld and Addon.db and Addon.db.wheelSavedCamera then self:SuspendCamera(false) end
end

-- How the camera stick is stopped while a wheel button is held (setting "wheelBlock"): "hard" (default) takes only the logical
-- "Camera" stick while held (same as Blizzard's InputAxisBinding.lua, leaving walking untouched), "listener" skips taking it while
-- walking, "both" takes both "Camera" and "Movement", "off" stops nothing.
function Wheels:BlockMode()
    local mode = Addon.db.wheelBlock
    if mode == "listener" or mode == "hard" or mode == "both" or mode == "off" then return mode end
    return "hard"
end

-- While a wheel button is held (on): the camera is stopped the chosen way. The stick listener and blocker are enabled only while
-- the button is held (at rest both stay hidden with EnableGamePadStick(false) so nothing intercepts sticks after /reload).
function Wheels:SetSticks(on)
    local mode = self:BlockMode()
    local eater, blocker = self.eater, self.blocker
    local listen = on and (mode == "listener" or mode == "hard" or mode == "both") and true or false
    if not eater or not eater.EnableGamePadStick then return end
    if (self.sticksOn or false) == listen and eater:IsShown() == listen then return end
    if listen then
        if self.stickSeen then wipe(self.stickSeen) end
        if self.stickPending then wipe(self.stickPending) end
        self.stickArmed = nil
        eater:Show()
        eater:SetScript("OnUpdate", function() self:OnStickFrameEnd() end)
        if blocker then
            blocker:Hide()
            if blocker.EnableGamePadStick then pcall(blocker.EnableGamePadStick, blocker, true) end
        end
        if pcall(eater.EnableGamePadStick, eater, true) then self.sticksOn = true end
    else
        if self.stickSeen then wipe(self.stickSeen) end
        self.stickArmed = nil
        self:LowerBlocker()
        if blocker and blocker.EnableGamePadStick then pcall(blocker.EnableGamePadStick, blocker, false) end
        eater:SetScript("OnUpdate", nil)
        if pcall(eater.EnableGamePadStick, eater, false) then self.sticksOn = false end
        eater:Hide()
    end
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

-- Called every refresh; everything that changes protected frames is left for outside combat.
function Wheels:Refresh(gamepad)
    if not self.cameraChecked then
        self.cameraChecked = true
        self:RestoreCamera()
        -- Earlier builds consumed raw physical sticks ("Right"/"Left") and then defaulted to "off". Now "hard" handles only
        -- logical "Camera" (matching Blizzard's InputAxisBinding.lua), leaving walking untouched; migrate once to "hard".
        if Addon.db.wheelBlockRev ~= 4 then
            Addon.db.wheelBlock, Addon.db.wheelBlockRev = "hard", 4
        end
        -- The R3 / L3 combos took the stick clicks of the player on every login (the pad's cursor clicks and the mouse-click
        -- bindings of many setups are those two buttons: seen as "L3 and R3 blocked"). Once, they become off; the player turns them
        -- on on purpose.
        if Addon.db.wheelCombosRev ~= 2 then
            Addon.db.wheelCombos, Addon.db.wheelCombosRev = false, 2
        end
        -- Earlier /cgp wheels safe also cleared wheelNumbers, wheelDynamic and wheelsDockFocus; restore them once.
        if Addon.db.wheelSafeRestoreRev ~= 1 then
            Addon.db.wheelSafeRestoreRev = 1
            if Addon.db.wheels == true then
                Addon.db.wheelNumbers = true
                Addon.db.wheelsDockFocus = true
                if (Addon.db.wheelDynFood or 0) > 0 or (Addon.db.wheelDynUse or 0) > 0 or (Addon.db.wheelDynProf or 0) > 0 or (Addon.db.wheelDynPet or 0) > 0 then
                    Addon.db.wheelDynamic = true
                    if Addon.Dynamic and Addon.Dynamic.Request then Addon.Dynamic:Request(0.2) end
                end
            end
        end
    end
    local dockOk, dockError = pcall(self.UpdateDock, self, gamepad)
    if not dockOk then Addon:Note("Wheels:UpdateDock", dockError) end
    if InCombatLockdown() then return end
    local want = gamepad and Addon.db.wheels == true and not Addon.nativeView
    if want and not self.layer then self:Create() end
    local layer = self.layer
    if not layer then return end
    if want then
        local pad = Addon.Input and Addon.Input.PadFree
        if (pad and not pad()) or (Addon.Input and Addon.Input.bindingMode) or self.previewing then
            want = false
        end
    end
    if not want then
        self:SetSticks(false)
        self.holding = nil
        if layer:GetAttribute("enabled") then layer:SetAttribute("enabled", false) end
        if layer:IsShown() then layer:Hide() end
        if not self.previewing then self:SetOpen(nil) end
        return
    end
    local now = GetTime()
    if not self.sticksAt or now - self.sticksAt > 2 then
        self.sticksAt = now
        self:FindSticks()
        for _, modifier in ipairs(self.mods) do
            if modifier:GetAttribute("stickmove") ~= self.stickMove then modifier:SetAttribute("stickmove", self.stickMove) end
            if modifier:GetAttribute("stickcamera") ~= self.stickCamera then modifier:SetAttribute("stickcamera", self.stickCamera) end
            if modifier:GetAttribute("camonly") ~= self:CameraOnly() then modifier:SetAttribute("camonly", self:CameraOnly()) end
        end
    end
    -- R3 and L3 are the layer's only when the player wants the combos (the keys of their own are the game's bindings).
    local combos = Addon.db.wheelCombos == true
    local combosChanged = layer:GetAttribute("combos") ~= combos
    if combosChanged then layer:SetAttribute("combos", combos) end
    local toggle = Addon.db.wheelToggle == true
    if layer:GetAttribute("toggle") ~= toggle then
        if layer:GetAttribute("openwheel") then layer:Execute(CLOSE_WHEEL) end
        layer:SetAttribute("toggle", toggle)
    end
    if not layer:GetAttribute("enabled") then layer:SetAttribute("enabled", true) end
    if self.flyoutsDirty then self:SyncFlyouts() end
    if self.petDirty then self:SyncPet() end
    if not layer:IsShown() then
        layer:Show()
    elseif combosChanged or self:BindingLost() then
        Addon:Trace("Wheels:BindingLost")
        layer:Execute(LAYER_SHOW)
    end
end

-- ---------------------------------------------------------------------------------------------
-- Keys of the player's own
-- ---------------------------------------------------------------------------------------------

local function Command(wheel) return "CLICK " .. FACE_NAME .. wheel .. ":LeftButton" end

-- The game shows a name for a binding it is asked about (the conflict line of /cgp, the binding lists of other addons).
function Wheels:NameBindings()
    for wheel = 1, COUNT do
        _G["BINDING_NAME_" .. Command(wheel)] = string.format(Text("wheelKeyName"), wheel, Wheels.Label(wheel))
    end
end

-- The key bound to a wheel (nil: none), as the game writes it ("SHIFT-F13").
function Wheels:KeyOf(wheel)
    local ok, key = pcall(GetBindingKey, Command(wheel))
    if ok and type(key) == "string" and key ~= "" then return key end
end

function Wheels:KeyText(wheel)
    local key = self:KeyOf(wheel)
    if not key then return Text("wheelKeyNone") end
    local ok, shown = pcall(GetBindingText, key, "KEY_")
    return ok and type(shown) == "string" and shown ~= "" and shown or key
end

-- Binds a key to open a wheel (nil: takes the key off). A key that did something else is taken from it, which is said.
-- Saved with the game's other bindings.
function Wheels:SetKey(wheel, chord)
    if InCombatLockdown() then Addon:Print(Text("wheelCombat")); return false end
    local command = Command(wheel)
    local old = { GetBindingKey(command) }
    for _, key in ipairs(old) do SetBinding(key) end
    if chord then
        local taken = GetBindingAction(chord)
        if not SetBinding(chord, command) then
            for _, key in ipairs(old) do SetBinding(key, command) end
            Addon:Print(Text("wheelKeyFail"))
            return false
        end
        if type(taken) == "string" and taken ~= "" and taken ~= command then
            local name = GetBindingName and GetBindingName(taken) or taken
            Addon:Print(string.format(Text("wheelKeyTaken"), tostring(name), wheel))
        end
        Addon:Print(string.format(Text("wheelKeyDone"), wheel, self:KeyText(wheel)))
    else
        Addon:Print(string.format(Text("wheelKeyCleared"), wheel))
    end
    SaveBindings(GetCurrentBindingSet())
    return true
end

-- A key (or an extra mouse button) pressed while a wheel waits for its key: bound, or Backspace takes the key off, Esc and a
-- click of the left or right button give up. Returns true when it was taken.
function Wheels:CaptureInput(key)
    local frame = self.capture
    if not frame or not frame:IsShown() then return false end
    local wheel, done = frame.wheel, frame.done
    if key == "ESCAPE" or key == "LeftButton" or key == "RightButton" then
        frame:Hide()
        return true
    end
    if key == "BACKSPACE" or key == "DELETE" then
        frame:Hide()
        self:SetKey(wheel, nil)
        if done then done() end
        return true
    end
    if type(IsKeyPressIgnoredForBinding) == "function" and IsKeyPressIgnoredForBinding(key) then return true end
    local chord = key
    if type(GetConvertedKeyOrButton) == "function" then chord = GetConvertedKeyOrButton(key) or key end
    if type(CreateKeyChordStringUsingMetaKeyState) == "function" then chord = CreateKeyChordStringUsingMetaKeyState(chord) or chord end
    frame:Hide()
    self:SetKey(wheel, chord)
    if done then done() end
    return true
end

-- Waits for the next key: a dark layer over the screen says which wheel it is for.
function Wheels:CaptureKey(wheel, done)
    if InCombatLockdown() then Addon:Print(Text("wheelCombat")); return end
    local frame = self.capture
    if not frame then
        frame = CreateFrame("Frame", "ClassicConsoleGamepadUIWheelKeyCatcher", UIParent)
        frame:SetAllPoints(UIParent)
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:EnableKeyboard(true)
        frame:EnableMouse(true)
        frame:Hide()
        local shade = frame:CreateTexture(nil, "BACKGROUND")
        shade:SetAllPoints()
        shade:SetColorTexture(0, 0, 0, 0.55)
        frame.Text = Addon.Fonts:String(frame, "OVERLAY", "HighlightLarge")
        frame.Text:SetPoint("CENTER", 0, 60)
        frame.Text:SetWidth(700)
        frame.Text:SetJustifyH("CENTER")
        frame:SetScript("OnKeyDown", function(f, key)
            local taken = self:CaptureInput(key)
            if f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(not taken) end
        end)
        frame:SetScript("OnMouseDown", function(_, button) self:CaptureInput(button) end)
        frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        frame:SetScript("OnEvent", function(f) f:Hide() end)
        self.capture = frame
    end
    frame.wheel, frame.done = wheel, done
    frame.Text:SetText(string.format(Text("wheelKeyCapture"), wheel, Wheels.Label(wheel)))
    frame:Show()
end

-- ---------------------------------------------------------------------------------------------
-- The wheel on the screen
-- ---------------------------------------------------------------------------------------------

local function Circle(parent, size, r, g, b, a, layer, sublevel)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
    texture:SetTexture(WHITE)
    texture:SetVertexColor(r, g, b, a)
    texture:SetSize(size, size)
    local mask = parent:CreateMaskTexture()
    mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(texture)
    texture:AddMaskTexture(mask)
    return texture
end

local function SlotOffset(slot, radius)
    local angle = math.rad((slot - 1) * STEP)
    radius = radius or RADIUS
    return radius * math.sin(angle), radius * math.cos(angle)
end

-- The wheel a slot frame belongs to: the small wheels beside the spellbook have their own, the big one shows the open wheel.
local function WheelOf(frame) return frame.wheel or Wheels.open or 1 end

-- One round slot: a gold ring, a dark disc and the icon in a circle.
local function CreateSlotFrame(parent, slot, size, radius)
    size = size or 52
    local frame = CreateFrame("Button", nil, parent)
    frame:SetSize(size, size)
    local x, y = SlotOffset(slot, radius)
    frame:SetPoint("CENTER", parent, "CENTER", x, y)
    frame.Ring = Circle(frame, size + 6, 0.48, 0.39, 0.25, 1, "BACKGROUND", 1)
    frame.Ring:SetPoint("CENTER")
    frame.Disc = Circle(frame, size, 0.08, 0.065, 0.05, 1, "BACKGROUND", 2)
    frame.Disc:SetPoint("CENTER")
    frame.Icon = frame:CreateTexture(nil, "ARTWORK")
    frame.Icon:SetSize(size - 6, size - 6)
    frame.Icon:SetPoint("CENTER")
    -- Icons have a dark border of their own; cut round, it would show as a ring at the edge. The outer part is cropped away.
    frame.Icon:SetTexCoord(0.09, 0.91, 0.09, 0.91)
    local mask = frame:CreateMaskTexture()
    mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(frame.Icon)
    frame.Icon:AddMaskTexture(mask)
    frame.FlyoutArrow = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    frame.FlyoutArrow:SetSize(size >= 40 and 15 or 10, size >= 40 and 6 or 4)
    frame.FlyoutArrow:SetPoint("TOP", frame, "TOP", 0, size >= 40 and 4 or 3)
    if frame.FlyoutArrow.SetAtlas then frame.FlyoutArrow:SetAtlas("UI-HUD-ActionBar-Flyout", false) end
    frame.FlyoutArrow:Hide()
    if size >= 40 then
        frame.Number = Addon.Fonts:String(frame, "OVERLAY", "HighlightSmall")
        frame.Number:SetPoint("BOTTOMRIGHT", 4, -2)
    end
    frame.slot = slot
    return frame
end

-- A slot takes drops like the button of an action bar: a dropped spell, item or macro is put on the slot and the old one goes
-- onto the cursor; dragging a slot out takes it off, a right click clears it. (The caller turns the mouse on.)
function Wheels:WireSlot(frame)
    local slot = frame.slot
    frame:RegisterForDrag("LeftButton")
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame:SetScript("OnReceiveDrag", function()
        self:Trace("slot %d of wheel %s got OnReceiveDrag", slot, tostring(WheelOf(frame)))
        self:Place(WheelOf(frame), slot)
    end)
    frame:SetScript("OnDragStart", function()
        self:Trace("slot %d of wheel %s got OnDragStart", slot, tostring(WheelOf(frame)))
        self:Remove(WheelOf(frame), slot, true)
    end)
    frame:SetScript("OnClick", function(_, button)
        local wheel = WheelOf(frame)
        self:Trace("slot %d of wheel %s got OnClick %s, the cursor holds %s", slot, tostring(wheel), tostring(button), tostring((GetCursorInfo())))
        if GetCursorInfo() then self:Place(wheel, slot)
        elseif button == "RightButton" then self:Remove(wheel, slot, false) end
    end)
    frame:SetScript("OnEnter", function(f)
        local wheel = WheelOf(frame)
        if self:IsPetWheel(wheel) then
            self:Tooltip(f, self:PetSlot(wheel, slot), true)
        else
            self:Tooltip(f, self:Get(wheel, slot))
        end
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- The game's pad navigation (SmartNavigation) walks over the buttons of a window with the D-pad and clicks the one it is on
    -- with A: this function is its click (true: handled). With something on the cursor it goes onto the slot, without it the
    -- slot's content is picked up (like a bar button). The right click (MouseUp with "RightButton") takes the content off.
    frame.OnSmartNavClick = function()
        if GetCursorInfo() then self:Place(WheelOf(frame), slot) else self:Remove(WheelOf(frame), slot, true) end
        return true
    end
    frame.MouseDown = function() end
    frame.MouseUp = function(_, button)
        if button == "RightButton" then self:Remove(WheelOf(frame), slot, false) end
    end
end

function Wheels:CreateHUD()
    if self.hud then return end
    local hud = CreateFrame("Frame", "ClassicConsoleGamepadUIWheel", UIParent)
    hud:SetSize(360, 360)
    hud:SetFrameStrata("HIGH")
    hud:EnableMouse(false)
    hud:Hide()
    local rim = Circle(hud, 366, 0.35, 0.29, 0.19, 0.95, "BACKGROUND", 0)
    rim:SetPoint("CENTER")
    local disc = Circle(hud, 360, 0.05, 0.04, 0.03, 0.82, "BACKGROUND", 1)
    disc:SetPoint("CENTER")
    local hubRim = Circle(hud, 142, 0.48, 0.39, 0.25, 0.8, "BACKGROUND", 2)
    hubRim:SetPoint("CENTER")
    local hub = Circle(hud, 136, 0.04, 0.032, 0.025, 0.9, "BACKGROUND", 3)
    hub:SetPoint("CENTER")
    hud.Name = Addon.Fonts:String(hud, "OVERLAY", "Normal")
    hud.Name:SetPoint("CENTER", 0, 12)
    hud.Name:SetWidth(124)
    hud.Hint = Addon.Fonts:String(hud, "OVERLAY", "HighlightSmall")
    hud.Hint:SetPoint("TOP", hud.Name, "BOTTOM", 0, -6)
    hud.Hint:SetWidth(124)
    -- The look of the game's wheels: a wedge for each slot (shown by Wheels:ApplyStyle).
    hud.Wedges = {}
    for slot = 1, SLOTS do
        local wedge = hud:CreateTexture(nil, "BACKGROUND", nil, 4)
        wedge:SetTexture(WEDGE_FILE)
        wedge:SetSize(360, 360)
        wedge:SetPoint("CENTER")
        wedge:SetRotation(-math.rad((slot - 1) * STEP))
        hud.Wedges[slot] = wedge
    end
    -- Above the wheel: what it is and which of the wheels it is (LB and RB change it); below: what the slot is.
    local function Band(parent)
        local band = CreateFrame("Frame", nil, parent)
        band:SetSize(400, 64)
        local back = band:CreateTexture(nil, "BACKGROUND")
        back:SetAllPoints()
        back:SetColorTexture(0.03, 0.025, 0.03, 0.78)
        for _, point in ipairs({ "TOPLEFT", "BOTTOMLEFT" }) do
            local line = band:CreateTexture(nil, "BORDER")
            line:SetColorTexture(0.62, 0.54, 0.38, 0.7)
            line:SetHeight(1)
            line:SetPoint(point)
            line:SetPoint(point == "TOPLEFT" and "TOPRIGHT" or "BOTTOMRIGHT")
        end
        return band
    end
    hud.Top = Band(hud)
    hud.Top:SetPoint("BOTTOM", hud, "TOP", 0, 18)
    hud.Top.Title = Addon.Fonts:String(hud.Top, "OVERLAY", "Normal")
    hud.Top.Title:SetPoint("TOP", 0, -9)
    hud.Top.Dots = {}
    for page = 1, COUNT do
        local dot = Circle(hud.Top, 11, 0.55, 0.56, 0.58, 1, "ARTWORK", 1)
        dot:SetPoint("CENTER", hud.Top, "BOTTOM", (page - (COUNT + 1) / 2) * 20, 18)
        hud.Top.Dots[page] = dot
    end
    hud.Top.LB = Addon.Fonts:String(hud.Top, "OVERLAY", "HighlightSmall")
    hud.Top.LB:SetPoint("CENTER", hud.Top, "BOTTOM", -(COUNT + 1) * 10 - 16, 18)
    hud.Top.RB = Addon.Fonts:String(hud.Top, "OVERLAY", "HighlightSmall")
    hud.Top.RB:SetPoint("CENTER", hud.Top, "BOTTOM", (COUNT + 1) * 10 + 16, 18)
    hud.Bottom = Band(hud)
    hud.Bottom:SetSize(400, 58)
    hud.Bottom:SetPoint("TOP", hud, "BOTTOM", 0, -18)
    hud.slots = {}
    for slot = 1, SLOTS do
        local frame = CreateSlotFrame(hud, slot)
        frame.action = Wheels.ActionOf(1, slot)
        frame.hudIndex = slot
        frame.Wedge = hud.Wedges[slot]
        hud.slots[slot] = frame
        -- The slots take the mouse only while the wheel is being filled (Wheels:SetEditing).
        frame:EnableMouse(false)
        self:WireSlot(frame)
    end
    self:SetNumbers(hud.slots, true)
    -- Esc, or anything else that hides the wheel, ends the filling.
    hud:SetScript("OnHide", function()
        if self.previewing then
            self.previewing = nil
            self:SetEditing(false)
        end
    end)
    self.hud = hud
    self:ApplyLayout()
end

-- Size, place and see-through-ness from the settings.
function Wheels:ApplyLayout()
    local hud = self.hud
    if not hud then return end
    local db = Addon.db
    hud:SetScale(db.wheelScale)
    hud:SetAlpha(db.wheelAlpha)
    hud:ClearAllPoints()
    hud:SetPoint("CENTER", UIParent, "CENTER", db.wheelX, db.wheelY)
    for slot, frame in ipairs(hud.slots) do
        frame:SetScale(db.wheelSlotScale * ((slot == self.selected and not self:Wedges()) and 1.18 or 1))
    end
    self:ApplyStyle()
end

-- Colours of a slot by what it is doing: the gold ring of the round look, and the wedge of the look of the game's wheels.
local RING = {
    filled = { 0.48, 0.39, 0.25, 1 }, empty = { 0.48, 0.39, 0.25, 0.55 }, selected = { 1, 0.81, 0.44, 1 },
    active = { 1, 0.85, 0.25, 1 }, dim = { 0.69, 0.54, 0.27, 1 }, drop = { 0.5, 1, 0.55, 1 },
}
local WEDGE = {
    filled = { 0.04, 0.035, 0.05, 0.82 }, empty = { 0.04, 0.035, 0.05, 0.62 }, selected = { 0.47, 0.48, 0.5, 0.7 },
    active = { 0.28, 0.23, 0.08, 0.82 }, dim = { 0.36, 0.37, 0.39, 0.62 }, drop = { 0.18, 0.5, 0.24, 0.85 },
}

-- Setting "wheelWedges" (on by default): segments like the game's own wheels. Off: round slots.
function Wheels:Wedges()
    return Addon.db.wheelWedges ~= false
end

-- Draws the colour a slot has now: the drop hint under a carried thing, the choice of the stick (dimmed while it only waits), or
-- filled / empty.
function Wheels:Paint(frame)
    local mode
    local wheel = WheelOf(frame)
    if frame.dropHint then
        mode = "drop"
    elseif frame.hudIndex and frame.hudIndex == self.selected then
        mode = self.dimmed and "dim" or "selected"
    elseif frame.hudIndex and self.flyoutSpells then
        mode = self.flyoutSpells[frame.slot] and "filled" or "empty"
    elseif self:IsPetWheel(wheel) then
        local entry = self:PetSlot(wheel, frame.slot)
        mode = entry and (entry.isActive and "active" or "filled") or "empty"
    else
        mode = self:Get(wheel, frame.slot) and "filled" or "empty"
    end
    local ring = RING[mode]
    frame.Ring:SetVertexColor(ring[1], ring[2], ring[3], ring[4])
    if frame.Wedge then
        local wedge = WEDGE[mode]
        frame.Wedge:SetVertexColor(wedge[1], wedge[2], wedge[3], wedge[4])
    end
end

local function ShowEntry(frame, entry)
    local _, icon, isFlyout = Describe(entry)
    frame.Icon:SetTexture(entry and icon or nil)
    frame.Icon:SetVertexColor(1, 1, 1, 1)
    frame.Disc:SetVertexColor(0.08, 0.065, 0.05, entry and 1 or 0.55)
    if frame.FlyoutArrow then frame.FlyoutArrow:SetShown(entry ~= nil and isFlyout == true) end
    Wheels:Paint(frame)
end

local function ShowFlyoutSpell(frame, spell)
    local tex
    if spell and spell.id and C_Spell and C_Spell.GetSpellTexture then
        local ok, icon = pcall(C_Spell.GetSpellTexture, spell.id)
        tex = ok and icon or nil
    end
    frame.Icon:SetTexture(spell and (tex or 134400) or nil)
    frame.Icon:SetVertexColor(1, 1, 1, 1)
    frame.Disc:SetVertexColor(0.08, 0.065, 0.05, spell and 1 or 0.55)
    if frame.FlyoutArrow then frame.FlyoutArrow:Hide() end
    Wheels:Paint(frame)
end

local function ShowPetEntry(frame, entry)
    frame.Icon:SetTexture(entry and (entry.icon or 134400) or nil)
    if entry and entry.usable == false then
        frame.Icon:SetVertexColor(0.45, 0.45, 0.45, 1)
    else
        frame.Icon:SetVertexColor(1, 1, 1, 1)
    end
    frame.Disc:SetVertexColor(0.08, 0.065, 0.05, entry and 1 or 0.55)
    if frame.FlyoutArrow then frame.FlyoutArrow:Hide() end
    Wheels:Paint(frame)
end

-- The slot the stick points at, written on the open wheel's button (outside combat only: the attribute is on a protected frame),
-- so that letting go can use it even when the secure code cannot read the stick.
function Wheels:PublishPick(slot)
    local face = self.faces and self.opened and self.faces[self.opened]
    if face and not InCombatLockdown() and face:GetAttribute("pickslot") ~= slot then face:SetAttribute("pickslot", slot) end
end

function Wheels:Select(slot)
    local hud = self.hud
    if not hud or self.selected == slot then return end
    self.selected = slot
    self.dimmed = nil
    self:PublishPick(slot)
    local db = Addon.db
    for index, frame in ipairs(hud.slots) do
        local on = index == slot
        frame:SetScale(db.wheelSlotScale * ((on and not self:Wedges()) and 1.18 or 1))
        self:Paint(frame)
    end
    self:DrawCenter()
end

-- Round look: name and buttons in the middle. Look of the game's wheels: the name in the panel below, the buttons in the title.
function Wheels:ApplyStyle()
    local hud = self.hud
    if not hud then return end
    local wedges = self:Wedges()
    for _, wedge in ipairs(hud.Wedges) do wedge:SetShown(wedges) end
    for _, frame in ipairs(hud.slots) do
        frame.Ring:SetShown(not wedges)
        frame.Disc:SetShown(not wedges)
        frame.Number:SetShown(not wedges)
        -- Without the ring and the disc the icon fills the slot (the round look keeps its gold ring around a smaller icon).
        local icon = wedges and 54 or 46
        frame.Icon:SetSize(icon, icon)
    end
    hud.Top:SetShown(wedges)
    -- While the wheel is filled the panel below makes room for the buttons that pick a wheel.
    hud.Bottom:SetShown(wedges and not self.previewing)
    hud.Name:ClearAllPoints()
    hud.Hint:ClearAllPoints()
    if wedges and not self.previewing then
        hud.Name:SetPoint("TOP", hud.Bottom, "TOP", 0, -10)
        hud.Name:SetWidth(380)
        hud.Hint:SetPoint("TOP", hud.Name, "BOTTOM", 0, -6)
        hud.Hint:SetWidth(380)
    else
        hud.Name:SetPoint("CENTER", hud, "CENTER", 0, 12)
        hud.Name:SetWidth(124)
        hud.Hint:SetPoint("TOP", hud.Name, "BOTTOM", 0, -6)
        hud.Hint:SetWidth(124)
    end
    self:DrawCenter()
end

-- The title above the wheel: its bar and the buttons that open it, the page dots and the buttons that turn the page.
function Wheels:DrawHeader()
    local hud = self.hud
    if not hud or not hud.Top or not self.open then return end
    if self.flyoutSpells then
        hud.Top.Title:SetText(self.flyoutName or "Flyout")
        for _, dot in ipairs(hud.Top.Dots) do dot:Hide() end
        hud.Top.LB:SetText("")
        hud.Top.RB:SetText("")
        return
    end
    local modifier, key = WheelKeys(self.open)
    local ok, glyphs = pcall(function() return Addon.MenuHints:KeyText(modifier .. "-" .. key) end)
    local keys = ok and type(glyphs) == "string" and glyphs ~= "" and glyphs or Wheels.Label(self.open)
    local title = string.format(Text("wheelsBar"), self.open + 3) .. "  ·  " .. keys
    -- A wheel that fills itself says what with.
    local category = Addon.Dynamic and Addon.Dynamic:CategoryOf(self.open)
    if category then title = title .. "  ·  " .. Text("dynName" .. category) end
    hud.Top.Title:SetText(title)
    for page, dot in ipairs(hud.Top.Dots) do
        dot:Show()
        if page == self.open then dot:SetVertexColor(1, 0.81, 0.23, 1) else dot:SetVertexColor(0.55, 0.56, 0.58, 1) end
    end
    local function Glyph(key, fallback)
        local good, text = pcall(function() return Addon.MenuHints:KeyText(key) end)
        return good and type(text) == "string" and text ~= "" and text or fallback
    end
    hud.Top.LB:SetText(Glyph("PADLSHOULDER", "LB"))
    hud.Top.RB:SetText(Glyph("PADRSHOULDER", "RB"))
end

function Wheels:DrawCenter()
    local hud, db = self.hud, Addon.db
    if not hud then return end
    self:DrawHeader()
    local name
    if self.flyoutSpells then
        local spell = self.selected and self.flyoutSpells[self.selected]
        if spell then
            local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spell.id)
            name = (type(info) == "table" and info.name) or spell.name or tostring(spell.id)
        end
    elseif self.open and self:IsPetWheel(self.open) then
        local entry = self.selected and self:PetSlot(self.open, self.selected)
        name = entry and entry.name
    else
        local entry = self.selected and self.open and self:Get(self.open, self.selected)
        name = entry and Describe(entry)
    end
    if self:Wedges() and not self.previewing then
        -- The panel below: the name of the chosen slot and what the buttons do.
        hud.Name:SetText(db.wheelNames and (name or (self.selected and Text("wheelEmpty")) or "") or "")
        if db.wheelHints then
            hud.Hint:SetText(Text((db.wheelToggle or self.flyoutSpells) and "wheelHintToggle" or "wheelHintHold"))
        else
            hud.Hint:SetText("")
        end
        return
    end
    if self.previewing then
        -- While the wheel is filled the middle says what to do.
        hud.Name:SetText(Text("wheelEditHub"))
    else
        hud.Name:SetText(db.wheelNames and (name or (self.selected and Text("wheelEmpty")) or "") or "")
    end
    if (db.wheelHints or self.previewing) and self.open then
        if self.flyoutSpells then
            hud.Hint:SetText(Text("wheelHintToggle"))
        else
            local modifier, key = WheelKeys(self.open)
            local ok, glyphs = pcall(function() return Addon.MenuHints:KeyText(modifier .. "-" .. key) end)
            hud.Hint:SetText(ok and glyphs or Wheels.Label(self.open))
        end
    else
        hud.Hint:SetText("")
    end
end

local function IsOver(frame)
    if frame.IsMouseOver then return frame:IsMouseOver() end
    return MouseIsOver(frame)
end

-- While slots are on the screen to be filled (the wheel in fill mode, the small wheels beside the spellbook): the slot under a
-- dragged spell, item or macro is lit, and letting go of the mouse over a slot with something on the cursor puts it there even
-- when the slot's own scripts were not called (a frame in between, or a drop the game did not hand to it). The scripts count
-- first: a slot they filled a moment ago is left alone. `state` keeps the mouse button between two calls.
function Wheels:WatchSlots(slots, state)
    local carrying = GetCursorInfo() ~= nil
    local over
    for _, frame in ipairs(slots) do
        local hit = carrying and IsOver(frame) or false
        if hit then over = frame end
        if hit ~= (frame.dropHint or false) then
            frame.dropHint = hit
            self:Paint(frame)
        end
    end
    local down = IsMouseButtonDown("LeftButton") and true or false
    local was = state.mouseWasDown
    state.mouseWasDown = down
    if was and not down and carrying and over then
        local wheel = WheelOf(over)
        if self.lastPlace and GetTime() - self.lastPlace < 0.4 then
            self:Trace("released over slot %d of wheel %s, already placed by its scripts", over.slot, tostring(wheel))
        else
            self:Trace("released over slot %d of wheel %s with %s on the cursor and no script ran: placing it", over.slot, tostring(wheel), tostring((GetCursorInfo())))
            self:Place(wheel, over.slot)
        end
    elseif was and not down and carrying then
        self:Trace("released with %s on the cursor, not over a slot", tostring((GetCursorInfo())))
    end
end

function Wheels:WatchCursor()
    self.watch = self.watch or {}
    self:WatchSlots(self.hud.slots, self.watch)
end

-- Draws the slots again when the bars changed (checked while a wheel is on the screen).
function Wheels:Freshen()
    if self.stale then
        self.stale = nil
        self:Redraw()
    end
end

-- A stick let go springs back through the middle in a moment, often before the button is let go. The choice stays for as long as
-- the setting "wheelKeep" says (milliseconds) after the stick leaves its slot, so that letting go of the button a little later
-- still uses it; keep the stick in the middle for longer and it is a cancel. Pushing it to another slot changes the choice at
-- once. While the choice only waits for that, the chosen slot dims and a bar in the middle runs down.
local function KeepSeconds()
    local ms = tonumber(Addon.db.wheelKeep) or 800
    return math.max(0.1, ms / 1000)
end

-- `left` is how much of the waiting time is left (1 to 0), nil when the stick is on a slot or nothing is chosen.
function Wheels:DrawCountdown(left)
    local hud = self.hud
    if not hud then return end
    if not hud.Timer then
        hud.Timer = hud:CreateTexture(nil, "OVERLAY")
        hud.Timer:SetTexture(WHITE)
        hud.Timer:SetVertexColor(1, 0.81, 0.44, 0.9)
        hud.Timer:SetHeight(3)
        hud.Timer:SetPoint("LEFT", hud, "CENTER", -45, -44)
    end
    if left then
        hud.Timer:SetWidth(math.max(1, 90 * left))
        hud.Timer:Show()
    else
        hud.Timer:Hide()
    end
    local dim = left ~= nil
    if self.dimmed ~= dim then
        self.dimmed = dim
        local frame = self.selected and hud.slots[self.selected]
        if frame then self:Paint(frame) end
    end
end

local function Update(hud)
    Wheels:Freshen()
    -- A button that never comes up must not keep the sticks for ever.
    if Wheels.holding and GetTime() - (Wheels.holdingAt or 0) > MAX_HOLD then
        Wheels.holding = nil
        Wheels:SetSticks(false)
        if Addon.db.wheelToggle then Wheels:Cancel() end
    end
    local len, x, y = Wheels:Stick()
    local slot = Wheels.SlotOf(len, x, y)
    local now = GetTime()
    -- While the wheel is filled the stick only points; nothing is kept.
    local keep = Wheels.previewing and 0 or KeepSeconds()
    local waited = Wheels.latchAt and now - Wheels.latchAt or 0
    if slot then
        Wheels.latch, Wheels.latchAt = slot, now
        waited = 0
    elseif Wheels.latch and waited > keep then
        Wheels.latch = nil
    end
    Wheels:Select(slot or Wheels.latch)
    Wheels:DrawCountdown((not slot and Wheels.latch and keep > 0) and math.max(0, 1 - waited / keep) or nil)
    if Wheels.previewing then Wheels:WatchCursor() end
end

-- Open the wheel of a face button (nil closes it).
function Wheels:SetOpen(wheel)
    if wheel == nil and self.previewing then wheel = 1 end
    if not wheel then
        self.open, self.opened, self.selected, self.latch, self.dimmed = nil, nil, nil, nil, nil
        self.flyoutID, self.flyoutSpells, self.flyoutName = nil, nil, nil
        self.holding = nil
        self:SetSticks(false)
        if self.hud and self.hud.Timer then self.hud.Timer:Hide() end
        if self.hud then self.hud:SetScript("OnUpdate", nil); self.hud:Hide() end
        return
    end
    self:CreateHUD()
    self.open, self.opened, self.selected, self.latch, self.dimmed = wheel, wheel, nil, nil, nil
    if self.hud.Timer then self.hud.Timer:Hide() end
    if self.stickEvents then wipe(self.stickEvents) end
    self:SetNumbers(self.hud.slots, true)
    self:Redraw()
    self.hud:SetScript("OnUpdate", Update)
    self.hud:Show()
end

-- Enters or leaves a flyout sub-wheel (driven by the secure layer's "flyoutid" attribute).
function Wheels:SetFlyout(flyoutID)
    if type(flyoutID) == "number" and flyoutID > 0 then
        local spells, flyName
        if Addon.FlyoutSpells then
            local _, _
            spells, _, _, flyName = Addon.FlyoutSpells(flyoutID)
        end
        self.flyoutID = flyoutID
        self.flyoutSpells = spells or {}
        self.flyoutName = flyName
        self.selected, self.latch, self.dimmed = nil, nil, nil
        self.holdingAt = GetTime()
        if self.hud and self.hud.Timer then self.hud.Timer:Hide() end
        if self.open then self:Redraw() end
    else
        self.flyoutID, self.flyoutSpells, self.flyoutName = nil, nil, nil
        if self.open then self:Redraw() end
    end
end

-- LB / RB (or the pad) changed the shown wheel: the secure side already uses it, this draws it.
function Wheels:SetPage(page)
    if not self.open or type(page) ~= "number" or page == self.open then return end
    self.open = page
    self:Redraw()
    if SOUNDKIT and SOUNDKIT.GAMEPAD_RADIAL_MENU_TAB_OVER then pcall(PlaySound, SOUNDKIT.GAMEPAD_RADIAL_MENU_TAB_OVER) end
end

local function RefreshSlotNumbers(slots)
    if Addon.db.wheelNumbers == false then return end
    local api = NumbersApi()
    if not api then return end
    if type(api.RefreshButton) == "function" then
        for _, frame in ipairs(slots) do pcall(api.RefreshButton, frame) end
    elseif type(api.Refresh) == "function" then
        pcall(api.Refresh)
    end
end

function Wheels:Redraw()
    local hud = self.hud
    if hud and self.open then
        if self.flyoutSpells then
            for slot, frame in ipairs(hud.slots) do
                frame.action = nil
                ShowFlyoutSpell(frame, self.flyoutSpells[slot])
                frame.Number:SetText(tostring(slot))
            end
        elseif self:IsPetWheel(self.open) then
            for slot, frame in ipairs(hud.slots) do
                frame.action = nil
                ShowPetEntry(frame, self:PetSlot(self.open, slot))
                frame.Number:SetText(tostring(slot))
            end
        else
            for slot, frame in ipairs(hud.slots) do
                frame.action = Wheels.ActionOf(self.open, slot)
                ShowEntry(frame, self:Get(self.open, slot))
                frame.Number:SetText(tostring(slot))
            end
        end
        RefreshSlotNumbers(hud.slots)
        self:DrawCenter()
    end
    self:RedrawDock()
end

-- ---------------------------------------------------------------------------------------------
-- The small wheels beside the spellbook
-- ---------------------------------------------------------------------------------------------

-- While a spell, item or macro is carried on the cursor all five wheels stand beside the windows that are open, small, each with its twelve slots, so a spell is dragged
-- a short way onto a slot and no wheel has to be picked first. Drops, drags out and right clicks work as on the big wheel.
local DOCK = { slot = 24, radius = 60, face = 152, cellW = 156, cellH = 178, head = 40, pad = 8 }

function Wheels:CreateDock()
    if self.dock then return end
    local d = DOCK
    local dock = CreateFrame("Frame", "ClassicConsoleGamepadUIWheelDock", UIParent)
    dock:SetSize(2 * d.cellW + 2 * d.pad, d.head + 3 * d.cellH + d.pad)
    dock:SetFrameStrata("DIALOG")
    dock:SetFrameLevel(50)
    dock:EnableMouse(true)
    dock:Hide()
    local rim = dock:CreateTexture(nil, "BACKGROUND", nil, 0)
    rim:SetAllPoints()
    rim:SetColorTexture(0.48, 0.39, 0.25, 0.95)
    local fill = dock:CreateTexture(nil, "BACKGROUND", nil, 1)
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", -1, 1)
    fill:SetColorTexture(0.05, 0.04, 0.03, 0.9)
    dock.Title = Addon.Fonts:String(dock, "OVERLAY", "HighlightSmall")
    dock.Title:SetPoint("TOP", 0, -8)
    dock.Title:SetWidth(2 * d.cellW)
    dock.minis, dock.slots, dock.watch = {}, {}, {}
    local function Cell(index)
        local mini = CreateFrame("Frame", nil, dock)
        mini:SetSize(d.cellW, d.cellH)
        mini:SetPoint("TOPLEFT", dock, "TOPLEFT", d.pad + ((index - 1) % 2) * d.cellW, -d.head - math.floor((index - 1) / 2) * d.cellH)
        return mini
    end
    for wheel = 1, COUNT do
        local mini = Cell(wheel)
        mini.Label = Addon.Fonts:String(mini, "OVERLAY", "HighlightSmall")
        mini.Label:SetPoint("TOP", 0, -2)
        local face = CreateFrame("Frame", nil, mini)
        face:SetSize(d.face, d.face)
        face:SetPoint("TOP", 0, -20)
        local ring = Circle(face, d.face, 0.35, 0.29, 0.19, 0.95, "BACKGROUND", 0)
        ring:SetPoint("CENTER")
        local disc = Circle(face, d.face - 4, 0.07, 0.055, 0.04, 0.95, "BACKGROUND", 1)
        disc:SetPoint("CENTER")
        -- In the middle of a wheel that fills itself: what it is filled with (Dynamic.lua).
        mini.Kind = Addon.Fonts:String(face, "OVERLAY", "HighlightSmall")
        mini.Kind:SetPoint("CENTER")
        mini.Kind:SetWidth(78)
        mini.Kind:SetJustifyH("CENTER")
        mini.Kind:SetTextColor(1, 0.82, 0.4)
        for slot = 1, SLOTS do
            local frame = CreateSlotFrame(face, slot, d.slot, d.radius)
            frame.wheel = wheel
            frame.action = Wheels.ActionOf(wheel, slot)
            frame:EnableMouse(true)
            self:WireSlot(frame)
            dock.slots[#dock.slots + 1] = frame
        end
        dock.minis[wheel] = mini
    end
    -- The cell left over says what the wheels are.
    local note = Addon.Fonts:String(Cell(COUNT + 1), "OVERLAY", "DisableSmall")
    note:SetPoint("TOPLEFT", 10, -30)
    note:SetPoint("TOPRIGHT", -10, -30)
    note:SetJustifyH("LEFT")
    dock.Note = note
    dock:SetScript("OnUpdate", function() self:Freshen(); self:WatchSlots(dock.slots, dock.watch) end)
    -- The pad's window switching: the dock is one of the windows LT and RT step through (it stands to the right of the bags or
    -- the spellbook, so RT goes to it and LT back), its slots are walked with the D-pad, A puts down what is carried, B puts it
    -- back and the dock goes. The rim lights up while the dock has the focus.
    dock.FocusGamepad = function() rim:SetColorTexture(1, 0.81, 0.44, 1) end
    dock.UnfocusGamepad = function() rim:SetColorTexture(0.48, 0.39, 0.25, 0.95) end
    dock.SmartNavigationCloseHandler = function()
        if GetCursorInfo() ~= nil then
            -- What is carried is put down: a slot's content picked up with A is gone from the wheel then.
            ClearCursor()
        elseif self.previewing then
            self:Preview(false)
        end
        return true
    end
    dock:SetScript("OnShow", function()
        self:JoinFocus(true)
        self:SetNumbers(dock.slots, true)
    end)
    dock:SetScript("OnHide", function()
        self:JoinFocus(false)
        self:SetNumbers(dock.slots, false)
    end)
    self.dock = dock
end

-- Tells the game's window switching (GamepadMode.FrameControlsManager) that the dock is a window. Shown without taking the focus:
-- the player is in the bags or the spellbook with a thing in hand, and presses LT / RT to move between windows and the dock.
-- Both FrameShown and FrameHidden are wrapped by Blizzard's SecureHelper:WrapFunction (taint-free), and calling them through
-- securecallfunction adds an extra barrier. We only join while manager.isUIFocused == true (another UI panel already owns focus)
-- so the dock can never steal character control on /reload or when no window is focused.
local function Barrier(...)
    local call = securecallfunction
    if type(call) ~= "function" then return pcall(...) end
    return pcall(call, ...)
end

function Wheels:JoinFocus(shown)
    local mode = GamepadMode
    local manager = type(mode) == "table" and mode.FrameControlsManager or nil
    if type(manager) ~= "table" or not self.dock then return end
    if shown then
        if Addon.db.wheelsDockFocus ~= true or self.joined or manager.isUIFocused ~= true or type(manager.FrameShown) ~= "function" then return end
        if Barrier(manager.FrameShown, manager, self.dock, false, false) then self.joined = true end
    elseif self.joined then
        self.joined = nil
        if type(manager.FrameHidden) == "function" then Barrier(manager.FrameHidden, manager, self.dock) end
    end
end

-- /cgp wheels safe: every part of the wheels that reaches into how the pad, the camera or the game's focus work is switched off,
-- the wheels themselves stay (the R3 / L3 combos too: they bind the stick clicks; "wheelCombos" is the one to turn off for those).
-- To find out which part a problem comes from: switch the parts on again one at a time.
function Wheels:Safe()
    local db = Addon.db
    -- Only what reaches into the pad, the camera or the game's focus: the numbers of DoesItDiePlus and the dynamic wheels do not, so
    -- they are left as the player set them.
    db.wheelBlock, db.wheelsDockFocus, db.wheelToggle, db.wheelsDockAlways, db.wheelCombos = "off", false, false, false, false
    self:Reset()
    Addon:QueueRefresh(true)
    Addon:Print("wheels safe: no stick or camera stopping, no window-list entry, no open-choose-confirm mode, no always-up small wheels, and the R3 / L3 combos are off (the stick clicks are the game's). The numbers and the dynamic wheels were not touched. Open the wheels with the keys you set in the settings.")
end

-- /cgp wheels reset: what this addon did to the sticks and the window list is put back (the stick listener off, the dock out of the
-- game's window list). It does NOT touch the game's focus state: calling SetUIFocusState from here wrote the game's focus and
-- binding tables as this addon (seen in the saved diagnostics: FrameControlsManager.isUIFocused and activeBindings.PAD1/3/4 owned
-- by this addon, then "SetPreferredGamepadInteractTarget blocked" twice). That is /cgp wheels unfocus, on purpose.
function Wheels:Reset()
    self.holding = nil
    if self.hud then self:SetOpen(nil) end
    self:SuspendCamera(false)
    self:LowerBlocker()
    if self.stickSeen then wipe(self.stickSeen) end
    self.stickArmed = nil
    if self.blocker and self.blocker.EnableGamePadStick then pcall(self.blocker.EnableGamePadStick, self.blocker, false) end
    if self.eater then
        self.eater:SetScript("OnUpdate", nil)
        if self.eater.EnableGamePadStick then pcall(self.eater.EnableGamePadStick, self.eater, false) end
        self.eater:Hide()
    end
    self.sticksOn = false
    self:JoinFocus(false)
    Addon:Print("wheels reset: stick listener off, the small wheels out of the window list. The game's own focus is not touched (/cgp wheels unfocus does that).")
end

-- /cgp wheels unfocus: the emergency lever for controls that do not answer because the game thinks the interface has the focus (the
-- sticks then move a cursor, not the character): asks the game to give the focus back, through a taint barrier. It still may mark
-- some of the game's gamepad tables as this addon's and be followed by one "blocked action" message about the interact target; it
-- is only run when the player types it.
function Wheels:Unfocus()
    local mode = GamepadMode
    local manager = type(mode) == "table" and mode.FrameControlsManager or nil
    if type(manager) ~= "table" or type(manager.SetUIFocusState) ~= "function" then
        Addon:Print("wheels unfocus: the game's window system is not there")
        return
    end
    if manager.isUIFocused ~= true then
        Addon:Print("wheels unfocus: the game does not think the interface has the focus (nothing done)")
        return
    end
    local ok = Barrier(manager.SetUIFocusState, manager, false)
    Addon:Print("wheels unfocus: " .. (ok and "the focus was given back to the character" or "the game refused"))
end

-- What the game's window focus did since this addon loaded, for finding out who focuses the interface.
-- Post-hooks only (they leave the game's code secure): every FrameShown, FrameHidden and SetUIFocusState call is noted with its
-- time, the window, the focus state after it and the top of the stack, up to 30 calls; kept in the saved variables too.
function Wheels:WatchFocus()
    if self.focusWatched then return end
    local mode = GamepadMode
    local manager = type(mode) == "table" and mode.FrameControlsManager or nil
    if type(manager) ~= "table" or type(hooksecurefunc) ~= "function" then return end
    self.focusWatched = true
    local log, started = {}, GetTime()
    self.focusLog = log
    Addon.db.wheelFocusLog = log
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
    local log = self.focusLog
    if not log or #log == 0 then Addon:Print("wheels focus: no focus call seen since the addon loaded"); return end
    for _, entry in ipairs(log) do
        Addon:Print(string.format("wheels focus: +%ss %s %s (interface focused after: %s)", entry.at, entry.what, tostring(entry.window or ""), entry.focused))
    end
end

function Wheels:RedrawDock()
    local dock = self.dock
    if not dock then return end
    for wheel, mini in ipairs(dock.minis) do
        local category = Addon.Dynamic and Addon.Dynamic:CategoryOf(wheel)
        mini.Kind:SetText(category and Text("dynName" .. category) or "")
    end
    for _, frame in ipairs(dock.slots) do
        frame.dropHint = false
        if self:IsPetWheel(frame.wheel) then
            frame.action = nil
            ShowPetEntry(frame, self:PetSlot(frame.wheel, frame.slot))
        else
            frame.action = Wheels.ActionOf(frame.wheel, frame.slot)
            ShowEntry(frame, self:Get(frame.wheel, frame.slot))
        end
    end
    if dock:IsShown() then RefreshSlotNumbers(dock.slots) end
end

-- The windows things are dragged from onto the wheels: the spellbook, the bags (the combined bag and the single ones), the macro
-- window and the collections (mounts). `around` also holds the character window, which the gamepad interface puts beside the
-- bags, so the small wheels do not cover it.
local BAG_FRAMES = { "ContainerFrameCombinedBags" }
for i = 1, 13 do BAG_FRAMES[#BAG_FRAMES + 1] = "ContainerFrame" .. i end

local function Shown(frame)
    return type(frame) == "table" and frame.IsShown ~= nil and frame:IsShown() == true
end

-- Something is on the cursor that a slot could take (not money, not a buy-back item).
local function Carrying()
    local ok, kind = pcall(GetCursorInfo)
    return ok and type(kind) == "string" and kind ~= "money" and kind ~= "merchant"
end

local function DragWindows()
    local sources = {}
    -- The spellbook is a page of the player spells window; an older build has a window of its own.
    local owner = PlayerSpellsFrame
    local book = owner and owner.SpellBookFrame
    if not owner then owner = SpellBookFrame; book = owner end
    if Shown(owner) and Shown(book) then sources[#sources + 1] = owner end
    for _, name in ipairs(BAG_FRAMES) do
        local frame = _G[name]
        if Shown(frame) then sources[#sources + 1] = frame end
    end
    if Shown(MacroFrame) then sources[#sources + 1] = MacroFrame end
    if Shown(CollectionsJournal) then sources[#sources + 1] = CollectionsJournal end
    local around = {}
    for index, frame in ipairs(sources) do around[index] = frame end
    if #sources > 0 and Shown(CharacterFrame) then around[#around + 1] = CharacterFrame end
    -- Keep the small wheels dock clear of an open SpellBook flyout (e.g. Hunter Aspect list).
    if #sources > 0 and Shown(SpellFlyout) and not SpellFlyout.isActionBar then around[#around + 1] = SpellFlyout end
    return sources, around
end

-- What a window shows can reach beyond its own rectangle (the bags draw their rows of things past the frame's edge), so the
-- rectangle of the frame and its children counts too, but only up to this far beyond the frame (a child far away must not push
-- the wheels off the screen).
local BOUNDS_EXTRA = 320

-- A window's left, right and top edge in its own units.
local function Edges(frame)
    local l, r, t = frame:GetLeft(), frame:GetRight(), frame:GetTop()
    if l and r and t and frame.GetBoundsRect then
        local ok, bl, _, bw, bh, bb = pcall(frame.GetBoundsRect, frame)
        if ok and type(bl) == "number" and type(bw) == "number" then
            local br = bl + bw
            l = math.min(l, bl)
            r = math.max(r, math.min(br, r + BOUNDS_EXTRA))
        end
    end
    return l, r, t
end

-- The box around the windows, in interface points of the screen: left, right and top edge.
local function Around(windows)
    local ui = UIParent:GetEffectiveScale()
    local left, right, top
    for _, frame in ipairs(windows) do
        local l, r, t = Edges(frame)
        if l and r and t then
            local scale = frame:GetEffectiveScale() / ui
            l, r, t = l * scale, r * scale, t * scale
            left, right, top = math.min(left or l, l), math.max(right or r, r), math.max(top or t, t)
        end
    end
    return left, right, top
end

-- Beside the windows, on the side that faces the middle of the screen (the right of windows on the left half, the left of the others),
-- on the other side when there is no room there. Made smaller when the screen is low.
function Wheels:PlaceDock(windows)
    local dock = self.dock
    local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
    local scale = math.min(1, screenH * 0.94 / dock:GetHeight())
    dock:SetScale(scale)
    local left, right, top = Around(windows)
    self.dockAt = string.format("%d %d %d %d", #windows, left or 0, right or 0, top or screenH)
    local width, height = dock:GetWidth() * scale, dock:GetHeight() * scale
    local x
    if not left then
        -- No window open (something was picked up from a bar): the right edge of the screen, in the middle.
        x = math.max(0, screenW - width - 24)
        top = (screenH + height) / 2
    else
        local roomRight, roomLeft = right + 6 + width <= screenW, left - 6 - width >= 0
        local towardRight = (left + right) / 2 <= screenW / 2
        if towardRight and roomRight then x = right + 6
        elseif not towardRight and roomLeft then x = left - 6 - width
        elseif roomRight then x = right + 6
        elseif roomLeft then x = left - 6 - width
        else x = math.max(0, screenW - width) end
        top = math.min(screenH, math.max(top, height))
    end
    dock:ClearAllPoints()
    dock:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, top / scale)
end

-- Called every refresh (also in combat: it only touches plain frames).
function Wheels:UpdateDock(gamepad)
    -- While something is carried (put the spell, item or macro down, or let go on a slot, and the wheels go), while the wheels
    -- are being filled (that is how a slot is emptied with the pad: pick it up with A, put it down with B), and, when the player
    -- asked for it, whenever a window to drag from is open.
    local around
    if gamepad and Addon.db.wheels == true and Addon.db.wheelsDock ~= false and not Addon.nativeView then
        local sources, windows = DragWindows()
        if Carrying() or self.previewing or (Addon.db.wheelsDockAlways == true and #sources > 0) then around = windows end
    end
    if not around then
        if self.dock and self.dock:IsShown() then self.dock:Hide() end
        return
    end
    self:CreateDock()
    local dock = self.dock
    if dock:IsShown() and not self.joined then self:JoinFocus(true) end
    if dock:IsShown() then
        -- A window was opened, closed or moved: the small wheels follow.
        local left, right, top = Around(around)
        if string.format("%d %d %d %d", #around, left or 0, right or 0, top or UIParent:GetHeight()) ~= self.dockAt then
            self:PlaceDock(around)
        end
        return
    end
    self:PlaceDock(around)
    dock.Title:SetText(Text("wheelsDockTitle"))
    dock.Note:SetText(Text("wheelsDockNote"))
    for wheel, mini in ipairs(dock.minis) do
        local modifier, key = WheelKeys(wheel)
        local ok, glyphs = pcall(function() return Addon.MenuHints:KeyText(modifier .. "-" .. key) end)
        local keys = ok and type(glyphs) == "string" and glyphs ~= "" and glyphs or Wheels.Label(wheel)
        mini.Label:SetText(keys .. "  -  " .. string.format(Text("wheelsBar"), wheel + 3))
    end
    self:RedrawDock()
    dock:Show()
end

-- Fills the wheels: the wheel stays on the screen at its place and size (so the sliders of the settings can be tried too),
-- takes the mouse and has a button for each of the five wheels. Spells, items and macros are dragged onto it like onto an
-- action bar. "Done", Esc and /cgp wheels end it.
function Wheels:Preview(on)
    if on then
        self.previewing = true
        self:CreateHUD()
        self:SetEditing(true)
        self:SetOpen(1)
    else
        self.previewing = nil
        self:SetEditing(false)
        self:SetOpen(nil)
    end
end

function Wheels:Toggle()
    self:Preview(not self.previewing)
end

local function SpecialFrame(name, on)
    for index = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[index] == name then table.remove(UISpecialFrames, index) end
    end
    if on then tinsert(UISpecialFrames, name) end
end

-- The slots and the wheel itself take the mouse, the wheel buttons and "Done" are shown, and the wheel rises above the
-- windows while it is filled.
function Wheels:SetEditing(on)
    local hud = self.hud
    if not hud then return end
    if on and not self.editBuilt then
        self.editBuilt = true
        hud.Note = Addon.Fonts:String(hud, "OVERLAY", "DisableSmall")
        hud.Note:SetPoint("TOP", hud, "BOTTOM", 0, -6)
        hud.Note:SetWidth(340)
        hud.Tabs = {}
        for wheel = 1, COUNT do
            local tab = CreateFrame("Button", nil, hud, "UIPanelButtonTemplate")
            tab:SetSize(84, 22)
            tab:SetPoint("TOPLEFT", hud, "BOTTOMLEFT", 8 + ((wheel - 1) % 4) * 86, -38 - math.floor((wheel - 1) / 4) * 24)
            tab:SetScript("OnClick", function() self:SetOpen(wheel) end)
            hud.Tabs[wheel] = tab
        end
        hud.Done = CreateFrame("Button", nil, hud, "UIPanelButtonTemplate")
        hud.Done:SetSize(120, 24)
        hud.Done:SetPoint("TOP", hud, "BOTTOM", 0, -92)
        hud.Done:SetScript("OnClick", function() self:Preview(false) end)
        -- B on the pad (the game's key PAD2) is "back": it ends the filling like Esc does.
        hud:SetScript("OnGamePadButtonDown", function(_, button)
            if button == "PAD2" and self.previewing then self:Preview(false) end
        end)
    end
    if hud.EnableGamePadButton then pcall(hud.EnableGamePadButton, hud, on and true or false) end
    hud:EnableMouse(on and true or false)
    hud:SetFrameStrata(on and "DIALOG" or "HIGH")
    for _, frame in ipairs(hud.slots) do frame:EnableMouse(on and true or false) end
    if self.editBuilt then
        hud.Note:SetText(on and Text("wheelsEditorNote") or "")
        hud.Done:SetText(Text("wheelsDone"))
        for wheel, tab in ipairs(hud.Tabs) do
            tab:SetText(Wheels.Label(wheel))
            tab:SetShown(on and true or false)
        end
        hud.Note:SetShown(on and true or false)
        hud.Done:SetShown(on and true or false)
    end
    SpecialFrame("ClassicConsoleGamepadUIWheel", on)
    self:ApplyStyle()
end

function Wheels:Changed(key)
    if key == "wheelCameraOnly" then self.sticksAt = nil end
    self:ApplyLayout()
    if key == "wheelNames" or key == "wheelHints" or key == "wheelToggle" then self:DrawCenter() end
    if key == "wheelWedges" and self.hud then
        self:ApplyStyle()
        self:Redraw()
        for index, frame in ipairs(self.hud.slots) do
            frame:SetScale(Addon.db.wheelSlotScale * ((index == self.selected and not self:Wedges()) and 1.18 or 1))
        end
    end
    if key:sub(1, 8) == "wheelDyn" and Addon.Dynamic then
        self.petDirty = true
        if not InCombatLockdown() then self:SyncPet() end
        Addon.Dynamic:Request(0.2)
        self:RedrawDock()
        self:Redraw()
    end
    if key == "wheelNumbers" then
        if self.hud then self:SetNumbers(self.hud.slots, true) end
        if self.dock and self.dock:IsShown() then self:SetNumbers(self.dock.slots, true) end
    end
    if key == "wheelsDock" and self.dock and not Addon.db.wheelsDock then self.dock:Hide() end
end

function Wheels:Tooltip(frame, action, isPet)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    if isPet then
        if type(action) == "table" then
            if action.kind == "pet" and action.index then
                if not pcall(GameTooltip.SetPetAction, GameTooltip, action.index) then GameTooltip:SetText(action.name or "") end
            elseif action.kind == "spell" and action.id then
                if not pcall(GameTooltip.SetSpellByID, GameTooltip, action.id) then GameTooltip:SetText(action.name or "") end
            else
                GameTooltip:SetText(action.name or "")
            end
        else
            GameTooltip:SetText(Text("wheelEmpty"))
        end
    elseif action then
        if not pcall(GameTooltip.SetAction, GameTooltip, action) then GameTooltip:SetText((Describe(action))) end
    else
        GameTooltip:SetText(Text("wheelDropHere"))
    end
    GameTooltip:Show()
end

-- /cgp wheels diag: what the secure code made of the last release, and whether the layer is bound.
function Wheels:Diagnose()
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
    -- Which windows the game lists (the one that holds the pad when the controls do not answer), and whether the pad is free for the
    -- wheels: they are switched off while the interface has the pad.
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
    -- What the game itself does with the two stick clicks (the combos, when on, take them from it).
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
