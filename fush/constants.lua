--[[
* Fush - Fishing constants
]]--

require('common');

local M = {};

-- Chat lines for hook type (matched in bite tracker). logcolor = Ashita chat mode.
M.HOOK_MESSAGES = {
    { message = 'Something caught the hook!!!', hook = 'Large Fish', color = '#44ff88', logcolor = 204 },
    { message = 'Something caught the hook!', hook = 'Small Fish', color = '#44ff88', logcolor = 204 },
    { message = 'You feel something pulling at your line.', hook = 'Item', color = '#e6c84a', logcolor = 141 },
    { message = 'Something clamps onto your line ferociously!', hook = 'Monster', color = '#ff5555', logcolor = 167 },
};

M.FEEL_MESSAGES = {
    { message = 'You have a good feeling about this one!', feel = 'Good', color = '#44ff88', logcolor = 204 },
    { message = 'You have a bad feeling about this one.', feel = 'Bad', color = '#e6c84a', logcolor = 141 },
    { message = 'You have a terrible feeling about this one...', feel = 'Terrible', color = '#ff5555', logcolor = 167 },
    { message = 'You don\'t know if you have enough skill to reel this one in.', feel = 'Skill?', color = '#88ddff', logcolor = 204 },
    { message = 'You\'re fairly sure you don\'t have enough skill to reel this one in.', feel = 'Low Skill', color = '#e6c84a', logcolor = 141 },
    { message = 'You\'re positive you don\'t have enough skill to reel this one in!', feel = 'Too Low', color = '#ff5555', logcolor = 167 },
    { message = 'This strength... You get the sense that you are on the verge of an epic catch!', feel = 'Epic', color = '#b44dff', logcolor = 204 },
    -- Keen Angler's Sense; fish name varies.
    { message = 'Your keen angler\'s senses tell you that this is the pull of an? (.+)!', feel = 'Keen', color = '#3359B3', logcolor = 204 },
};

M.FISH_HOOK_TYPES = T{ 'Small Fish', 'Large Fish' };
M.ITEM_HOOK_TYPE = 'Item';
M.MONSTER_HOOK_TYPE = 'Monster';

-- HorizonXI pool restock hours (Vana'diel clock).
M.POOL_RESTOCK_HOURS = T{ 0, 4, 6, 7, 17, 18, 20 };

-- Outgoing action: start fishing (action field on 0x01A).
M.FISHING_ACTION_START = 0x0E;
-- Outgoing: general action packet (cast / engage fishing).
M.PACKET_ACTION = 0x01A;
-- Fishing-specific action packet (not used for cast counting currently).
M.PACKET_FISHING_ACTION = 0x110;
-- Incoming: zone / enter (player entity refresh).
M.PACKET_ZONE = 0x00A;
-- Incoming: player status update (used to clear bite overlay when idle).
M.PACKET_STATUS = 0x037;

-- Ashita GetCraftSkill index for Fishing.
M.FISHING_CRAFT_SKILL_INDEX = 0;
-- Skill id inside message packet 0x029 for fishing craft.
M.FISHING_SKILL_ID = 48;
-- Incoming message / skillup packet.
M.PACKET_MESSAGE = 0x029;
-- 0x029 MessageNum values (lower 15 bits):
M.MSG_SKILL_FRAC = 38; -- tenths ("skill rises 0.1")
M.MSG_SKILL_TICK = 53; -- whole rank ("skill rises to N")

return M;
