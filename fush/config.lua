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

local fonts = require('libs.fonts');

local attribution = require('libs.attribution');

local tracker = require('modules.tracker');

local bite = require('modules.bite');



local M = {};



M.default_settings = T{

    font_size = T{ 13 },

    reset_on_load = T{ false },

    -- Last known fishing skill. `exact` becomes true after observing a whole-level
    -- tick (tenths are then trustworthy). level is stored as e.g. 66.4.
    fishing_skill = T{
        exact = T{ false },
        level = T{ 0 },
    },

    -- Survives /addon reload unless Reset Session On Load is enabled.
    session_snapshot = T{
        active = T{ false },
        lines_cast = T{ 0 },
        bait_used = T{ 0 },
        hooks = T{ 0 },
        small_fish_bites = T{ 0 },
        large_fish_bites = T{ 0 },
        item_bites = T{ 0 },
        monster_bites = T{ 0 },
        fish_caught = T{ 0 },
        items_caught = T{ 0 },
        monsters_caught = T{ 0 },
        lost = T{ 0 },
        broken = T{ 0 },
        elapsed_ms = T{ 0 },
        activity_ago_ms = T{ 0 },
        skill_gain = T{ 0 },
        skill_start = T{ -1 },
        rewards = T{},
    },

    ui = T{
        background_theme = T{ 'OceanBlue' },
        font_family = T{ 'Tahoma Bold' },
        bite = T{
            scale = T{ 1.0 },
            padding = T{ 8 },
            bg_scale = T{ 1.0 },
            border_scale = T{ 1.0 },
            background_opacity = T{ 0.8 },
            border_opacity = T{ 0.9 },
            border_thickness = T{ 0 },
            panel_rounding = T{ 6 },
        },
        tracker = T{
            scale = T{ 1.0 },
            padding = T{ 6 },
            bg_scale = T{ 1.0 },
            border_scale = T{ 1.0 },
            background_opacity = T{ 0.60 },
            border_opacity = T{ 0.9 },
            border_thickness = T{ 0 },
            panel_rounding = T{ 6 },
        },
        pool = T{
            scale = T{ 1.0 },
            padding = T{ 6 },
            bg_scale = T{ 1.0 },
            border_scale = T{ 1.0 },
            background_opacity = T{ 0.60 },
            border_opacity = T{ 0.9 },
            border_thickness = T{ 0 },
            panel_rounding = T{ 6 },
            show_bookends = T{ false },
            bookend_size = T{ 10 },
            bar_border_thickness = T{ 0 },
            no_bookend_rounding = T{ 0 },
            show_next_restock = T{ true },
            show_vana_time = T{ true },
            show_moon_phase = T{ true },
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

        bait_cost = T{ 1 },

        subtract_bait = T{ false },

        use_lure = T{ false },

        item_index = T{
            'abaia:1920',
            'ahtapot:700',
            'alabaligi:98',
            'ancient carp:0',
            'apkallufa:1000',
            'armored pisces:969',
            'aurora bass:0',
            'barnacle:230',
            'bastore bream:615',
            'bastore sardine:8',
            'bastore sweeper:93',
            'betta:400',
            'bhefhel marlin:307',
            'bibiki slug:10',
            'bibiki urchin:750',
            'bibikibo:99',
            'black bubble-eye:9',
            'black eel:192',
            'black ghost:600',
            'black prawn:96',
            'black sole:700',
            'bladefish:408',
            'blindfish:229',
            'bluetail:300',
            'bloodblotch:0',
            'blowfish:469',
            'bonefish:0',
            'brass loach:276',
            'ca cuong:560',
            'caedarva frog:100',
            'calico comet:12',
            'cameroceras:0',
            'cave cherax:1600',
            'cheval salmon:20',
            'clump of adoulinian kelp:31',
            'clump of pamtam kelp:8',
            'cobalt jellyfish:8',
            'cone calamary:165',
            'contortopus:0',
            'contortacle:0',
            'coral butterfly:125',
            'copper frog:20',
            'crocodilos:3526',
            'crayfish:10',
            'crescent fish:403',
            'crystal bass:0',
            'dark bass:20',
            'deademoiselle:100',
            'denizanasi:7',
            'dil:700',
            'dorado gar:5783',
            'dragonfish:0',
            'dragon\'s tabernacle:0',
            'dragonfly trout:0',
            'dwarf remora:100',
            'elshimo frog:52',
            'elshimo newt:175',
            'emperor fish:615',
            'far east puffer:0',
            'forest carp:22',
            'frigorifish:100',
            'garpike:610',
            'gavial fish:500',
            'gerrothorax:118',
            'giant catfish:102',
            'giant chirai:1100',
            'giant donko:195',
            'gigant octopus:238',
            'gigant squid:612',
            'gold carp:289',
            'gold lobster:194',
            'greedie:11',
            'grimmonite:717',
            'gugru tuna:100',
            'gugrusaurus:1760',
            'gurnard:475',
            'hakuryu:10542',
            'hamsi:7',
            'icefish:156',
            'istakoz:200',
            'istavrit:100',
            'istiridye:279',
            'jacknife:53',
            'jungle catfish:627',
            'kalamar:170',
            'kalkanbaligi:780',
            'kaplumbaga:830',
            'kayabaligi:310',
            'kilicbaligi:450',
            'king perch:877',
            'kokuryu:10568',
            'lamp marimo:786',
            'lakerda:103',
            'lik:1760',
            'lionhead:12',
            'lord of ulbuka:0',
            'lungfish:231',
            'mackerel:21',
            'malicious perch:0',
            'matsya:25688',
            'megalodon:864',
            'mercanbaligi:600',
            'moat carp:10',
            'mola mola:975',
            'monke-onke:306',
            'moorish idol:242',
            'morinabaligi:548',
            'muddy siredon:0',
            'mussel:0',
            'nebimonite:52',
            'noble lady:400',
            'nosteau herring:80',
            'ogre eel:32',
            'pearlscale:12',
            'pelazoea:734',
            'phanauet newt:4',
            'phantom serpent:0',
            'pipira:46',
            'pirarucu:901',
            'pterygotus:780',
            'quicksilver blade:0',
            'quus:20',
            'rakaznar shellfish:0',
            'red bubble-eye:356',
            'red terrapin:306',
            'remora:100',
            'rhinochimera:613',
            'ruddy seema:0',
            'ryugu titan:1500',
            'sandfish:26',
            'sazanbaligi:300',
            'sea zombie:628',
            'sekiryu:9200',
            'senroh frog:0',
            'senroh sardine:0',
            'shall shell:300',
            'shen:0',
            'shining trout:26',
            'shockfish:0',
            'silver shark:500',
            'soryu:10516',
            'takitaro:714',
            'tavnazian goby:400',
            'three-eyed fish:512',
            'thysanopeltis:0',
            'tiny goldfish:1',
            'tiger cod:52',
            'tiger shark:0',
            'titanic sawfish:1620',
            'titanictus:700',
            'translucent salpa:0',
            'tricolored carp:52',
            'tricorn:616',
            'trilobite:40',
            'tropical clam:5100',
            'trumpet shell:512',
            'turnabaligi:693',
            'tusoteuthis longa:0',
            'ulbukan lobster:0',
            'uskumru:300',
            'veydal wrasse:420',
            'vongola clam:192',
            'white lobster:0',
            'yawning catfish:0',
            'yayinbaligi:225',
            'yellow globe:20',
            'yilanbaligi:200',
            'yorchete:100',
            'zafmlug bass:31',
            'zebra eel:385',
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

    if M.settings.font_size == nil then
        M.settings.font_size = T{ 13 };
    else
        local size = tonumber(M.settings.font_size[1]) or 13;
        if size < 6 then size = 6; end
        if size > 30 then size = 30; end
        M.settings.font_size[1] = math.floor(size + 0.5);
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

    if M.settings.ui.font_family == nil then
        M.settings.ui.font_family = T{ 'Tahoma Bold' };
    end

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

    -- Removed themes: map legacy choices to OceanBlue.
    local theme_name = M.settings.ui.background_theme and M.settings.ui.background_theme[1];
    if theme_name == 'Transparent' or theme_name == 'Window1' or theme_name == nil or theme_name == '' then
        M.settings.ui.background_theme = T{ 'OceanBlue' };
    end

    -- Force locked appearance values AFTER legacy migration (controls removed from UI).
    local function lock(module_cfg, key, value)
        if module_cfg[key] == nil then
            module_cfg[key] = T{ value };
        else
            module_cfg[key][1] = value;
        end
    end

    lock(M.settings.ui.bite, 'padding', 8);
    lock(M.settings.ui.bite, 'bg_scale', 1.0);
    lock(M.settings.ui.bite, 'border_scale', 1.0);
    lock(M.settings.ui.bite, 'panel_rounding', 6);

    lock(M.settings.ui.tracker, 'padding', 6);
    lock(M.settings.ui.tracker, 'bg_scale', 1.0);
    lock(M.settings.ui.tracker, 'border_scale', 1.0);
    lock(M.settings.ui.tracker, 'panel_rounding', 6);

    lock(M.settings.ui.pool, 'padding', 6);
    lock(M.settings.ui.pool, 'bg_scale', 1.0);
    lock(M.settings.ui.pool, 'border_scale', 1.0);
    lock(M.settings.ui.pool, 'panel_rounding', 6);
    lock(M.settings.ui.pool, 'show_bookends', false);
    lock(M.settings.ui.pool, 'bar_border_thickness', 0);
    lock(M.settings.ui.pool, 'no_bookend_rounding', 0);

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



-- Remaining content-region height for panels that should grow with the window.
local function fill_height(min_h)
    min_h = min_h or 80;
    local avail_w, avail_h = imgui.GetContentRegionAvail();
    if type(avail_w) == 'table' then
        avail_h = avail_w[2];
    end
    avail_h = tonumber(avail_h) or 0;
    if avail_h < min_h then
        return min_h;
    end
    return avail_h;
end

local function render_general()

    imgui.Text('Modules');

    imgui.BeginChild('fush_modules', { 0, 130 }, true);

    imgui.Checkbox('Bite Tracker', M.settings.bite.visible);

    imgui.Checkbox('Session Tracker', M.settings.tracker.visible);

    imgui.Checkbox('Pool Resupply Bar', M.settings.pool.visible);

    imgui.Checkbox('Reset Session On Load', M.settings.reset_on_load);

    imgui.EndChild();



    imgui.Text('Fonts');

    imgui.BeginChild('fush_fonts', { 0, 100 }, true);

    if M.settings.font_size == nil then
        M.settings.font_size = T{ 13 };
    end
    if imgui.InputInt('Font Size', M.settings.font_size) then
        if M.settings.font_size[1] < 6 then M.settings.font_size[1] = 6; end
        if M.settings.font_size[1] > 30 then M.settings.font_size[1] = 30; end
    end

    if M.settings.ui.font_family == nil then
        M.settings.ui.font_family = T{ 'Tahoma Bold' };
    end
    fonts.render_combo(M.settings.ui.font_family);

    imgui.EndChild();

end



local function render_appearance()

    imgui.BeginChild('fush_appearance', { 0, fill_height(280) }, true);

    imgui.Text('Window Theme');

    local themes = T{ 'DarkGold', 'OceanBlue', 'Plain' };

    local current_theme = M.settings.ui.background_theme[1];

    for _, theme_name in ipairs(themes) do

        if imgui.RadioButton(theme_name, current_theme == theme_name) then
            M.settings.ui.background_theme[1] = theme_name;
        end

        imgui.SameLine();

    end

    imgui.NewLine();

    local function render_module_style_section(label, module_style)
        imgui.Separator();
        imgui.Text(label);
        imgui.SliderFloat(label .. ' Scale', module_style.scale, 0.50, 2.50, '%.2f');
        imgui.SliderFloat(label .. ' Background Opacity', module_style.background_opacity, 0.0, 1.0, '%.2f');
        imgui.SliderInt(label .. ' Border Thickness', module_style.border_thickness, 0, 6);
    end

    render_module_style_section('Bite', M.settings.ui.bite);
    render_module_style_section('Session', M.settings.ui.tracker);
    render_module_style_section('Pool', M.settings.ui.pool);

    if M.settings.ui.pool.show_next_restock == nil then
        M.settings.ui.pool.show_next_restock = T{ true };
    end
    if M.settings.ui.pool.show_vana_time == nil then
        M.settings.ui.pool.show_vana_time = T{ true };
    end
    if M.settings.ui.pool.show_moon_phase == nil then
        M.settings.ui.pool.show_moon_phase = T{ true };
    end
    imgui.Checkbox('Show Next Restock', M.settings.ui.pool.show_next_restock);
    imgui.Checkbox('Show Vana Time', M.settings.ui.pool.show_vana_time);
    imgui.Checkbox('Show Moon Phase', M.settings.ui.pool.show_moon_phase);

    imgui.EndChild();

end



local function render_tracker()

    imgui.BeginChild('fush_tracker_cfg', { 0, 123 }, true);

    imgui.InputInt('Display Timeout (sec)', M.settings.tracker.display_timeout);

    imgui.InputInt('Bait Cost (per cast)', M.settings.tracker.bait_cost);

    imgui.Checkbox('Subtract Bait Cost', M.settings.tracker.subtract_bait);

    imgui.Checkbox('Using Lure (skip bait cost)', M.settings.tracker.use_lure);

    imgui.EndChild();



    imgui.Text('Item Prices (name:price, one per line)');

    local temp = T{ table.concat(M.settings.tracker.item_index, '\n') };

    if imgui.InputTextMultiline('##fush_prices', temp, 8192, { 0, fill_height(120) }) then

        M.settings.tracker.item_index = split(temp[1], '\n');
        M.update_pricing();

    end

end



local function do_reset_defaults()
    settings.reset();
    M.ensure_ui_settings();
    ui.bind(M.settings, M.editor_open);
    M.update_pricing();
    print(chat.header('fush'):append(chat.message('Settings reset.')));
end

local function render_positions()

    imgui.BeginChild('fush_positions', { 0, 280 }, true);

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

    imgui.Separator();
    imgui.Spacing();

    if imgui.Button('Reset Defaults') then
        imgui.OpenPopup('FushResetDefaults##Confirm');
    end
    imgui.TextDisabled('Restores all Fush settings to factory defaults.');

    if imgui.BeginPopupModal('FushResetDefaults##Confirm', nil, ImGuiWindowFlags_AlwaysAutoResize) then
        imgui.Text('Reset all Fush settings to defaults?');
        imgui.TextWrapped('This cannot be undone. Saved positions, prices, fonts, and appearance will be lost.');
        imgui.Spacing();
        if imgui.Button('Confirm Reset', { 140, 0 }) then
            do_reset_defaults();
            imgui.CloseCurrentPopup();
        end
        imgui.SameLine();
        if imgui.Button('Cancel', { 140, 0 }) then
            imgui.CloseCurrentPopup();
        end
        imgui.EndPopup();
    end

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

                imgui.BeginChild('fush_about', { 0, fill_height(200) }, true);

                ui.render_about();

                imgui.Spacing();

                imgui.TextDisabled(attribution.XIUI_LICENSE);

                imgui.EndChild();

                imgui.EndTabItem();

            end

            imgui.EndTabBar();

        end

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


