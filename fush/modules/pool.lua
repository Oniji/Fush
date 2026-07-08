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
    last_size = { w = 380, h = 72 },
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

function M.render(settings)
    if not settings.pool.visible[1] then
        return;
    end

    local timestamp = vana.get_timestamp();
    local notches = build_notches(timestamp);
    local next_hour = vana.next_restock_hour(timestamp);
    local hours_left = vana.hours_until_restock(timestamp);

    local x = settings.pool.x[1];
    local y = settings.pool.y[1];
    local width = settings.pool.width[1];
    local height = settings.pool.height[1];
    local pad = settings.ui.padding[1];
    local draw_list = drawing.GetUIDrawList();

    ui.draw_panel_background(draw_list, x, y, M.last_size.w, M.last_size.h, settings);

    imgui.SetNextWindowBgAlpha(0);
    imgui.SetNextWindowPos({ x, y }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ M.last_size.w, 0 }, ImGuiCond_Always);

    if imgui.Begin('FushPool##Display', true, ui.get_panel_flags()) then
        imgui.SetCursorPos({ pad, pad });

        imgui.PushStyleColor(ImGuiCol_Text, theme.colors.text_gold);
        imgui.Text('Pool Resupply');
        imgui.PopStyleColor(1);
        imgui.SameLine();
        imgui.PushStyleColor(ImGuiCol_Text, theme.colors.text_dim);
        imgui.Text(string.format('Vana %s', vana.format_time(timestamp)));
        imgui.PopStyleColor(1);

        local bar_x, bar_y = imgui.GetCursorScreenPos();
        imgui.Dummy({ width, height + 28 });
        ui.draw_progress_bar(settings, timestamp.day_progress, width, height, bar_x, bar_y, draw_list);
        ui.draw_notches(draw_list, bar_x, bar_y, width, height, notches, timestamp.day_progress, settings);
        ui.draw_time_cursor(draw_list, bar_x, bar_y, width, timestamp.day_progress, settings);

        for _, notch in ipairs(notches) do
            local nx = bar_x + (width * notch.progress) - 8;
            local ny = bar_y + height + 6;
            imgui.SetCursorScreenPos({ nx, ny });
            imgui.PushStyleColor(ImGuiCol_Text, theme.hex_to_imgui(
                notch.passed and settings.ui.notch_passed_color[1] or settings.ui.notch_color[1]
            ));
            imgui.Text(tostring(notch.hour));
            imgui.PopStyleColor(1);
        end

        imgui.SetCursorPosX(pad);
        imgui.PushStyleColor(ImGuiCol_Text, theme.colors.text_dim);
        imgui.Text(string.format('Next restock: %02d:00 (~%.1f hr)', next_hour, hours_left));
        imgui.PopStyleColor(1);

        local size = { imgui.GetWindowSize() };
        M.last_size.w = size[1];
        M.last_size.h = size[2];
    end
    imgui.End();
end

return M;
