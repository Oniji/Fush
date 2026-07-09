--[[
* Fush - Fishing pool resupply bar (Vanadiel day)
]]--

require('common');
local constants = require('constants');
local vana = require('libs.vana');
local theme = require('libs.theme');
local ui = require('libs.ui');
local drawing = require('libs.drawing');
local imgui = require('imgui');

local M = {
    last_size = { w = 380, h = 52 },
};

local PULSE_DURATION_MS = 520;

M.pulse = {
    active = false,
    start_ms = 0,
    last_progress = nil,
};

local function build_notches(timestamp)
    local notches = T{};
    for _, hour in ipairs(constants.POOL_RESTOCK_HOURS) do
        notches:append({
            hour = hour,
            progress = hour / 24,
            passed = hour <= timestamp.hour,
        });
    end
    return notches;
end

local function draw_time_label(draw_list, text, x, y, settings)
    local size = ui.measure_text(text);
    local draw_x = x - size;

    if ui.is_transparent_theme(settings) then
        ui.draw_text_outlined(draw_list, draw_x, y, text, { 1, 1, 1, 1 }, { 0, 0, 0, 1 }, 1);
    else
        draw_list:AddText({ draw_x, y }, imgui.GetColorU32(theme.colors.text_light), text);
    end
end

local function update_restock_pulse(progress)
    local now = ashita.time.clock()['ms'];
    local last = M.pulse.last_progress;

    if last ~= nil then
        -- Normal forward cross of a restock notch.
        for _, hour in ipairs(constants.POOL_RESTOCK_HOURS) do
            local notch = hour / 24;
            if last < notch and progress >= notch then
                M.pulse.active = true;
                M.pulse.start_ms = now;
                break;
            end
        end

        -- Day wrap: progress resets near 0 after passing the final hours.
        if last > progress and progress < 0.02 then
            M.pulse.active = true;
            M.pulse.start_ms = now;
        end
    end

    M.pulse.last_progress = progress;

    if not M.pulse.active then
        return nil;
    end

    local elapsed = now - M.pulse.start_ms;
    if elapsed >= PULSE_DURATION_MS then
        M.pulse.active = false;
        return nil;
    end

    return elapsed / PULSE_DURATION_MS;
end

function M.render(settings)
    if not settings.pool.visible[1] then
        return;
    end

    local timestamp = vana.get_timestamp();
    local notches = build_notches(timestamp);
    local countdown = vana.format_restock_countdown(timestamp);
    local time_text = vana.format_time(timestamp);
    local pulse_t = update_restock_pulse(timestamp.day_progress);

    local x = settings.pool.x[1];
    local y = settings.pool.y[1];
    local width = settings.pool.width[1];
    local height = settings.pool.height[1];
    local pad = ui.get_padding(settings, 'pool');
    local draw_list = drawing.GetUIDrawList();
    local scale = ui.get_module_scale(settings, 'pool');
    local line_h = imgui.GetTextLineHeight() * scale;
    local label_row_h = line_h + 2;
    local countdown_h = line_h + 4;
    local content_h = countdown_h + height + label_row_h + 4;

    ui.draw_panel_background(draw_list, x, y, M.last_size.w, M.last_size.h, settings, 'pool');

    imgui.SetNextWindowBgAlpha(0);
    imgui.SetNextWindowPos({ x, y }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ M.last_size.w, 0 }, ImGuiCond_Always);

    if imgui.Begin('FushPool##Display', ui.get_panel_open('pool'), ui.get_panel_flags()) then
        imgui.SetWindowFontScale(scale);
        imgui.SetCursorPos({ pad, pad });

        local countdown_text = 'Next restock: ' .. countdown;
        ui.text_outlined_colored(countdown_text, theme.colors.text_light);

        imgui.SetCursorPos({ pad, pad + countdown_h });
        local bar_x, bar_y = imgui.GetCursorScreenPos();
        imgui.Dummy({ width, content_h - countdown_h });

        local content_x, content_y, content_w, content_h_bar = ui.draw_progress_bar(
            settings,
            timestamp.day_progress,
            width,
            height,
            bar_x,
            bar_y,
            draw_list
        );

        if pulse_t ~= nil then
            ui.draw_restock_pulse(
                draw_list,
                content_x,
                content_y,
                content_w,
                content_h_bar,
                timestamp.day_progress,
                pulse_t
            );
        end

        ui.draw_notches(draw_list, bar_x, bar_y, width, height, notches, timestamp.day_progress, settings);
        ui.draw_time_cursor(draw_list, bar_x, bar_y, width, timestamp.day_progress, settings);

        local labels = ui.layout_notch_labels(notches, bar_x, width);
        draw_time_label(draw_list, time_text, bar_x + width, bar_y + height + 2, settings);
        ui.draw_notch_labels(draw_list, labels, bar_y + height + 14, settings);

        local size = { imgui.GetWindowSize() };
        M.last_size.w = math.max(size[1], width + pad * 2);
        M.last_size.h = size[2];

        ui.draw_panel_drag('pool', settings.pool.x, settings.pool.y, size[1], size[2]);
        imgui.SetWindowFontScale(1.0);
    end
    imgui.End();
end

return M;
