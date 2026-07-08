--[[

* Fush - Bite type and feeling tracker

]]--



require('common');

local constants = require('constants');

local theme = require('libs.theme');

local ui = require('libs.ui');

local drawing = require('libs.drawing');

local imgui = require('imgui');



local M = {

    last_size = { w = 260, h = 96 },

};



M.state = {

    active = false,

    hook = 'Unknown',

    hook_color = '#999999',

    feel = 'Unknown',

    feel_color = '#e6c84a',

};



function M.reset()

    M.state.active = false;

    M.state.hook = 'Unknown';

    M.state.hook_color = '#999999';

    M.state.feel = 'Unknown';

    M.state.feel_color = '#e6c84a';

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



function M.handle_text(e)

    if e.injected then

        return nil;

    end



    for _, entry in ipairs(constants.HOOK_MESSAGES) do

        if string.match(e.message, entry.message) ~= nil then

            M.state.feel = 'Unknown';

            M.state.feel_color = '#e6c84a';

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



function M.handle_packet(e)

    if e.id == constants.PACKET_ZONE then

        M.deactivate();

        return;

    end



    if e.id == constants.PACKET_STATUS then

        if struct.unpack('B', e.data, 0x30 + 1) == 0 then

            M.deactivate();

        end

    end

end



function M.render(settings)

    if not settings.bite.visible[1] or not M.state.active then

        return;

    end



    local x = settings.bite.x[1];

    local y = settings.bite.y[1];

    local pad = settings.ui.padding[1];

    local draw_list = drawing.GetUIDrawList();



    ui.draw_panel_background(draw_list, x, y, M.last_size.w, M.last_size.h, settings);



    imgui.SetNextWindowBgAlpha(0);

    imgui.SetNextWindowPos({ x, y }, ImGuiCond_Always);

    imgui.SetNextWindowSize({ M.last_size.w, 0 }, ImGuiCond_Always);



    if imgui.Begin('FushBite##Display', true, ui.get_panel_flags()) then

        imgui.SetWindowFontScale(settings.font_scale[1]);

        imgui.SetCursorPos({ pad, pad });



        imgui.PushStyleColor(ImGuiCol_Text, theme.colors.text_gold);

        imgui.Text('Hook Detected');

        imgui.PopStyleColor(1);



        imgui.PushStyleColor(ImGuiCol_Text, theme.hex_to_imgui(M.state.hook_color));

        imgui.SetWindowFontScale(settings.font_scale[1] * 1.15);

        imgui.Text(M.state.hook);

        imgui.PopStyleColor(1);

        imgui.SetWindowFontScale(settings.font_scale[1]);



        imgui.PushStyleColor(ImGuiCol_Text, theme.colors.text_dim);

        imgui.Text('Feeling');

        imgui.PopStyleColor(1);

        imgui.SameLine();

        imgui.PushStyleColor(ImGuiCol_Text, theme.hex_to_imgui(M.state.feel_color));

        imgui.Text(M.state.feel);

        imgui.PopStyleColor(1);



        local size = { imgui.GetWindowSize() };

        M.last_size.w = size[1];

        M.last_size.h = size[2];

    end

    imgui.End();

end



return M;


