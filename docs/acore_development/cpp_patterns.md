# C++ Patterns and Utilities

Reference for common C++ patterns, utility classes, and key API methods used in AzerothCore module development.

---

## 1. ObjectMgr — The Game Object Database

`sObjectMgr` is a global singleton (accessed via the macro `sObjectMgr`) that provides access to static game data loaded from the database at startup. Use it to look up templates and spawn data.

```cpp
#include "ObjectMgr.h"
```

**Key methods:**

```cpp
// Template lookups (read from creature_template, item_template, etc.)
CreatureTemplate const* ct = sObjectMgr->GetCreatureTemplate(uint32 entry);
ItemTemplate const*     it = sObjectMgr->GetItemTemplate(uint32 entry);
Quest const*            q  = sObjectMgr->GetQuestTemplate(uint32 questId);

// Iterate all templates
CreatureTemplateContainer const* all = sObjectMgr->GetCreatureTemplates();

// Creature addons
CreatureAddon const* addon = sObjectMgr->GetCreatureTemplateAddon(uint32 entry);
```

Always null-check the return value — `GetCreatureTemplate` returns `nullptr` if the entry does not exist in the database.

**`CreatureTemplate` key fields** (from `creature_template` table):

```cpp
ct->Entry           // uint32 — NPC entry ID
ct->Name            // std::string
ct->minlevel        // uint8
ct->maxlevel        // uint8
ct->faction         // uint32
ct->npcflag         // uint32
ct->rank            // uint32 (CREATURE_ELITE_NORMAL, etc.)
ct->type            // uint32 (beast, humanoid, etc.)
ct->type_flags      // uint32
ct->flags_extra     // uint32 (CreatureFlagsExtra bitmask)
ct->AIName          // std::string — e.g. "SmartAI"
ct->ScriptID        // uint32
ct->ModHealth       // float — health multiplier
ct->ModMana         // float
ct->MechanicImmuneMask  // uint32
ct->spells[8]       // uint32[MAX_CREATURE_SPELLS]
ct->lootid          // uint32
ct->mingold         // uint32
ct->maxgold         // uint32
```

**`CreatureData`** is the per-spawn instance (from `creature` table, one row per world spawn):

```cpp
// CreatureData fields
data->id1       // uint32 — entry (maps to CreatureTemplate)
data->mapid     // uint16
data->posX/Y/Z  // float — spawn position
data->orientation
data->spawntimesecs
data->movementType
```

---

## 2. ObjectAccessor — Finding Live Game Objects

`ObjectAccessor` functions search for objects that are currently spawned and loaded into memory. They are **not** for looking up static template data.

```cpp
#include "ObjectAccessor.h"
```

**Finding players (global, any map):**

```cpp
// Returns a player if they are in the world (any map). Thread-unsafe — use only from the world thread.
Player* player = ObjectAccessor::FindPlayer(ObjectGuid guid);

// Returns a player if they have an active session, regardless of world state.
Player* player = ObjectAccessor::FindConnectedPlayer(ObjectGuid guid);

// Find by name
Player* player = ObjectAccessor::FindPlayerByName(std::string const& name, bool checkInWorld = true);

// Find by low GUID (uint32 counter portion)
Player* player = ObjectAccessor::FindPlayerByLowGUID(ObjectGuid::LowType lowguid);
```

**Finding objects within a map context** (requires a `WorldObject` for map lookup):

```cpp
// These only find objects on the same map as the reference WorldObject
Creature*      c  = ObjectAccessor::GetCreature(*worldObject, ObjectGuid guid);
Unit*          u  = ObjectAccessor::GetUnit(*worldObject, ObjectGuid guid);
GameObject*    go = ObjectAccessor::GetGameObject(*worldObject, ObjectGuid guid);
WorldObject*   wo = ObjectAccessor::GetWorldObject(*worldObject, ObjectGuid guid);
Player*        p  = ObjectAccessor::GetPlayer(*worldObject, ObjectGuid guid);
```

**Iterating all online players:**

```cpp
// Iterate all players. The map is locked during iteration via HashMapHolder's shared_mutex.
// Do not call FindPlayer or other ObjectAccessor functions that lock inside this loop.
auto& players = ObjectAccessor::GetPlayers();
for (auto& [guid, player] : players)
{
    // process player
}
```

---

## 3. ObjectGuid System

`ObjectGuid` is a 64-bit value that uniquely identifies every game object. It encodes a high-type byte (the object type), an optional entry (for creatures/GOs), and a counter (the spawn/instance index).

```cpp
#include "ObjectGuid.h"
```

**Creating and using GUIDs:**

```cpp
ObjectGuid guid = player->GetGUID();
ObjectGuid guid = creature->GetGUID();

// Get the raw 64-bit integer (for storing in database or maps)
uint64 rawValue = guid.GetRawValue();

// Restore from a stored uint64
ObjectGuid restored = ObjectGuid(rawValue);

// Check emptiness
guid.IsEmpty()   // true if _guid == 0
if (!guid) { }   // operator bool() returns !IsEmpty()
```

**Type-checking methods:**

```cpp
guid.IsPlayer()            // HighGuid::Player
guid.IsCreature()          // HighGuid::Unit
guid.IsPet()               // HighGuid::Pet
guid.IsVehicle()           // HighGuid::Vehicle
guid.IsCreatureOrPet()     // creature or pet
guid.IsAnyTypeCreature()   // creature, pet, or vehicle
guid.IsUnit()              // any creature type OR player
guid.IsGameObject()        // HighGuid::GameObject
guid.IsItem()              // HighGuid::Item
guid.IsDynamicObject()
guid.IsCorpse()
guid.IsGroup()
guid.IsInstance()
```

**Extracting components:**

```cpp
uint32 entry   = guid.GetEntry();    // creature/GO entry (0 for players/items)
uint32 counter = guid.GetCounter();  // spawn/instance index
// For DB storage use GetCounter() as the character GUID, GetRawValue() for full GUID
```

**The GUID safety pattern — never store raw pointers across calls:**

Pointers to `Player`, `Creature`, or other world objects can become dangling at any point outside the immediate call stack — objects can be removed from the map, die, or log out between server ticks. The correct pattern is to store the `ObjectGuid` and re-acquire the pointer at the point of use:

```cpp
// WRONG — pointer may be dangling by the time the lambda runs
Player* dangling = player;
scheduler.Schedule(5s, [dangling]() { dangling->CastSpell(...); }); // crash risk

// CORRECT — capture by GUID, recover pointer inside the callback
ObjectGuid playerGuid = player->GetGUID();
scheduler.Schedule(5s, [playerGuid]() {
    Player* p = ObjectAccessor::FindPlayer(playerGuid);
    if (!p) return; // player logged out or is gone — safe exit
    p->CastSpell(p, SPELL_SOMETHING, true);
});
```

The same rule applies to class member variables in script objects: store `ObjectGuid _targetGuid`, not `Unit* _target`.

**Common typedef aliases:**

```cpp
typedef std::set<ObjectGuid>          GuidSet;
typedef std::list<ObjectGuid>         GuidList;
typedef std::deque<ObjectGuid>        GuidDeque;
typedef std::vector<ObjectGuid>       GuidVector;
typedef std::unordered_set<ObjectGuid> GuidUnorderedSet;
```

---

## 4. Unit and Player Key Methods

### Health and Power

```cpp
// Health
uint32 hp    = unit->GetHealth();
uint32 maxHp = unit->GetMaxHealth();
float  pct   = unit->GetHealthPct();           // 0.0–100.0
unit->SetHealth(uint32 val);
unit->SetMaxHealth(uint32 val);
unit->SetFullHealth();

bool full  = unit->IsFullHealth();
bool below = unit->HealthBelowPct(int32 pct);  // true if health < pct% of max
bool above = unit->HealthAbovePct(int32 pct);  // true if health > pct% of max
// Variant that accounts for pending damage (useful in DamageTaken hook):
bool below = unit->HealthBelowPctDamaged(int32 pct, uint32 damage);

uint32 threshold = unit->CountPctFromMaxHealth(int32 pct); // raw HP value at pct%

// Power (Powers enum: POWER_MANA=0, POWER_RAGE=1, POWER_ENERGY=3, etc.)
uint32 mana    = unit->GetPower(POWER_MANA);
uint32 maxMana = unit->GetMaxPower(POWER_MANA);
float  manaPct = unit->GetPowerPct(POWER_MANA);
unit->SetPower(Powers power, uint32 val, bool withPowerUpdate = true);
```

### State Checks

```cpp
bool alive    = unit->IsAlive();     // DeathState::Alive
bool dead     = !unit->IsAlive();
bool combat   = unit->IsInCombat();  // UNIT_FLAG_IN_COMBAT set
bool engaged  = unit->IsEngaged();   // same as IsInCombat()
bool combatWith = unit->IsInCombatWith(Unit const* who);
```

### Position and Movement

```cpp
// Position getters (inherited from Position/WorldObject)
float x   = unit->GetPositionX();
float y   = unit->GetPositionY();
float z   = unit->GetPositionZ();
float o   = unit->GetOrientation();

uint32 mapId = unit->GetMapId();
Map*   map   = unit->GetMap();

// Distance
float dist2D  = unit->GetDistance2d(WorldObject* target);
float dist3D  = unit->GetDistance(WorldObject* target);
float dist3D  = unit->GetDistance(float x, float y, float z);
float exactDist = unit->GetExactDist(WorldObject* target); // no sqrt approximation

bool within   = unit->IsWithinDist(WorldObject* obj, float dist, bool is3D = true);
bool within2D = unit->IsWithinDist2d(float x, float y, float dist);
bool inRange  = unit->IsInRange(WorldObject* obj, float minRange, float maxRange);

// Near teleport (same map, no loading screen)
unit->NearTeleportTo(float x, float y, float z, float o,
    bool casting = false, bool vehicleTeleport = false,
    bool withPet = false, bool removeTransport = false);
unit->NearTeleportTo(Position& pos, bool casting = false);
```

### Spells and Auras

```cpp
// Casting — returns SpellCastResult (SPELL_CAST_OK on success)
unit->CastSpell(Unit* victim, uint32 spellId, bool triggered = false);
unit->CastSpell(Unit* victim, uint32 spellId, TriggerCastFlags triggerFlags);
unit->CastSpell(float x, float y, float z, uint32 spellId, bool triggered);
unit->CastSpell(Unit* victim, SpellInfo const* spellInfo, bool triggered);

// TriggerCastFlags for common cases:
//   TRIGGERED_NONE            — normal cast, can fail
//   TRIGGERED_FULL_MASK       — bypasses almost all checks
//   true (bool overload)      — same as TRIGGERED_FULL_MASK shorthand

// Auras — apply without casting (no cast time, no range check)
Aura* aura = unit->AddAura(uint32 spellId, Unit* target);
Aura* aura = unit->AddAura(SpellInfo const* spellInfo, uint8 effMask, Unit* target);

// Check / get auras
bool      has  = unit->HasAura(uint32 spellId);
Aura*     aur  = unit->GetAura(uint32 spellId);  // returns nullptr if not present
uint32    cnt  = unit->GetAuraCount(uint32 spellId);
bool      hasT = unit->HasAuraType(AuraType auraType);

// Aura effects
AuraEffect* eff = unit->GetAuraEffect(uint32 spellId, uint8 effIndex);
AuraEffectList const& list = unit->GetAuraEffectsByType(AuraType type);

// Remove auras
unit->RemoveAurasDueToSpell(uint32 spellId);
unit->RemoveAura(uint32 spellId);
unit->RemoveAurasByType(AuraType auraType);
unit->RemoveAurasWithMechanic(uint32 mechanic_mask);

// Immunity
bool immune = unit->IsImmunedToSpell(SpellInfo const* spellInfo);
bool immune = unit->IsImmunedToSpellEffect(SpellInfo const* spellInfo, uint32 index);
```

### Combat

```cpp
// Start/stop attacking
bool started = unit->Attack(Unit* victim, bool meleeAttack);
bool stopped = unit->AttackStop();

// Current target
Unit* victim = unit->GetVictim();       // unit's attack target

// Threat
ThreatMgr& tm = unit->GetThreatMgr();

// Direct damage (static method)
uint32 Unit::DealDamage(
    Unit* attacker, Unit* victim, uint32 damage,
    CleanDamage const* cleanDamage = nullptr,
    DamageEffectType damagetype = DIRECT_DAMAGE,
    SpellSchoolMask damageSchoolMask = SPELL_SCHOOL_MASK_NORMAL,
    SpellInfo const* spellProto = nullptr,
    bool durabilityLoss = true,
    bool allowGM = false,
    Spell const* spell = nullptr
);

// Heal (static method)
int32 Unit::DealHeal(Unit* healer, Unit* victim, uint32 addhealth);

// Damage types (DamageEffectType):
//   DIRECT_DAMAGE       — normal weapon swing
//   SPELL_DIRECT_DAMAGE — spell/ability hit
//   DOT                 — damage over time tick
//   HEAL                — healing
//   SELF_DAMAGE         — self-inflicted
```

### Player-Specific Methods

```cpp
#include "Player.h"

// XP
player->GiveXP(uint32 xp, Unit* victim, float group_rate = 1.0f, bool isLFGReward = false);

// Money (amounts are in copper: 1 GOLD = 10000 copper)
uint32 money = player->GetMoney();
bool ok      = player->ModifyMoney(int32 amount, bool sendError = true); // negative = subtract
bool enough  = player->HasEnoughMoney(uint32 amount);

// Items
bool added = player->AddItem(uint32 itemId, uint32 count);
player->DestroyItemCount(uint32 item, uint32 count, bool update, bool unequip_check = false);
bool has   = player->HasItemCount(uint32 item, uint32 count = 1, bool inBankAlso = false);

// Spells (note: lowercase 'l' in learnSpell)
player->learnSpell(uint32 spellId, bool temporary = false, bool learnFromSkill = false);
bool known = player->HasSpell(uint32 spellId); // overrides Unit::HasSpell

// Teleport (cross-map, triggers loading screen)
bool ok = player->TeleportTo(uint32 mapid, float x, float y, float z, float orientation,
    uint32 options = 0, Unit* target = nullptr, bool newInstance = false);
bool ok = player->TeleportTo(WorldLocation const& loc, uint32 options = 0);

// Session / messaging
WorldSession* session = player->GetSession();
session->SendNotification("Welcome!");                    // yellow notification text
session->SendAreaTriggerMessage("You entered a zone!");   // area trigger message

// Direct system message via ChatHandler
ChatHandler(player->GetSession()).PSendSysMessage("Your money: {}", player->GetMoney());
ChatHandler(player->GetSession()).SendSysMessage("Hello!");
```

---

## 5. ScriptedAI — Creature Script Base

`ScriptedAI` inherits from `CreatureAI` (which inherits from `UnitAI`). It is the standard base class for custom creature scripts.

```cpp
#include "ScriptedCreature.h"

struct MyCreatureAI : public ScriptedAI
{
    explicit MyCreatureAI(Creature* creature) : ScriptedAI(creature) {}
    // 'me' is available as Creature* me (inherited from ScriptedAI)
};
```

**Core virtual methods (all have empty defaults in ScriptedAI):**

```cpp
void Reset() override;                                     // creature resets (evade or respawn)
void JustEngagedWith(Unit* who) override;                  // first enters combat
void JustDied(Unit* killer) override;                      // creature dies
void KilledUnit(Unit* victim) override;                    // creature kills something
void JustSummoned(Creature* summon) override;              // successfully summoned a creature
void SummonedCreatureDespawn(Creature* summon) override;   // a summon despawns
void SpellHit(Unit* caster, SpellInfo const* spell) override;
void SpellHitTarget(Unit* target, SpellInfo const* spell) override;
void MovementInform(uint32 type, uint32 id) override;      // waypoint/charge reached
void DamageTaken(Unit* attacker, uint32& damage,
    DamageEffectType damagetype, SpellSchoolMask mask) override;
void UpdateAI(uint32 diff) override;                       // called every world tick
void AttackStart(Unit* target) override;                   // before JustEngagedWith
```

**Inherited from `CreatureAI`:**

```cpp
bool UpdateVictim();       // returns false if no valid target; call at top of UpdateAI
void EnterEvadeMode(EvadeReason why = EVADE_REASON_OTHER);
void Talk(uint8 id, WorldObject const* whisperTarget = nullptr, Milliseconds delay = 0ms);
void DoZoneInCombat(Creature* creature = nullptr, float maxRange = 250.0f);
```

**Inherited from `UnitAI` (spell helpers):**

```cpp
SpellCastResult DoCast(uint32 spellId);
SpellCastResult DoCast(Unit* victim, uint32 spellId, bool triggered = false);
SpellCastResult DoCastSelf(uint32 spellId, bool triggered = false);
SpellCastResult DoCastVictim(uint32 spellId, bool triggered = false);
SpellCastResult DoCastAOE(uint32 spellId, bool triggered = false);
SpellCastResult DoCastToAllHostilePlayers(uint32 spellId, bool triggered = false);
SpellCastResult DoCastRandomTarget(uint32 spellId, uint32 threatTablePosition = 0,
    float dist = 0.0f, bool playerOnly = true, bool triggered = false, bool withTank = true);
```

**ScriptedAI helpers:**

```cpp
// Target selection
Player* GetPlayerAtMinimumRange(float minRange);
Player* SelectTargetFromPlayerList(float maxdist, uint32 excludeAura = 0, bool mustBeInLOS = false) const;
Unit*   DoSelectLowestHpFriendly(float range, uint32 minHPDiff = 1);
std::list<Creature*> DoFindFriendlyCC(float range);
std::list<Creature*> DoFindFriendlyMissingBuff(float range, uint32 spellId);

// Threat manipulation
void DoAddThreat(Unit* unit, float amount);
void DoModifyThreatByPercent(Unit* unit, int32 pct);
void DoResetThreat(Unit* unit);
void DoResetThreatList();
float DoGetThreat(Unit* unit);

// Movement helpers
void DoStartMovement(Unit* target, float distance = 0.0f, float angle = 0.0f);
void DoStartNoMovement(Unit* target);
void DoStopAttack();
void DoTeleportPlayer(Unit* unit, float x, float y, float z, float o);
void DoTeleportAll(float x, float y, float z, float o);

// Misc
Creature* DoSpawnCreature(uint32 entry, float offsetX, float offsetY, float offsetZ,
    float angle, uint32 type, uint32 despawntime);
bool IsHeroic() const;
bool Is25ManRaid() const;
Difficulty GetDifficulty() const;
bool HealthBelowPct(uint32 pct) const;  // wraps me->HealthBelowPct
bool HealthAbovePct(uint32 pct) const;

// Invincibility / auto-attack control
void SetInvincibility(bool apply);  // allows dropping to 1 HP but prevents death
void SetAutoAttackAllowed(bool allow);

// Difficulty-mode helpers (returns appropriate value for current difficulty)
template<class T>
const T& DUNGEON_MODE(const T& normal5, const T& heroic10) const;

template<class T>
const T& RAID_MODE(const T& n10, const T& n25) const;

template<class T>
const T& RAID_MODE(const T& n10, const T& n25, const T& h10, const T& h25) const;
```

### SummonList

`BossAI` provides a `SummonList summons` member. `ScriptedAI` does not — you must declare your own.

```cpp
SummonList summons; // declare as member in your AI struct
// Initialize in constructor:
MyCreatureAI(Creature* c) : ScriptedAI(c), summons(c) {}

// In JustSummoned:
void JustSummoned(Creature* summon) override { summons.Summon(summon); }

// Despawn all tracked summons (optional delay)
summons.DespawnAll();
summons.DespawnAll(Milliseconds(500));

// Despawn by entry
summons.DespawnEntry(uint32 entry);

// Send action to all summons
summons.DoAction(int32 info);

// Check state
bool alive  = summons.IsAnyCreatureAlive();
bool combat = summons.IsAnyCreatureInCombat();
bool hasIt  = summons.HasEntry(uint32 entry);
uint32 cnt  = summons.GetEntryCount(uint32 entry);
Creature* c = summons.GetCreatureWithEntry(uint32 entry);

// Engage all summons with nearby players
summons.DoZoneInCombat();

// Iterate manually
for (ObjectGuid guid : summons)
{
    if (Creature* summon = ObjectAccessor::GetCreature(*me, guid))
    {
        // process summon
    }
}

// Lambda iteration (does not modify storage while iterating)
summons.DoForAllSummons([](WorldObject* obj) {
    if (Creature* c = obj->ToCreature())
        c->CastSpell(c, SOME_SPELL, true);
});
```

### BossAI

`BossAI` extends `ScriptedAI` and adds instance script integration, EventMap, and health-check events. Use it for instance bosses.

```cpp
class boss_myBoss : public CreatureScript
{
public:
    boss_myBoss() : CreatureScript("boss_myBoss") {}

    struct boss_myBossAI : public BossAI
    {
        boss_myBossAI(Creature* c) : BossAI(c, DATA_MY_BOSS_ID) {}

        void Reset() override { _Reset(); }
        void JustEngagedWith(Unit* who) override
        {
            _JustEngagedWith();
            events.ScheduleEvent(EVENT_FIREBALL, 5s);
        }
        void JustDied(Unit* who) override { _JustDied(); }
        void EnterEvadeMode(EvadeReason why) override { _EnterEvadeMode(why); }

        void ExecuteEvent(uint32 eventId) override
        {
            switch (eventId)
            {
                case EVENT_FIREBALL:
                    DoCastVictim(SPELL_FIREBALL);
                    events.Repeat(8s, 12s);
                    break;
            }
        }

        // BossAI provides: instance, summons, events (EventMap)
    };

    CreatureAI* GetAI(Creature* c) const override
    {
        return GetInstanceAI<boss_myBossAI>(c);
    }
};
```

`BossAI` protected helpers:

```cpp
void _Reset();             // clears events, despawns summons, sets not-active
void _JustEngagedWith();   // sets active, may call TeleportCheaters
void _JustDied();          // saves boss state as DONE, clears summons
void _JustReachedHome();   // sets inactive
void _EnterEvadeMode(EvadeReason why);
void TeleportCheaters();   // teleports players outside the boss room

// Health-based event trigger (fired from DamageTaken via ProcessHealthCheck)
void ScheduleHealthCheckEvent(uint32 healthPct, std::function<void()> exec,
    bool allowedWhileCasting = true);
void ScheduleHealthCheckEvent(std::initializer_list<uint8> healthPcts,
    std::function<void()> exec, bool allowedWhileCasting = true);

// Enrage timer — casts spell after timer regardless of cast state
void ScheduleEnrageTimer(uint32 spellId, Milliseconds timer, uint8 textId = 0);
```

### Grid Searchers (global helpers from ScriptedCreature.h)

```cpp
Creature*    GetClosestCreatureWithEntry(WorldObject* source, uint32 entry,
    float maxRange, bool alive = true);
GameObject*  GetClosestGameObjectWithEntry(WorldObject* source, uint32 entry,
    float maxRange, bool onlySpawned = false);

void GetCreatureListWithEntryInGrid(std::list<Creature*>& list,
    WorldObject* source, uint32 entry, float maxRange);
void GetGameObjectListWithEntryInGrid(std::list<GameObject*>& list,
    WorldObject* source, uint32 entry, float maxRange);
void GetDeadCreatureListInGrid(std::list<Creature*>& list,
    WorldObject* source, float maxRange, bool alive = false);
```

### TaskScheduler (from ScriptedAI helpers)

`ScriptedAI` exposes `ScheduleTimedEvent` wrappers. For direct `TaskScheduler` use inside `BossAI`, declare a `TaskScheduler _scheduler` member and update it in `UpdateAI`.

```cpp
// ScriptedAI wrappers:
void ScheduleTimedEvent(Milliseconds timerMin, Milliseconds timerMax,
    std::function<void()> exec, Milliseconds repeatMin,
    Milliseconds repeatMax = 0ms, uint32 uniqueId = 0);

// Convenience overload (timerMin = 0)
void ScheduleTimedEvent(Milliseconds timerMax, std::function<void()> exec,
    Milliseconds repeatMin, Milliseconds repeatMax = 0ms, uint32 uniqueId = 0);

// One-shot (requires non-zero uniqueId)
void ScheduleUniqueTimedEvent(Milliseconds timer, std::function<void()> exec,
    uint32 uniqueId);
```

Direct `TaskScheduler` usage (when you need full control):

```cpp
#include "TaskScheduler.h"

TaskScheduler _scheduler;

void UpdateAI(uint32 diff) override
{
    _scheduler.Update(diff);
    if (!UpdateVictim()) return;
    // ...
}

void JustEngagedWith(Unit*) override
{
    _scheduler.Schedule(5s, [this](TaskContext ctx) {
        DoCastVictim(SPELL_SOMETHING);
        ctx.Repeat(8s, 12s); // re-schedule with random window
    });
}
```

---

## 6. Manual Timer Pattern

When you do not need `TaskScheduler` or `EventMap`, the classic countdown timer pattern is straightforward and zero-dependency:

```cpp
class MyCreatureAI : public ScriptedAI
{
    uint32 _spellTimer;
    uint32 _checkTimer;

public:
    explicit MyCreatureAI(Creature* c) : ScriptedAI(c) {}

    void Reset() override
    {
        _spellTimer = 5000; // ms
        _checkTimer = 1000;
    }

    void UpdateAI(uint32 diff) override
    {
        if (!UpdateVictim())
            return;

        if (_spellTimer <= diff)
        {
            DoCastVictim(SPELL_SOMETHING);
            _spellTimer = 8000;
        }
        else
            _spellTimer -= diff;

        if (_checkTimer <= diff)
        {
            if (HealthBelowPct(50))
                DoCastSelf(SPELL_ENRAGE, true);
            _checkTimer = 1000;
        }
        else
            _checkTimer -= diff;
    }
};
```

Rules:
- `if (timer <= diff)` handles the case where `diff` is larger than the remaining time in a single tick.
- Reset timers on `Reset()` so they are correct after evade and respawn.
- Timers keep their value across calls where they do not fire — subtract `diff`, never set to `0` without resetting to the next interval.

---

## 7. Logging

AzerothCore uses the `fmt` library for log formatting. Use `{}` placeholders, not `%s`/`%u`.

```cpp
#include "Log.h"

LOG_FATAL("module", "Critical failure in {}: entry {}", moduleName, entry);
LOG_ERROR("module", "Failed to find creature entry {}", entry);
LOG_WARN("module",  "Unexpected state for player {}", player->GetName());
LOG_INFO("module",  "Player {} logged in, loading data", player->GetName());
LOG_DEBUG("module", "Tick diff={}, timer={}", diff, _timer);
LOG_TRACE("module", "Very verbose: value={}", someValue);
```

Log levels in order of severity (FATAL is highest):
`LOG_FATAL > LOG_ERROR > LOG_WARN > LOG_INFO > LOG_DEBUG > LOG_TRACE`

The string passed as the first argument is the **logger name** — use your module name consistently (e.g., `"module.dreamforge"`). Log output is filtered by level and logger in `Logger.conf`.

---

## 8. Common Patterns

### Safe Pointer Access (GUID Pattern)

```cpp
// Store as GUID in class member
ObjectGuid _tankGuid;

// Set it when you acquire a valid pointer
void JustEngagedWith(Unit* who) override
{
    if (who->IsPlayer())
        _tankGuid = who->GetGUID();
}

// Recover safely before use
void SomeSpellLogic()
{
    Player* tank = ObjectAccessor::FindPlayer(_tankGuid);
    if (!tank || !tank->IsAlive())
        return;
    DoCast(tank, SPELL_MARK_TANK);
}
```

### Sending Messages to Players

```cpp
// Yellow notification bar (top of screen)
player->GetSession()->SendNotification("Welcome to the server!");

// Area trigger message (center of screen, small)
player->GetSession()->SendAreaTriggerMessage("You have discovered something.");

// Grey system message in chat (supports fmt-style via PSendSysMessage)
ChatHandler(player->GetSession()).PSendSysMessage("Your gold: {}", player->GetMoney() / 10000);
ChatHandler(player->GetSession()).SendSysMessage("A plain system message.");

// Creature talking (uses creature_text DB table)
creature->AI()->Talk(0);           // say text id 0 to nearby
creature->AI()->Talk(0, player);   // whisper text id 0 to specific player
```

### OnLogin Cache Pattern

```cpp
class MyPlayerScript : public PlayerScript
{
public:
    MyPlayerScript() : PlayerScript("MyPlayerScript") {}

    void OnPlayerLogin(Player* player, bool /*firstLogin*/) override
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT value FROM my_module_table WHERE guid = {}",
            player->GetGUID().GetCounter());
        if (result)
            _cache[player->GetGUID()] = result->Fetch()[0].Get<uint32>();
        else
            _cache[player->GetGUID()] = 0;
    }

    void OnPlayerLogout(Player* player) override
    {
        _cache.erase(player->GetGUID());
    }

private:
    std::unordered_map<ObjectGuid, uint32> _cache;
};
```

### Spawning a Temporary Creature

```cpp
// DoSpawnCreature (relative offsets from caster):
Creature* add = DoSpawnCreature(
    NPC_ENTRY,
    offsetX, offsetY, offsetZ,
    angle,
    TEMPSUMMON_TIMED_DESPAWN,  // SummonType
    30000                       // despawn after 30s
);

// Direct summon at absolute position via map:
if (TempSummon* summon = me->SummonCreature(
    NPC_ENTRY,
    x, y, z, orientation,
    TEMPSUMMON_CORPSE_DESPAWN))
{
    summons.Summon(summon);
}
```

### Creature React State

```cpp
me->SetReactState(REACT_AGGRESSIVE); // attack on sight
me->SetReactState(REACT_PASSIVE);    // never auto-attack
me->SetReactState(REACT_NEUTRAL);    // attack only if attacked
me->HasReactState(REACT_PASSIVE);    // check current state
```

---

## 9. sWorld — Global World Operations

`sWorld` is a macro for `getWorldInstance()` which returns the `World*` singleton. It implements the `IWorld` interface.

```cpp
#include "World.h"

// Config access
uint32 val  = sWorld->getIntConfig(CONFIG_MAX_PLAYER_LEVEL);
bool   flag = sWorld->getBoolConfig(CONFIG_ALLOW_TWO_SIDE_ACCOUNTS);
float  rate = sWorld->getRate(RATE_XP_KILL);

// Server state
bool   shutting  = sWorld->IsShuttingDown();
uint32 timeLeft  = sWorld->GetShutDownTimeLeft();
std::string_view dbVer = sWorld->GetDBVersion();
std::string const& name = sWorld->GetRealmName();
LocaleConstant loc = sWorld->GetDefaultDbcLocale();
```

For player counts and session queries, use `sWorldSessionMgr` (from `WorldSessionMgr.h`):

```cpp
#include "WorldSessionMgr.h"
uint32 activeSessions = sWorldSessionMgr->GetActiveSessionCount();
```

For server-wide player messaging, use `sWorld->SendWorldText` if available in your build, otherwise send via iterating `ObjectAccessor::GetPlayers()`:

```cpp
// Broadcast to all online players
auto& players = ObjectAccessor::GetPlayers();
for (auto& [guid, player] : players)
    ChatHandler(player->GetSession()).SendSysMessage("Server announcement!");
```

---

## 10. Required Include Headers

Minimal includes for common module tasks:

```cpp
#include "ScriptMgr.h"          // ScriptMgr, RegisterCreatureScript, etc.
#include "Player.h"              // Player class + GiveXP, ModifyMoney, etc.
#include "Creature.h"            // Creature class
#include "Unit.h"                // Unit base class (health, spells, combat)
#include "DatabaseEnv.h"         // WorldDatabase, CharacterDatabase, LoginDatabase
#include "ObjectMgr.h"           // sObjectMgr, CreatureTemplate, ItemTemplate, Quest
#include "ObjectAccessor.h"      // ObjectAccessor::FindPlayer, GetCreature, etc.
#include "ScriptedCreature.h"    // ScriptedAI, BossAI, WorldBossAI, SummonList
#include "Log.h"                 // LOG_INFO, LOG_ERROR, LOG_DEBUG, etc.
#include "Config.h"              // sConfigMgr->GetOption<T>()
#include "Chat.h"                // ChatHandler
#include "SpellInfo.h"           // SpellInfo class
#include "SpellMgr.h"            // sSpellMgr->GetSpellInfo(id)
#include "DBCStores.h"           // sSpellStore, sAreaTableStore, sMapStore, etc.
#include "TaskScheduler.h"       // TaskScheduler, TaskContext
#include "EventMap.h"            // EventMap (used in BossAI)
#include "InstanceScript.h"      // InstanceScript base class
#include "CreatureScript.h"      // CreatureScript registration (newer ACore)
#include "PlayerScript.h"        // PlayerScript base class
#include "WorldScript.h"         // WorldScript base class
```

**Registration macros (at end of .cpp file):**

```cpp
// Creature script
void AddSC_my_module()
{
    RegisterCreatureScript(MyCreatureAI);  // or: new MyCreatureScript(); (older pattern)
}

// Player script
void AddSC_my_module()
{
    new MyPlayerScript();
}
```

Declare `void AddSC_my_module();` in the module's script loader header and call it from the loader `.cpp`.
