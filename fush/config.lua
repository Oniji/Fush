--[[

* Fush - Configuration UI and settings

*

* UI rendering adapted from XIUI (https://github.com/tirem/XIUI), GPLv3.

* See THIRD_PARTY_NOTICES.md for attribution details.

]]--



require('common');

local chat = require('chat');

local imgui = require('imgui');

local settings = require('settings');

local theme = require('libs.theme');

local ui = require('libs.ui');

local attribution = require('libs.attribution');



local M = {};



M.default_settings = T{

    opacity = T{ 0.92 },

    font_scale = T{ 1.0 },

    reset_on_load = T{ false },



    ui = T{

        background_theme = T{ 'Window1' },

        padding = T{ 8 },

        bg_scale = T{ 1.0 },

        border_scale = T{ 1.0 },

        background_opacity = T{ 1.0 },

        border_opacity = T{ 1.0 },

        show_bookends = T{ true },

        bookend_size = T{ 10 },

        bar_border_thickness = T{ 2 },

        no_bookend_rounding = T{ 4 },

        background_gradient_start = T{ '#01122b' },

        background_gradient_end = T{ '#061c39' },

        bookend_gradient_start = T{ '#576C92' },

        bookend_gradient_mid = T{ '#B7C9FF' },

        bookend_gradient_stop = T{ '#576C92' },

        bar_fill_start = T{ '#3798ce' },

        bar_fill_end = T{ '#78c5ee' },

        notch_color = T{ '#F2D159' },

        notch_passed_color = T{ '#738299' },

    },



    bite = T{

        visible = T{ true },

        x = T{ 20 },

        y = T{ 120 },

    },



    tracker = T{

        visible = T{ true },

        x = T{ 20 },

        y = T{ 320 },

        display_timeout = T{ 600 },

        bait_cost = T{ 8 },

        subtract_bait = T{ true },

        use_lure = T{ false },

        item_index = T{

            'moat carp:200',

            'crayfish:500',

        },

    },



    pool = T{

        visible = T{ true },

        x = T{ 20 },

        y = T{ 520 },

        width = T{ 360 },

        height = T{ 14 },

    },

};



M.settings = settings.load(M.default_settings);

M.pricing = T{};

M.editor_open = T{ false };



ui.bind(M.settings, M.editor_open);



local function split(input, sep)

    local result = T{};

    for part in string.gmatch(input, '([^' .. sep .. ']+)') do

        result:append(part);

    end

    return result;

end



function M.update_pricing()

    M.pricing = T{};

    for _, entry in ipairs(M.settings.tracker.item_index) do

        local parts = split(entry, ':');

        if #parts >= 2 then

            M.pricing[string.lower(parts[1])] = tonumber(parts[2]) or 0;

        end

    end

end



local function render_general()

    imgui.Text('Display');

    imgui.BeginChild('fush_general', { 0, 120 }, true);

    imgui.SliderFloat('Opacity', M.settings.opacity, 0.125, 1.0, '%.2f');

    imgui.SliderFloat('Font Scale', M.settings.font_scale, 0.5, 2.0, '%.2f');

    imgui.Checkbox('Reset Session On Load', M.settings.reset_on_load);

    imgui.EndChild();



    imgui.Text('Modules');

    imgui.BeginChild('fush_modules', { 0, 110 }, true);

    imgui.Checkbox('Bite Tracker', M.settings.bite.visible);

    imgui.Checkbox('Session Tracker', M.settings.tracker.visible);

    imgui.Checkbox('Pool Resupply Bar', M.settings.pool.visible);

    imgui.EndChild();

end



local function render_appearance()

    imgui.BeginChild('fush_appearance', { 0, 360 }, true);



    imgui.Text('Window Theme');

    local themes = T{ 'Window1', 'Plain' };

    local current_theme = M.settings.ui.background_theme[1];

    for _, theme_name in ipairs(themes) do

        if imgui.RadioButton(theme_name, current_theme == theme_name) then

            M.settings.ui.background_theme[1] = theme_name;

        end

        imgui.SameLine();

    end

    imgui.NewLine();



    imgui.SliderInt('Panel Padding', M.settings.ui.padding, 4, 16);

    imgui.SliderFloat('Background Scale', M.settings.ui.bg_scale, 0.5, 2.0, '%.2f');

    imgui.SliderFloat('Border Scale', M.settings.ui.border_scale, 0.5, 2.0, '%.2f');

    imgui.Checkbox('Show Bar Bookends', M.settings.ui.show_bookends);

    imgui.SliderInt('Bookend Size', M.settings.ui.bookend_size, 5, 20);

    imgui.SliderInt('Bar Border Thickness', M.settings.ui.bar_border_thickness, 0, 5);

    imgui.SliderInt('Bar Roundness (no bookends)', M.settings.ui.no_bookend_rounding, 0, 10);



    imgui.EndChild();

end



local function render_tracker()

    imgui.BeginChild('fush_tracker_cfg', { 0, 220 }, true);

    imgui.InputInt('Display Timeout (sec)', M.settings.tracker.display_timeout);

    imgui.InputInt('Bait Cost (per cast)', M.settings.tracker.bait_cost);

    imgui.Checkbox('Subtract Bait Cost', M.settings.tracker.subtract_bait);

    imgui.Checkbox('Using Lure (skip bait cost)', M.settings.tracker.use_lure);

    imgui.EndChild();



    imgui.Text('Item Prices (name:price, one per line)');

    local temp = T{ table.concat(M.settings.tracker.item_index, '\n') };

    if imgui.InputTextMultiline('##fush_prices', temp, 8192, { 0, 180 }) then

        M.settings.tracker.item_index = split(temp[1], '\n');

    end

end



local function render_positions()

    imgui.BeginChild('fush_positions', { 0, 200 }, true);



    local bite_pos = { M.settings.bite.x[1], M.settings.bite.y[1] };

    if imgui.InputInt2('Bite Position', bite_pos) then

        M.settings.bite.x[1] = bite_pos[1];

        M.settings.bite.y[1] = bite_pos[2];

    end



    local tracker_pos = { M.settings.tracker.x[1], M.settings.tracker.y[1] };

    if imgui.InputInt2('Tracker Position', tracker_pos) then

        M.settings.tracker.x[1] = tracker_pos[1];

        M.settings.tracker.y[1] = tracker_pos[2];

    end



    local pool_pos = { M.settings.pool.x[1], M.settings.pool.y[1] };

    if imgui.InputInt2('Pool Bar Position', pool_pos) then

        M.settings.pool.x[1] = pool_pos[1];

        M.settings.pool.y[1] = pool_pos[2];

    end



    imgui.InputInt('Pool Bar Width', M.settings.pool.width);

    imgui.InputInt('Pool Bar Height', M.settings.pool.height);

    imgui.EndChild();

end



function M.render_editor()

    if not M.editor_open[1] then

        return;

    end



    imgui.SetNextWindowSize({ 540, 600 }, ImGuiCond_FirstUseEver);

    local style_count = theme.apply_style();



    if imgui.Begin('Fush##Config', M.editor_open) then

        if imgui.Button('Save') then

            M.update_pricing();

            settings.save();

            print(chat.header('fush'):append(chat.message('Settings saved.')));

        end

        imgui.SameLine();

        if imgui.Button('Reload') then

            settings.reload();

            ui.bind(M.settings, M.editor_open);

            M.update_pricing();

            print(chat.header('fush'):append(chat.message('Settings reloaded.')));

        end

        imgui.SameLine();

        if imgui.Button('Reset Defaults') then

            settings.reset();

            ui.bind(M.settings, M.editor_open);

            M.update_pricing();

            print(chat.header('fush'):append(chat.message('Settings reset.')));

        end



        imgui.Separator();



        if imgui.BeginTabBar('##fush_tabs') then

            if imgui.BeginTabItem('General') then

                render_general();

                imgui.EndTabItem();

            end

            if imgui.BeginTabItem('Appearance') then

                render_appearance();

                imgui.EndTabItem();

            end

            if imgui.BeginTabItem('Tracker') then

                render_tracker();

                imgui.EndTabItem();

            end

            if imgui.BeginTabItem('Layout') then

                render_positions();

                imgui.EndTabItem();

            end

            if imgui.BeginTabItem('About') then

                imgui.BeginChild('fush_about', { 0, 360 }, true);

                ui.render_about();

                imgui.Spacing();

                imgui.TextDisabled(attribution.XIUI_LICENSE);

                imgui.EndChild();

                imgui.EndTabItem();

            end

            imgui.EndTabBar();

        end

        ui.render_credit_footer();

    end

    imgui.End();

    theme.pop_style(style_count);

end



settings.register('settings', 'settings_update', function (s)

    if s ~= nil then

        M.settings = s;

    end

    ui.bind(M.settings, M.editor_open);

    M.update_pricing();

    settings.save();

end);



return M;


