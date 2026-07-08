--[[
* Fush - Formatting helpers
]]--

local M = {};

function M.format_int(number)
    if number == nil or number == '' then
        return '0';
    end

    number = tonumber(number) or 0;
    if math.abs(number) < 1000 then
        return tostring(math.floor(number));
    end

    local text = tostring(math.floor(number));
    local negative = '';
    if text:sub(1, 1) == '-' then
        negative = '-';
        text = text:sub(2);
    end

    local int = text:reverse():gsub('(%d%d%d)', '%1,');
    return negative .. int:reverse():gsub('^,', '');
end

function M.format_percent(value)
    return string.format('%.1f%%', value or 0);
end

function M.format_gph(total_gil, elapsed_seconds)
    if elapsed_seconds == nil or elapsed_seconds <= 0 then
        return 0;
    end
    return math.floor((total_gil / elapsed_seconds) * 3600);
end

return M;
