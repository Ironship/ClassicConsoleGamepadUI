local _, Addon = ...
-- The texts of the interface. Every language has a file of its own in Locales/ that hands its texts to Register; English is
-- the base, and a text another language does not have is shown in English. The language is the player's choice (the
-- settings, English by default) and not the game client's, so a German client can show English hints.
--   Addon.L.key        the text in the language in use
--   Locales.Use(code)  switch language ("auto" follows the game client)
local Locales = { tables = {}, names = {}, order = {}, code = "enUS" }
Addon.Locales = Locales

function Locales.Register(code, name, strings)
    if not Locales.tables[code] then Locales.order[#Locales.order + 1] = code end
    Locales.tables[code] = strings
    Locales.names[code] = name
end

-- Client languages that share the texts of another one.
local CLIENT_ALIASES = { enGB = "enUS", esMX = "esES" }

-- The language a setting stands for: a language code, or "auto" for the game client's language. Anything without texts
-- of its own is English.
function Locales.Resolve(setting)
    if setting == "auto" then
        local client = GetLocale and GetLocale() or "enUS"
        setting = CLIENT_ALIASES[client] or client
    end
    if Locales.tables[setting] then return setting end
    return "enUS"
end

function Locales.Use(setting)
    Locales.code = Locales.Resolve(setting)
end

-- The text of a key in the language in use: English where the language has none, the key itself where English has none
-- either (so a typo shows up on screen instead of failing).
Addon.L = setmetatable({}, { __index = function(_, key)
    local active = Locales.tables[Locales.code]
    local text = active and active[key]
    if text == nil then
        local base = Locales.tables.enUS
        text = base and base[key]
    end
    if text == nil then return key end
    return text
end })
