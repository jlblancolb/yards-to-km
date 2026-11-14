-- Frame scan: stays within a time budget per game frame and resumes later,
-- so thousands of addon frames can't trigger "script ran too long".
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
function hooksecurefunc() end

local pending = {}
C_Timer = {
    NewTicker = function() end,
    After = function(_, callback) pending[#pending + 1] = callback end,
}

-- Each frame visited costs 1 ms of fake time.
local now = 0
function debugprofilestop() return now end

local FRAME_COUNT = 50
local frames, visited = {}, {}
for index = 1, FRAME_COUNT do
    local frame = { index = index }
    function frame:IsForbidden() return false end
    function frame:IsObjectType() return false end
    function frame:GetRegions()
        now = now + 1
        visited[self.index] = (visited[self.index] or 0) + 1
    end
    frames[index] = frame
end

function EnumerateFrames(previous)
    return frames[previous and previous.index + 1 or 1]
end

local eventFrame
function CreateFrame()
    local frame = setmetatable({}, { __index = function() return function() end end })
    eventFrame = eventFrame or frame
    function frame:SetScript(_, callback) self.callback = callback end
    return frame
end

assert(loadfile("YardsToKm.lua"))("YardsToKm")
eventFrame.callback(eventFrame, "ADDON_LOADED", "YardsToKm")

assert(#pending == 1, "scan did not yield after its time budget")
assert(not visited[FRAME_COUNT], "scan visited every frame in one call")

-- A scan requested while one is running doesn't start over.
SlashCmdList.YARDSTOKM("scan")
assert(visited[1] == 1, "a second scan restarted the running one")

local slices = 1
while #pending > 0 do
    local callback = table.remove(pending, 1)
    callback()
    slices = slices + 1
end
assert(slices > 2, "expected the scan to span several game frames")
for index = 1, FRAME_COUNT do
    assert(visited[index] == 1, "frame " .. index .. " visited " .. tostring(visited[index]) .. " times")
end

-- Once finished, a new scan starts from the first frame again.
SlashCmdList.YARDSTOKM("scan")
assert(visited[1] == 2, "a finished scan could not be started again")

print("Frame scan time budget and resume passed")
