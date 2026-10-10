SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
C_Timer = { NewTicker = function() end }

function hooksecurefunc(object, method, callback)
    local original = object[method]
    object[method] = function(self, ...)
        original(self, ...)
        callback(self, ...)
    end
end

local text = { text = "" }
function text:IsObjectType(kind) return kind == "FontString" end
function text:GetText() return self.text end
function text:SetText(value) self.text = value end
function text:SetFormattedText(format, ...)
    self.text = string.format(format, ...)
end

local tooltip = { scripts = {} }
local label = { text = "Compact" }
setmetatable(label, { __index = text })
function tooltip:IsObjectType(kind) return kind == "GameTooltip" end
function tooltip:GetRegions() return text, label end
function tooltip:HasScript() return true end
function tooltip:HookScript(event, callback) self.scripts[event] = callback end

function EnumerateFrames(previous)
    if not previous then return tooltip end
end

local eventFrame = {}
function eventFrame:RegisterEvent() end
function eventFrame:SetScript(_, callback) self.callback = callback end
function CreateFrame() return eventFrame end

assert(loadfile("YardsToKm.lua"))("YardsToKm")
eventFrame.callback(eventFrame, "ADDON_LOADED", "YardsToKm")

-- Simulate native writes: no SetText or SetFormattedText call.
text.text = "8-35 yd range"
tooltip.scripts.OnTooltipSetSpell(tooltip)
assert(text.text == "7 m - 32 m range", text.text)

tooltip.scripts.OnUpdate(tooltip, 0.1)
-- Button:SetText can change its label natively, bypassing FontString hooks.
label.text = "Precise"
SlashCmdList.YARDSTOKM("off")
assert(text.text == "8-35 yd range", text.text)
assert(label.text == "Precise", "Settings refresh restored a stale button label")
SlashCmdList.YARDSTOKM("on")
assert(text.text == "7 m - 32 m range", text.text)
assert(label.text == "Precise", "Enabling conversion changed an unrelated label")

text.text = "40 yd range"
tooltip.scripts.OnUpdate(tooltip, 0.05)
assert(text.text == "40 yd range", text.text)
tooltip.scripts.OnUpdate(tooltip, 0.05)
assert(text.text == "37 m range", text.text)

text:SetFormattedText("%d-%d yd range", 8, 35)
assert(text.text == "7 m - 32 m range", text.text)
text:SetText(nil)
tooltip.scripts.OnUpdate(tooltip, 0.1)
assert(text.text == nil)

text.text = "30 yd range"
tooltip.scripts.OnShow(tooltip)
assert(text.text == "27 m range", text.text)
print("Tooltip native writes, formatted text, polling, and restoration passed")
