--[[
* Drawing helpers (adapted from XIUI)
* https://github.com/tirem/XIUI — GNU GPL v3
]]--

local imgui = require('imgui');

local M = {};

function M.GetUIDrawList()
    -- Always use background draw list for panel/backdrop primitives so text
    -- rendered by ImGui windows stays on top and does not look faded.
    return imgui.GetBackgroundDrawList();
end

return M;
