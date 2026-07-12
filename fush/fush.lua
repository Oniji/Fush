--[[

* Fush - HorizonXI fishing companion

*

* Bite/feeling overlay, session tracker, and pool resupply bar.

*

* UI rendering and assets adapted from XIUI (https://github.com/tirem/XIUI)

* under the GNU General Public License v3.0. See fush/THIRD_PARTY_NOTICES.md.

]]--



addon.name = 'fush';

addon.author = 'Fush';

addon.version = '0.1.0';

addon.desc = 'Fishing bite tracker, session stats, and pool resupply bar. UI adapted from XIUI (GPLv3).';

addon.link = 'https://github.com/casme/Fush';

addon.commands = { '/fush' };



require('common');

local chat = require('chat');

local settings = require('settings');



local config = require('config');

local ui = require('libs.ui');

local fonts = require('libs.fonts');

local bite = require('modules.bite');

local tracker = require('modules.tracker');

local pool = require('modules.pool');



local function print_help(is_error)

    if is_error then

        print(chat.header(addon.name):append(chat.error('Invalid command.')));

    else

        print(chat.header(addon.name):append(chat.message('Commands:')));

    end



    local cmds = T{

        { '/fush', 'Toggle the config window.' },

        { '/fush config', 'Toggle the config window.' },

        { '/fush report', 'Print session stats to chat.' },

        { '/fush clear', 'Clear the current session.' },

        { '/fush show', 'Show all panels.' },

        { '/fush hide', 'Hide all panels.' },

        { '/fush save', 'Save settings.' },

        { '/fush reload', 'Reload settings.' },

    };



    cmds:ieach(function (v)

        print(chat.header(addon.name)

            :append(chat.error('Usage: '))

            :append(chat.message(v[1]))

            :append(' - ')

            :append(chat.color1(6, v[2])));

    end);

end



ashita.events.register('load', 'load_cb', function ()

    config.ensure_ui_settings();

    ui.bind(config.settings, config.editor_open);

    config.update_pricing();

    tracker.refresh_player_name();
    tracker.bind_skill_settings(config.settings);
    fonts.prewarm();

    if config.settings.reset_on_load[1] then

        tracker.reset_session();

        bite.reset();

    else

        tracker.restore_session();

    end

end);



ashita.events.register('unload', 'unload_cb', function ()

    tracker.persist_session();

    tracker.flush_fishing_skill();

    ui.cleanup();

    settings.save();

end);



ashita.events.register('command', 'command_cb', function (e)

    local args = e.command:args();

    if #args == 0 or not args[1]:any('/fush') then

        return;

    end



    e.blocked = true;



    if #args == 1 or args[2]:any('config', 'edit') then

        config.editor_open[1] = not config.editor_open[1];

        return;

    end



    if args[2]:any('save') then

        config.update_pricing();

        settings.save();

        print(chat.header(addon.name):append(chat.message('Settings saved.')));

        return;

    end



    if args[2]:any('reload') then

        settings.reload();

        config.ensure_ui_settings();

        ui.bind(config.settings, config.editor_open);

        config.update_pricing();

        print(chat.header(addon.name):append(chat.message('Settings reloaded.')));

        return;

    end



    if args[2]:any('report') then

        print(tracker.build_report(config.settings, config.pricing));

        return;

    end



    if args[2]:any('clear') then

        tracker.reset_session();

        bite.reset();

        print(chat.header(addon.name):append(chat.message('Session cleared.')));

        return;

    end



    if args[2]:any('show') then

        config.settings.bite.visible[1] = true;

        config.settings.tracker.visible[1] = true;

        config.settings.pool.visible[1] = true;

        tracker.touch_activity();

        return;

    end



    if args[2]:any('hide') then

        config.settings.bite.visible[1] = false;

        config.settings.tracker.visible[1] = false;

        config.settings.pool.visible[1] = false;

        return;

    end



    print_help(true);

end);



ashita.events.register('text_in', 'text_in_cb', function (e)

    local event_type, hook_type = bite.handle_text(e);

    if event_type == 'hook' then

        tracker.record_hook(hook_type);

    end

    tracker.handle_text(e, bite, config.pricing);

end);



ashita.events.register('packet_in', 'packet_in_cb', function (e)

    bite.handle_packet(e);
    tracker.handle_packet_in(e);

    if e.id == 0x00A then
        tracker.refresh_player_name();
        tracker.restore_fishing_skill();
    end

end);



ashita.events.register('packet_out', 'packet_out_cb', function (e)

    tracker.handle_packet_out(e);

end);



ashita.events.register('d3d_present', 'present_cb', function ()

    if not AshitaCore:GetFontManager():GetVisible() then

        return;

    end



    ui.present_frame_start();

    -- Config stays on Ashita's default ImGui font (Agave ~18px).
    config.render_editor();

    fonts.push(config.settings);

    bite.render(config.settings, config.editor_open[1] and config.settings.bite.visible[1]);

    tracker.render(config.settings, config.pricing, config.editor_open[1] and config.settings.tracker.visible[1]);

    pool.render(config.settings);

    fonts.pop();

end);


