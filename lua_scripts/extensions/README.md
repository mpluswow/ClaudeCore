# extensions — Lua Engine Extensions

Utility scripts that load **before all other Lua files**. mod-ale loads `.ext` files prior to `.lua` files, so everything defined here is available globally when any module starts.

---

## Files

| File | Description |
|------|-------------|
| `_Misc.ext` | RNG seed + StackTracePlus integration |
| `ObjectVariables.ext` | `GetData` / `SetData` on all game objects |
| `StackTracePlus/StackTracePlus.ext` | Enhanced Lua stack trace library |
| `StackTracePlus/README.md` | StackTracePlus usage and output examples |

---

## `_Misc.ext`

**Purpose:** Global initialization that must run before anything else.

### What it does

#### 1. RNG seed
```lua
math.randomseed(tonumber(tostring(os.time()):reverse():sub(1,6)))
```
Seeds `math.random` using the lower digits of `os.time()` (reversed, first 6 chars). This avoids the common pitfall of seeding with the full epoch value, which changes slowly and produces identical sequences on rapid restarts.

#### 2. StackTracePlus
```lua
local trace = require("StackTracePlus")
debug.traceback = trace.stacktrace
```
Replaces the default `debug.traceback` with StackTracePlus's implementation. All Eluna error output will include local variable dumps and full call chains instead of just line numbers.

---

## `ObjectVariables.ext`

**Purpose:** Adds `GetData(key)` and `SetData(key, val)` methods to `Player`, `Creature`, `GameObject`, and `Map` — allowing scripts to attach arbitrary Lua values to any in-world object without modifying the C++ source.

### API

```lua
-- Store a value on any game object
obj:SetData("myKey", someValue)

-- Retrieve a value
local val = obj:GetData("myKey")

-- Retrieve the entire data table
local tbl = obj:GetData()
```

Supported types: `Player`, `Creature`, `GameObject`, `Map`.

### Storage Structure

Data is held in a module-local table, never in the C++ object itself:

```
variableStores = {
    Player     = { [guidLow] = { key = val, ... } }
    Creature   = { [mapId] = { [instanceId] = { [guidLow] = { key = val } } } }
    GameObject = { [mapId] = { [instanceId] = { [guidLow] = { key = val } } } }
    Map        = { [mapId] = { [instanceId] = { [1]       = { key = val } } } }
}
```

**Players** are keyed directly by `GetGUIDLow()` — they are not tied to a specific map or instance.

**All other objects** are keyed by `mapId → instanceId → guidLow`. The instance dimension prevents GUID collisions between different instances of the same dungeon.

### Automatic Cleanup

Stale data is removed automatically via registered events:

| Event | Raw ID | Handler | What it cleans |
|-------|--------|---------|----------------|
| `PLAYER_EVENT_ON_LOGOUT` | 4 | `DestroyObjData` | Player's data entry |
| `SERVER_EVENT_ON_CREATURE_DELETE` | 31 | `DestroyObjData` | Creature's data entry |
| `SERVER_EVENT_ON_GAMEOBJECT_DELETE` | 32 | `DestroyObjData` | GameObject's data entry |
| `SERVER_EVENT_ON_MAP_CREATE` | 17 | `DestroyMapData` | All entries for the map+instance |
| `SERVER_EVENT_ON_MAP_DESTROY` | 18 | `DestroyMapData` | All entries for the map+instance |

`DestroyMapData` clears the entire `[mapId][instanceId]` subtree across all object types, covering Creature, GameObject, and Map data in one pass.

### Method Injection

At load time the methods are injected into the global metatables:

```lua
for k, v in pairs(variableStores) do
    _G[k].GetData = GetData   -- e.g. Player.GetData, Creature.GetData, ...
    _G[k].SetData = SetData
end
```

This means `GetData` and `SetData` become methods on every instance of those types, accessible via `:` syntax.

### Usage Example

```lua
-- Store a cooldown timestamp on a player
player:SetData("lastTeleport", os.time())

-- Check it later (in a different event callback)
local last = player:GetData("lastTeleport")
if last and (os.time() - last) < 60 then
    player:SendBroadcastMessage("Teleport is on cooldown.")
    return
end
```

---

## `StackTracePlus/StackTracePlus.ext`

**Purpose:** Enhanced stack trace library. Replaces Lua's minimal `debug.traceback` output with a detailed report that includes:

- Full call chain with source file and line number
- Local variable names and values at each stack frame
- Recognition of Lua standard library functions
- Support for C functions, tail calls, and coroutines

**Source:** Eluna Lua Engine project (GPL v3, emudevs.com). Supports Lua 5.1, 5.2, LuaJIT.

### Output Example

Without StackTracePlus:
```
attempt to index a nil value (global 'player')
stack traceback:
    dt-server.lua:42: in function 'dtSendInit'
    dt-server.lua:120: in function <dt-server.lua:110>
```

With StackTracePlus:
```
attempt to index a nil value (global 'player')
stack traceback:
    dt-server.lua:42: in function 'dtSendInit'
        local guid = 12345
        local c    = table: 0x55f2a1b3c0
        local player = nil   <-- problem here
    dt-server.lua:120: in function <dt-server.lua:110>
        ...
```

This is configured in `_Misc.ext` and applies globally to all Eluna error output.

See [StackTracePlus/README.md](StackTracePlus/README.md) for full usage documentation.
