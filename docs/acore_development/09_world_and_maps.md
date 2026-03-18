# World and Maps System

Comprehensive reference for AzerothCore world systems: maps, instances, area triggers, transports, weather, game events, and the coordinate system. Covers both database tables and C++ scripting APIs.

---

## Table of Contents

1. [Map System](#1-map-system)
2. [InstanceScript / BossAI System](#2-instancescript--bossai-system)
3. [WorldScript Hooks](#3-worldscript-hooks)
4. [Area Trigger System](#4-area-trigger-system)
5. [Transport System](#5-transport-system)
6. [Weather System](#6-weather-system)
7. [Game Events System](#7-game-events-system)
8. [Coordinate System](#8-coordinate-system)
9. [Spawn Mask / Difficulty Flags](#9-spawn-mask--difficulty-flags)
10. [Cross-References](#cross-references)

---

## 1. Map System

### 1.1 MapType Enum

```cpp
enum MapType : uint8
{
    MAP_TYPE_COMMON        = 0,  // Open world zones (Eastern Kingdoms, Kalimdor, Outland, Northrend)
    MAP_TYPE_INSTANCE      = 1,  // 5-man dungeons (normal and heroic)
    MAP_TYPE_RAID          = 2,  // Raid instances (10 and 25 man)
    MAP_TYPE_BATTLEGROUND  = 3,  // PvP battlegrounds (AV, WSG, AB, EotS, SotA, IoC)
    MAP_TYPE_ARENA         = 4   // Arena maps (2v2, 3v3, 5v5)
};
```

### 1.2 Map ID Reference

#### Open World Maps

| Map ID | Name | Type |
|--------|------|------|
| 0 | Eastern Kingdoms | Common |
| 1 | Kalimdor | Common |
| 530 | Outland (The Burning Crusade) | Common |
| 571 | Northrend (Wrath of the Lich King) | Common |
| 870 | The Maelstrom (unreleased in WotLK) | Common |

#### Classic / Vanilla Dungeons

| Map ID | Name | Type |
|--------|------|------|
| 33 | Shadowfang Keep | Instance |
| 34 | Stormwind Stockade | Instance |
| 36 | Deadmines | Instance |
| 43 | Wailing Caverns | Instance |
| 44 | Monastery (Scarlet Monastery complex) | Instance |
| 47 | Razorfen Kraul | Instance |
| 48 | Blackfathom Deeps | Instance |
| 70 | Uldaman | Instance |
| 90 | Gnomeregan | Instance |
| 109 | Sunken Temple (Temple of Atal'Hakkar) | Instance |
| 129 | Razorfen Downs | Instance |
| 189 | Scarlet Monastery | Instance |
| 209 | Zul'Farrak | Instance |
| 229 | Blackrock Spire | Instance |
| 230 | Blackrock Depths | Instance |
| 289 | Scholomance | Instance |
| 329 | Stratholme | Instance |
| 349 | Maraudon | Instance |
| 389 | Ragefire Chasm | Instance |
| 409 | Molten Core | Raid |
| 469 | Blackwing Lair | Raid |
| 509 | Ruins of Ahn'Qiraj (AQ20) | Raid |
| 531 | Temple of Ahn'Qiraj (AQ40) | Raid |
| 533 | Naxxramas (original) | Raid |
| 568 | Zul'Aman | Raid |

#### The Burning Crusade Dungeons

| Map ID | Name | Type |
|--------|------|------|
| 269 | The Black Morass | Instance |
| 540 | Hellfire Citadel: The Shattered Halls | Instance |
| 542 | Hellfire Citadel: Blood Furnace | Instance |
| 543 | Hellfire Citadel: Ramparts | Instance |
| 545 | Coilfang: Steam Vault | Instance |
| 546 | Coilfang: Underbog | Instance |
| 547 | Coilfang: Slave Pens | Instance |
| 550 | Tempest Keep: The Eye | Raid |
| 552 | Tempest Keep: The Arcatraz | Instance |
| 553 | Tempest Keep: The Botanica | Instance |
| 554 | Tempest Keep: The Mechanar | Instance |
| 555 | Auchindoun: Shadow Labyrinth | Instance |
| 556 | Auchindoun: Sethekk Halls | Instance |
| 557 | Auchindoun: Mana-Tombs | Instance |
| 558 | Auchindoun: Auchenai Crypts | Instance |
| 560 | Old Hillsbrad (Caverns of Time) | Instance |
| 564 | Black Temple | Raid |
| 565 | Gruul's Lair | Raid |
| 566 | Eye of the Storm (BG) | Battleground |
| 580 | Sunwell Plateau | Raid |
| 585 | Magisters' Terrace | Instance |

#### Wrath of the Lich King Dungeons

| Map ID | Name | Type |
|--------|------|------|
| 533 | Naxxramas (WotLK version) | Raid |
| 574 | Utgarde Keep | Instance |
| 575 | Utgarde Pinnacle | Instance |
| 576 | The Nexus | Instance |
| 578 | The Oculus | Instance |
| 595 | The Culling of Stratholme | Instance |
| 598 | Sunken City of Vashj'ir (phase) | Instance |
| 599 | Halls of Stone | Instance |
| 600 | Drak'Tharon Keep | Instance |
| 601 | Azjol-Nerub | Instance |
| 602 | Halls of Lightning | Instance |
| 603 | Ulduar | Raid |
| 604 | Gundrak | Instance |
| 608 | Violet Hold | Instance |
| 615 | The Obsidian Sanctum | Raid |
| 616 | The Eye of Eternity | Raid |
| 619 | Ahn'kahet: The Old Kingdom | Instance |
| 624 | Vault of Archavon | Raid |
| 631 | Icecrown Citadel | Raid |
| 632 | The Forge of Souls | Instance |
| 643 | Trial of the Champion | Instance |
| 645 | Pit of Saron | Instance |
| 649 | Trial of the Crusader | Raid |
| 650 | Trial of the Champion (heroic variant) | Instance |
| 658 | Halls of Reflection | Instance |
| 668 | Halls of Reflection (heroic entry) | Instance |
| 724 | The Ruby Sanctum | Raid |

#### Battlegrounds and Arenas

| Map ID | Name | Type |
|--------|------|------|
| 30 | Alterac Valley | Battleground |
| 37 | Azshara Crater (unused) | Battleground |
| 489 | Warsong Gulch | Battleground |
| 529 | Arathi Basin | Battleground |
| 559 | Nagrand Arena | Arena |
| 562 | Blade's Edge Arena | Arena |
| 566 | Eye of the Storm | Battleground |
| 572 | Ruins of Lordaeron Arena | Arena |
| 607 | Strand of the Ancients | Battleground |
| 617 | Dalaran Sewers Arena | Arena |
| 618 | Ring of Valor Arena | Arena |
| 628 | Isle of Conquest | Battleground |

### 1.3 `instance_template` Table

Stores per-instance configuration. One row per instanced map.

| Column | Type | Null | Default | Description |
|--------|------|------|---------|-------------|
| `map` | INT UNSIGNED | NO | — | Map ID (PK). Must match a Maps.dbc entry |
| `parent` | BIGINT UNSIGNED | NO | 0 | Parent map ID for sub-instances (0 = none) |
| `script` | VARCHAR(128) | NO | — | ScriptName registered via `AddSC_` function. Empty string = no script |
| `allowMount` | TINYINT(1) | NO | 0 | 0 = mounting forbidden inside; 1 = mounting allowed |
| `resetTimeHeroic` | INT UNSIGNED | NO | 0 | Heroic reset interval in seconds (86400 = 24h, 0 = use default) |
| `resetTimeRaid` | INT UNSIGNED | NO | 0 | Raid reset interval in seconds (604800 = 7 days, 0 = use default) |

Example rows:

```sql
-- Icecrown Citadel: 25-man, 7-day lockout, has instance script
INSERT INTO instance_template (map, parent, script, allowMount, resetTimeHeroic, resetTimeRaid)
VALUES (631, 0, 'instance_icecrown_citadel', 0, 0, 604800);

-- Violet Hold: 24h heroic lockout
INSERT INTO instance_template (map, parent, script, allowMount, resetTimeHeroic, resetTimeRaid)
VALUES (608, 0, 'instance_violet_hold', 0, 86400, 0);
```

### 1.4 Difficulty System

WotLK difficulty IDs used in `creature.difficulty_entry_1/2/3`, `DungeonEncounter.dbc`, and loot tables:

| ID | Constant | Description |
|----|----------|-------------|
| 0 | DUNGEON_DIFFICULTY_NORMAL | 5-man normal |
| 1 | DUNGEON_DIFFICULTY_HEROIC | 5-man heroic |
| 2 | RAID_DIFFICULTY_10MAN_NORMAL | 10-man normal raid |
| 3 | RAID_DIFFICULTY_25MAN_NORMAL | 25-man normal raid |
| 4 | RAID_DIFFICULTY_10MAN_HEROIC | 10-man heroic raid |
| 5 | RAID_DIFFICULTY_25MAN_HEROIC | 25-man heroic raid |

### 1.5 `instance_encounters` Table

Links boss encounters (from `DungeonEncounter.dbc`) to the creatures or spells that complete them. Used by the LFG system and achievement tracking.

| Column | Type | Null | Description |
|--------|------|------|-------------|
| `entry` | INT UNSIGNED | NO | DungeonEncounter.dbc entry ID (PK) |
| `creditType` | TINYINT UNSIGNED | NO | 0 = creature kill; 1 = spell cast |
| `creditEntry` | INT UNSIGNED | NO | creature_template.entry OR Spell.dbc entry depending on creditType |
| `lastEncounterDungeon` | SMALLINT UNSIGNED | NO | LfgDungeon.dbc entry for the dungeon where this is the final boss |
| `comment` | VARCHAR(255) | YES | Human-readable description (e.g., "The Lich King") |

Example:

```sql
-- Lich King encounter in ICC 25-man heroic
INSERT INTO instance_encounters (entry, creditType, creditEntry, lastEncounterDungeon, comment)
VALUES (4812, 0, 36597, 285, 'The Lich King (25H)');
```

---

## 2. InstanceScript / BossAI System

### 2.1 `EncounterState` Enum

```cpp
enum EncounterState : uint8
{
    NOT_STARTED   = 0,  // Boss has not been engaged
    IN_PROGRESS   = 1,  // Fight is ongoing
    FAIL          = 2,  // Wipe — reset pending
    DONE          = 3,  // Boss killed, encounter complete
    SPECIAL       = 4,  // Custom intermediate state (e.g. intermission)
    TO_BE_DECIDED = 5   // Uninitialized / unknown state
};
```

### 2.2 `InstanceScript` Base Class

`InstanceScript` (defined in `src/server/game/Instances/InstanceScript.h`) is the base for all instance C++ scripts. Attach to an instance by specifying the script name in `instance_template.script`.

#### Virtual Methods to Override

```cpp
class InstanceScript : public ZoneScript
{
public:
    // Called once when the instance map is first loaded/created
    virtual void Initialize() {}

    // Called to load persisted encounter state from DB string
    // data is a space-separated list of EncounterState values, one per boss
    virtual void Load(char const* data);

    // Called to generate the DB persistence string (space-separated states)
    virtual std::string GetSaveData() { return ""; }

    // Called every world update tick for the instance
    virtual void Update(uint32 diff) {}

    // Called when a creature spawns inside the instance
    void OnCreatureCreate(Creature* creature) override;

    // Called when a creature is removed from the instance
    void OnCreatureRemove(Creature* creature) override;

    // Called when a game object spawns inside the instance
    void OnGameObjectCreate(GameObject* go) override;

    // Called when a game object is removed from the instance
    void OnGameObjectRemove(GameObject* go) override;

    // Called when a unit dies inside the instance
    // NOTE: In AzerothCore this is typically handled via OnCreatureKilled
    // Override SetData() or use creature AI JustDied() hooks instead

    // Called when a player enters the instance
    virtual void OnPlayerEnter(Player* player) {}

    // Called when a player leaves the instance
    virtual void OnPlayerLeave(Player* player) {}

    // Called to fill the initial world state packet for the instance UI
    virtual void FillInitialWorldStates(WorldPackets::WorldState::InitWorldStates& /*packet*/) {}

    // Return false to block a player from entering based on encounter state
    virtual bool CheckRequiredBosses(uint32 bossId, Player const* player = nullptr) const { return true; }

    // Handle generic data events (custom use — replaces SetData in derived classes)
    virtual void SetData(uint32 type, uint32 data) {}
    virtual uint32 GetData(uint32 type) const { return 0; }
    virtual ObjectGuid GetGuidData(uint32 type) const { return ObjectGuid::Empty; }

    // Achievement criteria override
    virtual bool CheckAchievementCriteriaMeet(uint32 criteriaId, Player const* source,
                                               Unit const* target, uint32 miscValue) { return false; }
};
```

#### Key Public (Non-Virtual) Methods

```cpp
// Set boss encounter state; automatically saves to DB on DONE/FAIL
// Returns true if state actually changed
bool SetBossState(uint32 id, EncounterState state);

// Get current state of boss by index (0-based, matches your enum order)
EncounterState GetBossState(uint32 id) const;

// Returns true if any boss is currently IN_PROGRESS
bool IsEncounterInProgress() const;

// Activate or deactivate a door/button GO; withRestoreTime = auto-close delay in ms (0 = permanent)
// useAlternativeState = true to toggle to an alternate open/closed animation state
void DoUseDoorOrButton(ObjectGuid guid, uint32 withRestoreTime = 0, bool useAlternativeState = false);

// Toggle a game object open/closed by its stored GUID
void HandleGameObject(ObjectGuid guid, bool open, GameObject* go = nullptr);

// Respawn a game object after timeToDespawn milliseconds
void DoRespawnGameObject(ObjectGuid guid, uint32 timeToDespawn = MINUTE);

// Force save current encounter states to the characters DB
void SaveToDB();

// Update a world state variable (visible in instance UI frames)
void DoUpdateWorldState(uint32 worldStateId, uint32 value);

// Send notification text to all players in instance
void DoSendNotifyToInstance(char const* format, ...);

// Send an encounter unit frame event (adds/removes boss frames from UI)
// type: 1=add, 2=remove, 3=enable power bar, 4=disable power bar
void SendEncounterUnit(uint32 type, Unit* unit = nullptr, uint8 param1 = 0, uint8 param2 = 0);

// Bitmask of completed (DONE state) boss encounter IDs
uint32 GetCompletedEncounterMask() const;

// Access the instance map itself
InstanceMap* instance;
```

#### BossInfo Structure

```cpp
struct BossInfo
{
    BossInfo() : state(TO_BE_DECIDED) {}
    EncounterState state;
    DoorSet door[MAX_DOOR_TYPES]; // Doors associated with this boss (auto-managed)
    MinionSet minion;              // Minions that share boss state
    CreatureBoundary boundary;     // Evade boundary for the boss area
};
```

Bosses are registered in `SetupDoors()` / `AddDoor()` / `AddBossJournal()` helpers in derived classes.

### 2.3 `ScriptedAI` Class

`ScriptedAI` (in `src/server/game/AI/ScriptedAI/ScriptedAI.h`) is the standard base for all creature AI scripts.

```cpp
class ScriptedAI : public CreatureAI
{
public:
    explicit ScriptedAI(Creature* creature);

    // ---- Override these in your boss AI ----

    // Called when creature resets (out of combat, wipe, etc.)
    virtual void Reset() {}

    // Called when creature enters combat (first aggro)
    virtual void EnterCombat(Unit* victim) {}

    // Called when the creature kills a unit
    virtual void KilledUnit(Unit* victim) {}

    // Called when the creature dies
    virtual void JustDied(Unit* killer) {}

    // Called when the creature evades (leaves combat without dying)
    virtual void EnterEvadeMode(EvadeReason why = EVADE_REASON_OTHER) override;

    // Called every diff ms while in combat (main update loop)
    virtual void UpdateAI(uint32 diff) override;

    // Called when creature summons another creature
    virtual void JustSummoned(Creature* summon) {}

    // Called when a summoned creature dies
    virtual void SummonedCreatureDies(Creature* summon, Unit* killer) {}

    // Called when creature reaches a waypoint
    virtual void WaypointReached(uint32 waypointId, uint32 pathId) {}

    // ---- Helper utilities ----

    // Summon a creature at a position with optional despawn time
    Creature* DoSummon(uint32 entry, Position const& pos,
                       uint32 despawnTime = 30000,
                       TempSummonType summonType = TEMPSUMMON_CORPSE_TIMED_DESPAWN);

    // Summon near the creature itself
    Creature* DoSummonFlyer(uint32 entry, WorldObject* obj,
                             float flightZ, float radius = 5.0f,
                             uint32 despawnTime = 30000,
                             TempSummonType summonType = TEMPSUMMON_CORPSE_TIMED_DESPAWN);

    // True if the creature is in heroic difficulty
    bool IsHeroic() const;

    // Returns difficulty ID of the current instance
    Difficulty GetDifficulty() const;

    // Common combat helpers
    void DoCast(uint32 spellId);
    void DoCast(Unit* target, uint32 spellId, bool triggered = false);
    void DoCastSelf(uint32 spellId, bool triggered = false);
    void DoCastVictim(uint32 spellId, bool triggered = false);
    void DoCastAOE(uint32 spellId, bool triggered = false);

    // Talk (yell/say/whisper) using creature_text
    void Talk(uint8 id, WorldObject const* whisperTarget = nullptr);

protected:
    // Direct access to the creature this AI manages
    Creature* const me;
};
```

### 2.4 `BossAI` Class

`BossAI` extends `ScriptedAI` with automatic instance integration. Use this for any boss that is part of an instanced encounter.

```cpp
class BossAI : public ScriptedAI
{
public:
    BossAI(Creature* creature, uint32 bossId);

    // Automatically calls instance->SetBossState(bossId, IN_PROGRESS)
    void EnterCombat(Unit* victim) override;

    // Automatically calls instance->SetBossState(bossId, DONE), despawns summons
    void JustDied(Unit* killer) override;

    // Automatically calls instance->SetBossState(bossId, NOT_STARTED), despawns summons
    void EnterEvadeMode(EvadeReason why = EVADE_REASON_OTHER) override;

    // Despawns all tracked summons
    void JustSummoned(Creature* summon) override; // adds to summons list

protected:
    // The bossId passed to constructor — index into instance bosses array
    uint32 const _bossId;

    // Pointer to the instance script (cast from me->GetInstanceScript())
    InstanceScript* const instance;

    // Manages all summoned creatures; DespawnAll() called automatically on evade/death
    SummonList summons;

    // Task scheduler for periodic abilities (preferred over manual timer tracking)
    TaskScheduler scheduler;
};
```

**TaskScheduler example inside BossAI:**

```cpp
void EnterCombat(Unit* victim) override
{
    BossAI::EnterCombat(victim); // sets IN_PROGRESS state
    Talk(SAY_AGGRO);

    scheduler.Schedule(5s, [this](TaskContext ctx)
    {
        DoCastVictim(SPELL_SHADOW_BOLT);
        ctx.Repeat(8s, 12s); // repeat every 8-12 seconds
    });
    scheduler.Schedule(20s, [this](TaskContext ctx)
    {
        DoCastAOE(SPELL_BLIZZARD);
        ctx.Repeat(25s);
    });
}

void UpdateAI(uint32 diff) override
{
    if (!UpdateVictim())
        return;
    scheduler.Update(diff);
    DoMeleeAttackIfReady();
}
```

### 2.5 `InstanceMapScript` Wrapper

All instance scripts are wrapped in `InstanceMapScript`, which provides the factory pattern:

```cpp
class instance_your_dungeon : public InstanceMapScript
{
public:
    instance_your_dungeon() : InstanceMapScript("instance_your_dungeon", MAP_ID) {}

    InstanceScript* GetInstanceScript(InstanceMap* map) const override
    {
        return new instance_your_dungeon_InstanceScript(map);
    }

    struct instance_your_dungeon_InstanceScript : public InstanceScript
    {
        // ... your InstanceScript implementation
    };
};
```

### 2.6 Complete Basic Instance Script Example

Full working example demonstrating all major patterns:

```cpp
// src/server/scripts/MyDungeon/instance_my_dungeon.cpp

#include "ScriptMgr.h"
#include "InstanceScript.h"
#include "ScriptedCreature.h"
#include "Player.h"

// --- Boss and NPC entry IDs ---
enum MyDungeonNPCs
{
    NPC_FIRST_BOSS  = 100001,
    NPC_SECOND_BOSS = 100002,
    NPC_FINAL_BOSS  = 100003,
};

// --- Game object entry IDs ---
enum MyDungeonGameObjects
{
    GO_FIRST_BOSS_DOOR  = 200001,
    GO_SECOND_BOSS_DOOR = 200002,
    GO_FINAL_DOOR       = 200003,
    GO_CHEST            = 200010,
};

// --- Boss indices (0-based, must match SetBossState calls) ---
enum MyDungeonBosses
{
    BOSS_FIRST  = 0,
    BOSS_SECOND = 1,
    BOSS_FINAL  = 2,
    MAX_BOSSES  = 3,
};

// --- World states (for UI display) ---
enum MyDungeonWorldStates
{
    WS_FIRST_BOSS_DEAD  = 3000,
};

class instance_my_dungeon : public InstanceMapScript
{
public:
    instance_my_dungeon() : InstanceMapScript("instance_my_dungeon", 12345) {}

    InstanceScript* GetInstanceScript(InstanceMap* map) const override
    {
        return new instance_my_dungeon_InstanceScript(map);
    }

    struct instance_my_dungeon_InstanceScript : public InstanceScript
    {
        // Stored GUIDs for creatures and objects
        ObjectGuid FirstBossGUID;
        ObjectGuid SecondBossGUID;
        ObjectGuid FinalBossGUID;
        ObjectGuid FirstDoorGUID;
        ObjectGuid SecondDoorGUID;
        ObjectGuid FinalDoorGUID;
        ObjectGuid ChestGUID;

        explicit instance_my_dungeon_InstanceScript(InstanceMap* map)
            : InstanceScript(map)
        {
            // Tell the base class how many bosses to track for persistence
            SetHeaders("MY_DUNGEON");
            SetBossNumber(MAX_BOSSES);
        }

        // Called once when instance map loads — set up door/boss associations
        void Initialize() override
        {
            // Register boss-controlled doors so they auto-open/close with SetBossState
            // AddDoor(GO_ENTRY, bossId, DOOR_TYPE_ROOM or DOOR_TYPE_PASSAGE);
        }

        // Store GUIDs when creatures spawn
        void OnCreatureCreate(Creature* creature) override
        {
            switch (creature->GetEntry())
            {
                case NPC_FIRST_BOSS:
                    FirstBossGUID = creature->GetGUID();
                    break;
                case NPC_SECOND_BOSS:
                    SecondBossGUID = creature->GetGUID();
                    break;
                case NPC_FINAL_BOSS:
                    FinalBossGUID = creature->GetGUID();
                    break;
                default:
                    break;
            }
        }

        // Store GUIDs when game objects spawn
        void OnGameObjectCreate(GameObject* go) override
        {
            switch (go->GetEntry())
            {
                case GO_FIRST_BOSS_DOOR:
                    FirstDoorGUID = go->GetGUID();
                    // If boss 0 is done, ensure door is already open
                    if (GetBossState(BOSS_FIRST) == DONE)
                        HandleGameObject(FirstDoorGUID, true);
                    break;
                case GO_SECOND_BOSS_DOOR:
                    SecondDoorGUID = go->GetGUID();
                    if (GetBossState(BOSS_SECOND) == DONE)
                        HandleGameObject(SecondDoorGUID, true);
                    break;
                case GO_FINAL_DOOR:
                    FinalDoorGUID = go->GetGUID();
                    break;
                case GO_CHEST:
                    ChestGUID = go->GetGUID();
                    break;
                default:
                    break;
            }
        }

        // Expose GUIDs to boss AI scripts
        ObjectGuid GetGuidData(uint32 type) const override
        {
            switch (type)
            {
                case NPC_FIRST_BOSS:  return FirstBossGUID;
                case NPC_SECOND_BOSS: return SecondBossGUID;
                case NPC_FINAL_BOSS:  return FinalBossGUID;
                case GO_FINAL_DOOR:   return FinalDoorGUID;
                default:              return ObjectGuid::Empty;
            }
        }

        // Called by SetBossState — react to encounter state changes
        bool SetBossState(uint32 id, EncounterState state) override
        {
            if (!InstanceScript::SetBossState(id, state))
                return false;

            switch (id)
            {
                case BOSS_FIRST:
                    if (state == DONE)
                    {
                        HandleGameObject(FirstDoorGUID, true);  // Open passage
                        DoUpdateWorldState(WS_FIRST_BOSS_DEAD, 1);
                    }
                    break;
                case BOSS_SECOND:
                    if (state == DONE)
                        HandleGameObject(SecondDoorGUID, true);
                    break;
                case BOSS_FINAL:
                    if (state == DONE)
                    {
                        // Respawn loot chest after 5 minutes
                        DoRespawnGameObject(ChestGUID, 5 * MINUTE * IN_MILLISECONDS);
                    }
                    break;
                default:
                    break;
            }
            return true;
        }

        // Fill initial world state UI values when player enters
        void FillInitialWorldStates(WorldPackets::WorldState::InitWorldStates& packet) override
        {
            packet.Worldstates.push_back({ WS_FIRST_BOSS_DEAD,
                (GetBossState(BOSS_FIRST) == DONE) ? 1u : 0u });
        }
    };
};

// Boss AI example (attached via creature_template.ScriptName)
class boss_my_dungeon_final : public CreatureScript
{
public:
    boss_my_dungeon_final() : CreatureScript("boss_my_dungeon_final") {}

    struct boss_my_dungeon_finalAI : public BossAI
    {
        boss_my_dungeon_finalAI(Creature* creature) : BossAI(creature, BOSS_FINAL)
        {
        }

        void Reset() override
        {
            _Reset(); // BossAI helper: resets summons and scheduler
        }

        void EnterCombat(Unit* victim) override
        {
            BossAI::EnterCombat(victim);
            instance->SendEncounterUnit(1, me);

            scheduler.Schedule(6s, [this](TaskContext ctx)
            {
                DoCastVictim(SPELL_FIREBALL);
                ctx.Repeat(7s, 10s);
            });
        }

        void JustDied(Unit* killer) override
        {
            BossAI::JustDied(killer);
            instance->SendEncounterUnit(2, me);
            // Open final door via instance script's SetBossState(BOSS_FINAL, DONE)
            // which was already called by BossAI::JustDied
        }

        void UpdateAI(uint32 diff) override
        {
            if (!UpdateVictim())
                return;
            scheduler.Update(diff);
            DoMeleeAttackIfReady();
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return GetInstanceAI<boss_my_dungeon_finalAI>(creature);
    }
};

// Registration — called from scripts_list or equivalent
void AddSC_instance_my_dungeon()
{
    new instance_my_dungeon();
    new boss_my_dungeon_final();
}
```

### 2.7 Wiring the Script to the Database

```sql
-- 1. Register the instance in instance_template
INSERT INTO instance_template (map, parent, script, allowMount, resetTimeHeroic, resetTimeRaid)
VALUES (12345, 0, 'instance_my_dungeon', 0, 86400, 604800);

-- 2. Assign AI script to the final boss creature
UPDATE creature_template SET ScriptName = 'boss_my_dungeon_final'
WHERE entry = 100003;

-- 3. Register the encounter in instance_encounters (links to DungeonEncounter.dbc)
-- entry = DungeonEncounter.dbc ID for this boss
INSERT INTO instance_encounters (entry, creditType, creditEntry, lastEncounterDungeon, comment)
VALUES (9999, 0, 100003, 0, 'My Final Boss');
```

---

## 3. WorldScript Hooks

`WorldScript` hooks into global server-level events. Register by inheriting `WorldScript` and calling `new MyWorldScript()` in your `AddSC_` function.

### 3.1 All Virtual Methods

```cpp
class WorldScript : public ScriptObject
{
public:
    // Called once when the world server starts up (after DB load)
    virtual void OnStartup() {}

    // Called once when the world server is shutting down
    virtual void OnShutdown() {}

    // Called every world update tick (before most other updates)
    // diff = milliseconds since last tick
    virtual void OnWorldUpdate(uint32 diff) {}

    // Called before config is loaded (first load and reloads)
    // reload = true if this is a .reload config command, false on startup
    virtual void OnBeforeConfigLoad(bool reload) {}

    // Called after config is fully loaded
    virtual void OnAfterConfigLoad(bool reload) {}

    // Called when the MOTD is changed via command
    // Modify newMotd in-place to override the displayed text
    virtual void OnMotdChange(std::string& newMotd, LocaleConstant& locale) {}

    // Called when a shutdown is initiated (countdown starts)
    virtual void OnShutdownInitiate(ShutdownExitCode code, ShutdownMask mask) {}

    // Called when a pending shutdown is cancelled
    virtual void OnShutdownCancel() {}

    // Called when world open state changes (login queue opens/closes)
    virtual void OnOpenStateChange(bool open) {}

    // Called before world initialization (before map manager, etc.)
    virtual void OnBeforeWorldInitialized() {}

    // Called after all maps have been unloaded on shutdown
    virtual void OnAfterUnloadAllMaps() {}

    // Called to load any custom database tables you define
    virtual void OnLoadCustomDatabaseTable() {}

    // Called when finalizing a player's world session on character creation
    virtual void OnBeforeFinalizePlayerWorldSession(uint32& cacheVersion) {}
};
```

### 3.2 Example WorldScript

```cpp
class MyWorldScript : public WorldScript
{
public:
    MyWorldScript() : WorldScript("MyWorldScript") {}

    void OnStartup() override
    {
        LOG_INFO("server.loading", ">> MyWorldScript: Server started");
    }

    void OnWorldUpdate(uint32 diff) override
    {
        // Runs every server tick (~100ms intervals by default)
        // Accumulate diff and act on thresholds — never stall here
    }

    void OnShutdown() override
    {
        LOG_INFO("server.loading", ">> MyWorldScript: Server shutting down");
    }
};

void AddSC_my_world_script()
{
    new MyWorldScript();
}
```

---

## 4. Area Trigger System

Area triggers are invisible volumes in the world (defined in `AreaTrigger.dbc`) that fire server-side events when players walk through them.

### 4.1 `areatrigger_scripts` Table

Maps area trigger IDs to C++ ScriptNames.

| Column | Type | Key | Null | Description |
|--------|------|-----|------|-------------|
| `entry` | MEDIUMINT UNSIGNED | PRI | NO | Area trigger ID from `AreaTrigger.dbc` |
| `ScriptName` | CHAR(64) | — | NO | C++ script name, or `SmartTrigger` to use SmartAI |

### 4.2 `areatrigger_involvedrelation` Table

Links area triggers to quest exploration objectives.

| Column | Type | Key | Null | Description |
|--------|------|-----|------|-------------|
| `id` | MEDIUMINT UNSIGNED | PRI | NO | Area trigger ID from `AreaTrigger.dbc` |
| `quest` | MEDIUMINT UNSIGNED | — | NO | Quest ID (references `quest_template.ID`) |

When a player crosses this trigger, the exploration objective for the linked quest is satisfied.

### 4.3 `areatrigger_teleport` Table

Teleports players upon crossing (used for dungeon entrances, etc.).

| Column | Type | Null | Description |
|--------|------|------|-------------|
| `ID` | MEDIUMINT UNSIGNED | NO | Area trigger ID (PK) from `AreaTrigger.dbc` |
| `name` | TEXT | YES | Descriptive name (no gameplay effect) |
| `target_map` | SMALLINT UNSIGNED | NO | Destination map ID |
| `target_position_x` | FLOAT | NO | Destination X coordinate |
| `target_position_y` | FLOAT | NO | Destination Y coordinate |
| `target_position_z` | FLOAT | NO | Destination Z coordinate (altitude) |
| `target_orientation` | FLOAT | NO | Facing direction in radians (0–2π) at destination |

### 4.4 `AreaTriggerScript` C++ Class

```cpp
class AreaTriggerScript : public ScriptObject
{
public:
    // Called when a player enters the area trigger volume
    // Return true to consume the trigger (no further processing)
    // Return false to let the default handler also run
    virtual bool OnTrigger(Player* player, AreaTrigger const* trigger) { return false; }
};
```

Full implementation example:

```cpp
// Trigger fires when player enters a specific zone; grants an aura
class at_my_custom_trigger : public AreaTriggerScript
{
public:
    at_my_custom_trigger() : AreaTriggerScript("at_my_custom_trigger") {}

    bool OnTrigger(Player* player, AreaTrigger const* /*trigger*/) override
    {
        if (!player->IsAlive())
            return false;

        player->CastSpell(player, SPELL_MY_BUFF, true);
        return true; // prevent further processing
    }
};

void AddSC_my_area_triggers()
{
    new at_my_custom_trigger();
}
```

Register in DB:

```sql
INSERT INTO areatrigger_scripts (entry, ScriptName)
VALUES (1234, 'at_my_custom_trigger');
```

### 4.5 Finding Area Trigger IDs

- **In-game (GM):** Use `.gps` to get your position, then cross-reference with `AreaTrigger.dbc` by position.
- **GM command:** `.trigger nearest` or `.trigger <id>` to inspect triggers near you.
- **Database query:** `SELECT * FROM areatrigger_teleport WHERE name LIKE '%Stormwind%';`
- **DBC tools:** Use CASC/MPQ extraction tools to open `AreaTrigger.dbc` and search by map + coordinates.

### 4.6 SmartTrigger Usage

Setting `ScriptName = 'SmartTrigger'` routes the trigger through the SmartAI system. Create rows in `smart_scripts` with `source_type = 2` (SMART_SCRIPT_TYPE_AREATRIGGER) and the trigger `entry` as `entryorguid`.

---

## 5. Transport System

### 5.1 How Transports Work

Boats and zeppelins are type-15 GameObjects (`GAMEOBJECT_TYPE_MO_TRANSPORT`). They follow path data from `TransportAnimation.dbc`. The server moves the GO along the path and re-broadcasts its position to nearby clients on each tick.

Passengers (players, creatures) are attached to the transport's internal passenger list. Their position is stored relative to the transport (offset coordinates) and translated to world coordinates on demand.

Two internal types exist:
- `MotionTransport` — continuously moving (boats, zeppelins)
- `StaticTransport` — position-based, triggered (elevators, trams)

### 5.2 `transports` Table

| Column | Type | Key | Null | Default | Description |
|--------|------|-----|------|---------|-------------|
| `Guid` | INT UNSIGNED | PRI | NO | AUTO_INCREMENT | Unique row identifier |
| `Entry` | MEDIUMINT UNSIGNED | UNI | NO | 0 | References `gameobject_template.entry` (must be type 15) |
| `Name` | TEXT | — | YES | NULL | Arbitrary descriptive name |
| `ScriptName` | CHAR(64) | — | NO | '' | C++ TransportScript name (empty = no script) |

### 5.3 `TransportScript` C++ Hooks

```cpp
class TransportScript : public ScriptObject
{
public:
    // Called when a player boards the transport
    virtual void OnAddPassenger(Transport* transport, Player* player) {}

    // Called when a creature boards the transport (e.g., vendor NPCs on the boat)
    virtual void OnAddCreaturePassenger(Transport* transport, Creature* creature) {}

    // Called when a player disembarks from the transport
    virtual void OnRemovePassenger(Transport* transport, Player* player) {}

    // Called every update tick while the transport is active
    virtual void OnTransportUpdate(Transport* transport, uint32 diff) {}

    // Called when transport arrives at a waypoint
    // waypointId = waypoint index, mapId = current map, x/y/z = world position
    virtual void OnRelocate(Transport* transport, uint32 waypointId,
                            uint32 mapId, float x, float y, float z) {}
};
```

### 5.4 Getting Transport Position in C++

```cpp
// Transport inherits from GameObject which inherits from WorldObject
// Standard position methods work:
float x = transport->GetPositionX();
float y = transport->GetPositionY();
float z = transport->GetPositionZ();
float o = transport->GetOrientation();

// Get a passenger's absolute world position from their transport-relative offset:
float passengerX, passengerY, passengerZ;
transport->CalculatePassengerPosition(passengerX, passengerY, passengerZ);

// Get transport-relative offset from a world position:
float offsetX, offsetY, offsetZ;
transport->CalculatePassengerOffset(offsetX, offsetY, offsetZ);
```

---

## 6. Weather System

### 6.1 `game_weather` Table

Controls seasonal weather probabilities per zone. Percentages for all weather types in a season must not exceed 100 (remainder = clear/fine weather).

| Column | Type | Key | Null | Description |
|--------|------|-----|------|-------------|
| `zone` | MEDIUMINT UNSIGNED | PRI | NO | Zone ID from `AreaTable.dbc` |
| `spring_rain_chance` | TINYINT UNSIGNED | — | NO | % chance of rain in spring |
| `spring_snow_chance` | TINYINT UNSIGNED | — | NO | % chance of snow in spring |
| `spring_storm_chance` | TINYINT UNSIGNED | — | NO | % chance of storm in spring |
| `summer_rain_chance` | TINYINT UNSIGNED | — | NO | % chance of rain in summer |
| `summer_snow_chance` | TINYINT UNSIGNED | — | NO | % chance of snow in summer |
| `summer_storm_chance` | TINYINT UNSIGNED | — | NO | % chance of storm in summer |
| `fall_rain_chance` | TINYINT UNSIGNED | — | NO | % chance of rain in fall |
| `fall_snow_chance` | TINYINT UNSIGNED | — | NO | % chance of snow in fall |
| `fall_storm_chance` | TINYINT UNSIGNED | — | NO | % chance of storm in fall |
| `winter_rain_chance` | TINYINT UNSIGNED | — | NO | % chance of rain in winter |
| `winter_snow_chance` | TINYINT UNSIGNED | — | NO | % chance of snow in winter |
| `winter_storm_chance` | TINYINT UNSIGNED | — | NO | % chance of storm in winter |

Example — Icecrown heavy snow in winter:

```sql
INSERT INTO game_weather (zone,
    spring_rain_chance, spring_snow_chance, spring_storm_chance,
    summer_rain_chance, summer_snow_chance, summer_storm_chance,
    fall_rain_chance,   fall_snow_chance,   fall_storm_chance,
    winter_rain_chance, winter_snow_chance, winter_storm_chance)
VALUES (3523,
    10, 20, 5,
    5,  5,  0,
    10, 30, 5,
    0,  80, 10);
```

### 6.2 Weather Type Constants

These map to `WeatherState` in the client and server:

| ID | Constant | Description |
|----|----------|-------------|
| 0 | WEATHER_TYPE_FINE | Clear weather (no effect) |
| 1 | WEATHER_TYPE_RAIN | Rain (visual + sound) |
| 2 | WEATHER_TYPE_SNOW | Snow (visual + sound) |
| 3 | WEATHER_TYPE_STORM | Sandstorm / electrical storm |
| 22 | WEATHER_TYPE_SANDSTORM | Desert sandstorm |
| 86 | WEATHER_TYPE_THUNDERSTORM | Heavy thunderstorm |

The `grade` parameter (0.0–1.0) controls weather intensity.

### 6.3 `WeatherScript` Hooks

```cpp
class WeatherScript : public ScriptObject
{
public:
    // Called when weather state changes in a zone
    // state = new WeatherState, grade = intensity 0.0 (none) to 1.0 (maximum)
    virtual void OnWeatherChange(Weather* weather, WeatherState state, float grade) {}

    // Called every weather update tick
    virtual void OnWeatherUpdate(Weather* weather, uint32 diff) {}
};
```

### 6.4 Setting Weather via C++

```cpp
// Force weather on a specific map:
if (Map* map = sMapMgr->FindBaseNonInstanceMap(mapId))
    map->SetWeather(zoneId, WeatherState::WEATHER_STATE_HEAVY_RAIN, 1.0f);

// Send weather update directly to a single player's client:
player->GetSession()->SendWeatherUpdate(WEATHER_TYPE_RAIN, 0.75f);

// Using the Weather manager for a zone:
if (Weather* w = sWeatherMgr->FindWeather(zoneId))
    w->SetWeather(WEATHER_TYPE_SNOW, 0.5f);
else
    sWeatherMgr->AddWeather(zoneId)->SetWeather(WEATHER_TYPE_SNOW, 0.5f);
```

---

## 7. Game Events System

### 7.1 `game_event` Table

Controls all scheduled in-game events (seasonal holidays, daily events, etc.).

| Column | Type | Key | Null | Default | Description |
|--------|------|-----|------|---------|-------------|
| `eventEntry` | TINYINT UNSIGNED | PRI | NO | — | Unique event ID |
| `start_time` | TIMESTAMP | — | YES | NULL | Absolute earliest start datetime |
| `end_time` | TIMESTAMP | — | YES | NULL | Absolute latest end datetime (event will not start after this) |
| `occurrence` | BIGINT UNSIGNED | — | NO | — | Minutes between recurrences (2880 = 2 days, 525960 = ~1 year) |
| `length` | BIGINT UNSIGNED | — | NO | — | Duration in minutes the event lasts once started |
| `holiday` | MEDIUMINT UNSIGNED | — | NO | 0 | Client-side holiday ID from `Holidays.dbc` (0 = none) |
| `holidayStage` | TINYINT UNSIGNED | — | NO | 0 | Stage within multi-stage holiday |
| `description` | VARCHAR(255) | — | YES | NULL | Human-readable event name shown in console/logs |
| `world_event` | TINYINT UNSIGNED | — | NO | 0 | 0 = local event; 1 = world event (tracked globally) |
| `announce` | TINYINT UNSIGNED | — | YES | 2 | 0 = no announce; 1 = always announce; 2 = follow config |

### 7.2 WotLK Holiday IDs (Major Events)

| Holiday ID | Event Name |
|------------|------------|
| 141 | Hallow's End |
| 141 | Day of the Dead (overlaps Hallow's End period) |
| 147 | Pilgrim's Bounty |
| 141 | All Saints' Day (serverside Hallow's End variant) |
| 62 | Feast of Winter Veil |
| 64 | Lunar Festival |
| 65 | Love is in the Air |
| 26 | Noblegarden |
| 1 | Children's Week |
| 400 | Midsummer Fire Festival |
| 175 | Harvest Festival |
| 321 | Brewfest |
| 409 | Pirates' Day |
| 286 | Darkmoon Faire (Elwynn) |
| 287 | Darkmoon Faire (Mulgore) |
| 288 | Darkmoon Faire (Terokkar) |
| 372 | Arena Season (generic) |
| 404 | WoW's Anniversary |

### 7.3 `game_event_creature` Table

Spawns (or despawns) specific creature GUIDs only while the event is active.

| Column | Type | Null | Description |
|--------|------|------|-------------|
| `eventEntry` | SMALLINT SIGNED | NO | Event ID. **Positive** = spawn during event; **negative** = despawn during event |
| `guid` | INT UNSIGNED | NO | References `creature.guid` |

### 7.4 `game_event_gameobject` Table

Spawns (or despawns) specific game object GUIDs only while the event is active.

| Column | Type | Null | Description |
|--------|------|------|-------------|
| `eventEntry` | SMALLINT SIGNED | NO | Event ID. Positive = spawn; negative = despawn during event |
| `guid` | INT UNSIGNED | NO | References `gameobject.guid` |

### 7.5 `game_event_npc_vendor` Table

Adds items to an NPC vendor's inventory only while the event is active.

| Column | Type | Null | Description |
|--------|------|------|-------------|
| `eventEntry` | SMALLINT SIGNED | NO | Event ID (positive only) |
| `guid` | MEDIUMINT UNSIGNED | NO | NPC GUID (references `creature.guid`) |
| `slot` | SMALLINT SIGNED | NO | Vendor inventory slot position (references `npc_vendor.slot`) |
| `item` | MEDIUMINT UNSIGNED | NO | Item entry (references `item_template.entry`) |
| `maxcount` | MEDIUMINT UNSIGNED | NO | Max quantity available (0 = unlimited) |
| `incrtime` | MEDIUMINT UNSIGNED | NO | Restock time in seconds |
| `ExtendedCost` | MEDIUMINT UNSIGNED | NO | Extended currency cost ID (0 = none) |

### 7.6 `game_event_creature_quest` and `game_event_gameobject_quest`

These tables associate quests with specific creatures/GOs only during an event:

```sql
-- game_event_creature_quest
-- id (creature entry), quest (quest_template.ID), eventEntry

-- game_event_gameobject_quest
-- id (gameobject entry), quest (quest_template.ID), eventEntry
```

### 7.7 `GameEventScript` Hooks

```cpp
class GameEventScript : public ScriptObject
{
public:
    // Called when the event begins (server-side activation)
    virtual void OnGameEventStart(uint16 eventId) {}

    // Called when the event ends
    virtual void OnGameEventStop(uint16 eventId) {}

    // Called when the event is checked/evaluated
    virtual void OnGameEventCheck(uint16 eventId) {}
};
```

### 7.8 Checking Active Events in C++

```cpp
#include "GameEventMgr.h"

// Check if a specific event is currently active
if (sGameEventMgr->IsActiveEvent(GAME_EVENT_HALLOW_END))
{
    // Do holiday-specific logic
}

// Get all currently active events
GameEventMgr::ActiveEvents const& activeEvents = sGameEventMgr->GetActiveEventList();
for (uint16 eventId : activeEvents)
{
    LOG_INFO("scripts", "Active event: {}", eventId);
}
```

---

## 8. Coordinate System

### 8.1 Axis Conventions

WoW uses a right-hand coordinate system. The origin (0, 0) is roughly at the center of the world.

| Axis | Direction | Notes |
|------|-----------|-------|
| X | East is negative, West is positive | Opposite of most conventions |
| Y | North is positive, South is negative | Standard Y-up convention |
| Z | Altitude (up) | Height above sea level |
| O | Orientation / facing (radians) | 0 = East, π/2 = North, π = West, 3π/2 = South |

**Cardinal directions:**
- **North** = +Y direction
- **South** = −Y direction
- **East** = −X direction
- **West** = +X direction

Orientation `O` is measured counter-clockwise from East (the +X/−X boundary) in radians:
- `0.0` = East (facing negative X)
- `π/2 ≈ 1.571` = North (facing positive Y)
- `π ≈ 3.14159` = West (facing positive X)
- `3π/2 ≈ 4.712` = South (facing negative Y)

### 8.2 Retrieving Position in C++

Every `WorldObject` (Unit, Player, Creature, GameObject, Transport, etc.) inherits position accessors:

```cpp
// Basic position
float x = obj->GetPositionX();    // World X
float y = obj->GetPositionY();    // World Y
float z = obj->GetPositionZ();    // World Z (height/altitude)
float o = obj->GetOrientation();  // Facing in radians [0, 2π)

// Map context
uint32 mapId   = obj->GetMapId();
uint32 zoneId  = obj->GetZoneId();    // Zone (e.g., Icecrown = 4197)
uint32 areaId  = obj->GetAreaId();    // Sub-area

// Full position struct
Position pos = obj->GetPosition();    // Contains x, y, z, o

// Distance between two objects
float dist = obj->GetDistance(otherObj);           // 3D distance
float dist2d = obj->GetDistance2d(otherObj);       // XY plane only

// Get position offset from current facing
Position dest;
obj->GetNearPosition(dest, distance, angle);  // angle relative to facing
obj->GetFirstCollisionPosition(dest, distance, angle);
```

### 8.3 Map Tile System

The world maps use a **64 × 64 tile grid**:

| Property | Value |
|----------|-------|
| Total tiles per axis | 64 |
| Tile size (world units) | 533.33 yards |
| Total map width/height | 34,133 yards (~34 km) |
| ADT file coverage | One tile = one `.adt` file |
| Center tile | (32, 32) |

**Tile index to world coordinate conversion:**

```
world_x = (32 - tile_x) * 533.33
world_y = (32 - tile_y) * 533.33
```

**World coordinate to tile index:**

```
tile_x = floor(32 - (world_x / 533.33))
tile_y = floor(32 - (world_y / 533.33))
```

ADT file naming convention: `Map_XX_YY.adt` where XX = tile column (0–63) and YY = tile row (0–63).

### 8.4 Zone vs. World Coordinates

Zone/minimap coordinates displayed in the UI are relative to the zone bounding rectangle. The client calculates these from world coordinates using the zone's `AreaTable.dbc` bounding box fields. There is no server-side API for this conversion — compute it manually if needed:

```
ui_x = (world_x - zone_min_x) / (zone_max_x - zone_min_x)
ui_y = (world_y - zone_min_y) / (zone_max_y - zone_min_y)
```

---

## 9. Spawn Mask / Difficulty Flags

The `spawnMask` column on `creature` and `gameobject` tables is a bitmask that controls which difficulty modes a spawn appears in.

### 9.1 Bitmask Values

| Bit | Value | Difficulty |
|-----|-------|-----------|
| 0 | 1 | Normal 5-man / 10-man normal |
| 1 | 2 | Heroic 5-man |
| 2 | 4 | 10-man normal raid |
| 3 | 8 | 25-man normal raid |
| 4 | 16 | 10-man heroic raid |
| 5 | 32 | 25-man heroic raid |

### 9.2 Common SpawnMask Values

| SpawnMask | Decimal | Appears In |
|-----------|---------|-----------|
| `0x01` | 1 | Normal only (5-man normal / open world) |
| `0x02` | 2 | Heroic 5-man only |
| `0x03` | 3 | Normal + heroic 5-man |
| `0x04` | 4 | 10-man normal only |
| `0x08` | 8 | 25-man normal only |
| `0x0C` | 12 | 10-man and 25-man normal |
| `0x10` | 16 | 10-man heroic only |
| `0x20` | 32 | 25-man heroic only |
| `0x30` | 48 | Both heroic raid sizes |
| `0x3C` | 60 | All four raid difficulties |
| `0xFF` | 255 | All difficulties |

### 9.3 Usage Examples

```sql
-- Spawn a trash mob in all raid difficulties but not 5-man:
UPDATE creature SET spawnMask = 60 WHERE guid = 12345;

-- Spawn a boss in 25-man normal and 25-man heroic only:
UPDATE creature SET spawnMask = 40 WHERE guid = 12346;  -- 8 + 32 = 40

-- Spawn something everywhere (typical open-world creature):
UPDATE creature SET spawnMask = 1 WHERE guid = 12347;

-- Spawn in all modes:
UPDATE creature SET spawnMask = 255 WHERE guid = 12348;
```

### 9.4 Reading SpawnMask in C++

```cpp
// Map::GetDifficulty() returns Difficulty enum value
// Difficulty enum in Difficulty.h or SharedDefines.h

Difficulty diff = instance->GetDifficulty();

bool isHeroic = (diff == DUNGEON_DIFFICULTY_HEROIC
              || diff == RAID_DIFFICULTY_10MAN_HEROIC
              || diff == RAID_DIFFICULTY_25MAN_HEROIC);

bool is25Man  = (diff == RAID_DIFFICULTY_25MAN_NORMAL
              || diff == RAID_DIFFICULTY_25MAN_HEROIC);
```

---

## Cross-References

| Topic | Related Document |
|-------|-----------------|
| SmartAI system (for SmartTrigger and creature behaviors) | `10_smartai_system.md` |
| Creature scripting (ScriptedAI base, creature_template) | `03_creature_system.md` |
| Game Object scripting and templates | `08_gameobject_system.md` |
| Quest system (areatrigger_involvedrelation integration) | `07_quest_system.md` |
| Module system (how to register AddSC_ functions) | `01_module_system.md` |
| Database schema overview | `11_database_schema.md` |
| Player system (session, zone, position APIs) | `04_player_system.md` |

### Key AzerothCore Source Files

| File | Purpose |
|------|---------|
| `src/server/game/Instances/InstanceScript.h` | InstanceScript class, EncounterState enum, BossInfo struct |
| `src/server/game/AI/ScriptedAI/ScriptedAI.h` | ScriptedAI and BossAI base classes |
| `src/server/game/Scripting/ScriptMgr.h` | All script base classes including WorldScript, AreaTriggerScript, TransportScript, WeatherScript, GameEventScript |
| `src/server/game/Entities/Transport/Transport.h` | Transport class, MotionTransport, StaticTransport |
| `src/server/game/Weather/Weather.h` | Weather class and WeatherState enum |
| `src/server/game/Events/GameEventMgr.h` | sGameEventMgr singleton, IsActiveEvent() |
| `src/server/game/Maps/Map.h` | Map class, SetWeather(), GetDifficulty() |
| `src/server/game/World/WorldPosition.h` | Position struct, coordinate utilities |

### Key DBC Files Referenced

| DBC File | Purpose |
|----------|---------|
| `Maps.dbc` | Map IDs, map types, names |
| `AreaTrigger.dbc` | Area trigger IDs, positions, radii |
| `AreaTable.dbc` | Zone and area IDs, bounding boxes |
| `DungeonEncounter.dbc` | Boss encounter IDs for instance_encounters |
| `LfgDungeon.dbc` | LFG dungeon IDs for lastEncounterDungeon |
| `Holidays.dbc` | Holiday IDs for game_event.holiday |
| `TransportAnimation.dbc` | Transport path animation data |
| `WeatherSounds.dbc` | Weather sound set IDs |
