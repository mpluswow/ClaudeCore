# Dreamforge — Private WoW 3.3.5a Server Modding Project

## What Is This?

Dreamforge is a private World of Warcraft server project targeting **Wrath of the Lich King, Patch 3.3.5a (build 12340)**. The goal is full-stack WoW server modding: custom server logic, Lua scripting, UI addons, client modifications, and database content — all running on a local AzerothCore installation.

---

## Project Structure

```
wow335a/
├── AIO/                        # AIO Addon I/O — Lua server↔client messaging system
│   ├── AIO_Client/             # Runs inside WoW as a client addon
│   ├── AIO_Server/             # Runs server-side via Eluna/mod-ale
│   └── Examples/               # Reference examples (HelloWorld, PingPong, etc.)
│
├── acore_source/               # AzerothCore server emulator (C++, CMake)
│   ├── src/                    # Core source code
│   │   ├── common/             # Shared libs: networking, crypto, logging, threading
│   │   ├── server/game/        # ~52 game subsystems
│   │   ├── server/scripts/     # Content scripts (bosses, zones, spells)
│   │   ├── server/database/    # DB abstraction + migrations
│   │   └── tools/              # Map/vmap/mmap data extractors
│   ├── modules/mod-ale/        # Lua scripting engine (AzerothCore fork of Eluna)
│   ├── data/sql/               # Database schemas and update files
│   └── conf/dist/              # Default config templates
│
├── game_client/WOTLK/          # Full WoW client (realmlist → 127.0.0.1)
│   └── Interface/AddOns/       # 27 addons, including DreamBar* and AIO
│
├── raw_patches/                # Extracted MPQ archives (base game data)
├── raw_locale_patches/         # Extracted MPQ archives (enUS locale/speech)
│
├── docs/                       # Project documentation
│   └── findings/               # Research notes
├── db_info.md                  # Database credentials
└── useful_links.md             # Reference links
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Server emulator | AzerothCore v16.0.0-dev (C++17, CMake) |
| Game version | WoW 3.3.5a, build 12340 |
| Server scripting | mod-ale (Eluna fork) — Lua 5.2/5.3/5.4/LuaJIT |
| Addon communication | AIO (pure Lua, Eluna + WoW API) |
| Database | MySQL — auth, characters, world, eluna |
| Client | WOTLK client, patched for localhost |

---

## Servers

| Server | Port | Database |
|---|---|---|
| authserver | 3724 | claude_auth |
| worldserver | 8085 | claude_characters, claude_world |

---

## Databases

| Database | Purpose |
|---|---|
| `claude_auth` | Accounts, realm list, bans |
| `claude_characters` | Character data, progression, inventories |
| `claude_world` | Game content (creatures, items, quests, spells) |
| `claude_eluna` | Custom Lua script data storage |

DB connection: `127.0.0.1` — see `db_info.md` for credentials.

---

## Custom Content (In Progress)

### Client Addons
- **DreamBar** — Custom UI bar
- **DreamBar_Rankings** — Rankings UI
- **DreamBar_DailyQuests** — Daily quest tracker
- **AIO** — Server↔client communication (enables server-driven UI)

### AIO System
AIO allows server-side Lua code to push addon code and messages to connected players. Architecture:
1. Server registers addon files via `AIO.AddAddon()` (runs in Eluna/mod-ale)
2. Client caches addon Lua code (via hidden addon channel)
3. Both sides use `AIO.Msg():Add(name, handler, ...):Send()` for real-time messaging

---

## Key Reference Links

| Resource | URL |
|---|---|
| WoW Dev Wiki | https://wowdev.wiki/Main_Page |
| WoW 3.3.5a API | https://wowwiki-archive.fandom.com/wiki/World_of_Warcraft_API |
| Eluna API | https://www.azerothcore.org/eluna/ |
| Lua 5.2 Manual | https://www.lua.org/manual/5.2/ |
| Awesome WotLK mods | https://github.com/FrostAtom/awesome_wotlk |
| API Unlocking guide | https://romanh.de/article/Unlocking-API-Functions-in-WoW-335a-using-a-Disassembler |

---

## Build Notes (AzerothCore)

```bash
# CMake configure (out-of-source build)
cmake ../acore_source \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DSCRIPTS=static \
  -DMODULES=static \
  -DAPPS_BUILD=all \
  -DTOOLS_BUILD=none

# Build
make -j$(nproc)
```

Key CMake options:
- `SCRIPTS` — none / static / dynamic / minimal-static / minimal-dynamic
- `MODULES` — none / static / dynamic
- `APPS_BUILD` — none / all / auth-only / world-only
- `TOOLS_BUILD` — none / all / db-only / maps-only
- `BUILD_TESTING` — 0/1

---

## AzerothCore Source Architecture (Quick Reference)

```
src/server/game/
├── Entities/       # Player, Creature, Unit, Item, GameObject, Pet, Vehicle...
├── Spells/         # Spell system, auras, effects, damage
├── Maps/           # World maps, grid system, instancing
├── AI/             # Creature AI framework
├── Scripting/      # Script registration (SpellScript, CreatureScript, etc.)
├── Handlers/       # Client packet handlers
├── Quests/         # Quest system
├── Combat/         # Combat resolution
├── Battlegrounds/  # BG instances
├── Guilds/         # Guild system
└── ...~52 total subsystems
```

Script pattern:
```cpp
class my_script : public CreatureScript {
public:
    my_script() : CreatureScript("my_script") {}
    // override hooks...
};

void AddSC_my_script() {
    new my_script();
}
```

---

*Last updated: 2026-03-17*
