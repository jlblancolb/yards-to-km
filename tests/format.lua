-- Conversion formatting, slash commands, and saved-variable defaults.
SlashCmdList = {}
local messages = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) messages[#messages + 1] = message end }
C_Timer = { NewTicker = function() end }
YardsToKmDB = { enabled = "yes", unitMode = "miles", precision = 7 }

function hooksecurefunc(object, method, callback)
    local original = object[method]
    object[method] = function(self, ...)
        original(self, ...)
        callback(self, ...)
    end
end

local line = { text = "" }
function line:IsObjectType(kind) return kind == "FontString" end
function line:GetText() return self.text end
function line:SetText(value) self.text = value end

local frame = {}
function frame:IsObjectType() return false end
function frame:GetRegions() return line end
function EnumerateFrames(previous)
    if not previous then return frame end
end

local eventFrame = {}
function eventFrame:RegisterEvent() end
function eventFrame:SetScript(_, callback) self.callback = callback end
function CreateFrame() return eventFrame end

assert(loadfile("YardsToKm.lua"))("YardsToKm")
eventFrame.callback(eventFrame, "ADDON_LOADED", "YardsToKm")

-- Invalid saved values fall back to defaults; existing truthy values are kept.
assert(YardsToKmDB.enabled == "yes")
assert(YardsToKmDB.unitMode == "auto", YardsToKmDB.unitMode)
assert(YardsToKmDB.precision == "compact", tostring(YardsToKmDB.precision))

local function check(input, expected)
    line:SetText(input)
    assert(line.text == expected, ("%q -> %q, expected %q"):format(input, line.text, expected))
end

local function mode(...)
    for _, command in ipairs({ ... }) do SlashCmdList.YARDSTOKM(command) end
end

mode("auto", "compact")
check("30 yd range", "27 m range")
check("Range 30 yards.", "Range 27 m.")
check("1 Yard", "1 m")
check("5yds", "5 m")
check("1,093 yards", "999 m")
check("1,094 yards", "1 km")
check("10,000 yards away", "9.144 km away")
check("2.5 yd", "2 m")
check("8-35 yd range", "7 m - 32 m range")
check("8 – 35 yards", "7 m - 32 m")
check("8—35 yd", "7 m - 32 m")
check("No distance here", "No distance here")
check("Lasts 30 sec", "Lasts 30 sec")
check("30 yardsticks", "30 yardsticks")
check("|Hspell:1|h[30 yd]|h", "|Hspell:1|h[30 yd]|h")
check("|TInterface\\Icon:0|t 30 yd", "|TInterface\\Icon:0|t 30 yd")

mode("precise")
check("30 yd", "27.4 m")
check("10,000 yards", "9.144 km")
check("1,100 yards", "1.0058 km")

mode("km", "compact")
check("30 yd", "0.027 km")
mode("precise")
check("30 yd", "0.0274 km")

mode("off")
assert(line.text == "30 yd", line.text)
mode("on", "auto", "compact")
assert(line.text == "27 m", line.text)

messages = {}
SlashCmdList.YARDSTOKM("")
assert(messages[1]:find("conversion on, units automatic %(m / km%), precision compact%."), messages[1])
assert(messages[2]:find("commands:"), messages[2])
print("Formatting, slash commands, and saved-variable defaults passed")
