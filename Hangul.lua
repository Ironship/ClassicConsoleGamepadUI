local _, Addon = ...
-- Hangul for the on-screen keyboard. A Korean keyboard types the letters (jamo) one by one and the text grows by syllable
-- blocks: ㅎ ㅏ ㄴ make 한. The game's chat line knows nothing of that, so the keyboard does what a Korean input method
-- does: it looks at the last character before the cursor and either merges the new jamo into it or starts a new one.
--   Hangul.Append(last, jamo)   what replaces the last character when a jamo is typed after it (nil: start a new one)
--   Hangul.Backspace(last)      what replaces it when one jamo is taken away again ("" when nothing is left)
--   Hangul.Key(word)            the word as a plain list of jamo (compound ones split), nil unless it is all Hangul
-- Everything works on UTF-8 strings (Lua 5.1 has no utf8 library); every Hangul character is three bytes.
local Hangul = {}
Addon.Hangul = Hangul

local CHARACTER = "[\227-\237][\128-\191][\128-\191]"
Hangul.CHARACTER = CHARACTER

local function Characters(text)
    local list = {}
    for character in text:gmatch(CHARACTER) do list[#list + 1] = character end
    return list
end

local function Encode(code)
    return string.char(224 + math.floor(code / 4096), 128 + math.floor(code / 64) % 64, 128 + code % 64)
end

local function Decode(character)
    local first, second, third = character:byte(1, 3)
    if not third or first < 224 or first > 239 then return nil end
    return (first - 224) * 4096 + (second - 128) * 64 + (third - 128)
end

-- The letters in the order of the Unicode syllable block (initial, vowel, final; a syllable may have no final).
local INITIAL = Characters("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
local VOWEL = Characters("ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ")
local FINAL = Characters("ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ")

local INITIAL_INDEX, VOWEL_INDEX, FINAL_INDEX = {}, {}, {}
for i, letter in ipairs(INITIAL) do INITIAL_INDEX[letter] = i - 1 end
for i, letter in ipairs(VOWEL) do VOWEL_INDEX[letter] = i - 1 end
for i, letter in ipairs(FINAL) do FINAL_INDEX[letter] = i end

-- Two vowels that make one (ㅗ + ㅏ = ㅘ), and two consonants that make a final (ㄹ + ㄱ = ㄺ), and the way back.
local VOWEL_PAIRS = { "ㅗㅏㅘ", "ㅗㅐㅙ", "ㅗㅣㅚ", "ㅜㅓㅝ", "ㅜㅔㅞ", "ㅜㅣㅟ", "ㅡㅣㅢ" }
local FINAL_PAIRS = { "ㄱㅅㄳ", "ㄴㅈㄵ", "ㄴㅎㄶ", "ㄹㄱㄺ", "ㄹㅁㄻ", "ㄹㅂㄼ", "ㄹㅅㄽ", "ㄹㅌㄾ", "ㄹㅍㄿ", "ㄹㅎㅀ", "ㅂㅅㅄ" }
local VOWEL_JOIN, VOWEL_SPLIT, FINAL_JOIN, FINAL_SPLIT = {}, {}, {}, {}
for _, pair in ipairs(VOWEL_PAIRS) do
    local a, b, joined = unpack(Characters(pair))
    VOWEL_JOIN[a .. b], VOWEL_SPLIT[joined] = joined, { a, b }
end
for _, pair in ipairs(FINAL_PAIRS) do
    local a, b, joined = unpack(Characters(pair))
    FINAL_JOIN[a .. b], FINAL_SPLIT[joined] = joined, { a, b }
end

local FIRST, LAST = 44032, 55203   -- U+AC00 and U+D7A3: the syllable block

local function Syllable(initial, vowel, final)
    return Encode(FIRST + (initial * 21 + vowel) * 28 + final)
end

-- What a character is: "syllable" (with its three parts), "vowel" or "consonant" (a letter on its own), or nothing.
local function Parse(character)
    if VOWEL_INDEX[character] then return "vowel" end
    if INITIAL_INDEX[character] or FINAL_INDEX[character] then return "consonant" end
    local code = Decode(character)
    if not code or code < FIRST or code > LAST then return nil end
    local offset = code - FIRST
    return "syllable", math.floor(offset / 588), math.floor(offset / 28) % 21, offset % 28
end

function Hangul.IsHangul(character)
    return type(character) == "string" and Parse(character) ~= nil
end

-- A letter the keyboard types: one that can be put after a character (the other Hangul characters are syllables).
function Hangul.IsJamo(character)
    local kind = type(character) == "string" and Parse(character)
    return kind == "vowel" or kind == "consonant"
end

-- The text that replaces `last` (one Hangul character) when `jamo` is typed after it; nil when the jamo starts a character
-- of its own (the last one is left as it is).
function Hangul.Append(last, jamo)
    local kind, initial, vowel, final = Parse(last)
    local jamoKind = Parse(jamo)
    local isVowel, isConsonant = jamoKind == "vowel", jamoKind == "consonant"
    if kind == "consonant" then
        if isVowel and INITIAL_INDEX[last] then return Syllable(INITIAL_INDEX[last], VOWEL_INDEX[jamo], 0) end
        return nil
    elseif kind == "vowel" then
        return isVowel and VOWEL_JOIN[last .. jamo] or nil
    elseif kind ~= "syllable" then
        return nil
    end
    if final == 0 then
        if isVowel then
            local joined = VOWEL_JOIN[VOWEL[vowel + 1] .. jamo]
            return joined and Syllable(initial, VOWEL_INDEX[joined], 0) or nil
        elseif isConsonant and FINAL_INDEX[jamo] then
            return Syllable(initial, vowel, FINAL_INDEX[jamo])
        end
        return nil
    end
    local letter = FINAL[final]
    if isVowel then
        -- The last consonant of the block moves to the next one: 한 + ㅏ = 하나; of a double final only the second moves.
        local split = FINAL_SPLIT[letter]
        local kept = split and FINAL_INDEX[split[1]] or 0
        local moved = split and split[2] or letter
        return Syllable(initial, vowel, kept) .. Syllable(INITIAL_INDEX[moved], VOWEL_INDEX[jamo], 0)
    elseif isConsonant then
        local joined = FINAL_JOIN[letter .. jamo]
        return joined and Syllable(initial, vowel, FINAL_INDEX[joined]) or nil
    end
    return nil
end

-- The text that replaces `last` when its last letter is taken away: 한 -> 하 -> ㅎ -> nothing. nil when `last` is no Hangul.
function Hangul.Backspace(last)
    local kind, initial, vowel, final = Parse(last)
    if kind == "syllable" then
        if final ~= 0 then
            local split = FINAL_SPLIT[FINAL[final]]
            return Syllable(initial, vowel, split and FINAL_INDEX[split[1]] or 0)
        end
        local split = VOWEL_SPLIT[VOWEL[vowel + 1]]
        if split then return Syllable(initial, VOWEL_INDEX[split[1]], 0) end
        return INITIAL[initial + 1]
    elseif kind == "vowel" then
        local split = VOWEL_SPLIT[last]
        return split and split[1] or ""
    elseif kind == "consonant" then
        local split = FINAL_SPLIT[last]
        return split and split[1] or ""
    end
end

-- A word as the list of its letters, compound ones split (ㅘ -> ㅗㅏ, ㄺ -> ㄹㄱ): two words that begin the same when typed begin
-- the same here, however far the last syllable has come. nil unless the word is nothing but Hangul.
function Hangul.Key(word)
    if type(word) ~= "string" or word == "" then return nil end
    local parts = {}
    local rest = word:gsub(CHARACTER, function(character)
        local kind, initial, vowel, final = Parse(character)
        if kind == "syllable" then
            parts[#parts + 1] = INITIAL[initial + 1]
            local v = VOWEL[vowel + 1]
            local split = VOWEL_SPLIT[v]
            parts[#parts + 1] = split and (split[1] .. split[2]) or v
            if final ~= 0 then
                local f = FINAL[final]
                split = FINAL_SPLIT[f]
                parts[#parts + 1] = split and (split[1] .. split[2]) or f
            end
        elseif kind == "vowel" then
            local split = VOWEL_SPLIT[character]
            parts[#parts + 1] = split and (split[1] .. split[2]) or character
        elseif kind == "consonant" then
            local split = FINAL_SPLIT[character]
            parts[#parts + 1] = split and (split[1] .. split[2]) or character
        else
            return nil
        end
        return ""
    end)
    if rest ~= "" then return nil end
    return table.concat(parts)
end

-- True when every character of the word is Hangul.
function Hangul.Fits(word)
    return Hangul.Key(word) ~= nil
end
