# Client Addon Development

WoW 3.3.5a (build 12340) client addon development.
Addons live in `game_client/WOTLK/Interface/AddOns/`.

← [Back to Wiki Home](../README.md)

---

> **Status:** Reference file present. Full structured docs planned.

## Current Files

| File | Description |
|------|-------------|
| [addon_api.md](addon_api.md) | TOC/XML structure, frame system, events, unit/spell/item API for WoW 3.3.5a |

## Planned Files

| File | Will cover |
|------|------------|
| `overview.md` | Addon sandbox, SavedVariables, LibStub, loading order |
| `frame_system.md` | All frame types, CreateFrame, anchoring, scripts |
| `event_system.md` | RegisterEvent, all WotLK events with parameters |
| `unit_api.md` | UnitXxx functions, GUID format, unit tokens |
| `spell_item_api.md` | GetSpellInfo, GetItemInfo, tooltip functions |
| `combat_log.md` | WotLK CLEU — all events, varargs format (no CombatLogGetCurrentEventInfo) |
| `communication.md` | SendAddonMessage, AIO integration, ChatThrottleLib |
| `ui_patterns.md` | Minimap button, options panel, movable frame recipes |

## Project Addons

No custom addons installed yet — starting fresh. Addons go in `game_client/WOTLK/Interface/AddOns/`.

AIO bridge is available: `AIO/AIO_Client/AIO.lua` (client-side) — see [Lua Scripting](../lua_scripting/README.md) for server side.

## Key WotLK 3.3.5a Differences from Retail
- No `CombatLogGetCurrentEventInfo()` — use direct varargs
- No `C_Timer` — use `frame:SetScript("OnUpdate", ...)` for timers
- `RegisterAddonMessagePrefix` may not exist on private servers
- Protected API is bypassable with binary patches (see [wow_internals.md](../client_modding/wow_internals.md))
