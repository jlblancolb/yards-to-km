std = "lua51"
max_line_length = 120

files["YardsToKm.lua"] = {
    globals = {
        "YardsToKmDB", "SLASH_YARDSTOKM1", "SlashCmdList", "YardsToKm_OnAddonCompartmentClick",
        "YardsToKm_OnAddonCompartmentEnter", "YardsToKm_OnAddonCompartmentLeave",
    },
    read_globals = {
        "C_Timer", "CreateFrame", "DEFAULT_CHAT_FRAME", "EnumerateFrames", "Enum",
        "GameTooltip", "hooksecurefunc", "InCombatLockdown", "issecretvalue", "Settings", "TooltipDataProcessor",
    },
}

-- Tests install WoW API mocks as globals.
files["tests"] = { allow_defined_top = true, ignore = { "11", "212" } }
