# AzerothCore: Architecture & Server Overview

## Overview

AzerothCore (AC) is an open-source, modular World of Warcraft 3.3.5a (WotLK) server emulator derived from MaNGOS → TrinityCore → SunwellCore. It runs two server binaries — `worldserver` and `authserver` — backed by three MySQL databases, with all gameplay scripting surface-area exposed through a `ScriptMgr` hook system and optionally the Eluna Lua Engine module.

Understanding this architecture is essential for modding because every hook, SQL injection point, config option, and CMake module slot sits at a specific layer of this stack. Getting something wrong at the wrong layer (e.g., touching world state from a network thread) causes hard-to-debug race conditions or crashes.

---

## Server Binaries

### worldserver
The core process. Loads all game data, manages the live world, runs the main update loop, and accepts player connections on TCP port 8085 (default). All scripting hooks described in `01_module_system.md` run inside this process.

### authserver
Handles account login, realm list, and session key distribution. Talks to `acore_auth` only. Players connect here first (port 3724), authenticate, then redirect to worldserver. Authserver has very few scripting hooks — most custom work goes into worldserver.

### Shared Libraries
Both binaries link against common static libraries built from `src/common/`. This includes:

- `common` — Configuration manager (`sConfigMgr`), logging (`sLog`), database connection pool, cryptography utilities, threading primitives
- `shared` — Basic WoW data types (guids, opcodes, packet structures)

---

## The Three Databases

| Database | Name | Purpose |
|---|---|---|
| Auth | `acore_auth` | Account credentials, session keys, realm list, IP bans, character selection list |
| Characters | `acore_characters` | All character data: stats, inventory, quests, spells learned, mail, friends, guilds, groups |
| World | `acore_world` | Game content: creature templates, gameobject templates, quest templates, item templates, spell customizations, waypoints, loot tables, SmartAI data |

### Database Access Singletons
```cpp
// In any server-side C++ file:
CharacterDatabaseConnection& CharacterDatabase;  // extern in DatabaseEnv.h
LoginDatabaseConnection&     LoginDatabase;
WorldDatabaseConnection&     WorldDatabase;
```

All DB access goes through `PreparedStatement` objects. Direct string queries are deprecated. The async pattern uses `CharacterDatabase.AsyncQuery(stmt, callback)`.

### Custom Tables
Modules add custom tables by placing SQL files in their `sql/` subdirectory. The AC database assembler applies these automatically. See `01_module_system.md` for the `base/` + `updates/` pattern.

---

## Key Source Directories

```
azerothcore-wotlk/
├── modules/                        ← Module drop-in directory
│   ├── CMakeLists.txt              ← Module discovery and linkage logic
│   ├── ModulesScriptLoader.h       ← Generated file listing all AddSC_ functions
│   ├── create_module.sh            ← Interactive module scaffolding tool
│   └── <mod-name>/                 ← One directory per installed module
│
├── src/
│   ├── common/                     ← Shared utilities (config, logging, DB, crypto)
│   ├── server/
│   │   ├── authserver/             ← Auth binary entry point
│   │   ├── worldserver/            ← World binary entry point + Main.cpp
│   │   └── game/                   ← All game logic (the bulk of the codebase)
│   │       ├── AI/                 ← CreatureAI, SmartAI, CombatAI
│   │       ├── Accounts/
│   │       ├── AuctionHouse/
│   │       ├── Battlegrounds/
│   │       ├── Chat/               ← ChatHandler, command system
│   │       ├── Combat/
│   │       ├── Entities/           ← Player, Creature, Item, GameObject classes
│   │       ├── Grids/              ← Spatial partitioning, cell management
│   │       ├── Guilds/
│   │       ├── Handlers/           ← Opcode handler functions (HandleXxxOpcode)
│   │       ├── Instances/
│   │       ├── Loot/
│   │       ├── Maps/               ← Map, MapMgr, InstanceMap, BattlegroundMap
│   │       ├── Misc/
│   │       ├── Movement/
│   │       ├── Quests/
│   │       ├── Scripting/          ← ScriptMgr.h/.cpp, ScriptObject, ScriptDefines/
│   │       ├── Server/             ← WorldSocket, WorldSession, Opcodes
│   │       ├── Spells/
│   │       ├── World/              ← World singleton, sWorld, update loop
│   │       └── ...
│   └── test/                       ← Unit tests (gtest)
│
├── data/                           ← DBC extracts, maps, vmaps, mmaps
├── conf/                           ← worldserver.conf.dist, authserver.conf.dist
└── deps/                           ← Bundled third-party libraries
```

### Scripts Subdirectory
`src/server/scripts/` contains the built-in C++ scripts (Northrend bosses, spells, quests, etc.) that ship with AC. These register themselves via the same `ScriptMgr` system your modules use. Module scripts live in `modules/<mod-name>/src/` instead.

---

## Startup Sequence (worldserver)

The worldserver startup runs roughly in this order:

### 1. Process & Signal Setup
Early init: signal handlers, random seed, detour memory management functions, VMap function pointers, pid file.

### 2. Configuration Loading
`sConfigMgr->LoadInitial(configFile)` reads `worldserver.conf`. All options are now available through `sConfigMgr->GetOption<T>(key, default)`. Modules hook `OnBeforeConfigLoad` / `OnAfterConfigLoad` here.

### 3. Logging System
`sLog->Initialize()` starts async logging threads.

### 4. Database Connections
Connection pools for all three databases are opened. Schema version checks run. The DB assembler applies any pending SQL updates from `sql/updates/` directories (including module SQL). Hooks: `OnAfterDatabasesLoaded`.

### 5. Script Loading (Phase 1 — Registration)
`ScriptMgr::SetScriptLoader()` and `ScriptMgr::SetModulesLoader()` register callback functions. At this point the generated `ModulesScriptLoader.cpp` calls every module's `AddXxxScripts()` function, which calls `new MyScript()` inside, registering all script objects in `ScriptRegistry<T>`.

### 6. World Initialization — `World::SetInitialWorldSettings()`
This is the big one. In order:

1. Core singletons: RNG, game time, uptime counters
2. Config values cached into world config system
3. DB GUID high-watermarks loaded
4. Map file existence checks
5. Pool manager and game event manager init
6. **DBC data loading**: races, classes, spell data, maps, areas, factions, items, etc.
7. VMap and MMap managers initialized
8. Content loading: graveyards, spells, items, creatures, quests, vendors, trainers, waypoints, loot tables
9. Dynamic content: guilds, groups, arenas, achievements, calendar
10. **Scripts loaded and validated** (`ScriptMgr::LoadDatabase()`, SmartAI data from `acore_world.smart_scripts`)
11. Battlegrounds, outdoor PvP, transports, warden initialized
12. Timers set (daily/weekly/monthly quest resets)
13. Map manager initialized; optionally pre-loads all non-instanced map grids

### 7. Network Startup (IoContext / WorldSocketMgr)
`WorldSocketMgr::StartNetwork()` creates the Asio `io_context`, binds TCP port 8085, and starts the network thread pool. Hooks: `OnNetworkStart`.

### 8. Main Loop
`World::UpdateLoop()` begins. See the "Server Tick" section below.

### 9. Shutdown
On SIGTERM or `.server shutdown`: `OnShutdownInitiate`, graceful session drain, `OnShutdown`, `OnAfterUnloadAllMaps`, network stop (`OnNetworkStop`).

---

## WorldPacket Flow: Opcode Lifecycle

How a client action (e.g., buying an item from a vendor) travels through the stack:

```
[WoW Client]
    │  TCP stream → encrypted packet
    ▼
[WorldSocket::ReadHeaderHandler()]
    │  Decrypts ClientPktHeader (size + opcode)
    │  Validates: size in [4, 10240], opcode < NUM_OPCODE_HANDLERS
    ▼
[WorldSocket::ReadDataHandler()]
    │  Reads payload into WorldPacket
    │  Looks up OpcodeTable[opcode] → ClientOpcodeHandler*
    │  Checks SessionStatus (must be authed / in-world / etc.)
    │  Checks PacketProcessing: INPLACE, THREADUNSAFE, THREADSAFE
    │
    ├─ INPLACE → call handler directly on network thread (rare, safe small ops)
    ├─ THREADUNSAFE → enqueue to WorldSession::_recvQueue
    └─ THREADSAFE → enqueue to separate thread-safe queue
    ▼
[WorldSession::Update() — called from Map/World update tick]
    │  Drains _recvQueue
    │  For each packet: handler->Call(session, packet)
    ▼
[OpcodeHandler::Call() → WorldSession::HandleBuyItemOpcode()]
    │  Reads fields from WorldPacket using >> operator
    │  Calls game logic (Player::BuyItemFromVendorSlot, etc.)
    │  Sends response packet via WorldSession::SendPacket()
    ▼
[WorldSession::SendPacket() → WorldSocket::SendPacket()]
    │  Encodes ServerOpcodeHandler response
    │  Async write to client TCP socket
    ▼
[WoW Client receives response packet]
```

### OpcodeTable Structure
```cpp
class OpcodeHandler {
public:
    char const*   Name;
    SessionStatus Status;   // STATUS_AUTHED, STATUS_LOGGEDIN, etc.
};

class ClientOpcodeHandler : public OpcodeHandler {
public:
    PacketProcessing ProcessingPlace;  // INPLACE, THREADUNSAFE, THREADSAFE
    virtual void Call(WorldSession* session, WorldPacket& packet) const = 0;
};

class OpcodeTable {
    ClientOpcodeHandler* _internalTableClient[NUM_OPCODE_HANDLERS];
public:
    ClientOpcodeHandler const* operator[](Opcodes index) const;
    void Initialize();
};
extern OpcodeTable opcodeTable;
```

### ScriptMgr Packet Hooks
Before a packet is processed, `ServerScript` hooks are called:
```cpp
// CanPacketReceive — return false to silently drop an incoming packet
virtual bool CanPacketReceive(WorldSession* session, WorldPacket const& packet);

// CanPacketSend — return false to prevent a packet being sent to the client
virtual bool CanPacketSend(WorldSession* session, WorldPacket const& packet);
```

---

## Threading Model: IoContext and ThreadPool

AzerothCore uses Boost.Asio (wrapped as `Acore::Asio`) for all async I/O.

### Network Threads
`WorldSocketMgr` creates a thread pool sized to `Network.Threads` config value (default 1). Each thread runs `io_context::run()`. All socket reads and writes are posted to this pool. The network threads **never** directly call game logic — they only enqueue packets to session queues.

### Map Update Threads
Each `Map` object runs its `Update()` on a dedicated thread managed by `MapUpdater`. Instance maps, battleground maps, and the world map each have their own thread. This means:

- **Safe to access**: objects on the same map (same thread)
- **Unsafe without locking**: cross-map object access, static singletons that aren't thread-safe

### World Thread
The `World::UpdateLoop()` runs on the main thread. It processes global state (sessions not yet assigned to a map, CLI commands, cross-map broadcasts).

### Database Async Pattern
```cpp
// Async query with callback — runs DB query on DB thread, calls lambda on world thread
CharacterDatabase.AsyncQuery(stmt, [](QueryResult result) {
    // Called from world thread after DB returns
});
```

---

## The Server Tick: World::Update()

Called continuously from the main loop. The `diff` parameter is milliseconds since last tick. The sequence per tick:

1. **Game time update** — advance internal clock, check shutdown condition
2. **World timer processing** — MOTD, config reload timers
3. **Ban cleanup** (every 5 s) — remove expired character/IP bans
4. **Who list cache refresh**
5. **Quest timer resets** — daily (midnight), weekly, monthly
6. **Auction house processing** — expire/complete auctions
7. **Mail expiration checks**
8. **Session update loop** — `WorldSession::Update()` for all sessions not on a map
9. **Map manager update** — triggers per-map update threads
10. **Battleground updates**
11. **Outdoor PvP updates**
12. **Battlefield (Wintergrasp/TB) updates**
13. **LFG system update**
14. **SQL async callback processing**
15. **Server statistics / uptime table**
16. **Game event check/trigger**
17. **Database ping** — keeps connection alive
18. **Instance reset timer checks**
19. **CLI command processing** (last)

WorldScript hooks that fire during the tick:
```cpp
virtual void OnUpdate(uint32 diff);          // every tick
virtual void OnStartup();                    // once after world init
virtual void OnShutdown();                   // during shutdown
virtual void OnBeforeConfigLoad(bool reload);
virtual void OnAfterConfigLoad(bool reload);
virtual void OnLoadCustomDatabaseTable();    // during DB load phase
```

---

## Build System: CMake Superbuild

AzerothCore uses CMake 3.16+ with a macro-based module discovery system.

### Top-Level Structure
```
CMakeLists.txt
├── add_subdirectory(deps)          ← bundled libs (zlib, openssl wrappers, etc.)
├── add_subdirectory(src/common)    ← shared utilities library
├── add_subdirectory(src)           ← game/worldserver/authserver
└── add_subdirectory(modules)       ← all discovered modules
```

### Module Discovery (`modules/CMakeLists.txt`)
```cmake
# Enumerate all subdirectories of modules/
CU_SUBDIRLIST(sub_DIRS "${CMAKE_SOURCE_DIR}/modules" FALSE FALSE)

foreach(subdir ${sub_DIRS})
    # Skip if in DISABLED_AC_MODULES list
    if (NOT subdir IN_LIST DISABLED_AC_MODULES)
        add_subdirectory(${subdir})
    endif()
endforeach()
```

### Module Linkage Modes
Set via `-DMODULES=<mode>` at cmake configure time:

| Mode | Behavior |
|---|---|
| `static` | All module `.cpp` files compiled into a single `modules` static lib, linked into worldserver |
| `dynamic` | Each module becomes a `.so`/`.dll` shared library, loaded at runtime |
| `disabled` | No modules compiled |

Default is `static` for most builds.

### Script Loader Generation
The `ConfigureScriptLoader()` CMake function generates `ModulesScriptLoader.cpp` at build time. It contains forward declarations and calls for every module's `AddXxxScripts()` function:
```cpp
// Generated: build/modules/ModulesScriptLoader.cpp
void AddSkeleton_moduleScripts();

void AddModulesScripts() {
    AddSkeleton_moduleScripts();
    // ... one line per installed module
}
```

This generated file is compiled and linked, forming the bridge between module registration functions and the ScriptMgr initialization.

### CMake Macros in `src/cmake/macros/`
- `ConfigureModules.cmake` — module static/dynamic linkage logic
- `ConfigureScripts.cmake` — built-in script configuration
- `AutoCollect.cmake` — glob-collect source files helper
- `GroupSources.cmake` — IDE source grouping
- `ConfigureBaseTargets.cmake` — compiler flags, PCH setup
- `ConfigureApplications.cmake` — worldserver/authserver target setup

---

## Configuration System

All config is read from `worldserver.conf` (copy of `worldserver.conf.dist`). Modules add their own `.conf.dist` files to `modules/<mod-name>/conf/`.

Reading config in C++:
```cpp
#include "Config.h"

bool enabled = sConfigMgr->GetOption<bool>("MyModule.Enable", false);
int32 rate    = sConfigMgr->GetOption<int32>("MyModule.XPRate", 1);
std::string s = sConfigMgr->GetOption<std::string>("MyModule.Prefix", "Hello");
```

`WorldScript::OnAfterConfigLoad(bool reload)` fires after every config load (initial + `/reload config`). This is where modules should re-read their config values.

---

## Cross-References

- `../kb_azerothcore_dev.md` — Comprehensive C++ hooks, SmartAI, DB schema reference (legacy KB)
- `01_module_system.md` — ScriptMgr hook details, module creation, all script types
- `../kb_eluna_api.md` — Eluna/ALE Lua engine API; mod-ale hooks into ScriptMgr via `ALEScript`
- `../kb_lua_reference.md` — Lua 5.2 stdlib and awesome_wotlk patterns
- `../kb_wow_internals.md` — WoW taint, protected API, memory offsets
