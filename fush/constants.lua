--[[
* Fush - Fishing constants
]]--

require('common');

local M = {};

M.HOOK_MESSAGES = {
    { message = 'Something caught the hook!!!', hook = 'Large Fish',  color = '#44ff88', logcolor = 204 },
    { message = 'Something caught the hook!',   hook = 'Small Fish',  color = '#44ff88', logcolor = 204 },
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
};

M.FISH_HOOK_TYPES = T{ 'Small Fish', 'Large Fish' };
M.ITEM_HOOK_TYPE = 'Item';
M.MONSTER_HOOK_TYPE = 'Monster';

-- HorizonXI fishing pool restock hours (Vana'diel time)
M.POOL_RESTOCK_HOURS = T{ 0, 4, 6, 7, 17, 18, 20 };

M.FISHING_ACTION_START = 0x0E;
M.PACKET_ACTION = 0x01A;
M.PACKET_FISHING_ACTION = 0x110;
M.PACKET_ZONE = 0x00A;
M.PACKET_STATUS = 0x037;

-- Ashita craft skill index: Fishing is 0
M.FISHING_CRAFT_SKILL_INDEX = 0;
-- Packet 0x029 skill ID for fishing craft skillups
M.FISHING_SKILL_ID = 48;
M.PACKET_MESSAGE = 0x029;
M.MSG_SKILL_FRAC = 38;
M.MSG_SKILL_TICK = 53;

return M;
