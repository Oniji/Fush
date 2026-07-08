--[[

* Fush - Fishing session tracker

]]--



require('common');

local constants = require('constants');

local format = require('libs.format');

local theme = require('libs.theme');

local ui = require('libs.ui');

local drawing = require('libs.drawing');

local imgui = require('imgui');



local M = {

    last_size = { w = 240, h = 220 },

};



M.session = {

    lines_cast = 0,

    hooks = 0,

    fish_caught = 0,

    items_caught = 0,

    monsters_caught = 0,

    lost = 0,

    broken = 0,

    first_cast_ms = 0,

    last_activity_ms = 0,

    current_hook = nil,

    rewards = T{},

};



function M.reset_session()

    M.session.lines_cast = 0;

    M.session.hooks = 0;

    M.session.fish_caught = 0;

    M.session.items_caught = 0;

    M.session.monsters_caught = 0;

    M.session.lost = 0;

    M.session.broken = 0;

    M.session.first_cast_ms = 0;

    M.session.last_activity_ms = 0;

    M.session.current_hook = nil;

    M.session.rewards = T{};

end



function M.touch_activity()

    M.session.last_activity_ms = ashita.time.clock()['ms'];

end



function M.record_cast()

    M.touch_activity();

    M.session.lines_cast = M.session.lines_cast + 1;

    if M.session.first_cast_ms == 0 then

        M.session.first_cast_ms = M.session.last_activity_ms;

    end

end



function M.record_hook(hook_type)

    M.touch_activity();

    M.session.hooks = M.session.hooks + 1;

    M.session.current_hook = hook_type;

end



local function add_reward(name)

    if M.session.rewards[name] == nil then

        M.session.rewards[name] = 1;

    else

        M.session.rewards[name] = M.session.rewards[name] + 1;

    end

end



function M.record_catch(item_name, hook_type)

    M.touch_activity();

    hook_type = hook_type or M.session.current_hook;



    if hook_type == constants.ITEM_HOOK_TYPE then

        M.session.items_caught = M.session.items_caught + 1;

    elseif hook_type == constants.MONSTER_HOOK_TYPE then

        M.session.monsters_caught = M.session.monsters_caught + 1;

    else

        M.session.fish_caught = M.session.fish_caught + 1;

    end



    if item_name ~= nil and item_name ~= '' then

        add_reward(item_name);

    end



    M.session.current_hook = nil;

end



function M.record_lost()

    M.touch_activity();

    M.session.lost = M.session.lost + 1;

    M.session.current_hook = nil;

end



function M.record_broken()

    M.touch_activity();

    M.session.broken = M.session.broken + 1;

    M.session.current_hook = nil;

end



function M.get_accuracy()

    if M.session.hooks == 0 then

        return 0;

    end

    return (M.session.fish_caught / M.session.hooks) * 100;

end



function M.get_total_worth(pricing)

    local total = 0;

    for name, count in pairs(M.session.rewards) do

        local key = string.lower(name);

        if pricing[key] ~= nil then

            total = total + (tonumber(pricing[key]) or 0) * count;

        end

    end

    return total;

end



function M.get_net_gil(settings, pricing)

    local total = M.get_total_worth(pricing);

    if settings.tracker.subtract_bait[1] and not settings.tracker.use_lure[1] then

        total = total - (M.session.lines_cast * settings.tracker.bait_cost[1]);

    end

    return total;

end



function M.get_elapsed_seconds()

    if M.session.first_cast_ms == 0 then

        return 0;

    end

    return (ashita.time.clock()['ms'] - M.session.first_cast_ms) / 1000;

end



function M.handle_text(e, bite)

    if e.injected then

        return;

    end



    local message = string.lower(string.strip_colors(e.message));



    local catch = string.match(message, 'obtained: (.*).')

        or string.match(message, 'you catch an? (.*).')

        or string.match(message, 'you catch a (.*).');



    if catch ~= nil then

        M.record_catch(catch, bite.get_hook_type());

        return;

    end



    if string.contains(message, 'you lost your catch')

        or string.contains(message, 'the fish got away')

        or string.contains(message, 'lack of skill')

        or string.contains(message, 'weren\'t able to catch anything') then

        M.record_lost();

        return;

    end



    if string.contains(message, 'your line breaks') then

        M.record_broken();

        return;

    end

end



function M.handle_packet_out(e)

    if e.id ~= constants.PACKET_ACTION then

        return;

    end



    local action = struct.unpack('H', e.data_modified, 0x0A + 1);

    if action == constants.FISHING_ACTION_START then

        M.record_cast();

    end

end



function M.build_report(settings, pricing)

    local elapsed = M.get_elapsed_seconds();

    local accuracy = M.get_accuracy();

    local net = M.get_net_gil(settings, pricing);

    local gph = format.format_gph(net, elapsed);



    local lines = T{};

    lines:append('~~~~~~ Fush Session ~~~~~~');

    lines:append('Lines Cast: ' .. format.format_int(M.session.lines_cast));

    lines:append('Hooks: ' .. format.format_int(M.session.hooks));

    lines:append('Fish Caught: ' .. format.format_int(M.session.fish_caught));

    lines:append('Items Caught: ' .. format.format_int(M.session.items_caught));

    lines:append('Fish Accuracy: ' .. format.format_percent(accuracy));

    lines:append('Lost / Broken: ' .. M.session.lost .. ' / ' .. M.session.broken);

    lines:append('~~~~~~~~~~~~~~~~~~~~~~~~~~~~');



    for name, count in pairs(M.session.rewards) do

        local key = string.lower(name);

        local price = tonumber(pricing[key]) or 0;

        lines:append(name .. ': x' .. format.format_int(count) .. ' (' .. format.format_int(price * count) .. 'g)');

    end



    lines:append('~~~~~~~~~~~~~~~~~~~~~~~~~~~~');



    if settings.tracker.subtract_bait[1] and not settings.tracker.use_lure[1] then

        local bait_spent = M.session.lines_cast * settings.tracker.bait_cost[1];

        lines:append('Bait Cost: ' .. format.format_int(bait_spent) .. 'g');

    end



    lines:append('Net Gil: ' .. format.format_int(net) .. 'g (' .. format.format_int(gph) .. ' gph)');

    return table.concat(lines, '\n');

end



function M.render(settings, pricing)

    if not settings.tracker.visible[1] then

        return;

    end



    local idle_secs = (ashita.time.clock()['ms'] - M.session.last_activity_ms) / 1000;

    if M.session.last_activity_ms > 0 and idle_secs > settings.tracker.display_timeout[1] then

        return;

    end



    local x = settings.tracker.x[1];

    local y = settings.tracker.y[1];

    local pad = settings.ui.padding[1];

    local draw_list = drawing.GetUIDrawList();



    ui.draw_panel_background(draw_list, x, y, M.last_size.w, M.last_size.h, settings);



    imgui.SetNextWindowBgAlpha(0);

    imgui.SetNextWindowPos({ x, y }, ImGuiCond_Always);



    if imgui.Begin('FushTracker##Display', true, ui.get_panel_flags()) then

        imgui.SetWindowFontScale(settings.font_scale[1]);

        imgui.SetCursorPos({ pad, pad });



        imgui.PushStyleColor(ImGuiCol_Text, theme.colors.text_gold);

        imgui.Text('Fush Session');

        imgui.PopStyleColor(1);

        imgui.Separator();



        imgui.Text('Lines: ' .. format.format_int(M.session.lines_cast));

        imgui.Text('Hooks: ' .. format.format_int(M.session.hooks));

        imgui.Text('Fish: ' .. format.format_int(M.session.fish_caught) .. '  Items: ' .. format.format_int(M.session.items_caught));

        imgui.Text('Accuracy: ' .. format.format_percent(M.get_accuracy()));

        imgui.Text('Lost: ' .. M.session.lost .. '  Broken: ' .. M.session.broken);



        local elapsed = M.get_elapsed_seconds();

        local net = M.get_net_gil(settings, pricing);

        local gph = format.format_gph(net, elapsed);

        imgui.Separator();

        local gil_x, gil_y = imgui.GetCursorScreenPos();
        local gil_offset = ui.draw_gil_icon(draw_list, gil_x, gil_y + 2, 14);
        if gil_offset > 0 then
            imgui.SetCursorPosX(pad + gil_offset);
        end
        imgui.Text('Net Gil: ' .. format.format_int(net) .. 'g');

        imgui.Text('Rate: ' .. format.format_int(gph) .. ' gph');



        if next(M.session.rewards) ~= nil then

            imgui.Separator();

            for name, count in pairs(M.session.rewards) do

                imgui.Text(name .. ' x' .. count);

            end

        end



        local size = { imgui.GetWindowSize() };

        M.last_size.w = size[1];

        M.last_size.h = size[2];

    end

    imgui.End();

end



return M;


