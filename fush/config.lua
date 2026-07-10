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

local tracker = require('modules.tracker');

local bite = require('modules.bite');



local M = {};



M.default_settings = T{

    opacity = T{ 0.92 },

    font_scale = T{ 1.0 },

    reset_on_load = T{ false },

    -- Last known fishing skill. `exact` becomes true after observing a whole-level
    -- tick (tenths are then trustworthy). level is stored as e.g. 66.4.
    fishing_skill = T{
        exact = T{ false },
        level = T{ 0 },
    },

    ui = T{
        background_theme = T{ 'DarkGold' },
        bite = T{
            scale = T{ 1.0 },
            padding = T{ 8 },
            bg_scale = T{ 1.0 },
            border_scale = T{ 1.0 },
            background_opacity = T{ 1.0 },
            border_opacity = T{ 0.9 },
            border_thickness = T{ 2 },
            panel_rounding = T{ 6 },
        },
        tracker = T{
            scale = T{ 1.0 },
            padding = T{ 8 },
            bg_scale = T{ 1.0 },
            border_scale = T{ 1.0 },
            background_opacity = T{ 1.0 },
            border_opacity = T{ 0.9 },
            border_thickness = T{ 2 },
            panel_rounding = T{ 6 },
        },
        pool = T{
            scale = T{ 1.0 },
            padding = T{ 8 },
            bg_scale = T{ 1.0 },
            border_scale = T{ 1.0 },
            background_opacity = T{ 1.0 },
            border_opacity = T{ 0.9 },
            border_thickness = T{ 2 },
            panel_rounding = T{ 6 },
            show_bookends = T{ true },
            bookend_size = T{ 10 },
            bar_border_thickness = T{ 2 },
            no_bookend_rounding = T{ 4 },
        },
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

        font_scale = T{ 1.0 },

        x = T{ 20 },

        y = T{ 120 },

    },



    tracker = T{

        visible = T{ true },

        font_scale = T{ 1.0 },

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

        font_scale = T{ 1.0 },

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



function M.ensure_ui_settings()

    if M.settings.ui == nil then

        M.settings.ui = T{};

    end



    local defaults = M.default_settings.ui;

    local function ensure_ui_section(section_name)
        if M.settings.ui[section_name] == nil then
            M.settings.ui[section_name] = T{};
        end
        for key, value in pairs(defaults[section_name]) do
            if M.settings.ui[section_name][key] == nil then
                M.settings.ui[section_name][key] = value;
            end
        end
    end

    -- Flat keys from previous schema -> per-module schema migration.
    local legacy_map = {
        { old = 'padding', new = 'padding' },
        { old = 'bg_scale', new = 'bg_scale' },
        { old = 'border_scale', new = 'border_scale' },
        { old = 'background_opacity', new = 'background_opacity' },
        { old = 'border_opacity', new = 'border_opacity' },
        { old = 'border_thickness', new = 'border_thickness' },
        { old = 'panel_rounding', new = 'panel_rounding' },
    };

    ensure_ui_section('bite');
    ensure_ui_section('tracker');
    ensure_ui_section('pool');

    for _, map in ipairs(legacy_map) do
        if M.settings.ui[map.old] ~= nil then
            if M.settings.ui.bite[map.new] == nil then M.settings.ui.bite[map.new] = M.settings.ui[map.old]; end
            if M.settings.ui.tracker[map.new] == nil then M.settings.ui.tracker[map.new] = M.settings.ui[map.old]; end
            if M.settings.ui.pool[map.new] == nil then M.settings.ui.pool[map.new] = M.settings.ui[map.old]; end
        end
    end

    local legacy_pool_map = {
        { old = 'show_bookends', new = 'show_bookends' },
        { old = 'bookend_size', new = 'bookend_size' },
        { old = 'bar_border_thickness', new = 'bar_border_thickness' },
        { old = 'no_bookend_rounding', new = 'no_bookend_rounding' },
    };
    for _, map in ipairs(legacy_pool_map) do
        if M.settings.ui[map.old] ~= nil and M.settings.ui.pool[map.new] == nil then
            M.settings.ui.pool[map.new] = M.settings.ui[map.old];
        end
    end

    for key, value in pairs(defaults) do
        if type(value) ~= 'table' or (key ~= 'bite' and key ~= 'tracker' and key ~= 'pool') then
            if M.settings.ui[key] == nil then
                M.settings.ui[key] = value;
            end
        end
    end

end

local function ensure_module_settings(module_name)
    if M.settings[module_name] == nil then
        M.settings[module_name] = T{};
    end

    local defaults = M.default_settings[module_name];
    for key, value in pairs(defaults) do
        if M.settings[module_name][key] == nil then
            M.settings[module_name][key] = value;
        end
    end
end



M.ensure_ui_settings();
ensure_module_settings('bite');
ensure_module_settings('tracker');
ensure_module_settings('pool');

if M.settings.fishing_skill == nil then
    M.settings.fishing_skill = T{
        exact = T{ false },
        level = T{ 0 },
    };
end
if M.settings.fishing_skill.exact == nil then
    M.settings.fishing_skill.exact = T{ false };
end
if M.settings.fishing_skill.level == nil then
    M.settings.fishing_skill.level = T{ 0 };
end



local function trim_line(s)
    if s == nil then
        return '';
    end
    s = s:gsub('\r', '');
    s = s:gsub('^%s+', '');
    s = s:gsub('%s+$', '');
    return s;
end



local function split(input, sep)

    local result = T{};

    for part in string.gmatch(input, '([^' .. sep .. ']+)') do
        part = trim_line(part);
        if part ~= '' then
            result:append(part);
        end
    end

    return result;

end



function M.update_pricing()

    M.pricing = T{};

    for _, entry in ipairs(M.settings.tracker.item_index) do
        entry = trim_line(entry);
        if entry ~= '' then
            local colon = entry:find(':');
            if colon ~= nil and colon > 1 then
                local name = trim_line(entry:sub(1, colon - 1));
                local price = tonumber(trim_line(entry:sub(colon + 1))) or 0;
                if name ~= '' then
                    M.pricing[string.lower(name)] = price;
                end
            end
        end
    end

end



local function render_general()

    imgui.Text('Display');

    imgui.BeginChild('fush_general', { 0, 200 }, true);

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

    local themes = T{ 'DarkGold', 'OceanBlue', 'Transparent', 'Window1', 'Plain' };

    local current_theme = M.settings.ui.background_theme[1];

    for _, theme_name in ipairs(themes) do

        if imgui.RadioButton(theme_name, current_theme == theme_name) then

            M.settings.ui.background_theme[1] = theme_name;
            if theme_name == 'Plain' then
                M.settings.ui.bite.background_opacity[1] = 0.5;
                M.settings.ui.tracker.background_opacity[1] = 0.5;
                M.settings.ui.pool.background_opacity[1] = 0.5;
                M.settings.ui.bite.border_thickness[1] = 0;
                M.settings.ui.tracker.border_thickness[1] = 0;
                M.settings.ui.pool.border_thickness[1] = 0;
            elseif theme_name == 'OceanBlue' then
                -- Sensible defaults on theme switch; sliders remain free to change after.
                M.settings.ui.bite.background_opacity[1] = 0.3;
                M.settings.ui.tracker.background_opacity[1] = 0.3;
                M.settings.ui.pool.background_opacity[1] = 0.3;
                M.settings.ui.bite.border_thickness[1] = 2;
                M.settings.ui.tracker.border_thickness[1] = 2;
                M.settings.ui.pool.border_thickness[1] = 2;
            end

        end

        imgui.SameLine();

    end

    imgui.NewLine();



    local function render_module_style_section(label, module_style, is_pool)
        imgui.Separator();
        imgui.Text(label);
        imgui.SliderFloat(label .. ' Scale', module_style.scale, 0.50, 2.50, '%.2f');
        imgui.SliderInt(label .. ' Panel Padding', module_style.padding, 0, 24);
        imgui.SliderFloat(label .. ' Background Scale', module_style.bg_scale, 0.5, 2.0, '%.2f');
        imgui.SliderFloat(label .. ' Border Scale', module_style.border_scale, 0.5, 2.0, '%.2f');
        imgui.SliderFloat(label .. ' Background Opacity', module_style.background_opacity, 0.0, 1.0, '%.2f');
        imgui.SliderInt(label .. ' Border Thickness', module_style.border_thickness, 0, 6);
        imgui.SliderInt(label .. ' Panel Roundness', module_style.panel_rounding, 0, 16);

        if is_pool then
            imgui.Checkbox('Pool Show Bar Bookends', module_style.show_bookends);
            imgui.SliderInt('Pool Bookend Size', module_style.bookend_size, 5, 20);
            imgui.SliderInt('Pool Bar Border Thickness', module_style.bar_border_thickness, 0, 6);
            imgui.SliderInt('Pool Bar Roundness', module_style.no_bookend_rounding, 0, 16);
        end
    end

    render_module_style_section('Bite', M.settings.ui.bite, false);
    render_module_style_section('Session', M.settings.ui.tracker, false);
    render_module_style_section('Pool', M.settings.ui.pool, true);



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
        M.update_pricing();

    end

end



local function render_positions()

    imgui.BeginChild('fush_positions', { 0, 200 }, true);



    local bite_pos = T{ M.settings.bite.x[1], M.settings.bite.y[1] };
    if imgui.InputInt2('Bite Seam Position', bite_pos) then
        M.settings.bite.x[1] = bite_pos[1];
        M.settings.bite.y[1] = bite_pos[2];
    end
    imgui.TextDisabled('Bite X is the center seam; halves grow outward from it.');



    local tracker_pos = T{ M.settings.tracker.x[1], M.settings.tracker.y[1] };

    if imgui.InputInt2('Tracker Position', tracker_pos) then

        M.settings.tracker.x[1] = tracker_pos[1];

        M.settings.tracker.y[1] = tracker_pos[2];

    end



    local pool_pos = T{ M.settings.pool.x[1], M.settings.pool.y[1] };

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

    M.ensure_ui_settings();



    imgui.SetNextWindowSize({ 540, 600 }, ImGuiCond_FirstUseEver);

    local style_counts = theme.apply_style();



    if imgui.Begin('Fush##Config', M.editor_open) then

        if imgui.Button('Save') then

            M.update_pricing();

            settings.save();

            print(chat.header('fush'):append(chat.message('Settings saved.')));

        end

        imgui.SameLine();

        if imgui.Button('Reload') then

            settings.reload();

            M.ensure_ui_settings();

            ui.bind(M.settings, M.editor_open);

            M.update_pricing();

            print(chat.header('fush'):append(chat.message('Settings reloaded.')));

        end

        imgui.SameLine();

        if imgui.Button('Reset Session') then

            tracker.reset_session();

            bite.reset();

            print(chat.header('fush'):append(chat.message('Session cleared.')));

        end

        imgui.SameLine();

        if imgui.Button('Reset Defaults') then

            settings.reset();

            M.ensure_ui_settings();

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

    theme.pop_style(style_counts);

end



settings.register('settings', 'settings_update', function (s)

    if s ~= nil then

        M.settings = s;

    end

    M.ensure_ui_settings();
    ensure_module_settings('bite');
    ensure_module_settings('tracker');
    ensure_module_settings('pool');

    if M.settings.fishing_skill == nil then
        M.settings.fishing_skill = T{
            exact = T{ false },
            level = T{ 0 },
        };
    end

    ui.bind(M.settings, M.editor_open);

    local tracker = require('modules.tracker');
    tracker.bind_skill_settings(M.settings);

    M.update_pricing();

end);



return M;


