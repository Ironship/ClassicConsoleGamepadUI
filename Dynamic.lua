local _, Addon = ...
-- Dynamic wheels: wheels that fill themselves. Since a wheel is an action bar (Wheels.lua: wheels 1 to 5 are the bars 4 to 8), "filling"
-- is putting items and spells on the twelve buttons of that bar, outside combat, whenever the bags or the spellbook change:
--   food        food and drink in the bags,
--   use         potions, elixirs, flasks, scrolls, bandages and the other consumables, and the usable things of the bags (a
--               hearthstone, a quest item with a "use"),
--   prof        the spells of the professions (Cooking, First Aid, Fishing, the two primary ones).
-- The player chooses which wheel each kind goes to (settings "wheelDynFood", "wheelDynUse", "wheelDynProf": 0 off, 1 to 5 the wheel).
-- A dynamic wheel belongs to this module: what the player puts on it by hand is replaced at the next run. What is already
-- in place stays where it is (the positions in a wheel do not shuffle when the bags change), what is gone is cleared and what is
-- new takes a free place; at most twelve things fit.
local Dynamic = {}
Addon.Dynamic = Dynamic

local CAPACITY = 12
local WHEELS = 5
local MAX_WRITES = 24     -- changes to the bars in one run, the rest follows in the next
local DELAY = 1           -- seconds the bags are left to settle after a change
local CATEGORIES = { "food", "use", "prof", "pet" }
local SETTING = { food = "wheelDynFood", use = "wheelDynUse", prof = "wheelDynProf", pet = "wheelDynPet" }

-- Item class and subclass numbers of the game (Consumable 0 with the subclasses below; Quest 12; Miscellaneous 15).
local CONSUMABLE, QUEST, MISC = 0, 12, 15
local FOOD_DRINK = 5
-- Order of the consumables in the "use" wheel: potions first, the rest after.
local USE_RANK = { [1] = 1, [2] = 2, [3] = 3, [4] = 4, [7] = 5, [6] = 6, [8] = 7, [0] = 8 }

local function Text(key) return Addon.L[key] end

-- The kind of wheel an item belongs to ("food", "use" or nil) and how early it comes among the others of its kind.
function Dynamic.Classify(classID, subClassID, hasSpell)
    if classID == CONSUMABLE then
        if subClassID == FOOD_DRINK then return "food", 0 end
        return "use", USE_RANK[subClassID] or 9
    elseif (classID == QUEST or classID == MISC) and hasSpell then
        return "use", 10
    end
end

-- Which kind of thing fills a wheel (nil: nothing does). Two kinds asking for the same wheel: the first of food, use, prof wins.
function Dynamic:CategoryOf(wheel)
    local db = Addon.db
    if not db or db.wheelDynamic ~= true then return nil end
    for _, category in ipairs(CATEGORIES) do
        if db[SETTING[category]] == wheel then return category end
    end
end

-- ---------------------------------------------------------------------------------------------
-- Planning (pure: no game calls)
-- ---------------------------------------------------------------------------------------------

-- `current[slot]` is what a bar's button holds now (a key such as "item:118" or nil), `wanted` the things that belong on the wheel, best
-- first. The answer is what every button should hold: what is there and still wanted stays, the rest of the buttons are taken by
-- the wanted things that are not there yet, in order.
function Dynamic.Plan(current, wanted, capacity)
    capacity = capacity or CAPACITY
    local want = {}
    local list = {}
    for _, key in ipairs(wanted) do
        if #list >= capacity then break end
        if not want[key] then want[key] = true; list[#list + 1] = key end
    end
    local result, placed = {}, {}
    for slot = 1, capacity do
        local key = current[slot]
        if key and want[key] and not placed[key] then result[slot] = key; placed[key] = true end
    end
    local slot = 1
    for _, key in ipairs(list) do
        if not placed[key] then
            while slot <= capacity and result[slot] do slot = slot + 1 end
            if slot > capacity then break end
            result[slot] = key
            placed[key] = true
        end
    end
    return result
end

-- ---------------------------------------------------------------------------------------------
-- What the player has
-- ---------------------------------------------------------------------------------------------

local function Info(itemID)
    local instant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if type(instant) ~= "function" then return end
    local ok, _, _, _, _, _, classID, subClassID = pcall(instant, itemID)
    if ok and type(classID) == "number" then return classID, subClassID or 0 end
end

local function MinLevel(itemID)
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    if type(get) ~= "function" then return 0 end
    local ok, _, _, _, _, minLevel = pcall(get, itemID)
    return ok and type(minLevel) == "number" and minLevel or 0
end

local function HasSpell(itemID)
    local get = C_Item and C_Item.GetItemSpell or GetItemSpell
    if type(get) ~= "function" then return false end
    local ok, name, id = pcall(get, itemID)
    return ok and (name ~= nil or id ~= nil)
end

-- The distinct items of the bags: [itemID] = how many.
local function BagItems()
    local items = {}
    local container = C_Container
    if type(container) ~= "table" or type(container.GetContainerNumSlots) ~= "function" then return items, false end
    local ready = false
    for bag = 0, 5 do
        local slots = container.GetContainerNumSlots(bag) or 0
        if slots > 0 then ready = true end
        for slot = 1, slots do
            local info = container.GetContainerItemInfo(bag, slot)
            if type(info) == "table" and type(info.itemID) == "number" then
                items[info.itemID] = (items[info.itemID] or 0) + (tonumber(info.stackCount) or 1)
            end
        end
    end
    return items, ready
end

-- The items of one kind of wheel, best first: { "item:118", ... }.
local function WantedItems(category)
    local items = BagItems()
    local entries = {}
    for itemID, count in pairs(items) do
        local classID, subClassID = Info(itemID)
        if classID then
            local kind, rank = Dynamic.Classify(classID, subClassID, (classID == QUEST or classID == MISC) and HasSpell(itemID) or false)
            if kind == category then
                entries[#entries + 1] = { key = "item:" .. itemID, id = itemID, rank = rank, level = MinLevel(itemID), count = count }
            end
        end
    end
    table.sort(entries, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.level ~= b.level then return a.level > b.level end
        if a.count ~= b.count then return a.count > b.count end
        return a.id < b.id
    end)
    local keys = {}
    for i, entry in ipairs(entries) do keys[i] = entry.key end
    return keys
end

-- The spells of the professions the character has: the two primary ones, then Cooking, Fishing and First Aid; passive ones and
-- flyouts are left out.
local function WantedProfessions()
    local keys = {}
    -- Without the profession API nothing is known: nil, and the wheel is left as it is.
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then return nil end
    local book = C_SpellBook
    if type(book) ~= "table" or type(book.GetSpellBookItemInfo) ~= "function" then return nil end
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local first, second, firstAid, fishing, cooking = GetProfessions()
    for _, index in ipairs({ first or false, second or false, cooking or false, fishing or false, firstAid or false }) do
        if index then
            local _, _, _, _, numSpells, offset = GetProfessionInfo(index)
            for i = 1, tonumber(numSpells) or 0 do
                local ok, item = pcall(book.GetSpellBookItemInfo, (tonumber(offset) or 0) + i, bank)
                if ok and type(item) == "table" and type(item.spellID) == "number" and not item.isPassive
                    and not (Enum and Enum.SpellBookItemType and item.itemType == Enum.SpellBookItemType.Flyout) then
                    keys[#keys + 1] = "spell:" .. item.spellID
                end
            end
        end
    end
    return keys
end

function Dynamic:Wanted(category)
    if category == "prof" then return WantedProfessions() end
    return WantedItems(category)
end

-- One slot of the pet action bar (1..NUM_PET_ACTION_SLOTS) as a live entry, or nil when no pet bar is active or the slot is empty.
function Dynamic.PetActionEntry(index)
    if type(index) ~= "number" or index < 1 then return nil end
    if type(PetHasActionBar) ~= "function" or not PetHasActionBar() then return nil end
    if type(GetPetActionInfo) ~= "function" then return nil end
    local ok, name, texture, isToken, isActive, _, _, spellID = pcall(GetPetActionInfo, index)
    if not ok or not name then return nil end
    local displayName = (isToken and type(_G[name]) == "string" and _G[name]) or name
    local icon = (isToken and _G[texture]) or texture
    local usable = true
    if type(GetPetActionSlotUsable) == "function" then
        local uok, u = pcall(GetPetActionSlotUsable, index)
        if uok then usable = u ~= false end
    end
    return {
        kind = "pet",
        index = index,
        name = displayName,
        rawName = name,
        isToken = isToken == true,
        icon = icon,
        isActive = isActive == true,
        usable = usable,
        spellID = type(spellID) == "number" and spellID or nil,
    }
end

-- Live list of pet commands and active pet spells (up to 12): non-empty pet bar slots first, then any extra active spells from
-- the pet spellbook that are not already on the pet bar.
function Dynamic.PetEntries()
    local entries = {}
    if type(PetHasActionBar) ~= "function" or not PetHasActionBar() then return entries end
    local seenSpellID, seenName = {}, {}
    local slots = (type(NUM_PET_ACTION_SLOTS) == "number" and NUM_PET_ACTION_SLOTS) or 10
    for i = 1, slots do
        local entry = Dynamic.PetActionEntry(i)
        if entry then
            entries[#entries + 1] = entry
            if entry.spellID then seenSpellID[entry.spellID] = true end
            if entry.name then seenName[entry.name] = true end
            if entry.rawName then seenName[entry.rawName] = true end
        end
    end
    if #entries >= CAPACITY then return entries end
    local petCount
    if C_SpellBook and type(C_SpellBook.HasPetSpells) == "function" then
        local ok, n = pcall(C_SpellBook.HasPetSpells)
        if ok and type(n) == "number" then petCount = n end
    elseif type(HasPetSpells) == "function" then
        local ok, n = pcall(HasPetSpells)
        if ok and type(n) == "number" then petCount = n end
    end
    local book = C_SpellBook
    if petCount and petCount > 0 and type(book) == "table" and type(book.GetSpellBookItemInfo) == "function" then
        local petBank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet) or 1
        local extraOrder, extraByName = {}, {}
        for i = 1, petCount do
            local ok, item = pcall(book.GetSpellBookItemInfo, i, petBank)
            if ok and type(item) == "table" and type(item.spellID) == "number"
                and not (Enum and Enum.SpellBookItemType and item.itemType == Enum.SpellBookItemType.Flyout) then
                local passive = item.isPassive
                if passive == nil and C_Spell and type(C_Spell.IsSpellPassive) == "function" then
                    local pok, p = pcall(C_Spell.IsSpellPassive, item.spellID)
                    if pok then passive = p end
                end
                if not passive then
                    local spellName = item.name
                    if (not spellName or spellName == "") and C_Spell and C_Spell.GetSpellInfo then
                        local iok, info = pcall(C_Spell.GetSpellInfo, item.spellID)
                        if iok and type(info) == "table" then spellName = info.name end
                    end
                    if spellName and spellName ~= "" and not seenSpellID[item.spellID] and not seenName[spellName] then
                        if not extraByName[spellName] then extraOrder[#extraOrder + 1] = spellName end
                        local icon = item.iconID
                        if not icon and C_Spell and C_Spell.GetSpellTexture then
                            local tok, tex = pcall(C_Spell.GetSpellTexture, item.spellID)
                            if tok then icon = tex end
                        end
                        extraByName[spellName] = { kind = "spell", id = item.spellID, name = spellName, icon = icon, usable = true }
                    end
                end
            end
        end
        for _, spellName in ipairs(extraOrder) do
            if #entries >= CAPACITY then break end
            entries[#entries + 1] = extraByName[spellName]
        end
    end
    return entries
end

-- ---------------------------------------------------------------------------------------------
-- Writing to the bars
-- ---------------------------------------------------------------------------------------------

-- What an action button holds, as a key; anything else (a macro, a mount ...) counts as foreign and is replaced.
local function KeyOf(action)
    local ok, kind, id = pcall(GetActionInfo, action)
    if not ok or not kind then return nil end
    if (kind == "item" or kind == "spell") and type(id) == "number" then return kind .. ":" .. id end
    return "other:" .. tostring(kind)
end

local function Put(action, key)
    local kind, id = key:match("^(%a+):(%d+)$")
    id = tonumber(id)
    if not kind or not id then return false end
    ClearCursor()
    if kind == "item" then
        local pick = (C_Item and C_Item.PickupItem) or PickupItem
        if pick then pcall(pick, id) end
    else
        local pick = (C_Spell and C_Spell.PickupSpell) or PickupSpell
        if pick then pcall(pick, id) end
    end
    if GetCursorInfo() == nil then return false end
    PlaceAction(action)
    ClearCursor()
    return true
end

local function Clear(action)
    PickupAction(action)
    ClearCursor()
end

-- Brings the bar of one wheel to what it should hold. Returns how many buttons were changed and the plan.
function Dynamic:Fill(wheel, wanted, budget)
    local current = {}
    for slot = 1, CAPACITY do current[slot] = KeyOf(Addon.Wheels.ActionOf(wheel, slot)) end
    local plan = Dynamic.Plan(current, wanted, CAPACITY)
    local changed = 0
    for slot = 1, CAPACITY do
        if changed >= budget then break end
        local action = Addon.Wheels.ActionOf(wheel, slot)
        if plan[slot] ~= current[slot] then
            if plan[slot] then
                if Put(action, plan[slot]) then changed = changed + 1 end
            else
                Clear(action)
                changed = changed + 1
            end
        end
    end
    return changed, plan
end

local function Enabled()
    return Addon.db and Addon.db.wheels == true and Addon.db.wheelDynamic == true
end

-- Works out and writes all the dynamic wheels. Out of combat and with nothing on the cursor only; otherwise it waits for the
-- next event (combat over, the cursor empty). Returns the report lines (for /cgp wheels dyn).
function Dynamic:Run(report)
    self.scheduled = nil
    if not Enabled() then return end
    if InCombatLockdown() or GetCursorInfo() ~= nil then
        self.dirty = true
        return
    end
    self.dirty = false
    local budget, lines, more = MAX_WRITES, {}, false
    local _, ready = BagItems()
    for wheel = 1, WHEELS do
        local category = self:CategoryOf(wheel)
        if category == "pet" then
            if Addon.Wheels and Addon.Wheels.SyncPet then Addon.Wheels:SyncPet() end
            if report then
                local entries = Dynamic.PetEntries()
                local names = {}
                for slot = 1, math.min(#entries, CAPACITY) do
                    local e = entries[slot]
                    names[#names + 1] = slot .. "=" .. (e.kind == "pet" and ("pet:" .. e.index) or ("spell:" .. tostring(e.id)))
                end
                lines[#lines + 1] = string.format("wheel %d (bar %d): pet, %d entries: %s", wheel, wheel + 3, #entries,
                    #names > 0 and table.concat(names, " ") or "nothing")
            end
        -- Bags that are not there yet (just after logging in) would make an empty wheel: wait for them.
        elseif category and (category == "prof" or ready) then
            local wanted = self:Wanted(category)
            if wanted then
                local changed, plan = self:Fill(wheel, wanted, budget)
                budget = budget - changed
                if budget <= 0 then more = true end
                if report then
                    local names = {}
                    for slot = 1, CAPACITY do
                        if plan[slot] then names[#names + 1] = slot .. "=" .. plan[slot] end
                    end
                    lines[#lines + 1] = string.format("wheel %d (bar %d): %s, %d wanted, %d changed: %s", wheel, wheel + 3, category, #wanted, changed,
                        #names > 0 and table.concat(names, " ") or "nothing")
                end
            elseif report then
                lines[#lines + 1] = string.format("wheel %d (bar %d): %s, the game does not say (left as it is)", wheel, wheel + 3, category)
            end
        end
    end
    if more then self:Request(0.5) end
    return lines
end

-- A change of the bags, the spellbook or the settings asks for a run after a moment.
function Dynamic:Request(delay)
    if not Enabled() then return end
    self.dirty = true
    if self.scheduled then return end
    self.scheduled = true
    local wait = delay or DELAY
    if C_Timer and C_Timer.After then
        C_Timer.After(wait, function() self:Run() end)
    else
        self:Run()
    end
end

-- /cgp wheels dyn: runs it now and says what each dynamic wheel holds.
function Dynamic:Report()
    if not Enabled() then
        Addon:Print("dynamic wheels: off (turn on the wheels and \"Dynamic wheels\" on the Controls tab)")
        return
    end
    if InCombatLockdown() or GetCursorInfo() ~= nil then
        Addon:Print("dynamic wheels: not now (combat, or something is on the cursor)")
        return
    end
    local lines = self:Run(true) or {}
    if #lines == 0 then Addon:Print("dynamic wheels: no wheel is set to a kind (Controls tab)") end
    for _, line in ipairs(lines) do Addon:Print("dynamic " .. line) end
end

function Dynamic:Observe()
    if self.frame then return end
    local frame = CreateFrame("Frame")
    self.frame = frame
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "SPELLS_CHANGED", "SKILL_LINES_CHANGED", "PLAYER_REGEN_ENABLED",
        "CURSOR_CHANGED", "ITEM_DATA_LOAD_RESULT", "PLAYER_ENTERING_WORLD", "PET_BAR_UPDATE", "UNIT_PET", "PET_UI_UPDATE" }) do
        pcall(frame.RegisterEvent, frame, event)
    end
    frame:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_PET" and unit ~= "player" then return end
        -- The cursor is only interesting when a run was held back by it.
        if event == "CURSOR_CHANGED" and not (self.dirty and GetCursorInfo() == nil) then return end
        self:Request(event == "PLAYER_ENTERING_WORLD" and 3 or nil)
    end)
    self:Request(3)
end
