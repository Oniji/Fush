--[[
* Fush - Fishing session tracker
]]--

require('common');
local settings = require('settings');
local constants = require('constants');
local format = require('libs.format');
local theme = require('libs.theme');
local ui = require('libs.ui');
local drawing = require('libs.drawing');
local imgui = require('imgui');

local M = {
    last_size = { w = 220, h = 200 },
    layout_w = 220,
};
local MIN_COLUMN_WIDTH = 48;
local STAT_COLUMN_PAD = 6;
local CATCH_COUNT_GAP = 8;
local CATCH_GIL_GAP = 12;
local MIN_NAME_COL = 90;
local RATE_UPDATE_MS = 30000;

M.session = {
    lines_cast = 0,
    bait_used = 0, -- incremented only when a bite occurs (fish/item/monster)
    hooks = 0, -- total bites (any hook type)
    small_fish_bites = 0,
    large_fish_bites = 0,
    item_bites = 0,
    monster_bites = 0,
    fish_caught = 0,
    items_caught = 0,
    monsters_caught = 0,
    lost = 0,
    broken = 0,
    first_cast_ms = 0,
    last_activity_ms = 0,
    -- Pause support: elapsed excludes time while paused (affects Rate/gph).
    paused = false,
    pause_started_ms = 0,
    pause_accumulated_ms = 0,
    current_hook = nil,
    rewards = T{},
    skill_start = nil,
    skill_gain = 0,
    fishing_frac = 0,
    last_skill_int = nil,
    -- True once a whole-level tick (or restored exact save) makes tenths trustworthy.
    skill_exact = false,
};

M.skillup_pkt_at = nil;
M.skill_settings = nil;
M.skill_dirty = false;
M.skill_last_save_ms = 0;
local SKILL_SAVE_DEBOUNCE_MS = 2000;

-- Session is only memory-resident until flushed. Autosave ~every 10s when dirty
-- so a hard crash loses at most ~one interval of activity.
M.session_dirty = false;
M.session_last_save_ms = 0;
local SESSION_AUTOSAVE_MS = 10000;

local function mark_session_dirty()
    -- Keep the bound character settings table current so Ashita's automatic
    -- per-character save on login/logout has an up-to-date snapshot.
    M.persist_session();
    M.session_dirty = true;
end

M.rate_cache = {
    gph = 0,
    net = nil,
    last_update_ms = 0,
};

M.player_name = '';

local function trim_line(s)
    if s == nil then
        return '';
    end
    s = s:gsub('\r', '');
    s = s:gsub('^%s+', '');
    s = s:gsub('%s+$', '');
    return s;
end

function M.refresh_player_name()
    local name = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0);
    if name ~= nil and name ~= '' then
        M.player_name = string.lower(trim_line(name));
    end
    return M.player_name;
end

local function sanitize_item_name(name)
    if name == nil then
        return nil;
    end

    name = trim_line(name);
    name = name:gsub('[!%.]+$', '');
    name = trim_line(name);
    if name == '' then
        return nil;
    end
    return name;
end

local function title_case(name)
    if name == nil or name == '' then
        return name;
    end
    return (tostring(name):lower():gsub("(%a)([%w']*)", function(first, rest)
        return first:upper() .. rest;
    end));
end

local function normalize_price_key(name)
    if name == nil then
        return nil;
    end
    return string.lower(trim_line(name));
end

local PREVIEW_SESSION = {
    lines_cast = 48,
    bait_used = 42,
    hooks = 42,
    small_fish_bites = 18,
    large_fish_bites = 16,
    item_bites = 5,
    monster_bites = 3,
    fish_caught = 35,
    items_caught = 4,
    monsters_caught = 1,
    lost = 5,
    broken = 2,
    first_cast_ms = ashita.time.clock()['ms'] - (45 * 60 * 1000),
    last_activity_ms = ashita.time.clock()['ms'],
    skill_start = 45.1,
    skill_gain = 0.1,
    skill_current = 45.2,
    rewards = T{
        ['Moat Carp'] = 12,
        ['Crayfish'] = 5,
        ['Gold Carp'] = 3,
    },
};

function M.reset_rate_cache()
    M.rate_cache.gph = 0;
    M.rate_cache.net = nil;
    M.rate_cache.last_update_ms = 0;
end

-- Wipe live session runtime state without writing settings.
-- Used when binding a different character's settings table.
-- preserve_skill: keep exact fishing skill (session clear); character binds
-- must leave this false so another character's skill cannot leak.
function M.clear_session_memory(preserve_skill)
    M.session.lines_cast = 0;
    M.session.bait_used = 0;
    M.session.hooks = 0;
    M.session.small_fish_bites = 0;
    M.session.large_fish_bites = 0;
    M.session.item_bites = 0;
    M.session.monster_bites = 0;
    M.session.fish_caught = 0;
    M.session.items_caught = 0;
    M.session.monsters_caught = 0;
    M.session.lost = 0;
    M.session.broken = 0;
    M.session.first_cast_ms = 0;
    M.session.last_activity_ms = 0;
    M.session.paused = false;
    M.session.pause_started_ms = 0;
    M.session.pause_accumulated_ms = 0;
    M.session.current_hook = nil;
    M.session.rewards = T{};
    M.session.skill_gain = 0;
    M.session.skill_start = nil;
    if not preserve_skill then
        M.session.fishing_frac = 0;
        M.session.last_skill_int = nil;
        M.session.skill_exact = false;
    end
    M.session_dirty = false;
    M.skill_dirty = false;
    M.reset_rate_cache();
end

-- Rebind to the active character settings (Ashita switches tables on login).
-- Always clears in-memory session first so another character's data cannot leak.
function M.bind_skill_settings(settings_ref)
    M.skill_settings = settings_ref;
    M.clear_session_memory(false);
    -- Restore session before skill: skill restore may flush settings to disk
    -- and must not overwrite this character's snapshot with an empty session.
    M.restore_session();
    M.restore_fishing_skill();
    M.refresh_player_name();
end

function M.get_fishing_skill_int()
    local ok, skill = pcall(function()
        local player = AshitaCore:GetMemoryManager():GetPlayer();
        if player == nil then
            return nil;
        end
        local craft = player:GetCraftSkill(constants.FISHING_CRAFT_SKILL_INDEX);
        if craft == nil then
            return nil;
        end
        return craft:GetSkill();
    end);

    if not ok or skill == nil then
        return nil;
    end
    return tonumber(skill);
end

-- During zone/load the craft API often reports 0. Treat that as unavailable
-- whenever we already know a non-zero skill (stored or last observed).
local function api_skill_usable(skill_int)
    if skill_int == nil then
        return false;
    end
    if skill_int > 0 then
        return true;
    end
    -- Genuine 0 is only trusted when we have no prior non-zero knowledge.
    local last = M.session.last_skill_int;
    if last ~= nil and last > 0 then
        return false;
    end
    if M.skill_settings ~= nil and M.skill_settings.fishing_skill ~= nil then
        local saved = tonumber(M.skill_settings.fishing_skill.level and M.skill_settings.fishing_skill.level[1]) or 0;
        if saved > 0 then
            return false;
        end
    end
    return true;
end

local function round_tenth(v)
    return math.floor(v * 10 + 0.5) / 10;
end

-- Exact skill (from a whole-rank tick) is source of truth. Only treat the craft
-- API as a hard contradiction when it disagrees by more than one whole level
-- (e.g. stored 89.3 vs API 91). Off-by-one is common around rank-up and must
-- not discard tenths; the whole-rank chat/packet is what advances the integer.
local function api_contradicts_exact(skill_int, base_int)
    if skill_int == nil or base_int == nil then
        return false;
    end
    return math.abs(skill_int - base_int) > 1;
end

local function apply_exact_skill(base_int, frac)
    M.session.skill_exact = true;
    M.session.last_skill_int = base_int;
    M.session.fishing_frac = math.min(0.9, math.max(0, round_tenth(frac or 0)));
end

local function clear_exact_skill(skill_int)
    M.session.skill_exact = false;
    M.session.fishing_frac = 0;
    if skill_int ~= nil then
        M.session.last_skill_int = skill_int;
    end
    if M.skill_settings ~= nil and M.skill_settings.fishing_skill ~= nil then
        M.skill_settings.fishing_skill.exact[1] = false;
        if skill_int ~= nil then
            M.skill_settings.fishing_skill.level[1] = skill_int;
        end
    end
end

function M.persist_fishing_skill(force)
    if M.skill_settings == nil or M.skill_settings.fishing_skill == nil then
        return;
    end

    local skill_int = M.get_fishing_skill_int();
    local api_ok = api_skill_usable(skill_int);
    local base = nil;
    if M.session.skill_exact then
        -- Never let a transient API whole-level overwrite the exact base.
        base = M.session.last_skill_int;
        if base == nil and api_ok then
            base = skill_int;
        end
    else
        if not api_ok then
            return;
        end
        base = skill_int;
    end
    if base == nil then
        return;
    end

    local frac = M.session.skill_exact and math.min(0.9, M.session.fishing_frac or 0) or 0;
    local level = base + frac;
    local store = M.skill_settings.fishing_skill;
    store.exact[1] = M.session.skill_exact == true;
    store.level[1] = round_tenth(level);
    if M.session.last_skill_int == nil then
        M.session.last_skill_int = base;
    end
    M.skill_dirty = true;

    local now = ashita.time.clock()['ms'];
    if force or (now - (M.skill_last_save_ms or 0)) >= SKILL_SAVE_DEBOUNCE_MS then
        M.skill_last_save_ms = now;
        M.skill_dirty = false;
        -- Piggy-back session snapshot onto this write when present.
        M.persist_session();
        M.session_dirty = false;
        M.session_last_save_ms = now;
        settings.save();
    end
end

function M.flush_fishing_skill()
    if M.skill_dirty then
        M.persist_fishing_skill(true);
    end
end

-- Call once per frame from d3d_present. Cheap no-op unless session is dirty
-- and SESSION_AUTOSAVE_MS has elapsed since the last disk write.
function M.tick_autosave()
    if not M.session_dirty then
        return;
    end

    local now = ashita.time.clock()['ms'];
    if (now - (M.session_last_save_ms or 0)) < SESSION_AUTOSAVE_MS then
        return;
    end

    M.persist_session();
    if M.skill_dirty then
        M.persist_fishing_skill(true);
    else
        settings.save();
        M.session_dirty = false;
        M.session_last_save_ms = now;
    end
end

local function ensure_session_snapshot()
    if M.skill_settings == nil then
        return nil;
    end
    if M.skill_settings.session_snapshot == nil then
        M.skill_settings.session_snapshot = T{
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
            paused = T{ false },
            skill_gain = T{ 0 },
            skill_start = T{ -1 },
            rewards = T{},
        };
    end
    local snap = M.skill_settings.session_snapshot;
    local defaults = {
        active = false,
        lines_cast = 0,
        bait_used = 0,
        hooks = 0,
        small_fish_bites = 0,
        large_fish_bites = 0,
        item_bites = 0,
        monster_bites = 0,
        fish_caught = 0,
        items_caught = 0,
        monsters_caught = 0,
        lost = 0,
        broken = 0,
        elapsed_ms = 0,
        activity_ago_ms = 0,
        paused = false,
        skill_gain = 0,
        skill_start = -1,
    };
    for key, value in pairs(defaults) do
        if snap[key] == nil then
            snap[key] = T{ value };
        end
    end
    if snap.rewards == nil then
        snap.rewards = T{};
    end
    return snap;
end

local function session_has_data()
    local s = M.session;
    if s.lines_cast > 0 or s.hooks > 0 or s.fish_caught > 0 or s.items_caught > 0
        or s.monsters_caught > 0 or s.lost > 0 or s.broken > 0 or (s.skill_gain or 0) > 0
        or (s.small_fish_bites or 0) > 0 or (s.large_fish_bites or 0) > 0
        or (s.item_bites or 0) > 0 or (s.monster_bites or 0) > 0 then
        return true;
    end
    if s.first_cast_ms ~= nil and s.first_cast_ms > 0 then
        return true;
    end
    for _, _ in pairs(s.rewards or {}) do
        return true;
    end
    return false;
end

function M.persist_session()
    local snap = ensure_session_snapshot();
    if snap == nil then
        return;
    end

    if not session_has_data() then
        snap.active[1] = false;
        snap.lines_cast[1] = 0;
        snap.bait_used[1] = 0;
        snap.hooks[1] = 0;
        snap.small_fish_bites[1] = 0;
        snap.large_fish_bites[1] = 0;
        snap.item_bites[1] = 0;
        snap.monster_bites[1] = 0;
        snap.fish_caught[1] = 0;
        snap.items_caught[1] = 0;
        snap.monsters_caught[1] = 0;
        snap.lost[1] = 0;
        snap.broken[1] = 0;
        snap.elapsed_ms[1] = 0;
        snap.activity_ago_ms[1] = 0;
        if snap.paused ~= nil then
            snap.paused[1] = false;
        end
        snap.skill_gain[1] = 0;
        snap.skill_start[1] = -1;
        snap.rewards = T{};
        return;
    end

    local s = M.session;
    local now = ashita.time.clock()['ms'];
    snap.active[1] = true;
    snap.lines_cast[1] = s.lines_cast or 0;
    snap.bait_used[1] = s.bait_used or 0;
    snap.hooks[1] = s.hooks or 0;
    snap.small_fish_bites[1] = s.small_fish_bites or 0;
    snap.large_fish_bites[1] = s.large_fish_bites or 0;
    snap.item_bites[1] = s.item_bites or 0;
    snap.monster_bites[1] = s.monster_bites or 0;
    snap.fish_caught[1] = s.fish_caught or 0;
    snap.items_caught[1] = s.items_caught or 0;
    snap.monsters_caught[1] = s.monsters_caught or 0;
    snap.lost[1] = s.lost or 0;
    snap.broken[1] = s.broken or 0;
    -- Persist active elapsed (pause time excluded) so restore keeps Rate correct.
    snap.elapsed_ms[1] = math.floor(M.get_elapsed_seconds(s) * 1000 + 0.5);
    snap.activity_ago_ms[1] = (s.last_activity_ms ~= nil and s.last_activity_ms > 0)
        and math.max(0, now - s.last_activity_ms) or 0;
    if snap.paused ~= nil then
        snap.paused[1] = s.paused == true;
    end
    snap.skill_gain[1] = s.skill_gain or 0;
    snap.skill_start[1] = (s.skill_start ~= nil) and s.skill_start or -1;

    local rewards = T{};
    for name, count in pairs(s.rewards or {}) do
        if name ~= nil and name ~= '' then
            rewards:append(string.format('%s:%d', tostring(name), tonumber(count) or 0));
        end
    end
    snap.rewards = rewards;
end

function M.restore_session()
    local snap = ensure_session_snapshot();
    if snap == nil or not snap.active[1] then
        return false;
    end

    local now = ashita.time.clock()['ms'];
    M.session.lines_cast = snap.lines_cast[1] or 0;
    -- Older snapshots lacked bait_used; approximate from total bites.
    if snap.bait_used ~= nil then
        M.session.bait_used = snap.bait_used[1] or 0;
    else
        M.session.bait_used = snap.hooks and snap.hooks[1] or 0;
    end
    M.session.hooks = snap.hooks[1] or 0;
    M.session.small_fish_bites = snap.small_fish_bites[1] or 0;
    M.session.large_fish_bites = snap.large_fish_bites[1] or 0;
    M.session.item_bites = snap.item_bites[1] or 0;
    M.session.monster_bites = snap.monster_bites[1] or 0;
    M.session.fish_caught = snap.fish_caught[1] or 0;
    M.session.items_caught = snap.items_caught[1] or 0;
    M.session.monsters_caught = snap.monsters_caught[1] or 0;
    M.session.lost = snap.lost[1] or 0;
    M.session.broken = snap.broken[1] or 0;
    M.session.skill_gain = snap.skill_gain[1] or 0;
    M.session.current_hook = nil;

    local skill_start = snap.skill_start[1];
    if skill_start ~= nil and skill_start >= 0 then
        M.session.skill_start = skill_start;
    else
        M.session.skill_start = nil;
    end

    local elapsed = snap.elapsed_ms[1] or 0;
    if elapsed > 0 then
        M.session.first_cast_ms = now - elapsed;
    else
        M.session.first_cast_ms = 0;
    end

    local ago = snap.activity_ago_ms[1] or 0;
    if M.session.first_cast_ms > 0 then
        M.session.last_activity_ms = now - ago;
    else
        M.session.last_activity_ms = 0;
    end

    M.session.pause_accumulated_ms = 0;
    M.session.pause_started_ms = 0;
    M.session.paused = snap.paused ~= nil and snap.paused[1] == true;
    if M.session.paused and M.session.first_cast_ms > 0 then
        -- Freeze the restored active elapsed until the player resumes.
        M.session.pause_started_ms = now;
    end

    M.session.rewards = T{};
    for _, entry in ipairs(snap.rewards or {}) do
        entry = trim_line(tostring(entry or ''));
        if entry ~= '' then
            local colon = entry:find(':');
            if colon ~= nil and colon > 1 then
                local name = trim_line(entry:sub(1, colon - 1));
                local count = tonumber(trim_line(entry:sub(colon + 1))) or 0;
                if name ~= '' and count > 0 then
                    M.session.rewards[name] = count;
                end
            end
        end
    end

    M.reset_rate_cache();
    return true;
end

function M.restore_fishing_skill()
    local skill_int = M.get_fishing_skill_int();
    local api_ok = api_skill_usable(skill_int);

    if M.skill_settings == nil or M.skill_settings.fishing_skill == nil then
        if api_ok then
            clear_exact_skill(skill_int);
        end
        return;
    end

    local store = M.skill_settings.fishing_skill;
    local exact = store.exact and store.exact[1];
    local saved = tonumber(store.level and store.level[1]) or 0;

    -- Stored exact skill is the source of truth until API/chat contradicts it.
    if exact and saved > 0 then
        local saved_int = math.floor(saved);
        local saved_frac = round_tenth(saved - saved_int);

        if not api_ok then
            -- Zone/load: keep decimals; ignore unavailable API (often 0).
            apply_exact_skill(saved_int, saved_frac);
            return;
        end

        if not api_contradicts_exact(skill_int, saved_int) then
            -- Same whole level, or off-by-one around rank-up: keep saved exact.
            apply_exact_skill(saved_int, saved_frac);
            return;
        end

        -- Hard contradiction (e.g. API 91 vs saved 89.3): trust API integer,
        -- hide tenths until the next whole-rank chat/packet.
        clear_exact_skill(skill_int);
        M.skill_dirty = true;
        M.persist_fishing_skill(true);
        return;
    end

    -- No exact store yet: only adopt a usable API integer.
    if api_ok then
        clear_exact_skill(skill_int);
    end
end

-- Memory only exposes whole levels; fractional tenths come from 0x029 / chat.
-- Whole-rank chat/packets are what make tenths "exact"; API alone never does.
function M.get_fishing_skill()
    local skill_int = M.get_fishing_skill_int();
    local api_ok = api_skill_usable(skill_int);

    -- Retry restore once settings say we have exact skill but runtime lost it
    -- (e.g. first frames after load before memory is ready).
    if not M.session.skill_exact
        and M.skill_settings
        and M.skill_settings.fishing_skill
        and M.skill_settings.fishing_skill.exact
        and M.skill_settings.fishing_skill.exact[1] then
        M.restore_fishing_skill();
    end

    if M.session.skill_exact then
        local base = M.session.last_skill_int;
        if api_ok and base ~= nil and api_contradicts_exact(skill_int, base) then
            -- API whole level contradicts stored exact skill by >1.
            clear_exact_skill(skill_int);
            M.persist_fishing_skill(true);
            return skill_int;
        end
        if base == nil then
            if api_ok then
                apply_exact_skill(skill_int, M.session.fishing_frac or 0);
                base = skill_int;
            else
                return nil;
            end
        end
        return base + math.min(0.9, M.session.fishing_frac or 0);
    end

    -- Not exact: show whole API integer when usable, else last known int.
    if api_ok then
        M.session.last_skill_int = skill_int;
        return skill_int;
    end
    if M.session.last_skill_int ~= nil then
        return M.session.last_skill_int;
    end
    return nil;
end

function M.add_fishing_frac(delta)
    if delta == nil or delta <= 0 then
        return;
    end

    local nv = (M.session.fishing_frac or 0) + delta;
    nv = round_tenth(nv);
    if nv >= 1.0 then
        -- Integer tick packet usually follows; keep frac at 0 until confirmed.
        nv = 0;
    end
    M.session.fishing_frac = nv;
    M.session.skill_gain = round_tenth((M.session.skill_gain or 0) + delta);
    M.touch_activity();
    mark_session_dirty();
    if M.session.skill_exact then
        M.persist_fishing_skill(false);
    end
end

function M.on_fishing_skill_tick(new_int)
    -- Whole-level tick from chat/packet is always the new source of truth.
    local tick_int = tonumber(new_int);
    if tick_int == nil then
        tick_int = M.get_fishing_skill_int();
    end
    if tick_int == nil or tick_int <= 0 then
        return;
    end

    apply_exact_skill(tick_int, 0);
    mark_session_dirty();
    M.persist_fishing_skill(true);
end

function M.ensure_skill_start()
    if M.session.skill_start ~= nil then
        return;
    end

    local current = M.get_fishing_skill();
    if current == nil then
        return;
    end

    -- Baseline for internal reference only; session gain uses skill_gain accumulator.
    M.session.skill_start = current;
    mark_session_dirty();
end

function M.get_skill_display(session, preview)
    if preview then
        return session.skill_current or 45.2, session.skill_gain or 0.1, true;
    end

    local current = M.get_fishing_skill();
    if current == nil then
        return nil, nil, false;
    end

    M.ensure_skill_start();
    return current, M.session.skill_gain or 0, M.session.skill_exact == true;
end

function M.format_skill_line(current, gain, exact)
    local value = M.format_skill_value(current, gain, exact);
    if value == nil then
        return nil;
    end
    return 'Skill: ' .. value;
end

function M.format_skill_value(current, gain, exact)
    if current == nil then
        return nil;
    end

    -- Hide once fishing skill hits 100.
    if current >= 100 then
        return nil;
    end

    local value;
    if exact then
        value = string.format('%.1f', current);
    else
        -- Tenths not yet proven; show whole level only.
        value = string.format('%d', math.floor(current));
    end

    if gain ~= nil and gain > 0.0001 then
        value = value .. string.format(' (+%.1f)', gain);
    end
    return value;
end

function M.reset_session()
    -- Only clears/saves the currently bound character's settings.
    -- Preserve exact fishing skill across session clears.
    M.clear_session_memory(true);
    if not M.session.skill_exact then
        M.restore_fishing_skill();
    else
        M.persist_fishing_skill(true);
    end
    M.session.skill_start = nil;
    M.persist_session();
    M.session_dirty = false;
    M.session_last_save_ms = ashita.time.clock()['ms'];
    settings.save();
end

function M.get_cached_gph(session, settings, pricing)
    local net = M.get_net_gil(session, settings, pricing);
    local now = ashita.time.clock()['ms'];
    local needs_update = M.rate_cache.net == nil
        or M.rate_cache.net ~= net
        or (now - M.rate_cache.last_update_ms) >= RATE_UPDATE_MS;

    if needs_update then
        M.rate_cache.gph = format.format_gph(net, M.get_elapsed_seconds(session));
        M.rate_cache.net = net;
        M.rate_cache.last_update_ms = now;
    end

    return net, M.rate_cache.gph;
end

function M.touch_activity()
    M.session.last_activity_ms = ashita.time.clock()['ms'];
end

function M.record_cast()
    M.touch_activity();
    M.ensure_skill_start();
    M.session.lines_cast = M.session.lines_cast + 1;
    if M.session.first_cast_ms == 0 then
        M.session.first_cast_ms = M.session.last_activity_ms;
        -- If the timer was paused before the first cast, anchor pause here so
        -- elapsed stays 0 until resume.
        if M.session.paused then
            M.session.pause_started_ms = M.session.last_activity_ms;
            M.session.pause_accumulated_ms = 0;
        end
    end
    mark_session_dirty();
end

function M.record_hook(hook_type)
    M.touch_activity();
    M.session.hooks = M.session.hooks + 1;
    M.session.bait_used = (M.session.bait_used or 0) + 1;
    M.session.current_hook = hook_type;

    if hook_type == 'Small Fish' then
        M.session.small_fish_bites = (M.session.small_fish_bites or 0) + 1;
    elseif hook_type == 'Large Fish' then
        M.session.large_fish_bites = (M.session.large_fish_bites or 0) + 1;
    elseif hook_type == constants.ITEM_HOOK_TYPE then
        M.session.item_bites = (M.session.item_bites or 0) + 1;
    elseif hook_type == constants.MONSTER_HOOK_TYPE then
        M.session.monster_bites = (M.session.monster_bites or 0) + 1;
    end
    mark_session_dirty();
end

local function add_reward(name)
    if M.session.rewards[name] == nil then
        M.session.rewards[name] = 1;
    else
        M.session.rewards[name] = M.session.rewards[name] + 1;
    end
end

function M.is_priced_item(item_name, pricing)
    if item_name == nil or item_name == '' or pricing == nil then
        return false;
    end
    return pricing[normalize_price_key(item_name)] ~= nil;
end

function M.record_catch(item_name, hook_type, pricing)
    M.touch_activity();
    hook_type = hook_type or M.session.current_hook;

    -- Only track catches that exist in the Tracker item/price list.
    if not M.is_priced_item(item_name, pricing) then
        M.session.current_hook = nil;
        return;
    end

    if hook_type == constants.ITEM_HOOK_TYPE then
        M.session.items_caught = M.session.items_caught + 1;
    elseif hook_type == constants.MONSTER_HOOK_TYPE then
        M.session.monsters_caught = M.session.monsters_caught + 1;
    else
        M.session.fish_caught = M.session.fish_caught + 1;
    end

    add_reward(item_name);
    M.session.current_hook = nil;
    mark_session_dirty();
end

function M.record_lost()
    M.touch_activity();
    M.session.lost = M.session.lost + 1;
    M.session.current_hook = nil;
    mark_session_dirty();
end

function M.record_broken()
    M.touch_activity();
    M.session.broken = M.session.broken + 1;
    M.session.current_hook = nil;
    mark_session_dirty();
end

local function get_session(preview)
    if preview then
        return PREVIEW_SESSION;
    end
    return M.session;
end

function M.get_accuracy(session)
    if session.lines_cast == 0 then
        return 0;
    end
    -- Bite rate: bites / casts.
    return ((session.hooks or 0) / session.lines_cast) * 100;
end

function M.get_total_worth(session, pricing)
    local total = 0;
    for name, count in pairs(session.rewards) do
        local key = normalize_price_key(name);
        if pricing[key] ~= nil then
            total = total + (tonumber(pricing[key]) or 0) * count;
        end
    end
    return total;
end

function M.get_net_gil(session, settings, pricing)
    local total = M.get_total_worth(session, pricing);
    if settings.tracker.subtract_bait[1] and not settings.tracker.use_lure[1] then
        total = total - ((session.bait_used or 0) * settings.tracker.bait_cost[1]);
    end
    return total;
end

function M.get_elapsed_seconds(session)
    session = session or M.session;
    if session.first_cast_ms == nil or session.first_cast_ms == 0 then
        return 0;
    end

    local end_ms;
    if session.paused and session.pause_started_ms ~= nil and session.pause_started_ms > 0 then
        end_ms = session.pause_started_ms;
    else
        end_ms = ashita.time.clock()['ms'];
    end

    local paused_ms = session.pause_accumulated_ms or 0;
    return math.max(0, (end_ms - session.first_cast_ms - paused_ms) / 1000);
end

function M.is_paused(session)
    session = session or M.session;
    return session.paused == true;
end

function M.pause_session()
    if M.session.paused then
        return;
    end
    -- No timer yet — nothing to pause, but still mark paused so Rate stays at 0.
    M.session.paused = true;
    M.session.pause_started_ms = ashita.time.clock()['ms'];
    M.touch_activity();
    M.reset_rate_cache();
    mark_session_dirty();
end

function M.resume_session()
    if not M.session.paused then
        return;
    end
    local now = ashita.time.clock()['ms'];
    if M.session.pause_started_ms ~= nil and M.session.pause_started_ms > 0 then
        M.session.pause_accumulated_ms = (M.session.pause_accumulated_ms or 0)
            + math.max(0, now - M.session.pause_started_ms);
    end
    M.session.pause_started_ms = 0;
    M.session.paused = false;
    M.touch_activity();
    M.reset_rate_cache();
    mark_session_dirty();
end

function M.clear_session()
    M.reset_session();
    M.touch_activity();
end

function M.handle_packet_in(e)
    if e.id ~= constants.PACKET_MESSAGE then
        return;
    end

    local ok, raw_msgnum = pcall(struct.unpack, 'H', e.data, 0x18 + 0x01);
    if not ok or raw_msgnum == nil then
        return;
    end

    -- Bit 15 may be set; MessageNum is the lower 15 bits.
    local msgnum = raw_msgnum % 32768;
    if msgnum == constants.MSG_SKILL_FRAC then
        local sid = struct.unpack('L', e.data, 0x0C + 0x01);
        local tenths = struct.unpack('L', e.data, 0x10 + 0x01);
        if sid == constants.FISHING_SKILL_ID and tenths ~= nil and tenths > 0 then
            M.ensure_skill_start();
            M.add_fishing_frac(tenths / 10.0);
            M.skillup_pkt_at = os.clock();
        end
    elseif msgnum == constants.MSG_SKILL_TICK then
        local sid = struct.unpack('L', e.data, 0x0C + 0x01);
        local new_int = struct.unpack('L', e.data, 0x10 + 0x01);
        if sid == constants.FISHING_SKILL_ID then
            M.ensure_skill_start();
            M.on_fishing_skill_tick(tonumber(new_int));
            M.skillup_pkt_at = os.clock();
            M.touch_activity();
        end
    end
end

function M.handle_text(e, bite, pricing)
    if e.injected then
        return;
    end

    -- Fallback fishing skill fraction capture (chat), if packet_in missed it.
    local plain = string.strip_colors(e.message or '');
    local skill_name, frac_digit = plain:match('([%a%-]+[%a%- ]*)%s*[Ss]kill rises[%s%a]*0%.(%d)');
    if skill_name ~= nil and frac_digit ~= nil then
        local name = skill_name:lower():gsub('^your%s+', ''):gsub('%s+$', '');
        if name == 'fishing' then
            local fresh_pkt = M.skillup_pkt_at ~= nil and (os.clock() - M.skillup_pkt_at) < 1.5;
            if not fresh_pkt then
                M.ensure_skill_start();
                M.add_fishing_frac(tonumber('0.' .. frac_digit) or 0);
            end
        end
    end

    -- Fallback whole-rank tick from chat (e.g. "Fishing skill rises to 90.").
    -- Always treated as the new source of truth for exact skill.
    local tick_name, tick_level = plain:match('([%a%-]+[%a%- ]*)%s*[Ss]kill rises to (%d+)');
    if tick_name ~= nil and tick_level ~= nil then
        local name = tick_name:lower():gsub('^your%s+', ''):gsub('%s+$', '');
        if name == 'fishing' then
            local fresh_pkt = M.skillup_pkt_at ~= nil and (os.clock() - M.skillup_pkt_at) < 1.5;
            if not fresh_pkt then
                M.ensure_skill_start();
                M.on_fishing_skill_tick(tonumber(tick_level));
                M.touch_activity();
            end
        end
    end

    local message = string.lower(string.strip_colors(e.message));
    M.refresh_player_name();
    local player = M.player_name;

    -- HorizonXI / HGather style: "Playername caught a Tavnazian goby!"
    -- Parse catcher from the line so a stale cached name after char swap cannot block catches.
    local catcher, catch_item = message:match('^([%a]+) caught an? ([^!]+)!$');
    if catcher ~= nil and catch_item ~= nil then
        if player == nil or player == '' then
            M.player_name = catcher;
            player = catcher;
        end
        if catcher == player then
            M.record_catch(sanitize_item_name(catch_item), bite.get_hook_type(), pricing);
            return;
        end
    end

    if player ~= nil and player ~= '' then
        local monster = string.match(message, '^' .. player .. ' caught a monster!$');
        if monster ~= nil then
            M.record_catch('monster', constants.MONSTER_HOOK_TYPE, pricing);
            return;
        end

        local count, multi_catch = string.match(message, '^' .. player .. ' caught ([0-9]+) ([^!]+)!$');
        if count ~= nil and multi_catch ~= nil then
            local item = sanitize_item_name(multi_catch);
            local hook_type = bite.get_hook_type();
            for _ = 1, tonumber(count) or 1 do
                M.record_catch(item, hook_type, pricing);
            end
            return;
        end

        local catch = string.match(message, '^' .. player .. ' caught an? ([^!]+)!$');
        if catch ~= nil then
            M.record_catch(sanitize_item_name(catch), bite.get_hook_type(), pricing);
            return;
        end
    end

    -- Fallback patterns (older / alternate clients)
    local fallback = string.match(message, 'obtained: (.*).')
        or string.match(message, 'you catch an? ([^!.]+)')
        or string.match(message, 'you caught an? ([^!]+)!?');

    if fallback ~= nil then
        M.record_catch(sanitize_item_name(fallback), bite.get_hook_type(), pricing);
        return;
    end

    if string.contains(message, 'you didn\'t catch anything') then
        M.touch_activity();
        M.session.current_hook = nil;
        return;
    end

    if string.contains(message, 'you lost your catch')
        or string.contains(message, 'the fish got away')
        or string.contains(message, 'lack of skill')
        or string.contains(message, 'weren\'t able to catch anything')
        or string.contains(message, 'you give up') then
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
    return M.build_report_for(M.session, settings, pricing);
end

function M.build_report_for(session, settings, pricing)
    local elapsed = M.get_elapsed_seconds(session);
    local accuracy = M.get_accuracy(session);
    local net = M.get_net_gil(session, settings, pricing);
    local gph = format.format_gph(net, elapsed);

    local lines = T{};
    lines:append('~~~~~~ Fush Session ~~~~~~');
    lines:append('Casts: ' .. format.format_int(session.lines_cast));
    lines:append('Bites: ' .. format.format_int(session.hooks));
    lines:append('Bite Rate: ' .. format.format_percent(accuracy));
    lines:append('Monsters: ' .. format.format_int(session.monster_bites or 0));
    lines:append('Items: ' .. format.format_int(session.item_bites or 0));
    lines:append('Fish: ' .. format.format_int((session.small_fish_bites or 0) + (session.large_fish_bites or 0)));
    lines:append('Lost / Broken: ' .. (session.lost or 0) .. ' / ' .. (session.broken or 0));
    lines:append('~~~~~~~~~~~~~~~~~~~~~~~~~~~~');

    for name, count in pairs(session.rewards) do
        local key = string.lower(name);
        local price = tonumber(pricing[key]) or 0;
        lines:append(title_case(name) .. ': x' .. format.format_int(count) .. ' (' .. format.format_int(price * count) .. 'g)');
    end

    if settings.tracker.subtract_bait[1] and not settings.tracker.use_lure[1] then
        local bait_qty = session.bait_used or 0;
        local bait_spent = bait_qty * settings.tracker.bait_cost[1];
        lines:append('Bait: x' .. format.format_int(bait_qty) .. ' (-' .. format.format_int(bait_spent) .. 'g)');
    end

    lines:append('~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
    lines:append('Net Gil: ' .. format.format_int(net) .. 'g (' .. format.format_int(gph) .. ' gph)');
    return table.concat(lines, '\n');
end

local function stat_cell(label, value, value_color)
    ui.text_outlined_colored(label, theme.colors.text_light);
    ui.text_outlined_colored(value, value_color or theme.colors.text_gold);
end

local function text_w(s)
    local w = ui.measure_text(tostring(s or ''));
    if type(w) ~= 'number' then
        return 0;
    end
    return w;
end

local function measure_stat_column_width(label, value)
    return math.max(MIN_COLUMN_WIDTH, math.max(text_w(label), text_w(value)) + STAT_COLUMN_PAD);
end

-- Shared widths so Casts/Monsters, Bites/Items, Bite Rate/Fish line up.
local function measure_shared_stat_widths(row1, row2)
    local count = math.max(#row1.labels, #row2.labels);
    local widths = {};
    local total = 0;
    for i = 1, count do
        local w = 0;
        if row1.labels[i] ~= nil then
            w = math.max(w, measure_stat_column_width(row1.labels[i], row1.values[i]));
        end
        if row2.labels[i] ~= nil then
            w = math.max(w, measure_stat_column_width(row2.labels[i], row2.values[i]));
        end
        widths[i] = w;
        total = total + w;
    end
    return widths, total;
end

local function draw_stat_row(row_id, labels, values, column_widths, colors)
    local count = #labels;
    imgui.Columns(count, '##fush_stats_' .. row_id, false);
    for i = 0, count - 1 do
        imgui.SetColumnWidth(i, column_widths[i + 1]);
    end

    for i = 1, count do
        stat_cell(labels[i], values[i], colors and colors[i] or nil);
        imgui.NextColumn();
    end

    imgui.Columns(1);
end

-- Reserve space for the longest unit ("gph") so ones-digits share one column
-- across catch totals, Net Gil (…g), and Rate (…gph).
local GIL_UNIT_RESERVE = 'gph';
local GIL_UNIT_GAP = 3;

local function should_show_bait(settings, session)
    return settings.tracker.subtract_bait[1]
        and not settings.tracker.use_lure[1]
        and (session.bait_used or 0) > 0;
end

local function get_bait_qty(session)
    return session.bait_used or 0;
end

local function get_bait_spent(settings, session)
    return get_bait_qty(session) * settings.tracker.bait_cost[1];
end

local function control_cluster_metrics(scale)
    local btn_s = math.max(16, math.floor(18 * (scale or 1) + 0.5));
    local gap = math.max(3, math.floor(4 * (scale or 1) + 0.5));
    return btn_s, gap, (btn_s * 3) + (gap * 2);
end

-- Content-measured width only — never GetWindowWidth(), or AlwaysAutoResize
-- feedback will stretch the panel forever as right-aligned gil runs away.
local function compute_tracker_layout(session, pricing, settings, pad, net, gph, skill_value, row1, row2, duration_line, show_controls, scale)
    local max_num_w = math.max(text_w(format.format_int(net)), text_w(format.format_int(gph)));
    local max_name_w = math.max(text_w('Net Gil'), text_w('Rate'), text_w('Bait'));
    local max_count_w = text_w('0');

    for name, count in pairs(session.rewards or {}) do
        local unit_price = tonumber(pricing[normalize_price_key(name)]) or 0;
        local total_gil = unit_price * count;
        max_num_w = math.max(max_num_w, text_w(format.format_int(total_gil)));
        max_name_w = math.max(max_name_w, text_w(title_case(name)));
        max_count_w = math.max(max_count_w, text_w(tostring(count)));
    end

    if should_show_bait(settings, session) then
        local spent = get_bait_spent(settings, session);
        max_num_w = math.max(max_num_w, text_w(format.format_int(-spent)));
        max_count_w = math.max(max_count_w, text_w(tostring(get_bait_qty(session))));
    end

    local gil_col = max_num_w + GIL_UNIT_GAP + text_w(GIL_UNIT_RESERVE);
    local name_col = math.max(MIN_NAME_COL, max_name_w);
    local count_col = math.max(24, max_count_w);
    local list_w = name_col + CATCH_COUNT_GAP + count_col + CATCH_GIL_GAP + gil_col;

    local inner = list_w;
    local header_w = 0;
    if skill_value ~= nil then
        header_w = header_w + math.max(text_w('Skill'), text_w(skill_value));
    end
    if duration_line ~= nil then
        header_w = header_w + 12 + math.max(text_w('Duration'), text_w(duration_line));
    end
    if show_controls then
        local _, _, controls_w = control_cluster_metrics(scale);
        header_w = header_w + 8 + controls_w;
    end
    if header_w > 0 then
        inner = math.max(inner, header_w);
    end
    local stat_widths, stats_w = measure_shared_stat_widths(row1, row2);
    inner = math.max(inner, stats_w);

    return {
        width = inner + (pad * 2),
        name_col = name_col,
        count_x = pad + name_col + CATCH_COUNT_GAP,
        stat_widths = stat_widths,
    };
end

local function show_tracker_duration(settings)
    local ui_cfg = settings and settings.ui and settings.ui.tracker;
    return ui_cfg ~= nil and ui_cfg.show_duration ~= nil and ui_cfg.show_duration[1] == true;
end

local function show_tracker_controls(settings)
    local ui_cfg = settings and settings.ui and settings.ui.tracker;
    return ui_cfg ~= nil and ui_cfg.show_controls ~= nil and ui_cfg.show_controls[1] == true;
end

local function push_control_button_colors(active)
    local bg = active and (theme.colors.accent or theme.colors.text_gold) or (theme.colors.bg_mid or theme.bg_medium);
    local hovered = theme.colors.bg_light or theme.bg_light;
    local pressed = theme.colors.bg_light or theme.bg_lighter;
    if active then
        hovered = theme.colors.text_gold or theme.gold;
        pressed = theme.colors.accent or theme.gold_dark;
    end
    imgui.PushStyleColor(ImGuiCol_Button, bg);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, hovered);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, pressed);
    imgui.PushStyleColor(ImGuiCol_Border, theme.colors.border_gold or theme.colors.border or theme.border_gold);
    return 4;
end

local function icon_tint_for_button(active)
    if active then
        return theme.colors.bg_dark or theme.bg_dark or { 0.05, 0.05, 0.08, 1.0 };
    end
    return theme.colors.text_light or theme.text_light or { 1, 1, 1, 1 };
end

local function read_vec2(a, b)
    if type(a) == 'table' then
        return a[1] or a.x or 0, a[2] or a.y or 0;
    end
    return a or 0, b or 0;
end

local function draw_icon_control_button(id, icon_name, size, active, preview, on_click)
    local count = push_control_button_colors(active);
    local clicked = imgui.Button('##' .. id, { size, size });
    local a, b = imgui.GetItemRectMin();
    local min_x, min_y = read_vec2(a, b);
    a, b = imgui.GetItemRectMax();
    local max_x, max_y = read_vec2(a, b);
    local icon_pad = math.max(2, math.floor(size * 0.20 + 0.5));
    local icon_size = math.max(8, (max_x - min_x) - (icon_pad * 2));
    local draw_list = imgui.GetWindowDrawList();
    if draw_list ~= nil then
        ui.draw_asset_icon(
            draw_list,
            icon_name,
            min_x + icon_pad,
            min_y + icon_pad,
            icon_size,
            icon_tint_for_button(active)
        );
    end
    imgui.PopStyleColor(count);
    if clicked and not preview and on_click ~= nil then
        on_click();
    end
end

local function draw_control_cluster_at(x, y, btn_s, gap, preview)
    local paused = M.is_paused();
    imgui.SetCursorPos({ x, y });
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, 3.0);
    imgui.PushStyleVar(ImGuiStyleVar_FrameBorderSize, 1.0);
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { gap, 0 });
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 0, 0 });

    draw_icon_control_button('fush_sess_play', 'session_play', btn_s, not paused, preview, M.resume_session);
    imgui.SameLine();
    draw_icon_control_button('fush_sess_pause', 'session_pause', btn_s, paused, preview, M.pause_session);
    imgui.SameLine();
    draw_icon_control_button('fush_sess_clear', 'session_clear', btn_s, false, preview, M.clear_session);

    imgui.PopStyleVar(4);
end

-- Top info strip: Skill (left), Duration (right), compact controls beside duration.
local function draw_info_header(skill_value, duration_text, show_controls, pad, layout_w, scale, preview)
    if skill_value == nil and duration_text == nil and not show_controls then
        return;
    end

    local line_h = imgui.GetTextLineHeight();
    local row_gap = 1;
    local label_y = imgui.GetCursorPosY();
    local right_edge = layout_w - pad;
    local btn_s, btn_gap, controls_w = control_cluster_metrics(scale);
    local controls_x = show_controls and (right_edge - controls_w) or right_edge;

    -- Controls alone: keep a single compact row.
    if skill_value == nil and duration_text == nil then
        draw_control_cluster_at(controls_x, label_y, btn_s, btn_gap, preview);
        imgui.SetCursorPosY(label_y + btn_s + 6);
        return;
    end

    local value_y = label_y + line_h + row_gap;
    local block_h = (line_h * 2) + row_gap;
    local meta_right = show_controls and (controls_x - 8) or right_edge;

    if skill_value ~= nil then
        imgui.SetCursorPos({ pad, label_y });
        ui.text_outlined_colored('Skill', theme.colors.text_light);
        imgui.SetCursorPos({ pad, value_y });
        ui.text_outlined_colored(skill_value, theme.colors.text_gold);
    end

    if duration_text ~= nil then
        local label_w = text_w('Duration');
        local value_w = text_w(duration_text);
        imgui.SetCursorPos({ meta_right - label_w, label_y });
        ui.text_outlined_colored('Duration', theme.colors.text_light);
        imgui.SetCursorPos({ meta_right - value_w, value_y });
        ui.text_outlined_colored(duration_text, theme.colors.text_gold);
    end

    if show_controls then
        local btn_y = label_y + math.max(0, (block_h - btn_s) * 0.5);
        draw_control_cluster_at(controls_x, btn_y, btn_s, btn_gap, preview);
    end

    imgui.SetCursorPosY(value_y + line_h + 6);
end

-- Two related stat groups with shared column alignment and even vertical rhythm.
local function draw_info_stat_groups(row1, row2, column_widths)
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 4, 1 });
    draw_stat_row('casts', row1.labels, row1.values, column_widths);
    imgui.Dummy({ 0, 4 });
    draw_stat_row('bites', row2.labels, row2.values, column_widths);
    imgui.PopStyleVar(1);
end

local function gil_digit_right_x(pad, layout_w)
    return layout_w - pad - text_w(GIL_UNIT_RESERVE) - GIL_UNIT_GAP;
end

local function draw_aligned_gil(amount, unit, color, pad, layout_w, same_line)
    local num = format.format_int(amount);
    local num_w = text_w(num);
    local right = gil_digit_right_x(pad, layout_w);
    if same_line then
        imgui.SameLine(right - num_w);
    else
        local y = imgui.GetCursorPosY();
        imgui.SetCursorPosX(right - num_w);
        imgui.SetCursorPosY(y);
    end
    ui.text_outlined_colored(num, color);
    imgui.SameLine(0, GIL_UNIT_GAP);
    ui.text_outlined_colored(unit, color);
end

local function draw_catch_row(name, count, total_gil, color, pad, layout)
    ui.text_outlined_colored(title_case(name), color);
    imgui.SameLine(layout.count_x);
    ui.text_outlined_colored(tostring(count), color);
    draw_aligned_gil(total_gil, 'g', color, pad, layout.width, true);
end

local function draw_money_row(label, amount, unit, draw_list, pad, settings, layout)
    local transparent = ui.is_transparent_theme(settings);

    if label == 'Net Gil' and not transparent then
        local gil_x, gil_y = imgui.GetCursorScreenPos();
        local offset = ui.draw_gil_icon(draw_list, gil_x, gil_y + 1, 13);
        if offset > 0 then
            imgui.SetCursorPosX(pad + offset);
        end
    end

    ui.text_outlined_colored(label, theme.colors.text_light);
    draw_aligned_gil(amount, unit, theme.colors.text_gold, pad, layout.width, true);
end

local function draw_section_separator(transparent)
    local gap = math.max(1, math.floor(imgui.GetTextLineHeight() * 0.25 + 0.5));
    imgui.Dummy({ 0, gap });
    if not transparent then
        imgui.PushStyleColor(ImGuiCol_Separator, theme.colors.border_gold or theme.colors.border);
        imgui.Separator();
        imgui.PopStyleColor(1);
    end
    imgui.Dummy({ 0, gap });
end

function M.render(settings, pricing, preview)

    if not settings.tracker.visible[1] and not preview then
        return;
    end

    if not preview then
        local never_hide = settings.tracker.never_hide ~= nil and settings.tracker.never_hide[1] == true;
        if not never_hide then
            local idle_secs = (ashita.time.clock()['ms'] - M.session.last_activity_ms) / 1000;
            if M.session.last_activity_ms > 0 and idle_secs > settings.tracker.display_timeout[1] then
                return;
            end
        end
    end

    local session = get_session(preview);
    local x = settings.tracker.x[1];
    local y = settings.tracker.y[1];
    local pad = ui.get_padding(settings, 'tracker');
    local draw_list = drawing.GetUIDrawList();
    local scale = ui.get_module_scale(settings, 'tracker');
    local transparent = ui.is_transparent_theme(settings);

    local layout_w = M.layout_w or 220;
    ui.draw_panel_background(draw_list, x, y, layout_w, M.last_size.h, settings, 'tracker');

    imgui.SetNextWindowBgAlpha(0);
    imgui.SetNextWindowPos({ x, y }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ layout_w, 0 }, ImGuiCond_Always);

    if imgui.Begin('FushTracker##Display', ui.get_panel_open('tracker'), ui.get_panel_flags()) then
        imgui.SetWindowFontScale(scale);
        imgui.SetCursorPos({ pad, pad });

        local accuracy = M.get_accuracy(session);
        local net, gph = M.get_cached_gph(session, settings, pricing);
        local skill_current, skill_gain, skill_exact = M.get_skill_display(session, preview);
        local skill_value = M.format_skill_value(skill_current, skill_gain, skill_exact);
        local fish_bites = (session.small_fish_bites or 0) + (session.large_fish_bites or 0);
        local want_duration = show_tracker_duration(settings);
        local want_controls = show_tracker_controls(settings);
        local duration_text = want_duration
            and format.format_duration(M.get_elapsed_seconds(session))
            or nil;

        local row1 = {
            labels = { 'Casts', 'Bites', 'Bite Rate' },
            values = {
                format.format_int(session.lines_cast),
                format.format_int(session.hooks),
                format.format_percent(accuracy),
            },
        };
        local row2 = {
            labels = { 'Monsters', 'Items', 'Fish' },
            values = {
                format.format_int(session.monster_bites or 0),
                format.format_int(session.item_bites or 0),
                format.format_int(fish_bites),
            },
        };

        local layout = compute_tracker_layout(
            session, pricing, settings, pad, net, gph, skill_value, row1, row2, duration_text, want_controls, scale
        );
        M.layout_w = layout.width;
        M.last_size.w = layout.width;

        draw_info_header(skill_value, duration_text, want_controls, pad, layout.width, scale, preview);
        draw_info_stat_groups(row1, row2, layout.stat_widths);

        local reward_names = T{};
        for name, _ in pairs(session.rewards) do
            reward_names:append(name);
        end
        table.sort(reward_names);

        local show_bait = should_show_bait(settings, session);
        local has_list = #reward_names > 0 or show_bait;

        draw_section_separator(transparent);

        if has_list then
            for _, name in ipairs(reward_names) do
                local count = session.rewards[name];
                local unit_price = tonumber(pricing[normalize_price_key(name)]) or 0;
                local total_gil = unit_price * count;
                draw_catch_row(name, count, total_gil, theme.colors.text_light, pad, layout);
            end

            if show_bait then
                local bait_qty = get_bait_qty(session);
                local bait_spent = get_bait_spent(settings, session);
                draw_catch_row('bait', bait_qty, -bait_spent, theme.colors.text_light, pad, layout);
            end

            draw_section_separator(transparent);
        end

        draw_money_row('Net Gil', net, 'g', draw_list, pad, settings, layout);
        draw_money_row('Rate', gph, 'gph', draw_list, pad, settings, layout);

        imgui.SetWindowFontScale(1.0);

        local size = { imgui.GetWindowSize() };
        M.last_size.h = size[2];
        M.last_size.w = layout.width;

        ui.draw_panel_drag('tracker', settings.tracker.x, settings.tracker.y, layout.width, size[2]);
    end
    imgui.End();
end

return M;
