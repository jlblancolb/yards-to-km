-- Addon compartment handlers: open settings (deferred in combat), toggle, tooltip.
SlashCmdList = {}
local messages = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) messages[#messages + 1] = message end }
C_Timer = { NewTicker = function() end }
function hooksecurefunc() end
function EnumerateFrames() end

-- Widgets accept any method call; only the ones the test reads are recorded.
local function NewWidget()
    local widget = {}
    return setmetatable(widget, { __index = function(_, method)
        if method == "CreateFontString" then
            return function() return NewWidget() end
        end
        return function() end
    end })
end

local eventFrame
function CreateFrame()
    local frame = NewWidget()
    if not eventFrame then
        eventFrame = frame
        function frame:SetScript(_, callback) self.callback = callback end
    end
    return frame
end

local opened = {}
local category = { GetID = function() return 42 end }
Settings = {
    RegisterCanvasLayoutCategory = function() return category end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function(id) opened[#opened + 1] = id end,
}

local inCombat = false
function InCombatLockdown() return inCombat end

local lines = {}
GameTooltip = {
    SetOwner = function() end,
    SetText = function(_, text) lines = { text } end,
    AddLine = function(_, text) lines[#lines + 1] = text end,
    Show = function() end,
    Hide = function() lines = {} end,
}

assert(loadfile("YardsToKm.lua"))("YardsToKm")
YardsToKmDB = { enabled = true }
eventFrame.callback(eventFrame, "ADDON_LOADED", "YardsToKm")

-- The TOC names these globals; a typo there would silently drop the menu entry.
-- fengari (the local fallback runner) has no io.open; CI's Lua 5.1 does.
if io.open then
    local toc = assert(io.open("YardsToKm.toc")):read("*a")
    for field, name in toc:gmatch("## (AddonCompartmentFunc%a*): (%S+)") do
        assert(type(_G[name]) == "function", field .. " names a missing function: " .. name)
    end
    assert(toc:find("AddonCompartmentFuncOnLeave", 1, true), "TOC lacks compartment fields")
end

YardsToKm_OnAddonCompartmentClick("YardsToKm", "LeftButton")
assert(opened[1] == 42, "left-click did not open settings")

inCombat = true
YardsToKm_OnAddonCompartmentClick("YardsToKm", "LeftButton")
assert(#opened == 1, "settings opened during combat")
assert(messages[#messages]:find("when combat ends", 1, true), messages[#messages])
inCombat = false
eventFrame.callback(eventFrame, "PLAYER_REGEN_ENABLED")
assert(#opened == 2, "settings did not open after combat")
eventFrame.callback(eventFrame, "PLAYER_REGEN_ENABLED")
assert(#opened == 2, "settings reopened on a later combat end")

YardsToKm_OnAddonCompartmentClick("YardsToKm", "RightButton")
assert(YardsToKmDB.enabled == false, "right-click did not disable conversion")
YardsToKm_OnAddonCompartmentEnter("YardsToKm", {})
assert(lines[1] == "Yards to Kilometers" and lines[2] == "Conversion off", tostring(lines[2]))
YardsToKm_OnAddonCompartmentLeave()
YardsToKm_OnAddonCompartmentClick("YardsToKm", "RightButton")
assert(YardsToKmDB.enabled == true, "right-click did not re-enable conversion")

print("Addon compartment click, combat deferral, toggle, and tooltip passed")
