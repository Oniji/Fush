--[[
* Fush - Ship / ferry departure tracker (HorizonXI schedules)
*
* Times sourced from Horizogenes / HorizonXI wiki boat schedules (Vana'diel).
* Countdown shown in real-world mm:ss (1 Vana unit ≈ 1 Earth second).
]]--

require('common');
local vana = require('libs.vana');
local theme = require('libs.theme');
local ui = require('libs.ui');
local drawing = require('libs.drawing');
local imgui = require('imgui');

local M = {
    last_size = { w = 220, h = 140 },
    layout_w = 220,
};

-- ToAU / Whitegate ferry unlock (HorizonXI). Local calendar date is fine.
local WHITEGATE_UNLOCK_OS = os.time({
    year = 2026,
    month = 8,
    day = 7,
    hour = 0,
    min = 0,
    sec = 0,
});

local COLOR_TIMER_OK = nil;      -- filled from theme each frame
local COLOR_TIMER_WARN = nil;
local COLOR_TIMER_URGENT = { 0.95, 0.28, 0.24, 1.0 };
local COLOR_LOCKED = { 0.52, 0.54, 0.58, 1.0 };

-- One row per route. Multiple departure times -> countdown uses the soonest.
-- Schedules are Vana'diel HH:MM departure times.
local ROUTES = {
    {
        from = 'Selbina',
        to = 'Mhaura',
        departures = {
            { hour = 0, minute = 0 },
            { hour = 8, minute = 0 },
            { hour = 16, minute = 0 },
        },
    },
    {
        from = 'Mhaura',
        to = 'Selbina',
        departures = {
            { hour = 0, minute = 0 },
            { hour = 8, minute = 0 },
            { hour = 16, minute = 0 },
        },
    },
    {
        from = 'Mhaura',
        to = 'Whitegate',
        locked_until_os = WHITEGATE_UNLOCK_OS,
        departures = {
            { hour = 4, minute = 0 },
            { hour = 12, minute = 0 },
            { hour = 20, minute = 0 },
        },
    },
    {
        -- Maliyakaleya Reef Tour + Dhalmel Rock Tour from Bibiki Bay.
        from = 'Bibiki Bay',
        to = 'Tours',
        departures = {
            { hour = 0, minute = 50 },   -- Dhalmel Rock
            { hour = 12, minute = 50 },  -- Maliyakaleya Reef
        },
    },
    {
        from = 'Bibiki Bay',
        to = 'Purgo. Isle',
        departures = {
            { hour = 5, minute = 30 },
            { hour = 17, minute = 30 },
        },
    },
    {
        from = 'Purgo. Isle',
        to = 'Bibiki Bay',
        departures = {
            { hour = 9, minute = 15 },
            { hour = 21, minute = 15 },
        },
    },
};

local ARROW = '->'; -- fallback if assets/arrow.png fails to load
local ARROW_LINE_RATIO = 0.78; -- arrow height relative to text line height

local ROW_GAP = 2;
local COL_GAP = 12;
local ROUTE_GAP = 6; -- gap between from / arrow / to

local function route_locked(route, now_os)
    local until_os = route.locked_until_os;
    if until_os == nil then
        return false;
    end
    return now_os < until_os;
end

-- >5m white, 1m..5m yellow, <1m red (Earth seconds; 1 Vana unit ≈ 1s).
local function timer_color(units)
    if units == nil then
        return COLOR_TIMER_OK;
    end
    if units < 60 then
        return COLOR_TIMER_URGENT;
    end
    if units <= 300 then
        return COLOR_TIMER_WARN;
    end
    return COLOR_TIMER_OK;
end

local function text_w(text)
    local w = ui.measure_text(text);
    if type(w) ~= 'number' then
        return 0;
    end
    return w;
end

local function cursor_screen_pos()
    local sx, sy = imgui.GetCursorScreenPos();
    if type(sx) == 'table' then
        sy = sx.y or sx[2] or 0;
        sx = sx.x or sx[1] or 0;
    end
    return sx, sy;
end

-- Arrow size tracks line height (font size × module scale via SetWindowFontScale).
local function arrow_size_for_line(line_h)
    local h = math.max(8, math.floor(line_h * ARROW_LINE_RATIO + 0.5));
    return h, h;
end

local function draw_route_arrow(draw_list, x_pos, y_pos, arrow_w, arrow_h, line_h, color)
    imgui.SetCursorPos({ x_pos, y_pos });
    local sx, sy = cursor_screen_pos();
    local ay = sy + math.max(0, (line_h - arrow_h) * 0.5);
    if ui.draw_arrow_icon(draw_list, sx, ay, arrow_w, arrow_h, color) then
        return;
    end
    ui.text_outlined_colored(ARROW, color);
end

function M.render(settings)
    if not settings.ship or not settings.ship.visible[1] then
        return;
    end

    COLOR_TIMER_OK = theme.colors.text_light;
    -- Keep warning yellow even on Plain (theme gold becomes white there).
    local ocean = theme.get_palette('OceanBlue');
    COLOR_TIMER_WARN = ocean and ocean.gold or { 1.0, 0.886, 0.278, 1.0 };

    local timestamp = vana.get_timestamp();
    local now_os = os.time();
    local x = settings.ship.x[1];
    local y = settings.ship.y[1];
    local pad = ui.get_padding(settings, 'ship');
    local scale = ui.get_module_scale(settings, 'ship');
    local draw_list = drawing.GetUIDrawList();
    local layout_w = M.layout_w or 220;

    ui.draw_panel_background(draw_list, x, y, layout_w, M.last_size.h, settings, 'ship');

    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 0, 0 });

    imgui.SetNextWindowBgAlpha(0);
    imgui.SetNextWindowPos({ x, y }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ layout_w, 0 }, ImGuiCond_Always);

    if imgui.Begin('FushShip##Display', ui.get_panel_open('ship'), ui.get_panel_flags()) then
        imgui.SetWindowFontScale(scale);

        local line_h = imgui.GetTextLineHeight();
        local arrow_w, arrow_h = arrow_size_for_line(line_h);
        local rows = T{};
        local max_from_w = 0;
        local max_to_w = 0;
        local max_timer_w = 0;

        for _, route in ipairs(ROUTES) do
            local locked = route_locked(route, now_os);
            local units = nil;
            local timer = '';
            local timer_w = 0;

            if not locked then
                units = vana.next_departure_units(timestamp, route.departures);
                timer = vana.format_units_countdown(units);
                timer_w = text_w(timer);
                if timer_w > max_timer_w then max_timer_w = timer_w; end
            end

            local from_w = text_w(route.from);
            local to_w = text_w(route.to);
            if from_w > max_from_w then max_from_w = from_w; end
            if to_w > max_to_w then max_to_w = to_w; end

            rows:append({
                from = route.from,
                to = route.to,
                locked = locked,
                timer = timer,
                timer_w = timer_w,
                color = locked and COLOR_LOCKED or timer_color(units),
                label_color = locked and COLOR_LOCKED or theme.colors.text_light,
            });
        end

        local max_route_w = max_from_w + ROUTE_GAP + arrow_w + ROUTE_GAP + max_to_w;
        local content_w = max_route_w + COL_GAP + max_timer_w;
        local content_h = (#rows * line_h) + (math.max(0, #rows - 1) * ROW_GAP);
        local panel_w = content_w + (pad * 2);
        local panel_h = content_h + (pad * 2);

        local arrow_x = pad + max_from_w + ROUTE_GAP;
        local to_x = arrow_x + arrow_w + ROUTE_GAP;

        local cursor_y = pad;
        for _, row in ipairs(rows) do
            imgui.SetCursorPos({ pad, cursor_y });
            ui.text_outlined_colored(row.from, row.label_color);

            draw_route_arrow(draw_list, arrow_x, cursor_y, arrow_w, arrow_h, line_h, row.label_color);

            imgui.SetCursorPos({ to_x, cursor_y });
            ui.text_outlined_colored(row.to, row.label_color);

            if not row.locked then
                local timer_x = pad + max_route_w + COL_GAP + (max_timer_w - row.timer_w);
                imgui.SetCursorPos({ timer_x, cursor_y });
                ui.text_outlined_colored(row.timer, row.color);
            end

            cursor_y = cursor_y + line_h + ROW_GAP;
        end

        imgui.SetCursorPos({ 0, 0 });
        imgui.Dummy({ panel_w, panel_h });

        M.layout_w = panel_w;
        M.last_size.w = panel_w;
        M.last_size.h = panel_h;

        ui.draw_panel_drag('ship', settings.ship.x, settings.ship.y, panel_w, panel_h);
        imgui.SetWindowFontScale(1.0);
    end
    imgui.End();
    imgui.PopStyleVar(2);
end

return M;
