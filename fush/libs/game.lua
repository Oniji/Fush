--[[
* Fush - Client login / world state helpers
*
* Ashita GetLoginStatus():
*   2 = logged into the game world (includes brief zone transitions
*       when GetPlayerEntity() may be nil)
*   other values = title screen / character select / not in world
]]--

local M = {};

local LOGIN_STATUS_INGAME = 2;

function M.get_login_status()
    local ok, status = pcall(function()
        local player = AshitaCore:GetMemoryManager():GetPlayer();
        if player == nil then
            return nil;
        end
        return player:GetLoginStatus();
    end);
    if not ok then
        return nil;
    end
    return status;
end

-- True while in the game world. Stays true during inter-zone loads even if
-- player entity / craft APIs are temporarily unavailable.
function M.is_logged_in()
    return M.get_login_status() == LOGIN_STATUS_INGAME;
end

return M;
