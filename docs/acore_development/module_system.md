# Module System

This document is a complete reference for creating AzerothCore C++ modules. All information is derived from reading the actual source files in this repository.

---

## Table of Contents

1. [How the Module System Works](#1-how-the-module-system-works)
2. [Module Directory Layout](#2-module-directory-layout)
3. [CMakeLists.txt — Minimal Template](#3-cmakeliststxt--minimal-template)
4. [The Script Loader Pattern](#4-the-script-loader-pattern)
5. [All Script Types Available](#5-all-script-types-available)
6. [PlayerScript — Complete Hook List](#6-playerscript--complete-hook-list)
7. [WorldScript — Complete Hook List](#7-worldscript--complete-hook-list)
8. [CreatureScript — Hook List](#8-creaturescript--hook-list)
9. [ModuleScript](#9-modulescript)
10. [Config System in Modules](#10-config-system-in-modules)
11. [Complete Working Module Example: mod-dreamforge](#11-complete-working-module-example-mod-dreamforge)
12. [Build Commands](#12-build-commands)

---

## 1. How the Module System Works

The module system is built entirely on CMake code generation. When you run CMake, it scans every subdirectory under `modules/` and for each enabled module:

1. Collects all `.cpp`/`.h` source files via `CollectSourceFiles()`.
2. Generates a `ModulesLoader.cpp` from the template `modules/ModulesLoader.cpp.in.cmake`. This generated file contains a single function `AddModulesScripts()` that calls every module's `Add<ModuleName>Scripts()` function.
3. Compiles everything into a static library called `modules` that is linked into `worldserver`.

The generated loader (`ModulesLoader.cpp`) looks like this (simplified):

```cpp
// Auto-generated — do not edit by hand
void Addmod_dreamforgeScripts();   // forward declaration

void AddModulesScripts()
{
    Addmod_dreamforgeScripts();    // call each module's loader
}
```

The key rule: **the function name is derived mechanically from the module directory name.** Hyphens in the directory name become underscores. The pattern is:

```
directory name:  mod-dreamforge
function name:   Addmod_dreamforgeScripts()
```

This is confirmed in `modules/CMakeLists.txt` line 153:
```cmake
string(REGEX REPLACE - "_" LOCALE_SCRIPT_MODULE ${LOCALE_SCRIPT_MODULE})
set(LOADER_FUNCTION "Add${LOCALE_SCRIPT_MODULE}Scripts()")
```

If the function name in your loader `.cpp` does not match exactly, the linker will produce an unresolved symbol error at build time.

---

## 2. Module Directory Layout

Based on `mod-ale` as the reference module:

```
modules/mod-mymodule/
├── CMakeLists.txt           ← required; tells CMake about sources
├── src/
│   ├── mymodule_loader.cpp  ← defines Add<mod_mymodule>Scripts()
│   └── mymodule_SC.cpp      ← script class definition(s) + AddSC_*() function
├── conf/
│   └── mod-mymodule.conf.dist   ← optional; config file template
└── sql/
    ├── base/
    │   └── db_world/
    │       └── base.sql     ← optional; initial world DB data
    └── updates/             ← optional; incremental DB updates
```

**Notes:**
- `conf/` is auto-scanned by CMake during build. Any `.conf.dist` file found here is copied to the server's `etc/modules/` directory during `cmake --install`.
- `sql/` is not processed automatically by CMake. SQL files are applied manually or via the AzerothCore database importer.
- The directory name must start with `mod-` by convention (not enforced, but expected by tooling).

---

## 3. CMakeLists.txt — Minimal Template

This is based on `mod-ale/CMakeLists.txt` stripped of its Lua-specific content. Use this as the starting point for any module that has no external library dependencies.

```cmake
# modules/mod-dreamforge/CMakeLists.txt

# CollectSourceFiles() recursively finds all .cpp and .h files under the
# given directory. This is a macro defined in the AzerothCore CMake utilities.
# It appends results into the second argument (a list variable).
# You almost never need to list files manually — just put them in src/.
CollectSourceFiles(
    ${CMAKE_CURRENT_SOURCE_DIR}   # root: the module directory itself
    PRIVATE_SOURCES               # output variable
)

# CollectIncludeDirectories() finds all directories that contain .h files.
# The PUBLIC_INCLUDES variable is accumulated across all modules and eventually
# passed to target_include_directories(modules PUBLIC ...).
CollectIncludeDirectories(
    ${CMAKE_CURRENT_SOURCE_DIR}
    PUBLIC_INCLUDES
)
```

**That is the entire CMakeLists.txt for a simple module.** The `modules/CMakeLists.txt` parent file handles the rest: it calls `CollectSourceFiles` and `CollectIncludeDirectories` for each module, then combines everything into the `modules` static library:

```cmake
add_library(modules STATIC
    ModulesScriptLoader.h
    ${SCRIPT_MODULE_PRIVATE_SCRIPTLOADER}
    ${PRIVATE_SOURCES_MODULES})    # your module's files end up here

target_link_libraries(modules
  PRIVATE acore-core-interface
  PUBLIC  game-interface)
```

Your module code automatically gets access to all AzerothCore game headers because `modules` links against `game-interface`, which transitively provides every include directory in the core.

**If your module needs additional include directories** (e.g. a vendored header-only library bundled inside your module's `src/lib/` folder):

```cmake
# Add your module's own include subdirectory explicitly:
list(APPEND PUBLIC_INCLUDES ${CMAKE_CURRENT_SOURCE_DIR}/src/include)
```

**If your module needs to link an external library** (rare):

```cmake
target_link_libraries(modules PUBLIC my_external_lib)
```

Note: `target_link_libraries` on `modules` here works because `modules` is defined in the parent `CMakeLists.txt` and your module's `CMakeLists.txt` is included into that same scope.

---

## 4. The Script Loader Pattern

Every module must provide exactly one function with a name derived from its directory name. This is the entry point CMake generates a call to.

### Naming Rule

```
Directory name  →  Replace hyphens with underscores  →  Prefix "Add", suffix "Scripts()"
mod-dreamforge  →  mod_dreamforge                     →  Addmod_dreamforgeScripts()
mod-ale         →  mod_ale                            →  Addmod_aleScripts()
```

From the actual `ALE_loader.cpp`:
```cpp
// Forward declare every AddSC_*() function from your SC files:
void AddSC_ALE();

// The loader function — name MUST match the derived pattern:
void Addmod_aleScripts()
{
    AddSC_ALE();
}
```

### What Happens If the Name Is Wrong

CMake generates `void Addmod_dreamforgeScripts();` as a forward declaration and calls it in `AddModulesScripts()`. If your `.cpp` file defines `void AddDreamforgeScripts()` (different casing or missing the directory prefix), the linker will fail with:

```
undefined reference to `Addmod_dreamforgeScripts()'
```

There is no runtime check — it is a hard linker error.

### What AddSC_*() Does

The `AddSC_MyThing()` function constructs instances of your script classes using `new`. The AzerothCore scripting system works by registration at startup: every `ScriptObject` subclass registers itself in `ScriptRegistry<T>` upon construction. You allocate with `new` and never call `delete` — the ScriptMgr owns these objects.

```cpp
// In mymodule_SC.cpp:
void AddSC_MyModule()
{
    new MyPlayerScript();      // registers automatically in constructor
    new MyWorldScript();
    new MyCreatureScript();
}
```

---

## 5. All Script Types Available

These are all the script base classes available. Every header is included through `AllScriptsObjects.h`, which is itself included by `ScriptMgr.h`. Include `ScriptMgr.h` in your SC file and all of these are available.

Source: `src/server/game/Scripting/ScriptDefines/AllScriptsObjects.h`

| Base Class | Header | Purpose |
|---|---|---|
| `AccountScript` | AccountScript.h | Account login, logout, creation |
| `AchievementCriteriaScript` | AchievementCriteriaScript.h | Custom achievement criteria checks |
| `AchievementScript` | AchievementScript.h | Achievement completion hooks |
| `AllBattlegroundScript` / `BGScript` | AllBattlegroundScript.h | BG start/end/create/destroy |
| `AllCommandScript` / `CommandSC` | AllCommandScript.h | Chat command execution interception |
| `AllCreatureScript` | AllCreatureScript.h | Hooks on ALL creatures (not DB-bound) |
| `AllGameObjectScript` | AllGameObjectScript.h | Hooks on ALL game objects |
| `AllItemScript` | AllItemScript.h | Hooks on ALL items |
| `AllMapScript` | AllMapScript.h | Hooks on ALL maps |
| `AllSpellScript` / `SpellSC` | AllSpellScript.h | Hooks on ALL spells |
| `AreaTriggerScript` | AreaTriggerScript.h | Area trigger activation |
| `ArenaScript` | ArenaScript.h | Arena-specific events |
| `ArenaTeamScript` | ArenaTeamScript.h | Arena team events |
| `AuctionHouseScript` | AuctionHouseScript.h | Auction add/remove/complete/expire |
| `BattlefieldScript` | BattlefieldScript.h | Outdoor battlefield events |
| `BattlegroundMapScript` | BattlegroundMapScript.h | BG map lifecycle |
| `BattlegroundScript` | BattlegroundScript.h | Per-BG scripting |
| `CommandScript` | CommandScript.h | Register new chat commands |
| `ConditionScript` | ConditionScript.h | Custom condition evaluation |
| `CreatureScript` | CreatureScript.h | DB-bound creature gossip/quest/AI |
| `DatabaseScript` | DatabaseScript.h | Database worker thread hooks |
| `DynamicObjectScript` | DynamicObjectScript.h | Dynamic object updates |
| `ALEScript` | ALEScript.h | ALE-specific hooks (weather, area trigger via Lua bridge) |
| `FormulaScript` | FormulaScript.h | Honor/XP/damage formula overrides |
| `GameEventScript` | GameEventScript.h | Game event start/stop |
| `GameObjectScript` | GameObjectScript.h | DB-bound game object scripting |
| `GlobalScript` | GlobalScript.h | Misc global hooks |
| `GroupScript` | GroupScript.h | Group add/remove/disband/create |
| `GuildScript` | GuildScript.h | Guild add/remove/create/bank events |
| `InstanceMapScript` | InstanceMapScript.h | Instance script (boss tracking etc.) |
| `ItemScript` | ItemScript.h | DB-bound item use/equip/loot |
| `LootScript` | LootScript.h | Loot money |
| `MailScript` | MailScript.h | Mail sending hooks |
| `MiscScript` | MiscScript.h | Miscellaneous (dialog status) |
| `ModuleScript` | ModuleScript.h | Module identity registration (see section 9) |
| `MovementHandlerScript` | MovementHandlerScript.h | Player movement packet hooks |
| `OutdoorPvPScript` | OutdoorPvPScript.h | Outdoor PvP zone events |
| `PetScript` | PetScript.h | Pet world add |
| `PlayerScript` | PlayerScript.h | All player lifecycle hooks (see section 6) |
| `ServerScript` | ServerScript.h | Packet send/receive interception |
| `SpellScriptLoader` | SpellScriptLoader.h | Per-spell script (SpellScript/AuraScript) |
| `TicketScript` | TicketScript.h | GM ticket create/update/close/resolve |
| `TransportScript` | TransportScript.h | Transport (boat/zeppelin) events |
| `UnitScript` | UnitScript.h | Unit aura, damage, heal hooks |
| `VehicleScript` | VehicleScript.h | Vehicle install/uninstall/passengers |
| `WeatherScript` | WeatherScript.h | Weather state changes |
| `WorldMapScript` | WorldMapScript.h | World map script |
| `WorldObjectScript` | WorldObjectScript.h | WorldObject create/destroy/update |
| `WorldScript` | WorldScript.h | Server startup/shutdown/config/update |

### Hook Selection: Enabled Hooks Vector

Many script types accept a `std::vector<uint16>` in their constructor to declare which hooks the script actually uses. This is an optimization: the engine only calls a script for an event if it declared that hook. You must pass the relevant `XHOOK_Y` enum values.

```cpp
// Only fires on login and logout — other PlayerScript hooks are not called
class MyPlayerScript : public PlayerScript
{
public:
    MyPlayerScript() : PlayerScript("MyPlayerScript", {
        PLAYERHOOK_ON_LOGIN,
        PLAYERHOOK_ON_LOGOUT
    }) { }

    void OnPlayerLogin(Player* player) override { /* ... */ }
    void OnPlayerLogout(Player* player) override { /* ... */ }
};
```

If you pass an empty vector (the default), **no hooks fire**. You must explicitly list every hook you override.

### Spell Script Registration (SpellScriptLoader)

Spell scripts use a different registration pattern via macros defined in `SpellScriptLoader.h`:

```cpp
// Single spell script (SpellScript or AuraScript):
RegisterSpellScript(my_spell_SpellScript)

// Both SpellScript and AuraScript for the same spell ID:
RegisterSpellAndAuraScriptPair(my_spell_SpellScript, my_spell_AuraScript)

// With constructor arguments:
RegisterSpellScriptWithArgs(my_spell_SpellScript, "spell_name", arg1, arg2)
```

These macros expand to `new GenericSpellAndAuraScriptLoader<...>(...)`.

### Creature AI Registration

```cpp
// Simple: uses GenericCreatureScript wrapper
RegisterCreatureAI(my_creature_AI)

// With custom factory function:
RegisterCreatureAIWithFactory(my_creature_AI, my_factory_function)
```

---

## 6. PlayerScript — Complete Hook List

Source: `src/server/game/Scripting/ScriptDefines/PlayerScript.h`

All hooks are `virtual` with a no-op default body. Override only what you need. The hook enum constant to pass in the constructor vector is shown alongside each signature.

### Session / Lifecycle

```cpp
// PLAYERHOOK_ON_LOGIN
virtual void OnPlayerLogin(Player* player) { }

// PLAYERHOOK_ON_BEFORE_LOGOUT
virtual void OnPlayerBeforeLogout(Player* player) { }

// PLAYERHOOK_ON_LOGOUT
virtual void OnPlayerLogout(Player* player) { }

// PLAYERHOOK_ON_FIRST_LOGIN — character first ever login (after creation)
virtual void OnPlayerFirstLogin(Player* player) { }

// PLAYERHOOK_ON_CREATE — character creation
virtual void OnPlayerCreate(Player* player) { }

// PLAYERHOOK_ON_DELETE — character deletion
virtual void OnPlayerDelete(ObjectGuid guid, uint32 accountId) { }

// PLAYERHOOK_ON_FAILED_DELETE
virtual void OnPlayerFailedDelete(ObjectGuid guid, uint32 accountId) { }

// PLAYERHOOK_ON_SAVE
virtual void OnPlayerSave(Player* player) { }

// PLAYERHOOK_ON_LOAD_FROM_DB
virtual void OnPlayerLoadFromDB(Player* player) { }

// PLAYERHOOK_ON_SEND_INITIAL_PACKETS_BEFORE_ADD_TO_MAP
virtual void OnPlayerSendInitialPacketsBeforeAddToMap(Player* player, WorldPacket& data) { }
```

### Death / Resurrection

```cpp
// PLAYERHOOK_ON_PLAYER_JUST_DIED
virtual void OnPlayerJustDied(Player* player) { }

// PLAYERHOOK_ON_PLAYER_RELEASED_GHOST — clicking the release button
virtual void OnPlayerReleasedGhost(Player* player) { }

// PLAYERHOOK_ON_PLAYER_RESURRECT
virtual void OnPlayerResurrect(Player* player, float restore_percent, bool applySickness) { }

// PLAYERHOOK_CAN_RESURRECT — return false to prevent resurrection
virtual bool OnPlayerCanResurrect(Player* player) { return true; }

// PLAYERHOOK_CAN_REPOP_AT_GRAVEYARD — return false to prevent
[[nodiscard]] virtual bool OnPlayerCanRepopAtGraveyard(Player* player) { return true; }

// PLAYERHOOK_ON_BEFORE_CHOOSE_GRAVEYARD
virtual void OnPlayerBeforeChooseGraveyard(Player* player, TeamId teamId, bool nearCorpse, uint32& graveyardOverride) { }
```

### Leveling / Talents

```cpp
// PLAYERHOOK_ON_LEVEL_CHANGED
virtual void OnPlayerLevelChanged(Player* player, uint8 oldlevel) { }

// PLAYERHOOK_ON_CALCULATE_TALENTS_POINTS
virtual void OnPlayerCalculateTalentsPoints(Player const* player, uint32& talentPointsForLevel) { }

// PLAYERHOOK_ON_FREE_TALENT_POINTS_CHANGED
virtual void OnPlayerFreeTalentPointsChanged(Player* player, uint32 points) { }

// PLAYERHOOK_ON_TALENTS_RESET
virtual void OnPlayerTalentsReset(Player* player, bool noCost) { }

// PLAYERHOOK_ON_AFTER_SPEC_SLOT_CHANGED
virtual void OnPlayerAfterSpecSlotChanged(Player* player, uint8 newSlot) { }

// PLAYERHOOK_ON_BEFORE_INIT_TALENT_FOR_LEVEL
virtual void OnPlayerBeforeInitTalentForLevel(Player* player, uint8& level, uint32& talentPointsForLevel) { }

// PLAYERHOOK_ON_PLAYER_LEARN_TALENTS
virtual void OnPlayerLearnTalents(Player* player, uint32 talentId, uint32 talentRank, uint32 spellid) { }

// PLAYERHOOK_ON_LEARN_SPELL
virtual void OnPlayerLearnSpell(Player* player, uint32 spellID) { }

// PLAYERHOOK_ON_FORGOT_SPELL
virtual void OnPlayerForgotSpell(Player* player, uint32 spellID) { }

// PLAYERHOOK_ON_SET_MAX_LEVEL
virtual void OnPlayerSetMaxLevel(Player* player, uint32& maxPlayerLevel) { }

// PLAYERHOOK_ON_CAN_GIVE_LEVEL — return false to block level grant
virtual bool OnPlayerCanGiveLevel(Player* player, uint8 newLevel) { return true; }
```

### XP / Economy

```cpp
// PLAYERHOOK_ON_GIVE_EXP
virtual void OnPlayerGiveXP(Player* player, uint32& amount, Unit* victim, uint8 xpSource) { }

// PLAYERHOOK_SHOULD_BE_REWARDED_WITH_MONEY_INSTEAD_OF_EXP
virtual bool OnPlayerShouldBeRewardedWithMoneyInsteadOfExp(Player* player) { return false; }

// PLAYERHOOK_ON_MONEY_CHANGED
virtual void OnPlayerMoneyChanged(Player* player, int32& amount) { }

// PLAYERHOOK_ON_BEFORE_LOOT_MONEY
virtual void OnPlayerBeforeLootMoney(Player* player, Loot* loot) { }

// PLAYERHOOK_ON_REPUTATION_CHANGE — return false to cancel
virtual bool OnPlayerReputationChange(Player* player, uint32 factionID, int32& standing, bool incremental) { return true; }

// PLAYERHOOK_ON_REPUTATION_RANK_CHANGE
virtual void OnPlayerReputationRankChange(Player* player, uint32 factionID, ReputationRank newRank, ReputationRank oldRank, bool increased) { }

// PLAYERHOOK_ON_GIVE_REPUTATION
virtual void OnPlayerGiveReputation(Player* player, int32 factionID, float& amount, ReputationSource repSource) { }

// PLAYERHOOK_ON_GET_REPUTATION_PRICE_DISCOUNT (two overloads)
virtual void OnPlayerGetReputationPriceDiscount(Player const* player, Creature const* creature, float& discount) { }
virtual void OnPlayerGetReputationPriceDiscount(Player const* player, FactionTemplateEntry const* factionTemplate, float& discount) { }
```

### Combat

```cpp
// PLAYERHOOK_ON_PLAYER_ENTER_COMBAT
virtual void OnPlayerEnterCombat(Player* player, Unit* enemy) { }

// PLAYERHOOK_ON_PLAYER_LEAVE_COMBAT
virtual void OnPlayerLeaveCombat(Player* player) { }

// PLAYERHOOK_ON_PVP_KILL
virtual void OnPlayerPVPKill(Player* killer, Player* killed) { }

// PLAYERHOOK_ON_PLAYER_PVP_FLAG_CHANGE
virtual void OnPlayerPVPFlagChange(Player* player, bool state) { }

// PLAYERHOOK_ON_CREATURE_KILL
virtual void OnPlayerCreatureKill(Player* killer, Creature* killed) { }

// PLAYERHOOK_ON_CREATURE_KILLED_BY_PET
virtual void OnPlayerCreatureKilledByPet(Player* PetOwner, Creature* killed) { }

// PLAYERHOOK_ON_PLAYER_KILLED_BY_CREATURE
virtual void OnPlayerKilledByCreature(Creature* killer, Player* killed) { }

// PLAYERHOOK_ON_DUEL_REQUEST
virtual void OnPlayerDuelRequest(Player* target, Player* challenger) { }

// PLAYERHOOK_ON_DUEL_START
virtual void OnPlayerDuelStart(Player* player1, Player* player2) { }

// PLAYERHOOK_ON_DUEL_END
virtual void OnPlayerDuelEnd(Player* winner, Player* loser, DuelCompleteType type) { }

// PLAYERHOOK_ON_SPELL_CAST
virtual void OnPlayerSpellCast(Player* player, Spell* spell, bool skipCheck) { }

// PLAYERHOOK_ON_VICTIM_REWARD_BEFORE
virtual void OnPlayerVictimRewardBefore(Player* player, Player* victim, uint32& killer_title, int32& victim_rank) { }

// PLAYERHOOK_ON_VICTIM_REWARD_AFTER
virtual void OnPlayerVictimRewardAfter(Player* player, Player* victim, uint32& killer_title, int32& victim_rank, float& honor_f) { }
```

### Items

```cpp
// PLAYERHOOK_ON_EQUIP
virtual void OnPlayerEquip(Player* player, Item* it, uint8 bag, uint8 slot, bool update) { }

// PLAYERHOOK_ON_UNEQUIP_ITEM
virtual void OnPlayerUnequip(Player* player, Item* it) { }

// PLAYERHOOK_ON_LOOT_ITEM
virtual void OnPlayerLootItem(Player* player, Item* item, uint32 count, ObjectGuid lootguid) { }

// PLAYERHOOK_ON_BEFORE_FILL_QUEST_LOOT_ITEM
virtual void OnPlayerBeforeFillQuestLootItem(Player* player, LootItem& item) { }

// PLAYERHOOK_ON_STORE_NEW_ITEM — after looting (includes master loot)
virtual void OnPlayerStoreNewItem(Player* player, Item* item, uint32 count) { }

// PLAYERHOOK_ON_CREATE_ITEM — after crafting
virtual void OnPlayerCreateItem(Player* player, Item* item, uint32 count) { }

// PLAYERHOOK_ON_QUEST_REWARD_ITEM
virtual void OnPlayerQuestRewardItem(Player* player, Item* item, uint32 count) { }

// PLAYERHOOK_ON_GROUP_ROLL_REWARD_ITEM
virtual void OnPlayerGroupRollRewardItem(Player* player, Item* item, uint32 count, RollVote voteType, Roll* roll) { }

// PLAYERHOOK_ON_BEFORE_OPEN_ITEM — return false to cancel open
[[nodiscard]] virtual bool OnPlayerBeforeOpenItem(Player* player, Item* item) { return true; }

// PLAYERHOOK_CAN_USE_ITEM — return false to block use
[[nodiscard]] virtual bool OnPlayerCanUseItem(Player* player, ItemTemplate const* proto, InventoryResult& result) { return true; }

// PLAYERHOOK_CAN_EQUIP_ITEM
[[nodiscard]] virtual bool OnPlayerCanEquipItem(Player* player, uint8 slot, uint16& dest, Item* pItem, bool swap, bool not_loading) { return true; }

// PLAYERHOOK_CAN_UNEQUIP_ITEM
[[nodiscard]] virtual bool OnPlayerCanUnequipItem(Player* player, uint16 pos, bool swap) { return true; }

// PLAYERHOOK_CAN_SAVE_EQUIP_NEW_ITEM
[[nodiscard]] virtual bool OnPlayerCanSaveEquipNewItem(Player* player, Item* item, uint16 pos, bool update) { return true; }

// PLAYERHOOK_CAN_APPLY_ENCHANTMENT
[[nodiscard]] virtual bool OnPlayerCanApplyEnchantment(Player* player, Item* item, EnchantmentSlot slot, bool apply, bool apply_dur, bool ignore_condition) { return true; }

// PLAYERHOOK_ON_BEFORE_BUY_ITEM_FROM_VENDOR
virtual void OnPlayerBeforeBuyItemFromVendor(Player* player, ObjectGuid vendorguid, uint32 vendorslot, uint32& item, uint8 count, uint8 bag, uint8 slot) { }

// PLAYERHOOK_ON_BEFORE_STORE_OR_EQUIP_NEW_ITEM
virtual void OnPlayerBeforeStoreOrEquipNewItem(Player* player, uint32 vendorslot, uint32& item, uint8 count, uint8 bag, uint8 slot, ItemTemplate const* pProto, Creature* pVendor, VendorItem const* crItem, bool bStore) { }

// PLAYERHOOK_ON_AFTER_STORE_OR_EQUIP_NEW_ITEM
virtual void OnPlayerAfterStoreOrEquipNewItem(Player* player, uint32 vendorslot, Item* item, uint8 count, uint8 bag, uint8 slot, ItemTemplate const* pProto, Creature* pVendor, VendorItem const* crItem, bool bStore) { }

// PLAYERHOOK_CAN_PLACE_AUCTION_BID
[[nodiscard]] virtual bool OnPlayerCanPlaceAuctionBid(Player* player, AuctionEntry* auction) { return true; }

// PLAYERHOOK_CAN_SELL_ITEM
[[nodiscard]] virtual bool OnPlayerCanSellItem(Player* player, Item* item, Creature* creature) { return true; }

// PLAYERHOOK_ON_SEND_LIST_INVENTORY
virtual void OnPlayerSendListInventory(Player* player, ObjectGuid vendorGuid, uint32& vendorEntry) { }

// PLAYERHOOK_ON_AFTER_CREATURE_LOOT
virtual void OnPlayerAfterCreatureLoot(Player* player) { }

// PLAYERHOOK_ON_AFTER_CREATURE_LOOT_MONEY
virtual void OnPlayerAfterCreatureLootMoney(Player* player) { }
```

### Quests

```cpp
// PLAYERHOOK_ON_PLAYER_COMPLETE_QUEST
virtual void OnPlayerCompleteQuest(Player* player, Quest const* quest) { }

// PLAYERHOOK_ON_BEFORE_QUEST_COMPLETE — return false to block
[[nodiscard]] virtual bool OnPlayerBeforeQuestComplete(Player* player, uint32 quest_id) { return true; }

// PLAYERHOOK_ON_QUEST_COMPUTE_EXP
virtual void OnPlayerQuestComputeXP(Player* player, Quest const* quest, uint32& xpValue) { }

// PLAYERHOOK_ON_QUEST_ABANDON
virtual void OnPlayerQuestAbandon(Player* player, uint32 questId) { }

// PLAYERHOOK_ON_GET_QUEST_RATE
virtual void OnPlayerGetQuestRate(Player* player, float& result) { }

// PLAYERHOOK_PASSED_QUEST_KILLED_MONSTER_CREDIT
[[nodiscard]] virtual bool OnPlayerPassedQuestKilledMonsterCredit(Player* player, Quest const* qinfo, uint32 entry, uint32 real_entry, ObjectGuid guid) { return true; }

// PLAYERHOOK_ON_REWARD_KILL_REWARDER
virtual void OnPlayerRewardKillRewarder(Player* player, KillRewarder* rewarder, bool isDungeon, float& rate) { }
```

### Chat / Communication

```cpp
// PLAYERHOOK_ON_BEFORE_SEND_CHAT_MESSAGE — modify outgoing message
virtual void OnPlayerBeforeSendChatMessage(Player* player, uint32& type, uint32& lang, std::string& msg) { }

// PLAYERHOOK_CAN_PLAYER_USE_CHAT — general say/yell/emote; return false to block
[[nodiscard]] virtual bool OnPlayerCanUseChat(Player* player, uint32 type, uint32 language, std::string& msg) { return true; }

// PLAYERHOOK_CAN_PLAYER_USE_PRIVATE_CHAT — whisper; return false to block
[[nodiscard]] virtual bool OnPlayerCanUseChat(Player* player, uint32 type, uint32 language, std::string& msg, Player* receiver) { return true; }

// PLAYERHOOK_CAN_PLAYER_USE_GROUP_CHAT — return false to block
[[nodiscard]] virtual bool OnPlayerCanUseChat(Player* player, uint32 type, uint32 language, std::string& msg, Group* group) { return true; }

// PLAYERHOOK_CAN_PLAYER_USE_GUILD_CHAT — return false to block
[[nodiscard]] virtual bool OnPlayerCanUseChat(Player* player, uint32 type, uint32 language, std::string& msg, Guild* guild) { return true; }

// PLAYERHOOK_CAN_PLAYER_USE_CHANNEL_CHAT — return false to block
[[nodiscard]] virtual bool OnPlayerCanUseChat(Player* player, uint32 type, uint32 language, std::string& msg, Channel* channel) { return true; }

// PLAYERHOOK_CAN_SEND_MAIL — return false to block mail
[[nodiscard]] virtual bool OnPlayerCanSendMail(Player* player, ObjectGuid receiverGuid, ObjectGuid mailbox, std::string& subject, std::string& body, uint32 money, uint32 COD, Item* item) { return true; }

// PLAYERHOOK_ON_EMOTE
virtual void OnPlayerEmote(Player* player, uint32 emote) { }

// PLAYERHOOK_ON_TEXT_EMOTE
virtual void OnPlayerTextEmote(Player* player, uint32 textEmote, uint32 emoteNum, ObjectGuid guid) { }
```

### Navigation / Zones

```cpp
// PLAYERHOOK_ON_UPDATE_ZONE
virtual void OnPlayerUpdateZone(Player* player, uint32 newZone, uint32 newArea) { }

// PLAYERHOOK_ON_UPDATE_AREA
virtual void OnPlayerUpdateArea(Player* player, uint32 oldArea, uint32 newArea) { }

// PLAYERHOOK_ON_MAP_CHANGED
virtual void OnPlayerMapChanged(Player* player) { }

// PLAYERHOOK_ON_BEFORE_TELEPORT — return false to cancel teleport
[[nodiscard]] virtual bool OnPlayerBeforeTeleport(Player* player, uint32 mapid, float x, float y, float z, float orientation, uint32 options, Unit* target) { return true; }

// PLAYERHOOK_ON_UPDATE_FACTION
virtual void OnPlayerUpdateFaction(Player* player) { }

// PLAYERHOOK_ON_BIND_TO_INSTANCE
virtual void OnPlayerBindToInstance(Player* player, Difficulty difficulty, uint32 mapId, bool permanent) { }

// PLAYERHOOK_CAN_ENTER_MAP — return false to block
[[nodiscard]] virtual bool OnPlayerCanEnterMap(Player* player, MapEntry const* entry, InstanceTemplate const* instance, MapDifficulty const* mapDiff, bool loginCheck) { return true; }

// PLAYERHOOK_ON_CAN_PLAYER_FLY_IN_ZONE — return false to prevent flight
[[nodiscard]] virtual bool OnPlayerCanFlyInZone(Player* player, uint32 mapId, uint32 zoneId, SpellInfo const* bySpell) { return true; }
```

### Groups / Social

```cpp
// PLAYERHOOK_CAN_GROUP_INVITE — return false to block group invite
[[nodiscard]] virtual bool OnPlayerCanGroupInvite(Player* player, std::string& membername) { return true; }

// PLAYERHOOK_CAN_GROUP_ACCEPT
[[nodiscard]] virtual bool OnPlayerCanGroupAccept(Player* player, Group* group) { return true; }

// PLAYERHOOK_CAN_JOIN_LFG
[[nodiscard]] virtual bool OnPlayerCanJoinLfg(Player* player, uint8 roles, std::set<uint32>& dungeons, const std::string& comment) { return true; }

// PLAYERHOOK_CAN_INIT_TRADE — return false to block trade
[[nodiscard]] virtual bool OnPlayerCanInitTrade(Player* player, Player* target) { return true; }

// PLAYERHOOK_CAN_SET_TRADE_ITEM
[[nodiscard]] virtual bool OnPlayerCanSetTradeItem(Player* player, Item* tradedItem, uint8 tradeSlot) { return true; }
```

### Battleground / Arena

```cpp
// PLAYERHOOK_ON_BATTLEGROUND_DESERTION
virtual void OnPlayerBattlegroundDesertion(Player* player, BattlegroundDesertionType const desertionType) { }

// PLAYERHOOK_ON_ADD_TO_BATTLEGROUND
virtual void OnPlayerAddToBattleground(Player* player, Battleground* bg) { }

// PLAYERHOOK_ON_REMOVE_FROM_BATTLEGROUND
virtual void OnPlayerRemoveFromBattleground(Player* player, Battleground* bg) { }

// PLAYERHOOK_ON_PLAYER_JOIN_BG
virtual void OnPlayerJoinBG(Player* player) { }

// PLAYERHOOK_ON_PLAYER_JOIN_ARENA
virtual void OnPlayerJoinArena(Player* player) { }

// PLAYERHOOK_CAN_JOIN_IN_BATTLEGROUND_QUEUE
[[nodiscard]] virtual bool OnPlayerCanJoinInBattlegroundQueue(Player* player, ObjectGuid BattlemasterGuid, BattlegroundTypeId BGTypeID, uint8 joinAsGroup, GroupJoinBattlegroundResult& err) { return true; }

// PLAYERHOOK_CAN_JOIN_IN_ARENA_QUEUE
[[nodiscard]] virtual bool OnPlayerCanJoinInArenaQueue(Player* player, ObjectGuid BattlemasterGuid, uint8 arenaslot, BattlegroundTypeId BGTypeID, uint8 joinAsGroup, uint8 IsRated, GroupJoinBattlegroundResult& err) { return true; }

// PLAYERHOOK_CAN_BATTLEFIELD_PORT
[[nodiscard]] virtual bool OnPlayerCanBattleFieldPort(Player* player, uint8 arenaType, BattlegroundTypeId BGTypeID, uint8 action) { return true; }
```

### Achievements

```cpp
// PLAYERHOOK_ON_ACHI_COMPLETE
virtual void OnPlayerAchievementComplete(Player* player, AchievementEntry const* achievement) { }

// PLAYERHOOK_ON_BEFORE_ACHI_COMPLETE — return false to disable
virtual bool OnPlayerBeforeAchievementComplete(Player* player, AchievementEntry const* achievement) { return true; }

// PLAYERHOOK_ON_CRITERIA_PROGRESS
virtual void OnPlayerCriteriaProgress(Player* player, AchievementCriteriaEntry const* criteria) { }

// PLAYERHOOK_ON_BEFORE_CRITERIA_PROGRESS
virtual bool OnPlayerBeforeCriteriaProgress(Player* player, AchievementCriteriaEntry const* criteria) { return true; }

// PLAYERHOOK_ON_ACHI_SAVE
virtual void OnPlayerAchievementSave(CharacterDatabaseTransaction trans, Player* player, uint16 achId, CompletedAchievementData achiData) { }

// PLAYERHOOK_ON_CRITERIA_SAVE
virtual void OnPlayerCriteriaSave(CharacterDatabaseTransaction trans, Player* player, uint16 achId, CriteriaProgress criteriaData) { }
```

### Skills

```cpp
// PLAYERHOOK_ON_CAN_UPDATE_SKILL — return false to block skill update
virtual bool OnPlayerCanUpdateSkill(Player* player, uint32 skillId) { return true; }

// PLAYERHOOK_ON_BEFORE_UPDATE_SKILL
virtual void OnPlayerBeforeUpdateSkill(Player* player, uint32 skillId, uint32& value, uint32 max, uint32 step) { }

// PLAYERHOOK_ON_UPDATE_SKILL
virtual void OnPlayerUpdateSkill(Player* player, uint32 skillId, uint32 value, uint32 max, uint32 step, uint32 newValue) { }

// PLAYERHOOK_ON_UPDATE_GATHERING_SKILL
virtual void OnPlayerUpdateGatheringSkill(Player* player, uint32 skill_id, uint32 current, uint32 gray, uint32 green, uint32 yellow, uint32& gain) { }

// PLAYERHOOK_ON_UPDATE_CRAFTING_SKILL
virtual void OnPlayerUpdateCraftingSkill(Player* player, SkillLineAbilityEntry const* skill, uint32 current_level, uint32& gain) { }

// PLAYERHOOK_ON_UPDATE_FISHING_SKILL
[[nodiscard]] virtual bool OnPlayerUpdateFishingSkill(Player* player, int32 skill, int32 zone_skill, int32 chance, int32 roll) { return true; }

// PLAYERHOOK_ON_GET_MAX_SKILL_VALUE
virtual void OnPlayerGetMaxSkillValue(Player* player, uint32 skill, int32& result, bool IsPure) { }

// PLAYERHOOK_ON_GET_MAX_SKILL_VALUE_FOR_LEVEL
virtual void OnPlayerGetMaxSkillValueForLevel(Player* player, uint16& result) { }
```

### Stats / Formulas

```cpp
// PLAYERHOOK_ON_AFTER_UPDATE_MAX_POWER
virtual void OnPlayerAfterUpdateMaxPower(Player* player, Powers& power, float& value) { }

// PLAYERHOOK_ON_AFTER_UPDATE_MAX_HEALTH
virtual void OnPlayerAfterUpdateMaxHealth(Player* player, float& value) { }

// PLAYERHOOK_ON_BEFORE_UPDATE_ATTACK_POWER_AND_DAMAGE
virtual void OnPlayerBeforeUpdateAttackPowerAndDamage(Player* player, float& level, float& val2, bool ranged) { }

// PLAYERHOOK_ON_AFTER_UPDATE_ATTACK_POWER_AND_DAMAGE
virtual void OnPlayerAfterUpdateAttackPowerAndDamage(Player* player, float& level, float& base_attPower, float& attPowerMod, float& attPowerMultiplier, bool ranged) { }

// PLAYERHOOK_ON_CUSTOM_SCALING_STAT_VALUE_BEFORE
virtual void OnPlayerCustomScalingStatValueBefore(Player* player, ItemTemplate const* proto, uint8 slot, bool apply, uint32& CustomScalingStatValue) { }

// PLAYERHOOK_ON_CUSTOM_SCALING_STAT_VALUE
virtual void OnPlayerCustomScalingStatValue(Player* player, ItemTemplate const* proto, uint32& statType, int32& val, uint8 itemProtoStatNumber, uint32 ScalingStatValue, ScalingStatValuesEntry const* ssv) { }

// PLAYERHOOK_ON_APPLY_WEAPON_DAMAGE
virtual void OnPlayerApplyWeaponDamage(Player* player, uint8 slot, ItemTemplate const* proto, float& minDamage, float& maxDamage, uint8 damageIndex) { }
```

### Gossip

```cpp
// PLAYERHOOK_ON_GOSSIP_SELECT
virtual void OnPlayerGossipSelect(Player* player, uint32 menu_id, uint32 sender, uint32 action) { }

// PLAYERHOOK_ON_GOSSIP_SELECT_CODE
virtual void OnPlayerGossipSelectCode(Player* player, uint32 menu_id, uint32 sender, uint32 action, const char* code) { }
```

### Misc

```cpp
// PLAYERHOOK_ON_BEFORE_UPDATE / PLAYERHOOK_ON_UPDATE
virtual void OnPlayerBeforeUpdate(Player* player, uint32 p_time) { }
virtual void OnPlayerUpdate(Player* player, uint32 p_time) { }

// PLAYERHOOK_ON_BEFORE_DURABILITY_REPAIR
virtual void OnPlayerBeforeDurabilityRepair(Player* player, ObjectGuid npcGUID, ObjectGuid itemGUID, float& discountMod, uint8 guildBank) { }

// PLAYERHOOK_ON_QUEUE_RANDOM_DUNGEON
virtual void OnPlayerQueueRandomDungeon(Player* player, uint32& rDungeonId) { }

// PLAYERHOOK_ON_DELETE_FROM_DB
virtual void OnPlayerDeleteFromDB(CharacterDatabaseTransaction trans, uint32 guid) { }

// PLAYERHOOK_ON_BEING_CHARMED
virtual void OnPlayerBeingCharmed(Player* player, Unit* charmer, uint32 oldFactionId, uint32 newFactionId) { }

// PLAYERHOOK_ON_FFA_PVP_STATE_UPDATE
virtual void OnPlayerFfaPvpStateUpdate(Player* player, bool result) { }

// PLAYERHOOK_ON_SET_SERVER_SIDE_VISIBILITY
virtual void OnPlayerSetServerSideVisibility(Player* player, ServerSideVisibilityType& type, AccountTypes& sec) { }

// PLAYERHOOK_ON_SET_SERVER_SIDE_VISIBILITY_DETECT
virtual void OnPlayerSetServerSideVisibilityDetect(Player* player, ServerSideVisibilityType& type, AccountTypes& sec) { }

// Anticheat system hooks (passive — for anticheat modules):
virtual void AnticheatSetCanFlybyServer(Player* player, bool apply) { }
virtual void AnticheatSetUnderACKmount(Player* player) { }
virtual void AnticheatSetRootACKUpd(Player* player) { }
virtual void AnticheatSetJumpingbyOpcode(Player* player, bool jump) { }
virtual void AnticheatUpdateMovementInfo(Player* player, MovementInfo const& movementInfo) { }
[[nodiscard]] virtual bool AnticheatHandleDoubleJump(Player* player, Unit* mover) { return true; }
[[nodiscard]] virtual bool AnticheatCheckMovementInfo(Player* player, MovementInfo const& movementInfo, Unit* mover, bool jump) { return true; }
```

---

## 7. WorldScript — Complete Hook List

Source: `src/server/game/Scripting/ScriptDefines/WorldScript.h`

WorldScript fires at server lifecycle events. Use the `WORLDHOOK_*` enum values in the constructor vector.

```cpp
class MyWorldScript : public WorldScript
{
public:
    MyWorldScript() : WorldScript("MyWorldScript", {
        WORLDHOOK_ON_STARTUP,
        WORLDHOOK_ON_SHUTDOWN,
        WORLDHOOK_ON_UPDATE,
        WORLDHOOK_ON_AFTER_CONFIG_LOAD,
        WORLDHOOK_ON_BEFORE_CONFIG_LOAD,
    }) { }

    // Called when the world opens or closes to players
    void OnOpenStateChange(bool open) override { }      // WORLDHOOK_ON_OPEN_STATE_CHANGE

    // Called BEFORE config is (re)loaded — use this to initialize from config
    void OnBeforeConfigLoad(bool reload) override { }   // WORLDHOOK_ON_BEFORE_CONFIG_LOAD

    // Called AFTER config is (re)loaded
    void OnAfterConfigLoad(bool reload) override { }    // WORLDHOOK_ON_AFTER_CONFIG_LOAD

    // Called when loading custom database tables (worldserver startup)
    void OnLoadCustomDatabaseTable() override { }       // WORLDHOOK_ON_LOAD_CUSTOM_DATABASE_TABLE

    // Called before MOTD is changed
    void OnMotdChange(std::string& newMotd, LocaleConstant& locale) override { }  // WORLDHOOK_ON_MOTD_CHANGE

    // Called when shutdown is initiated
    void OnShutdownInitiate(ShutdownExitCode code, ShutdownMask mask) override { }  // WORLDHOOK_ON_SHUTDOWN_INITIATE

    // Called when shutdown is cancelled
    void OnShutdownCancel() override { }                // WORLDHOOK_ON_SHUTDOWN_CANCEL

    // Called every world tick — keep this fast
    void OnUpdate(uint32 diff) override { }             // WORLDHOOK_ON_UPDATE

    // Called when the world starts (after DB load, before players connect)
    void OnStartup() override { }                       // WORLDHOOK_ON_STARTUP

    // Called when the world shuts down
    void OnShutdown() override { }                      // WORLDHOOK_ON_SHUTDOWN

    // Called after all maps are unloaded from core
    void OnAfterUnloadAllMaps() override { }            // WORLDHOOK_ON_AFTER_UNLOAD_ALL_MAPS

    // Called before finalizing player world session (can modify client cache version)
    void OnBeforeFinalizePlayerWorldSession(uint32& cacheVersion) override { }  // WORLDHOOK_ON_BEFORE_FINALIZE_PLAYER_WORLD_SESSION

    // Called after all scripts are loaded and before world is fully initialized
    void OnBeforeWorldInitialized() override { }        // WORLDHOOK_ON_BEFORE_WORLD_INITIALIZED
};
```

---

## 8. CreatureScript — Hook List

Source: `src/server/game/Scripting/ScriptDefines/CreatureScript.h`

`CreatureScript` is **database-bound**: it is identified by a name string that must match `ScriptName` in `creature_template`. The scripted creature's entry in the DB must reference this name.

```cpp
class my_npc_example : public CreatureScript
{
public:
    my_npc_example() : CreatureScript("my_npc_example") { }

    // Called when a player opens gossip dialog with this creature
    bool OnGossipHello(Player* player, Creature* creature) override { return false; }

    // Called when a player selects a gossip item
    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override { return false; }

    // Called when a player selects gossip with a text code entry
    bool OnGossipSelectCode(Player* player, Creature* creature, uint32 sender, uint32 action, const char* code) override { return false; }

    // Called when a player accepts a quest from this creature
    bool OnQuestAccept(Player* player, Creature* creature, Quest const* quest) override { return false; }

    // Called when player selects a quest in the quest menu
    bool OnQuestSelect(Player* player, Creature* creature, Quest const* quest) override { return false; }

    // Called when player completes a quest with this creature
    bool OnQuestComplete(Player* player, Creature* creature, Quest const* quest) override { return false; }

    // Called when player selects a quest reward
    bool OnQuestReward(Player* player, Creature* creature, Quest const* quest, uint32 opt) override { return false; }

    // Returns a dialog status for the NPC icon above the creature
    uint32 GetDialogStatus(Player* player, Creature* creature) override { return DIALOG_STATUS_SCRIPTED_NO_STATUS; }

    // Returns a CreatureAI* for this creature
    CreatureAI* GetAI(Creature* creature) const override { return nullptr; }

    // Called when FFA PvP state changes on creature
    void OnFfaPvpStateUpdate(Creature* creature, bool result) override { }
};

// Alternative: use the template helper for AI-only scripts (no gossip/quest hooks needed)
// This is cleaner when you only need to provide an AI:
//   RegisterCreatureAI(my_creature_AI_class)
// Equivalent to:
//   new GenericCreatureScript<my_creature_AI_class>("my_creature_AI_class")
```

---

## 9. ModuleScript

Source: `src/server/game/Scripting/ScriptDefines/ModuleScript.h`

`ModuleScript` is a minimal extension point with no built-in virtual hooks of its own:

```cpp
// This class can be used to be extended by Modules
// creating their own custom hooks inside the module itself
class ModuleScript : public ScriptObject
{
protected:
    ModuleScript(const char* name);
};
```

Its purpose is to serve as a base class when a module wants to expose a custom scripting interface to other modules. For example, if your module defines a system that other modules could extend, you would create `class MyModuleScript : public ModuleScript` with your custom virtual methods, define a registry and dispatcher for it, and let other modules inherit from `MyModuleScript`.

For server startup/shutdown hooks, use `WorldScript` instead. `ModuleScript` is not needed for typical single-module development.

---

## 10. Config System in Modules

### The .conf.dist File

Place a `.conf.dist` file in your module's `conf/` directory:

```
modules/mod-dreamforge/conf/mod-dreamforge.conf.dist
```

During `cmake --install`, the build system copies all `.conf.dist` files from every enabled module's `conf/` directory into the server's `etc/modules/` directory. On first install (when `AC_ENABLE_CONF_COPY_ON_INSTALL` is set), the `.conf.dist` is also copied to `.conf` as the active config file.

Example `.conf.dist` content:

```ini
########################################
# Dreamforge Module Configuration
########################################

[worldserver]

# Enable the Dreamforge module
# Default: 1 (enabled)
Dreamforge.Enable = 1

# Welcome message shown on login
# Default: "Welcome to the server!"
Dreamforge.LoginMessage = "Welcome to the server!"

# Bonus XP multiplier for new characters
# Default: 1.0
Dreamforge.NewCharXPRate = 1.0
```

### Reading Config Values in C++

Include: `#include "Config.h"` (located at `src/common/Configuration/Config.h`)

The `sConfigMgr` macro expands to `ConfigMgr::instance()`. It is defined at line 93 of `Config.h`:
```cpp
#define sConfigMgr ConfigMgr::instance()
```

```cpp
#include "Config.h"

// bool — second arg is the default if key is missing
bool enabled = sConfigMgr->GetOption<bool>("Dreamforge.Enable", true);

// uint32
uint32 someValue = sConfigMgr->GetOption<uint32>("Dreamforge.SomeValue", 0);

// int32
int32 someInt = sConfigMgr->GetOption<int32>("Dreamforge.SomeInt", -1);

// float
float rate = sConfigMgr->GetOption<float>("Dreamforge.NewCharXPRate", 1.0f);

// std::string
std::string msg = sConfigMgr->GetOption<std::string>("Dreamforge.LoginMessage", "Welcome!");
```

### When to Read Config

Read config values in `WorldScript::OnBeforeConfigLoad(bool reload)`. This hook fires on both initial startup and on every `/reload config`. The `reload` parameter is `false` on startup, `true` on hot reload.

```cpp
class DreamforgeWorldScript : public WorldScript
{
public:
    DreamforgeWorldScript() : WorldScript("DreamforgeWorldScript", {
        WORLDHOOK_ON_BEFORE_CONFIG_LOAD
    }) { }

    void OnBeforeConfigLoad(bool /*reload*/) override
    {
        g_enabled  = sConfigMgr->GetOption<bool>("Dreamforge.Enable", true);
        g_loginMsg = sConfigMgr->GetOption<std::string>("Dreamforge.LoginMessage", "Welcome!");
    }
};
```

---

## 11. Complete Working Module Example: mod-dreamforge

This module sends a greeting message in system chat when a player logs in. It reads the message text from a config option.

### File: `modules/mod-dreamforge/CMakeLists.txt`

```cmake
# modules/mod-dreamforge/CMakeLists.txt
#
# No project() call. No add_library(). No target_link_libraries().
# The parent modules/CMakeLists.txt handles all of that.
# Your job is only to declare sources and include directories.

# Collect all .cpp and .h files from this module directory tree.
# CollectSourceFiles appends to the PRIVATE_SOURCES variable which the
# parent CMakeLists then folds into the PRIVATE_SOURCES_MODULES list,
# which is compiled into the 'modules' static library.
CollectSourceFiles(
    ${CMAKE_CURRENT_SOURCE_DIR}
    PRIVATE_SOURCES
)

# Collect all directories containing .h files so they are added to
# the modules library's include path.
CollectIncludeDirectories(
    ${CMAKE_CURRENT_SOURCE_DIR}
    PUBLIC_INCLUDES
)
```

### File: `modules/mod-dreamforge/src/mod_dreamforge_loader.cpp`

```cpp
/*
 * mod_dreamforge_loader.cpp
 *
 * Defines the module entry point. The function name is derived mechanically
 * from the directory name:
 *
 *   Directory:     mod-dreamforge
 *   Hyphens->_:    mod_dreamforge
 *   Final name:    Addmod_dreamforgeScripts()
 *
 * CMake generates a forward declaration and call site for this exact name
 * in the auto-generated ModulesLoader.cpp. If the name does not match,
 * the linker will fail with "undefined reference to Addmod_dreamforgeScripts".
 */

// Forward-declare every AddSC_*() function defined in other .cpp files
// in this module. One declaration per function.
void AddSC_mod_dreamforge();

// The entry point — called once at server startup by the generated loader.
void Addmod_dreamforgeScripts()
{
    AddSC_mod_dreamforge();
}
```

### File: `modules/mod-dreamforge/src/mod_dreamforge_SC.cpp`

```cpp
/*
 * mod_dreamforge_SC.cpp
 *
 * Script classes and their registration function.
 */

#include "Config.h"     // sConfigMgr and GetOption<T>()
#include "Player.h"     // Player class and ChatHandler
#include "ScriptMgr.h"  // PlayerScript, WorldScript, and all other script types
                        // (ScriptMgr.h includes AllScriptsObjects.h which includes
                        //  all individual script type headers)

// -----------------------------------------------------------------------
// Module-level config cache.
// Read once per config load in OnBeforeConfigLoad.
// Static variables scoped to this translation unit keep the pattern simple.
// -----------------------------------------------------------------------
static bool        g_enabled  = true;
static std::string g_loginMsg = "Welcome to the server!";

// -----------------------------------------------------------------------
// WorldScript: reads config on startup and on every /reload config.
// -----------------------------------------------------------------------
class DreamforgeWorldScript : public WorldScript
{
public:
    // The string "DreamforgeWorldScript" is the internal script name.
    // It must be globally unique across all registered scripts.
    //
    // The second constructor argument is the enabled-hooks list.
    // Only hooks listed here will ever fire for this object.
    // An empty list means no hooks fire at all.
    DreamforgeWorldScript() : WorldScript("DreamforgeWorldScript", {
        WORLDHOOK_ON_BEFORE_CONFIG_LOAD
    }) { }

    // Called before config is loaded — fires on startup (reload=false)
    // and on every /reload config (reload=true).
    void OnBeforeConfigLoad(bool /*reload*/) override
    {
        g_enabled  = sConfigMgr->GetOption<bool>("Dreamforge.Enable", true);
        g_loginMsg = sConfigMgr->GetOption<std::string>(
            "Dreamforge.LoginMessage", "Welcome to the server!");
    }
};

// -----------------------------------------------------------------------
// PlayerScript: fires on player events.
// -----------------------------------------------------------------------
class DreamforgePlayerScript : public PlayerScript
{
public:
    // List only the hooks you override. Any hook not listed here is never
    // dispatched to this object, avoiding unnecessary virtual call overhead.
    DreamforgePlayerScript() : PlayerScript("DreamforgePlayerScript", {
        PLAYERHOOK_ON_LOGIN
    }) { }

    // Called after a player fully logs in (character placed in world,
    // loading screen complete, ready to play).
    void OnPlayerLogin(Player* player) override
    {
        // Always guard with the enable flag.
        if (!g_enabled)
            return;

        // ChatHandler wraps a player's WorldSession to send them messages.
        // PSendSysMessage sends a formatted system message (printf-style).
        // The message appears in the player's chat frame as a system message.
        // SendSysMessage sends a literal const char* without formatting.
        ChatHandler(player->GetSession()).PSendSysMessage("%s", g_loginMsg.c_str());
    }
};

// -----------------------------------------------------------------------
// Registration function.
// Name pattern: AddSC_<anything> — called by the loader function above.
// Construct each script with 'new'. The ScriptMgr takes ownership.
// Never store these pointers or call delete on them.
// -----------------------------------------------------------------------
void AddSC_mod_dreamforge()
{
    new DreamforgeWorldScript();
    new DreamforgePlayerScript();
}
```

### File: `modules/mod-dreamforge/conf/mod-dreamforge.conf.dist`

```ini
########################################
# mod-dreamforge configuration
########################################

[worldserver]

#
#    Dreamforge.Enable
#        Description: Enable or disable the mod-dreamforge module entirely.
#        Default:     1 (enabled)
#
Dreamforge.Enable = 1

#
#    Dreamforge.LoginMessage
#        Description: System message sent to a player when they log in.
#        Default:     "Welcome to the server!"
#
Dreamforge.LoginMessage = "Welcome to the server!"
```

### Line-by-Line Explanation

**`CMakeLists.txt`**

- `CollectSourceFiles(${CMAKE_CURRENT_SOURCE_DIR} PRIVATE_SOURCES)` — Finds all `.cpp`/`.h` files recursively under this directory. The result is appended to `PRIVATE_SOURCES_MODULES` by the parent file and compiled into the `modules` static library. No manual file listing needed.
- `CollectIncludeDirectories(${CMAKE_CURRENT_SOURCE_DIR} PUBLIC_INCLUDES)` — Adds any directory containing `.h` files to the include path. Your scripts can include each other's headers without relative paths.
- No `add_library`, `project()`, or `target_link_libraries` needed — the parent `modules/CMakeLists.txt` handles the library definition and links against `game-interface` (all core headers) and `acore-core-interface`.

**`mod_dreamforge_loader.cpp`**

- `void Addmod_dreamforgeScripts()` — the exact name CMake expects. Derived from directory `mod-dreamforge` by replacing `-` with `_` and wrapping. Getting this wrong causes a linker error, not a runtime error.
- `void AddSC_mod_dreamforge();` — forward declaration required before the call. C++ does not have implicit forward declarations.

**`mod_dreamforge_SC.cpp`**

- `#include "Config.h"` — provides `sConfigMgr` (`ConfigMgr::instance()`) and the `GetOption<T>()` template. Located at `src/common/Configuration/Config.h`.
- `#include "Player.h"` — provides `Player`, `ChatHandler`, and `GetSession()`.
- `#include "ScriptMgr.h"` — transitively brings in every script type header via `AllScriptsObjects.h`, including `PlayerScript.h` and `WorldScript.h`. This is the only include you need for script types.
- Static config variables — the simplest config caching pattern. More complex modules may use a dedicated config singleton class.
- Constructor `PlayerScript("DreamforgePlayerScript", { PLAYERHOOK_ON_LOGIN })` — the string name must be globally unique across all modules. The initializer list is the opt-in hook set.
- `ChatHandler(player->GetSession()).PSendSysMessage(...)` — sends a system message visible only to this player. `PSendSysMessage` is `printf`-style; `SendSysMessage` takes a literal `const char*`.
- `new DreamforgeWorldScript()` and `new DreamforgePlayerScript()` — each constructor calls `ScriptMgr::instance()->RegisterScript(this)` automatically via the `ScriptObject` base constructor. Never call `delete` on these.

---

## 12. Build Commands

Source: `apps/compiler/includes/functions.sh`

### Configure

```bash
mkdir -p build && cd build

cmake /path/to/azerothcore \
  -DCMAKE_INSTALL_PREFIX=/path/to/server \
  -DSCRIPTS=static \
  -DMODULES=static \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo
```

Key CMake options relevant to modules:

| Option | Values | Effect |
|---|---|---|
| `-DMODULES=static` | `static`, `dynamic`, `disabled` | Static: modules compiled into worldserver binary. Dynamic: each module is a `.so`/`.dll` loaded at runtime. |
| `-DSCRIPTS=static` | `static`, `dynamic`, etc. | Controls built-in content scripts (bosses, spells, etc.) — not your module |
| `-DDISABLED_AC_MODULES="mod-foo;mod-bar"` | semicolon-separated names | Disable specific modules without removing them from disk |

### Build and Install

```bash
# Build (replace 4 with your core count)
cmake --build . --config RelWithDebInfo -j 4

# Install binaries + copy .conf.dist files to etc/modules/
cmake --install . --config RelWithDebInfo
```

### Rebuild After Changing Module Code

If you only changed existing `.cpp` files (no new files, no CMakeLists changes):

```bash
cd build
cmake --build . --config RelWithDebInfo -j 4
cmake --install . --config RelWithDebInfo
```

If you added new source files or changed any `CMakeLists.txt`, re-run the `cmake` configure step before building.

### Config File Activation

After install, your `.conf.dist` file is at:

```
$PREFIX/etc/modules/mod-dreamforge.conf.dist
```

Copy it to activate:

```bash
cp $PREFIX/etc/modules/mod-dreamforge.conf.dist \
   $PREFIX/etc/modules/mod-dreamforge.conf
```

Edit `mod-dreamforge.conf` to set your values. Reload at runtime without restarting the server:

```
.reload config
```

This triggers `WorldScript::OnBeforeConfigLoad(true)` and `OnAfterConfigLoad(true)` in all registered WorldScripts.
