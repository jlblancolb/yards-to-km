local addonName = ...
local hookedFontStrings = setmetatable({}, { __mode = "k" })
local convertingFontStrings = setmetatable({}, { __mode = "k" })
local originalTexts = setmetatable({}, { __mode = "k" })
local displayedTexts = setmetatable({}, { __mode = "k" })
local hookedTooltips = setmetatable({}, { __mode = "k" })
local settingsControls = {}
local settingsCategory
local openSettingsAfterCombat = false
-- Mainline clients (Retail, WoW Forever) can hand addons secret values that
-- error when compared or parsed; Classic Era has no such function.
local issecretvalue = issecretvalue

local function IsReadableText(text)
    return type(text) == "string" and not (issecretvalue and issecretvalue(text))
end

local function IsForbidden(object)
    return type(object.IsForbidden) == "function" and object:IsForbidden()
end

-- Mainline can also restrict objects that don't report IsForbidden; their
-- methods error when called from addon code, so treat any error as "no".
local function IsObjectOfType(object, objectType)
    local ok, result = pcall(object.IsObjectType, object, objectType)
    return ok and result
end

-- Saved variables replace this table after the file runs, so defaults are also
-- applied again on ADDON_LOADED.
YardsToKmDB = {}

-- Cycling display options. Each value name doubles as its /ytk command, and the
-- first value is the default.
local OPTIONS = {
    { key = "unitMode", label = "Units",
      tooltip = "Automatic shows meters below 1,000 m and kilometers above.", values = {
        { "auto", "Automatic (m / km)" }, { "km", "Kilometers only" } } },
    { key = "precision", label = "Number precision",
      tooltip = "Precise shows one more decimal place.", values = {
        { "compact", "Compact" }, { "precise", "Precise" } } },
    { key = "display", label = "Display",
      tooltip = "Replace yards with metric, or keep yards and add metric in parentheses.", values = {
        { "replace", "Metric only" }, { "both", "Yards and metric" } } },
    { key = "decimal", label = "Decimal separator",
      tooltip = "Write decimals with a point or a comma.", values = {
        { "point", "Point (0.5)" }, { "comma", "Comma (0,5)" } } },
}

local function OptionValueIndex(option)
    for index, value in ipairs(option.values) do
        if value[1] == YardsToKmDB[option.key] then
            return index
        end
    end
end

local function ApplySettingDefaults()
    if type(YardsToKmDB) ~= "table" then
        YardsToKmDB = {}
    end
    -- Missing means on; native checkboxes need a real boolean.
    YardsToKmDB.enabled = YardsToKmDB.enabled ~= false
    for _, option in ipairs(OPTIONS) do
        if not OptionValueIndex(option) then
            YardsToKmDB[option.key] = option.values[1][1]
        end
    end
end
ApplySettingDefaults()

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
    if hookedFontStrings[fontString] or not IsObjectOfType(fontString, "FontString") then
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

-- Walk regions as varargs instead of packing them into a table: these run for
-- every frame on each scan and every 0.1 s on a shown tooltip, so a table per
-- call adds up to megabytes of garbage.
local function RefreshTooltipRegions(...)
    for index = 1, select("#", ...) do
        local region = select(index, ...)
        if IsObjectOfType(region, "FontString") then
            -- Native tooltip updates can bypass the Lua text setter hooks.
            local text = region:GetText()
            if IsReadableText(text) and text ~= displayedTexts[region] then
                ConvertFontString(region)
            end
            HookFontString(region)
        end
    end
end

local function RefreshTooltip(tooltip)
    RefreshTooltipRegions(tooltip:GetRegions())
end

local function HookTooltip(tooltip)
    if hookedTooltips[tooltip] or IsForbidden(tooltip) or not IsObjectOfType(tooltip, "GameTooltip") then
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

local function HookRegions(...)
    for index = 1, select("#", ...) do
        HookFontString((select(index, ...)))
    end
end

-- Called through pcall: restricted frames error on GetRegions.
local function HookFrameRegions(frame)
    HookRegions(frame:GetRegions())
end

local function ScanFrames()
    local frame = EnumerateFrames()
    while frame do
        if not IsForbidden(frame) then
            HookTooltip(frame)
            pcall(HookFrameRegions, frame)
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

local SETTINGS_NAME = "Yards to Kilometers"
local ENABLED_LABEL = "Convert visible yard measurements"
-- Native Settings objects by saved-variable key, on clients that use them.
local nativeSettings = {}

local function UpdateSettingsControls()
    if settingsControls.enabled then
        settingsControls.enabled:SetChecked(YardsToKmDB.enabled)
        for _, option in ipairs(OPTIONS) do
            settingsControls[option.key]:SetText(OptionLabel(option))
        end
    end
    -- Keep native controls in step with /ytk and compartment changes. SetValue
    -- calls back into SetSetting, which then finds the value already matches.
    for key, setting in pairs(nativeSettings) do
        if setting:GetValue() ~= YardsToKmDB[key] then
            setting:SetValue(YardsToKmDB[key])
        end
    end
end

local function SetSetting(key, value)
    YardsToKmDB[key] = value
    RefreshAllText()
    UpdateSettingsControls()
end

-- Blizzard-style settings page with a checkbox and dropdowns (Mainline API,
-- used by WoW Forever). Returns the category, or nil if any piece is missing.
local function CreateNativeSettings()
    if WOW_PROJECT_ID and WOW_PROJECT_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
        return nil
    end
    for _, name in ipairs({ "RegisterVerticalLayoutCategory", "RegisterAddOnSetting", "CreateCheckbox",
            "CreateDropdown", "CreateControlTextContainer", "RegisterAddOnCategory" }) do
        if not Settings[name] then
            return nil
        end
    end
    local varTypes = Settings.VarType or {}

    local category = Settings.RegisterVerticalLayoutCategory(SETTINGS_NAME)
    local registered = {}
    local function Register(key, varType, label, default)
        local setting = Settings.RegisterAddOnSetting(category, addonName .. "_" .. key, key, YardsToKmDB,
            varType, label, default)
        setting:SetValueChangedCallback(function(_, value)
            SetSetting(key, value)
        end)
        registered[key] = setting
        return setting
    end

    local enabled = Register("enabled", varTypes.Boolean or "boolean", ENABLED_LABEL, true)
    Settings.CreateCheckbox(category, enabled, "Turn off to show the original yard values.")
    for _, option in ipairs(OPTIONS) do
        local setting = Register(option.key, varTypes.String or "string", option.label, option.values[1][1])
        Settings.CreateDropdown(category, setting, function()
            local container = Settings.CreateControlTextContainer()
            for _, value in ipairs(option.values) do
                container:Add(value[1], value[2])
            end
            return container:GetData()
        end, option.tooltip)
    end

    Settings.RegisterAddOnCategory(category)
    nativeSettings = registered
    return category
end

local function CreateSettingsPanel()
    if not Settings or not Settings.RegisterAddOnCategory then
        PrintStatus("in-game settings panel is unavailable in this client; type /ytk for commands.")
        return
    end

    local ok, category = pcall(CreateNativeSettings)
    if ok and category then
        settingsCategory = category
        return
    elseif not ok then
        PrintStatus("using the basic settings page (" .. tostring(category) .. ").")
    end
    if not Settings.RegisterCanvasLayoutCategory then
        PrintStatus("in-game settings panel is unavailable in this client; type /ytk for commands.")
        return
    end

    -- Fallback page for Classic Era: cycling buttons on a canvas.
    local panel = CreateFrame("Frame")
    panel.name = SETTINGS_NAME
    panel:Hide()

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(SETTINGS_NAME)

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetText("Choose how converted yard distances are displayed.")

    local enabled = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    enabled:SetSize(26, 26)
    enabled:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -20)
    local enabledLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    enabledLabel:SetPoint("LEFT", enabled, "RIGHT", 6, 0)
    enabledLabel:SetText(ENABLED_LABEL)
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

    settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(settingsCategory)
    UpdateSettingsControls()
end

-- The settings panel is protected UI, so wait for combat to end before opening it.
local function OpenSettings()
    if not settingsCategory or not Settings.OpenToCategory then
        PrintStatus("settings panel is unavailable in this client; type /ytk for commands.")
    elseif InCombatLockdown and InCombatLockdown() then
        openSettingsAfterCombat = true
        PrintStatus("settings will open when combat ends.")
    else
        Settings.OpenToCategory(settingsCategory:GetID())
    end
end

-- Addon compartment (minimap addon menu) handlers, named in the TOC. Clients
-- without the compartment ignore those TOC fields.
function YardsToKm_OnAddonCompartmentClick(_, mouseButton)
    if mouseButton == "RightButton" then
        SetSetting("enabled", not YardsToKmDB.enabled)
        PrintStatus("yard conversion " .. (YardsToKmDB.enabled and "enabled." or "disabled."))
    else
        OpenSettings()
    end
end

function YardsToKm_OnAddonCompartmentEnter(_, menuButton)
    GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
    GameTooltip:SetText("Yards to Kilometers")
    GameTooltip:AddLine("Conversion " .. (YardsToKmDB.enabled and "on" or "off"), 1, 1, 1)
    GameTooltip:AddLine("Left-click: open settings", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Right-click: turn conversion on or off", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

function YardsToKm_OnAddonCompartmentLeave()
    GameTooltip:Hide()
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
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" then
        if loadedAddon == addonName then
            ApplySettingDefaults()
            ScanFrames()
            HookSpellTooltipData()
            CreateSettingsPanel()
        end
    elseif event == "PLAYER_LOGIN" then
        ScanFrames()
        C_Timer.NewTicker(10, ScanFrames)
    elseif event == "PLAYER_REGEN_ENABLED" and openSettingsAfterCombat then
        openSettingsAfterCombat = false
        OpenSettings()
    end
end)
