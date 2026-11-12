local _, Addon = ...
-- The game's interface font (Friz Quadrata) has no Polish letters except ó and ł: ą, ć, ę, ń, ś, ź and ż show as boxes.
-- The font of the chat (Arial Narrow) has them. What this addon draws with the game's fonts goes through font objects of
-- its own (copies of the game's, CGPFont...), so one call can put the chat's font file under all of them: the interface
-- set while the interface is in Polish, the key set while the keyboard types Polish. The texts of the game's own tooltips
-- cannot be helped: the Polish texts the addon hands to them avoid those letters (see Locales/plPL.lua).
local Fonts = { name = {}, object = {} }
Addon.Fonts = Fonts

local FALLBACK = "Fonts\\ARIALN.TTF"

-- The languages whose letters the game's font lacks.
local WIDE_INTERFACE = { plPL = true }
local WIDE_KEYBOARD = { PL = true }

-- The copies: key -> the game's font object it copies. "ui" follows the language of the interface, "key" the keyboard's.
local SETS = {
    ui = { Normal = "GameFontNormal", NormalSmall = "GameFontNormalSmall", Highlight = "GameFontHighlight",
        HighlightSmall = "GameFontHighlightSmall", HighlightLarge = "GameFontHighlightLarge", Disable = "GameFontDisable",
        DisableSmall = "GameFontDisableSmall" },
    key = { Key = "GameFontHighlight", KeyLarge = "GameFontHighlightLarge" },
}

local entries = { ui = {}, key = {} }
local BASE = {}

for set, fonts in pairs(SETS) do
    for key, base in pairs(fonts) do
        local name = "CGPFont" .. key
        Fonts.name[key], BASE[key] = name, base
        local source = _G[base]
        if source and CreateFont then
            local existing = _G[name]
            local font = (type(existing) == "table" and existing.CopyFontObject) and existing or CreateFont(name)
            font:CopyFontObject(source)
            Fonts.object[key] = font
            entries[set][#entries[set] + 1] = { font = font, base = source }
        end
    end
end

-- A font file with the letters of Central Europe: the one the chat uses.
function Fonts:WidePath()
    local chat = _G.ChatFontNormal
    if chat and chat.GetFont then
        local ok, path = pcall(chat.GetFont, chat)
        if ok and type(path) == "string" and path ~= "" then return path end
    end
    return FALLBACK
end

-- Puts the wide font (or the game's own again) under a set of copies. Arial Narrow looks smaller than Friz Quadrata at the
-- same size, so it is a little bigger.
function Fonts:Set(set, wide)
    local path = wide and self:WidePath() or nil
    for _, entry in ipairs(entries[set]) do
        local original, size, flags = entry.base:GetFont()
        local done = false
        if path and original then
            local ok, result = pcall(entry.font.SetFont, entry.font, path, math.floor((size or 12) * 1.08 + 0.5), flags or "")
            done = ok and result ~= false
        end
        if not done and original then pcall(entry.font.SetFont, entry.font, original, size, flags or "") end
    end
end

function Fonts.InterfaceWide()
    return WIDE_INTERFACE[Addon.Locales and Addon.Locales.code] == true
end

-- Looks at the languages in use and sets the fonts: at the start, and when the interface language or the keyboard's changes.
function Fonts:Update()
    local interface = self.InterfaceWide()
    local keyboard = WIDE_KEYBOARD[Addon.db and Addon.db.keyboardLanguage] == true
    if self.interface ~= interface then
        self.interface = interface
        self:Set("ui", interface)
    end
    if self.keyboard ~= keyboard then
        self.keyboard = keyboard
        self:Set("key", keyboard)
    end
end

-- /cgp fonts: what the addon does about fonts, for when Polish letters still show as boxes.
function Fonts:Debug()
    local function Describe(font)
        local path, size = font:GetFont()
        return tostring(path) .. ", " .. tostring(size)
    end
    Addon:Print(string.format("fonts: interface language %s (wide font: %s), keyboard language %s (wide font: %s)",
        tostring(Addon.Locales and Addon.Locales.code), tostring(self.InterfaceWide()), tostring(Addon.db and Addon.db.keyboardLanguage),
        tostring(self.keyboard == true)))
    Addon:Print("chat font (used as the wide font): " .. tostring(self:WidePath()))
    if self.object.Highlight then Addon:Print("interface font now: " .. Describe(self.object.Highlight)) end
    if self.object.Key then Addon:Print("key font now: " .. Describe(self.object.Key)) end
end

-- A text of the interface: a FontString made from the game's font object, then given the copy.
function Fonts:String(parent, layer, key)
    local text = parent:CreateFontString(nil, layer, BASE[key])
    if self.object[key] then text:SetFontObject(self.object[key]) end
    return text
end

-- The three fonts of a button (normal, mouse over, disabled); `small` for the tabs.
function Fonts:Button(button, small)
    local normal, highlight, disabled = self.object.Normal, self.object.Highlight, self.object.Disable
    if small then normal, highlight, disabled = self.object.NormalSmall, self.object.HighlightSmall, self.object.HighlightSmall end
    if normal then button:SetNormalFontObject(normal) end
    if highlight then button:SetHighlightFontObject(highlight) end
    if disabled then button:SetDisabledFontObject(disabled) end
end
