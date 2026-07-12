# Third-Party Notices

## XIUI

Fush's panel backgrounds, progress bars, and related UI rendering are adapted from
[XIUI](https://github.com/tirem/XIUI) by the XIUI contributors.

- **License:** GNU General Public License v3.0
- **Components used:** color utilities, bitmap gradient generation, texture loading,
  window background renderer, progress bar renderer, and bundled PNG assets under
  `fush/assets/` (Window1 backgrounds, optional gil/arrow icons).

Fush is a separate addon and is not affiliated with or endorsed by the XIUI project.

## Bundled fonts (`fush/assets/fonts/`)

Optional overlay fonts (Tahoma, Tahoma Bold, Segoe UI, Consolas, Verdana) are
Microsoft Windows fonts copied for local/offline use with the addon. They are
not redistributed as part of Fush's open-source license grant — do not ship them
publicly unless you have rights to do so. The Default (Agave) option uses
Ashita's built-in ImGui font and requires no bundled files.

## Lua-Bitmap (via XIUI)

`libs/bitmap.lua` is based on [Lua-Bitmap](https://github.com/RexmecK/Lua-Bitmap)
by RexmecK, as included in XIUI.
