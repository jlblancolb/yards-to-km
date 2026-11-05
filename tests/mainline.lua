-- Mocks Mainline (Retail / WoW Forever) behavior: no OnTooltipSetSpell,
-- tooltip data post-calls, forbidden frames, and secret text values.
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
C_Timer = { NewTicker = function() end }

local secret = setmetatable({}, {
    __index = function() error("attempt to index a secret value") end,
    __tostring = function() error("attempt to stringify a secret value") end,
})
function issecretvalue(value) return value == secret end

function hooksecurefunc(object, method, callback)
    local original = object[method]
    object[method] = function(self, ...)
        original(self, ...)
        callback(self, ...)
    end
end

local function NewFontString(value)
    local fontString = { text = value }
    function fontString:IsObjectType(kind) return kind == "FontString" end
    function fontString:GetText() return self.text end
    function fontString:SetText(newText) self.text = newText end
    function fontString:SetFormattedText(format, ...) self.text = string.format(format, ...) end
    return fontString
end

local line = NewFontString("")
local tooltip = { scripts = {} }
function tooltip:IsObjectType(kind) return kind == "GameTooltip" end
function tooltip:IsForbidden() return false end
function tooltip:GetRegions() return line end
function tooltip:HasScript(event) return event ~= "OnTooltipSetSpell" end
function tooltip:HookScript(event, callback) self.scripts[event] = callback end

local forbidden = {}
function forbidden:IsForbidden() return true end
function forbidden:IsObjectType() error("touched a forbidden frame") end
function forbidden:GetRegions() error("touched a forbidden frame") end

local frames = { forbidden, tooltip }
function EnumerateFrames(previous)
    for index, frame in ipairs(frames) do
        if frame == previous then return frames[index + 1] end
    end
    if not previous then return frames[1] end
end

local postCalls = {}
Enum = { TooltipDataType = { Spell = 1 } }
TooltipDataProcessor = {
    AddTooltipPostCall = function(kind, callback) postCalls[kind] = callback end,
}

local eventFrame = {}
function eventFrame:RegisterEvent() end
function eventFrame:SetScript(_, callback) self.callback = callback end
function CreateFrame() return eventFrame end

assert(loadfile("YardsToKm.lua"))("YardsToKm")
eventFrame.callback(eventFrame, "ADDON_LOADED", "YardsToKm")
assert(tooltip.scripts.OnTooltipSetSpell == nil)
assert(postCalls[Enum.TooltipDataType.Spell], "Spell tooltip post-call not registered")

line.text = "8-35 yd range"
postCalls[Enum.TooltipDataType.Spell](tooltip)
assert(line.text == "7 m - 32 m range", line.text)

-- Secret text must be left alone without erroring, on every code path.
line.text = secret
postCalls[Enum.TooltipDataType.Spell](tooltip)
tooltip.scripts.OnUpdate(tooltip, 0.1)
line:SetText(secret)
SlashCmdList.YARDSTOKM("off")
SlashCmdList.YARDSTOKM("on")
SlashCmdList.YARDSTOKM("scan")
assert(line.text == secret)

line:SetText("30 yd range")
assert(line.text == "27 m range", tostring(line.text))
print("Mainline tooltip data, forbidden frames, and secret values passed")
