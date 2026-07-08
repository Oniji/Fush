# Fush

Ashita v4 fishing addon for HorizonXI with UI rendering adapted from [XIUI](https://github.com/tirem/XIUI) (GPLv3).

## Features

- **Bite tracker** — Large on-screen display for hook type (small/large fish, item, monster) and feeling, based on [AshitaFishaid](https://github.com/TheAngryRogue/AshitaFishaid).
- **Session tracker** — Lines cast, hooks, fish/items caught, fish accuracy, gil earned, and optional bait cost subtraction (like [HGather](https://github.com/SlowedHaste/HGather), fishing-only).
- **Pool resupply bar** — Vanadiel day progress bar with notches at HorizonXI pool restock hours: `00:00`, `04:00`, `06:00`, `07:00`, `17:00`, `18:00`, `20:00`.

## Attribution

Fush uses adapted UI rendering code and assets from [XIUI](https://github.com/tirem/XIUI) (GNU GPL v3.0). See `fush/THIRD_PARTY_NOTICES.md` and the **About** tab in `/fush` for details.

## Install

1. Copy the `fush` folder into your Ashita `addons` directory:
   ```
   Ashita/addons/fush/
   ```
2. In-game:
   ```
   /addon load fush
   ```

## Commands

| Command | Description |
|---------|-------------|
| `/fush` | Toggle config window |
| `/fush report` | Print session stats to chat |
| `/fush clear` | Reset session stats |
| `/fush show` | Show all panels |
| `/fush hide` | Hide all panels |
| `/fush save` | Save settings |
| `/fush reload` | Reload settings |

## Configuration

Open `/fush` and use the tabs:

- **General** — Opacity, font scale, module visibility
- **Appearance** — Window theme, bookends, bar styling (XIUI renderer)
- **Tracker** — Bait cost, lure mode (skips bait subtraction), item prices (`itemname:price` per line)
- **Layout** — Panel positions and pool bar size
- **About** — Version info and third-party notices

## Requirements

- Ashita v4
- Addons plugin loaded (`/load addons`)

## Notes

- Pool restock `+X` fish counts per pool are not implemented yet (would require reliable pool/zone detection).
- Item prices are matched case-insensitively against catch names from chat log.
- Bite overlay hides when you zone or stop fishing (status packet).
