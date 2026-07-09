--[[
* Fush - Theme palettes and config menu styling
* Colors adapted from XIUI config.lua (https://github.com/tirem/XIUI), GPLv3.
]]--

require('common');
local imgui = require('imgui');

local M = {};

M.palettes = {
    DarkGold = {
        gold = { 0.957, 0.855, 0.592, 1.0 },       -- #F4DA97
        gold_dark = { 0.765, 0.684, 0.474, 1.0 },  -- #C3AE79
        gold_darker = { 0.573, 0.512, 0.355, 1.0 }, -- #92835B
        bg_dark = { 0.051, 0.051, 0.051, 0.95 },   -- #0D0D0D
        bg_medium = { 0.098, 0.090, 0.075, 1.0 },  -- #191713
        bg_light = { 0.137, 0.125, 0.106, 1.0 },   -- #23201B
        bg_lighter = { 0.176, 0.161, 0.137, 1.0 }, -- #2D2923
        text_light = { 0.878, 0.855, 0.812, 1.0 }, -- #E0DACF
        text_muted = { 0.6, 0.58, 0.54, 1.0 },
        border_dark = { 0.3, 0.275, 0.235, 1.0 },  -- #4D463C
        border_gold = { 0.957, 0.855, 0.592, 0.85 },
        panel_bg_hex = '#0D0D0D',
        panel_border_hex = '#F4DA97',
        default_bg_opacity = 0.92,
        bar_fill = { 0.22, 0.60, 0.81, 1.0 },
    },
    OceanBlue = {
        gold = { 1.0, 0.886, 0.278, 1.0 },         -- #FFE247 bright yellow/gold
        gold_dark = { 1.0, 0.843, 0.0, 1.0 },      -- #FFD700
        gold_darker = { 0.85, 0.65, 0.05, 1.0 },
        bg_dark = { 0.035, 0.12, 0.38, 0.95 },     -- royal blue config bg
        bg_medium = { 0.06, 0.18, 0.48, 1.0 },
        bg_light = { 0.10, 0.26, 0.58, 1.0 },
        bg_lighter = { 0.15, 0.34, 0.70, 1.0 },
        text_light = { 0.92, 0.95, 1.0, 1.0 },
        text_muted = { 0.70, 0.78, 0.92, 1.0 },
        border_dark = { 0.20, 0.35, 0.70, 1.0 },
        border_gold = { 1.0, 0.886, 0.278, 0.95 }, -- bright yellow/gold trim
        panel_bg_hex = '#163A9C',                  -- royal blue
        panel_border_hex = '#FFE247',
        default_bg_opacity = 0.30,
        bar_fill = { 0.25, 0.55, 0.95, 1.0 },
    },
};

local function apply_palette(p)
    M.gold = p.gold;
    M.gold_dark = p.gold_dark;
    M.gold_darker = p.gold_darker;
    M.bg_dark = p.bg_dark;
    M.bg_medium = p.bg_medium;
    M.bg_light = p.bg_light;
    M.bg_lighter = p.bg_lighter;
    M.text_light = p.text_light;
    M.text_muted = p.text_muted;
    M.border_dark = p.border_dark;
    M.border_gold = p.border_gold;
    M.panel_bg_hex = p.panel_bg_hex;
    M.panel_border_hex = p.panel_border_hex;
    M.default_bg_opacity = p.default_bg_opacity;

    M.colors = {
        bg_dark       = p.bg_dark,
        bg_mid        = p.bg_medium,
        bg_light      = p.bg_light,
        border        = p.border_gold,
        border_gold   = p.border_gold,
        text          = p.text_light,
        text_light    = p.text_light,
        text_dim      = p.text_muted,
        text_gold     = p.gold,
        accent        = p.gold,
        bar_fill      = p.bar_fill,
    };
end

apply_palette(M.palettes.DarkGold);
M.active_name = 'DarkGold';

function M.set_active(theme_name)
    local palette = M.palettes[theme_name];
    if palette == nil then
        palette = M.palettes.DarkGold;
        theme_name = 'DarkGold';
    end
    if M.active_name == theme_name then
        return;
    end
    apply_palette(palette);
    M.active_name = theme_name;
end

function M.get_palette(theme_name)
    return M.palettes[theme_name] or M.palettes.DarkGold;
end

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
    style.WindowBorderSize = 1;
    style.ChildBorderSize = 1;
    style.FrameBorderSize = 1;
    style.TabBorderSize = 1;

    local g = M.gold;
    local tab_active = { g[1], g[2], g[3], 0.3 };

    imgui.PushStyleColor(ImGuiCol_WindowBg, M.bg_dark);
    imgui.PushStyleColor(ImGuiCol_ChildBg, { 0, 0, 0, 0 });
    imgui.PushStyleColor(ImGuiCol_TitleBg, M.bg_medium);
    imgui.PushStyleColor(ImGuiCol_TitleBgActive, M.bg_light);
    imgui.PushStyleColor(ImGuiCol_TitleBgCollapsed, M.bg_dark);
    imgui.PushStyleColor(ImGuiCol_FrameBg, M.bg_medium);
    imgui.PushStyleColor(ImGuiCol_FrameBgHovered, M.bg_light);
    imgui.PushStyleColor(ImGuiCol_FrameBgActive, M.bg_lighter);
    imgui.PushStyleColor(ImGuiCol_Header, M.bg_light);
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, M.bg_lighter);
    imgui.PushStyleColor(ImGuiCol_HeaderActive, tab_active);
    imgui.PushStyleColor(ImGuiCol_Border, M.border_gold);
    imgui.PushStyleColor(ImGuiCol_Text, M.text_light);
    imgui.PushStyleColor(ImGuiCol_TextDisabled, M.gold_dark);
    imgui.PushStyleColor(ImGuiCol_Button, M.bg_medium);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, M.bg_light);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, M.bg_lighter);
    imgui.PushStyleColor(ImGuiCol_CheckMark, M.gold);
    imgui.PushStyleColor(ImGuiCol_SliderGrab, M.gold_dark);
    imgui.PushStyleColor(ImGuiCol_SliderGrabActive, M.gold);
    imgui.PushStyleColor(ImGuiCol_ScrollbarBg, M.bg_medium);
    imgui.PushStyleColor(ImGuiCol_ScrollbarGrab, M.bg_lighter);
    imgui.PushStyleColor(ImGuiCol_ScrollbarGrabHovered, M.border_dark);
    imgui.PushStyleColor(ImGuiCol_ScrollbarGrabActive, M.gold_dark);
    imgui.PushStyleColor(ImGuiCol_Separator, M.border_dark);
    imgui.PushStyleColor(ImGuiCol_PopupBg, M.bg_medium);
    imgui.PushStyleColor(ImGuiCol_Tab, M.bg_medium);
    imgui.PushStyleColor(ImGuiCol_TabHovered, M.bg_light);
    imgui.PushStyleColor(ImGuiCol_TabActive, tab_active);
    imgui.PushStyleColor(ImGuiCol_TabUnfocused, M.bg_dark);
    imgui.PushStyleColor(ImGuiCol_TabUnfocusedActive, M.bg_medium);
    imgui.PushStyleColor(ImGuiCol_ResizeGrip, M.gold_darker);
    imgui.PushStyleColor(ImGuiCol_ResizeGripHovered, M.gold_dark);
    imgui.PushStyleColor(ImGuiCol_ResizeGripActive, M.gold);

    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 12, 12 });
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 6, 4 });
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 8, 6 });
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, 4.0);
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 6.0);
    imgui.PushStyleVar(ImGuiStyleVar_ChildRounding, 4.0);
    imgui.PushStyleVar(ImGuiStyleVar_PopupRounding, 4.0);
    imgui.PushStyleVar(ImGuiStyleVar_ScrollbarRounding, 4.0);
    imgui.PushStyleVar(ImGuiStyleVar_GrabRounding, 4.0);

    return { colors = 34, vars = 9 };
end

function M.pop_style(counts)
    counts = counts or { colors = 34, vars = 9 };
    imgui.PopStyleVar(counts.vars or 9);
    imgui.PopStyleColor(counts.colors or 34);
end

return M;
