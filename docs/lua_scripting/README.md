# Lua Scripting (mod-ale / Eluna)

Server-side Lua scripting via **mod-ale** (AzerothCore Lua Engine, Eluna fork).
Scripts live in `acore_source/env/dist/bin/lua_scripts/`.

← [Back to Wiki Home](../README.md)

---

> **Status:** Reference files present. Full structured docs planned next session.
> Agents will read from local source: `acore_source/modules/mod-ale/src/LuaEngine/`

## Current Files

| File | Description |
|------|-------------|
| [eluna_api.md](eluna_api.md) | Complete Eluna/ALE API — all 28 classes, all methods, RegisterXEvent constants, patterns |
| [lua_language.md](lua_language.md) | Lua 5.2 stdlib reference + awesome_wotlk / ConsolePortLK client mod patterns |

## Planned Files

| File | Will cover |
|------|------------|
| `overview.md` | How mod-ale loads scripts, globals available, error handling, file discovery |
| `event_system.md` | Every RegisterXEvent function — parameters, return values, when it fires |
| `database_queries.md` | WorldDBQuery, CharDBQuery, PreparedStatement from Lua |
| `aio_messaging.md` | AIO server↔client messaging — AddHandlers, Handle, sending tables, client wiring |
| `script_patterns.md` | Persistent data, timers, GUID safety, cross-script globals, performance tips |

## Quick Reference

```lua
-- Register a player event
RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, function(event, player)
    player:SendBroadcastMessage("Welcome, " .. player:GetName() .. "!")
end)

-- Query the database
local result = WorldDBQuery("SELECT value FROM dreamforge_players WHERE guid = " .. player:GetGUID())
if result then
    local value = result:GetUInt32(0)
end

-- Create a timer (fires once after 5 seconds)
CreateLuaEvent(function(event, delay, repeats)
    -- do something
end, 5000, 1)
```

## Local Source Files
- All Lua method headers: `acore_source/modules/mod-ale/src/LuaEngine/methods/`
- Event hook constants: `acore_source/modules/mod-ale/src/LuaEngine/Hooks.h`
- See [source_index.md](../source_index.md) for full file list
