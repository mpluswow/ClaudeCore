# Dreamforge

Private WoW server modding project — **Wrath of the Lich King 3.3.5a (build 12340)**.

Full-stack: custom C++ modules, server-side Lua, client addons, database content, DBC edits.

---

## Quick Start

### Build the server
```bash
./rebuild.sh                 # configure + build + install (~30-60 min first time)
./rebuild.sh --build-only    # recompile only changed files (fast, use after edits)
./rebuild.sh --clean         # wipe build dir and rebuild from scratch
```

### Run the server
```bash
# Terminal 1
acore_source/env/dist/bin/authserver

# Terminal 2
acore_source/env/dist/bin/worldserver
```

### Connect
Set `game_client/WOTLK/realmlist.wtf` to `SET realmlist "127.0.0.1"` (already done).
Launch `game_client/WOTLK/Wow.exe`.

---

## Project Layout

```
wow335a/
├── readme.md                   ← you are here
├── rebuild.sh                  ← build script
├── db_info.md                  ← database credentials
├── useful_links.md             ← external reference links
│
├── acore_source/               ← AzerothCore server (C++, CMake)
│   ├── src/                    ← core source code
│   ├── modules/mod-ale/        ← Eluna Lua scripting engine
│   ├── env/dist/               ← compiled output (bin/, etc/)
│   ├── var/build/obj/          ← CMake build cache
│   └── data/sql/               ← DB schemas and migrations
│
├── acore_data_files/           ← extracted client data for server
│   ├── dbc/                    ← 494 DBC files
│   ├── maps/                   ← map geometry
│   ├── vmaps/                  ← visual collision
│   └── mmaps/                  ← pathfinding
│
├── Keira3/                     ← DB editor (Electron + Angular)
│
├── AIO/                        ← server↔client Lua messaging system
│   ├── AIO_Server/AIO.lua      ← server-side (runs in mod-ale)
│   └── AIO_Client/AIO.lua      ← client-side (runs as addon)
│
├── game_client/WOTLK/          ← WoW 3.3.5a client
│   └── Interface/AddOns/       ← addons: AIO, DreamBar, DreamBar_Rankings, DreamBar_DailyQuests
│
├── raw_patches/                ← extracted MPQ data (base game assets)
├── raw_locale_patches/         ← extracted MPQ data (enUS locale)
│
└── docs/                       ← modding wiki → start at docs/README.md
```

---

## Databases

Connection: `mysql -u root -pkulka34` (local MySQL 8.4)

| Database | Purpose |
|----------|---------|
| `acore_world` | Game content — creatures, items, quests, spells, loot |
| `acore_characters` | Player data — characters, inventory, progress |
| `acore_auth` | Accounts, realm list, bans |

Custom project data goes in **`dreamforge_`-prefixed tables** inside `acore_world`.

---

## Tech Stack

| Layer | Tech |
|-------|------|
| Server emulator | AzerothCore v16.0.0-dev (C++17, clang 18) |
| Game version | WoW 3.3.5a, build 12340, WotLK |
| Server Lua engine | mod-ale (Eluna fork, Lua 5.2) |
| Addon communication | AIO (pure Lua, server↔client) |
| DB editor | Keira3 (Electron + Angular) |
| Database | MySQL 8.4 |

---

## Documentation

→ **[docs/README.md](docs/README.md)** — full modding wiki

Quick links:
- [Module System](docs/acore_development/module_system.md) — create a custom C++ module
- [Script Hooks](docs/acore_development/script_hooks.md) — all 49 hook types
- [Database Access](docs/acore_development/database_access.md) — C++ DB query API
- [DBC Access](docs/acore_development/dbc_access.md) — read DBC data from C++
- [Lua Scripting](docs/lua_scripting/README.md) — mod-ale / Eluna

---

## Config Files

After first build, edit these:

| File | What to set |
|------|-------------|
| `acore_source/env/dist/etc/worldserver.conf` | Already configured (DB creds + DataDir) |
| `acore_source/env/dist/etc/authserver.conf` | Already configured (DB creds) |

---

## Custom Addons

| Addon | Location | Purpose |
|-------|----------|---------|
| DreamBar | `game_client/WOTLK/Interface/AddOns/DreamBar/` | Custom UI bar |
| DreamBar_Rankings | `…/DreamBar_Rankings/` | Rankings display |
| DreamBar_DailyQuests | `…/DreamBar_DailyQuests/` | Daily quest tracker |
| AIO | `…/AIO/` + `AIO/AIO_Client/` | Server↔client messaging |
