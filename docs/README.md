# Dreamforge Modding Wiki

Private WoW server modding reference for **AzerothCore / WotLK 3.3.5a (build 12340)**.

> **Local source index:** [`source_index.md`](source_index.md) — exact file paths for every topic, use before reading any doc.

---

## Quick Start

| Task | Where to go |
|------|-------------|
| Build the server | `cd /home/dr3am/projects/wow335a && ./rebuild.sh` |
| Rebuild after changes | `./rebuild.sh --build-only` |
| Create a custom module | [Module System](acore_development/module_system.md) |
| Add a script to an NPC | [Script Hooks](acore_development/script_hooks.md) → [Creatures](acore_development/creatures.md) |
| Write server-side Lua | [Eluna API](lua_scripting/eluna_api.md) |
| Edit a client addon | [Addon API](addon_development/addon_api.md) |
| Edit DBC files | [DBC Access](acore_development/dbc_access.md) |
| Query the database | [Database Access](acore_development/database_access.md) |

---

## Server-Side C++ (AzerothCore Modules)

### Architecture
| File | Description |
|------|-------------|
| [overview.md](acore_development/overview.md) | AC architecture, startup sequence, worldserver/authserver, three-DB layout |
| [module_system.md](acore_development/module_system.md) | ⭐ Create a module: CMakeLists template, loader naming rule, enabled-hooks vector, full example |
| [script_hooks.md](acore_development/script_hooks.md) | ⭐ All 49 script hook types — every virtual method with signatures |

### Game Systems
| File | Description |
|------|-------------|
| [players.md](acore_development/players.md) | characters table, stat system, PlayerScript hooks (212 hooks), commands, achievements |
| [creatures.md](acore_development/creatures.md) | creature_template (all columns + bitmasks), AI hierarchy, gossip, vendor, boss scripting |
| [spells.md](acore_development/spells.md) | SpellEffects enum, AuraTypes enum, school/dispel/mechanic flags, proc tables |
| [spell_scripting.md](acore_development/spell_scripting.md) | SpellScript + AuraScript — all hooks, C++ casting API, complete working example |
| [items.md](acore_development/items.md) | item_template (all columns), loot system, vendor/ExtendedCost, random enchants |
| [quests.md](acore_development/quests.md) | quest_template (all columns), QuestScript hooks, conditions system |
| [gameobjects.md](acore_development/gameobjects.md) | gameobject_template, all 33 GO types with data fields, GameObjectScript hooks |
| [world_maps.md](acore_development/world_maps.md) | Map types, InstanceScript/BossAI, WorldScript, area triggers, game events |
| [smartai.md](acore_development/smartai.md) | All SmartAI event/action/target types with parameters, phase system, SQL recipes |

### C++ Reference
| File | Description |
|------|-------------|
| [cpp_patterns.md](acore_development/cpp_patterns.md) | ⭐ ObjectMgr, ObjectAccessor, Unit/Player methods (verified from source), ScriptedAI, GUID safety, logging |
| [database_access.md](acore_development/database_access.md) | ⭐ WorldDatabase/CharacterDatabase API, prepared statements, transactions, async queries |
| [database_schema.md](acore_development/database_schema.md) | All tables in acore_auth / acore_characters / acore_world with column descriptions |
| [dbc_access.md](acore_development/dbc_access.md) | All 60 DBC stores, full SpellEntry field list, key structs, LookupEntry patterns |

---

## Lua Scripting (mod-ale / Eluna)

> **Status:** Reference files present. Full structured docs planned for next session.

| File | Description |
|------|-------------|
| [eluna_api.md](lua_scripting/eluna_api.md) | Eluna/ALE Lua API — all classes, methods, RegisterXEvent constants, patterns |
| [lua_language.md](lua_scripting/lua_language.md) | Lua 5.2 stdlib + awesome_wotlk / ConsolePortLK client mod patterns |

**Planned files:** overview, event_system, database_queries, aio_messaging, script_patterns

---

## Client Addons (WoW 3.3.5a)

> **Status:** Reference file present. Full structured docs planned.

| File | Description |
|------|-------------|
| [addon_api.md](addon_development/addon_api.md) | TOC/XML, frame system, events, unit/spell/item API for WoW 3.3.5a |

**Planned files:** frame_system, event_system, unit_api, spell_item_api, combat_log, communication, ui_patterns

---

## Client Modding

> **Status:** Reference files present. Full structured docs planned.

| File | Description |
|------|-------------|
| [file_formats.md](client_modding/file_formats.md) | MPQ archives, DBC, ADT terrain, BLP textures, M2 models — struct layouts and tools |
| [wow_internals.md](client_modding/wow_internals.md) | Taint system, protected API, IDA Pro binary unlocking, secure frames, build 12340 offsets |

**Planned files:** mpq_archives, dbc_files, adt_terrain, blp_textures, m2_models, taint_security, api_unlocking

---

## Game Data Reference

> **Status:** Planned for future session.

Topics: classes/races, spell database, item database, creature database, quest database, world structure, combat mechanics.

---

## Project Files

| File | Description |
|------|-------------|
| [DREAMFORGE.md](DREAMFORGE.md) | Project overview — goals, tech stack, custom addons |
| [source_index.md](source_index.md) | Local file paths for every topic (use when writing KB docs) |
| [next_step.md](next_step.md) | Session planning — what to build next |

---

## Key Facts (verified from local source)

- **Module loader function:** `mod-my-name` dir → `Addmod_my_nameScripts()` — wrong name = linker error
- **Enabled-hooks vector is mandatory** — unlisted hooks silently never fire
- **ModuleScript has no hooks** — use `WorldScript` for server lifecycle
- **`learnSpell()` is lowercase** on Player (not `LearnSpell`)
- **`DealDamage` / `DealHeal` are static methods**
- **Custom data goes in `dreamforge_` prefixed tables** inside `acore_world` (never modify AC tables)
- **DBC `HasRecord()` doesn't exist** — use `LookupEntry(id) != nullptr`
- **AllCreatureScript has no enabledHooks** — all hooks always active (performance cost)
