local _, Addon = ...
-- The word list behind the predictive layouts of the on-screen keyboard (Hybrid and Smart). Three layers stand behind a
-- suggestion, best first:
--   * the player's own words, learned from the chat they see and send and from quest and gossip texts: single words and
--     their counts in ClassicConsoleGamepadUIDB.words (`/cgp keyboard forget` clears them),
--   * a few hundred common words for the language the keyboard types in (Languages.lua),
--   * the word list of an installed WordHunterWoW add-on (WordSources.lua), which is only read and never changed.
-- Which words fit the keys typed so far is decided by the player's language (Addon.db.keyboardLanguage).
local Words = { size = 0 }
Addon.Words = Words
local Languages = Addon.Languages

local MAX_WORDS, KEEP_WORDS, MAX_LENGTH = 6000, 4500, 24
local CHARACTER = Languages.CHARACTER
local DIGIT = Languages.DIGIT

-- What a word is worth when suggestions are ranked: the weight its source gives it (0-31, WordSources.lua), a bonus for
-- the common words of the language, and a bonus that grows with how often the player used it (up to OWN_CAP).
local SEED_BONUS, OWN_STEP, OWN_CAP = 8, 6, 24
local LN2 = math.log(2)

-- Lowercase, and the digit sequence of the word on a phone keypad; nil when it holds anything but letters.
function Words.Normalize(word)
    word = Languages.Lower(word)
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
    return (self.db and self.db[word] or 0) + (self.seed and self.seed[word] or 0)
end

-- The language the keyboard types in, and the words of the layers above in it.
function Words:Language()
    return Languages.Valid(Addon.db and Addon.db.keyboardLanguage)
end

function Words:Index(word, digits)
    if self.known[word] then return end
    self.known[word] = digits
    local list = self.index[digits]
    if not list then list = {}; self.index[digits] = list end
    list[#list + 1] = word
end

-- The common words and the player's own that fit the language; built again when the language changes.
function Words:Load()
    local language = self:Language()
    if self.index and self.language == language then return end
    self.language = language
    self.index, self.known, self.seed = {}, {}, {}
    for token in Languages[language].seeds:gmatch("[^ ]+") do
        local word, digits = self.Normalize(token)
        if word then self.seed[word] = 1; self:Index(word, digits) end
    end
    self.size = 0
    for word in pairs(self.db or {}) do
        local normal, digits = self.Normalize(word)
        if normal == word then
            self.size = self.size + 1
            if Languages.Fits(language, word) then self:Index(word, digits) end
        else
            self.db[word] = nil
        end
    end
end

-- The word list of a WordHunterWoW add-on for this language, when one is installed and turned on (nil otherwise).
function Words:Lexicon()
    if Addon.db and Addon.db.wordHunter == false then return nil end
    local sources = Addon.WordSources
    return sources and sources:Lexicon(self.language)
end

-- What a word is worth for suggestions: see the constants above.
function Words:Score(word, lexicon)
    local score = lexicon and lexicon.score[word] or 0
    if self.seed[word] then score = score + SEED_BONUS end
    local own = self.db and self.db[word]
    if own then score = score + math.min(OWN_CAP, math.floor(OWN_STEP * math.log(1 + own) / LN2)) end
    return score
end

-- Best first: worth, then the shorter word, then alphabetical.
function Words:Rank(list, lexicon)
    local scores = {}
    for _, word in ipairs(list) do scores[word] = self:Score(word, lexicon) end
    table.sort(list, function(a, b)
        if scores[a] ~= scores[b] then return scores[a] > scores[b] end
        if #a ~= #b then return #a < #b end
        return a < b
    end)
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
    if Languages.Fits(self.language, word) then self:Index(word, digits) end
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

-- Words that spell the key sequence, best first, then longer words that begin with it. `limit` suggestions at most.
function Words:Lookup(digits, limit)
    self:Load()
    limit = limit or 5
    local length, seen = #digits, {}
    local exact, longer = {}, {}
    for _, word in ipairs(self.index[digits] or {}) do
        seen[word] = true
        exact[#exact + 1] = word
    end
    for word, wordDigits in pairs(self.known) do
        if #wordDigits > length and wordDigits:sub(1, length) == digits then
            seen[word] = true
            longer[#longer + 1] = word
        end
    end
    local lexicon = self:Lexicon()
    if lexicon then
        local more, beyond = lexicon:Digits(digits, limit * 3)
        for _, word in ipairs(more) do
            if not seen[word] then seen[word] = true; exact[#exact + 1] = word end
        end
        for _, word in ipairs(beyond) do
            if not seen[word] then seen[word] = true; longer[#longer + 1] = word end
        end
    end
    local result = {}
    for _, list in ipairs({ exact, longer }) do
        self:Rank(list, lexicon)
        for _, word in ipairs(list) do
            if #result < limit then result[#result + 1] = word end
        end
    end
    return result
end

-- Words that begin with the letters typed so far (longer than the prefix), best first.
function Words:Prefix(prefix, limit)
    self:Load()
    limit = limit or 5
    local word = self.Normalize(prefix)
    if not word then return {} end
    local found, seen = {}, {}
    for known in pairs(self.known) do
        if #known > #word and known:sub(1, #word) == word then
            seen[known] = true
            found[#found + 1] = known
        end
    end
    local lexicon = self:Lexicon()
    if lexicon then
        for _, known in ipairs(lexicon:Prefix(word, limit * 3)) do
            if not seen[known] then seen[known] = true; found[#found + 1] = known end
        end
    end
    self:Rank(found, lexicon)
    for i = #found, limit + 1, -1 do found[i] = nil end
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
