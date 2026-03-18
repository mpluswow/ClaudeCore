# AzerothCore Development Reference

> Knowledge base for Dreamforge. Covers C++ module development, all script hooks, and complete database schema for WoW 3.3.5a (WotLK, build 12340).

---

## 1. Module Structure

### Directory Layout

```
modules/
└── mod-my-module/
    ├── CMakeLists.txt
    ├── module.ini.dist         # Default config
    ├── README.md
    ├── src/
    │   └── MyModule.cpp
    └── data/sql/
        ├── db_world/base/      # Run once on install
        ├── db_characters/base/
        └── db_auth/base/
```

### CMakeLists.txt (minimal)

```cmake
CollectSourceFiles(${CMAKE_CURRENT_SOURCE_DIR}/src PRIVATE_SOURCES)

if(PRIVATE_SOURCES)
  add_library(mod-my-module SHARED ${PRIVATE_SOURCES})
  target_include_directories(mod-my-module PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src)
  target_link_libraries(mod-my-module PRIVATE game-interface)
  set_target_properties(mod-my-module PROPERTIES FOLDER "modules")
  install(TARGETS mod-my-module LIBRARY DESTINATION ${LIBS_DIR})
  if(COPY_CONF)
    CopyModuleConfigFiles()
  endif()
endif()
```

### Minimal Script File

```cpp
#include "ScriptMgr.h"
#include "Player.h"

class MyPlayerScript : public PlayerScript
{
public:
    MyPlayerScript() : PlayerScript("MyPlayerScript") {}

    void OnLogin(Player* player) override
    {
        ChatHandler(player->GetSession()).PSendSysMessage("Welcome!");
    }
};

void AddSC_MyModule()
{
    new MyPlayerScript();
}
```

---

## 2. Script Base Classes & Hooks

### PlayerScript

```cpp
class PlayerScript : public ScriptObject
{
public:
    // Login / Lifecycle
    virtual void OnLogin(Player* player, bool firstLogin) {}
    virtual void OnLogout(Player* player) {}
    virtual void OnCreate(Player* player) {}
    virtual void OnDelete(uint64 guid, uint32 accountId) {}
    virtual void OnSave(Player* player) {}
    virtual void OnFirstLogin(Player* player) {}

    // Map / Zone
    virtual void OnUpdateZone(Player* player, uint32 newZone, uint32 newArea) {}
    virtual void OnMapChanged(Player* player) {}
    virtual bool OnBeforeTeleport(Player* player, uint32 mapid, float x, float y, float z, float orientation, uint32 options, Unit* target) { return true; }
    virtual void OnBindToInstance(Player* player, Difficulty difficulty, uint32 mapId, bool permanent) {}

    // XP / Level
    virtual void OnGiveXP(Player* player, uint32& amount, Unit* victim) {}
    virtual void OnLevelChanged(Player* player, uint8 oldLevel) {}
    virtual void OnFreeTalentPointsChanged(Player* player, uint32 points) {}
    virtual void OnTalentsReset(Player* player, bool noCost) {}

    // Money / Economy
    virtual void OnMoneyChanged(Player* player, int32& amount) {}
    virtual void OnMoneyLimit(Player* player, int32 amount) {}
    virtual bool OnBeforeBuyItemFromVendor(Player* player, ObjectGuid vendorguid, uint32 vendorslot, uint32& item, uint8 count, uint8 bag, uint8 slot) { return true; }

    // Reputation
    virtual void OnReputationChange(Player* player, uint32 factionId, int32& standing, bool incremental) {}

    // Combat / Death
    virtual void OnDeath(Player* player) {}
    virtual void OnResurrect(Player* player) {}
    virtual void OnAfterResurrect(Player* player, float restore_percent, bool applySickness) {}
    virtual void OnSpellCast(Player* player, Spell* spell, bool skipCheck) {}
    virtual void OnCreatureKill(Player* killer, Creature* killed) {}
    virtual void OnPlayerKilledByCreature(Creature* killer, Player* killed) {}
    virtual void OnPlayerKillPlayer(Player* killer, Player* killed) {}
    virtual void OnPVPKill(Player* killer, Player* killed) {}
    virtual void OnKilledMonsterCredit(Player* player, uint32 entry, ObjectGuid guid) {}
    virtual void OnDuelRequest(Player* target, Player* challenger) {}
    virtual void OnDuelStart(Player* player1, Player* player2) {}
    virtual void OnDuelEnd(Player* winner, Player* loser, DuelCompleteType type) {}

    // Chat
    virtual void OnChat(Player* player, uint32 type, uint32 lang, std::string& msg) {}
    virtual void OnChat(Player* player, uint32 type, uint32 lang, std::string& msg, Player* receiver) {}
    virtual void OnChat(Player* player, uint32 type, uint32 lang, std::string& msg, Group* group) {}
    virtual void OnChat(Player* player, uint32 type, uint32 lang, std::string& msg, Guild* guild) {}
    virtual void OnChat(Player* player, uint32 type, uint32 lang, std::string& msg, Channel* channel) {}

    // Equipment / Inventory
    virtual void OnEquip(Player* player, Item* it, uint8 bag, uint8 slot, bool update) {}
    virtual void OnItemAddedToInventory(Player* player, Item* item) {}
    virtual void OnAfterMoveItemFromInventory(Player* player, Item* it, uint8 bag, uint8 slot, bool update) {}

    // Quests
    virtual void OnQuestAccept(Player* player, const Quest* quest) {}
    virtual void OnQuestReward(Player* player, const Quest* quest, uint32 option) {}
    virtual void OnQuestStatusChange(Player* player, uint32 questId) {}
    virtual void OnQuestComplete(Player* player, const Quest* quest) {}
    virtual void OnPlayerCompleteQuest(Player* player, Quest const* quest) {}

    // Achievements
    virtual void OnAchiComplete(Player* player, AchievementEntry const* achievement) {}
    virtual bool OnBeforeAchiComplete(Player* player, AchievementEntry const* achievement) { return true; }
    virtual void OnCriteriaProgress(Player* player, AchievementCriteriaEntry const* criteria) {}

    // Misc
    virtual void OnLearnSpell(Player* player, uint32 spellID) {}
    virtual void OnGossipSelect(Player* player, uint32 menu_id, uint32 sender, uint32 action) {}
    virtual void OnGossipSelectCode(Player* player, uint32 menu_id, uint32 sender, uint32 action, const char* code) {}
    virtual void OnUpdateHonorFields(Player* player) {}
    virtual void OnSetMaxLevel(Player* player, uint32& maxPlayerLevel) {}
    virtual void OnReleasedGhost(Player* player) {}
};
```

### CreatureScript

```cpp
class CreatureScript : public ScriptObject
{
public:
    virtual CreatureAI* GetAI(Creature* creature) const { return nullptr; }
    virtual bool OnGossipHello(Player* player, Creature* creature) { return false; }
    virtual bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) { return false; }
    virtual bool OnGossipSelectCode(Player* player, Creature* creature, uint32 sender, uint32 action, const char* code) { return false; }
    virtual bool OnQuestAccept(Player* player, Creature* creature, const Quest* quest) { return false; }
    virtual bool OnQuestReward(Player* player, Creature* creature, const Quest* quest, uint32 opt) { return false; }
    virtual uint32 GetDialogStatus(Player* player, Creature* creature) { return 0; }
};
```

### WorldScript

```cpp
class WorldScript : public ScriptObject
{
public:
    virtual void OnOpenStateChange(bool open) {}
    virtual void OnConfigLoad(bool reload) {}
    virtual void OnAfterConfigLoad(bool reload) {}
    virtual void OnMotdChange(std::string& newMotd) {}
    virtual void OnShutdownInitiate(ShutdownExitCode code, ShutdownMask mask) {}
    virtual void OnShutdownCancel() {}
    virtual void OnWorldUpdate(uint32 diff) {}
    virtual void OnStartup() {}
    virtual void OnShutdown() {}
    virtual void OnBeforeWorldInitialized() {}
};
```

### ItemScript

```cpp
class ItemScript : public ScriptObject
{
public:
    virtual bool OnUse(Player* player, Item* item, SpellCastTargets const& targets) { return false; }
    virtual bool OnItemExpire(Player* player, ItemTemplate const* proto) { return false; }
    virtual bool OnItemRemove(Player* player, Item* item) { return false; }
    virtual void OnGossipSelect(Player* player, Item* item, uint32 sender, uint32 action) {}
    virtual void OnGossipSelectCode(Player* player, Item* item, uint32 sender, uint32 action, const char* code) {}
};
```

### GameObjectScript

```cpp
class GameObjectScript : public ScriptObject
{
public:
    virtual GameObjectAI* GetAI(GameObject* go) const { return nullptr; }
    virtual bool OnGossipHello(Player* player, GameObject* go) { return false; }
    virtual bool OnGossipSelect(Player* player, GameObject* go, uint32 sender, uint32 action) { return false; }
    virtual bool OnQuestAccept(Player* player, GameObject* go, const Quest* quest) { return false; }
    virtual bool OnQuestReward(Player* player, GameObject* go, const Quest* quest, uint32 opt) { return false; }
    virtual void OnDestroyed(GameObject* go, Player* player) {}
    virtual void OnDamaged(GameObject* go, Player* player) {}
    virtual void OnLootStateChanged(GameObject* go, uint32 state, Unit* unit) {}
    virtual void OnGameObjectStateChanged(GameObject* go, uint32 state) {}
};
```

### SpellScriptLoader

```cpp
class SpellScriptLoader : public ScriptObject
{
public:
    virtual SpellScript* GetSpellScript() const { return nullptr; }
    virtual AuraScript* GetAuraScript() const { return nullptr; }
};
// Register: new SpellScriptLoader("spell_my_script");
// Linked by spell_script_names table: spell_id → script_name
```

### UnitScript

```cpp
class UnitScript : public ScriptObject
{
public:
    virtual void OnHeal(Unit* healer, Unit* receiver, uint32& gain) {}
    virtual void OnDamage(Unit* attacker, Unit* victim, uint32& damage) {}
    virtual void ModifyPeriodicDamageAurasTick(Unit* target, Unit* attacker, uint32& damage) {}
    virtual void ModifyMeleeDamage(Unit* target, Unit* attacker, uint32& damage) {}
    virtual void ModifySpellDamageTaken(Unit* target, Unit* attacker, int32& damage) {}
};
```

### MapScript / InstanceMapScript

```cpp
class MapScript : public ScriptObject
{
public:
    virtual void OnCreate(Map* map) {}
    virtual void OnDestroy(Map* map) {}
    virtual void OnUpdate(Map* map, uint32 diff) {}
    virtual void OnPlayerEnter(Map* map, Player* player) {}
    virtual void OnPlayerLeave(Map* map, Player* player) {}
};

class InstanceMapScript : public MapScript
{
public:
    virtual InstanceScript* GetInstanceScript(InstanceMap* map) const { return nullptr; }
};
```

### AreatriggerScript

```cpp
class AreatriggerScript : public ScriptObject
{
public:
    virtual bool OnTrigger(Player* player, AreaTrigger const* trigger) { return false; }
};
```

### AllCreatureScript / AllMapScript (fire for ALL, no ScriptName needed)

```cpp
class AllCreatureScript : public ScriptObject
{
public:
    virtual void OnAllCreatureUpdate(Creature* creature, uint32 diff) {}
    virtual void OnCreatureAddWorld(Creature* creature) {}
    virtual void OnCreatureRemoveWorld(Creature* creature) {}
    virtual void OnCreatureKill(Creature* killer, Creature* killed) {}
};

class AllMapScript : public ScriptObject
{
public:
    virtual void OnCreateMap(Map* map) {}
    virtual void OnDestroyMap(Map* map) {}
    virtual void OnPlayerEnterAll(Map* map, Player* player) {}
    virtual void OnPlayerLeaveAll(Map* map, Player* player) {}
};
```

### GroupScript / GuildScript

```cpp
class GroupScript : public ScriptObject
{
public:
    virtual void OnAddMember(Group* group, ObjectGuid guid) {}
    virtual void OnRemoveMember(Group* group, ObjectGuid guid, RemoveMethod method, ObjectGuid kicker, const char* reason) {}
    virtual void OnChangeLeader(Group* group, ObjectGuid newLeaderGuid, ObjectGuid oldLeaderGuid) {}
    virtual void OnDisband(Group* group) {}
    virtual void OnCreate(Group* group, Player* leader) {}
};

class GuildScript : public ScriptObject
{
public:
    virtual void OnAddMember(Guild* guild, Player* player, uint8& plRank) {}
    virtual void OnRemoveMember(Guild* guild, Player* player, bool isDisbanding, bool isKicked) {}
    virtual void OnCreate(Guild* guild, Player* leader, const std::string& name) {}
    virtual void OnDisband(Guild* guild) {}
    virtual void OnMemberDepositMoney(Guild* guild, Player* player, uint32& amount) {}
    virtual void OnMemberWithdrawMoney(Guild* guild, Player* player, uint32& amount, bool isRepair) {}
};
```

---

## 3. CreatureAI Hooks (ScriptedAI)

```cpp
class MyBossAI : public ScriptedAI
{
    EventMap events;
    enum Events { EVENT_SPELL_1 = 1, EVENT_SPELL_2 };

public:
    MyBossAI(Creature* c) : ScriptedAI(c) {}

    void EnterCombat(Unit* who) override {
        events.ScheduleEvent(EVENT_SPELL_1, 5000);
        events.ScheduleEvent(EVENT_SPELL_2, 15000);
    }
    void JustDied(Unit* killer) override {}
    void KilledUnit(Unit* victim) override {}
    void JustRespawned() override {}
    void EnterEvadeMode(EvadeReason why) override {}
    void SpellHit(Unit* caster, SpellInfo const* spell) override {}
    void SpellHitTarget(Unit* target, SpellInfo const* spell) override {}
    void DamageTaken(Unit* attacker, uint32& damage) override {}
    void HealReceived(Unit* done_by, uint32& addhealth) override {}
    void SummonedCreatureDespawn(Creature* summon) override {}
    void MovementInform(uint32 type, uint32 id) override {}
    void WaypointReached(uint32 waypointId, uint32 pathId) override {}

    void UpdateAI(uint32 diff) override {
        if (!UpdateVictim()) return;
        events.Update(diff);
        while (uint32 eventId = events.ExecuteEvent()) {
            switch (eventId) {
                case EVENT_SPELL_1:
                    me->CastSpell(me->GetVictim(), SPELL_ID, false);
                    events.Repeat(urand(8000, 12000));
                    break;
            }
        }
        DoMeleeAttackIfReady();
    }
};
```

---

## 4. C++ Common Patterns

### Chat / Messages

```cpp
// System message to player (yellow):
ChatHandler(player->GetSession()).PSendSysMessage("Hello %s!", player->GetName().c_str());

// Broadcast to all:
sWorld->SendServerMessage(SERVER_MSG_STRING, "Server announcement");

// Notification popup:
player->GetSession()->SendNotification("Warning text");
```

### Database Queries

```cpp
// Sync query:
QueryResult result = WorldDatabase.Query("SELECT entry FROM creature_template WHERE entry = {}", entry);
if (result) {
    Field* fields = result->Fetch();
    uint32 e = fields[0].Get<uint32>();
}

// Transaction:
CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_INS_ITEM);
stmt->SetData(0, itemEntry);
trans->Append(stmt);
CharacterDatabase.CommitTransaction(trans);
```

### Object Searching

```cpp
Creature* nearby = me->FindNearestCreature(ENTRY, 30.0f, true);
GameObject* go = me->FindNearestGameObject(GO_ENTRY, 20.0f);

std::list<Player*> players;
me->GetPlayerListInGrid(players, 40.0f);
```

### Summoning

```cpp
creature->SummonCreature(ENTRY, x, y, z, orientation, TEMPSUMMON_TIMED_DESPAWN, 30000);
player->SummonCreature(ENTRY, *player, TEMPSUMMON_CORPSE_DESPAWN, 0);
```

### Custom Config

```cpp
void OnAfterConfigLoad(bool reload) override {
    myEnabled = sConfigMgr->GetOption<bool>("MyModule.Enabled", true);
    myRate    = sConfigMgr->GetOption<float>("MyModule.Rate", 1.0f);
    myMsg     = sConfigMgr->GetOption<std::string>("MyModule.Message", "Hello!");
}
```

### Key Headers

```cpp
#include "ScriptMgr.h"        // Script base classes
#include "Player.h"           // Player class
#include "Creature.h"         // Creature class
#include "ScriptedCreature.h" // ScriptedAI, BossAI helpers
#include "SpellScript.h"      // SpellScript, AuraScript
#include "Item.h"             // Item class
#include "GameObject.h"       // GameObject class
#include "InstanceScript.h"   // InstanceScript base
#include "Chat.h"             // ChatHandler
#include "Config.h"           // sConfigMgr
#include "DatabaseEnv.h"      // WorldDatabase, CharacterDatabase, AuthDatabase
#include "ObjectMgr.h"        // sObjectMgr
#include "World.h"            // sWorld
#include "EventMap.h"         // EventMap for scheduling
#include "TaskScheduler.h"    // TaskScheduler
#include "Log.h"              // LOG_INFO, LOG_ERROR
#include "MoveSplineInit.h"   // Custom movement
#include "MotionMaster.h"     // Movement management
```

---

## 5. Instance Scripting

```cpp
class instance_my_dungeon : public InstanceScript
{
    ObjectGuid boss1GUID;

public:
    instance_my_dungeon(InstanceMap* map) : InstanceScript(map)
    {
        SetHeaders("MY");
        SetBossNumber(2);
    }

    void OnCreatureCreate(Creature* creature) override {
        if (creature->GetEntry() == BOSS_1_ENTRY)
            boss1GUID = creature->GetGUID();
    }

    bool SetBossState(uint32 id, EncounterState state) override {
        if (!InstanceScript::SetBossState(id, state)) return false;
        return true;
    }

    std::string GetSaveData() override {
        OUT_SAVE_INST_DATA;
        std::ostringstream saveStream;
        SaveToBitset(saveStream);
        OUT_SAVE_INST_DATA_COMPLETE;
        return saveStream.str();
    }

    void Load(const char* in) override {
        if (!in) return;
        IN_LOAD_DATA;
        LoadFromBitset(in);
        IN_LOAD_DATA_COMPLETE;
    }
};

class instance_my_dungeon_script : public InstanceMapScript
{
public:
    instance_my_dungeon_script() : InstanceMapScript("instance_my_dungeon", MAP_ID) {}
    InstanceScript* GetInstanceScript(InstanceMap* map) const override {
        return new instance_my_dungeon(map);
    }
};
```

---

## 6. Database Schema

### World DB: `creature_template` (key columns)

| Column | Type | Description |
|--------|------|-------------|
| `entry` | INT UNSIGNED | Unique creature type ID |
| `name` | VARCHAR(100) | Display name |
| `subname` | VARCHAR(100) | Title/subtype shown in UI |
| `IconName` | VARCHAR(100) | Cursor icon override |
| `gossip_menu_id` | INT UNSIGNED | Default gossip menu |
| `minlevel` / `maxlevel` | TINYINT | Level range |
| `faction` | SMALLINT | Faction ID |
| `npcflag` | INT | NPC flags (see below) |
| `speed_walk` / `speed_run` | FLOAT | Movement speeds (1.0 = normal) |
| `rank` | TINYINT | 0=Normal, 1=Elite, 2=RareElite, 3=Boss, 4=Rare |
| `AIName` | VARCHAR(64) | `SmartAI`, `NullCreatureAI`, `ReactorAI`, `PassiveAI` |
| `MovementType` | TINYINT | 0=idle, 1=random, 2=waypoint |
| `ScriptName` | VARCHAR(64) | C++ script class name |
| `HealthModifier` | FLOAT | HP multiplier |
| `DamageModifier` | FLOAT | Damage multiplier |
| `lootid` | INT | References loot table |
| `modelid1`–`modelid4` | INT | Display model IDs |
| `type` | TINYINT | Creature type: 1=Beast, 2=Dragon, 3=Demon, 4=Elemental, 5=Giant, 6=Undead, 7=Humanoid, 8=Critter, 9=Mechanical, 10=NotSpecified, 11=Totem, 12=NonCombatPet, 13=GasCloud |

**`npcflag` values (bitmask):**

| Value | Flag |
|-------|------|
| 1 | GOSSIP |
| 2 | QUESTGIVER |
| 16 | TRAINER |
| 128 | VENDOR |
| 4096 | REPAIR |
| 8192 | FLIGHTMASTER |
| 65536 | INNKEEPER |
| 131072 | BANKER |
| 2097152 | AUCTIONEER |
| 4194304 | STABLEMASTER |
| 16777216 | SPELLCLICK |

### World DB: `creature` (spawns)

| Column | Type | Description |
|--------|------|-------------|
| `guid` | INT UNSIGNED | Unique spawn GUID |
| `id` | INT UNSIGNED | References `creature_template.entry` |
| `map` | SMALLINT | Map ID |
| `position_x/y/z` | FLOAT | Spawn coordinates |
| `orientation` | FLOAT | Facing direction (radians) |
| `spawntimesecs` | INT | Respawn timer |
| `MovementType` | TINYINT | 0=idle, 1=random, 2=waypoint |
| `wander_distance` | FLOAT | Random movement radius |

### World DB: `item_template` (key columns)

| Column | Type | Description |
|--------|------|-------------|
| `entry` | INT UNSIGNED | Unique item ID |
| `name` | VARCHAR(255) | Item name |
| `Quality` | TINYINT | 0=grey, 1=white, 2=green, 3=blue, 4=purple, 5=orange, 6=heirloom |
| `InventoryType` | TINYINT | Slot (0=non-equip, 1=head, 5=chest, 13=trinket, 16=back, 23=offhand, etc.) |
| `AllowableClass` | INT | Class bitmask (-1=all) |
| `AllowableRace` | INT | Race bitmask (-1=all) |
| `ItemLevel` | SMALLINT | Item level |
| `RequiredLevel` | TINYINT | Min player level |
| `bonding` | TINYINT | 0=none, 1=BoP, 2=BoE, 3=BoU, 4=BoA |
| `BuyPrice` / `SellPrice` | INT | Copper prices |
| `stackable` | INT | Max stack size |
| `spellid_1`–`spellid_5` | INT | On-use/equip spell IDs |
| `spelltrigger_1`–`5` | TINYINT | 0=use, 1=equip, 2=chance on hit, 6=learn |
| `ScriptName` | VARCHAR(64) | C++ script class name |

### World DB: `quest_template` (key columns)

| Column | Description |
|--------|-------------|
| `ID` | Quest ID |
| `QuestLevel` | Level of the quest (affects XP) |
| `MinLevel` | Minimum level to accept |
| `Title` | Quest name |
| `Details` | Quest description text |
| `Objectives` | Objectives text |
| `CompletedText` | Text shown on completion |
| `RewardMoney` | Copper reward |
| `RewardXPDifficulty` | XP reward index |
| `RewardItem1`–`4` | Item reward IDs |
| `RewardChoiceItemID1`–`6` | Choice item IDs |
| `RequiredNpcOrGo1`–`4` | Kill/interact objectives (positive=creature, negative=GO) |
| `RequiredNpcOrGoCount1`–`4` | Objective counts |
| `RequiredItemId1`–`6` | Item collection IDs |
| `RequiredItemCount1`–`6` | Item collection counts |
| `RewardFactionID1`–`5` | Rep reward faction IDs |
| `RewardFactionValue1`–`5` | Rep amounts |

### World DB: `smart_scripts` (SmartAI)

```sql
entryorguid   -- >0 = creature entry, <0 = guid, GO entry for source_type=1
source_type   -- 0=creature, 1=gameobject, 2=areatrigger, 9=timed_actionlist
id            -- sequential index
link          -- chain to another event
event_type    -- what triggers this (see Event Types below)
event_param1–4 -- event-specific parameters
action_type   -- what happens (see Action Types below)
action_param1–6 -- action-specific parameters
target_type   -- what to target (see Target Types below)
target_param1–4 -- target filter parameters
target_x/y/z/o -- explicit position (for SMART_TARGET_POSITION)
comment       -- description
```

**Key SmartAI Event Types:**

| ID | Name | Params (1,2,3,4) |
|----|------|-----------------|
| 0 | UPDATE_IC | initial_min, initial_max, repeat_min, repeat_max |
| 1 | UPDATE_OOC | initial_min, initial_max, repeat_min, repeat_max |
| 2 | HP_PCT | hppct_min, hppct_max, repeat_min, repeat_max |
| 5 | AGGRO | — |
| 6 | KILL | cooldown_min, cooldown_max, playerOnly, creatureEntry |
| 7 | DEATH | — |
| 8 | EVADE | — |
| 9 | SPELLHIT | spellId, school, cooldown_min, cooldown_max |
| 11 | OOC_LOS | maxDist, 0, repeat_min, repeat_max |
| 21 | REACHED_HOME | — |
| 25 | RESET | — |
| 38 | DATA_SET | id, value, cooldown_min, cooldown_max |
| 40 | WAYPOINT_REACHED | pointId, pathId |
| 52 | TEXT_OVER | textGroupId, creatureEntry |
| 60 | UPDATE | initial_min, initial_max, repeat_min, repeat_max |
| 62 | GOSSIP_HELLO | onlyFirstTime |
| 63 | GOSSIP_SELECT | menuId, optionId |

**Key SmartAI Action Types:**

| ID | Name | Params |
|----|------|--------|
| 1 | TALK | groupId, useTalkTarget |
| 2 | SET_FACTION | factionId (0=restore) |
| 4 | SOUND | soundId, onlySelf |
| 5 | PLAY_EMOTE | emoteId |
| 11 | CAST | spellId, castFlags |
| 12 | SUMMON_CREATURE | entry, type, duration |
| 22 | SET_EVENT_PHASE | phase |
| 24 | EVADE | — |
| 28 | REMOVEAURASFROMSPELL | spellId, charges |
| 37 | DIE | — |
| 41 | FORCE_DESPAWN | delay, respawnTimer |
| 53 | WP_START | run, pathId, quest, despawnTime |
| 69 | MOVE_TO_POS | pointId, transport, disablePathfinding |
| 72 | CLOSE_GOSSIP | — |
| 75 | ADD_AURA | spellId |
| 98 | SEND_GOSSIP_MENU | menuId, npcTextId |

**Key SmartAI Target Types:**

| ID | Name |
|----|------|
| 0 | NONE |
| 1 | SELF |
| 2 | VICTIM |
| 7 | ACTION_INVOKER |
| 8 | POSITION |
| 17 | PLAYER_RANGE |
| 19 | CLOSEST_CREATURE |
| 21 | CLOSEST_PLAYER |
| 24 | THREAT_LIST |

### World DB: Key Table Index

| Table | Purpose |
|-------|---------|
| `creature_template` | Creature type definitions |
| `creature` | World spawn placements |
| `creature_addon` | Per-spawn extra data (auras, emote, path) |
| `creature_template_addon` | Per-type extra data |
| `creature_text` | SAI dialogue groups |
| `item_template` | Item definitions |
| `gameobject_template` | GO type definitions |
| `gameobject` | GO spawn placements |
| `quest_template` | Quest definitions |
| `smart_scripts` | SmartAI scripts |
| `waypoint_data` | Movement paths (id, point, x/y/z, delay, move_type) |
| `gossip_menu` | Menu → NPC text mapping |
| `gossip_menu_option` | Gossip option definitions |
| `npc_vendor` | Vendor item lists |
| `npc_trainer` | Trainer spell lists |
| `creature_loot_template` | Creature drop tables |
| `gameobject_loot_template` | GO loot tables |
| `reference_loot_template` | Reusable loot groups |
| `item_loot_template` | Item contents (boxes, etc.) |
| `spell_dbc` | Spell DB overrides |
| `areatrigger_teleport` | Zone teleport triggers |
| `conditions` | Conditional checks |
| `access_requirement` | Instance entry requirements |
| `instance_template` | Dungeon/raid definitions |
| `pool_template` / `pool_creature` | Spawn pools |
| `game_event` | Seasonal events |
| `page_text` | Book/scroll text |
| `npc_text` | NPC dialogue texts |
| `playercreateinfo` | Starting data by race+class |
| `player_levelstats` | Stats per level |

### Auth DB: `account`

| Column | Description |
|--------|-------------|
| `id` | Account ID |
| `username` | Login name (max 32 chars) |
| `sha_pass_hash` | SHA1 of "USERNAME:PASSWORD" (uppercase) |
| `expansion` | 0=Vanilla, 1=TBC, 2=WotLK |
| `online` | Currently logged in |
| `gmlevel` | GM level (set via `account_access`) |

### Auth DB: `realmlist`

| Column | Description |
|--------|-------------|
| `name` | Realm name shown in client |
| `address` | Public IP/hostname |
| `port` | Worldserver port (default 8085) |
| `gamebuild` | Must match client: **12340** for 3.3.5a |
| `flag` | 0=normal, 2=recommended, 4=offline |

### Characters DB: `characters` (key columns)

| Column | Description |
|--------|-------------|
| `guid` | Character GUID |
| `account` | Owner account ID |
| `name` | Character name |
| `race` | Race ID |
| `class` | Class ID |
| `level` | Current level |
| `xp` | Current XP |
| `money` | Copper amount |
| `map` / `position_x/y/z` | Current position |
| `totaltime` | Total played time (seconds) |
| `at_login` | Flags for next login action |

---

## 7. SQL Update File Convention

```
modules/mod-my-module/data/sql/
├── db_world/
│   ├── base/
│   │   └── mod_mymod_custom_table.sql   # CREATE TABLE IF NOT EXISTS
│   └── updates/
│       └── 2024_01_15_00.sql            # Incremental changes
```

Each update file starts with:
```sql
-- DO NOT DELETE THIS LINE.
-- Revision data start
-- Revision data end
```

Use `INSERT IGNORE` and `IF NOT EXISTS` for idempotent SQL.

---

## 8. Module Best Practices

1. **Prefix script names** — `"mod_mymod_PlayerScript"` to avoid collisions
2. **Never block the main thread** — no heavy sync DB queries in `OnWorldUpdate`
3. **Use PreparedStatements** — register in module init, reference by enum
4. **Support hot-reload** — re-read config in `OnAfterConfigLoad(bool reload)`
5. **Prefix custom tables** — `mod_mymod_tablename`
6. **Use `LOG_INFO("module", ...)`** for logging
7. **`ScriptName` field** — must exactly match the string in the script constructor
8. **Prefer hooks over core edits** — only touch core when hooks don't cover it
9. **SQL idempotency** — `CREATE TABLE IF NOT EXISTS`, `INSERT IGNORE`
10. **`AddSC_` naming** — one per file, matches filename convention

*Last updated: 2026-03-17*
