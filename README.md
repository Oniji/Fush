# Fush

Ashita v4 fishing companion for [HorizonXI](https://horizonxi.com/). Tracks bites and feelings, session stats and gil, and (on HorizonXI) fishing pool restocks on the Vanadiel clock.

UI rendering adapted from [XIUI](https://github.com/tirem/XIUI) (GPLv3).

---

## Features

### Bite tracker

Large on-screen overlay for hook type (small fish, large fish, item, monster) and feeling as soon as the bite message appears.

![Bite tracker](docs/screenshots/bite.png)

### Session tracker

Live session panel with:

- Fishing skill and session skillups (hidden at 100)
- Casts, bites, and accuracy (bites per cast)
- Monster / item / fish bite counts (counted on bite, not only on catch)
- Priced catch list, optional bait cost, net gil and gil/hour

Session stats persist across addon reloads unless **Reset Session On Load** is enabled.

![Session tracker](docs/screenshots/session.png)

### Pool resupply bar

Vanadiel-day progress bar with notches at HorizonXI pool restock hours (`00:00`, `04:00`, `06:00`, `07:00`, `17:00`, `18:00`, `20:00`), countdown to the next restock, and current Vanadiel time with day-element indicator.

> **HorizonXI only.** Restock hours and pool timing are specific to HorizonXI and will not match retail or other private servers.

![Pool resupply bar](docs/screenshots/pool.png)

### Config UI

In-game settings for module visibility, fonts, themes, per-module opacity, tracker prices/bait, and panel layout. Hold **Shift** and left-drag a panel to move it when the config window is closed (or drag freely while config is open).

![Config](docs/screenshots/config.png)

---

## Installation

1. Copy the `fush` folder into your Ashita addons directory:

   ```text
   Ashita/addons/fush/
   ```

2. Ensure the Ashita **addons** plugin is loaded (`/load addons` if needed).

3. Load the addon in-game:

   ```text
   /addon load fush
   ```

Optional: add `fush` to your Ashita bootstrap so it loads automatically on login.

---

## Commands

| Command | Description |
|---------|-------------|
| `/fush` | Toggle the config window |
| `/fush config` | Toggle the config window |
| `/fush report` | Print session stats to chat |
| `/fush clear` | Clear the current session |
| `/fush show` | Show all panels |
| `/fush hide` | Hide all panels |
| `/fush save` | Save settings |
| `/fush reload` | Reload settings from disk |

---

## Notes

- **Pool tracker** is intended for **HorizonXI only**. Disable it in General → Modules on other servers.
- **Default item prices** are **LandSandBoat (LSB) vendor prices**. HorizonXI values may differ — edit them under Tracker → Item Prices (`name:price`, one per line). Only items in that list are counted toward gil and the catch list.
- Prices are matched case-insensitively against catch names from the chat log.
- The bite overlay hides when you zone or stop fishing.

---

## Attribution

Panel backgrounds, progress bars, and related UI rendering are adapted from [XIUI](https://github.com/tirem/XIUI) (GNU GPL v3.0). See `fush/THIRD_PARTY_NOTICES.md` and the **About** tab in `/fush`.

Bite/feeling message handling draws on ideas from [AshitaFishaid](https://github.com/TheAngryRogue/AshitaFishaid). Session gil/bait tracking is in the spirit of fishing-focused use of [HGather](https://github.com/SlowedHaste/HGather).

---

## Requirements

- Ashita v4
- Addons plugin loaded
