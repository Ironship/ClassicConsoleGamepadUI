local _, Addon = ...
-- The word list behind the predictive (T9) layout of the on-screen keyboard. It ships only a few dozen common
-- words per language and learns the rest, in the language the player actually uses: from chat the player
-- sees and sends, and from quest and gossip texts. Only single words and their counts are kept, in
-- ClassicConsoleGamepadUIDB.words (`/cgp keyboard forget` clears them).
local Words = { size = 0 }
Addon.Words = Words

local MAX_WORDS, KEEP_WORDS, MAX_LENGTH = 6000, 4500, 24

local DIGIT = {
    a = "2", b = "2", c = "2", d = "3", e = "3", f = "3", g = "4", h = "4", i = "4", j = "5", k = "5", l = "5",
    m = "6", n = "6", o = "6", p = "7", q = "7", r = "7", s = "7", t = "8", u = "8", v = "8", w = "9", x = "9",
    y = "9", z = "9",
    ["ä"] = "2", ["ö"] = "6", ["ü"] = "8", ["ß"] = "7",
    ["ą"] = "2", ["ć"] = "2", ["ę"] = "3", ["ł"] = "5", ["ń"] = "6", ["ó"] = "6", ["ś"] = "7", ["ź"] = "9", ["ż"] = "9",
}

local LOWER = {
    ["Ä"] = "ä", ["Ö"] = "ö", ["Ü"] = "ü", ["Ą"] = "ą", ["Ć"] = "ć", ["Ę"] = "ę", ["Ł"] = "ł", ["Ń"] = "ń",
    ["Ó"] = "ó", ["Ś"] = "ś", ["Ź"] = "ź", ["Ż"] = "ż",
}

local SEEDS = {
    "a i the and you for that with this have are not but what all can your was will just they get out how now "
        .. "here there who when good thanks please help need group guild join run dungeon quest level going want "
        .. "anyone yes no ok hello hi bye sorry wait ready tank heal dps loot come let see one two",
    "und der die das ist nicht ich du wir ihr ein eine mit für auf ja nein danke bitte hallo hilfe suche gilde "
        .. "gruppe jemand noch auch aber wie was wer wo wann kann kannst will bin bist hab habe gut schon mal "
        .. "komm komme los warte bereit tschüss",
    "i w nie na to jest się z do że co ale jak tak czy ja ty on my wy cześć dzięki proszę pomoc gildia grupa "
        .. "ktoś szukam mogę chcę dobra dobrze hej czekaj gotowy pa już tu tam kto gdzie kiedy",
}

local CHARACTER = "[%z\1-\127\194-\244][\128-\191]*"

-- Lowercase, and the digit sequence of the word on a phone keypad; nil when it holds anything but letters.
function Words.Normalize(word)
    word = word:lower():gsub("[\195-\197][\128-\191]", function(c) return LOWER[c] end)
    local digits = {}
    for character in word:gmatch(CHARACTER) do
        local digit = DIGIT[character]
        if not digit then return end
        digits[#digits + 1] = digit
    end
    if #digits == 0 or #word > MAX_LENGTH then return end
    return word, table.concat(digits)
end

local function Readable(value)
    return type(value) == "string" and not (issecretvalue and issecretvalue(value))
end

function Words:Count(word)
    return (self.db[word] or 0) + (self.seed[word] or 0)
end

function Words:Index(word, digits)
    if self.known[word] then return end
    self.known[word] = digits
    local list = self.index[digits]
    if not list then list = {}; self.index[digits] = list end
    list[#list + 1] = word
end

function Words:Load()
    if self.index then return end
    self.index, self.known, self.seed = {}, {}, {}
    for _, seeds in ipairs(SEEDS) do
        for token in seeds:gmatch("%S+") do
            local word, digits = self.Normalize(token)
            if word then self.seed[word] = 1; self:Index(word, digits) end
        end
    end
    self.size = 0
    for word in pairs(self.db) do
        local normal, digits = self.Normalize(word)
        if normal == word then self:Index(word, digits); self.size = self.size + 1 else self.db[word] = nil end
    end
end

-- Over the limit: keep the most used words (ties keep the alphabetically first), so a list full of words that were
-- all seen more than once still shrinks, and the next message does not rebuild the whole index again.
function Words:Prune()
    local list = {}
    for word in pairs(self.db) do list[#list + 1] = word end
    local db = self.db
    table.sort(list, function(a, b)
        if db[a] ~= db[b] then return db[a] > db[b] end
        return a < b
    end)
    for i = KEEP_WORDS + 1, #list do db[list[i]] = nil end
    self.size = math.min(#list, KEEP_WORDS)
    self.index = nil
    self:Load()
end

function Words:Add(token, weight)
    local word, digits = self.Normalize(token)
    if not word or #word < 2 then return end
    if not self.db[word] then self.size = self.size + 1 end
    self.db[word] = (self.db[word] or 0) + weight
    self:Index(word, digits)
end

-- Learn every word of a text (chat line, quest text). Links and colours are removed first.
function Words:Learn(text, weight)
    -- Nothing is learned while the keyboard is turned off (the word index is not even built).
    if Addon.db and Addon.db.keyboardEnabled == false then return end
    if not self.db or not Readable(text) then return end
    self:Load()
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "")
    for token in text:gmatch("[%a\128-\255]+") do self:Add(token, weight or 1) end
    if self.size > MAX_WORDS then self:Prune() end
end

-- Words that spell the key sequence, most used first, then longer words that begin with it.
function Words:Lookup(digits, limit)
    self:Load()
    limit = limit or 5
    local function ByCount(a, b)
        local ca, cb = self:Count(a), self:Count(b)
        if ca ~= cb then return ca > cb end
        return a < b
    end
    local result, seen = {}, {}
    local exact = {}
    for i, word in ipairs(self.index[digits] or {}) do exact[i] = word end
    table.sort(exact, ByCount)
    for _, word in ipairs(exact) do
        if #result < limit then result[#result + 1] = word; seen[word] = true end
    end
    if #result < limit then
        local longer, length = {}, #digits
        for word, wordDigits in pairs(self.known) do
            if #wordDigits > length and wordDigits:sub(1, length) == digits then longer[#longer + 1] = word end
        end
        table.sort(longer, ByCount)
        for _, word in ipairs(longer) do
            if #result < limit and not seen[word] then result[#result + 1] = word end
        end
    end
    return result
end

-- Words that begin with the letters typed so far (longer than the prefix), most used first.
function Words:Prefix(prefix, limit)
    self:Load()
    local word = self.Normalize(prefix)
    if not word then return {} end
    local found = {}
    for known in pairs(self.known) do
        if #known > #word and known:sub(1, #word) == word then found[#found + 1] = known end
    end
    table.sort(found, function(a, b)
        local ca, cb = self:Count(a), self:Count(b)
        if ca ~= cb then return ca > cb end
        return a < b
    end)
    for i = #found, (limit or 5) + 1, -1 do found[i] = nil end
    return found
end

-- Nothing matches: the first letter of each key (2 = a, 3 = d, ...), to show the keys were taken.
function Words.Fallback(digits)
    local first = { ["2"] = "a", ["3"] = "d", ["4"] = "g", ["5"] = "j", ["6"] = "m", ["7"] = "p", ["8"] = "t", ["9"] = "w" }
    return (digits:gsub(".", function(d) return first[d] or "" end))
end

function Words:Forget()
    if self.db then wipe(self.db) end
    self.index, self.size = nil, 0
end

function Words:Observe()
    if type(Addon.db.words) ~= "table" then Addon.db.words = {} end
    self.db = Addon.db.words
    local frame = CreateFrame("Frame")
    local events = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY",
        "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT",
        "CHAT_MSG_WHISPER", "CHAT_MSG_CHANNEL", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "GOSSIP_SHOW" }
    for _, event in ipairs(events) do pcall(frame.RegisterEvent, frame, event) end
    frame:SetScript("OnEvent", function(_, event, text)
        local ok = pcall(function()
            if event:find("^CHAT_MSG") then
                self:Learn(text, 1)
            elseif event == "QUEST_DETAIL" then
                self:Learn(GetQuestText and GetQuestText(), 1)
                self:Learn(GetObjectiveText and GetObjectiveText(), 1)
            elseif event == "QUEST_PROGRESS" then
                self:Learn(GetProgressText and GetProgressText(), 1)
            elseif event == "QUEST_COMPLETE" then
                self:Learn(GetRewardText and GetRewardText(), 1)
            elseif event == "GOSSIP_SHOW" then
                self:Learn(C_GossipInfo and C_GossipInfo.GetText and C_GossipInfo.GetText(), 1)
            end
        end)
        if not ok then Addon:Trace("Words: " .. event .. " failed") end
    end)
    -- What the player sends counts more than what they read.
    local owner, name = _G, "SendChatMessage"
    if C_ChatInfo and C_ChatInfo.SendChatMessage then owner = C_ChatInfo end
    if owner[name] or owner == C_ChatInfo then
        pcall(hooksecurefunc, owner, "SendChatMessage", function(text) pcall(self.Learn, self, text, 3) end)
    end
end
