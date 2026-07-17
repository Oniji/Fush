--[[
* Fush UI bridge — XIUI rendering wrappers
* https://github.com/tirem/XIUI — GNU GPL v3
]]--

require('common');
local imgui = require('imgui');
local colorLib = require('libs.color');
local drawing = require('libs.drawing');
local windowbackground = require('libs.windowbackground');
local progressbar = require('libs.progressbar');
local TextureManager = require('libs.texturemanager');
local attribution = require('libs.attribution');
local theme = require('libs.theme');

local M = {};

local current_settings = nil;
local editor_open = nil;
local active_drag = nil;

local OUTLINE_OFFSETS = {
    { -1, -1 }, { 0, -1 }, { 1, -1 },
    { -1,  0 },             { 1,  0 },
    { -1,  1 }, { 0,  1 }, { 1,  1 },
};

local function clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function vec4_to_u32(c)
    local r = math.floor(clamp01(c[1] or c.r or 1) * 255 + 0.5);
    local g = math.floor(clamp01(c[2] or c.g or 1) * 255 + 0.5);
    local b = math.floor(clamp01(c[3] or c.b or 1) * 255 + 0.5);
    local a = math.floor(clamp01(c[4] or c.a or 1) * 255 + 0.5);
    -- IM_COL32 packs as ABGR in memory.
    return bit.bor(bit.lshift(a, 24), bit.lshift(b, 16), bit.lshift(g, 8), r);
end

local function ui_settings(settings)
    settings = settings or current_settings;
    if settings == nil or settings.ui == nil then
        return nil;
    end
    return settings.ui;
end

local function get_theme_name(settings)
    local ui = ui_settings(settings);
    local name = ui and ui.background_theme[1] or 'OceanBlue';
    if name == 'Transparent' or name == 'Window1' then
        return 'OceanBlue';
    end
    return name;
end

local MODULE_DEFAULTS = {
    bite = { scale = 1.0, padding = 8, bg_scale = 1.0, border_scale = 1.0, background_opacity = 0.8, border_opacity = 0.9, border_thickness = 0, panel_rounding = 6 },
    tracker = { scale = 1.0, padding = 6, bg_scale = 1.0, border_scale = 1.0, background_opacity = 0.60, border_opacity = 0.9, border_thickness = 0, panel_rounding = 6 },
    pool = { scale = 1.0, padding = 6, bg_scale = 1.0, border_scale = 1.0, background_opacity = 0.60, border_opacity = 0.9, border_thickness = 0, panel_rounding = 6, show_bookends = false, bookend_size = 10, bar_border_thickness = 0, no_bookend_rounding = 0 },
    ship = { scale = 1.0, padding = 6, bg_scale = 1.0, border_scale = 1.0, background_opacity = 0.60, border_opacity = 0.9, border_thickness = 0, panel_rounding = 6 },
};

local function module_settings(settings, module_name)
    local ui = ui_settings(settings);
    module_name = module_name or 'tracker';
    local defaults = MODULE_DEFAULTS[module_name] or MODULE_DEFAULTS.tracker;
    local module_cfg = ui and ui[module_name] or nil;
    return module_cfg, defaults;
end

function M.bind(settings, editor_open_ref)
    current_settings = settings;
    editor_open = editor_open_ref;

    progressbar.set_style_provider(function ()
        local ui = ui_settings();
        local pool_cfg, pool_defaults = module_settings(current_settings, 'pool');
        if ui == nil then
            return {
                show_bookends = pool_defaults.show_bookends,
                bookend_size = pool_defaults.bookend_size,
                bar_border_thickness = pool_defaults.bar_border_thickness,
                no_bookend_rounding = pool_defaults.no_bookend_rounding,
                background_gradient_start = '#01122b',
                background_gradient_end = '#061c39',
                bookend_gradient_start = '#576C92',
                bookend_gradient_mid = '#B7C9FF',
                bookend_gradient_stop = '#576C92',
            };
        end
        return {
            show_bookends = pool_cfg and pool_cfg.show_bookends and pool_cfg.show_bookends[1] or pool_defaults.show_bookends,
            bookend_size = pool_cfg and pool_cfg.bookend_size and pool_cfg.bookend_size[1] or pool_defaults.bookend_size,
            bar_border_thickness = pool_cfg and pool_cfg.bar_border_thickness and pool_cfg.bar_border_thickness[1] or pool_defaults.bar_border_thickness,
            no_bookend_rounding = pool_cfg and pool_cfg.no_bookend_rounding and pool_cfg.no_bookend_rounding[1] or pool_defaults.no_bookend_rounding,
            background_gradient_start = ui.background_gradient_start[1],
            background_gradient_end = ui.background_gradient_end[1],
            bookend_gradient_start = ui.bookend_gradient_start[1],
            bookend_gradient_mid = ui.bookend_gradient_mid[1],
            bookend_gradient_stop = ui.bookend_gradient_stop[1],
        };
    end);
end

function M.present_frame_start()
    theme.set_active(get_theme_name(current_settings));
    TextureManager.FlushPendingReleases();
end

function M.cleanup()
    progressbar.Cleanup();
    TextureManager.clear();
    colorLib.InvalidateColorCaches();
end

function M.is_editor_open()
    return editor_open ~= nil and editor_open[1] == true;
end

function M.is_transparent_theme(settings)
    return get_theme_name(settings) == 'Transparent';
end

-- Persistent open refs so Begin does not get a bare `true` (which can force
-- a titled/closable host window that looks like a debug popup).
M.panel_open = {
    bite = { true },
    tracker = { true },
    pool = { true },
    ship = { true },
};

function M.get_panel_flags()
    -- Prefer explicit title/chrome flags over NoDecoration alone: some Ashita
    -- ImGui builds do not define NoDecoration, which left a titled host window.
    return bit.bor(
        ImGuiWindowFlags_NoTitleBar,
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_NoScrollWithMouse,
        ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoFocusOnAppearing,
        ImGuiWindowFlags_NoNav,
        ImGuiWindowFlags_NoBackground
    );
end

function M.get_panel_open(id)
    return M.panel_open[id] or M.panel_open.tracker;
end

function M.get_module_scale(settings, module_name)
    local module_cfg, defaults = module_settings(settings, module_name);
    local module_scale = defaults.scale;
    if module_cfg and module_cfg.scale then
        module_scale = module_cfg.scale[1];
    end

    local fonts = require('libs.fonts');
    return module_scale * fonts.get_scale(settings);
end

function M.get_padding(settings, module_name)
    local module_cfg, defaults = module_settings(settings, module_name);
    if module_cfg and module_cfg.padding then
        return module_cfg.padding[1];
    end
    return defaults.padding;
end

function M.get_background_options(settings, module_name)
    local ui = ui_settings(settings);
    if ui == nil then
        return { theme = 'OceanBlue', padding = 8 };
    end

    local module_cfg, defaults = module_settings(settings, module_name);
    local opts = {
        theme = get_theme_name(settings),
        padding = module_cfg and module_cfg.padding and module_cfg.padding[1] or defaults.padding,
        paddingY = module_cfg and module_cfg.padding and module_cfg.padding[1] or defaults.padding,
        bgScale = module_cfg and module_cfg.bg_scale and module_cfg.bg_scale[1] or defaults.bg_scale,
        borderScale = module_cfg and module_cfg.border_scale and module_cfg.border_scale[1] or defaults.border_scale,
        bgOpacity = module_cfg and module_cfg.background_opacity and module_cfg.background_opacity[1] or defaults.background_opacity,
        borderOpacity = module_cfg and module_cfg.border_opacity and module_cfg.border_opacity[1] or defaults.border_opacity,
        borderThickness = module_cfg and module_cfg.border_thickness and module_cfg.border_thickness[1] or defaults.border_thickness,
        panelRounding = module_cfg and module_cfg.panel_rounding and module_cfg.panel_rounding[1] or defaults.panel_rounding,
    };

    if opts.theme == 'Plain' then
        -- Keep the user's opacity slider; only force border off.
        opts.borderOpacity = 0.0;
        opts.borderThickness = 0;
        opts.panel_bg_hex = '#000000';
    elseif opts.theme == 'OceanBlue' or opts.theme == 'GreenGold' or opts.theme == 'DarkGold' then
        local palette = theme.get_palette(opts.theme);
        opts.borderOpacity = opts.borderOpacity or 0.95;
        opts.panel_bg_hex = palette.panel_bg_hex;
        opts.panel_border_hex = palette.panel_border_hex;
    end

    return opts;
end

function M.draw_dark_panel(draw_list, x, y, w, h, settings, module_name)
    local opts = M.get_background_options(settings, module_name);
    local pad = opts.padding or 8;
    local opacity = opts.bgOpacity or 0.92;
    local rounding = opts.panelRounding or 6;
    local thickness = opts.borderThickness or 2;
    local theme_name = opts.theme or 'OceanBlue';
    local palette = theme.get_palette(theme_name);

    local bx = x - pad;
    local by = y - pad;
    local bw = w + (pad * 2);
    local bh = h + (pad * 2);

    local bg = colorLib.HexToImGui(opts.panel_bg_hex or palette.panel_bg_hex or '#0D0D0D');
    bg[4] = opacity;
    local border = colorLib.HexToImGui(opts.panel_border_hex or palette.panel_border_hex or '#F4DA97');
    border[4] = opts.borderOpacity or 0.9;

    draw_list:AddRectFilled({ bx, by }, { bx + bw, by + bh }, imgui.GetColorU32(bg), rounding);
    if thickness > 0 then
        draw_list:AddRect({ bx, by }, { bx + bw, by + bh }, imgui.GetColorU32(border), rounding, 0, thickness);
    end
end

function M.draw_plain_panel(draw_list, x, y, w, h, settings, module_name)
    local opts = M.get_background_options(settings, module_name);
    local pad = opts.padding or 8;
    local bx = x - pad;
    local by = y - pad;
    local bw = w + (pad * 2);
    local bh = h + (pad * 2);
    local bg = colorLib.HexToImGui('#000000');
    bg[4] = opts.bgOpacity or 0.5;
    draw_list:AddRectFilled({ bx, by }, { bx + bw, by + bh }, imgui.GetColorU32(bg), opts.panelRounding or 0);
end

function M.draw_panel_background(draw_list, x, y, w, h, settings, module_name)
    local opts = M.get_background_options(settings, module_name);
    local theme_name = opts.theme or 'OceanBlue';

    if theme_name == 'Transparent' then
        return;
    end

    if theme_name == 'Plain' then
        M.draw_plain_panel(draw_list, x, y, w, h, settings, module_name);
        return;
    end

    if theme_name == 'Window1' then
        windowbackground.Draw(draw_list, x, y, w, h, opts);
        return;
    end

    M.draw_dark_panel(draw_list, x, y, w, h, settings, module_name);
end

function M.get_show_bookends(settings)
    local pool_cfg, defaults = module_settings(settings, 'pool');
    if pool_cfg and pool_cfg.show_bookends then
        return pool_cfg.show_bookends[1];
    end
    return defaults.show_bookends;
end

function M.draw_progress_bar(settings, progress, width, height, x, y, draw_list)
    local ui = ui_settings(settings);
    local fillStart = ui and ui.bar_fill_start[1] or '#3798ce';
    local fillEnd = ui and ui.bar_fill_end[1] or '#78c5ee';
    local decorate = M.get_show_bookends(settings);

    progressbar.ProgressBar({
        { progress, { fillStart, fillEnd } },
    }, { width, height }, {
        drawList = draw_list,
        absolutePosition = { x, y },
        decorate = decorate,
    });

    return M.get_progress_bar_content_rect(settings, width, height, x, y);
end

function M.get_progress_bar_content_rect(settings, width, height, x, y)
    local decorate = M.get_show_bookends(settings);
    local pool_cfg, defaults = module_settings(settings, 'pool');
    local bookend = decorate and (pool_cfg and pool_cfg.bookend_size and pool_cfg.bookend_size[1] or defaults.bookend_size) or 0;
    local content_x = x + bookend;
    local content_w = math.max(0, width - (bookend * 2));
    return content_x, y, content_w, height;
end

function M.draw_restock_pulse(draw_list, bar_x, bar_y, bar_w, bar_h, progress, pulse_t)
    if pulse_t == nil or pulse_t < 0 or pulse_t > 1 then
        return;
    end

    local fill_w = math.max(0, bar_w * math.clamp(progress, 0, 1));
    if fill_w < 4 then
        return;
    end

    -- Narrow bright band sweeping across the filled portion.
    local band_w = math.max(10, fill_w * 0.22);
    local travel = fill_w + band_w;
    local band_x = bar_x + (travel * pulse_t) - band_w;
    local left = math.max(bar_x, band_x);
    local right = math.min(bar_x + fill_w, band_x + band_w);
    if right <= left then
        return;
    end

    -- Soft envelope: brighter mid-sweep, fades near start/end.
    local envelope = math.sin(pulse_t * math.pi);
    local alpha = 0.18 + (0.42 * envelope);

    local top = { 0.90, 0.97, 1.0, alpha };
    local mid = { 1.0, 1.0, 1.0, alpha * 0.95 };
    local bot = { 0.72, 0.90, 1.0, alpha * 0.75 };

    local mid_y = bar_y + (bar_h * 0.5);
    draw_list:AddRectFilledMultiColor(
        { left, bar_y },
        { right, mid_y },
        imgui.GetColorU32(top),
        imgui.GetColorU32(top),
        imgui.GetColorU32(mid),
        imgui.GetColorU32(mid)
    );
    draw_list:AddRectFilledMultiColor(
        { left, mid_y },
        { right, bar_y + bar_h },
        imgui.GetColorU32(mid),
        imgui.GetColorU32(mid),
        imgui.GetColorU32(bot),
        imgui.GetColorU32(bot)
    );
end

function M.draw_notches(draw_list, x, y, width, height, notches, progress, settings)
    local ui = ui_settings(settings);
    local active = colorLib.HexToImGui(ui and ui.notch_color[1] or '#F2D159');
    local passed = colorLib.HexToImGui(ui and ui.notch_passed_color[1] or '#738299');

    for _, notch in ipairs(notches) do
        local nx = x + (width * notch.progress);
        local is_passed = notch.progress <= progress;
        draw_list:AddLine(
            { nx, y - 2 },
            { nx, y + height + 2 },
            imgui.GetColorU32(is_passed and passed or active),
            is_passed and 1.5 or 2.5
        );
    end
end

function M.draw_time_cursor(draw_list, x, y, width, progress, settings)
    local cx = x + (width * progress);
    local tex = TextureManager.getFileTexture('arrow');
    local ptr = TextureManager.getTexturePtr(tex);

    if ptr ~= nil then
        draw_list:AddImage(ptr, { cx - 6, y - 14 }, { cx + 6, y - 2 }, { 0, 0 }, { 1, 1 }, IM_COL32_WHITE);
        return;
    end

    draw_list:AddTriangleFilled(
        { cx, y - 6 },
        { cx - 5, y - 12 },
        { cx + 5, y - 12 },
        imgui.GetColorU32({ 1, 1, 1, 0.95 })
    );
end

function M.draw_text_outlined(draw_list, x, y, text, text_color, outline_color, thickness)
    outline_color = outline_color or { 0, 0, 0, 1 };
    thickness = thickness or 1;
    local outline_u32 = vec4_to_u32(outline_color);
    local text_u32 = vec4_to_u32(text_color);

    for _, off in ipairs(OUTLINE_OFFSETS) do
        draw_list:AddText(
            { x + off[1] * thickness, y + off[2] * thickness },
            outline_u32,
            text
        );
    end

    draw_list:AddText({ x, y }, text_u32, text);
end

function M.measure_text(text)
    local w, h = imgui.CalcTextSize(text);
    if type(w) == 'table' then
        local tw = w.x or w[1] or 0;
        local th = w.y or w[2] or imgui.GetTextLineHeight();
        return tw, th;
    end
    if type(w) ~= 'number' then
        return 0, imgui.GetTextLineHeight();
    end
    if type(h) ~= 'number' then
        h = imgui.GetTextLineHeight();
    end
    return w, h;
end

function M.text_outlined(text, color, outline_color)
    local draw_list = imgui.GetWindowDrawList();
    local x, y = imgui.GetCursorScreenPos();
    local width, height = M.measure_text(text);
    M.draw_text_outlined(draw_list, x, y, text, color, outline_color or { 0, 0, 0, 1 }, 1);
    imgui.Dummy({ width, height });
    return width;
end

function M.text_outlined_colored(text, color)
    local text_color = color or { 1, 1, 1, 1 };
    if M.is_transparent_theme(current_settings) then
        text_color = { 1, 1, 1, 1 };
    end

    -- Keep overlays readable regardless of config style state.
    M.text_outlined(text, text_color, { 0, 0, 0, 1 });
end

function M.text_outlined_same_line(text, color)
    imgui.SameLine();
    M.text_outlined_colored(text, color);
end

local function is_shift_held()
    local io = nil;
    if imgui.GetIO ~= nil then
        io = imgui.GetIO();
    end
    if io == nil then
        io = imgui.io;
    end
    return io ~= nil and io.KeyShift == true;
end

function M.draw_panel_drag(id, x_ref, y_ref, width, height, screen_x, screen_y)
    local editor_open = M.is_editor_open();
    local dragging_this = active_drag ~= nil and active_drag.id == id;

    -- Config open: free drag. Config closed: Shift+LMB to start; keep dragging until LMB up.
    if not editor_open and not is_shift_held() and not dragging_this then
        return;
    end

    local win_x, win_y;
    if screen_x ~= nil and screen_y ~= nil then
        win_x, win_y = screen_x, screen_y;
    else
        win_x, win_y = imgui.GetWindowPos();
        if type(win_x) == 'table' then
            win_y = win_x.y or win_x[2] or 0;
            win_x = win_x.x or win_x[1] or 0;
        end
    end

    local win_w, win_h = width, height;
    if win_w == nil or win_h == nil then
        win_w, win_h = imgui.GetWindowSize();
        if type(win_w) == 'table' then
            win_h = win_w.y or win_w[2] or 0;
            win_w = win_w.x or win_w[1] or 0;
        end
    end

    local mouse_x, mouse_y = imgui.GetMousePos();
    if type(mouse_x) == 'table' then
        mouse_y = mouse_x.y or mouse_x[2] or 0;
        mouse_x = mouse_x.x or mouse_x[1] or 0;
    end

    local hovering = mouse_x >= win_x and mouse_x <= (win_x + win_w)
        and mouse_y >= win_y and mouse_y <= (win_y + win_h);

    if hovering and imgui.IsMouseClicked(0) and (editor_open or is_shift_held()) then
        active_drag = {
            id = id,
            start_mouse_x = mouse_x,
            start_mouse_y = mouse_y,
            start_x = x_ref[1],
            start_y = y_ref[1],
        };
    end

    if active_drag and active_drag.id == id then
        if imgui.IsMouseDown(0) then
            x_ref[1] = active_drag.start_x + (mouse_x - active_drag.start_mouse_x);
            y_ref[1] = active_drag.start_y + (mouse_y - active_drag.start_mouse_y);
        else
            active_drag = nil;
        end
    end
end

function M.layout_notch_labels(notches, bar_x, width)
    local labels = T{};
    local min_gap = 20;

    for _, notch in ipairs(notches) do
        labels:append({
            hour = notch.hour,
            x = bar_x + (width * notch.progress),
            passed = notch.passed,
        });
    end

    table.sort(labels, function (a, b)
        return a.x < b.x;
    end);

    if #labels > 0 then
        labels[1].x = labels[1].x + 4;
    end

    for i = 2, #labels do
        local gap = labels[i].x - labels[i - 1].x;
        if gap < min_gap then
            local mid = (labels[i].x + labels[i - 1].x) / 2;
            labels[i - 1].x = mid - (min_gap / 2);
            labels[i].x = mid + (min_gap / 2);
        end
    end

    return labels;
end

function M.draw_notch_labels(draw_list, labels, y, settings, font_scale)
    font_scale = font_scale or 1.0;
    local transparent = M.is_transparent_theme(settings);

    for _, label in ipairs(labels) do
        local text = tostring(label.hour);
        local size = M.measure_text(text);
        local x = label.x - (size / 2);
        local color = colorLib.HexToImGui(M.get_notch_color(settings, label.passed));

        if transparent then
            M.draw_text_outlined(draw_list, x, y, text, { 1, 1, 1, 1 }, { 0, 0, 0, 1 }, 1);
        else
            draw_list:AddText({ x, y }, imgui.GetColorU32(color), text);
        end
    end
end

function M.get_notch_color(settings, passed)
    local ui = ui_settings(settings);
    if passed then
        return ui and ui.notch_passed_color[1] or '#738299';
    end
    return ui and ui.notch_color[1] or '#F2D159';
end

function M.render_about()
    imgui.Text('Fush');
    imgui.TextDisabled(string.format('Version %s', addon.version));
    imgui.TextDisabled('Created by Saraji');
    imgui.Separator();
    imgui.TextWrapped(attribution.DESCRIPTION);
    imgui.Spacing();
    imgui.TextWrapped(attribution.XIUI_NOTICE);
    imgui.Spacing();
    imgui.TextWrapped(attribution.get_short_credit());
end

function M.render_credit_footer()
    imgui.Separator();
    imgui.TextDisabled(attribution.get_short_credit());
end

function M.draw_gil_icon(draw_list, x, y, size)
    size = size or 12;
    local tex = TextureManager.getFileTexture('gil');
    local ptr = TextureManager.getTexturePtr(tex);
    if ptr ~= nil then
        draw_list:AddImage(ptr, { x, y }, { x + size, y + size }, { 0, 0 }, { 1, 1 }, IM_COL32_WHITE);
        return size + 4;
    end
    return 0;
end

return M;
