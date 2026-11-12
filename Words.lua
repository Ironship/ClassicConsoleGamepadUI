local _, Addon = ...
-- The word list behind the predictive layouts of the on-screen keyboard (Hybrid and Smart) and the suggestions of the full
-- keyboard. Four layers stand behind a suggestion, best first:
--   * the player's own words: what they send and what they accept from the suggestions, so the suggestions come to fit the
--     way they write. Kept per language of the keyboard: ClassicConsoleGamepadUIDB.own[language][word] = times used.
--   * the words of the chat they read and of quest and gossip texts, but only while the keyboard types the language of the
--     game, which is the language of those texts: ClassicConsoleGamepadUIDB.seen[language][word] = times seen. (One list
--     for all languages let the quest texts of a German game fill the suggestions of a Polish keyboard.)
--   * a few hundred common words for the language the keyboard types in (Languages.lua),
--   * the word list of an installed WordHunterWoW add-on (WordSources.lua), which is only read and never changed.
-- Only single words and their counts are kept, never sentences. `/cgp keyboard forget` and the button in the settings clear
-- all of it.
local Words = { sizes = { own = 0, seen = 0 } }
Addon.Words = Words
local Languages = Addon.Languages

local MAX_LENGTH = 24
local CHARACTER = Languages.CHARACTER
local DIGIT = Languages.DIGIT
-- How many words are kept: past `max` the `keep` most used stay.
local LIMITS = { own = { max = 3000, keep = 2500 }, seen = { max = 6000, keep = 4500 } }

-- What a word is worth when suggestions are ranked: the weight its source gives it (0-31, WordSources.lua), a bonus for the
-- common words of the language, and bonuses that grow with how often the player used the word (up to 30) and saw it (up to
-- 12). A word of the player's own that was used a few times comes before most words of a word list.
local SEED_BONUS = 8
local OWN_STEP, OWN_CAP = 8, 30
local SEEN_STEP, SEEN_CAP = 4, 12
local LN2 = math.log(2)

-- The keyboard language the game's own language corresponds to.
local CLIENT = { enUS = "EN", enGB = "EN", deDE = "DE", frFR = "FR", esES = "ES", esMX = "ES", itIT = "IT", ptBR = "PT" }
function Words.ClientLanguage()
    return CLIENT[GetLocale and GetLocale() or "enUS"] or "EN"
end

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

-- Nothing is learned while the keyboard is turned off.
local function Active()
    return Addon.db ~= nil and Addon.db.keyboardEnabled ~= false
end

-- The table of one kind ("own", "seen") for one language, made when it is not there yet.
local function Bucket(kind, language)
    local db = Addon.db
    if type(db[kind]) ~= "table" then db[kind] = {} end
    if type(db[kind][language]) ~= "table" then db[kind][language] = {} end
    return db[kind][language]
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

-- The common words and the player's words that fit the language; built again when the language changes.
function Words:Load()
    local language = self:Language()
    if self.index and self.language == language then return end
    self.language = language
    self.index, self.known, self.seed = {}, {}, {}
    for token in Languages[language].seeds:gmatch("[^ ]+") do
        local word, digits = self.Normalize(token)
        if word then self.seed[word] = 1; self:Index(word, digits) end
    end
    self.own, self.seen = {}, {}
    if Addon.db then self.own, self.seen = Bucket("own", language), Bucket("seen", language) end
    self.sizes = { own = 0, seen = 0 }
    for kind, list in pairs({ own = self.own, seen = self.seen }) do
        for word in pairs(list) do
            local normal, digits = self.Normalize(word)
            if normal == word then
                self.sizes[kind] = self.sizes[kind] + 1
                if Languages.Fits(language, word) then self:Index(word, digits) end
            else
                list[word] = nil
            end
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
    local own, seen = self.own[word], self.seen[word]
    if own then score = score + math.min(OWN_CAP, math.floor(OWN_STEP * math.log(1 + own) / LN2)) end
    if seen then score = score + math.min(SEEN_CAP, math.floor(SEEN_STEP * math.log(1 + seen) / LN2)) end
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
function Words:Prune(kind)
    local list, keep = self[kind], LIMITS[kind].keep
    local words = {}
    for word in pairs(list) do words[#words + 1] = word end
    table.sort(words, function(a, b)
        if list[a] ~= list[b] then return list[a] > list[b] end
        return a < b
    end)
    for i = keep + 1, #words do list[words[i]] = nil end
    self.index = nil
    self:Load()
end

-- The distinct words of a text, links and colours removed: a list of { lowercase word, its digit sequence }. A word counts
-- once however often a text repeats it.
local function WordsOf(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "")
    local list, done = {}, {}
    for token in text:gmatch("[%a\128-\255]+") do
        local word, digits = Words.Normalize(token)
        if word and #word >= 2 and not done[word] then
            done[word] = true
            list[#list + 1] = { word, digits }
        end
    end
    return list
end

-- Counts the words of a text once each in the list of one kind ("own" or "seen") of the keyboard's language.
function Words:Learn(kind, text)
    if not Active() or not Readable(text) then return end
    self:Load()
    local list = self[kind]
    for _, entry in ipairs(WordsOf(text)) do
        local word, digits = entry[1], entry[2]
        if not list[word] then self.sizes[kind] = self.sizes[kind] + 1 end
        list[word] = (list[word] or 0) + 1
        if Languages.Fits(self.language, word) then self:Index(word, digits) end
    end
    if self.sizes[kind] > LIMITS[kind].max then self:Prune(kind) end
end

-- Words from what the player reads (chat, quest and gossip texts). Those are in the language of the game, so they only
-- teach a keyboard that types that language.
function Words:LearnSeen(text)
    if not Active() or Languages.Valid(Addon.db.keyboardLanguage) ~= self.ClientLanguage() then return end
    self:Learn("seen", text)
end

-- Words the player accepted from the suggestions or sent: their own vocabulary, in the language of the keyboard.
function Words:LearnOwn(text)
    self:Learn("own", text)
end

-- A message that went out. Sending reaches this through the game's function and through the old global name of it, which
-- calls the first: one message counts once.
function Words:LearnSent(text)
    if not Readable(text) then return end
    local now = GetTime()
    if text == self.sent and now - self.sentAt < 1 then return end
    self.sent, self.sentAt = text, now
    self:LearnOwn(text)
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

-- Forgets everything learned, in every language.
function Words:Forget()
    local db = Addon.db
    if db then db.own, db.seen, db.words = {}, {}, nil end
    self.index, self.own, self.seen = nil, nil, nil
    self.sizes = { own = 0, seen = 0 }
end

-- How many words are learned for the language of the keyboard: the player's own, and those from chat and quest texts.
function Words:Counts()
    self:Load()
    return self.sizes.own, self.sizes.seen
end

-- One line for the settings.
function Words:Summary()
    local own, seen = self:Counts()
    return Addon.L.learnedStatus:format(Languages[self.language].name, own, seen)
end

-- Earlier versions kept one list for all languages, filled mostly with the quest and chat texts of the game's language:
-- it becomes that language's list of words seen.
function Words:Migrate()
    local db = Addon.db
    if db.words == nil then return end
    if type(db.words) == "table" then
        local list = Bucket("seen", self.ClientLanguage())
        for word, count in pairs(db.words) do
            if type(word) == "string" and type(count) == "number" then list[word] = (list[word] or 0) + count end
        end
    end
    db.words = nil
end

-- A chat line the player said themselves also comes back as an event; those words are in their own list already.
local function SaidByPlayer(guid)
    return type(guid) == "string" and not (issecretvalue and issecretvalue(guid)) and guid == UnitGUID("player")
end

function Words:Observe()
    self:Migrate()
    local frame = CreateFrame("Frame")
    local events = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY",
        "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT",
        "CHAT_MSG_WHISPER", "CHAT_MSG_CHANNEL", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "GOSSIP_SHOW" }
    for _, event in ipairs(events) do pcall(frame.RegisterEvent, frame, event) end
    frame:SetScript("OnEvent", function(_, event, text, ...)
        local guid = select(11, ...)   -- the 12th value of a chat event: the sender's GUID
        local ok = pcall(function()
            if event:find("^CHAT_MSG") then
                if not SaidByPlayer(guid) then self:LearnSeen(text) end
            elseif event == "QUEST_DETAIL" then
                self:LearnSeen(GetQuestText and GetQuestText())
                self:LearnSeen(GetObjectiveText and GetObjectiveText())
            elseif event == "QUEST_PROGRESS" then
                self:LearnSeen(GetProgressText and GetProgressText())
            elseif event == "QUEST_COMPLETE" then
                self:LearnSeen(GetRewardText and GetRewardText())
            elseif event == "GOSSIP_SHOW" then
                self:LearnSeen(C_GossipInfo and C_GossipInfo.GetText and C_GossipInfo.GetText())
            end
        end)
        if not ok then Addon:Trace("Words: " .. event .. " failed") end
    end)
    -- What the player sends is their own vocabulary, whatever way they typed it. The chat's edit box sends through
    -- C_ChatInfo.SendChatMessage (older clients: the global function of that name).
    local owner = _G
    if C_ChatInfo and C_ChatInfo.SendChatMessage then owner = C_ChatInfo end
    if owner.SendChatMessage then
        pcall(hooksecurefunc, owner, "SendChatMessage", function(text) pcall(self.LearnSent, self, text) end)
    end
end
