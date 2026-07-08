--[[
* Fush - XIUI-inspired theme for config ImGui styling
]]--

require('common');
local imgui = require('imgui');

local M = {};

M.colors = {
    bg_dark       = { 0.004, 0.071, 0.169, 0.92 },
    bg_mid        = { 0.024, 0.110, 0.224, 0.95 },
    bg_light      = { 0.050, 0.160, 0.300, 0.90 },
    border        = { 0.35, 0.55, 0.85, 0.65 },
    text          = { 0.92, 0.94, 0.98, 1.00 },
    text_dim      = { 0.65, 0.72, 0.82, 1.00 },
    text_gold     = { 0.95, 0.82, 0.35, 1.00 },
    accent        = { 0.20, 0.55, 0.95, 1.00 },
    bar_fill      = { 0.12, 0.45, 0.85, 1.00 },
};

function M.hex_to_imgui(hex)
    local clean = hex:gsub('#', '');
    return {
        tonumber(clean:sub(1, 2), 16) / 255,
        tonumber(clean:sub(3, 4), 16) / 255,
        tonumber(clean:sub(5, 6), 16) / 255,
        1.0,
    };
end

function M.apply_style()
    local style = imgui.GetStyle();
    style.WindowRounding = 6;
    style.ChildRounding = 4;
    style.FrameRounding = 4;
    style.GrabRounding = 4;
    style.WindowBorderSize = 1;
    style.FrameBorderSize = 1;
    style.WindowPadding = { 10, 10 };
    style.ItemSpacing = { 8, 6 };

    local c = M.colors;
    imgui.PushStyleColor(ImGuiCol_WindowBg, c.bg_mid);
    imgui.PushStyleColor(ImGuiCol_ChildBg, c.bg_dark);
    imgui.PushStyleColor(ImGuiCol_Border, c.border);
    imgui.PushStyleColor(ImGuiCol_FrameBg, c.bg_dark);
    imgui.PushStyleColor(ImGuiCol_FrameBgHovered, c.bg_light);
    imgui.PushStyleColor(ImGuiCol_FrameBgActive, c.bg_light);
    imgui.PushStyleColor(ImGuiCol_TitleBg, c.bg_dark);
    imgui.PushStyleColor(ImGuiCol_TitleBgActive, c.bg_mid);
    imgui.PushStyleColor(ImGuiCol_Header, c.bg_light);
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, c.accent);
    imgui.PushStyleColor(ImGuiCol_HeaderActive, c.accent);
    imgui.PushStyleColor(ImGuiCol_Button, c.bg_light);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, c.accent);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, c.bar_fill);
    imgui.PushStyleColor(ImGuiCol_CheckMark, c.text_gold);
    imgui.PushStyleColor(ImGuiCol_SliderGrab, c.bar_fill);
    imgui.PushStyleColor(ImGuiCol_SliderGrabActive, c.accent);
    imgui.PushStyleColor(ImGuiCol_Tab, c.bg_dark);
    imgui.PushStyleColor(ImGuiCol_TabHovered, c.accent);
    imgui.PushStyleColor(ImGuiCol_TabActive, c.bg_light);
    imgui.PushStyleColor(ImGuiCol_Text, c.text);

    return 20;
end

function M.pop_style(count)
    imgui.PopStyleColor(count or 20);
end

return M;
