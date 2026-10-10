local addonName = ...
local hookedFontStrings = setmetatable({}, { __mode = "k" })
local convertingFontStrings = setmetatable({}, { __mode = "k" })
local originalTexts = setmetatable({}, { __mode = "k" })
local displayedTexts = setmetatable({}, { __mode = "k" })
local hookedTooltips = setmetatable({}, { __mode = "k" })
local settingsControls = {}

if type(YardsToKmDB) ~= "table" then
    YardsToKmDB = {}
end
if YardsToKmDB.enabled == nil then
    YardsToKmDB.enabled = true
end
if YardsToKmDB.unitMode ~= "km" then
    YardsToKmDB.unitMode = "auto"
end
if YardsToKmDB.precision ~= "precise" then
    YardsToKmDB.precision = "compact"
end

local function FormatDistance(yardsText)
    local yards = tonumber((yardsText:gsub(",", "")))
    if not yards then
        return yardsText, ""
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
    return value, unit
end

local function ReplaceMeasurements(text, unitPattern)
    local numberPattern = "%f[%d](%d[%d,]*%.?%d*)"
    local dashPatterns = { "%-", "–", "—" }

    for _, dashPattern in ipairs(dashPatterns) do
        local rangePattern = numberPattern .. "(%s*" .. dashPattern .. "%s*)" ..
            numberPattern .. "%s*" .. unitPattern .. "%f[%A]"
        text = text:gsub(rangePattern, function(first, _, second)
            local firstValue, firstUnit = FormatDistance(first)
            local secondValue, secondUnit = FormatDistance(second)
            return firstValue .. " " .. firstUnit .. " - " ..
                secondValue .. " " .. secondUnit
        end)
    end

    local singlePattern = numberPattern .. "%s*" .. unitPattern .. "%f[%A]"
    return text:gsub(singlePattern, function(value)
        local converted, unit = FormatDistance(value)
        return converted .. " " .. unit
    end)
end

local function ConvertYards(text)
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
    local text = originalTexts[fontString]
    if text == nil then
        text = fontString:GetText()
        if type(text) ~= "string" then
            return
        end
        originalTexts[fontString] = text
    end

    local displayText = YardsToKmDB.enabled and ConvertYards(text) or text
    displayedTexts[fontString] = displayText
    if displayText ~= fontString:GetText() then
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

    local text = fontString:GetText()
    if type(text) == "string" then
        originalTexts[fontString] = text
    else
        originalTexts[fontString] = nil
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
            if text ~= displayedTexts[region] then
                ConvertFontString(region)
            end
            HookFontString(region)
        end
    end
end

local function HookTooltip(tooltip)
    if hookedTooltips[tooltip] or not tooltip:IsObjectType("GameTooltip") then
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
        HookTooltip(frame)
        local regions = { frame:GetRegions() }
        for _, region in ipairs(regions) do
            HookFontString(region)
        end
        frame = EnumerateFrames(frame)
    end
end

local function PrintStatus(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. addonName .. ":|r " .. message)
end

local function UpdateSettingsControls()
    if settingsControls.enabled then
        settingsControls.enabled:SetChecked(YardsToKmDB.enabled)
        settingsControls.unitMode:SetText(YardsToKmDB.unitMode == "auto" and "Automatic (m / km)" or "Kilometers only")
        settingsControls.precision:SetText(YardsToKmDB.precision == "compact" and "Compact" or "Precise")
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

    local unitsLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    unitsLabel:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 0, -20)
    unitsLabel:SetText("Units")
    local unitsButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    unitsButton:SetSize(190, 24)
    unitsButton:SetPoint("LEFT", unitsLabel, "RIGHT", 100, 0)
    unitsButton:SetScript("OnClick", function()
        SetSetting("unitMode", YardsToKmDB.unitMode == "auto" and "km" or "auto")
    end)
    settingsControls.unitMode = unitsButton

    local precisionLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    precisionLabel:SetPoint("TOPLEFT", unitsLabel, "BOTTOMLEFT", 0, -30)
    precisionLabel:SetText("Number precision")
    local precisionButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    precisionButton:SetSize(190, 24)
    precisionButton:SetPoint("LEFT", precisionLabel, "RIGHT", 100, 0)
    precisionButton:SetScript("OnClick", function()
        SetSetting("precision", YardsToKmDB.precision == "compact" and "precise" or "compact")
    end)
    settingsControls.precision = precisionButton

    local category = Settings.RegisterCanvasLayoutCategory(panel, addonName)
    Settings.RegisterAddOnCategory(category)
    UpdateSettingsControls()
end

SLASH_YARDSTOKM1 = "/ytk"
SlashCmdList.YARDSTOKM = function(message)
    local command = (message or ""):lower():match("^%s*(%S*)")

    if command == "on" then
        SetSetting("enabled", true)
        PrintStatus("yard conversion enabled.")
    elseif command == "off" then
        SetSetting("enabled", false)
        PrintStatus("yard conversion disabled.")
    elseif command == "scan" then
        ScanFrames()
        PrintStatus("scanned UI text.")
    else
        PrintStatus("use /ytk on, /ytk off, or /ytk scan; configure display under Options > AddOns.")
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" then
        if loadedAddon == addonName then
            ScanFrames()
            CreateSettingsPanel()
        end
    elseif event == "PLAYER_LOGIN" then
        ScanFrames()
        C_Timer.NewTicker(10, ScanFrames)
    end
end)
