# Dreamforge — Deep Knowledge Base Expansion Plan

## Goal

Transform the flat `docs/kb_*.md` files into a fully structured, folder-based knowledge system.
Each folder = one domain. Each file within = one focused aspect of that domain.
Coverage target: complete A-to-Z understanding — values, formulas, flags, DB schemas, C++ patterns,
Lua patterns, client internals, everything needed to mod WoW 3.3.5a from any angle.

---

## Phase 1: Folder Restructure

### New `docs/` layout

```
docs/
├── DREAMFORGE.md                      (keep as-is, top-level overview)
├── next_step.md                       (this file)
│
├── acore_development/                 ← EXPAND FROM kb_azerothcore_dev.md
│   ├── 00_overview.md
│   ├── 01_module_system.md
│   ├── 02_script_hooks.md
│   ├── 03_creature_system.md
│   ├── 04_player_system.md
│   ├── 05_spell_system.md
│   ├── 06_item_system.md
│   ├── 07_quest_system.md
│   ├── 08_gameobject_system.md
│   ├── 09_world_and_maps.md
│   ├── 10_smartai_system.md
│   ├── 11_database_schema.md
│   └── 12_cpp_patterns.md
│
├── client_modding/                    ← EXPAND FROM kb_file_formats.md + kb_wow_internals.md
│   ├── 00_overview.md
│   ├── 01_mpq_archives.md
│   ├── 02_dbc_files.md
│   ├── 03_adt_terrain.md
│   ├── 04_blp_textures.md
│   ├── 05_m2_models.md
│   ├── 06_taint_and_security.md
│   └── 07_api_unlocking.md
│
├── lua_scripting/                     ← EXPAND FROM kb_eluna_api.md + kb_lua_reference.md
│   ├── 00_overview.md
│   ├── 01_lua_52_language.md
│   ├── 02_eluna_core_api.md
│   ├── 03_event_system.md
│   ├── 04_database_queries.md
│   ├── 05_aio_messaging.md
│   └── 06_script_patterns.md
│
├── addon_development/                 ← EXPAND FROM kb_addon_api_335a.md
│   ├── 00_overview.md
│   ├── 01_frame_system.md
│   ├── 02_event_system.md
│   ├── 03_unit_api.md
│   ├── 04_spell_item_api.md
│   ├── 05_combat_log.md
│   ├── 06_communication.md
│   └── 07_ui_patterns.md
│
└── game_data/                         ← NEW — game mechanics and data structures
    ├── 00_overview.md
    ├── 01_classes_and_races.md
    ├── 02_spell_database.md
    ├── 03_item_database.md
    ├── 04_creature_database.md
    ├── 05_quest_database.md
    ├── 06_world_structure.md
    └── 07_combat_mechanics.md
```

---

## Phase 2: Topic Execution Order

Each topic is one session. Work through them in this order:

```
1. acore_development/      ← START HERE (next session)
2. lua_scripting/
3. addon_development/
4. client_modding/
5. game_data/
```

---

## Phase 3: acore_development — Agent Deployment Plan

This is what to execute at the START of the next session.
Deploy these 8 agents in waves of 2-3. Each writes its own file.

---

### Wave 1 (deploy first pair simultaneously)

#### Agent A — `acore_development/00_overview.md` + `01_module_system.md`
**Research targets:**
- AzerothCore overall architecture: worldserver, authserver, shared libs, how they connect
- How modules work: the `MODULE_LIST`, `CMakeLists.txt` structure, how hooks register
- The `ScriptMgr` singleton: how scripts are registered, the script loader pattern
- Build system: CMake superbuild, how to add a custom module
- AzerothCore startup sequence: what loads in what order (DB → scripts → world)
- The `WorldPacket` flow: client → server opcode handling
- ThreadPool, IoContext, async patterns used in AC
- Key source files to know: `src/server/scripts/`, `src/server/game/`, module `src/` layout
- Module best practices from AC wiki

**Sources to fetch (sequentially):**
- https://www.azerothcore.org/wiki/
- https://www.azerothcore.org/wiki/Create-a-Module
- https://www.azerothcore.org/wiki/Module-System
- https://github.com/azerothcore/azerothcore-wotlk/blob/master/src/game/Scripting/ScriptMgr.h (GitHub raw)

---

#### Agent B — `acore_development/03_creature_system.md`
**Research targets:**
- `creature_template` table: every column, data type, valid values, what it controls
- `npcflag` bitmask: all 32 bits, what each enables (vendor, trainer, gossip, etc.)
- `unit_flags`, `unit_flags2`, `dynamicflags`: complete bitmask tables
- `mechanic_immune_mask`: all mechanics with values
- CreatureAI class hierarchy: `BasicAI`, `EventAI`, `SmartAI`, `ReactAI`, custom
- `CreatureScript` vs `AllCreatureScript`: when to use each
- Creature movement: `MovementType`, waypoints, `creature_addon`
- How creature stats scale: level → HP/mana/damage formula
- Creature gossip: `gossip_menu`, `gossip_menu_option`, NPC_TEXT
- Creature phases, visibility conditions
- `creature` table (spawned instances) vs `creature_template`
- Vendor/trainer setup: `npc_vendor`, `npc_trainer` tables
- How to summon, despawn, respawn creatures via C++
- Boss mechanics: `BOSS_STATE_`, `instance_script`, encounter flags

**Sources:**
- AzerothCore source: search GitHub for `creature_template` schema comments
- https://www.azerothcore.org/wiki/creature_template
- https://www.azerothcore.org/wiki/creature

---

### Wave 2

#### Agent C — `acore_development/04_player_system.md`
**Research targets:**
- `characters` table: every column
- Player stats system: how base stats → derived stats (attack power, spell power, etc.)
- Class stat tables: what stats each class gets per level
- Race data: available races, racial abilities, model IDs, faction
- Talent system: `character_talent`, `talent_tab` DBC structure
- Dual spec: how it works in WotLK (3.3.5a has dual spec)
- `PlayerScript` hooks: complete list with parameters, return values, when they fire
- Player flags: `PLAYER_FLAGS_*` enum values
- How to modify player: SetLevel, ModifyMoney, LearnSpell, AddItem via C++
- Chat commands: `ChatHandler`, `CommandTable`, adding custom `.commands`
- Player phases: phase system in WotLK, how to phase players
- GroupScript, GuildScript hooks
- Honor system, arena points: tables and C++ API
- Achievement system: `achievement_criteria_data`, how to credit achievements

**Sources:**
- https://www.azerothcore.org/wiki/characters
- AzerothCore GitHub `Player.h` / `Player.cpp` key methods

---

#### Agent D — `acore_development/05_spell_system.md`
**Research targets:**
- `spell_template` table (if exists in AC world DB) — or SpellEntry DBC structure
- SpellEffect types: complete enum `SpellEffects` with values 0-255
- Aura types: `AuraType` enum, all SPELL_AURA_* values and what they do
- SpellScript hooks: `OnCast`, `OnHit`, `OnEffectHit`, `OnAuraApply`, `OnAuraTick` etc.
- SpellScriptLoader: how to register, the `SpellScript` vs `AuraScript` pattern
- Damage formula: how SP/AP → damage conversion works
- Spell school flags, dispel types, mechanic types — all enum values
- How to cast spells via C++: `CastSpell()`, `AddAura()`, `RemoveAurasDueToSpell()`
- Cooldown system: how to set/reset cooldowns
- Proc system: how SPELL_AURA_PROC_TRIGGER_SPELL works
- How WotLK spell inheritance (BasePoints, DieSides, BonusMultiplier) works
- `spell_proc_event` table in world DB
- `spell_linked_spell` table: chained spell triggers

---

### Wave 3

#### Agent E — `acore_development/06_item_system.md` + `07_quest_system.md`
**Research targets (items):**
- `item_template` table: every column, all flag bitmasks
- `ItemClass`, `ItemSubClass` enum values (complete tables)
- Stat types: `ITEM_MOD_*` enum — all 45+ stat types with IDs
- Loot system: `creature_loot_template`, `gameobject_loot_template`, `item_loot_template`
- Loot flags, `QuestRequired`, `GroupId`, reference entries
- `npc_vendor` table: all columns, `ExtendedCost` for badges
- Item quality colors and IDs (grey/white/green/blue/purple/orange/heirloom)
- How sockets work: socket colors, `GemProperties` DBC
- Random enchants: `item_enchantment_template`
- Disenchanting: `disenchant_loot_template`

**Research targets (quests):**
- `quest_template` table: every column
- Quest types, special flags, `QuestFlags` bitmask
- Objective types: kill, collect, visit, escort, event
- `QUEST_OBJECTIVE_TYPE_*` handling in C++
- `QuestScript` hooks: `OnQuestAccept`, `OnQuestReward`, `OnQuestComplete`
- Quest chains: `PrevQuestId`, `NextQuestId`, `ExclusiveGroup`
- Conditions system: `conditions` table, how to gate quests
- Quest reward types: XP formula, item rewards, spell rewards, faction rep

---

#### Agent F — `acore_development/10_smartai_system.md` (DEEP)
**Research targets:**
- Every SmartAI event type (all 86): what triggers it, what parameters it has
- Every SmartAI action type (all 139): what it does, all parameter fields
- Every SmartAI target type (all 29): how targeting works
- `smart_scripts` table: every column explained
- `source_type`: creature (0), gameobject (1), areatrigger (2), event (3) — what changes
- How `event_param1`–`event_param4` map for each event type
- How `action_param1`–`action_param6` map for each action type
- How `target_param1`–`target_param4` map for each target type
- `link` field: how event chaining works
- `event_phase_mask`: how to use phases in SmartAI
- `event_flags`: SMART_EVENT_FLAG_NOT_REPEATABLE etc.
- Practical SmartAI recipes: patrol path + talk, combat rotation, escort quest NPC
- Differences between SmartAI and EventAI
- How to debug SmartAI: `.debug smartai` command

---

#### Agent G — `acore_development/11_database_schema.md` (COMPLETE)
**Research targets:**
- Complete `acore_world` database: ALL table names and their purpose
- Complete `acore_characters` database: ALL tables
- Complete `acore_auth` database: ALL tables
- For each key table: column names, data types, foreign key relationships
- Focus on tables most used in modding:
  - world: creature_template, creature, gameobject_template, gameobject, item_template,
    quest_template, spell_template, smart_scripts, waypoint_data, creature_addon,
    gossip_menu, gossip_menu_option, npc_text, npc_vendor, npc_trainer,
    creature_loot_template, gameobject_loot_template, conditions, game_event,
    broadcast_text, areatrigger_scripts, disables
  - characters: characters, character_inventory, item_instance, character_aura,
    character_spell, character_talent, character_queststatus, character_reputation,
    character_achievement, character_skills
  - auth: account, account_access, realmlist, account_banned
- SQL conventions used in AC: update files, rev_ prefix
- How to safely modify the DB without breaking things

---

#### Agent H — `acore_development/08_gameobject_system.md` + `09_world_and_maps.md`
**Research targets (GameObjects):**
- `gameobject_template` table: all `data0`–`data23` fields mapped per GO type
- GO types: `GAMEOBJECT_TYPE_*` enum (all 33 types) — chest, door, button, trap, etc.
- `gameobject_loot_template`: how GO loot works
- `GameObjectScript` hooks: `OnGameObjectUse`, `OnGameObjectDamaged`, etc.
- Dynamic GOs: spawning, despawning, activating via C++
- GO state: GO_STATE_READY, GO_STATE_ACTIVE, GO_STATE_DESTROYED

**Research targets (World/Maps):**
- Map types: MAPTYPE_COMMON (open world), INSTANCE, RAID, BATTLEGROUND, ARENA
- `InstanceScript` / `BossAI`: how raid/dungeon scripting works
- `instance_template` table: script name binding
- `WorldScript` hooks: OnStartup, OnShutdown, OnUpdate, OnConfigLoad
- Area trigger system: `areatrigger_scripts`, `AreaTrigger` struct
- Transport system: boats/zeppelins, `transports` table
- Weather system: `game_weather`, `WeatherScript`
- Game events: `game_event` table, `GameEventScript`

---

## Phase 4: lua_scripting — Agent Plan (Session After acore_development)

Three agents:

**Agent A** — `lua_scripting/00_overview.md` + `05_aio_messaging.md`
- How mod-ale loads: file discovery, config options (mod-ale.conf)
- Script execution context: what globals are available
- Error handling in Eluna: how errors surface, logging
- AIO system deep dive:
  - Server-side AIO.lua structure
  - `AIO:AddHandlers()`, `AIO:Handle()` pattern
  - Client-side AIO addon structure
  - Message size limits, serialization
  - How to send tables, numbers, strings
  - Practical: sending DB data to client, receiving input from client

**Agent B** — `lua_scripting/03_event_system.md` (COMPLETE)
- Every RegisterXEvent function with complete parameter signatures
- Every event constant for every event type (73 player events, all creature events, etc.)
- When each event fires in the game lifecycle
- What parameters each event callback receives
- Return value behavior (some events use return values to cancel/modify)
- Thread safety: what you can/cannot do in callbacks

**Agent C** — `lua_scripting/06_script_patterns.md`
- Complete Eluna script templates for every use case
- Persistent data patterns: saving to DB, caching in Lua tables
- Timer patterns: CreateLuaEvent, repeat/cancel
- GUID safety pattern (detailed)
- Cross-script communication: shared Lua globals, require-like patterns
- Performance: what to avoid in hot paths (OnUpdate), batching DB queries
- Debugging: how to print/log from Eluna scripts

---

## Phase 5: addon_development — Agent Plan

Two agents:

**Agent A** — `addon_development/00_overview.md` + `07_ui_patterns.md`
- Deep addon architecture: how the Lua env is sandboxed
- WoW Lua restrictions: what APIs are blocked and why
- SavedVariables: how persistence works, ADDON_LOADED timing
- LibStub pattern: shared libraries across addons
- AceAddon / Ace3: how modular addon frameworks work (even if we write from scratch)
- Complete UI patterns: minimap button, options panel, movable frame

**Agent B** — `addon_development/05_combat_log.md` + `addon_development/06_communication.md`
- WotLK CLEU: complete event list, all prefix/suffix combos
- CLEU arguments in WotLK (no CombatLogGetCurrentEventInfo — direct varargs)
- How to build a damage meter from scratch
- `SendAddonMessage` on WotLK private servers: does `RegisterAddonMessagePrefix` exist?
- AIO integration: wiring client addon to AIO for server communication
- ChatThrottleLib: why it exists, how to use it

---

## Phase 6: client_modding — Agent Plan

Three agents:

**Agent A** — `client_modding/02_dbc_files.md` (DEEP)
- Fetch full DBC list from https://wowdev.wiki/Category:DBC_WotLK
- For each important DBC: exact struct layout, field names, how to read/edit
- Key DBCs for modding: Spell.dbc, Item.dbc, Map.dbc, AreaTable.dbc, ChrClasses.dbc,
  ChrRaces.dbc, CreatureDisplayInfo.dbc, ItemDisplayInfo.dbc, SkillLine.dbc,
  CharBaseInfo.dbc, SpellItemEnchantment.dbc, Talent.dbc, TalentTab.dbc,
  TotemCategory.dbc, SpellRange.dbc, SpellCastTimes.dbc, SpellDuration.dbc
- How DBC changes interact with server DB (which must match)
- Tools: WDBXEditor workflow, how to export to CSV and edit

**Agent B** — `client_modding/03_adt_terrain.md` + `client_modding/05_m2_models.md`
- ADT deep dive: every sub-chunk with field-level documentation
- How heightmaps work: the 9×9 + 8×8 vertex layout
- Texture blending: alpha map format, UV coordinates
- Noggit workflow: how to edit terrain, place objects, export patch
- M2 deep dive: bone system, animation IDs (all WotLK anim IDs), billboard types
- Skin file: submesh system, LOD, transparency rendering order
- How to replace existing model: M2 converter tools

**Agent C** — `client_modding/06_taint_and_security.md` + `client_modding/07_api_unlocking.md`
- Expand kb_wow_internals.md content into two focused files
- Taint file: complete list of protected/restricted functions, InCombatLockdown() details,
  all SecureHandler frame types with full attribute reference, hardware event list
- API unlocking file: step-by-step IDA Pro guide, all byte patches with hex values,
  complete memory offset table for build 12340, what each unlocked function enables

---

## Phase 7: game_data — Agent Plan (Final Phase)

Four agents covering all of `game_data/`:

**Agent A** — `game_data/01_classes_and_races.md`
- All 10 classes: stats, abilities, talent trees (structure not text)
- All 12 races: stats, racials, starting zones, faction
- How class+race combo determines starting stats
- `ChrClasses.dbc` and `ChrRaces.dbc` field breakdown
- `player_classlevelstats` and `player_levelstats` tables

**Agent B** — `game_data/02_spell_database.md`
- Spell.dbc: complete field layout (all ~230 fields of SpellEntry)
- SpellEffect: all effect types with formulas
- SpellAura: all aura types with mechanics
- How WotLK spell system chains: triggered spells, procs, dummy effects
- SpellCategory, SpellIcon, SpellRange, SpellCastTimes DBCs

**Agent C** — `game_data/06_world_structure.md`
- Map.dbc, AreaTable.dbc, WorldMapArea.dbc structure
- Coordinate systems: WoW X/Y/Z vs map tile coordinates
- Zone → subzone hierarchy, area IDs
- Phase system: how phase IDs work, what phased content exists in WotLK

**Agent D** — `game_data/07_combat_mechanics.md`
- Hit/miss/dodge/parry/block formulas for WotLK
- Armor mitigation formula
- Spell resistance formula
- Agro/threat system
- Diminishing returns system for CC
- Resilience formula
- How the server processes a combat tick

---

## Execution Notes for Next Session

1. **First action:** Create all folder structure and move existing kb_*.md files into correct folders (as starting points, not final docs)
2. **Deploy Wave 1 agents** (Agents A and B from acore_development) immediately
3. **While Wave 1 runs**, deploy Wave 2 (Agents C and D)
4. Continue until all 8 acore_development agents complete
5. Update MEMORY.md index after each phase completes

### File move mapping (existing → new location):
```
docs/kb_azerothcore_dev.md   → docs/acore_development/00_legacy_reference.md
docs/kb_file_formats.md      → docs/client_modding/00_legacy_reference.md
docs/kb_eluna_api.md         → docs/lua_scripting/00_legacy_reference.md
docs/kb_addon_api_335a.md    → docs/addon_development/00_legacy_reference.md
docs/kb_lua_reference.md     → docs/lua_scripting/01_lua_52_language.md
docs/kb_wow_internals.md     → docs/client_modding/00_legacy_internals.md
```

### Agent prompt template:
Each agent should:
1. Search AzerothCore GitHub source for relevant headers/tables
2. Fetch relevant AzerothCore wiki pages
3. Fetch relevant wowdev.wiki pages for game data topics
4. Synthesize everything into a structured guide with:
   - Overview section (what this system is, why it matters)
   - Deep technical reference (values, enums, table schemas)
   - Practical examples (real code/SQL showing how to use it)
   - Cross-references to related systems
5. Write to the target file — be comprehensive, this is the reference doc

---

## Priority Order Summary

```
Next session → acore_development/ (8 agents in 3 waves)
Then         → lua_scripting/     (3 agents)
Then         → addon_development/ (2 agents)
Then         → client_modding/    (3 agents)
Then         → game_data/         (4 agents)
```

Total: ~20 agents across ~5 sessions to build complete knowledge base.
