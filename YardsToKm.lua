local addonName = ...
local hookedFontStrings = setmetatable({}, { __mode = "k" })
local convertingFontStrings = setmetatable({}, { __mode = "k" })
local originalTexts = setmetatable({}, { __mode = "k" })
local displayedTexts = setmetatable({}, { __mode = "k" })
local hookedTooltips = setmetatable({}, { __mode = "k" })
local settingsControls = {}
-- Mainline clients (Retail, WoW Forever) can hand addons secret values that
-- error when compared or parsed; Classic Era has no such function.
local issecretvalue = issecretvalue

local function IsReadableText(text)
    return type(text) == "string" and not (issecretvalue and issecretvalue(text))
end

local function IsForbidden(object)
    return type(object.IsForbidden) == "function" and object:IsForbidden()
end

if type(YardsToKmDB) ~= "table" then
    YardsToKmDB = {}
end
if YardsToKmDB.enabled == nil then
    YardsToKmDB.enabled = true
end

-- Cycling display options. Each value name doubles as its /ytk command, and the
-- first value is the default.
local OPTIONS = {
    { key = "unitMode", label = "Units", values = {
        { "auto", "Automatic (m / km)" }, { "km", "Kilometers only" } } },
    { key = "precision", label = "Number precision", values = {
        { "compact", "Compact" }, { "precise", "Precise" } } },
    { key = "display", label = "Display", values = {
        { "replace", "Metric only" }, { "both", "Yards and metric" } } },
    { key = "decimal", label = "Decimal separator", values = {
        { "point", "Point (0.5)" }, { "comma", "Comma (0,5)" } } },
}

local function OptionValueIndex(option)
    for index, value in ipairs(option.values) do
        if value[1] == YardsToKmDB[option.key] then
            return index
        end
    end
end

for _, option in ipairs(OPTIONS) do
    if not OptionValueIndex(option) then
        YardsToKmDB[option.key] = option.values[1][1]
    end
end

local function FormatDistance(yardsText)
    local yards = tonumber((yardsText:gsub(",", "")))
    if not yards then
        return yardsText
    end

    local meters = yards * 0.9144
    local value, unit
    if YardsToKmDB.unitMode == "auto" and meters < 1000 then
        local decimals = YardsToKmDB.precision == "precise" and 1 or 0
        value = string.format("%." .. decimals .. "f", meters)
        unit = "m"
    else
        local decimals = YardsToKmDB.precision == "precise" and 4 or 3
        value = string.format("%." .. decimals .. "f", meters / 1000)
        unit = "km"
    end

    value = value:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
    if YardsToKmDB.decimal == "comma" then
        value = value:gsub("%.", ",")
    end
    return value .. " " .. unit
end

local NUMBER_PATTERN = "%f[%d](%d[%d,]*%.?%d*)"
-- Pattern separator, then the separator written between converted endpoints.
local RANGE_SEPARATORS = {
    { "%s*%-%s*", " - " }, { "%s*–%s*", " - " }, { "%s*—%s*", " - " },
    { "%s+[Tt][Oo]%s+", " to " },
}

-- True when a measurement ending before `position` is already followed by a
-- metric value in parentheses, as "Yards and metric" display writes it.
local function HasMetricSuffix(text, position)
    return text:find("^%s*%(%d[%d.,]*%s*k?m%f[%A]", position) ~= nil
end

local function Present(original, metric)
    if YardsToKmDB.display == "both" then
        return original .. " (" .. metric .. ")"
    end
    return metric
end

local function ReplaceMeasurements(text, unitPattern)
    local unitSuffix = "%s*" .. unitPattern .. ")%f[%A]()"

    for _, separator in ipairs(RANGE_SEPARATORS) do
        local rangePattern = "(" .. NUMBER_PATTERN .. separator[1] .. NUMBER_PATTERN .. unitSuffix
        text = text:gsub(rangePattern, function(original, first, second, position)
            if HasMetricSuffix(text, position) then
                return original
            end
            return Present(original, FormatDistance(first) .. separator[2] .. FormatDistance(second))
        end)
    end

    return text:gsub("(" .. NUMBER_PATTERN .. unitSuffix, function(original, value, position)
        if HasMetricSuffix(text, position) then
            return original
        end
        return Present(original, FormatDistance(value))
    end)
end

local function ConvertYards(text)
    -- Most UI text has no yard value; skip the pattern passes for it.
    if not text:find("[Yy]") or not text:find("%d") then
        return text
    end
    if text:find("|H", 1, true) or text:find("|T", 1, true) then
        return text
    end

    text = ReplaceMeasurements(text, "[Yy][Aa][Rr][Dd][Ss]?")
    return ReplaceMeasurements(text, "[Yy][Dd][Ss]?")
end

local function SetFontStringText(fontString, text)
    if text == nil then
        return
    end

    convertingFontStrings[fontString] = true
    fontString:SetText(text)
    convertingFontStrings[fontString] = nil
end

local function RefreshFontString(fontString)
    local currentText = fontString:GetText()
    if currentText ~= nil and not IsReadableText(currentText) then
        originalTexts[fontString] = nil
        displayedTexts[fontString] = nil
        return
    end

    local text = originalTexts[fontString]
    if text == nil then
        text = currentText
        if text == nil then
            return
        end
    end

    local converted = ConvertYards(text)
    if converted ~= text then
        originalTexts[fontString] = text
    end
    local displayText = YardsToKmDB.enabled and converted or text
    displayedTexts[fontString] = displayText
    if displayText ~= currentText then
        SetFontStringText(fontString, displayText)
    end
end

local function RefreshAllText()
    for fontString in pairs(originalTexts) do
        RefreshFontString(fontString)
    end
end

local function ConvertFontString(fontString)
    if convertingFontStrings[fontString] then
        return
    end

    originalTexts[fontString] = nil
    if not IsReadableText(fontString:GetText()) then
        displayedTexts[fontString] = nil
        return
    end
    RefreshFontString(fontString)
end

local function HookFontString(fontString)
    if hookedFontStrings[fontString] or not fontString:IsObjectType("FontString") then
        return
    end

    hookedFontStrings[fontString] = true
    if type(fontString.SetText) == "function" then
        hooksecurefunc(fontString, "SetText", ConvertFontString)
    end
    if type(fontString.SetFormattedText) == "function" then
        hooksecurefunc(fontString, "SetFormattedText", ConvertFontString)
    end
    RefreshFontString(fontString)
end

local function RefreshTooltip(tooltip)
    for _, region in ipairs({ tooltip:GetRegions() }) do
        if region:IsObjectType("FontString") then
            -- Native tooltip updates can bypass the Lua text setter hooks.
            local text = region:GetText()
            if IsReadableText(text) and text ~= displayedTexts[region] then
                ConvertFontString(region)
            end
            HookFontString(region)
        end
    end
end

local function HookTooltip(tooltip)
    if hookedTooltips[tooltip] or IsForbidden(tooltip) or not tooltip:IsObjectType("GameTooltip") then
        return
    end

    hookedTooltips[tooltip] = true
    tooltip:HookScript("OnShow", RefreshTooltip)
    if tooltip:HasScript("OnTooltipSetSpell") then
        tooltip:HookScript("OnTooltipSetSpell", RefreshTooltip)
    end
    local elapsedTime = 0
    tooltip:HookScript("OnUpdate", function(self, elapsed)
        elapsedTime = elapsedTime + elapsed
        if elapsedTime >= 0.1 then
            elapsedTime = 0
            RefreshTooltip(self)
        end
    end)
end

local function ScanFrames()
    local frame = EnumerateFrames()
    while frame do
        if not IsForbidden(frame) then
            HookTooltip(frame)
            for _, region in ipairs({ frame:GetRegions() }) do
                HookFontString(region)
            end
        end
        frame = EnumerateFrames(frame)
    end
end

local function HookSpellTooltipData()
    -- Mainline removed OnTooltipSetSpell in favor of tooltip data post-calls.
    if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Spell) then
        return
    end

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip)
        if tooltip and not IsForbidden(tooltip) then
            HookTooltip(tooltip)
            RefreshTooltip(tooltip)
        end
    end)
end

local function PrintStatus(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. addonName .. ":|r " .. message)
end

local function OptionLabel(option)
    return option.values[OptionValueIndex(option)][2]
end

local function UpdateSettingsControls()
    if settingsControls.enabled then
        settingsControls.enabled:SetChecked(YardsToKmDB.enabled)
        for _, option in ipairs(OPTIONS) do
            settingsControls[option.key]:SetText(OptionLabel(option))
        end
    end
end

local function SetSetting(key, value)
    YardsToKmDB[key] = value
    RefreshAllText()
    UpdateSettingsControls()
end

local function CreateSettingsPanel()
    if not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then
        PrintStatus("in-game settings panel is unavailable in this client; use /ytk on or /ytk off.")
        return
    end

    local panel = CreateFrame("Frame")
    panel.name = addonName
    panel:Hide()

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Yards to Kilometers")

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetText("Choose how converted yard distances are displayed.")

    local enabled = CreateFrame("CheckButton", nil, panel)
    enabled:SetSize(26, 26)
    enabled:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -20)
    local enabledLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    enabledLabel:SetPoint("LEFT", enabled, "RIGHT", 6, 0)
    enabledLabel:SetText("Convert visible yard measurements")
    enabled:SetScript("OnClick", function(self)
        SetSetting("enabled", self:GetChecked())
    end)
    settingsControls.enabled = enabled

    local previous, gap = enabled, -20
    for _, option in ipairs(OPTIONS) do
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, gap)
        label:SetText(option.label)
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(190, 24)
        button:SetPoint("LEFT", label, "LEFT", 180, 0)
        button:SetScript("OnClick", function()
            local nextValue = option.values[OptionValueIndex(option) % #option.values + 1]
            SetSetting(option.key, nextValue[1])
        end)
        settingsControls[option.key] = button
        previous, gap = label, -30
    end

    local category = Settings.RegisterCanvasLayoutCategory(panel, addonName)
    Settings.RegisterAddOnCategory(category)
    UpdateSettingsControls()
end

SLASH_YARDSTOKM1 = "/ytk"
local slashSettings = {
    on = { "enabled", true, "yard conversion enabled." },
    off = { "enabled", false, "yard conversion disabled." },
}
local commandNames = { "on", "off" }
for _, option in ipairs(OPTIONS) do
    for _, value in ipairs(option.values) do
        slashSettings[value[1]] = { option.key, value[1], option.label:lower() .. " set to " .. value[2] .. "." }
        commandNames[#commandNames + 1] = value[1]
    end
end
commandNames[#commandNames + 1] = "scan"

SlashCmdList.YARDSTOKM = function(message)
    local command = (message or ""):lower():match("^%s*(%S*)")
    local setting = slashSettings[command]

    if setting then
        SetSetting(setting[1], setting[2])
        PrintStatus(setting[3])
    elseif command == "scan" then
        ScanFrames()
        PrintStatus("scanned UI text.")
    else
        local status = { "conversion " .. (YardsToKmDB.enabled and "on" or "off") }
        for _, option in ipairs(OPTIONS) do
            status[#status + 1] = option.label:lower() .. " " .. OptionLabel(option)
        end
        PrintStatus(table.concat(status, ", ") .. ".")
        PrintStatus("commands: " .. table.concat(commandNames, ", ") .. ". Settings are also under Options > AddOns.")
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" then
        if loadedAddon == addonName then
            ScanFrames()
            HookSpellTooltipData()
            CreateSettingsPanel()
        end
    elseif event == "PLAYER_LOGIN" then
        ScanFrames()
        C_Timer.NewTicker(10, ScanFrames)
    end
end)
