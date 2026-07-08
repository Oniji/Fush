--[[
* Fush - Vanadiel time helpers
]]--

local constants = require('constants');

local M = {};

local vana_pattern = 'B0015EC390518B4C24088D4424005068';

function M.get_timestamp()
    local p_vana_time = ashita.memory.find('FFXiMain.dll', 0, vana_pattern, 0, 0);
    if p_vana_time == nil or p_vana_time == 0 then
        return { day = 0, hour = 0, minute = 0, raw = 0, day_progress = 0 };
    end

    local pointer = ashita.memory.read_uint32(p_vana_time + 0x34);
    local raw_time = ashita.memory.read_uint32(pointer + 0x0C) + 92514960;
    local day_units = raw_time % 3456;

    return {
        day = math.floor(raw_time / 3456),
        hour = math.floor(raw_time / 144) % 24,
        minute = math.floor((raw_time % 144) / 2.4),
        raw = raw_time,
        day_progress = day_units / 3456,
        day_units = day_units,
    };
end

function M.format_time(timestamp)
    return string.format('%02d:%02d', timestamp.hour, timestamp.minute);
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

function M.hour_to_progress(hour)
    return hour / 24;
end

return M;
