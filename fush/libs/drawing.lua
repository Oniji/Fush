--[[
* Drawing helpers (adapted from XIUI)
* https://github.com/tirem/XIUI — GNU GPL v3
]]--

local imgui = require('imgui');

local M = {};

local editor_open = nil;

function M.set_editor_open(ref)
    editor_open = ref;
end

function M.GetUIDrawList()
    if editor_open and editor_open[1] then
        return imgui.GetBackgroundDrawList();
    end
    return imgui.GetForegroundDrawList();
end

return M;
