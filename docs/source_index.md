# Dreamforge — Local Source File Index

> **For KB agents:** Always read these local files instead of fetching from GitHub.
> Base path: `/home/dr3am/projects/wow335a/`

---

## AzerothCore C++ Source
Base: `acore_source/src/`

### Core Definitions (read these first for any topic)
| File | Contains |
|------|----------|
| `src/server/shared/SharedDefines.h` | SpellEffects enum, AuraType enum, all game-wide constants, unit flags, item classes, mechanic types, dispel types |
| `src/server/game/Entities/Unit/UnitDefines.h` | Unit state, movement, combat flags |
| `src/server/shared/DataStores/DBCStructure.h` | All DBC struct layouts (SpellEntry, ItemEntry, Map, etc.) |

### Script Hooks — Each script type has its own header
| File | Script Type |
|------|-------------|
| `src/server/game/Scripting/ScriptMgr.h` | Master include, all RegisterXScript macros |
| `src/server/game/Scripting/ScriptDefines/PlayerScript.h` | All PlayerScript virtual hooks |
| `src/server/game/Scripting/ScriptDefines/CreatureScript.h` | CreatureScript hooks |
| `src/server/game/Scripting/ScriptDefines/AllCreatureScript.h` | AllCreatureScript hooks |
| `src/server/game/Scripting/ScriptDefines/SpellScriptLoader.h` | SpellScript/AuraScript registration |
| `src/server/game/Scripting/ScriptDefines/GameObjectScript.h` | GameObjectScript hooks |
| `src/server/game/Scripting/ScriptDefines/InstanceMapScript.h` | InstanceMapScript hooks |
| `src/server/game/Scripting/ScriptDefines/WorldScript.h` | WorldScript hooks |
| `src/server/game/Scripting/ScriptDefines/AreaTriggerScript.h` | AreaTriggerScript hooks |
| `src/server/game/Scripting/ScriptDefines/GroupScript.h` | GroupScript hooks |
| `src/server/game/Scripting/ScriptDefines/GuildScript.h` | GuildScript hooks |
| `src/server/game/Scripting/ScriptDefines/CommandScript.h` | CommandScript / ChatHandler |
| `src/server/game/Scripting/ScriptDefines/GameEventScript.h` | GameEventScript hooks |
| `src/server/game/Scripting/ScriptDefines/TransportScript.h` | TransportScript hooks |
| `src/server/game/Scripting/ScriptDefines/WeatherScript.h` | WeatherScript hooks |
| `src/server/game/Scripting/ScriptDefines/AllSpellScript.h` | AllSpellScript hooks |
| `src/server/game/Scripting/ScriptDefines/UnitScript.h` | UnitScript hooks |
| `src/server/game/Scripting/ScriptDefines/ItemScript.h` | ItemScript hooks |
| `src/server/game/Scripting/ScriptDefines/LootScript.h` | LootScript hooks |
| `src/server/game/Scripting/ScriptMgrMacros.h` | RegisterSpellScript, RegisterCreatureAI macros |

### Entity Headers
| File | Contains |
|------|----------|
| `src/server/game/Entities/Unit/Unit.h` | Unit class: all CastSpell, AddAura, HasAura, GetAura, damage methods |
| `src/server/game/Entities/Creature/Creature.h` | Creature class, creature-specific methods |
| `src/server/game/Entities/Creature/CreatureData.h` | CreatureTemplate struct (maps to creature_template table) |
| `src/server/game/Entities/Player/Player.h` | Player class: all player manipulation methods |
| `src/server/game/Entities/GameObject/GameObject.h` | GO class and methods |
| `src/server/game/Entities/GameObject/GameObjectData.h` | GameObjectTemplate struct (maps to gameobject_template) |
| `src/server/game/Entities/Item/Item.h` | Item class |
| `src/server/game/Entities/Item/ItemTemplate.h` | ItemTemplate struct (maps to item_template), all ITEM_MOD_* enums |
| `src/server/game/Entities/Object/ObjectGuid.h` | GUID types |

### Spell System
| File | Contains |
|------|----------|
| `src/server/game/Spells/SpellScript.h` | SpellScript and AuraScript base classes with ALL hook methods |
| `src/server/game/Spells/SpellInfo.h` | SpellInfo class (runtime spell data), SpellEffectInfo |
| `src/server/game/Spells/SpellDefines.h` | TriggerCastFlags, SpellCastResult, spell state enums |
| `src/server/game/Spells/SpellMgr.h` | SpellMgr class, ProcFlags, ProcFlagsExLegacy |
| `src/server/game/Spells/Auras/SpellAuraDefines.h` | AuraType enum (all SPELL_AURA_* values), AuraEffectHandleModes |
| `src/server/game/Spells/Auras/SpellAuraEffects.h` | AuraEffect class: GetAmount, GetBase, etc. |
| `src/server/game/Spells/Auras/SpellAuras.h` | Aura class: SetStackAmount, SetDuration, Remove |

### AI System
| File | Contains |
|------|----------|
| `src/server/game/AI/CreatureAI.h` | CreatureAI base class, all virtual methods |
| `src/server/game/AI/CoreAI/UnitAI.h` | UnitAI root class |
| `src/server/game/AI/ScriptedAI/ScriptedCreature.h` | ScriptedAI, BossAI, SummonList, TaskScheduler integration |
| `src/server/game/AI/SmartScripts/SmartScriptMgr.h` | ALL SmartAI event/action/target enums and parameter structs |
| `src/server/game/AI/SmartScripts/SmartAI.h` | SmartAI class |
| `src/server/game/Instances/InstanceScript.h` | InstanceScript class, all boss state methods |

### World / Maps
| File | Contains |
|------|----------|
| `src/server/game/Maps/Map.h` | Map class |
| `src/server/game/Quests/QuestDef.h` | Quest struct, QuestFlags enum |
| `src/server/game/Chat/Chat.h` | ChatHandler class, command registration |

---

## mod-ale (Eluna Lua Engine) Source
Base: `acore_source/modules/mod-ale/src/LuaEngine/`

### Core
| File | Contains |
|------|----------|
| `Hooks.h` | ALL RegisterXEvent function declarations and event ID enums |
| `ALEEventMgr.h` | Event manager internals |
| `ALEConfig.h` | Module configuration options |
| `GlobalMethods.h` (in methods/) | All global Lua functions (CreateLuaEvent, GetPlayer, etc.) |

### Lua Method Files (each = one class's Lua API)
| File | Lua Class |
|------|-----------|
| `methods/PlayerMethods.h` | Player methods |
| `methods/UnitMethods.h` | Unit methods |
| `methods/CreatureMethods.h` | Creature methods |
| `methods/GameObjectMethods.h` | GameObject methods |
| `methods/ItemMethods.h` | Item methods |
| `methods/SpellMethods.h` | Spell methods |
| `methods/SpellInfoMethods.h` | SpellInfo methods |
| `methods/AuraMethods.h` | Aura methods |
| `methods/MapMethods.h` | Map methods |
| `methods/GroupMethods.h` | Group methods |
| `methods/GuildMethods.h` | Guild methods |
| `methods/ChatHandlerMethods.h` | ChatHandler methods |
| `methods/ALEQueryMethods.h` | Database query methods (QueryResult, PreparedStatement) |
| `methods/WorldObjectMethods.h` | WorldObject base methods |
| `methods/ObjectMethods.h` | Object base methods |
| `methods/QuestMethods.h` | Quest methods |

---

## Keira3 — DB Entity Models (TypeScript = accurate schema source)
Base: `Keira3/libs/shared/acore-world-model/src/`

### Entity Types (one file = one DB table, exact column names)
| File | DB Table |
|------|----------|
| `entities/creature-template.type.ts` | creature_template |
| `entities/creature-template-model.type.ts` | creature_template_model (display IDs) |
| `entities/creature-template-addon.type.ts` | creature_template_addon |
| `entities/creature-template-movement.type.ts` | creature_template_movement |
| `entities/creature-template-resistance.type.ts` | creature_template_resistance |
| `entities/creature-template-spell.type.ts` | creature_template_spell |
| `entities/creature-spawn.type.ts` | creature (spawns) |
| `entities/creature-spawn-addon.type.ts` | creature_addon |
| `entities/creature-equip-template.type.ts` | creature_equip_template |
| `entities/creature-formations.type.ts` | creature_formations |
| `entities/creature-loot-template.type.ts` | creature_loot_template |
| `entities/creature-questitem.type.ts` | creature_questitem |
| `entities/creature-queststarter.type.ts` | creature_queststarter |
| `entities/creature-questender.type.ts` | creature_questender |
| `entities/creature-onkill-reputation.type.ts` | creature_onkill_reputation |
| `entities/creature-text.type.ts` | creature_text |
| `entities/creature-default-trainer.type.ts` | creature_default_trainer |
| `entities/gameobject-template.type.ts` | gameobject_template |
| `entities/gameobject-template-addon.type.ts` | gameobject_template_addon |
| `entities/gameobject-spawn.type.ts` | gameobject (spawns) |
| `entities/gameobject-spawn-addon.type.ts` | gameobject_addon |
| `entities/gameobject-loot-template.type.ts` | gameobject_loot_template |
| `entities/gameobject-questitem.type.ts` | gameobject_questitem |
| `entities/gameobject-queststarter.type.ts` | gameobject_queststarter |
| `entities/gameobject-questender.type.ts` | gameobject_questender |
| `entities/item-template.type.ts` | item_template |
| `entities/item-loot-template.type.ts` | item_loot_template |
| `entities/item-enchantment-template.type.ts` | item_enchantment_template |
| `entities/item-extended-cost.type.ts` | item_extended_cost |
| `entities/quest-template.type.ts` | quest_template |
| `entities/quest-template-addon.type.ts` | quest_template_addon |
| `entities/quest-offer-reward.type.ts` | quest_offer_reward |
| `entities/quest-request-items.type.ts` | quest_request_items |
| `entities/smart-scripts.type.ts` | smart_scripts |
| `entities/spell.type.ts` | spell_dbc / spell overrides |
| `entities/spell-dbc.type.ts` | spell_dbc |
| `entities/npc-vendor.type.ts` | npc_vendor |
| `entities/trainer.type.ts` | trainer |
| `entities/trainer-spell.type.ts` | trainer_spell |
| `entities/gossip-menu.type.ts` | gossip_menu |
| `entities/gossip-menu-option.type.ts` | gossip_menu_option |
| `entities/npc-text.type.ts` | npc_text |
| `entities/broadcast-text.type.ts` | broadcast_text |
| `entities/conditions.type.ts` | conditions |
| `entities/loot-template.type.ts` | loot_template (base) |
| `entities/reference-loot-template.type.ts` | reference_loot_template |
| `entities/disenchant-loot-template.type.ts` | disenchant_loot_template |
| `entities/fishing-loot-template.type.ts` | fishing_loot_template |
| `entities/pickpocketing-loot-template.type.ts` | pickpocketing_loot_template |
| `entities/skinning-loot-template.type.ts` | skinning_loot_template |
| `entities/milling-loot-template.type.ts` | milling_loot_template |
| `entities/prospecting-loot-template.type.ts` | prospecting_loot_template |
| `entities/spell-loot-template.type.ts` | spell_loot_template |
| `entities/mail-loot-template.type.ts` | mail_loot_template |
| `entities/page-text.type.ts` | page_text |
| `entities/area.type.ts` | areas/zones |
| `entities/map.type.ts` | map data |
| `entities/game-tele.type.ts` | game_tele |
| `entities/faction.type.ts` | faction |

### Flags / Bitmasks (each = one bitmask constant file)
| File | Bitmask |
|------|---------|
| `flags/npc-flags.ts` | npcflag values |
| `flags/flags-extra.ts` | flags_extra values |
| `flags/dynamic-flags.ts` | dynamicflags values |
| `flags/mechanic-immune-mask.ts` | mechanic_immune_mask values |
| `flags/item-flags.ts` | item_template Flags |
| `flags/item-flags-extra.ts` | item_template FlagsExtra |
| `flags/item-flags-custom.ts` | custom item flags |
| `flags/quest-flags.ts` | quest QuestFlags |
| `flags/spawn-mask.ts` | spawnMask values |
| `flags/phase-mask.ts` | phaseMask values |
| `flags/loot-mode.ts` | lootMode values |
| `flags/allowable-classes.ts` | class bitmask |
| `flags/allowable-races.ts` | race bitmask |
| `flags/smart-event-flags.ts` | SmartAI event_flags |
| `flags/gameobject-flags.ts` | gameobject flags |
| `flags/event-phase-mask.ts` | SmartAI event_phase_mask |
| `flags/bag-family.ts` | item BagFamily |
| `flags/socket-color.ts` | gem socket colors |
| `flags/creature-type-flags.ts` | creature type_flags |

---

## Live Databases (read with MySQL)
Connection: `mysql -u root -pkulka34`

| Database | Purpose |
|----------|---------|
| `acore_world` | All game content (creatures, items, quests, spells, loot) |
| `acore_characters` | Player data, inventories, progress |
| `acore_auth` | Accounts, realms, bans |

### Useful MySQL queries for KB research
```sql
-- Get exact creature_template columns (ground truth)
DESCRIBE acore_world.creature_template;

-- Get exact item_template columns
DESCRIBE acore_world.item_template;

-- List all tables in world DB
SHOW TABLES FROM acore_world;

-- View a specific table structure with types
SHOW CREATE TABLE acore_world.smart_scripts\G

-- Query live data for examples
SELECT entry, name, npcflag, AIName, ScriptName FROM acore_world.creature_template LIMIT 10;
```

---

## Data Files
| Path | Contains |
|------|----------|
| `acore_data_files/dbc/` | All WotLK DBC files (Spell.dbc, Item.dbc, Map.dbc, etc.) |
| `acore_data_files/maps/` | Extracted map geometry |
| `acore_data_files/vmaps/` | Visual collision maps |
| `acore_data_files/mmaps/` | Movement/pathfinding maps |

---

## Key Rules for KB Agents
1. **For DB schemas** → read Keira3 TypeScript types AND run `DESCRIBE table` on live DB
2. **For C++ API** → read local headers, NOT GitHub URLs
3. **For Lua/Eluna API** → read `mod-ale/src/LuaEngine/methods/*.h` and `Hooks.h`
4. **For SmartAI enums** → read `SmartScriptMgr.h` locally
5. **For flag/bitmask values** → read Keira3 `flags/*.ts` files
