--[[
* Fush UI bridge — XIUI rendering wrappers
* https://github.com/tirem/XIUI — GNU GPL v3
]]--

require('common');
local imgui = require('imgui');
local colorLib = require('libs.color');
local drawing = require('libs.drawing');
local windowbackground = require('libs.windowbackground');
local progressbar = require('libs.progressbar');
local TextureManager = require('libs.texturemanager');
local attribution = require('libs.attribution');

local M = {};

local current_settings = nil;
local editor_open = nil;

local function ui_settings(settings)
    settings = settings or current_settings;
    if settings == nil or settings.ui == nil then
        return nil;
    end
    return settings.ui;
end

function M.bind(settings, editor_open_ref)
    current_settings = settings;
    editor_open = editor_open_ref;
    drawing.set_editor_open(editor_open_ref);

    progressbar.set_style_provider(function ()
        local ui = ui_settings();
        if ui == nil then
            return nil;
        end
        return {
            show_bookends = ui.show_bookends[1],
            bookend_size = ui.bookend_size[1],
            bar_border_thickness = ui.bar_border_thickness[1],
            no_bookend_rounding = ui.no_bookend_rounding[1],
            background_gradient_start = ui.background_gradient_start[1],
            background_gradient_end = ui.background_gradient_end[1],
            bookend_gradient_start = ui.bookend_gradient_start[1],
            bookend_gradient_mid = ui.bookend_gradient_mid[1],
            bookend_gradient_stop = ui.bookend_gradient_stop[1],
        };
    end);
end

function M.present_frame_start()
    TextureManager.FlushPendingReleases();
end

function M.cleanup()
    progressbar.Cleanup();
    TextureManager.clear();
    colorLib.InvalidateColorCaches();
end

function M.get_panel_flags()
    return bit.bor(
        ImGuiWindowFlags_NoDecoration,
        ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoFocusOnAppearing,
        ImGuiWindowFlags_NoNav,
        ImGuiWindowFlags_NoBackground
    );
end

function M.get_background_options(settings)
    local ui = ui_settings(settings);
    if ui == nil then
        return { theme = 'Window1', padding = 8 };
    end

    return {
        theme = ui.background_theme[1],
        padding = ui.padding[1],
        paddingY = ui.padding[1],
        bgScale = ui.bg_scale[1],
        borderScale = ui.border_scale[1],
        bgOpacity = ui.background_opacity[1],
        borderOpacity = ui.border_opacity[1],
    };
end

function M.draw_panel_background(draw_list, x, y, w, h, settings)
    windowbackground.Draw(draw_list, x, y, w, h, M.get_background_options(settings));
end

function M.draw_progress_bar(settings, progress, width, height, x, y, draw_list)
    local ui = ui_settings(settings);
    local fillStart = ui and ui.bar_fill_start[1] or '#3798ce';
    local fillEnd = ui and ui.bar_fill_end[1] or '#78c5ee';

    progressbar.ProgressBar({
        { progress, { fillStart, fillEnd } },
    }, { width, height }, {
        drawList = draw_list,
        absolutePosition = { x, y },
        decorate = ui and ui.show_bookends[1] or true,
    });
end

function M.draw_notches(draw_list, x, y, width, height, notches, progress, settings)
    local ui = ui_settings(settings);
    local active = colorLib.HexToImGui(ui and ui.notch_color[1] or '#F2D159');
    local passed = colorLib.HexToImGui(ui and ui.notch_passed_color[1] or '#738299');

    for _, notch in ipairs(notches) do
        local nx = x + (width * notch.progress);
        local is_passed = notch.progress <= progress;
        draw_list:AddLine(
            { nx, y - 2 },
            { nx, y + height + 2 },
            imgui.GetColorU32(is_passed and passed or active),
            is_passed and 1.5 or 2.5
        );
    end
end

function M.draw_time_cursor(draw_list, x, y, width, progress, settings)
    local ui = ui_settings(settings);
    local cx = x + (width * progress);
    local tex = TextureManager.getFileTexture('arrow');
    local ptr = TextureManager.getTexturePtr(tex);

    if ptr ~= nil then
        draw_list:AddImage(ptr, { cx - 6, y - 14 }, { cx + 6, y - 2 }, { 0, 0 }, { 1, 1 }, IM_COL32_WHITE);
        return;
    end

    draw_list:AddTriangleFilled(
        { cx, y - 6 },
        { cx - 5, y - 12 },
        { cx + 5, y - 12 },
        imgui.GetColorU32({ 1, 1, 1, 0.95 })
    );
end

function M.render_about()
    imgui.Text('Fush');
    imgui.TextDisabled(string.format('Version %s', addon.version));
    imgui.Separator();
    imgui.TextWrapped(attribution.XIUI_NOTICE);
    imgui.Spacing();
    imgui.TextWrapped(attribution.get_short_credit());
end

function M.render_credit_footer()
    imgui.Separator();
    imgui.TextDisabled(attribution.get_short_credit());
end

function M.draw_gil_icon(draw_list, x, y, size)
    size = size or 12;
    local tex = TextureManager.getFileTexture('gil');
    local ptr = TextureManager.getTexturePtr(tex);
    if ptr ~= nil then
        draw_list:AddImage(ptr, { x, y }, { x + size, y + size }, { 0, 0 }, { 1, 1 }, IM_COL32_WHITE);
        return size + 4;
    end
    return 0;
end

return M;
