# lua_scripts — Dreamforge Server Scripts

Server-side Lua scripts for the **Dreamforge** private server, running on **AzerothCore 3.3.5a** via the **mod-ale** Eluna engine.

---

## Directory Structure

```
lua_scripts/
├── check.lua                  — ALE load verification (safe to delete after confirming)
│
├── extensions/                — Loaded FIRST (*.ext files before *.lua)
│   ├── _Misc.ext              — RNG seed + StackTracePlus integration
│   ├── ObjectVariables.ext    — GetData/SetData API for all game objects
│   └── StackTracePlus/
│       └── StackTracePlus.ext — Enhanced Lua error stack traces
│
├── dfp-panel/                 — DFP Panel server entry point
│   └── dfp-panel-server.lua   — Stub loader / module index
│
├── dfp-ah/                    — Auction House module
│   └── dfp-ah-server.lua      — ".ah" command handler, per-player NPC spawning
│
└── dfp-daily/                 — Daily Tasks module
    ├── dfp-daily-server.lua   — Full server implementation
    ├── dfp-daily-client.lua   — Client-side stub/notes
    ├── README.md              — Comprehensive module documentation
    └── sql/
        ├── install.sql        — One-time DB setup (claude_scripts schema)
        └── sample_tasks.sql   — 33 sample tasks across all 6 types
```

---

## Loading Order

mod-ale scans all `.lua` and `.ext` files under `lua_scripts/` recursively. The rules are:

| Rule | Detail |
|------|--------|
| `.ext` files load before `.lua` files | Extensions always run first regardless of directory depth |
| Within each type, load order is filesystem order | No guaranteed alphabetical order between modules |
| All files share a single Lua state | Globals and upvalues are visible across all scripts |

**Practical consequence:** `ObjectVariables.ext` and `_Misc.ext` are guaranteed to be available when any `.lua` module starts. Never rely on load order between two `.lua` files.

---

## Module Overview

### `extensions/`
Utility layer. Runs before everything else. Provides `GetData`/`SetData` on all game objects, seeds `math.random`, and replaces `debug.traceback` with StackTracePlus for richer error output. See [extensions/README.md](extensions/README.md).

### `dfp-panel/`
Server entry point for the DforgePanel feature set. Currently a stub that documents which submodules exist. Feature logic lives in module subdirectories (`dfp-ah/`, etc.). See [dfp-panel/README.md](dfp-panel/README.md).

### `dfp-ah/`
Remote Auction House access. Handles the `.ah` dot command from any player. Spawns a faction-correct temporary auctioneer NPC, opens the AH window, and reuses the existing NPC if the player triggers the command again before despawn. See [dfp-ah/README.md](dfp-ah/README.md).

### `dfp-daily/`
Daily task assignment, progress tracking, reward delivery, and midnight reset. Full architecture, schema, and protocol documented in [dfp-daily/README.md](dfp-daily/README.md).

---

## Client Addons

Each server module has a matching client addon under `game_client/WOTLK/Interface/AddOns/`:

| Server module | Client addon | Trigger |
|---------------|-------------|---------|
| `dfp-ah/` | `DFP_AH/` | `/ah` → sends `.ah` to server |
| `dfp-daily/` | `DFP_Daily/` | Receives `CHAT_MSG_ADDON` messages |
| `dfp-panel/` | `DFP_Panel/` | Panel UI, calls other addons' slash commands |

---

## Communication Pattern

All server→client communication uses `player:SendAddonMessage(prefix, msg, 6, player)` — a whisper-to-self addon message. The client receives it as `CHAT_MSG_ADDON`. No AIO dependency.

```
Server                                    Client
  player:SendAddonMessage(                  CHAT_MSG_ADDON event
    "PREFIX",          ──────────────►        prefix  = "PREFIX"
    "MSGTYPE~f1~f2",                          message = "MSGTYPE~f1~f2"
    6,                                        type    = "WHISPER"
    player                                    sender  = player name
  )
```

---

## Adding a New Module

1. Create `lua_scripts/<module-name>/<module-name>-server.lua`
2. Create matching client addon in `game_client/WOTLK/Interface/AddOns/<AddonName>/`
3. Add a reference comment to `dfp-panel/dfp-panel-server.lua`
4. If the panel should call it, add a button to `DFP_Panel.lua` that calls `SlashCmdList["DFPNAME"]("")`
5. Write a `README.md` in the module folder documenting events, protocol, and config

---

## Common Pitfalls

### Eluna userdata invalidation
After every event callback, Eluna calls `InvalidateObjects()` which increments an internal `callstackid`. Any `Player`, `Creature`, or other userdata captured in a closure will fail `IsValid()` when accessed from a `CreateLuaEvent` timer. **Always store plain GUIDs** (`GetGUID()`) and re-resolve fresh objects inside the timer via `GetPlayerByGUID` / `map:GetWorldObject`.

### uint64 as table key
`GetGUID()` returns a `uint64` userdata in mod-ale's Eluna fork. Using it directly as a Lua table key creates a new key entry each call (two distinct userdata objects are never `==` even for the same GUID). **Always use `tostring(guid)` as the key.**

### `GetGUIDLow()` vs `GetGUID()`
- `GetGUIDLow()` returns a plain Lua number (32-bit low part of the GUID) — safe as a table key directly.
- `GetGUID()` returns a uint64 userdata — must be `tostring()`'d before use as a table key.

The daily-tasks module uses `GetGUIDLow()`. The dfp-ah module uses `tostring(GetGUID())`. Either is correct; be consistent within a module.

### mod-ale event constants
mod-ale does **not** export Eluna event constants as Lua globals. Use raw integer values. See the constants table in each module's source file or the list at the top of `dt-server.lua`.
