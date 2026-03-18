# AzerothCore: Module System & ScriptMgr Hooks

## Overview

AzerothCore's module system lets you extend the server without patching core source files. A module is a directory dropped into `modules/` that the CMake build system auto-discovers. It compiles alongside (or separately from) the core and registers C++ hook callbacks through the `ScriptMgr` singleton. The result: your code gets called at defined points in the server's execution with no merge conflicts against upstream AC.

Three hook types exist:
- **Script hooks** — C++ virtual method overrides called at game events (player login, creature death, spell cast, etc.)
- **CMake hooks** — your module's `CMakeLists.txt` runs during the configure step; installs conf files, links extra libraries
- **Bash hooks** — `include.sh` in the module root runs during dashboard install/uninstall; typically applies SQL

This document covers everything needed to write production modules: full script class reference, file layouts, registration patterns, SQL migration patterns, and pitfalls.

---

## How the Module System Works

### Module Discovery
During CMake configure, `modules/CMakeLists.txt` calls `CU_SUBDIRLIST()` to enumerate every subdirectory of `modules/`. For each one not in `DISABLED_AC_MODULES`, it calls `add_subdirectory()`. Your module's `CMakeLists.txt` is then included in the build.

### Script Registration Flow
```
cmake configure
    → modules/CMakeLists.txt discovers your module
    → calls ConfigureScriptLoader() which generates ModulesScriptLoader.cpp
          containing:  void AddMy_moduleScripts();
                       called from AddModulesScripts()

compile time
    → your src/*.cpp compiled into modules static lib (or per-module .so)

runtime (worldserver startup)
    → ScriptMgr::SetModulesLoader(AddModulesScripts) registered
    → During World init: AddModulesScripts() called
        → AddMy_moduleScripts() called  (your _loader.cpp)
            → AddMyPlayerScripts() called
                → new MyPlayer()  ← ScriptObject constructor calls ScriptMgr::AddScript()
                    → stored in ScriptRegistry<PlayerScript>::ScriptPointerList
```

### ScriptRegistry Template
Scripts are stored in a per-type registry:
```cpp
// Conceptually (simplified from ScriptMgr.h):
template<class TScript>
class ScriptRegistry {
public:
    static std::map<uint32, TScript*> ScriptPointerList;
    static void AddScript(TScript* script);
    static TScript* GetScriptById(uint32 id);
    static void InitEnabledHooksIfNeeded(uint32 hookCount);
};
```

`AddScript()` assigns an incrementing integer ID to each script, checks for duplicate names, and validates `IsDatabaseBound()` constraints (database-bound scripts must have a matching name in a DB table). Scripts are never deleted until `ScriptMgr::Unload()` at shutdown.

### Hook Invocation
ScriptMgr has one method per hook event. Internally it uses the macros from `ScriptMgrMacros.h`:

```cpp
// CALL_ENABLED_HOOKS — calls a void hook on every registered script of that type
// CALL_ENABLED_BOOLEAN_HOOKS — returns false if any hook returns true (blocking hooks)
// CALL_ENABLED_BOOLEAN_HOOKS_WITH_DEFAULT_FALSE — returns true if any hook returns true
```

Example: `ScriptMgr::OnPlayerLogin(Player* player)` iterates `ScriptRegistry<PlayerScript>::ScriptPointerList` and calls `script->OnPlayerLogin(player)` on each entry that has this hook enabled.

### Hook Priority / Ordering
There is **no priority system** in AzerothCore's ScriptMgr. Scripts execute in registration order (order `new MyScript()` is called). For modules, that is the order their names appear in the generated `ModulesScriptLoader.cpp`, which reflects filesystem enumeration order.

**Consequence**: if two scripts both override `OnPlayerLogin`, both run. If two scripts both override a boolean hook (like `CanPacketReceive`), the first one to return `true` wins due to the `CALL_ENABLED_BOOLEAN_HOOKS` macro short-circuit behavior. Design your modules to be order-independent.

For `IsDatabaseBound()` scripts (creature, GO, spell, item scripts), only ONE script can be bound to a given script name. The DB column `creature_template.ScriptName` or equivalent must match exactly one registered script name.

---

## Creating a New Module: Step by Step

### Method 1: Automated (Recommended)
From the repo root:
```bash
cd modules/
bash create_module.sh
# Follow prompts: enter module name like "mod-my-feature"
```
This creates the full skeleton, sets up git with clean history, and configures local git settings.

### Method 2: Manual Skeleton

#### Step 1: Create the directory
```
modules/mod-my-feature/
```
**Naming convention**: use lowercase kebab-case (`mod-my-feature`). Hyphens become underscores in C++ identifiers.

#### Step 2: CMakeLists.txt
```cmake
# modules/mod-my-feature/CMakeLists.txt

# Collect all source files in src/
CollectSourceFiles(
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    PRIVATE_SOURCES
)

# Define the script module target
if (PRIVATE_SOURCES)
    AC_ADD_SCRIPT_LOADER("mod-my-feature" "${PRIVATE_SOURCES}")
endif()

# Optional: install config file
if (UNIX OR WIN32)
    install(FILES conf/mod_my_feature.conf.dist DESTINATION ${CONF_INSTALL_DIR})
endif()
```

If you need extra CMake logic (external libs, custom flags), put it in `mod_my_feature.cmake` in the module root — it is auto-included by `modules/CMakeLists.txt` around line 290.

#### Step 3: The Loader File
Every module needs exactly one loader file. Its job is to forward-declare every `AddXxxScripts()` function and call them all from the module entry point.
```cpp
// modules/mod-my-feature/src/mod_my_feature_loader.cpp

// Forward declarations — one per script file
void AddMyPlayerScripts();
void AddMyCreatureScripts();

// Entry point — name derived from module folder: replace '-' with '_', prefix "Add", suffix "Scripts"
void Addmod_my_featureScripts()
{
    AddMyPlayerScripts();
    AddMyCreatureScripts();
}
```

**Naming rule**: folder `mod-my-feature` → function `Addmod_my_featureScripts`. Every `-` becomes `_`, no capital letters changed.

#### Step 4: Script Files
```cpp
// modules/mod-my-feature/src/MyPlayerHooks.cpp
#include "ScriptMgr.h"
#include "Player.h"
#include "Config.h"
#include "Chat.h"

class MyFeaturePlayerScript : public PlayerScript
{
public:
    MyFeaturePlayerScript() : PlayerScript("MyFeaturePlayerScript") { }

    void OnPlayerLogin(Player* player) override
    {
        if (!sConfigMgr->GetOption<bool>("MyFeature.Enable", false))
            return;

        ChatHandler(player->GetSession()).PSendSysMessage("Welcome, %s!", player->GetName().c_str());
    }

    void OnPlayerLevelChanged(Player* player, uint8 oldLevel) override
    {
        // oldLevel is the level before the change; player->GetLevel() is new level
    }
};

void AddMyPlayerScripts()
{
    new MyFeaturePlayerScript();
}
```

#### Step 5: Config File
```ini
# modules/mod-my-feature/conf/mod_my_feature.conf.dist
[worldserver]

###################################################################################################
#  MY FEATURE MODULE
###################################################################################################

# Enable/disable the module
# Default: 0 (disabled)
MyFeature.Enable = 0

# XP multiplier
# Default: 1
MyFeature.XPRate = 1
```

The `.conf.dist` file is the template. Players copy it to `.conf` and edit it. The CMakeLists.txt installs it alongside `worldserver.conf.dist`.

#### Step 6: SQL Files
```
modules/mod-my-feature/sql/
├── base/
│   ├── auth/          ← Tables for acore_auth
│   ├── characters/    ← Tables for acore_characters
│   └── world/         ← Tables for acore_world
└── updates/
    ├── auth/          ← Incremental updates (named 2024_01_01_00.sql, etc.)
    ├── characters/
    └── world/
```

Base SQL runs once on fresh install. Updates run once each via the DB assembler tracking table. Example base file:
```sql
-- sql/base/characters/my_feature_data.sql
CREATE TABLE IF NOT EXISTS `my_feature_data` (
    `guid`      INT UNSIGNED NOT NULL,
    `points`    INT UNSIGNED NOT NULL DEFAULT 0,
    `updated`   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

The AC database assembler tracks which update files have been applied in `acore_world.updates` (or equivalent). Name update files with a timestamp prefix to ensure ordering: `2024_03_15_01_add_points_column.sql`.

#### Step 7: include.sh (Bash Hook — Optional)
```bash
# modules/mod-my-feature/include.sh
# Called by the AzerothCore dashboard during module install/uninstall
# Use to apply base SQL or do other setup
```

The dashboard calls this during `./acore.sh install` type workflows.

---

## Full Module Folder Layout

```
modules/mod-my-feature/
├── CMakeLists.txt                  ← Required: cmake build definition
├── mod_my_feature.cmake            ← Optional: extra cmake logic, auto-included
├── include.sh                      ← Optional: bash hook for dashboard
│
├── conf/
│   └── mod_my_feature.conf.dist   ← Optional: config template
│
├── data/                           ← Optional: DBC patches, BLP files, LUA files
│
├── src/
│   ├── mod_my_feature_loader.cpp  ← Required: module entry point (AddXxxScripts)
│   ├── MyPlayerHooks.cpp
│   ├── MyCreatureScripts.cpp
│   └── ...
│
└── sql/
    ├── base/
    │   ├── auth/
    │   ├── characters/
    │   └── world/
    └── updates/
        ├── auth/
        ├── characters/
        └── world/
```

---

## ScriptMgr: Complete Hook Reference

`ScriptMgr` is a singleton (`sScriptMgr`). You never call it directly from your scripts — instead you subclass one of the script base classes and override virtual methods. `ScriptMgr` calls into your overrides.

All script base classes inherit from `ScriptObject`. The constructor takes the script's name string, which must be unique across all registered scripts of that type.

---

### ScriptObject (Base)

```cpp
class ScriptObject {
public:
    [[nodiscard]] virtual bool IsDatabaseBound() const { return false; }
    [[nodiscard]] virtual bool isAfterLoadScript() const { return false; }
    virtual void checkValidity() { }
    [[nodiscard]] const std::string& GetName() const;
};
```

`IsDatabaseBound() = true` means the script name must appear in a database table (e.g., `creature_template.ScriptName`). Only one database-bound script per name can be registered. Non-database-bound scripts (like `PlayerScript`) fire for all entities of that type.

`UpdatableScript<T>` adds: `virtual void OnUpdate(T* obj, uint32 diff)`

`MapScript<TMap>` adds map lifecycle: `OnCreate`, `OnDestroy`, `OnLoadGridMap`, `OnUnloadGridMap`, `OnPlayerEnter`, `OnPlayerLeave`, `OnUpdate`.

---

### ServerScript

Network lifecycle. `IsDatabaseBound() = false`.

```cpp
class ServerScript : public ScriptObject {
public:
    virtual void OnNetworkStart() { }
    virtual void OnNetworkStop() { }
    virtual void OnSocketOpen(std::shared_ptr<WorldSocket> const& socket) { }
    // Note: OnSocketClose is in the spec; check current header for exact signature
    [[nodiscard]] virtual bool CanPacketSend(WorldSession* session, WorldPacket const& packet) { return true; }
    [[nodiscard]] virtual bool CanPacketReceive(WorldSession* session, WorldPacket const& packet) { return true; }
};
```

---

### WorldScript

Server-wide lifecycle. `IsDatabaseBound() = false`.

```cpp
class WorldScript : public ScriptObject {
public:
    virtual void OnOpenStateChange(bool open) { }
    virtual void OnBeforeConfigLoad(bool reload) { }
    virtual void OnAfterConfigLoad(bool reload) { }
    virtual void OnLoadCustomDatabaseTable() { }
    virtual void OnMotdChange(std::string& newMotd, LocaleConstant& locale) { }
    virtual void OnShutdownInitiate(ShutdownExitCode code, ShutdownMask mask) { }
    virtual void OnShutdownCancel() { }
    virtual void OnUpdate(uint32 diff) { }
    virtual void OnStartup() { }
    virtual void OnShutdown() { }
    virtual void OnAfterUnloadAllMaps() { }
    virtual void OnBeforeFinalizePlayerWorldSession(uint32& cacheVersion) { }
    virtual void OnBeforeWorldInitialized() { }
};
```

`OnLoadCustomDatabaseTable()` is the correct hook to load data from your custom DB tables at startup — fires during the DB load phase of `SetInitialWorldSettings()`.

---

### DatabaseScript

```cpp
class DatabaseScript : public ScriptObject {
public:
    [[nodiscard]] bool IsDatabaseBound() const override { return false; }
    virtual void OnAfterDatabasesLoaded(uint32 updateFlags) { }
    virtual void OnAfterDatabaseLoadCreatureTemplates(std::vector<CreatureTemplate*> creatureTemplates) { }
};
```

---

### PlayerScript

The largest hook class (150+ methods). `IsDatabaseBound() = false` — all overrides fire for every player. Subclass selectively; only override what you need.

```cpp
class PlayerScript : public ScriptObject {
public:
    // Lifecycle
    virtual void OnPlayerLogin(Player* player) { }
    virtual void OnPlayerLogout(Player* player) { }
    virtual void OnPlayerBeforeLogout(Player* player) { }
    virtual void OnPlayerCreate(Player* player) { }
    virtual void OnPlayerDelete(Player* player, uint32 accountId) { }
    virtual void OnPlayerFailedDelete(ObjectGuid guid, uint32 accountId) { }
    virtual void OnPlayerLoadFromDB(Player* player) { }
    virtual void OnPlayerSave(Player* player) { }
    virtual void OnPlayerFirstLogin(Player* player) { }

    // Combat & Death
    virtual void OnPlayerJustDied(Player* player) { }
    virtual void OnPlayerReleasedGhost(Player* player) { }
    virtual void OnPlayerEnterCombat(Player* player, Unit* enemy) { }
    virtual void OnPlayerLeaveCombat(Player* player) { }
    virtual void OnPlayerPVPKill(Player* killer, Player* killed) { }
    virtual void OnPlayerPVPFlagChange(Player* player, bool state) { }
    virtual void OnPlayerCreatureKill(Player* player, Creature* killed) { }
    virtual void OnPlayerKilledByCreature(Creature* killer, Player* killed) { }

    // Progression
    virtual void OnPlayerLevelChanged(Player* player, uint8 oldLevel) { }
    virtual void OnPlayerSetMaxLevel(Player* player, uint32& maxLevel) { }
    virtual void OnPlayerTalentsReset(Player* player, bool noCost) { }
    virtual void OnPlayerLearnTalents(Player* player, uint32 talentId, uint32 talentRank, uint32 spellId) { }
    virtual void OnPlayerFreeTalentPointsChanged(Player* player, uint32 points) { }
    virtual void OnPlayerCompleteQuest(Player* player, Quest const* quest) { }
    virtual void OnPlayerQuestAbandon(Player* player, uint32 questId) { }

    // Items
    virtual void OnPlayerEquip(Player* player, Item* it, uint8 bag, uint8 slot, bool update) { }
    virtual void OnPlayerUnequip(Player* player, uint16 pos, bool update) { }
    virtual void OnPlayerLootItem(Player* player, Item* item, uint32 count, ObjectGuid lootguid) { }
    virtual void OnPlayerCreateItem(Player* player, Item* item, uint32 count) { }
    virtual void OnPlayerStoreNewItem(Player* player, Item* item, uint32& count) { }
    virtual void OnPlayerQuestRewardItem(Player* player, Item* item, uint32 count) { }

    // Economy
    virtual void OnPlayerMoneyChanged(Player* player, int32& amount) { }
    virtual void OnPlayerBeforeLootMoney(Player* player, Loot* loot) { }

    // PvP & Battlegrounds
    virtual void OnPlayerAddToBattleground(Player* player, Battleground* bg) { }
    virtual void OnPlayerRemoveFromBattleground(Player* player, Battleground* bg) { }
    virtual void OnPlayerJoinBG(Player* player) { }
    virtual void OnPlayerJoinArena(Player* player) { }
    virtual void OnPlayerQueueRandomDungeon(Player* player, uint32& rDungeonId) { }

    // Stats & Skills
    virtual void OnPlayerUpdateGatheringSkill(Player* player, uint32 skillId, uint32 currentLevel, uint32 gray, uint32 green, uint32 yellow, uint32& gain) { }
    virtual void OnPlayerUpdateCraftingSkill(Player* player, SkillLineAbilityEntry const* skill, uint32 currentLevel, uint32& gain) { }
    virtual void OnPlayerAfterUpdateMaxHealth(Player* player, uint32& value) { }
    virtual void OnPlayerAfterUpdateMaxPower(Player* player, Powers power, float& value) { }
    virtual void OnPlayerBeforeUpdateAttackPowerAndDamage(Player* player, float& level, float& val2, bool ranged) { }

    // ... many more — see src/server/game/Scripting/ScriptDefines/PlayerScript.h for full list
};
```

---

### AccountScript

Fires for account-level events (auth-side). `IsDatabaseBound() = false`.

```cpp
class AccountScript : public ScriptObject {
public:
    virtual void OnAccountLogin(uint32 accountId) { }
    virtual void OnBeforeAccountDelete(uint32 accountId) { }
    virtual void OnLastIpUpdate(uint32 accountId, std::string ip) { }
    virtual void OnFailedAccountLogin(uint32 accountId) { }
    virtual void OnEmailChange(uint32 accountId) { }
    virtual void OnFailedEmailChange(uint32 accountId) { }
    virtual void OnPasswordChange(uint32 accountId) { }
    virtual void OnFailedPasswordChange(uint32 accountId) { }
    [[nodiscard]] virtual bool CanAccountCreateCharacter(uint32 accountId, uint8 charRace, uint8 charClass) { return true; }
};
```

---

### CreatureScript

Database-bound (`IsDatabaseBound() = true`). The script name must match `creature_template.ScriptName`. Only one CreatureScript per script name.

```cpp
class CreatureScript : public ScriptObject {
public:
    [[nodiscard]] bool IsDatabaseBound() const override { return true; }

    // Gossip
    [[nodiscard]] virtual bool OnGossipHello(Player* player, Creature* creature) { return false; }
    [[nodiscard]] virtual bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) { return false; }
    [[nodiscard]] virtual bool OnGossipSelectCode(Player* player, Creature* creature, uint32 sender, uint32 action, const char* code) { return false; }

    // Quest
    [[nodiscard]] virtual bool OnQuestAccept(Player* player, Creature* creature, Quest const* quest) { return false; }
    [[nodiscard]] virtual bool OnQuestSelect(Player* player, Creature* creature, Quest const* quest) { return false; }
    [[nodiscard]] virtual bool OnQuestComplete(Player* player, Creature* creature, Quest const* quest) { return false; }
    [[nodiscard]] virtual bool OnQuestReward(Player* player, Creature* creature, Quest const* quest, uint32 opt) { return false; }

    // Dialog
    virtual uint32 GetDialogStatus(Player* player, Creature* creature) { return DIALOG_STATUS_SCRIPTED_NO_STATUS; }

    // AI
    virtual CreatureAI* GetAI(Creature* creature) const { return nullptr; }

    // PvP state
    virtual void OnFfaPvpStateUpdate(Creature* creature, bool result) { }
};
```

To script a creature's combat AI, override `GetAI()`:
```cpp
class MyBossScript : public CreatureScript {
public:
    MyBossScript() : CreatureScript("boss_my_boss") { }

    CreatureAI* GetAI(Creature* creature) const override {
        return new MyBossAI(creature);
    }
};

struct MyBossAI : public ScriptedAI {
    MyBossAI(Creature* c) : ScriptedAI(c) { }

    void EnterCombat(Unit* who) override { }
    void UpdateAI(uint32 diff) override { }
    void JustDied(Unit* killer) override { }
};
```

---

### AllCreatureScript

Like `CreatureScript` but fires for ALL creatures regardless of `ScriptName`. `IsDatabaseBound() = false`.

```cpp
class AllCreatureScript : public ScriptObject {
public:
    virtual void OnAllCreatureUpdate(Creature* creature, uint32 diff) { }
    virtual void OnBeforeCreatureSelectLevel(const CreatureTemplate* cinfo, Creature* creature, uint8& level) { }
    virtual void OnCreatureSelectLevel(const CreatureTemplate* cinfo, Creature* creature) { }
    virtual void OnCreatureAddWorld(Creature* creature) { }
    virtual void OnCreatureRemoveWorld(Creature* creature) { }
    virtual void OnCreatureSaveToDB(Creature* creature) { }
    [[nodiscard]] virtual bool CanCreatureGossipHello(Player* player, Creature* creature) { return false; }
    [[nodiscard]] virtual bool CanCreatureGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) { return false; }
    [[nodiscard]] virtual bool CanCreatureGossipSelectCode(Player* player, Creature* creature, uint32 sender, uint32 action, const char* code) { return false; }
    [[nodiscard]] virtual bool CanCreatureQuestAccept(Player* player, Creature* creature, Quest const* quest) { return false; }
    [[nodiscard]] virtual bool CanCreatureQuestReward(Player* player, Creature* creature, Quest const* quest, uint32 opt) { return false; }
    [[nodiscard]] virtual CreatureAI* GetCreatureAI(Creature* creature) const { return nullptr; }
    virtual void OnFfaPvpStateUpdate(Creature* creature, bool InPvp) { }
};
```

---

### GameObjectScript

Database-bound — `gameobject_template.ScriptName` must match.

```cpp
class GameObjectScript : public ScriptObject {
public:
    [[nodiscard]] bool IsDatabaseBound() const override { return true; }

    [[nodiscard]] virtual bool OnGossipHello(Player* player, GameObject* go) { return false; }
    [[nodiscard]] virtual bool OnGossipSelect(Player* player, GameObject* go, uint32 sender, uint32 action) { return false; }
    [[nodiscard]] virtual bool OnGossipSelectCode(Player* player, GameObject* go, uint32 sender, uint32 action, const char* code) { return false; }
    [[nodiscard]] virtual bool OnQuestAccept(Player* player, GameObject* go, Quest const* quest) { return false; }
    [[nodiscard]] virtual bool OnQuestReward(Player* player, GameObject* go, Quest const* quest, uint32 opt) { return false; }
    virtual uint32 GetDialogStatus(Player* player, GameObject* go) { return DIALOG_STATUS_SCRIPTED_NO_STATUS; }
    virtual void OnDestroyed(GameObject* go, Player* player) { }
    virtual void OnDamaged(GameObject* go, Player* player) { }
    virtual void OnModifyHealth(GameObject* go, Unit* attackerOrHealer, int32& change, SpellInfo const* spellInfo) { }
    virtual void OnLootStateChanged(GameObject* go, uint32 state, Unit* unit) { }
    virtual void OnGameObjectStateChanged(GameObject* go, uint32 state) { }
    virtual GameObjectAI* GetAI(GameObject* go) const { return nullptr; }
};
```

---

### AllGameObjectScript

Fires for all GameObjects regardless of ScriptName.

```cpp
class AllGameObjectScript : public ScriptObject {
public:
    virtual void OnGameObjectAddWorld(GameObject* go) { }
    virtual void OnGameObjectSaveToDB(GameObject* go) { }
    virtual void OnGameObjectRemoveWorld(GameObject* go) { }
    virtual void OnGameObjectUpdate(GameObject* go, uint32 diff) { }
    [[nodiscard]] virtual bool CanGameObjectGossipHello(Player* player, GameObject* go) { return false; }
    [[nodiscard]] virtual bool CanGameObjectGossipSelect(Player* player, GameObject* go, uint32 sender, uint32 action) { return false; }
    [[nodiscard]] virtual bool CanGameObjectGossipSelectCode(Player* player, GameObject* go, uint32 sender, uint32 action, const char* code) { return false; }
    [[nodiscard]] virtual bool CanGameObjectQuestAccept(Player* player, GameObject* go, Quest const* quest) { return false; }
    [[nodiscard]] virtual bool CanGameObjectQuestReward(Player* player, GameObject* go, Quest const* quest, uint32 opt) { return false; }
    virtual void OnGameObjectDestroyed(GameObject* go, Player* player) { }
    virtual void OnGameObjectDamaged(GameObject* go, Player* player) { }
    virtual void OnGameObjectModifyHealth(GameObject* go, Unit* attackerOrHealer, int32& change, SpellInfo const* spellInfo) { }
    virtual void OnGameObjectLootStateChanged(GameObject* go, uint32 state, Unit* unit) { }
    virtual void OnGameObjectStateChanged(GameObject* go, uint32 state) { }
    virtual GameObjectAI* GetGameObjectAI(GameObject* go) const { return nullptr; }
};
```

---

### ItemScript

Database-bound — `item_template.ScriptName` must match.

```cpp
class ItemScript : public ScriptObject {
public:
    [[nodiscard]] bool IsDatabaseBound() const override { return true; }
    [[nodiscard]] virtual bool OnQuestAccept(Player* player, Item* item, Quest const* quest) { return false; }
    [[nodiscard]] virtual bool OnUse(Player* player, Item* item, SpellCastTargets const& targets) { return false; }
    [[nodiscard]] virtual bool OnRemove(Player* player, Item* item) { return false; }
    [[nodiscard]] virtual bool OnCastItemCombatSpell(Player* player, Unit* victim, SpellInfo const* spellInfo, Item* item) { return false; }
    [[nodiscard]] virtual bool OnExpire(Player* player, ItemTemplate const* proto) { return false; }
    virtual void OnGossipSelect(Player* player, Item* item, uint32 sender, uint32 action) { }
    virtual void OnGossipSelectCode(Player* player, Item* item, uint32 sender, uint32 action, const char* code) { }
};
```

---

### AllItemScript

Fires for all items.

```cpp
class AllItemScript : public ScriptObject {
public:
    [[nodiscard]] virtual bool CanItemQuestAccept(Player* player, Item* item, Quest const* quest) { return true; }
    [[nodiscard]] virtual bool CanItemUse(Player* player, Item* item, SpellCastTargets const& targets) { return false; }
    [[nodiscard]] virtual bool CanItemRemove(Player* player, Item* item) { return true; }
    [[nodiscard]] virtual bool CanItemExpire(Player* player, ItemTemplate const* proto) { return true; }
    virtual void OnItemGossipSelect(Player* player, Item* item, uint32 sender, uint32 action) { }
    virtual void OnItemGossipSelectCode(Player* player, Item* item, uint32 sender, uint32 action, const char* code) { }
};
```

---

### SpellScriptLoader

Database-bound — `spell_script_names.spell_id` + `spell_script_names.ScriptName` must match.

```cpp
class SpellScriptLoader : public ScriptObject {
public:
    [[nodiscard]] bool IsDatabaseBound() const override { return true; }
    [[nodiscard]] virtual SpellScript* GetSpellScript() const { return nullptr; }
    [[nodiscard]] virtual AuraScript* GetAuraScript() const { return nullptr; }
};
```

Usage:
```cpp
class MySpellLoader : public SpellScriptLoader {
public:
    MySpellLoader() : SpellScriptLoader("spell_my_spell") { }

    SpellScript* GetSpellScript() const override {
        return new MySpellScript();
    }
};

class MySpellScript : public SpellScript {
    // Prepare, Check, etc. — see AzerothCore SpellScript docs
};
```

---

### AllSpellScript

Global spell event hooks, not database-bound.

```cpp
class AllSpellScript : public ScriptObject {
public:
    virtual void OnCalcMaxDuration(Aura const* aura, int32& maxDuration) { }
    virtual void OnSpellCheckCast(Spell* spell, bool strict, SpellCastResult& res) { }
    virtual bool CanPrepare(Spell* spell, SpellCastTargets const* targets, AuraEffect const* triggeredByAura) { return true; }
    virtual bool CanScalingEverything(Spell* spell) { return false; }
    virtual bool CanSelectSpecTalent(Spell* spell) { return false; }
    virtual void OnScaleAuraUnitAdd(Spell* spell, Unit* target, uint32 effectMask, bool checkIfValid, bool implicit, uint8 auraScaleMask, TargetInfo& targetInfo) { }
    virtual void OnRemoveAuraScaleTargets(Spell* spell, TargetInfo& targetInfo, uint8 auraScaleMask, bool& needErase) { }
    virtual void OnBeforeAuraRankForLevel(SpellInfo const* spellInfo, SpellInfo const* latestSpellInfo, uint8 level) { }
    virtual void OnDummyEffect(WorldObject* caster, uint32 spellID, SpellEffIndex effIndex, GameObject* gameObjTarget) { }
    virtual void OnDummyEffect(WorldObject* caster, uint32 spellID, SpellEffIndex effIndex, Creature* creatureTarget) { }
    virtual void OnDummyEffect(WorldObject* caster, uint32 spellID, SpellEffIndex effIndex, Item* itemTarget) { }
    virtual void OnSpellCastCancel(Spell* spell, Unit* caster, SpellInfo const* spellInfo, bool bySelf) { }
    virtual void OnSpellCast(Spell* spell, Unit* caster, SpellInfo const* spellInfo, bool skipCheck) { }
    virtual void OnSpellPrepare(Spell* spell, Unit* caster, SpellInfo const* spellInfo) { }
};
```

---

### UnitScript

Fires for all Units (players, creatures, pets). `IsDatabaseBound() = false`.

```cpp
class UnitScript : public ScriptObject {
public:
    // Damage & Healing
    virtual void OnHeal(Unit* healer, Unit* reciever, uint32& gain) { }
    virtual void OnDamage(Unit* attacker, Unit* victim, uint32& damage) { }
    virtual void ModifyPeriodicDamageAurasTick(Unit* target, Unit* attacker, uint32& damage, SpellInfo const* spellInfo) { }
    virtual void ModifyMeleeDamage(Unit* target, Unit* attacker, uint32& damage) { }
    virtual void ModifySpellDamageTaken(Unit* target, Unit* attacker, int32& damage, SpellInfo const* spellInfo) { }
    virtual void ModifyHealReceived(Unit* target, Unit* healer, uint32& heal, SpellInfo const* spellInfo) { }
    virtual uint32 DealDamage(Unit* attacker, Unit* victim, uint32 damage, DamageEffectType damageType) { return damage; }

    // Combat
    virtual void OnBeforeRollMeleeOutcomeAgainst(Unit const* attacker, Unit const* victim, WeaponAttackType attType,
        int32& attackerMaxSkillValueForLevel, int32& victimMaxSkillValueForLevel,
        int32& attackerWeaponSkill, int32& victimDefenseSkill,
        int32& crit_chance, int32& miss_chance, int32& dodge_chance,
        int32& parry_chance, int32& block_chance) { }

    // Auras
    virtual void OnAuraApply(Unit* unit, Aura* aura) { }
    virtual void OnAuraRemove(Unit* unit, AuraApplication* aurApp, AuraRemoveMode mode) { }

    // State
    virtual void OnUnitUpdate(Unit* unit, uint32 diff) { }
    virtual void OnDisplayIdChange(Unit* unit, uint32 displayId) { }
    virtual void OnUnitEnterEvadeMode(Unit* unit, uint8 why) { }
    virtual void OnUnitEnterCombat(Unit* unit, Unit* victim) { }
    virtual void OnUnitDeath(Unit* unit, Unit* killer) { }
    virtual void OnUnitSetShapeshiftForm(Unit* unit, uint8 form) { }

    // Query hooks
    [[nodiscard]] virtual bool IfNormalReaction(Unit const* unit, Unit const* target, ReputationRank& repRank) { return true; }
    [[nodiscard]] virtual bool CanSetPhaseMask(Unit const* unit, uint32 newPhaseMask, bool update) { return true; }
    [[nodiscard]] virtual bool IsCustomBuildValuesUpdate(Unit const* unit, uint8 updateType, ByteBuffer& fieldBuffer, Player const* target, uint16 index) { return false; }
    [[nodiscard]] virtual bool ShouldTrackValuesUpdatePosByIndex(Unit const* unit, uint8 updateType, uint16 index) { return false; }
    virtual void OnPatchValuesUpdate(Unit const* unit, ByteBuffer& valuesUpdateBuf, BuildValuesCachePosPointers& posPointers, Player* target) { }
};
```

---

### InstanceMapScript

Database-bound — `instance_template.ScriptName` must match. Provides an `InstanceScript` object to the instance map.

```cpp
class InstanceMapScript : public ScriptObject, public MapScript<InstanceMap> {
public:
    [[nodiscard]] bool IsDatabaseBound() const override { return true; }
    virtual InstanceScript* GetInstanceScript(InstanceMap* map) const { return nullptr; }
};
```

Usage:
```cpp
class instance_my_dungeon : public InstanceMapScript {
public:
    instance_my_dungeon() : InstanceMapScript("instance_my_dungeon", 999) { }  // 999 = map id

    InstanceScript* GetInstanceScript(InstanceMap* map) const override {
        return new instance_my_dungeon_InstanceScript(map);
    }
};

struct instance_my_dungeon_InstanceScript : public InstanceScript {
    instance_my_dungeon_InstanceScript(Map* map) : InstanceScript(map) { }

    void Initialize() override { }
    void OnCreatureCreate(Creature* creature) override { }
    std::string GetSaveData() override { return ""; }
    void Load(const char* in) override { }
};
```

---

### WorldMapScript

For the open world (non-instanced) maps. `isAfterLoadScript() = true` (registered after world loads).

```cpp
class WorldMapScript : public ScriptObject, public MapScript<Map> {
    // Inherits MapScript<Map> methods:
    // OnCreate(Map*), OnDestroy(Map*), OnPlayerEnter(Map*, Player*)
    // OnPlayerLeave(Map*, Player*), OnUpdate(Map*, uint32 diff)
};
```

---

### AllMapScript

Fires for all maps regardless of type.

```cpp
class AllMapScript : public ScriptObject {
public:
    virtual void OnPlayerEnterAll(Map* map, Player* player) { }
    virtual void OnPlayerLeaveAll(Map* map, Player* player) { }
    virtual void OnBeforeCreateInstanceScript(InstanceMap* instanceMap, InstanceScript** instanceData, bool load, std::string data, uint32 completedEncounterMask) { }
    virtual void OnDestroyInstance(MapInstanced* mapInstanced, Map* map) { }
    virtual void OnCreateMap(Map* map) { }
    virtual void OnDestroyMap(Map* map) { }
    virtual void OnMapUpdate(Map* map, uint32 diff) { }
};
```

---

### GuildScript

```cpp
class GuildScript : public ScriptObject {
public:
    virtual void OnAddMember(Guild* guild, Player* player, uint8& plRank) { }
    virtual void OnRemoveMember(Guild* guild, Player* player, bool isDisbanding, bool isKicked) { }
    virtual void OnMOTDChanged(Guild* guild, const std::string& newMotd) { }
    virtual void OnInfoChanged(Guild* guild, const std::string& newInfo) { }
    virtual void OnCreate(Guild* guild, Player* leader, const std::string& name) { }
    virtual void OnDisband(Guild* guild) { }
    virtual void OnMemberWitdrawMoney(Guild* guild, Player* player, uint32& amount, bool isRepair) { }
    virtual void OnMemberDepositMoney(Guild* guild, Player* player, uint32& amount) { }
    virtual void OnItemMove(Guild* guild, Player* player, Item* pItem, bool isSrcBank, uint8 srcContainer, uint8 srcSlotId, bool isDestBank, uint8 destContainer, uint8 destSlotId) { }
    virtual void OnEvent(Guild* guild, uint8 eventType, ObjectGuid::LowType playerGuid1, ObjectGuid::LowType playerGuid2, uint8 newRank) { }
    virtual void OnBankEvent(Guild* guild, uint8 eventType, uint8 tabId, ObjectGuid::LowType playerGuid, uint32 itemOrMoney, uint16 itemStackCount, uint8 destTabId) { }
    [[nodiscard]] virtual bool CanGuildSendBankList(Guild const* guild, WorldSession* session, uint8 tabId, bool sendAllSlots) { return true; }
};
```

---

### GroupScript

```cpp
class GroupScript : public ScriptObject {
public:
    virtual void OnAddMember(Group* group, ObjectGuid guid) { }
    virtual void OnInviteMember(Group* group, ObjectGuid guid) { }
    virtual void OnRemoveMember(Group* group, ObjectGuid guid, RemoveMethod method, ObjectGuid kicker, const char* reason) { }
    virtual void OnChangeLeader(Group* group, ObjectGuid newLeaderGuid, ObjectGuid oldLeaderGuid) { }
    virtual void OnDisband(Group* group) { }
    virtual void OnCreate(Group* group, Player* leader) { }
    [[nodiscard]] virtual bool CanGroupJoinBattlegroundQueue(Group const* group, Player* member, Battleground const* bgTemplate, uint32 MinPlayerCount, bool isRated, uint32 arenaSlot) { return true; }
};
```

---

### BattlegroundScript

Database-bound — one per battleground type.

```cpp
class BattlegroundScript : public ScriptObject {
public:
    [[nodiscard]] bool IsDatabaseBound() const override { return true; }
    [[nodiscard]] virtual Battleground* GetBattleground() const = 0;
};
```

---

### ArenaScript

```cpp
class ArenaScript : public ScriptObject {
public:
    [[nodiscard]] bool IsDatabaseBound() const override { return false; }
    [[nodiscard]] virtual bool CanAddMember(ArenaTeam* team, ObjectGuid playerGuid) { return true; }
    virtual void OnGetPoints(ArenaTeam* team, uint32 memberRating, float& points) { }
    [[nodiscard]] virtual bool OnBeforeArenaCheckWinConditions(Battleground* const bg) { return true; }
    [[nodiscard]] virtual bool CanSaveToDB(ArenaTeam* team) { return true; }
    virtual void OnArenaStart(Battleground* bg) { }
    [[nodiscard]] virtual bool OnBeforeArenaTeamMemberUpdate(ArenaTeam* team, Player* player, bool isJoin, uint32 arenaTeamId, int32 arenaPersonalRating) { return true; }
    [[nodiscard]] virtual bool CanSaveArenaStatsForMember(ArenaTeam* team, ObjectGuid guid) { return true; }
};
```

---

### OutdoorPvPScript

Database-bound.

```cpp
class OutdoorPvPScript : public ScriptObject {
public:
    [[nodiscard]] bool IsDatabaseBound() const override { return true; }
    [[nodiscard]] virtual OutdoorPvP* GetOutdoorPvP() const = 0;
};
```

---

### BattlefieldScript

World PvP zones (Wintergrasp, Tol Barad).

```cpp
class BattlefieldScript : public ScriptObject {
public:
    [[nodiscard]] bool IsDatabaseBound() const override { return false; }
    virtual void OnBattlefieldPlayerEnterZone(Battlefield* bf, Player* player) { }
    virtual void OnBattlefieldPlayerLeaveZone(Battlefield* bf, Player* player) { }
    virtual void OnBattlefieldPlayerJoinWar(Battlefield* bf, Player* player) { }
    virtual void OnBattlefieldPlayerLeaveWar(Battlefield* bf, Player* player) { }
    virtual void OnBattlefieldBeforeInvitePlayerToWar(Battlefield* bf, Player* player) { }
};
```

---

### AuctionHouseScript

```cpp
class AuctionHouseScript : public ScriptObject {
public:
    virtual void OnAuctionAdd(AuctionHouseObject* ah, AuctionEntry* entry) { }
    virtual void OnAuctionRemove(AuctionHouseObject* ah, AuctionEntry* entry) { }
    virtual void OnAuctionSuccessful(AuctionHouseObject* ah, AuctionEntry* entry) { }
    virtual void OnAuctionExpire(AuctionHouseObject* ah, AuctionEntry* entry) { }
    virtual void OnBeforeAuctionHouseMgrSendAuctionWonMail(AuctionHouseMgr*, AuctionEntry*, Player*, uint32&, bool&, bool&, bool&) { }
    virtual void OnBeforeAuctionHouseMgrSendAuctionSalePendingMail(AuctionHouseMgr*, AuctionEntry*, Player*, uint32&, bool&) { }
    virtual void OnBeforeAuctionHouseMgrSendAuctionSuccessfulMail(AuctionHouseMgr*, AuctionEntry*, Player*, uint32&, uint32&, bool&, bool&, bool&) { }
    virtual void OnBeforeAuctionHouseMgrSendAuctionExpiredMail(AuctionHouseMgr*, AuctionEntry*, Player*, uint32&, bool&, bool&) { }
    virtual void OnBeforeAuctionHouseMgrSendAuctionOutbiddedMail(AuctionHouseMgr*, AuctionEntry*, Player*, uint32&, Player*, uint32&, bool&, bool&) { }
    virtual void OnBeforeAuctionHouseMgrSendAuctionCancelledToBidderMail(AuctionHouseMgr*, AuctionEntry*, Player*, uint32&, bool&) { }
    virtual void OnBeforeAuctionHouseMgrUpdate() { }
};
```

---

### VehicleScript

```cpp
class VehicleScript : public ScriptObject {
public:
    virtual void OnInstall(Vehicle* veh) { }
    virtual void OnUninstall(Vehicle* veh) { }
    virtual void OnReset(Vehicle* veh) { }
    virtual void OnInstallAccessory(Vehicle* veh, Creature* accessory) { }
    virtual void OnAddPassenger(Vehicle* veh, Unit* passenger, int8 seatId) { }
    virtual void OnRemovePassenger(Vehicle* veh, Unit* passenger) { }
};
```

---

### TransportScript

Database-bound.

```cpp
class TransportScript : public ScriptObject {
public:
    [[nodiscard]] bool IsDatabaseBound() const override { return true; }
    virtual void OnAddPassenger(Transport* transport, Player* player) { }
    virtual void OnAddCreaturePassenger(Transport* transport, Creature* creature) { }
    virtual void OnRemovePassenger(Transport* transport, Player* player) { }
    virtual void OnRelocate(Transport* transport, uint32 waypointId, uint32 mapId, float x, float y, float z) { }
};
```

---

### WeatherScript

Database-bound (by zone weather entry).

```cpp
class WeatherScript : public ScriptObject {
public:
    [[nodiscard]] bool IsDatabaseBound() const override { return true; }
    virtual void OnChange(Weather* weather, WeatherState state, float grade) { }
};
```

---

### AreaTriggerScript

Database-bound — `areatrigger_scripts.entry` must match.

```cpp
class AreaTriggerScript : public ScriptObject {
public:
    [[nodiscard]] bool IsDatabaseBound() const override { return true; }
    [[nodiscard]] virtual bool OnTrigger(Player* player, AreaTrigger const* trigger) { return false; }
};
```

---

### CommandScript

Registers custom `.` chat commands.

```cpp
class CommandScript : public ScriptObject {
public:
    [[nodiscard]] virtual std::vector<Acore::ChatCommands::ChatCommandBuilder> GetCommands() const = 0;
};
```

Usage:
```cpp
class MyCommandScript : public CommandScript {
public:
    MyCommandScript() : CommandScript("MyCommandScript") { }

    std::vector<Acore::ChatCommands::ChatCommandBuilder> GetCommands() const override {
        static std::vector<Acore::ChatCommands::ChatCommandBuilder> commandTable = {
            { "mycommand", SEC_MODERATOR, true, HandleMyCommand, "" },
        };
        return commandTable;
    }

    static bool HandleMyCommand(ChatHandler* handler, const char* args) {
        handler->PSendSysMessage("Hello from MyCommand!");
        return true;
    }
};
```

---

### ConditionScript

Database-bound — `conditions` table `ConditionValue3` references script name.

```cpp
class ConditionScript : public ScriptObject {
public:
    [[nodiscard]] bool IsDatabaseBound() const override { return true; }
    [[nodiscard]] virtual bool OnConditionCheck(Condition* condition, ConditionSourceInfo& sourceInfo) { return true; }
};
```

---

### FormulaScript

Override game formula calculations.

```cpp
class FormulaScript : public ScriptObject {
public:
    virtual void OnHonorCalculation(float& honor, uint8 level, float multiplier) { }
    virtual void OnGrayLevelCalculation(uint8& grayLevel, uint8 playerLevel) { }
    virtual void OnColorCodeCalculation(XPColorChar& color, uint8 playerLevel, uint8 mobLevel) { }
    virtual void OnZeroDifferenceCalculation(uint8& diff, uint8 playerLevel) { }
    virtual void OnBaseGainCalculation(uint32& gain, uint8 playerLevel, uint8 mobLevel, ContentLevels content) { }
    virtual void OnGainCalculation(uint32& gain, Player* player, Unit* unit) { }
    virtual void OnGroupRateCalculation(float& rate, uint32 count, bool isRaid) { }
    virtual void OnAfterArenaRatingCalculation(Battleground* const bg, int32& winnerMatchmakerChange, int32& loserMatchmakerChange, int32& winnerChange, int32& loserChange) { }
    virtual void OnBeforeUpdatingPersonalRating(int32& mod, uint32 type) { }
};
```

---

### GlobalScript

Loot, LFG, arena points, loot system deep hooks.

```cpp
class GlobalScript : public ScriptObject {
public:
    virtual void OnItemDelFromDB(CharacterDatabaseTransaction trans, ObjectGuid::LowType itemGuid) { }
    virtual void OnMirrorImageDisplayItem(Item const* item, uint32& display) { }
    virtual void OnAfterRefCount(Player const* player, LootStoreItem* LootStoreItem, Loot& loot, bool canRate, uint16 lootMode, uint32& maxcount, LootStore const& store) { }
    virtual void OnAfterCalculateLootGroupAmount(Player const* player, Loot& loot, uint16 lootMode, uint32& GroupType, LootStore const& store) { }
    virtual void OnBeforeDropAddItem(Player const* player, Loot& loot, bool canRate, uint16 lootMode, LootStoreItem* LootStoreItem, LootStore const& store) { }
    virtual bool OnItemRoll(Player const* player, LootStoreItem const* LootStoreItem, float& chance, Loot& loot, LootStore const& store) { return true; }
    virtual bool OnBeforeLootEqualChanced(Player const* player, std::list<LootStoreItem*> EqualChanced, Loot& loot, LootStore const& store) { return true; }
    virtual void OnInitializeLockedDungeons(Player* player, uint8& level, uint32& lockData, lfg::LFGDungeonData const* dungeon) { }
    virtual void OnAfterInitializeLockedDungeons(Player* player) { }
    virtual void OnBeforeUpdateArenaPoints(ArenaTeam* at, std::map<ObjectGuid, uint32>& ap) { }
    virtual void OnAfterUpdateEncounterState(Map* map, EncounterCreditType type, uint32 creditEntry, Unit* source, Difficulty difficulty, std::list<DungeonEncounter const*> const* encounters, uint32 dungeonCompleted, bool updated) { }
    virtual void OnBeforeWorldObjectSetPhaseMask(WorldObject const* worldObject, uint32& oldPhaseMask, uint32& newPhaseMask, bool& update, bool& deleted) { }
    virtual bool OnIsAffectedBySpellModCheck(SpellInfo const* affectSpell, SpellInfo const* checkSpell, SpellModifier const* mod) { return true; }
    virtual bool OnSpellHealingBonusTakenNegativeModifiers(Unit const* target, Unit const* caster, SpellInfo const* spellInfo, float& val) { return false; }
    virtual void OnLoadSpellCustomAttr(SpellInfo* spell) { }
    virtual bool OnAllowedForPlayerLootCheck(Player const* player, ObjectGuid source) { return true; }
    virtual bool OnAllowedToLootContainerCheck(Player const* player, ObjectGuid source) { return true; }
    virtual void OnInstanceIdRemoved(uint32 instanceId) { }
    virtual void OnBeforeSetBossState(uint32 id, EncounterState newState, EncounterState oldState, Map* instance) { }
    virtual void AfterInstanceGameObjectCreate(Map* instance, GameObject* go) { }
};
```

---

### MiscScript

Miscellaneous hooks that don't fit elsewhere.

```cpp
class MiscScript : public ScriptObject {
public:
    virtual void OnConstructObject(Object* origin) { }
    virtual void OnDestructObject(Object* origin) { }
    virtual void OnConstructPlayer(Player* origin) { }
    virtual void OnDestructPlayer(Player* origin) { }
    virtual void OnConstructGroup(Group* origin) { }
    virtual void OnDestructGroup(Group* origin) { }
    virtual void OnConstructInstanceSave(InstanceSave* origin) { }
    virtual void OnDestructInstanceSave(InstanceSave* origin) { }
    virtual void OnItemCreate(Item* item, ItemTemplate const* itemProto, Player const* owner) { }
    [[nodiscard]] virtual bool CanApplySoulboundFlag(Item* item, ItemTemplate const* proto) { return true; }
    [[nodiscard]] virtual bool CanItemApplyEquipSpell(Player* player, Item* item) { return true; }
    [[nodiscard]] virtual bool CanSendAuctionHello(WorldSession const* session, ObjectGuid guid, Creature* creature) { return true; }
    virtual void ValidateSpellAtCastSpell(Player* player, uint32& oldSpellId, uint32& spellId, uint8& castCount, uint8& castFlags) { }
    virtual void ValidateSpellAtCastSpellResult(Player* player, Unit* mover, Spell* spell, uint32 oldSpellId, uint32 spellId) { }
    virtual void OnAfterLootTemplateProcess(Loot* loot, LootTemplate const* tab, LootStore const& store, Player* lootOwner, bool personal, bool noEmptyError, uint16 lootMode) { }
    virtual void OnPlayerSetPhase(const AuraEffect* auraEff, AuraApplication const* aurApp, uint8 mode, bool apply, uint32& newPhase) { }
    virtual void OnInstanceSave(InstanceSave* instanceSave) { }
    virtual void GetDialogStatus(Player* player, Object* questGiver) { }
};
```

---

### WorldObjectScript

Fires for all WorldObjects.

```cpp
class WorldObjectScript : public ScriptObject {
public:
    virtual void OnWorldObjectDestroy(WorldObject* object) { }
    virtual void OnWorldObjectCreate(WorldObject* object) { }
    virtual void OnWorldObjectSetMap(WorldObject* object, Map* map) { }
    virtual void OnWorldObjectResetMap(WorldObject* object) { }
    virtual void OnWorldObjectUpdate(WorldObject* object, uint32 diff) { }
};
```

---

### PetScript

```cpp
class PetScript : public ScriptObject {
public:
    virtual void OnInitStatsForLevel(Guardian* guardian, uint8 petlevel) { }
    virtual void OnCalculateMaxTalentPointsForLevel(Pet* pet, uint8 level, uint8& points) { }
    [[nodiscard]] virtual bool CanUnlearnSpellSet(Pet* pet, uint32 level, uint32 spell) { return true; }
    [[nodiscard]] virtual bool CanUnlearnSpellDefault(Pet* pet, SpellInfo const* spellInfo) { return true; }
    [[nodiscard]] virtual bool CanResetTalents(Pet* pet) { return true; }
    virtual void OnPetAddToWorld(Pet* pet) { }
};
```

---

### AchievementScript

```cpp
class AchievementScript : public ScriptObject {
public:
    virtual void SetRealmCompleted(AchievementEntry const* achievement) { }
    [[nodiscard]] virtual bool IsCompletedCriteria(AchievementMgr* mgr, AchievementCriteriaEntry const* achievementCriteria, AchievementEntry const* achievement, CriteriaProgress const* progress) { return false; }
    [[nodiscard]] virtual bool IsRealmCompleted(AchievementGlobalMgr const* globalMgr, AchievementEntry const* achievement, SystemTimePoint completionTime) { return false; }
    virtual void OnBeforeCheckCriteria(AchievementMgr* mgr, std::list<AchievementCriteriaEntry const*> const* achievementCriteriaList) { }
    [[nodiscard]] virtual bool CanCheckCriteria(AchievementMgr* mgr, AchievementCriteriaEntry const* achievementCriteria) { return true; }
};
```

---

### GameEventScript

```cpp
class GameEventScript : public ScriptObject {
public:
    virtual void OnStart(uint16 EventID) { }
    virtual void OnStop(uint16 EventID) { }
    virtual void OnEventCheck(uint16 EventID) { }
};
```

---

### MailScript

```cpp
class MailScript : public ScriptObject {
public:
    virtual void OnBeforeMailDraftSendMailTo(MailDraft* mailDraft, MailReceiver const& receiver,
        MailSender const& sender, MailCheckMask& checked, uint32& deliver_delay,
        uint32& custom_expiration, bool& deleteMailItemsFromDB, bool& sendMail) { }
};
```

---

### LootScript

```cpp
class LootScript : public ScriptObject {
public:
    virtual void OnLootMoney(Player* player, uint32 gold) { }
};
```

---

### TicketScript

```cpp
class TicketScript : public ScriptObject {
public:
    virtual void OnTicketCreate(GmTicket* ticket) { }
    virtual void OnTicketUpdateLastChange(GmTicket* ticket) { }
    virtual void OnTicketClose(GmTicket* ticket) { }
    virtual void OnTicketStatusUpdate(GmTicket* ticket) { }
    virtual void OnTicketResolve(GmTicket* ticket) { }
};
```

---

### MovementHandlerScript

```cpp
class MovementHandlerScript : public ScriptObject {
public:
    virtual void OnPlayerMove(Player* player, MovementInfo movementInfo, uint32 opcode) { }
};
```

---

### DynamicObjectScript

Inherits `UpdatableScript<DynamicObject>` — provides `OnUpdate(DynamicObject*, uint32 diff)`.

---

### ALEScript

Integration hook for the Eluna Lua Engine (mod-ale). Provides override points for weather changes and area triggers that ALE handles internally.

```cpp
class ALEScript : public ScriptObject {
public:
    virtual void OnWeatherChange(Weather* weather, WeatherState state, float grade) { }
    [[nodiscard]] virtual bool CanAreaTrigger(Player* player, AreaTrigger const* trigger) { return false; }
};
```

---

## Hook Category Summary Table

| Class | DB Bound | Primary Use |
|---|---|---|
| `ServerScript` | No | Network socket/packet lifecycle |
| `WorldScript` | No | Server startup/shutdown/tick |
| `DatabaseScript` | No | Post-DB-load initialization |
| `PlayerScript` | No | All player events (150+ hooks) |
| `AccountScript` | No | Account login/security events |
| `CreatureScript` | Yes | Per-NPC gossip, quest, AI |
| `AllCreatureScript` | No | Global creature events |
| `GameObjectScript` | Yes | Per-GO gossip, quest, state |
| `AllGameObjectScript` | No | Global GO events |
| `ItemScript` | Yes | Per-item use, remove, expire |
| `AllItemScript` | No | Global item events |
| `SpellScriptLoader` | Yes | Per-spell/aura scripting |
| `AllSpellScript` | No | Global spell events |
| `UnitScript` | No | All unit damage/heal/aura events |
| `InstanceMapScript` | Yes | Dungeon/raid instance scripts |
| `WorldMapScript` | No | Open-world map events |
| `AllMapScript` | No | All map lifecycle events |
| `BattlegroundScript` | Yes | Per-BG implementation |
| `ArenaScript` | No | Arena rating/win conditions |
| `OutdoorPvPScript` | Yes | Zone PvP scripting |
| `BattlefieldScript` | No | Wintergrasp/TB events |
| `AuctionHouseScript` | No | Auction lifecycle |
| `GuildScript` | No | Guild member/bank events |
| `GroupScript` | No | Party/raid formation events |
| `VehicleScript` | No | Vehicle passenger events |
| `TransportScript` | Yes | Boat/zeppelin passenger events |
| `WeatherScript` | Yes | Weather change events |
| `AreaTriggerScript` | Yes | Area trigger activation |
| `CommandScript` | No | Custom chat commands |
| `ConditionScript` | Yes | Custom condition evaluation |
| `FormulaScript` | No | XP/honor/rating formulas |
| `GlobalScript` | No | Loot, LFG, arena point hooks |
| `MiscScript` | No | Object construction, misc |
| `WorldObjectScript` | No | All WorldObject lifecycle |
| `PetScript` | No | Pet talent/stat hooks |
| `AchievementScript` | No | Achievement criteria hooks |
| `GameEventScript` | No | Seasonal event hooks |
| `MailScript` | No | Mail delivery hooks |
| `LootScript` | No | Money loot |
| `TicketScript` | No | GM ticket lifecycle |
| `MovementHandlerScript` | No | Player movement packets |
| `DynamicObjectScript` | No | Dynamic object updates |
| `ALEScript` | No | Eluna Lua engine hooks |
| `ModuleScript` | No | Inter-module extension point |

---

## mod-ale: Eluna Lua Engine Integration

`mod-ale` (AzerothCore Lua Engine) is a special module that hooks the `ALEScript` interface and several other ScriptMgr hooks to expose the entire game event system to Lua scripts.

When mod-ale is compiled in, `modules/CMakeLists.txt` detects it and links the Eluna Lua library into worldserver. Lua scripts live in `lua_scripts/` at the server root.

mod-ale registers its own `PlayerScript`, `CreatureScript`, `SpellScriptLoader`, etc. implementations internally. Those implementations call the Eluna Lua dispatcher, which fires registered Lua hooks (`RegisterPlayerEvent`, `RegisterCreatureEvent`, etc.).

**Key interaction**: If both a C++ module hook and an Eluna Lua hook exist for the same event, both fire. C++ scripts registered earlier in `ModulesScriptLoader.cpp` run before mod-ale's hooks (since mod-ale is just another module in registration order).

---

## Module Best Practices

### DO

- **Use `sConfigMgr->GetOption<T>()`** for all config values. Re-read them in `WorldScript::OnAfterConfigLoad()` so `/reload config` works.
- **Use `OnLoadCustomDatabaseTable()`** in a `WorldScript` to load your SQL data at startup. Cache it in a module-level singleton or global map.
- **Prefix your DB table names** with your module name: `my_feature_player_data`, not `player_data`.
- **Prefix your script names** with your module name: `my_feature_boss` not just `boss`.
- **Use PreparedStatements** for all DB queries — never raw string queries.
- **Check `player->IsInWorld()`** before using player pointers in async callbacks.
- **Use `IsDatabaseBound() = false`** (default) for player/unit/global hooks; only return `true` if the script must be assigned per-entity via DB.

### DO NOT

- **Do not access WorldSession from a DB callback thread** without posting back to the correct thread.
- **Do not store raw `Player*` or `Creature*` pointers** beyond the scope of the hook call. Use GUIDs and look up objects fresh.
- **Do not call `sWorld->` methods from map threads** without checking thread safety. The world is updated on a different thread than per-map logic.
- **Do not use `new Script()` outside of `AddXxxScripts()` functions** — scripts must be registered during the module loader phase.
- **Do not put heavy per-tick logic in `OnUpdate` hooks** (WorldScript, AllCreatureScript::OnAllCreatureUpdate). These fire every server tick for every entity.
- **Do not ship `.conf` files** — only `.conf.dist`. The `.conf` is the user's local copy.
- **Do not hardcode spell IDs, creature entries, or item IDs** as magic numbers — put them in your config or define named constants.
- **Do not modify `modules/CMakeLists.txt` or `modules/ModulesScriptLoader.h`** — these are generated/managed by the AC build system.

### Config Pattern
```cpp
// Header or anonymous namespace in your script file:
struct MyFeatureConfig {
    bool   Enable = false;
    float  XPMultiplier = 1.0f;
    int32  MaxLevel = 80;

    void Load() {
        Enable       = sConfigMgr->GetOption<bool>("MyFeature.Enable", false);
        XPMultiplier = sConfigMgr->GetOption<float>("MyFeature.XPMultiplier", 1.0f);
        MaxLevel     = sConfigMgr->GetOption<int32>("MyFeature.MaxLevel", 80);
    }
} gConfig;

// In your WorldScript:
void OnAfterConfigLoad(bool /*reload*/) override {
    gConfig.Load();
}
void OnStartup() override {
    gConfig.Load();
}
```

### Custom DB Table Loading Pattern
```cpp
struct MyFeatureManager {
    std::unordered_map<uint32 /*guid*/, uint32 /*points*/> PlayerPoints;

    void LoadFromDB() {
        PlayerPoints.clear();
        QueryResult result = CharacterDatabase.Query("SELECT guid, points FROM my_feature_data");
        if (!result) return;
        do {
            Field* fields = result->Fetch();
            PlayerPoints[fields[0].Get<uint32>()] = fields[1].Get<uint32>();
        } while (result->NextRow());
        LOG_INFO("module", ">> Loaded {} my_feature records.", PlayerPoints.size());
    }
} sMyFeatureMgr;

// In WorldScript::OnLoadCustomDatabaseTable():
void OnLoadCustomDatabaseTable() override {
    sMyFeatureMgr.LoadFromDB();
}
```

---

## Hook Prioritization When Multiple Scripts Handle the Same Event

As noted earlier, there is no formal priority system. The execution order is:

1. Built-in scripts compiled from `src/server/scripts/` (registered first)
2. Module scripts in the order the CMake build enumerates module directories (filesystem order)

For **void hooks**: all registered scripts run unconditionally.

For **boolean hooks** (e.g., `CanPacketReceive`):
- `CALL_ENABLED_BOOLEAN_HOOKS` — default return is `true`, returns `false` if ANY script returns `true` (blocking semantics)
- `CALL_ENABLED_BOOLEAN_HOOKS_WITH_DEFAULT_FALSE` — default return is `false`, returns `true` if ANY script returns `true` (enabling semantics)

For **database-bound scripts**: only one script with a given name can exist. If you try to register a second script with the same name, the first registration wins and the duplicate is discarded (with a warning).

**Practical rule**: design module hooks to be composable. If you need guaranteed ordering between two of your own scripts, put them in the same script class. If you need to block another module's hook, you cannot — instead coordinate at the config level or via inter-module hooks using `ModuleScript`.

---

## Cross-References

- `00_overview.md` — Server architecture, startup sequence, database layout, threading model
- `../kb_azerothcore_dev.md` — Legacy comprehensive C++ hook reference, SmartAI, DB schema deep-dives
- `../kb_eluna_api.md` — Full Eluna Lua API; mod-ale registers these hooks through the C++ ScriptMgr layer
- `../kb_lua_reference.md` — Lua 5.2 language reference, awesome_wotlk patterns
- `../kb_wow_internals.md` — WoW taint, protected API, binary patching
- https://github.com/azerothcore/skeleton-module — Canonical module template
- `src/server/game/Scripting/ScriptDefines/` — One `.h` file per script class with current exact signatures
