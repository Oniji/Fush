--[[
* Fush - Vanadiel time helpers
]]--

local constants = require('constants');

local M = {};

local vana_pattern = 'B0015EC390518B4C24088D4424005068';
local UNITS_PER_DAY = 3456;
local UNITS_PER_HOUR = 144;
local UNITS_PER_MINUTE = 2.4;

-- Weekday index 0 = Firesday (Ashita / common FFXI convention).
M.WEEKDAYS = {
    { name = 'Firesday',     element = 'Fire',      color = { 0.95, 0.35, 0.18, 1.0 } },
    { name = 'Earthsday',    element = 'Earth',     color = { 0.78, 0.62, 0.28, 1.0 } },
    { name = 'Watersday',    element = 'Water',     color = { 0.30, 0.52, 0.95, 1.0 } },
    { name = 'Windsday',     element = 'Wind',      color = { 0.35, 0.82, 0.40, 1.0 } },
    { name = 'Iceday',       element = 'Ice',       color = { 0.55, 0.85, 0.98, 1.0 } },
    { name = 'Lightningday', element = 'Lightning', color = { 0.72, 0.45, 0.95, 1.0 } },
    { name = 'Lightsday',    element = 'Light',     color = { 0.96, 0.94, 0.70, 1.0 } },
    { name = 'Darksday',     element = 'Dark',      color = { 0.35, 0.28, 0.48, 1.0 } },
};

function M.get_timestamp()
    local p_vana_time = ashita.memory.find('FFXiMain.dll', 0, vana_pattern, 0, 0);
    if p_vana_time == nil or p_vana_time == 0 then
        return { day = 0, hour = 0, minute = 0, raw = 0, day_progress = 0, day_units = 0 };
    end

    local pointer = ashita.memory.read_uint32(p_vana_time + 0x34);
    local raw_time = ashita.memory.read_uint32(pointer + 0x0C) + 92514960;
    local day_units = raw_time % UNITS_PER_DAY;

    return {
        day = math.floor(raw_time / UNITS_PER_DAY),
        hour = math.floor(raw_time / UNITS_PER_HOUR) % 24,
        minute = math.floor((raw_time % UNITS_PER_HOUR) / UNITS_PER_MINUTE),
        raw = raw_time,
        day_progress = day_units / UNITS_PER_DAY,
        day_units = day_units,
    };
end

function M.get_weekday_index(timestamp)
    return (timestamp.day or 0) % 8;
end

function M.get_weekday(timestamp)
    return M.WEEKDAYS[M.get_weekday_index(timestamp) + 1];
end

function M.format_time(timestamp)
    return string.format('%02d:%02d', timestamp.hour, timestamp.minute);
end

-- Lunar cycle is 84 Vana'diel days. Matches common Ashita / LSB moon math:
-- (day + 26) % 84 → 0..42 waning Full→New, 42..84 waxing New→Full.
function M.get_moon(timestamp)
    local daysmod = ((timestamp.day or 0) + 26) % 84;
    local percent;
    local direction;

    if daysmod == 0 or daysmod == 42 then
        direction = 'neither';
    elseif daysmod < 42 then
        direction = 'waning';
    else
        direction = 'waxing';
    end

    if daysmod >= 42 then
        percent = math.floor(100 * ((daysmod - 42) / 42) + 0.5);
    else
        percent = math.floor(100 * (1 - (daysmod / 42)) + 0.5);
    end
    if percent < 0 then percent = 0; end
    if percent > 100 then percent = 100; end

    local name;
    if percent <= 5 then
        name = 'New Moon';
    elseif percent <= 25 then
        name = (direction == 'waning') and 'Waning Crescent' or 'Waxing Crescent';
    elseif percent <= 40 then
        name = (direction == 'waning') and 'Last Quarter' or 'First Quarter';
    elseif percent <= 90 then
        name = (direction == 'waning') and 'Waning Gibbous' or 'Waxing Gibbous';
    else
        name = 'Full Moon';
    end

    return {
        percent = percent,
        direction = direction,
        name = name,
    };
end

function M.format_moon(moon)
    if moon == nil then
        moon = M.get_moon({ day = 0 });
    end
    return string.format('%s %d%%', moon.name, moon.percent);
end

function M.next_restock_hour(timestamp)
    local current = timestamp.hour + (timestamp.minute / 60);

    for _, restock_hour in ipairs(constants.POOL_RESTOCK_HOURS) do
        if restock_hour > current then
            return restock_hour;
        end
    end

    return constants.POOL_RESTOCK_HOURS[1];
end

function M.hours_until_restock(timestamp)
    local next_hour = M.next_restock_hour(timestamp);
    local current = timestamp.hour + (timestamp.minute / 60);

    if next_hour >= current then
        return next_hour - current;
    end

    return (24 - current) + next_hour;
end

function M.units_until_restock(timestamp)
    local next_hour = M.next_restock_hour(timestamp);
    local target_units = next_hour * UNITS_PER_HOUR;
    local current_units = timestamp.day_units or 0;

    if target_units <= current_units then
        target_units = target_units + UNITS_PER_DAY;
    end

    return target_units - current_units;
end

function M.format_units_countdown(units)
    -- One Vana clock unit maps to ~1 real second.
    local total_seconds = math.max(0, math.floor(units or 0));
    local minutes = math.floor(total_seconds / 60);
    local seconds = total_seconds % 60;
    return string.format('%02d:%02d', minutes, seconds);
end

function M.format_restock_countdown(timestamp)
    return M.format_units_countdown(M.units_until_restock(timestamp));
end

-- Earth-seconds countdown until the next listed Vana'diel HH:MM (same day or wrap).
-- departures: list of { hour = H, minute = M } (or { H, M }).
function M.next_departure_units(timestamp, departures)
    if departures == nil or #departures == 0 then
        return nil;
    end

    local current = timestamp.day_units or 0;
    local best = nil;
    for _, dep in ipairs(departures) do
        local hour = dep.hour;
        local minute = dep.minute;
        if hour == nil then
            hour = dep[1];
            minute = dep[2];
        end
        hour = tonumber(hour) or 0;
        minute = tonumber(minute) or 0;
        local target = hour * UNITS_PER_HOUR + minute * UNITS_PER_MINUTE;
        if target <= current then
            target = target + UNITS_PER_DAY;
        end
        local until_units = target - current;
        if best == nil or until_units < best then
            best = until_units;
        end
    end
    return best;
end

function M.format_next_departure(timestamp, departures)
    local units = M.next_departure_units(timestamp, departures);
    if units == nil then
        return '--:--';
    end
    return M.format_units_countdown(units);
end

function M.hour_to_progress(hour)
    return hour / 24;
end

return M;
