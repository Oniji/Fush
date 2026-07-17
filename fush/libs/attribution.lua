--[[
* Third-party attribution notices for Fush
]]--

local M = {};

M.DESCRIPTION = [[
Fush is an Ashita v4 fishing companion for HorizonXI. It shows bite type and feeling as you hook, tracks session casts, bites, catches, skillups, and gil, displays HorizonXI pool restock timing on the Vanadiel clock, and countdowns for common ferry routes until the next departure.
]];

M.XIUI_URL = 'https://github.com/tirem/XIUI';
M.XIUI_LICENSE = 'GNU General Public License v3.0';

M.XIUI_NOTICE = [[
UI rendering components and visual assets in Fush are derived from XIUI
(https://github.com/tirem/XIUI), copyright its respective authors, and used
under the terms of the GNU General Public License v3.0.

Ported/adapted components include:
  - libs/color.lua
  - libs/bitmap.lua (originally by RexmecK, used by XIUI)
  - libs/memory.lua (D3D device helpers)
  - libs/texturemanager.lua
  - libs/windowbackground.lua
  - libs/progressbar.lua
  - libs/drawing.lua
  - assets/backgrounds/* (Window1 theme)
  - assets/gil.png, assets/arrow.png (optional icons)
  - Procedural bar bookends (no bookend.png asset; drawn via progressbar.lua)

Source code for Fush is available at the addon repository. Corresponding
source for XIUI is available at the URL above.
]];

function M.get_short_credit()
    return string.format('UI assets and rendering adapted from XIUI (%s), GPLv3.', M.XIUI_URL);
end

return M;
