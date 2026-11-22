local _, Addon = ...
-- Quiet: silences the game's item sounds for a player who hears them as noise.
--
-- Bags being sorted, items being picked up and put down, spell icons being picked up and dropped on a bar: the game plays a sound
-- file for each, and keeps one list of muted files (MuteSoundFile / UnmuteSoundFile take the file's data ID). A muted file is silent
-- whoever asks for it, the game itself or another addon, and it stays muted until somebody unmutes it (a /reload does not).
-- The files, by their paths in the game's file list:
--   sort  sound/interface/ui_bagsorting_01.ogg, SOUNDKIT.UI_BAG_SORTING_01: played by the bag sort buttons (the game's own and the
--         L3 sort of ImprovedForever)
--   icon  sound/interface/uspelliconpickup.ogg and uspellicondrop.ogg: a spell icon picked up and put down on a bar
--   item  sound/interface/pickup/pickup*.ogg and putdown*.ogg, a pair for each kind of material (cloth, metal, herb, gems ...): an item
--         picked up or put down (the files Baganator mutes while it sorts the bags)
-- Two things mute them: the setting "muteItemSounds" (all three groups, all the time) and the dynamic wheels, which hold the item and
-- icon groups for half a second around every write to a bar (every write picks a thing up and puts it down, with these sounds;
-- setting "quietDynamic").
--   /cgp sound              what is muted
--   /cgp sound on | off     "muteItemSounds" from the chat
--   /cgp sound test         plays one file of each kind, so one can hear whether it is muted
--   /cgp sound listen [s]   for some seconds, notes who asks for a sound and who moves things on the bars and in the bags
local Quiet = {}
Addon.Quiet = Quiet

local SORT = { 1045703 }
local ICON = { 567489, 567524 }
local ITEM = {}
for file = 567542, 567577 do ITEM[#ITEM + 1] = file end
local ALL = { SORT, ICON, ITEM }

-- What each reason for muting holds.
local REASON = { always = ALL, dynamic = { ICON, ITEM } }
-- How long after the last write of a dynamic wheel its sounds stay muted (the game may start a sound a moment after the call).
local HOLD = 0.5

-- Quiet.holds: the reasons that are muting now. Quiet.muted: the files this addon has muted and not unmuted again.
Quiet.holds, Quiet.muted = {}, {}
Quiet.windows = 0

local function Available()
    return type(MuteSoundFile) == "function" and type(UnmuteSoundFile) == "function"
end
Quiet.Available = Available

-- Mutes what the holds ask for and unmutes what nothing asks for any more.
function Quiet:Refresh()
    if not Available() then return end
    local want = {}
    for reason in pairs(self.holds) do
        for _, group in ipairs(REASON[reason]) do
            for _, file in ipairs(group) do want[file] = true end
        end
    end
    local muted = self.muted
    for file in pairs(want) do
        if not muted[file] then
            muted[file] = true
            pcall(MuteSoundFile, file)
        end
    end
    for file in pairs(muted) do
        if not want[file] then
            -- (forgotten first: the guard below puts back a mute that somebody else ended, not this one)
            muted[file] = nil
            pcall(UnmuteSoundFile, file)
        end
    end
end

-- Another addon that unmutes one of these files (Baganator does after every sort of the bags) would end a standing mute for good:
-- its call is answered with a mute again.
local function GuardUnmute()
    if Quiet.guarded or type(hooksecurefunc) ~= "function" then return end
    Quiet.guarded = pcall(hooksecurefunc, "UnmuteSoundFile", function(file)
        if Quiet.holds.always and Quiet.muted[file] then pcall(MuteSoundFile, file) end
    end)
end

-- Brings the muting in line with the setting "muteItemSounds".
function Quiet:Apply()
    local db = Addon.db
    if not db or not Available() then return end
    if db.muteItemSounds == true then
        self.holds.always = true
        GuardUnmute()
    else
        self.holds.always = nil
    end
    self:Refresh()
end

-- A dynamic wheel is about to write to a bar: the sounds of the write are muted until HOLD seconds after the last one. Does nothing
-- when the player turned that off ("quietDynamic").
function Quiet:Writing()
    local db = Addon.db
    if not db or db.quietDynamic == false or not Available() then return end
    self.releaseAt = GetTime() + HOLD
    if not self.holds.dynamic then
        self.holds.dynamic = true
        self.windows = self.windows + 1
        -- If the game is left while the files are muted they stay muted: the next start of the addon puts that right (Observe).
        db.quietStale = true
        self:Refresh()
    end
    if self.watching then return end
    self.watching = true
    local function Check()
        local left = (self.releaseAt or 0) - GetTime()
        if left > 0.01 then
            C_Timer.After(left, Check)
            return
        end
        self.watching = nil
        self.holds.dynamic = nil
        self:Refresh()
        if Addon.db then Addon.db.quietStale = nil end
    end
    C_Timer.After(HOLD, Check)
end

function Quiet:Changed(key)
    if key == "muteItemSounds" then self:Apply() end
end

function Quiet:Observe()
    local db = Addon.db
    if not Available() then
        if db and db.muteItemSounds == true then
            Addon:Print("mute item sounds: this client has no MuteSoundFile, so nothing is muted")
        end
        return
    end
    if db.quietStale then
        -- A reload or a logout came while a dynamic wheel's sounds were muted: the game kept them muted.
        for _, group in ipairs(ALL) do
            for _, file in ipairs(group) do pcall(UnmuteSoundFile, file) end
        end
        db.quietStale = nil
    end
    self:Apply()
end

-- ---------------------------------------------------------------------------------------------
-- /cgp sound
-- ---------------------------------------------------------------------------------------------

function Quiet:Status()
    local db = Addon.db
    local count = 0
    for _ in pairs(self.muted) do count = count + 1 end
    Addon:Print(string.format("sound: MuteSoundFile %s; mute item sounds (all the time) %s; quiet dynamic wheels %s",
        Available() and "is there" or "is MISSING on this client", db.muteItemSounds and "ON" or "off", db.quietDynamic ~= false and "ON" or "off"))
    Addon:Print(string.format("sound: %d of %d files muted by this addon right now; the dynamic wheels' writes were silenced %d times since the addon loaded",
        count, #SORT + #ICON + #ITEM, self.windows))
    Addon:Print("sound: /cgp sound on | off (all the time), /cgp sound test (plays the files), /cgp sound listen [seconds] (who asks for sounds)")
end

local TEST = {
    { 1045703, "bag sorting" },
    { 567565, "item picked up (cloth, leather)" },
    { 567571, "item put down (cloth, leather)" },
    { 567489, "spell icon picked up" },
    { 567524, "spell icon dropped" },
}

function Quiet:Test()
    if type(PlaySoundFile) ~= "function" then
        Addon:Print("sound test: this client has no PlaySoundFile")
        return
    end
    Addon:Print("sound test: five sounds, one every 1.2 seconds; a muted one is silent")
    for index, entry in ipairs(TEST) do
        C_Timer.After((index - 1) * 1.2, function()
            Addon:Print(string.format("  %d/%d %s (file %d): %s", index, #TEST, entry[2], entry[1],
                self.muted[entry[1]] and "muted" or "audible"))
            pcall(PlaySoundFile, entry[1], "SFX")
        end)
    end
end

-- ---------------------------------------------------------------------------------------------
-- /cgp sound listen: who asks for sounds, and who moves things on the bars and in the bags
-- ---------------------------------------------------------------------------------------------

local EVENTS = { "ACTIONBAR_SLOT_CHANGED", "ITEM_LOCK_CHANGED", "BAG_UPDATE_DELAYED", "CURSOR_CHANGED" }

-- The calls that are noted while listening: { the function, the table it lives in (nil: a global) }.
local CALLS = {
    { "PlaySound" }, { "PlaySoundFile" }, { "PlaceAction" }, { "PickupAction" },
    { "PickupItem", "C_Item" }, { "PickupSpell", "C_Spell" },
    { "SortBags", "C_Container" }, { "SortBank", "C_Container" }, { "PickupContainerItem", "C_Container" },
    { "UseContainerItem", "C_Container" }, { "SplitContainerItem", "C_Container" },
}

local function Plain(value)
    return type(value) == "number" and not (issecretvalue and issecretvalue(value))
end

local function SoundName(id)
    if not Quiet.soundNames then
        Quiet.soundNames = {}
        if type(SOUNDKIT) == "table" then
            for name, value in pairs(SOUNDKIT) do
                if type(value) == "number" then Quiet.soundNames[value] = name end
            end
        end
    end
    return Quiet.soundNames[id]
end

-- The first line of the call stack that is in an addon's file (this one excluded): "Addon/File.lua:123".
local function Caller()
    local ok, stack = pcall(debugstack, 2, 10, 0)
    if ok and type(stack) == "string" then
        for line in stack:gmatch("[^\n]+") do
            local addon, where = line:match("AddOns[/\\]([^/\\]+)[/\\]([^:]+:%d+)")
            if addon and where and not where:find("^Quiet%.lua") then return addon .. "/" .. where end
        end
    end
    return "?"
end

local function Note(name, arg)
    local session = Quiet.session
    if not session then return end
    local label = name
    if (name == "PlaySound" or name == "PlaySoundFile") and Plain(arg) then
        local kit = name == "PlaySound" and SoundName(arg)
        label = string.format("%s %d%s", name, arg, kit and (" " .. kit) or "")
    end
    local who = Caller()
    local key = label .. " <- " .. who
    local row = session.rows[key]
    if not row then
        if #session.order >= 120 then return end
        row = { n = 0, label = label, who = who }
        session.rows[key] = row
        session.order[#session.order + 1] = key
    end
    row.n = row.n + 1
    if (name == "PlaceAction" or name == "PickupAction") and Plain(arg) then
        row.low = math.min(row.low or arg, arg)
        row.high = math.max(row.high or arg, arg)
    end
end

-- Installed on the first listen and left in place (a hook cannot be taken off); it does nothing while nobody listens.
function Quiet:HookCalls()
    if self.hooked or type(hooksecurefunc) ~= "function" then return end
    self.hooked = true
    for _, call in ipairs(CALLS) do
        local name, ownerName = call[1], call[2]
        local owner = ownerName and _G[ownerName] or nil
        local target = ownerName and owner or _G
        if type(target) == "table" and type(target[name]) == "function" then
            local function Hook(arg) pcall(Note, name, arg) end
            if owner then pcall(hooksecurefunc, owner, name, Hook) else pcall(hooksecurefunc, name, Hook) end
        end
    end
end

function Quiet:Listen(seconds)
    if self.session then
        Addon:Print("sound listen: already listening")
        return
    end
    seconds = math.max(3, math.min(tonumber(seconds) or 15, 120))
    self:HookCalls()
    local stats = Addon.Dynamic and Addon.Dynamic.stats or {}
    self.session = { rows = {}, order = {}, events = {}, startedAt = GetTime(), runs = stats.runs or 0, writes = stats.writes or 0 }
    if not self.frame then
        local frame = CreateFrame("Frame")
        self.frame = frame
        frame:SetScript("OnEvent", function(_, event, slot)
            local session = Quiet.session
            if not session then return end
            session.events[event] = (session.events[event] or 0) + 1
            if event == "ACTIONBAR_SLOT_CHANGED" and Plain(slot) then
                session.low = math.min(session.low or slot, slot)
                session.high = math.max(session.high or slot, slot)
            end
        end)
    end
    for _, event in ipairs(EVENTS) do pcall(self.frame.RegisterEvent, self.frame, event) end
    Addon:Print(string.format("sound listen: %d seconds. Wait for the noise (or make it); the lines come when the time is up.", seconds))
    C_Timer.After(seconds, function() Quiet:Report() end)
end

function Quiet:Report()
    local session = self.session
    if not session then return end
    self.session = nil
    for _, event in ipairs(EVENTS) do pcall(self.frame.UnregisterEvent, self.frame, event) end
    local parts = {}
    for _, event in ipairs(EVENTS) do
        local n = session.events[event] or 0
        local extra = (event == "ACTIONBAR_SLOT_CHANGED" and n > 0 and session.low) and string.format(" (slots %d-%d)", session.low, session.high) or ""
        parts[#parts + 1] = event .. " " .. n .. extra
    end
    Addon:Print(string.format("sound listen: %.0f s. Events: %s", GetTime() - session.startedAt, table.concat(parts, ", ")))
    local stats = Addon.Dynamic and Addon.Dynamic.stats
    if stats then
        Addon:Print(string.format("  the dynamic wheels in that time: %d runs, %d writes", stats.runs - session.runs, stats.writes - session.writes))
    end
    Addon:Print(string.format("  muted now: all the time %s, dynamic wheels' window %s", self.holds.always and "yes" or "no", self.holds.dynamic and "open" or "closed"))
    local rows = session.rows
    table.sort(session.order, function(a, b) return rows[a].n > rows[b].n end)
    if #session.order == 0 then
        Addon:Print("  no sound and no bar or bag call came from Lua. If the noise was there anyway, the game makes it itself.")
    end
    for index = 1, math.min(#session.order, 14) do
        local row = rows[session.order[index]]
        local slots = ""
        if row.low then slots = row.low == row.high and string.format(" (slot %d)", row.low) or string.format(" (slots %d-%d)", row.low, row.high) end
        Addon:Print(string.format("  %dx %s%s  <- %s", row.n, row.label, slots, row.who))
    end
end

function Quiet:Command(text)
    local word, rest = (text or ""):match("^(%S*)%s*(.-)%s*$")
    if word == "on" or word == "off" then
        Addon.db.muteItemSounds = word == "on"
        self:Apply()
        Addon:Print(word == "on" and "mute item sounds: on (the bag sorting, item pick-up and put-down and spell icon sounds are silent)"
            or "mute item sounds: off")
    elseif word == "test" then
        self:Test()
    elseif word == "listen" then
        self:Listen(rest)
    else
        self:Status()
    end
end
