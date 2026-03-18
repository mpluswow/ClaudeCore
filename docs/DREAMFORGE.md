# Dreamforge — Private WoW 3.3.5a Server Modding Project

## What Is This?

Dreamforge is a private World of Warcraft server project targeting **Wrath of the Lich King, Patch 3.3.5a (build 12340)**. The goal is full-stack WoW server modding: custom server logic, Lua scripting, UI addons, client modifications, and database content — all running on a local AzerothCore installation.

---

## Project Structure

```
wow335a/
├── readme.md                   # Project entry point
├── rebuild.sh                  # Build script
├── db_info.md                  # Database credentials
├── useful_links.md             # External reference links
│
├── acore_source/               # AzerothCore server (C++, CMake)
│   ├── src/                    # Core source (game/, scripts/, database/, shared/)
│   ├── modules/mod-ale/        # Eluna Lua scripting engine
│   ├── env/dist/               # Compiled output: bin/, etc/
│   └── var/build/obj/          # CMake build cache
│
├── acore_data_files/           # Extracted client data (dbc/, maps/, vmaps/, mmaps/)
├── Keira3/                     # DB editor (Electron + Angular)
│
├── AIO/                        # Server↔client Lua messaging
│   ├── AIO_Client/AIO.lua      # Client-side (WoW addon)
│   └── AIO_Server/AIO.lua      # Server-side (mod-ale)
│
├── game_client/WOTLK/          # WoW 3.3.5a client (realmlist → 127.0.0.1)
│   └── Interface/AddOns/       # Custom addons go here
│
├── raw_patches/                # Extracted base MPQ archives
├── raw_locale_patches/         # Extracted enUS locale MPQ archives
│
└── docs/                       # Modding wiki (start at docs/README.md)
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
| authserver | 3724 | acore_auth |
| worldserver | 8085 | acore_characters, acore_world |

---

## Databases

| Database | Purpose |
|---|---|
| `acore_auth` | Accounts, realm list, bans |
| `acore_characters` | Character data, progression, inventories |
| `acore_world` | Game content (creatures, items, quests, spells) |

Custom project data: **`dreamforge_`-prefixed tables** inside `acore_world`.

DB connection: see `db_info.md` for credentials (local MySQL 8.4)

---

## Custom Content (In Progress)

### Client Addons

No custom addons installed yet — starting fresh. Addons go in `game_client/WOTLK/Interface/AddOns/`.

### AIO System
AIO allows server-side Lua code to push addon code and messages to connected players. Architecture:
1. Server registers addon files via `AIO.AddAddon()` (runs in Eluna/mod-ale)
2. Client caches addon Lua code (via hidden addon channel)
3. Both sides use `AIO.Msg():Add(name, handler, ...):Send()` for real-time messaging

AIO files: `AIO/AIO_Server/AIO.lua` (server-side), `AIO/AIO_Client/AIO.lua` (client-side template)

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
./rebuild.sh                  # configure + build + install
./rebuild.sh --build-only     # recompile changed files only (fast)
./rebuild.sh --clean          # clean build dir + full rebuild
```

Binaries installed to: `acore_source/env/dist/bin/`
Configs installed to: `acore_source/env/dist/etc/`

Key CMake options (set in `rebuild.sh`):
- `SCRIPTS=static`, `MODULES=static`, `APPS_BUILD=all`, `TOOLS_BUILD=none`
- `CMAKE_BUILD_TYPE=RelWithDebInfo`, compiler: clang 18

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

*Last updated: 2026-03-18*
