local _, Addon = ...
-- Reads the word lists of WordHunterWoW add-ons for the keyboard's suggestions, when they are installed:
--   English: the quest texts of English Quest Panel (WordHunterWoW-ENPanel). Every word is counted, so the common ones
--            rank first and the rare names last.
--   German, French, Spanish, Italian, Portuguese: the dictionary a WordHunterWoW dictionary add-on registered with the base
--            add-on (WordHunterWoW_Addon.DictionaryProviders). It has the words but no counts.
-- Nothing in those add-ons is changed or loaded here: only what the game has loaded already is read, a few
-- milliseconds per frame (and not in combat), so no frame takes long. The result is a Lexicon that Words consults after
-- the player's own words and the common ones.
local Languages = Addon.Languages
local Sources = { lexicons = {}, failed = {} }
Addon.WordSources = Sources

local CHARACTER = Languages.CHARACTER
local FIRST_CHARACTER = "^" .. CHARACTER
local DIGIT = Languages.DIGIT
local LN2 = math.log(2)
local byte = string.byte

local BUDGET_MS = 3     -- reading time per frame
local TOP = 60          -- words kept per first key and first letter, for the short sequences
local MIN_COUNT = 2     -- a word seen once in the quest texts is a name or a typo

-- ---------------------------------------------------------------------------------------------
-- The lexicon: words in buckets by their first three keys (a word of two letters by its two), so a lookup only
-- looks through the words that can match.
-- ---------------------------------------------------------------------------------------------

local Lexicon = {}
Lexicon.__index = Lexicon

-- Byte of an ASCII letter -> byte of its key; the letters as text -> the key.
local BYTE_DIGIT, ASCII_DIGIT = {}, {}
for letter, digit in pairs(DIGIT) do
    if #letter == 1 then
        BYTE_DIGIT[byte(letter)] = byte(digit)
        ASCII_DIGIT[letter] = digit
    end
end

local function NewLexicon(source)
    return setmetatable({ source = source, score = {}, ascii = {}, accented = {}, topDigit = {}, topLetter = {},
        size = 0, weighted = false, done = false }, Lexicon)
end

-- Best first: the higher score, then the shorter word, then alphabetical.
local function Before(wordA, scoreA, wordB, scoreB)
    if scoreA ~= scoreB then return scoreA > scoreB end
    if #wordA ~= #wordB then return #wordA < #wordB end
    return wordA < wordB
end

local function NewList() return { w = {}, s = {} } end

-- Keeps the `keep` best words offered to a list.
local function Offer(list, word, score, keep)
    local words, scores = list.w, list.s
    local n = #words
    if n >= keep and not Before(word, score, words[n], scores[n]) then return end
    local i = n
    while i >= 1 and Before(word, score, words[i], scores[i]) do i = i - 1 end
    table.insert(words, i + 1, word)
    table.insert(scores, i + 1, score)
    if #words > keep then
        words[#words] = nil
        scores[#scores] = nil
    end
end

-- Adds a lowercase word of letters with its key sequence; score 0 = no count known.
function Lexicon:Add(word, digits, score)
    if #digits < 2 then return end
    local buckets = word:find("[\128-\255]") and self.accented or self.ascii
    local key = digits:sub(1, 3)
    local bucket = buckets[key]
    if not bucket then bucket = {}; buckets[key] = bucket end
    bucket[#bucket + 1] = word
    self.size = self.size + 1
    if score > 0 then
        self.weighted = true
        self.score[word] = score
        local first = digits:sub(1, 1)
        local top = self.topDigit[first]
        if not top then top = NewList(); self.topDigit[first] = top end
        Offer(top, word, score, TOP)
        local letter = word:match(FIRST_CHARACTER)
        top = self.topLetter[letter]
        if not top then top = NewList(); self.topLetter[letter] = top end
        Offer(top, word, score, TOP)
    end
end

-- The key sequence of a word with accents.
local function DigitsOf(word)
    local keys = {}
    for character in word:gmatch(CHARACTER) do keys[#keys + 1] = DIGIT[character] or "?" end
    return table.concat(keys)
end

-- The buckets that can hold a word whose first keys are `digits` (two or more): one bucket for three keys or more, else
-- the words of exactly those two keys and the buckets of every third key.
local NEXT_KEYS = { "2", "3", "4", "5", "6", "7", "8", "9" }

local function Candidates(buckets, digits)
    local found = {}
    if #digits >= 3 then
        found[1] = buckets[digits:sub(1, 3)]
        return found
    end
    found[1] = buckets[digits]
    for _, key in ipairs(NEXT_KEYS) do found[#found + 1] = buckets[digits .. key] end
    return found
end

-- Words that spell the sequence, and longer ones that begin with it: the `keep` best of each, best first.
function Lexicon:Digits(digits, keep)
    local exact, longer = NewList(), NewList()
    local n = #digits
    if n == 1 then
        local top = self.topDigit[digits]
        if top then
            for i, word in ipairs(top.w) do Offer(longer, word, top.s[i], keep) end
        end
        return exact.w, longer.w
    end
    -- Without counts the shortest sequences would only suggest the first words of the alphabet.
    if not self.weighted and n < 3 then return exact.w, longer.w end
    local score = self.score
    local want = { byte(digits, 1, n) }
    for _, bucket in ipairs(Candidates(self.ascii, digits)) do
        for i = 1, #bucket do
            local word = bucket[i]
            -- The bucket has the first three keys right; the rest is compared letter by letter.
            local same = true
            for k = 4, n do
                if BYTE_DIGIT[byte(word, k)] ~= want[k] then same = false; break end
            end
            if same then
                local length = #word
                if length == n then
                    Offer(exact, word, score[word] or 0, keep)
                elseif length > n then
                    Offer(longer, word, score[word] or 0, keep)
                end
            end
        end
    end
    for _, bucket in ipairs(Candidates(self.accented, digits)) do
        for i = 1, #bucket do
            local word = bucket[i]
            local wordDigits = DigitsOf(word)
            if wordDigits == digits then
                Offer(exact, word, score[word] or 0, keep)
            elseif #wordDigits > n and wordDigits:sub(1, n) == digits then
                Offer(longer, word, score[word] or 0, keep)
            end
        end
    end
    return exact.w, longer.w
end

-- Words that begin with the (lowercase) letters, longer than them: the `keep` best, best first.
function Lexicon:Prefix(prefix, keep)
    local found, score = NewList(), self.score
    local letters = Languages.Characters(prefix)
    local count = #letters
    if count == 1 then
        local top = self.topLetter[prefix]
        if top then
            for i, word in ipairs(top.w) do Offer(found, word, top.s[i], keep) end
        end
        return found.w
    end
    if count < 2 or (not self.weighted and count < 3) then return found.w end
    local digits = ""
    for i = 1, math.min(count, 3) do
        local key = DIGIT[letters[i]]
        if not key then return found.w end
        digits = digits .. key
    end
    local length = #prefix
    for _, buckets in ipairs({ self.ascii, self.accented }) do
        for _, bucket in ipairs(Candidates(buckets, digits)) do
            for i = 1, #bucket do
                local word = bucket[i]
                if #word > length and word:sub(1, length) == prefix then
                    Offer(found, word, score[word] or 0, keep)
                end
            end
        end
    end
    return found.w
end

-- ---------------------------------------------------------------------------------------------
-- Reading the sources, a little at a time
-- ---------------------------------------------------------------------------------------------

-- What a word seen `count` times is worth: 2 times -> 2, 1000 -> 19, 80000 and more -> 31.
local function Weight(count)
    return math.min(31, math.floor(2 * math.log(count) / LN2))
end

local QUEST_FIELDS = { "title", "description", "objectives", "progress", "completion" }

-- English Quest Panel: count the words of every quest text (WordHunterWoW_QuestEN[id] = { title, description, ... }).
-- Only words of plain letters count (no contractions, no accents). A word that is never written with a small first letter
-- is a name (Gelkis, Orgrimmar) and is worth a little less than a word with the same count.
local PACK = 1048576        -- the count of lowercase sightings is kept above this, the total below it
local NAME_PENALTY = 6

local function ScanQuests(lexicon, tick, language, source)
    local quests = source.quests
    local counts = {}
    for _, quest in pairs(quests) do
        if type(quest) == "table" then
            for _, field in ipairs(QUEST_FIELDS) do
                local text = quest[field]
                if type(text) == "string" then
                    for token in text:gmatch("[A-Za-z\128-\255']+") do
                        if not token:find("[\128-\255']") then
                            local word = token:lower()
                            counts[word] = (counts[word] or 0) + (byte(token) >= 97 and PACK + 1 or 1)
                        end
                    end
                end
            end
        end
        tick()
    end
    local n = 0
    for word, packed in pairs(counts) do
        local total, written = packed % PACK, math.floor(packed / PACK)
        if total >= MIN_COUNT and #word >= 2 then
            local weight = Weight(total)
            if written == 0 then weight = math.max(1, weight - NAME_PENALTY) end
            lexicon:Add(word, (word:gsub("[a-z]", ASCII_DIGIT)), weight)
        end
        n = n + 1
        if n % 100 == 0 then tick() end
    end
end

-- A dictionary add-on: the keys of its entries are the words, lowercase; entries marked "ignored" are names.
local function ScanDictionary(lexicon, tick, language, source)
    local seen = #source.entries > 1 and {} or nil
    for _, entries in ipairs(source.entries) do
        local n = 0
        for key, entry in pairs(entries) do
            if type(key) == "string" and #key >= 2 and #key <= 24 and (type(entry) ~= "table" or entry.status ~= "ignored") then
                local word, digits
                if key:find("^[a-z]+$") then
                    word, digits = key, (key:gsub("[a-z]", ASCII_DIGIT))
                else
                    word, digits = Addon.Words.Normalize(key)
                end
                if word and not (seen and seen[word]) and Languages.Fits(language, word) then
                    if seen then seen[word] = true end
                    lexicon:Add(word, digits, 0)
                end
            end
            n = n + 1
            if n % 128 == 0 then tick() end
        end
    end
end

-- Which source can serve a language right now: { id, scan, ... } or nil. Looked at again every time, because a dictionary
-- may register later than the game's start.
function Sources:Find(language)
    if language == "EN" then
        local quests = _G.WordHunterWoW_QuestEN
        if type(quests) == "table" and next(quests) ~= nil then
            return { id = "enpanel", scan = ScanQuests, quests = quests }
        end
        return nil
    end
    local locales = Languages[language].locales
    local base = _G.WordHunterWoW_Addon
    if not locales or type(base) ~= "table" or type(base.DictionaryProviders) ~= "table" then return nil end
    local entries = {}
    for _, locale in ipairs(locales) do
        local byId = base.DictionaryProviders[locale]
        local order = type(base.DictionaryProviderOrder) == "table" and base.DictionaryProviderOrder[locale]
        if type(byId) == "table" and type(order) == "table" then
            for _, id in ipairs(order) do
                if type(byId[id]) == "table" then entries[#entries + 1] = byId[id] end
            end
        end
    end
    if #entries == 0 then return nil end
    return { id = "dictionary", scan = ScanDictionary, entries = entries }
end

local function Now()
    if debugprofilestop then return debugprofilestop() end
    return GetTime() * 1000
end

-- Starts reading for a language if a source is there and nothing has been read yet. Cheap to call again and again.
function Sources:Request(language)
    local db = Addon.db
    if not db or db.wordHunter == false or db.keyboardEnabled == false then return end
    language = Languages.Valid(language or (Addon.Words and Addon.Words:Language()))
    if self.lexicons[language] or self.failed[language] then return end
    local source = self:Find(language)
    if not source then return end
    -- Only the language in use is kept.
    for other in pairs(self.lexicons) do
        if other ~= language then self.lexicons[other] = nil end
    end
    local lexicon = NewLexicon(source.id)
    local job = { language = language, lexicon = lexicon }
    local function tick()
        if Now() - job.started > BUDGET_MS then coroutine.yield() end
    end
    job.thread = coroutine.create(function() source.scan(lexicon, tick, language, source) end)
    job.started = Now()
    -- Lookups see what has been read so far.
    self.lexicons[language] = lexicon
    self.job = job
    if self.frame then self.frame:Show() end
end

function Sources:Lexicon(language)
    return self.lexicons[language]
end

-- One slice of reading; not in combat.
function Sources:Pump()
    local job = self.job
    if not job then
        if self.frame then self.frame:Hide() end
        return
    end
    if InCombatLockdown() then return end
    job.started = Now()
    local ok, err = coroutine.resume(job.thread)
    if not ok then
        Addon:Trace("WordSources: " .. tostring(err))
        self.failed[job.language] = tostring(err)
        self.lexicons[job.language] = nil
        self.job = nil
    elseif coroutine.status(job.thread) == "dead" then
        job.lexicon.done = true
        self.job = nil
    end
end

-- The setting was switched: off frees the lists, on reads them.
function Sources:Changed()
    if Addon.db.wordHunter == false then
        self.lexicons, self.job, self.failed = {}, nil, {}
    else
        self:Request()
    end
end

-- Forget what was read (for a fresh start).
function Sources:Reset()
    self.lexicons, self.job, self.failed = {}, nil, {}
end

-- A line for the settings: where the suggestions come from.
function Sources:Status(language)
    local L = Addon.L
    if Addon.db.wordHunter == false then return L.wordsOff end
    language = Languages.Valid(language or Addon.Words:Language())
    self:Request(language)
    local lexicon = self.lexicons[language]
    if not lexicon then return L.wordsStatus:format(L.wordsOwn) end
    local name = lexicon.source == "enpanel" and L.srcENPanel or L.srcDictionary
    local from = lexicon.done and L.wordsFrom:format(name, lexicon.size) or L.wordsReading:format(name)
    return L.wordsStatus:format(L.wordsOwn .. " + " .. from)
end

function Sources:Observe()
    local frame = CreateFrame("Frame")
    frame:Hide()
    frame:SetScript("OnUpdate", function() self:Pump() end)
    self.frame = frame
    -- A while after the game has loaded in: the data of the add-ons is there and nothing else needs the frames.
    C_Timer.After(15, function() self:Request() end)
end
