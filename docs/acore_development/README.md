# AzerothCore C++ Development

Server-side modding reference built from **local source files** — not online docs.
All C++ signatures, DB schemas, and enum values verified against the installed AC version.

← [Back to Wiki Home](../README.md)

---

## Start Here

| If you want to... | Read this |
|-------------------|-----------|
| Create a new module | [module_system.md](module_system.md) |
| Know what hooks are available | [script_hooks.md](script_hooks.md) |
| Understand the AC architecture | [overview.md](overview.md) |
| Write C++ that manipulates players/creatures | [cpp_patterns.md](cpp_patterns.md) |
| Query the database from C++ | [database_access.md](database_access.md) |
| Read DBC data (spells, areas, maps) | [dbc_access.md](dbc_access.md) |

---

## All Files

### Architecture & Module Dev
| File | What's inside |
|------|---------------|
| [overview.md](overview.md) | AC architecture, startup order, worldserver/authserver, three DBs, packet flow |
| [module_system.md](module_system.md) | CMakeLists.txt template, loader naming rule, enabled-hooks vector (critical!), config system, complete mod-dreamforge example |
| [script_hooks.md](script_hooks.md) | All 49 script types — every virtual method with signature, registration macro, when it fires |

### Game Systems
| File | What's inside |
|------|---------------|
| [players.md](players.md) | characters table schema, stat derivation, PlayerScript (212 hooks), GM commands, achievements, honor |
| [creatures.md](creatures.md) | creature_template (all 54 columns), 7 bitmask tables, AI hierarchy, gossip, vendor, trainer, boss scripting |
| [spells.md](spells.md) | SpellEffects (165 values), AuraTypes (80+ values), spell school/dispel/mechanic/proc flags, spell_linked_spell |
| [spell_scripting.md](spell_scripting.md) | SpellScript + AuraScript hooks with Fn macros, C++ casting API, CastSpell overloads, AddAura, cooldowns |
| [items.md](items.md) | item_template (all columns), ItemClass/SubClass enums, ITEM_MOD_* stat types, loot templates, ExtendedCost |
| [quests.md](quests.md) | quest_template (all columns), QuestFlags bitmask, QuestScript hooks, conditions table |
| [gameobjects.md](gameobjects.md) | gameobject_template, all 33 GO types with data0-23 field mapping, GameObjectScript hooks, GO states |
| [world_maps.md](world_maps.md) | Map types + all WotLK map IDs, InstanceScript/BossAI, WorldScript hooks, area triggers, game events |
| [smartai.md](smartai.md) | All SMART_EVENT (86+), SMART_ACTION (139+), SMART_TARGET (29+) types with all parameter meanings, SQL recipes |

### C++ Reference
| File | What's inside |
|------|---------------|
| [cpp_patterns.md](cpp_patterns.md) | sObjectMgr, ObjectAccessor, Unit/Player methods (source-verified), ScriptedAI/BossAI/TaskScheduler, GUID safety pattern, logging |
| [database_access.md](database_access.md) | WorldDatabase/CharacterDatabase API, Query/Execute/Transaction patterns, Field::Get<T>(), prepared statements, async queries |
| [database_schema.md](database_schema.md) | All tables in acore_auth / acore_characters / acore_world with column descriptions |
| [dbc_access.md](dbc_access.md) | All 60 DBCStorage<T> stores, full SpellEntry field list, key structs from DBCStructure.h, LookupEntry patterns |

---

## Critical Facts

```
// Loader function name derived from directory name:
// modules/mod-dreamforge/ → Addmod_dreamforgeScripts()

// Enabled-hooks vector is NOT optional:
class MyScript : public PlayerScript {
public:
    MyScript() : PlayerScript("MyScript", {
        PLAYERHOOK_ON_LOGIN,     // ← must list every hook you implement
        PLAYERHOOK_ON_LOGOUT,
    }) {}
    void OnPlayerLogin(Player* player, bool firstLogin) override { ... }
};

// learnSpell is lowercase:
player->learnSpell(spellId, false);

// DealDamage is static:
Unit::DealDamage(attacker, victim, damage, nullptr, DIRECT_DAMAGE, SPELL_SCHOOL_MASK_NORMAL);

// Custom tables: dreamforge_ prefix in acore_world
// DBC: HasRecord() doesn't exist, use LookupEntry(id) != nullptr
```
