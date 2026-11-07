-- Native settings page (Mainline API, WoW Forever) and the Classic Era fallback.
local function NewWidget()
    return setmetatable({}, { __index = function(_, method)
        if method == "CreateFontString" then
            return function() return NewWidget() end
        end
        return function() end
    end })
end

-- Mocks the Settings API pieces the addon uses; settings write their table
-- and notify the change callback, as Blizzard's addon settings do.
local function InstallMocks(projectID, customize)
    local mock = { settings = {}, controls = {}, messages = {} }
    SlashCmdList = {}
    DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) mock.messages[#mock.messages + 1] = message end }
    C_Timer = { NewTicker = function() end }
    function hooksecurefunc(object, method, callback)
        local original = object[method]
        object[method] = function(self, ...)
            original(self, ...)
            callback(self, ...)
        end
    end
    mock.line = { text = "" }
    function mock.line:IsObjectType(kind) return kind == "FontString" end
    function mock.line:GetText() return self.text end
    function mock.line:SetText(value) self.text = value end
    local frame = NewWidget()
    function frame:IsObjectType() return false end
    function frame:GetRegions() return mock.line end
    function EnumerateFrames(previous)
        if not previous then return frame end
    end

    function CreateFrame(kind)
        local widget = NewWidget()
        if not mock.eventFrame then
            mock.eventFrame = widget
            function widget:SetScript(_, callback) self.callback = callback end
        elseif kind == "Frame" then
            mock.canvas = widget
        end
        return widget
    end

    WOW_PROJECT_CLASSIC = 2
    WOW_PROJECT_ID = projectID
    Settings = {
        VarType = { Boolean = "boolean", String = "string" },
        RegisterVerticalLayoutCategory = function(name)
            mock.verticalName = name
            return { GetID = function() return 7 end }
        end,
        RegisterCanvasLayoutCategory = function(_, name)
            mock.canvasName = name
            return { GetID = function() return 8 end }
        end,
        RegisterAddOnCategory = function(category) mock.registeredCategory = category end,
        RegisterAddOnSetting = function(_, variable, key, tbl, varType, name, default)
            local setting = { variable = variable, key = key, varType = varType, name = name, default = default }
            function setting:GetValue() return tbl[key] end
            function setting:SetValue(value)
                tbl[key] = value
                if self.callback then self.callback(self, value) end
            end
            function setting:SetValueChangedCallback(callback) self.callback = callback end
            mock.settings[key] = setting
            return setting
        end,
        CreateCheckbox = function(_, setting, tooltip)
            mock.controls[#mock.controls + 1] = { kind = "checkbox", setting = setting, tooltip = tooltip }
        end,
        CreateDropdown = function(_, setting, options, tooltip)
            mock.controls[#mock.controls + 1] =
                { kind = "dropdown", setting = setting, options = options, tooltip = tooltip }
        end,
        CreateControlTextContainer = function()
            local data = {}
            return {
                Add = function(_, value, label) data[#data + 1] = { value = value, label = label } end,
                GetData = function() return data end,
            }
        end,
    }

    if customize then customize(Settings) end

    assert(loadfile("YardsToKm.lua"))("YardsToKm")
    -- A 1.0 save: no display or decimal keys.
    YardsToKmDB = { enabled = true, unitMode = "auto", precision = "compact" }
    mock.eventFrame.callback(mock.eventFrame, "ADDON_LOADED", "YardsToKm")
    return mock
end

-- Forever / Mainline: native page with one checkbox and four dropdowns.
local mock = InstallMocks(1)
assert(mock.verticalName == "Yards to Kilometers", tostring(mock.verticalName))
assert(mock.canvasName == nil, "built the fallback page on Mainline")
assert(#mock.controls == 5, #mock.controls)
assert(mock.controls[1].kind == "checkbox" and mock.controls[1].setting.key == "enabled")
assert(mock.controls[1].setting.varType == "boolean" and mock.controls[1].setting.default == true)
local expected = { { "unitMode", "Units", "auto", 2 }, { "precision", "Number precision", "compact", 2 },
    { "display", "Display", "replace", 2 }, { "decimal", "Decimal separator", "point", 2 } }
for index, want in ipairs(expected) do
    local control = mock.controls[index + 1]
    assert(control.kind == "dropdown", control.kind)
    assert(control.setting.key == want[1] and control.setting.name == want[2], control.setting.key)
    assert(control.setting.default == want[3] and control.setting.varType == "string")
    assert(control.setting.variable == "YardsToKm_" .. want[1], control.setting.variable)
    assert(#control.options() == want[4] and control.tooltip, want[1])
end
assert(mock.controls[4].options()[2].label == "Yards and metric")
-- Saved-variable defaults are in place before the page reads them.
assert(mock.settings.display:GetValue() == "replace")

-- Choosing a dropdown value converts text with the new setting.
mock.line:SetText("Range: 30 yd")
assert(mock.line.text == "Range: 27 m", mock.line.text)
mock.settings.display:SetValue("both")
assert(YardsToKmDB.display == "both")
assert(mock.line.text == "Range: 30 yd (27 m)", mock.line.text)
mock.settings.enabled:SetValue(false)
assert(mock.line.text == "Range: 30 yd", mock.line.text)

-- Slash commands move the native controls too.
SlashCmdList.YARDSTOKM("on")
assert(mock.settings.enabled:GetValue() == true)
SlashCmdList.YARDSTOKM("comma")
assert(mock.settings.decimal:GetValue() == "comma")
SlashCmdList.YARDSTOKM("replace")
assert(mock.line.text == "Range: 27 m", mock.line.text)
YardsToKm_OnAddonCompartmentClick("YardsToKm", "RightButton")
assert(mock.settings.enabled:GetValue() == false)

-- Classic Era: the canvas page with cycling buttons, as before.
mock = InstallMocks(2)
assert(mock.verticalName == nil, "built the native page on Classic Era")
assert(mock.canvasName == "Yards to Kilometers", tostring(mock.canvasName))

-- A native API failure falls back to the canvas page and says why.
mock = InstallMocks(1, function(api)
    api.CreateDropdown = function() error("bad dropdown") end
end)
assert(mock.canvasName == "Yards to Kilometers", "no fallback page after a native error")
assert(mock.registeredCategory.GetID() == 8, "registered the broken native page")
assert(mock.messages[1]:find("basic settings page", 1, true) and mock.messages[1]:find("bad dropdown", 1, true),
    tostring(mock.messages[1]))

-- A client missing part of the native API uses the canvas page quietly.
mock = InstallMocks(1, function(api) api.CreateDropdown = nil end)
assert(mock.canvasName == "Yards to Kilometers" and #mock.messages == 0)

print("Native settings, slash sync, and Classic Era fallback passed")
