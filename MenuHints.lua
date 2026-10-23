local _, Addon = ...
local Hints = { buttons = {} }
Addon.MenuHints = Hints

local directions = { "→", "↗", "↑", "↖", "←", "↙", "↓", "↘" }
local centerText = ({
    deDE = "Stick zur Mitte zurückführen",
    plPL = "puść drążek do środka",
})[GetLocale()] or "return the stick to center"

function Hints:KeyText(key)
    local parts = InputIconTextureSetUtility.GetInputIconNameFromBindingKey(key)
    local labels = {}
    for _, part in ipairs(parts) do
        local textures = InputIconTextureSetUtility.GetActiveInputIconButtonTextures(part)
        local atlas = textures and InputIconTextureSetUtility.GetNormalActiveInputIconButtonTexture(part)
        labels[#labels + 1] = atlas and CreateAtlasMarkup(atlas, 24, 24) or GetBindingText(part, 1)
    end
    return table.concat(labels, " + ")
end
local function KeyText(key) return Hints:KeyText(key) end

local function PadKeys(command)
    local keys = {}
    if command then
        -- Use the same binding context as the native gamepad editor.
        for _, key in ipairs({ GetBindingKey(command, 1) }) do
            if IsBindingForGamePad(key) then keys[#keys + 1] = KeyText(key) end
        end
    end
    return table.concat(keys, " / ")
end

function Hints:GetHint(button)
    local direct = PadKeys(button.commandName)
    if direct ~= "" then return direct end
    local radial = GamepadRadial
    local menuKeys = PadKeys("OPENRADIAL")
    if radial and radial.mainMenuPages and menuKeys ~= "" then
        -- Read the live wheel layout instead of assuming a panel's segment or page.
        for pageIndex, page in ipairs(radial.mainMenuPages) do
            for index = 1, 8 do
                local handler = page.buttons[index]
                if type(handler) == "string" then handler = radial.segmentOptions[handler] end
                if handler and handler.button == button then
                    local route = { menuKeys }
                    if pageIndex ~= 2 then
                        local prompt = pageIndex < 2 and radial.PageLeftInputPrompt or radial.PageRightInputPrompt
                        for _ = 1, math.abs(pageIndex - 2) do route[#route + 1] = KeyText(prompt.mappedButtonKey) end
                    end
                    route[#route + 1] = KeyText(GAMEPAD_STICK_RIGHT) .. " " .. directions[index]
                    return table.concat(route, " > ") .. "\n" .. centerText
                end
            end
        end
    end
    return NOT_BOUND
end

function Hints:Append(button)
    if not Addon.db or not Addon.db.enabled or not Addon.db.showMenuHints or Addon.nativeView or Addon.conflict
        or not Addon:IsGamepadMode() or not GameTooltip:IsShown() or GameTooltip:GetOwner() ~= button then return end
    -- One hint per tooltip, even when bindings change while it is shown.
    local prefix = GAMEPAD_LABEL .. ": "
    for i = 1, GameTooltip:NumLines() do
        local line = _G["GameTooltipTextLeft" .. i]
        local current = line and line:GetText()
        if type(current) == "string" and current:sub(1, #prefix) == prefix then return end
    end
    local hint = prefix .. self:GetHint(button)
    GameTooltip:AddLine(hint, 1, 0.82, 0, true)
    GameTooltip:Show()
end

function Hints:Refresh()
    -- Never rebuild the micro button tooltip from addon code; it writes
    -- Blizzard tooltip state outside the button's own secure handlers.
    local button = GameTooltip:GetOwner()
    if self.buttons[button] and GameTooltip:IsShown() then self:Append(button) end
end

function Hints:Observe()
    for _, info in ipairs(MicroMenu:GenerateButtonInfos()) do
        local button = info.button
        self.buttons[button] = true
        button:HookScript("OnEnter", function() self:Append(button) end)
        hooksecurefunc(button, "EvaluateTooltipVisibility", function() self:Append(button) end)
    end
    -- Some menu buttons build their tooltip on an update rather than on mouse enter.
    local function AppendOwner()
        local owner = GameTooltip:GetOwner()
        if self.buttons[owner] then self:Append(owner) end
    end
    GameTooltip:HookScript("OnShow", AppendOwner)
    if type(MainMenuBarPerformanceBarFrame_OnEnter) == "function" then
        hooksecurefunc("MainMenuBarPerformanceBarFrame_OnEnter", AppendOwner)
    end
end
