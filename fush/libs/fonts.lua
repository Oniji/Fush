--[[
* Fush - Overlay font helpers
*
* Loads bundled fonts from fush/assets/fonts/ via imgui.AddFontFromFileTTF
* (same approach as XIUI). Fonts are prewarmed on load — never added mid-frame.
]]--

require('common');
local imgui = require('imgui');

local M = {};

-- Friendly label -> filename under assets/fonts/
-- "Default (Agave)" keeps Ashita's current ImGui font (no PushFont).
M.OPTIONS = T{
    { label = 'Default (Agave)', file = nil },
    { label = 'Tahoma Bold',     file = 'tahomabd.ttf' },
    { label = 'Tahoma',          file = 'tahoma.ttf' },
    { label = 'Segoe UI',        file = 'segoeui.ttf' },
    { label = 'Consolas',        file = 'consola.ttf' },
    { label = 'Verdana',         file = 'verdana.ttf' },
};

local cache = T{}; -- label -> ImFont* or false
local pushed = false;
local warned = T{};
local prewarmed = false;

-- Pixel size passed to AddFontFromFileTTF (matches XIUI). Runtime Font Size
-- scales relative to this via SetWindowFontScale.
M.BASE_SIZE = 20;

local function fonts_dir()
    local base = (addon and addon.path) or '';
    base = base:gsub('[/\\]+$', '');
    return base .. '/assets/fonts/';
end

local function clamp_size(size)
    size = tonumber(size) or 13;
    if size < 6 then return 6; end
    if size > 30 then return 30; end
    return math.floor(size + 0.5);
end

function M.get_size(settings)
    if settings ~= nil and settings.font_size ~= nil then
        return clamp_size(settings.font_size[1]);
    end
    return 13;
end

-- Call after PushFont. Returns scale so on-screen glyphs match Font Size.
function M.get_scale(settings)
    local desired = M.get_size(settings);
    local base = imgui.GetFontSize();
    if base == nil or base <= 0 then
        base = M.BASE_SIZE;
    end
    return desired / base;
end

local function find_option(label)
    for _, opt in ipairs(M.OPTIONS) do
        if opt.label == label then
            return opt;
        end
    end
    return M.OPTIONS[1];
end

local function try_add_font(path)
    -- XIUI uses imgui.AddFontFromFileTTF directly (Ashita binding).
    local size = M.BASE_SIZE;
    local attempts = T{
        function()
            return imgui.AddFontFromFileTTF(path, size);
        end,
        function()
            return imgui.GetIO().Fonts:AddFontFromFileTTF(path, size);
        end,
        function()
            return imgui.io.Fonts:AddFontFromFileTTF(path, size);
        end,
    };

    for _, attempt in ipairs(attempts) do
        local ok, font = pcall(attempt);
        if ok and font ~= nil and font ~= false then
            return font;
        end
    end
    return nil;
end

function M.resolve_label(label)
    return find_option(label).label;
end

function M.get_font(label)
    label = M.resolve_label(label);
    local opt = find_option(label);

    if opt.file == nil then
        return nil;
    end

    if cache[label] ~= nil then
        return (cache[label] ~= false) and cache[label] or nil;
    end

    local path = fonts_dir() .. opt.file;
    local font = try_add_font(path);
    if font == nil then
        cache[label] = false;
        if not warned[label] then
            warned[label] = true;
            print(string.format(
                '[fush] Could not load font "%s" from %s. Using Default.',
                label,
                path
            ));
        end
        return nil;
    end

    cache[label] = font;
    return font;
end

-- Call from addon load (NOT from d3d_present). Mutating the ImGui font atlas
-- mid-frame can crash Ashita (see XIUI imtext.PrewarmFonts).
function M.prewarm()
    if prewarmed then
        return;
    end
    prewarmed = true;

    for _, opt in ipairs(M.OPTIONS) do
        if opt.file ~= nil then
            M.get_font(opt.label);
        end
    end
end

function M.push(settings)
    if pushed then
        return;
    end

    local label = 'Tahoma Bold';
    if settings ~= nil and settings.ui ~= nil and settings.ui.font_family ~= nil then
        label = settings.ui.font_family[1] or label;
    end
    label = M.resolve_label(label);

    local font = M.get_font(label);
    if font == nil then
        return;
    end

    local ok = pcall(function()
        imgui.PushFont(font);
    end);
    if ok then
        pushed = true;
    end
end

function M.pop()
    if not pushed then
        return;
    end
    pcall(function()
        imgui.PopFont();
    end);
    pushed = false;
end

function M.render_combo(settings_ref)
    local current = M.resolve_label(settings_ref[1]);
    if imgui.BeginCombo('Font', current) then
        for _, opt in ipairs(M.OPTIONS) do
            local selected = (opt.label == current);
            if imgui.Selectable(opt.label, selected) then
                settings_ref[1] = opt.label;
            end
            if selected then
                imgui.SetItemDefaultFocus();
            end
        end
        imgui.EndCombo();
    end
end

return M;
