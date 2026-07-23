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

local function pool_flag(settings, key, default_value)
    local pool_ui = settings.ui and settings.ui.pool;
    if pool_ui == nil or pool_ui[key] == nil then
        return default_value;
    end
    local v = pool_ui[key][1];
    if v == nil then
        return default_value;
    end
    return v;
end

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

-- Flash when day_progress crosses a restock hour (or wraps past midnight).
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

--- Day-progress bar with restock notches; optional countdown / Vana time / moon.
function M.render(settings)
    if not settings.pool.visible[1] then
        return;
    end

    local timestamp = vana.get_timestamp();
    local notches = build_notches(timestamp);
    local countdown = vana.format_restock_countdown(timestamp);
    local time_text = vana.format_time(timestamp);
    local moon = vana.get_moon(timestamp);
    local moon_text = vana.format_moon(moon);
    local pulse_t = update_restock_pulse(timestamp.day_progress);

    local show_restock = pool_flag(settings, 'show_next_restock', true);
    local show_vana = pool_flag(settings, 'show_vana_time', true);
    local show_moon = pool_flag(settings, 'show_moon_phase', true);
    local show_top = show_restock or show_vana or show_moon;

    local x = settings.pool.x[1];
    local y = settings.pool.y[1];
    local width = settings.pool.width[1];
    local height = settings.pool.height[1];
    local pad = ui.get_padding(settings, 'pool');
    local draw_list = drawing.GetUIDrawList();
    local scale = ui.get_module_scale(settings, 'pool');
    local line_h = imgui.GetTextLineHeight() * scale;
    local label_row_h = line_h + 2;
    local countdown_h = show_top and (line_h + 4) or 0;
    -- Optional top row + bar + notch labels under the bar.
    local content_h = countdown_h + height + label_row_h + 4;

    ui.draw_panel_background(draw_list, x, y, M.last_size.w, M.last_size.h, settings, 'pool');

    imgui.SetNextWindowBgAlpha(0);
    imgui.SetNextWindowPos({ x, y }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ M.last_size.w, 0 }, ImGuiCond_Always);

    if imgui.Begin('FushPool##Display', ui.get_panel_open('pool'), ui.get_panel_flags()) then
        imgui.SetWindowFontScale(scale);
        imgui.SetCursorPos({ pad, pad });

        if show_restock then
            local countdown_text = 'Next restock: ' .. countdown;
            ui.text_outlined_colored(countdown_text, theme.colors.text_light);
        end

        if show_vana or show_moon then
            -- Right-align: [moon] [element] [time] so trailing edge matches the bar end.
            local weekday = vana.get_weekday(timestamp);
            local time_w, time_h = 0, line_h;
            if show_vana then
                time_w, time_h = ui.measure_text(time_text);
                if type(time_h) ~= 'number' then
                    time_h = line_h;
                end
            end
            local moon_w = 0;
            if show_moon then
                moon_w = ui.measure_text(moon_text);
                if type(moon_w) ~= 'number' then
                    moon_w = 0;
                end
            end

            local circle_r = show_vana and math.max(3.0, time_h * 0.28) or 0;
            local gap = 5.0;
            local outline_pad = 1.0;
            local cluster_w = outline_pad;
            if show_moon then
                cluster_w = cluster_w + moon_w;
            end
            if show_moon and show_vana then
                cluster_w = cluster_w + gap;
            end
            if show_vana then
                cluster_w = cluster_w + (circle_r * 2.0) + gap + time_w;
            end

            local bar_right = pad + width;
            local cluster_x = bar_right - cluster_w;
            local cursor_x = cluster_x;

            if show_moon then
                imgui.SetCursorPos({ cursor_x, pad });
                ui.text_outlined_colored(moon_text, theme.colors.text_light);
                cursor_x = cursor_x + moon_w + ((show_vana and gap) or 0);
            end

            if show_vana then
                imgui.SetCursorPos({ cursor_x, pad });
                local sx, sy = imgui.GetCursorScreenPos();
                if type(sx) == 'table' then
                    sy = sx.y or sx[2] or 0;
                    sx = sx.x or sx[1] or 0;
                end
                local cx = sx + circle_r;
                local cy = sy + (time_h * 0.5);
                draw_list:AddCircleFilled({ cx, cy }, circle_r, imgui.GetColorU32(weekday.color), 20);
                draw_list:AddCircle({ cx, cy }, circle_r, imgui.GetColorU32({ 0, 0, 0, 0.85 }), 20, 1.25);

                imgui.SetCursorPos({ cursor_x + (circle_r * 2.0) + gap, pad });
                ui.text_outlined_colored(time_text, theme.colors.text_light);
            end
        end

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

        local labels = ui.layout_notch_labels(notches, bar_x, width);
        ui.draw_notch_labels(draw_list, labels, bar_y + height + 4, settings);

        local size = { imgui.GetWindowSize() };
        M.last_size.w = math.max(size[1], width + pad * 2);
        M.last_size.h = size[2];

        ui.draw_panel_drag('pool', settings.pool.x, settings.pool.y, size[1], size[2]);
        imgui.SetWindowFontScale(1.0);
    end
    imgui.End();
end

return M;
