--[[
* Fush - Bite type and feeling tracker
]]--

require('common');
local ui = require('libs.ui');
local drawing = require('libs.drawing');
local colorLib = require('libs.color');
local imgui = require('imgui');

local M = {
    last_size = { w = 180, h = 28 },
    last_left_w = 90,
    last_right_w = 90,
};

M.state = {
    active = false,
    hook = 'Unknown',
    hook_color = '#738299',
    feel = 'Unknown',
    feel_color = '#738299',
};

local PREVIEW = {
    hook = 'Large Fish',
    hook_color = '#44ff88',
    feel = 'Good',
    feel_color = '#44ff88',
};

local CORNER_LEFT = ImDrawCornerFlags_Left;
local CORNER_RIGHT = ImDrawCornerFlags_Right;

-- Longest typical label; both halves use this width so text never clips.
local SIZING_LABEL = 'Large Fish';
-- Extra horizontal room beyond the label at scale 1.0 (each side).
local BASE_H_PAD = 12;
local BASE_V_PAD = 5;

local function clamp01(v)
    if v < 0 then
        return 0;
    end
    if v > 1 then
        return 1;
    end
    return v;
end

-- Slightly darken a hex color for the right half so matching colors stay distinct.
local RIGHT_DARKEN = 0.82;

local function darken_hex(hex, factor)
    factor = factor or RIGHT_DARKEN;
    local col = colorLib.HexToImGui(hex);
    local r = math.floor(clamp01((col[1] or 1) * factor) * 255 + 0.5);
    local g = math.floor(clamp01((col[2] or 1) * factor) * 255 + 0.5);
    local b = math.floor(clamp01((col[3] or 1) * factor) * 255 + 0.5);
    return string.format('#%02X%02X%02X', r, g, b);
end

local function color_to_u32(hex_or_vec, alpha)
    local col;
    if type(hex_or_vec) == 'string' then
        col = colorLib.HexToImGui(hex_or_vec);
    else
        col = hex_or_vec;
    end

    local r = math.floor(clamp01(col[1] or 1) * 255 + 0.5);
    local g = math.floor(clamp01(col[2] or 1) * 255 + 0.5);
    local b = math.floor(clamp01(col[3] or 1) * 255 + 0.5);
    local a = math.floor(clamp01(alpha or col[4] or 0.92) * 255 + 0.5);
    -- IM_COL32 packs as ABGR in memory.
    return bit.bor(bit.lshift(a, 24), bit.lshift(b, 16), bit.lshift(g, 8), r);
end

function M.reset()
    M.state.active = false;
    M.state.hook = 'Unknown';
    M.state.hook_color = '#738299';
    M.state.feel = 'Unknown';
    M.state.feel_color = '#738299';
end

function M.deactivate()
    M.state.active = false;
end

function M.get_hook_type()
    return M.state.hook;
end

function M.is_fish_hook()
    return M.state.hook == 'Small Fish' or M.state.hook == 'Large Fish';
end

--- Match HOOK_MESSAGES / FEEL_MESSAGES; sets chat logcolor and overlay state.
function M.handle_text(e)
    if e.injected then
        return nil;
    end

    local constants = require('constants');

    for _, entry in ipairs(constants.HOOK_MESSAGES) do
        if string.match(e.message, entry.message) ~= nil then
            M.state.feel = 'Unknown';
            M.state.feel_color = '#738299';
            M.state.hook = entry.hook;
            M.state.hook_color = entry.color;
            M.state.active = true;
            e.mode_modified = entry.logcolor;
            return 'hook', entry.hook;
        end
    end

    for _, entry in ipairs(constants.FEEL_MESSAGES) do
        if string.match(e.message, entry.message) ~= nil then
            M.state.feel = entry.feel;
            M.state.feel_color = entry.color;
            e.mode_modified = entry.logcolor;
            return 'feel', entry.feel;
        end
    end

    return nil;
end

--- Clear overlay on zone (0x00A) or when status packet says not fishing.
function M.handle_packet(e)
    local constants = require('constants');

    if e.id == constants.PACKET_ZONE then
        M.deactivate();
        return;
    end

    if e.id == constants.PACKET_STATUS then
        -- 0x037 status byte at +0x30: 0 = idle / not fishing.
        if struct.unpack('B', e.data, 0x30 + 1) == 0 then
            M.deactivate();
        end
    end
end

local function get_display_state(preview)
    if preview then
        return PREVIEW.hook, PREVIEW.hook_color, PREVIEW.feel, PREVIEW.feel_color;
    end
    return M.state.hook, M.state.hook_color, M.state.feel, M.state.feel_color;
end

local function get_feel_label(feel)
    if feel == nil or feel == '' or feel == 'Unknown' then
        return '—';
    end
    return feel;
end

local function get_bg_opacity(settings)
    local opts = ui.get_background_options(settings, 'bite');
    return opts.bgOpacity or 0.92;
end

local function get_rounding(settings)
    local opts = ui.get_background_options(settings, 'bite');
    return opts.panelRounding or 6;
end

local function measure_scaled(text, scale)
    local w, h = ui.measure_text(text);
    return w * scale, h * scale;
end

local function draw_half(draw_list, x, y, w, h, color_hex, text, scale, rounding, corners, opacity)
    draw_list:AddRectFilled(
        { x, y },
        { x + w, y + h },
        color_to_u32(color_hex, opacity),
        rounding,
        corners
    );

    local text_w, text_h = measure_scaled(text, scale);
    local tx = x + math.max(0, (w - text_w) / 2);
    local ty = y + math.max(0, (h - text_h) / 2);

    -- DrawList AddText ignores SetWindowFontScale; bake scale into font size.
    local font = imgui.GetFont();
    local font_size = imgui.GetFontSize() * scale;
    if font ~= nil and draw_list.AddText ~= nil then
        local ok = pcall(function()
            local outline = color_to_u32({ 0, 0, 0, 0.75 }, 0.75);
            local fill = color_to_u32({ 1, 1, 1, 1 }, 1);
            for _, off in ipairs({ { -1, -1 }, { -1, 0 }, { -1, 1 }, { 0, -1 }, { 0, 1 }, { 1, -1 }, { 1, 0 }, { 1, 1 } }) do
                draw_list:AddText(font, font_size, { tx + off[1], ty + off[2] }, outline, text);
            end
            draw_list:AddText(font, font_size, { tx, ty }, fill, text);
        end);
        if ok then
            return;
        end
    end

    ui.draw_text_outlined(
        draw_list,
        tx,
        ty,
        text,
        { 1, 1, 1, 1 },
        { 0, 0, 0, 0.75 },
        1
    );
end

--- Split hook | feel bar; stored X is the seam between halves.
function M.render(settings, preview)
    if not settings.bite.visible[1] and not preview then
        return;
    end

    if not preview and not M.state.active then
        return;
    end

    local hook, hook_color, feel, feel_color = get_display_state(preview);
    local feel_label = get_feel_label(feel);
    -- Stored X is the shared seam between left/right halves.
    local seam_x = settings.bite.x[1];
    local y = settings.bite.y[1];
    -- Appearance Scale x Font Size scale so panel + text grow together.
    local scale = ui.get_module_scale(settings, 'bite');
    local h_pad = math.max(BASE_H_PAD, ui.get_padding(settings, 'bite')) * scale;
    local v_pad = math.max(BASE_V_PAD, math.floor(ui.get_padding(settings, 'bite') * 0.45)) * scale;
    local opacity = get_bg_opacity(settings);
    local rounding = get_rounding(settings) * scale;
    local draw_list = drawing.GetUIDrawList();

    local ref_w, line_h = measure_scaled(SIZING_LABEL, scale);
    -- Equal fixed halves: sized for "Large Fish" + padding at current scale.
    local half_w = ref_w + (h_pad * 2);
    local height = line_h + (v_pad * 2);
    local width = half_w * 2;
    local panel_x = seam_x - half_w;

    draw_half(draw_list, panel_x, y, half_w, height, hook_color, hook, scale, rounding, CORNER_LEFT, opacity);
    draw_half(draw_list, seam_x, y, half_w, height, darken_hex(feel_color), feel_label, scale, rounding, CORNER_RIGHT, opacity);

    M.last_size.w = width;
    M.last_size.h = height;
    M.last_left_w = half_w;
    M.last_right_w = half_w;

    ui.draw_panel_drag('bite', settings.bite.x, settings.bite.y, width, height, panel_x, y);
end

return M;
