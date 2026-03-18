# SmartAI System

## Overview

SmartAI is AzerothCore's data-driven AI scripting system. Instead of writing C++ `CreatureScript` subclasses that must be compiled into the server binary, SmartAI reads behavior rules from the `smart_scripts` database table at server startup (or on `.reload smart_scripts`) and drives NPC logic entirely through those rows. The engine is implemented in `src/server/game/AI/SmartScripts/SmartScript.cpp` and `SmartScriptMgr.h`.

### What SmartAI Is

Each row in `smart_scripts` is an **Event → Action → Target** triplet:

- **Event** — *when* does this row fire? (health threshold crossed, player enters LOS, spell hits, etc.)
- **Action** — *what happens* when it fires? (cast a spell, talk, summon a creature, change phase, etc.)
- **Target** — *who or what* is affected by the action?

Multiple rows share the same `entryorguid`/`source_type`, creating a complete behavior set for one NPC, GameObject, or AreaTrigger.

### When to Use SmartAI vs. Other Approaches

| Approach | Best For | Limitations |
|---|---|---|
| **SmartAI** | Standard mobs, patrols, gossip, quest NPCs, simple bosses, anything achievable with built-in event/action primitives | Cannot express arbitrary C++ logic; complex math/data structures are awkward |
| **Eluna Lua** (`RegisterCreatureEvent`) | Quick iterative scripting, custom game systems, prototyping | Slightly higher per-call overhead than C++; needs Eluna module enabled |
| **CreatureScript C++** | Complex boss fights, unique mechanics, performance-critical inner loops, interactions with custom modules | Requires recompile and server restart for every change |

For most world content (patrol guards, dungeon trash, quest NPCs, simple scripted events), SmartAI is the fastest and safest path. For raid boss encounters with intricate phase logic, C++ is often cleaner. Eluna fills the middle ground well.

### Performance Notes

SmartAI evaluates all registered events on an NPC every AI update tick. Events that fire periodically (UPDATE_IC, UPDATE_OOC) use internal timers and only execute when their timer expires, so cost is low for idle NPCs. LOS events (OOC_LOS, IC_LOS) are more expensive because they require distance checks. The `event_flags` `SMART_EVENT_FLAG_NOT_REPEATABLE` eliminates repeat evaluations for one-shot events after they fire.

### Integration with AzerothCore Internals

- Creatures use SmartAI when their `creature_template.AIName = 'SmartAI'`.
- GameObjects use it when `gameobject_template.AIName = 'SmartGameObjectAI'`.
- AreaTriggers use it when `areatrigger_scripts.ScriptName = 'SmartTrigger'`.

The `SmartAIMgr` singleton loads all rows on startup, validates references (spell IDs, quest IDs, creature entries, etc.) against the live world database, and logs errors to `sql.sql`. The `SmartAI` class (a `CreatureAI` subclass) holds the event list per NPC and processes it on each tick.

### Enabling SmartAI

```sql
-- For a creature entry (all instances):
UPDATE creature_template SET AIName = 'SmartAI' WHERE entry = 1234;

-- For a specific creature instance (by GUID):
-- Use negative entryorguid in smart_scripts (no template change required unless
-- you also want the entry-level scripts active alongside it).

-- For a GameObject:
UPDATE gameobject_template SET AIName = 'SmartGameObjectAI' WHERE entry = 5678;

-- For an AreaTrigger:
INSERT INTO areatrigger_scripts (entry, ScriptName) VALUES (123, 'SmartTrigger');
```

---

## smart_scripts Table Schema

```sql
CREATE TABLE `smart_scripts` (
  `entryorguid`     INT(11) NOT NULL,
  `source_type`     TINYINT(3) UNSIGNED NOT NULL DEFAULT 0,
  `id`              SMALLINT(5) UNSIGNED NOT NULL DEFAULT 0,
  `link`            SMALLINT(5) UNSIGNED NOT NULL DEFAULT 0,
  `event_type`      TINYINT(3) UNSIGNED NOT NULL DEFAULT 0,
  `event_phase_mask` SMALLINT(5) UNSIGNED NOT NULL DEFAULT 0,
  `event_chance`    TINYINT(3) UNSIGNED NOT NULL DEFAULT 100,
  `event_flags`     SMALLINT(5) UNSIGNED NOT NULL DEFAULT 0,
  `event_param1`    INT(11) UNSIGNED NOT NULL DEFAULT 0,
  `event_param2`    INT(11) UNSIGNED NOT NULL DEFAULT 0,
  `event_param3`    INT(11) UNSIGNED NOT NULL DEFAULT 0,
  `event_param4`    INT(11) UNSIGNED NOT NULL DEFAULT 0,
  `event_param5`    INT(11) UNSIGNED NOT NULL DEFAULT 0,
  `event_param6`    INT(11) UNSIGNED NOT NULL DEFAULT 0,
  `action_type`     TINYINT(3) UNSIGNED NOT NULL DEFAULT 0,
  `action_param1`   INT(11) UNSIGNED NOT NULL DEFAULT 0,
  `action_param2`   INT(11) UNSIGNED NOT NULL DEFAULT 0,
  `action_param3`   INT(11) UNSIGNED NOT NULL DEFAULT 0,
  `action_param4`   INT(11) UNSIGNED NOT NULL DEFAULT 0,
  `action_param5`   INT(11) UNSIGNED NOT NULL DEFAULT 0,
  `action_param6`   INT(11) UNSIGNED NOT NULL DEFAULT 0,
  `target_type`     TINYINT(3) UNSIGNED NOT NULL DEFAULT 0,
  `target_param1`   INT(11) UNSIGNED NOT NULL DEFAULT 0,
  `target_param2`   INT(11) UNSIGNED NOT NULL DEFAULT 0,
  `target_param3`   INT(11) UNSIGNED NOT NULL DEFAULT 0,
  `target_param4`   INT(11) UNSIGNED NOT NULL DEFAULT 0,
  `target_x`        FLOAT NOT NULL DEFAULT 0,
  `target_y`        FLOAT NOT NULL DEFAULT 0,
  `target_z`        FLOAT NOT NULL DEFAULT 0,
  `target_o`        FLOAT NOT NULL DEFAULT 0,
  `comment`         TEXT NOT NULL,
  PRIMARY KEY (`entryorguid`, `source_type`, `id`, `link`)
);
```

### Column Reference

#### `entryorguid` (INT SIGNED)

- **Positive value**: references a `creature_template.entry` (or `gameobject_template.entry`). All spawns of that template share the script.
- **Negative value**: references a specific `creature.guid` (or `gameobject.guid`). Only that specific world object uses the script.
- When using a negative GUID with `source_type=0`, you do **not** need to set `AIName='SmartAI'` on the template — the GUID-specific script takes effect automatically provided the template is not overriding. The `SMART_EVENT_FLAG_DONT_RESET` / `DONT_OVERRIDE_SAI_ENTRY` mechanism allows GUID-specific and entry-level scripts to coexist for movement vs. combat AI.

#### `source_type` (TINYINT UNSIGNED)

| Value | Constant | Object Type |
|---|---|---|
| 0 | SMART_SCRIPT_TYPE_CREATURE | Creature (NPC) |
| 1 | SMART_SCRIPT_TYPE_GAMEOBJECT | GameObject |
| 2 | SMART_SCRIPT_TYPE_AREATRIGGER | AreaTrigger |
| 9 | SMART_SCRIPT_TYPE_TIMED_ACTIONLIST | Timed Action List (called by SMART_ACTION_CALL_TIMED_ACTIONLIST) |

#### `id` (SMALLINT UNSIGNED)

Sequential row number, starting at 0, scoped per `entryorguid`+`source_type`. Each row must have a unique `id`. The ordering of `id` values does not affect execution order — events fire independently based on their triggers.

#### `link` (SMALLINT UNSIGNED)

Links this row to another row's `id`. When this row's event fires and its action executes, the engine immediately fires the row whose `id` equals `link` (using event type `SMART_EVENT_LINK = 61`). Set to `0` for no linking.

The linked row must have `event_type = 61` (`SMART_EVENT_LINK`). Link chains can be arbitrarily long but are not recursive — you cannot create loops. Linking is the primary mechanism for firing multiple independent actions from a single trigger event.

#### `event_phase_mask` (SMALLINT UNSIGNED)

A bitmask controlling which encounter phases this row is active in.

| Value | Meaning |
|---|---|
| 0 | Active in **all** phases (always fires regardless of current phase) |
| 1 | Active in phase 1 only |
| 2 | Active in phase 2 only |
| 4 | Active in phase 3 only |
| 8 | Active in phase 4 only |
| 16 | Active in phase 5 only |
| 32 | Active in phase 6 only |
| 64 | Active in phase 7 only |
| 128 | Active in phase 8 only |
| 256 | Active in phase 9 only |
| 512 | Active in phase 10 only |
| 1024 | Active in phase 11 only |
| 2048 | Active in phase 12 only |

To activate a row in multiple specific phases, OR the bits together. For example, `event_phase_mask = 3` means active in phases 1 and 2. Phases 1–12 are set using `SMART_ACTION_SET_EVENT_PHASE` or `SMART_ACTION_INC_EVENT_PHASE`.

#### `event_chance` (TINYINT UNSIGNED)

Percentage probability (1–100) that the event fires when its trigger condition is met. Use 100 for guaranteed execution. Values of 0 are treated as 100 by the engine but 0 is not recommended.

#### `event_flags` (SMALLINT UNSIGNED)

Bitmask of behavioral modifiers for the event.

| Flag Value | Hex | Name | Description |
|---|---|---|---|
| 1 | 0x001 | SMART_EVENT_FLAG_NOT_REPEATABLE | Event fires at most once per combat/spawn. After firing, it is disabled for the remainder of the encounter. |
| 2 | 0x002 | SMART_EVENT_FLAG_DIFFICULTY_0 | Only fires in dungeon Normal mode (10-man Normal for raids) |
| 4 | 0x004 | SMART_EVENT_FLAG_DIFFICULTY_1 | Only fires in dungeon Heroic mode (25-man Normal for raids) |
| 8 | 0x008 | SMART_EVENT_FLAG_DIFFICULTY_2 | Only fires in 10-man Heroic (raids) |
| 16 | 0x010 | SMART_EVENT_FLAG_DIFFICULTY_3 | Only fires in 25-man Heroic (raids) |
| 32 | 0x020 | SMART_EVENT_FLAG_RESERVED_5 | Reserved |
| 64 | 0x040 | SMART_EVENT_FLAG_RESERVED_6 | Reserved |
| 128 | 0x080 | SMART_EVENT_FLAG_DEBUG_ONLY | Event only fires when SmartAI debug mode is enabled |
| 256 | 0x100 | SMART_EVENT_FLAG_DONT_RESET | Event is not reset when the creature resets/evades |
| 512 | 0x200 | SMART_EVENT_FLAG_WHILE_CHARMED | Event fires even when creature is charmed |

Difficulty flags 2, 4, 8, 16 can be combined to allow the event in multiple specific difficulties. If no difficulty flags are set, the event fires in all difficulties.

#### `event_param1` – `event_param6`

Meaning depends entirely on `event_type`. See the SMART_EVENT Types section below for per-event parameter descriptions.

#### `action_type` (TINYINT UNSIGNED)

The action to execute. See the SMART_ACTION Types section below.

#### `action_param1` – `action_param6`

Meaning depends entirely on `action_type`.

#### `target_type` (TINYINT UNSIGNED)

How to select the target(s) for the action. See the SMART_TARGET Types section below.

#### `target_param1` – `target_param4`

Meaning depends entirely on `target_type`.

#### `target_x`, `target_y`, `target_z`, `target_o` (FLOAT)

Used only by `SMART_TARGET_POSITION (8)` and a few movement actions. These are world coordinates. `target_o` is orientation in radians.

#### `comment` (TEXT)

Human-readable description of what this row does. Convention: `"NPC Name - Event Description - Action Description"`. Example: `"Krick - On Aggro - Talk Group 0"`. This is never read by the engine but is critical for maintainability.

---

## Phase System

Phases allow an NPC's behavior to change during an encounter without creating separate script entries. The current phase is a single integer (0–12) stored on the AI instance.

### How event_phase_mask Filtering Works

On every event evaluation, the engine checks:

```
if (event_phase_mask != 0 && !(event_phase_mask & (1 << current_phase)))
    skip this event
```

- Phase `0` in `event_phase_mask` means "always active" (0 has no bits set, so the check is bypassed).
- Phase `1` requires bit 0 set, meaning `event_phase_mask` must include `1`.
- Phase `2` requires bit 1, so `event_phase_mask` must include `2`.
- Phase `3` requires `event_phase_mask` to include `4`.

### Changing Phases

```sql
-- Set to a specific phase:
-- action_type=22, action_param1=2  → sets to phase 2

-- Increment the current phase by 1:
-- action_type=23, action_param1=1, action_param2=0

-- Set to a random phase from a list:
-- action_type=30, params = list of up to 6 phase values

-- Set to a random phase in a range:
-- action_type=31, action_param1=minPhase, action_param2=maxPhase
```

### Typical Phase Pattern: HP-based Transitions

```sql
-- Phase 1 combat (default phase 0 → effectively always-on before transition)
-- At 66% HP, switch to phase 1
INSERT INTO smart_scripts VALUES
(1234, 0, 0, 0,  2, 0, 100, 1,   66, 66, 0, 0, 0, 0,   22, 1, 0, 0, 0, 0, 0,   1, 0, 0, 0, 0, 0, 0, 0, 0, 'Boss - At 66% HP - Set Phase 1'),
-- Phase 1 specific row: fires only in phase 1
(1234, 0, 1, 0,  0, 2, 100, 0,   5000, 5000, 8000, 15000, 0, 0,   11, 12345, 0, 0, 0, 0, 0,   2, 0, 0, 0, 0, 0, 0, 0, 0, 'Boss - Phase1 - Cast Spell');
```

---

## Event Linking

The `link` field creates chains: when row A fires, its linked row B fires immediately after A's actions complete.

### How It Works

1. Row A has `link = 5` (pointing to row with `id = 5`).
2. Row 5 must have `event_type = 61` (SMART_EVENT_LINK) so it never fires independently.
3. When row A's event triggers, A's actions run, then row 5's actions run in the same tick.

### Multiple Chained Actions

```
Row id=0: event=AGGRO, link=1, action=TALK group 0
Row id=1: event=LINK,  link=2, action=CAST spell 1234
Row id=2: event=LINK,  link=0, action=SET_REACT_STATE aggressive
```

This fires three actions in sequence from one aggro event.

### Limitations

- Linked rows cannot themselves have a meaningful event; `event_type` must be 61 (LINK).
- You cannot create circular links (A→B→A). The engine does not guard against this but it would cause a hang.
- Phase masks on linked rows are respected — if a linked row's phase mask excludes the current phase, it still skips.
- The invoker of the parent event is passed through to linked rows, so `SMART_TARGET_ACTION_INVOKER` works in linked rows.

---

## SMART_EVENT Types

All 111 event types (IDs 0–83 standard TrinityCore/AzerothCore shared, 100–111 AzerothCore extensions).

**Common parameters used across multiple events:**

- `InitialMin/InitialMax` — first-fire delay range in milliseconds
- `RepeatMin/RepeatMax` — repeat timer range in milliseconds after first fire
- `CooldownMin/CooldownMax` — cooldown range after the event fires

| ID | Name | Description | Param1 | Param2 | Param3 | Param4 | Param5 | Param6 |
|---|---|---|---|---|---|---|---|---|
| 0 | SMART_EVENT_UPDATE_IC | Periodic timer, fires only **in combat**. Repeating. | InitialMin (ms) | InitialMax (ms) | RepeatMin (ms) | RepeatMax (ms) | | |
| 1 | SMART_EVENT_UPDATE_OOC | Periodic timer, fires only **out of combat**. Stopped when combat begins; restarted when combat ends. | InitialMin (ms) | InitialMax (ms) | RepeatMin (ms) | RepeatMax (ms) | | |
| 2 | SMART_EVENT_HEALTH_PCT | Fires when NPC's health % enters the specified range. `SMART_EVENT_FLAG_NOT_REPEATABLE` (flag=1) is almost always used here. | HPMin% | HPMax% | RepeatMin (ms) | RepeatMax (ms) | | |
| 3 | SMART_EVENT_MANA_PCT | Fires when NPC's mana % enters the specified range. | ManaMin% | ManaMax% | RepeatMin (ms) | RepeatMax (ms) | | |
| 4 | SMART_EVENT_AGGRO | Fires once when the NPC first enters combat (generates threat from a player). No params. | | | | | | |
| 5 | SMART_EVENT_KILL | Fires when the NPC kills a unit. | CooldownMin (ms) | CooldownMax (ms) | Player only (0=any, 1=players only) | Creature entry (0=any) | | |
| 6 | SMART_EVENT_DEATH | Fires when the NPC dies. No params. | | | | | | |
| 7 | SMART_EVENT_EVADE | Fires when the NPC evades (leaves combat and returns home). No params. | | | | | | |
| 8 | SMART_EVENT_SPELLHIT | Fires when the NPC is hit by a spell (as the target). | SpellID (0=any) | School bitmask (0=any) | CooldownMin (ms) | CooldownMax (ms) | | |
| 9 | SMART_EVENT_RANGE | Fires periodically while the NPC's current victim is within the specified distance range. | InitialMin (ms) | InitialMax (ms) | RepeatMin (ms) | RepeatMax (ms) | MinDist (yards) | MaxDist (yards) |
| 10 | SMART_EVENT_OOC_LOS | Fires when a unit enters the NPC's LOS **out of combat**. Hostile mode controls who triggers it. | HostilityMode (0=hostile, 1=not hostile, 2=any) | MaxRange (yards) | CooldownMin (ms) | CooldownMax (ms) | Player only (0/1) | |
| 11 | SMART_EVENT_RESPAWN | Fires when the NPC respawns. | Type (0=none, 1=map, 2=area) | MapID | ZoneID | | | |
| 12 | SMART_EVENT_TARGET_HEALTH_PCT | Fires when the NPC's current target's health % enters the range. | HPMin% | HPMax% | RepeatMin (ms) | RepeatMax (ms) | | |
| 13 | SMART_EVENT_VICTIM_CASTING | Fires periodically while the NPC's victim is casting a spell. | RepeatMin (ms) | RepeatMax (ms) | SpellID (0=any spell) | | | |
| 14 | SMART_EVENT_FRIENDLY_HEALTH | Fires when a friendly unit within range has a health deficit (missing HP) greater than the threshold. | HPDeficit (flat HP value) | Radius (yards) | RepeatMin (ms) | RepeatMax (ms) | | |
| 15 | SMART_EVENT_FRIENDLY_IS_CC | Fires when a friendly unit within radius is crowd-controlled. | Radius (yards) | RepeatMin (ms) | RepeatMax (ms) | | | |
| 16 | SMART_EVENT_FRIENDLY_MISSING_BUFF | Fires when a friendly unit within radius is missing a specific buff. | SpellID | Radius (yards) | RepeatMin (ms) | RepeatMax (ms) | onlyInCombat (0/1) | |
| 17 | SMART_EVENT_SUMMONED_UNIT | Fires when the NPC summons a creature. The summoned creature is the invoker. | CreatureEntry (0=any summon) | CooldownMin (ms) | CooldownMax (ms) | | | |
| 18 | SMART_EVENT_TARGET_MANA_PCT | Fires when the NPC's current target's mana % enters the range. | ManaMin% | ManaMax% | RepeatMin (ms) | RepeatMax (ms) | | |
| 19 | SMART_EVENT_ACCEPTED_QUEST | Fires when a player accepts a quest from the NPC. | QuestID (0=any) | CooldownMin (ms) | CooldownMax (ms) | | | |
| 20 | SMART_EVENT_REWARD_QUEST | Fires when a player turns in (rewards) a quest at the NPC. | QuestID (0=any) | CooldownMin (ms) | CooldownMax (ms) | | | |
| 21 | SMART_EVENT_REACHED_HOME | Fires when the NPC completes its evade path and reaches its home/spawn position. No params. | | | | | | |
| 22 | SMART_EVENT_RECEIVE_EMOTE | Fires when the NPC receives a `/emote` from a player. The player is the invoker. | EmoteID | CooldownMin (ms) | CooldownMax (ms) | | | |
| 23 | SMART_EVENT_HAS_AURA | Fires periodically while the NPC has a specific aura (or a specific stack count of it). | SpellID | Min stack count (0=any) | RepeatMin (ms) | RepeatMax (ms) | | |
| 24 | SMART_EVENT_TARGET_BUFFED | Fires periodically while the NPC's target has a specific aura. | SpellID | Min stack count | RepeatMin (ms) | RepeatMax (ms) | | |
| 25 | SMART_EVENT_RESET | Fires when the AI is reset (typically when the NPC evades and all timers restart). No params. | | | | | | |
| 26 | SMART_EVENT_IC_LOS | Same as OOC_LOS but fires **in combat**. | HostilityMode (0=hostile, 1=not hostile, 2=any) | MaxRange (yards) | CooldownMin (ms) | CooldownMax (ms) | Player only (0/1) | |
| 27 | SMART_EVENT_PASSENGER_BOARDED | Fires when a unit boards a vehicle seat on this NPC. | CooldownMin (ms) | CooldownMax (ms) | | | | |
| 28 | SMART_EVENT_PASSENGER_REMOVED | Fires when a passenger is removed from this vehicle NPC. | CooldownMin (ms) | CooldownMax (ms) | | | | |
| 29 | SMART_EVENT_CHARMED | Fires when the NPC is charmed or un-charmed. | onRemove (0=on charm applied, 1=on charm removed) | | | | | |
| 30 | SMART_EVENT_CHARMED_TARGET | Fires when the NPC's charm target changes. No params. | | | | | | |
| 31 | SMART_EVENT_SPELLHIT_TARGET | Fires when a spell cast by the NPC hits its target. | SpellID (0=any) | School bitmask (0=any) | RepeatMin (ms) | RepeatMax (ms) | | |
| 32 | SMART_EVENT_DAMAGED | Fires when the NPC takes damage within a specified range. | MinDamage | MaxDamage | RepeatMin (ms) | RepeatMax (ms) | | |
| 33 | SMART_EVENT_DAMAGED_TARGET | Fires when the NPC deals damage to its target within a range. | MinDamage | MaxDamage | RepeatMin (ms) | RepeatMax (ms) | | |
| 34 | SMART_EVENT_MOVEMENTINFORM | Fires when a movement generator sends a "reached point" notification. | MovementType (0=any; POINT=8, ESCORT=17) | PointID (0=any) | | | | |
| 35 | SMART_EVENT_SUMMON_DESPAWNED | Fires when a creature summoned by this NPC despawns. | CreatureEntry (0=any) | CooldownMin (ms) | CooldownMax (ms) | | | |
| 36 | SMART_EVENT_CORPSE_REMOVED | Fires when the NPC's corpse is removed from the world (after loot/despawn timer). No params. | | | | | | |
| 37 | SMART_EVENT_AI_INIT | Fires once when the AI is first initialized on spawn. Fires before JUST_CREATED. No params. | | | | | | |
| 38 | SMART_EVENT_DATA_SET | Fires when another script calls `SetData(field, value)` on this NPC. | Field | Value | CooldownMin (ms) | CooldownMax (ms) | | |
| 39 | SMART_EVENT_ESCORT_START | Fires when an escort starts. (Deprecated; prefer WAYPOINT_REACHED for new scripts.) | PointID (0=any) | PathID (0=any) | | | | |
| 40 | SMART_EVENT_ESCORT_REACHED | Fires when a waypoint is reached during escort. (Deprecated; prefer WAYPOINT_REACHED.) | PointID (0=any) | PathID (0=any) | | | | |
| 41 | SMART_EVENT_TRANSPORT_ADDPLAYER | Fires when a player boards a transport (this NPC must be on the transport). No params. | | | | | | |
| 42 | SMART_EVENT_TRANSPORT_ADDCREATURE | Fires when a creature boards a transport. | CreatureEntry | | | | | |
| 43 | SMART_EVENT_TRANSPORT_REMOVE_PLAYER | Fires when a player disembarks a transport. No params. | | | | | | |
| 44 | SMART_EVENT_TRANSPORT_RELOCATE | Fires when a transport reaches a waypoint. | PointID | | | | | |
| 45 | SMART_EVENT_INSTANCE_PLAYER_ENTER | Fires when a player enters the instance zone. | Team (0=any, 469=Alliance, 67=Horde) | CooldownMin (ms) | CooldownMax (ms) | | | |
| 46 | SMART_EVENT_AREATRIGGER_ONTRIGGER | Fires when an areatrigger is activated. Used with `source_type=2`. | TriggerID (0=any) | | | | | |
| 47 | SMART_EVENT_QUEST_ACCEPTED | Fires when a quest is accepted (quest script hook). | QuestID | | | | | |
| 48 | SMART_EVENT_QUEST_OBJ_COMPLETION | Fires when a quest objective is completed. | QuestID | | | | | |
| 49 | SMART_EVENT_QUEST_COMPLETION | Fires when all quest objectives are completed (quest becomes complete). | QuestID | | | | | |
| 50 | SMART_EVENT_QUEST_REWARDED | Fires when a quest is turned in and rewarded. | QuestID | | | | | |
| 51 | SMART_EVENT_QUEST_FAIL | Fires when a quest is failed. | QuestID | | | | | |
| 52 | SMART_EVENT_TEXT_OVER | Fires when creature_text speech finishes playing (duration expires). | creature_text.GroupID | CreatureEntry (0=any, NPC must be this entry) | | | | |
| 53 | SMART_EVENT_RECEIVE_HEAL | Fires when the NPC receives a heal within the specified range. | MinHeal | MaxHeal | CooldownMin (ms) | CooldownMax (ms) | | |
| 54 | SMART_EVENT_JUST_SUMMONED | Fires immediately after this NPC is summoned by another unit. No params. | | | | | | |
| 55 | SMART_EVENT_ESCORT_PAUSED | Fires when an escort is paused. (Deprecated.) | PointID (0=any) | PathID (0=any) | | | | |
| 56 | SMART_EVENT_ESCORT_RESUMED | Fires when an escort is resumed. (Deprecated.) | PointID (0=any) | PathID (0=any) | | | | |
| 57 | SMART_EVENT_ESCORT_STOPPED | Fires when an escort is stopped. (Deprecated.) | PointID (0=any) | PathID (0=any) | | | | |
| 58 | SMART_EVENT_ESCORT_ENDED | Fires when an escort completes. (Deprecated.) | PointID (0=any) | PathID (0=any) | | | | |
| 59 | SMART_EVENT_TIMED_EVENT_TRIGGERED | Fires when a timed event created with SMART_ACTION_CREATE_TIMED_EVENT fires. | EventID | | | | | |
| 60 | SMART_EVENT_UPDATE | Periodic timer that fires both in and out of combat (unlike UPDATE_IC/OOC). | InitialMin (ms) | InitialMax (ms) | RepeatMin (ms) | RepeatMax (ms) | | |
| 61 | SMART_EVENT_LINK | **Not a real trigger.** Used only as the target of a `link` field. This row fires when another row chains to it. Never put a real event condition here. | | | | | | |
| 62 | SMART_EVENT_GOSSIP_SELECT | Fires when a player selects a gossip menu option. | gossip_menu_option.MenuID | gossip_menu_option.OptionID | | | | |
| 63 | SMART_EVENT_JUST_CREATED | Fires when the NPC is first created in the world (on initial load or respawn). No params. | | | | | | |
| 64 | SMART_EVENT_GOSSIP_HELLO | Fires when a player opens the gossip window (right-clicks) on the NPC. | Filter (0=always, 1=GossipHello only, 2=reportUse only) | | | | | |
| 65 | SMART_EVENT_FOLLOW_COMPLETED | Fires when a follow action completes (the NPC stops following). No params. | | | | | | |
| 66 | SMART_EVENT_EVENT_PHASE_CHANGE | Fires when the event phase changes to a specific value. | event_phase_mask | | | | | |
| 67 | SMART_EVENT_IS_BEHIND_TARGET | Fires periodically while the NPC is behind its target. | InitialMin (ms) | InitialMax (ms) | RepeatMin (ms) | RepeatMax (ms) | RangeMin (yards) | RangeMax (yards) |
| 68 | SMART_EVENT_GAME_EVENT_START | Fires when a world game event starts. | game_event.eventEntry | | | | | |
| 69 | SMART_EVENT_GAME_EVENT_END | Fires when a world game event ends. | game_event.eventEntry | | | | | |
| 70 | SMART_EVENT_GO_STATE_CHANGED | Fires when a GameObject's state changes. (Used with `source_type=1`.) | State (0=Active, 1=Ready, 2=Alternative Active) | | | | | |
| 71 | SMART_EVENT_GO_EVENT_INFORM | Fires when a GameObject sends an event inform signal. | EventID | | | | | |
| 72 | SMART_EVENT_ACTION_DONE | Fires when an action with a specific ID is completed. | EventID | CooldownMin (ms) | CooldownMax (ms) | | | |
| 73 | SMART_EVENT_ON_SPELLCLICK | Fires when a player clicks a spell-click NPC. No params. | | | | | | |
| 74 | SMART_EVENT_FRIENDLY_HEALTH_PCT | Fires periodically while a friendly unit in range has HP% in a specified range. | InitialMin (ms) | InitialMax (ms) | RepeatMin (ms) | RepeatMax (ms) | HP% threshold | Range (yards) |
| 75 | SMART_EVENT_DISTANCE_CREATURE | Fires when a specific creature is within a distance. | Creature DB GUID (0=use entry) | creature_template.entry (0=use guid) | Distance (yards) | RepeatInterval (ms) |
| 76 | SMART_EVENT_DISTANCE_GAMEOBJECT | Fires when a specific GameObject is within a distance. | GO DB GUID (0=use entry) | gameobject_template.entry (0=use guid) | Distance (yards) | RepeatInterval (ms) |
| 77 | SMART_EVENT_COUNTER_SET | Fires when a script counter reaches a specific value. | CounterID | Value | CooldownMin (ms) | CooldownMax (ms) | | |
| 78 | SMART_EVENT_SCENE_START | Fires when a scene starts. | | | | | | |
| 79 | SMART_EVENT_SCENE_TRIGGER | Fires on a scene trigger event. | | | | | | |
| 80 | SMART_EVENT_SCENE_CANCEL | Fires when a scene is cancelled. | | | | | | |
| 81 | SMART_EVENT_SCENE_COMPLETE | Fires when a scene completes. | | | | | | |
| 82 | SMART_EVENT_SUMMONED_UNIT_DIES | Fires when a creature summoned by this NPC dies. The dead summon is the invoker. | CreatureEntry (0=any) | CooldownMin (ms) | CooldownMax (ms) | | | |
| 101 | SMART_EVENT_NEAR_PLAYERS | Fires when at least N players are within range. AzerothCore extension. | MinPlayers | Range (yards) | FirstCheck (ms) | RepeatMin (ms) | RepeatMax (ms) | |
| 102 | SMART_EVENT_NEAR_PLAYERS_NEGATION | Fires when fewer than N players are within range. AzerothCore extension. | MaxPlayers | Range (yards) | FirstCheck (ms) | RepeatMin (ms) | RepeatMax (ms) | |
| 103 | SMART_EVENT_NEAR_UNIT | Fires when at least N units of a type are within range. AzerothCore extension. | Unit type (0=creature, 1=GameObject) | Entry (template) | Count | Range (yards) | Timer (ms) | |
| 104 | SMART_EVENT_NEAR_UNIT_NEGATION | Fires when fewer than N units of a type are within range. AzerothCore extension. | Unit type (0=creature, 1=GameObject) | Entry (template) | Count | Range (yards) | Timer (ms) | |
| 105 | SMART_EVENT_AREA_CASTING | Fires periodically while a unit in range is casting (like IC_LOS but checks for casting). AzerothCore extension. | InitialMin (ms) | InitialMax (ms) | RepeatMin (ms) | RepeatMax (ms) | RangeMin (yards) | RangeMax (yards) |
| 106 | SMART_EVENT_AREA_RANGE | Fires periodically based on range check. AzerothCore extension. | InitialMin (ms) | InitialMax (ms) | RepeatMin (ms) | RepeatMax (ms) | RangeMin (yards) | RangeMax (yards) |
| 107 | SMART_EVENT_SUMMONED_UNIT_EVADE | Fires when a summoned creature from this NPC evades. AzerothCore extension. | CreatureEntry (0=any) | CooldownMin (ms) | CooldownMax (ms) | | | |
| 108 | SMART_EVENT_WAYPOINT_REACHED | Fires when the NPC reaches a specific waypoint. AzerothCore extension (preferred over ESCORT_REACHED). | PointID (0=any) | PathID (0=any) | | | | |
| 109 | SMART_EVENT_WAYPOINT_ENDED | Fires when the NPC completes an entire waypoint path. AzerothCore extension. | PointID (0=any) | PathID (0=any) | | | | |
| 110 | SMART_EVENT_IS_IN_MELEE_RANGE | Fires periodically based on whether the target is within melee range. AzerothCore extension. | InitialMin (ms) | InitialMax (ms) | RepeatMin (ms) | RepeatMax (ms) | Distance (yards, 0=default melee) | Invert (0=in range, 1=out of range) |

### Invoker-Aware Events

The following events set a valid invoker (accessible via `SMART_TARGET_ACTION_INVOKER` and `SMART_ACTION_INVOKER_CAST`). Events not in this list will have a null invoker.

`AGGRO`, `DEATH`, `KILL`, `SUMMONED_UNIT`, `SPELLHIT`, `SPELLHIT_TARGET`, `DAMAGED`, `RECEIVE_HEAL`, `RECEIVE_EMOTE`, `JUST_SUMMONED`, `DAMAGED_TARGET`, `SUMMON_DESPAWNED`, `PASSENGER_BOARDED`, `PASSENGER_REMOVED`, `GOSSIP_HELLO`, `GOSSIP_SELECT`, `ACCEPTED_QUEST`, `REWARD_QUEST`, `FOLLOW_COMPLETED`, `ON_SPELLCLICK`, `AREATRIGGER_ONTRIGGER`, `IC_LOS`, `OOC_LOS`, `DISTANCE_CREATURE`, `FRIENDLY_HEALTH`, `FRIENDLY_HEALTH_PCT`, `FRIENDLY_IS_CC`, `FRIENDLY_MISSING_BUFF`, `ACTION_DONE`, `TARGET_HEALTH_PCT`, `TARGET_MANA_PCT`, `RANGE`, `VICTIM_CASTING`, `TARGET_BUFFED`, `IS_BEHIND_TARGET`, `AREA_CASTING`, `AREA_RANGE`, `SUMMONED_UNIT_EVADE`, `IS_IN_MELEE_RANGE`

---

## SMART_ACTION Types

All action types from the AzerothCore source. IDs 0–199 are shared with TrinityCore lineage; IDs 200–242 are AzerothCore extensions.

### Cast Flags (used in SMART_ACTION_CAST and similar)

| Flag | Value | Description |
|---|---|---|
| SMARTCAST_INTERRUPT_PREVIOUS | 1 | Interrupt current cast before casting |
| SMARTCAST_TRIGGERED | 2 | Cast as triggered (bypasses GCD/costs) — use triggeredFlags=0 for TRIGGERED_FULL_MASK |
| SMARTCAST_AURA_NOT_PRESENT | 32 | Only cast if target does not already have the aura |
| SMARTCAST_COMBAT_MOVE | 64 | Allow combat movement to be set after cast |
| SMARTCAST_MAIN_SPELL | 1024 | Mark as main/primary spell |

### Triggered Flags (param3 of SMART_ACTION_CAST)

| Flag | Value | Description |
|---|---|---|
| TRIGGERED_IGNORE_GCD | 1 | Bypass global cooldown |
| TRIGGERED_IGNORE_SPELL_AND_CATEGORY_CD | 2 | Bypass spell cooldown |
| TRIGGERED_IGNORE_POWER_AND_REAGENT_COST | 4 | No mana/resource cost |
| TRIGGERED_IGNORE_CAST_ITEM | 8 | No item requirement check |
| TRIGGERED_IGNORE_AURA_SCALING | 16 | Ignore aura scaling |
| TRIGGERED_IGNORE_CAST_IN_PROGRESS | 32 | Cast even if already casting |
| TRIGGERED_IGNORE_EFFECTS | 64 | Skip spell effect processing |
| TRIGGERED_FULL_MASK | 524287 | All trigger flags — use triggeredFlags=0 to auto-apply this |

If `triggeredFlags = 0`, the engine applies `TRIGGERED_FULL_MASK` automatically (fully triggered cast). Set `triggeredFlags` to a specific value only if you need partially-triggered behavior.

### React States (used in SMART_ACTION_SET_REACT_STATE)

| Value | Name | Description |
|---|---|---|
| 0 | REACT_PASSIVE | NPC does not attack anything |
| 1 | REACT_DEFENSIVE | NPC counter-attacks when attacked but does not pursue |
| 2 | REACT_AGGRESSIVE | NPC proactively attacks enemies on its threat list |

### Summon Types (used in SMART_ACTION_SUMMON_CREATURE param2)

| Value | Name | Description |
|---|---|---|
| 1 | TEMPSUMMON_TIMED_OR_DEAD_DESPAWN | Despawn after duration OR when dead |
| 2 | TEMPSUMMON_TIMED_OR_CORPSE_DESPAWN | Despawn after duration OR after corpse timer |
| 3 | TEMPSUMMON_TIMED_DESPAWN | Despawn after duration regardless |
| 4 | TEMPSUMMON_TIMED_DESPAWN_OUT_OF_COMBAT | Despawn when out of combat after timer |
| 5 | TEMPSUMMON_CORPSE_DESPAWN | Despawn immediately on death |
| 6 | TEMPSUMMON_CORPSE_TIMED_DESPAWN | Despawn after corpse timer |
| 7 | TEMPSUMMON_DEAD_DESPAWN | Despawn when dead |
| 8 | TEMPSUMMON_MANUAL_DESPAWN | Despawn only when UnSummon() is called |

### Movement Types (used in SMART_EVENT_MOVEMENTINFORM param1)

| Value | Name |
|---|---|
| 0 | IDLE_MOTION_TYPE |
| 1 | RANDOM_MOTION_TYPE |
| 2 | WAYPOINT_MOTION_TYPE |
| 4 | CONFUSED_MOTION_TYPE |
| 6 | CHASE_MOTION_TYPE |
| 7 | HOME_MOTION_TYPE |
| 8 | POINT_MOTION_TYPE |
| 11 | FLEEING_MOTION_TYPE |
| 17 | ESCORT_MOTION_TYPE |

### Action Table

| ID | Name | Description | Param1 | Param2 | Param3 | Param4 | Param5 | Param6 |
|---|---|---|---|---|---|---|---|---|
| 0 | SMART_ACTION_NONE | No-op placeholder. | | | | | | |
| 1 | SMART_ACTION_TALK | Say a line from `creature_text` on the NPC (or target if useTalkTarget=1). | creature_text.GroupID | Duration before TEXT_OVER event fires (ms) | useTalkTarget: 0=say from self, 1=say from target | Delay before speaking (ms) | | |
| 2 | SMART_ACTION_SET_FACTION | Change the NPC's faction. | FactionID (0=restore template default) | | | | | |
| 3 | SMART_ACTION_MORPH_TO_ENTRY_OR_MODEL | Morph NPC to a creature entry or model. | creature_template.entry (0=use model) | creature_template.modelid index (0=use entry) | | | | |
| 4 | SMART_ACTION_SOUND | Play a sound. | SoundID | onlySelf (0=all, 1=self only) | Distance | | | |
| 5 | SMART_ACTION_PLAY_EMOTE | Play a one-shot emote. | EmoteID | | | | | |
| 6 | SMART_ACTION_FAIL_QUEST | Fail a player's quest. Target must be the player. | QuestID | | | | | |
| 7 | SMART_ACTION_OFFER_QUEST | Offer a quest to the player. Target must be the player. | quest_template.id | directAdd (0=normal offer, 1=add directly to log) | | | | |
| 8 | SMART_ACTION_SET_REACT_STATE | Set the NPC's react (aggro) state. | ReactState (0=passive, 1=defensive, 2=aggressive) | | | | | |
| 9 | SMART_ACTION_ACTIVATE_GOBJECT | Activate/use a GameObject. Target must be the GO. | | | | | | |
| 10 | SMART_ACTION_RANDOM_EMOTE | Play a random emote from up to 6 choices. Entries of 0 are ignored. | EmoteID1 | EmoteID2 | EmoteID3 | EmoteID4 | EmoteID5 | EmoteID6 |
| 11 | SMART_ACTION_CAST | Cast a spell on the selected target. | SpellID | castFlags | triggeredFlags | limitTargets (0=all matching, N=first N) | | |
| 12 | SMART_ACTION_SUMMON_CREATURE | Summon a creature. | creature_template.entry | Summon type (see Summon Types) | Duration (ms, 0=permanent) | attackInvoker (0=no, 1=attack invoker, 2=attack scriptowner) | attackScriptOwner (0/1) | |
| 13 | SMART_ACTION_THREAT_SINGLE_PCT | Modify a single target's threat percentage. | Threat% increase | Threat% decrease | | | | |
| 14 | SMART_ACTION_THREAT_ALL_PCT | Modify all targets' threat percentage. | Threat% increase | Threat% decrease | | | | |
| 15 | SMART_ACTION_CALL_AREAEXPLOREDOREVENTHAPPENS | Credits a quest area explore/event completion for the target player. | quest_template.id | | | | | |
| 16 | SMART_ACTION_RESERVED_16 | Reserved. Do not use. | | | | | | |
| 17 | SMART_ACTION_SET_EMOTE_STATE | Set a persistent emote state (looping emote). | EmoteID (0=clear) | | | | | |
| 18 | SMART_ACTION_SET_UNIT_FLAG | Set one or more unit flags. | Flags (bitmask) | Type (0=UNIT_FIELD_FLAGS, 1=UNIT_FIELD_FLAGS_2) | | | | |
| 19 | SMART_ACTION_REMOVE_UNIT_FLAG | Remove one or more unit flags. | Flags (bitmask) | Type (0=UNIT_FIELD_FLAGS, 1=UNIT_FIELD_FLAGS_2) | | | | |
| 20 | SMART_ACTION_AUTO_ATTACK | Enable or disable the NPC's auto-attack. | 0=disable, 1=enable | | | | | |
| 21 | SMART_ACTION_ALLOW_COMBAT_MOVEMENT | Enable or disable the NPC moving toward its target in combat. | 0=disable, 1=enable | | | | | |
| 22 | SMART_ACTION_SET_EVENT_PHASE | Set the current event phase. | Phase (0–12) | | | | | |
| 23 | SMART_ACTION_INC_EVENT_PHASE | Increment or decrement the current event phase. | Increment amount | Decrement amount | | | | |
| 24 | SMART_ACTION_EVADE | Force the NPC to evade (leave combat). No params. | | | | | | |
| 25 | SMART_ACTION_FLEE_FOR_ASSIST | Make the NPC flee for help. | sayText (0/1) | | | | | |
| 26 | SMART_ACTION_CALL_GROUPEVENTHAPPENS | Trigger group/shared quest event credit. | quest_template.id | | | | | |
| 27 | SMART_ACTION_COMBAT_STOP | Stop the NPC's combat without evading. No params. | | | | | | |
| 28 | SMART_ACTION_REMOVEAURASFROMSPELL | Remove aura(s) from spell. Target is the unit losing the aura. | SpellID (0=remove all auras) | Charges (0=remove all stacks) | | | | |
| 29 | SMART_ACTION_FOLLOW | Make this NPC follow a target. | Distance (0=use default) | Angle (0=use default) | EndCreature entry (stop following if this entry dies) | credit | creditType (0=creature kill, 1=event) | |
| 30 | SMART_ACTION_RANDOM_PHASE | Set the phase to a random value from up to 6 specified phases. | Phase1 | Phase2 | Phase3 | Phase4 | Phase5 | Phase6 |
| 31 | SMART_ACTION_RANDOM_PHASE_RANGE | Set the phase to a random value between min and max. | PhaseMin | PhaseMax | | | | |
| 32 | SMART_ACTION_RESET_GOBJECT | Reset a GameObject to its default state. Target must be the GO. | | | | | | |
| 33 | SMART_ACTION_CALL_KILLEDMONSTER | Credit players with killing a specific creature for quest purposes. | creature_template.entry | | | | | |
| 34 | SMART_ACTION_SET_INST_DATA | Set instance data (for dungeons/raids). | Field | Data | Type (0=SetData, 1=SetBossState) | | | |
| 35 | SMART_ACTION_SET_INST_DATA64 | Set instance data as a 64-bit value (typically a GUID). | Field | | | | | |
| 36 | SMART_ACTION_UPDATE_TEMPLATE | Change the NPC's creature template (recalculate stats). | creature_template.entry | UpdateLevel (0=no, 1=yes) | | | | |
| 37 | SMART_ACTION_DIE | Kill the NPC after a delay. | Delay (ms) | | | | | |
| 38 | SMART_ACTION_SET_IN_COMBAT_WITH_ZONE | Put the NPC in combat with all players in a range. | Range (yards) | | | | | |
| 39 | SMART_ACTION_CALL_FOR_HELP | Call nearby friendly NPCs for assistance. | Radius (yards) | withEmote (0/1) | | | | |
| 40 | SMART_ACTION_SET_SHEATH | Change the NPC's weapon sheath state. | 0=unarmed, 1=melee sheathed, 2=ranged sheathed | | | | | |
| 41 | SMART_ACTION_FORCE_DESPAWN | Despawn the NPC. | Delay (ms) | ForceRespawnTimer (s, 0=default) | removeObjectFromWorld (0/1) | | | |
| 42 | SMART_ACTION_SET_INVINCIBILITY_HP_LEVEL | Set an HP floor below which the NPC cannot be reduced. | Flat HP value (0=disable; use one or the other) | Percent HP value | | | | |
| 43 | SMART_ACTION_MOUNT_TO_ENTRY_OR_MODEL | Mount the NPC on a creature or display model. | creature_template.entry (0=use model) | Creature model index | | | | |
| 44 | SMART_ACTION_SET_INGAME_PHASE_MASK | Set the NPC's in-game phase mask (client phasing). | creature.phaseMask | | | | | |
| 45 | SMART_ACTION_SET_DATA | Call `SetData(field, data)` on target. Used with SMART_EVENT_DATA_SET. | Field | Data | | | | |
| 46 | SMART_ACTION_MOVE_FORWARD | Move the NPC directly forward a specified distance. | Distance (yards) | | | | | |
| 47 | SMART_ACTION_SET_VISIBILITY | Show or hide the NPC. | 0=invisible, 1=visible | | | | | |
| 48 | SMART_ACTION_SET_ACTIVE | Set the NPC's active state (force-loaded grid). | 0=inactive, 1=active | | | | | |
| 49 | SMART_ACTION_ATTACK_START | Force the NPC to begin attacking a target. | | | | | | |
| 50 | SMART_ACTION_SUMMON_GO | Summon a GameObject at the target location. | gameobject_template.entry | Despawn time (s, 0=permanent) | targetSummon (0=at NPC, 1=at target) | summonType (0/1) | | |
| 51 | SMART_ACTION_KILL_UNIT | Instantly kill the target unit. No params. | | | | | | |
| 52 | SMART_ACTION_ACTIVATE_TAXI | Start a taxi path for a player target. | TaxiPathID | | | | | |
| 53 | SMART_ACTION_ESCORT_START | Start an escort movement. (Prefer WAYPOINT_START for new scripts.) | forcedMovement (0=walk, 1=run, 2=flight) | waypoints.entry (pathID) | canRepeat (0/1) | quest_template.id (0=none) | despawnTime (ms) | ReactState |
| 54 | SMART_ACTION_ESCORT_PAUSE | Pause an escort at the current waypoint. | Time (ms) | | | | | |
| 55 | SMART_ACTION_ESCORT_STOP | Stop an escort. | despawnTime (ms) | quest_template.id | fail (0=don't fail, 1=fail quest) | | | |
| 56 | SMART_ACTION_ADD_ITEM | Give a player an item. Target must be the player. | item_template.entry | Count | | | | |
| 57 | SMART_ACTION_REMOVE_ITEM | Remove an item from a player. Target must be the player. | item_template.entry | Count | | | | |
| 58 | SMART_ACTION_INSTALL_AI_TEMPLATE | Install a preset AI behavior template. | TemplateID | Template params 1–5 | | | | |
| 59 | SMART_ACTION_SET_RUN | Enable or disable running movement. | 0=walk, 1=run | | | | | |
| 60 | SMART_ACTION_SET_FLY | Enable or disable flying movement. | fly (0/1) | Speed (0=default) | disableGravity (0/1) | | | |
| 61 | SMART_ACTION_SET_SWIM | Enable or disable swim movement. | 0=disable, 1=enable | | | | | |
| 62 | SMART_ACTION_TELEPORT | Teleport target(s) to a map (players only). | MapID | | | | | |
| 63 | SMART_ACTION_SET_COUNTER | Set a named counter to a value. | CounterID | Value | reset (0=set, 1=reset to 0 after setting) | | | |
| 64 | SMART_ACTION_STORE_TARGET_LIST | Store the current target list under an ID for later retrieval via SMART_TARGET_STORED. | varID | | | | | |
| 65 | SMART_ACTION_ESCORT_RESUME | Resume a paused escort. No params. | | | | | | |
| 66 | SMART_ACTION_SET_ORIENTATION | Set the NPC's facing direction. | quickChange (0/1) | random (0=use angle, 1=random) | Turning angle (degrees) | | | |
| 67 | SMART_ACTION_CREATE_TIMED_EVENT | Create a custom timed event that fires SMART_EVENT_TIMED_EVENT_TRIGGERED. | EventID | InitialMin (ms) | InitialMax (ms) | RepeatMin (ms) | RepeatMax (ms) | Chance% |
| 68 | SMART_ACTION_PLAYMOVIE | Play a cinematic movie for a player. Target must be the player. | MovieID | | | | | |
| 69 | SMART_ACTION_MOVE_TO_POS | Move the NPC to a specific point (uses target_x/y/z or a target NPC's position). | PointID | isTransport (0/1) | controlled (0/1) | ContactDistance | CombatReach (0/1) | disableForceDestination (0/1) |
| 70 | SMART_ACTION_RESPAWN_TARGET | Respawn a target creature or GO that is dead/despawned. | RespawnTime (s) | | | | | |
| 71 | SMART_ACTION_EQUIP | Equip items on the NPC. | creature_equip_template.ID (0=use slots) | SlotMask (which slots to change) | Slot1 item_template.entry | Slot2 item_template.entry | Slot3 item_template.entry | |
| 72 | SMART_ACTION_CLOSE_GOSSIP | Close the gossip menu for the target player. | | | | | | |
| 73 | SMART_ACTION_TRIGGER_TIMED_EVENT | Trigger a timed event by ID immediately. | EventID (must be > 1) | | | | | |
| 74 | SMART_ACTION_REMOVE_TIMED_EVENT | Remove a timed event by ID. | EventID (must be > 1) | | | | | |
| 75 | SMART_ACTION_ADD_AURA | Apply a spell aura directly (without casting). | SpellID | | | | | |
| 76 | SMART_ACTION_OVERRIDE_SCRIPT_BASE_OBJECT | **WARNING: Can crash core.** Override the AI script base object. | | | | | | |
| 77 | SMART_ACTION_RESET_SCRIPT_BASE_OBJECT | Reset the AI script base object. No params. | | | | | | |
| 78 | SMART_ACTION_CALL_SCRIPT_RESET | Reset the SmartAI script (re-run all init events). No params. | | | | | | |
| 79 | SMART_ACTION_SET_RANGED_MOVEMENT | Set ranged movement distance and angle for ranged attackers. | attackDistance (yards) | attackAngle | | | | |
| 80 | SMART_ACTION_CALL_TIMED_ACTIONLIST | Call a `source_type=9` (TimedActionList) script entry. See Timed Action List notes below. | EntryOrGuid×100 | timerUpdateType (0=OOC+IC, 1=OOC only, 2=IC only) | allowOverride (0/1) | | | |
| 81 | SMART_ACTION_SET_NPC_FLAG | Set the NPC's flags (replaces existing flags). | npcflag bitmask | | | | | |
| 82 | SMART_ACTION_ADD_NPC_FLAG | Add NPC flags (bitwise OR). | npcflag bitmask | | | | | |
| 83 | SMART_ACTION_REMOVE_NPC_FLAG | Remove NPC flags (bitwise AND NOT). | npcflag bitmask | | | | | |
| 84 | SMART_ACTION_SIMPLE_TALK | Say text from creature_text without invoker/target logic. Simpler than TALK. | creature_text.GroupID | | | | | |
| 85 | SMART_ACTION_SELF_CAST | Cast a spell with the NPC as both caster and target, regardless of the target_type. | SpellID | castFlags | triggeredFlags | limitTargets | | |
| 86 | SMART_ACTION_CROSS_CAST | Cast a spell where the caster and target are specified separately. | SpellID | castFlags | CasterTargetType | CasterTarget param1 | CasterTarget param2 | CasterTarget param3 |
| 87 | SMART_ACTION_CALL_RANDOM_TIMED_ACTIONLIST | Call a random timed action list from up to 6 entries. | EntryOrGuid1×100 | EntryOrGuid2×100 | EntryOrGuid3×100 | EntryOrGuid4×100 | EntryOrGuid5×100 | EntryOrGuid6×100 |
| 88 | SMART_ACTION_CALL_RANDOM_RANGE_TIMED_ACTIONLIST | Call a random timed action list from a range. | EntryOrGuidMin×100 | EntryOrGuidMax×100 | | | | |
| 89 | SMART_ACTION_RANDOM_MOVE | Set random movement within a radius. | Radius (yards) | | | | | |
| 90 | SMART_ACTION_SET_UNIT_FIELD_BYTES_1 | Set unit field bytes 1 (e.g., stand state, shapeshift). | Value | Type | | | | |
| 91 | SMART_ACTION_REMOVE_UNIT_FIELD_BYTES_1 | Remove unit field bytes 1. | Value | Type | | | | |
| 92 | SMART_ACTION_INTERRUPT_SPELL | Interrupt the target's current spell. | withDelay (0/1) | SpellID (0=any) | instant (0/1) | | | |
| 93 | SMART_ACTION_SEND_GO_CUSTOM_ANIM | Send a custom animation to a GameObject. | AnimProgress (0–255) | | | | | |
| 94 | SMART_ACTION_SET_DYNAMIC_FLAG | Set dynamic flags (replaces). | dynamicflags bitmask | | | | | |
| 95 | SMART_ACTION_ADD_DYNAMIC_FLAG | Add dynamic flags (OR). | dynamicflags bitmask | | | | | |
| 96 | SMART_ACTION_REMOVE_DYNAMIC_FLAG | Remove dynamic flags (AND NOT). | dynamicflags bitmask | | | | | |
| 97 | SMART_ACTION_JUMP_TO_POS | Make the NPC jump to the target position. Uses target_x/y/z. | SpeedXY | SpeedZ | selfJump (0/1) | | | |
| 98 | SMART_ACTION_SEND_GOSSIP_MENU | Open a gossip menu for a player. Target must be the player. | gossip_menu.entry | gossip_menu_option.text_id (npc_text.id) | | | | |
| 99 | SMART_ACTION_GO_SET_LOOT_STATE | Set a GameObject's loot state. | LootState (0=Not Ready, 1=Ready, 2=Activated, 3=Just Deactivated) | | | | | |
| 100 | SMART_ACTION_SEND_TARGET_TO_TARGET | Store a target list in a variable used by SMART_TARGET_STORED. | varID | | | | | |
| 101 | SMART_ACTION_SET_HOME_POS | Set the NPC's home (evade-to) position to current position or spawn position. | 0=use spawn position, 1=use current position | | | | | |
| 102 | SMART_ACTION_SET_HEALTH_REGEN | Enable or disable health regeneration. | 0=disable, 1=enable | | | | | |
| 103 | SMART_ACTION_SET_ROOT | Root or un-root the NPC. | 0=unroot, 1=root | | | | | |
| 104 | SMART_ACTION_SET_GO_FLAG | Set a GameObject's flags (replaces). | gameobject_template_addon.flags | | | | | |
| 105 | SMART_ACTION_ADD_GO_FLAG | Add GameObject flags (OR). | gameobject_template_addon.flags | | | | | |
| 106 | SMART_ACTION_REMOVE_GO_FLAG | Remove GameObject flags (AND NOT). | gameobject_template_addon.flags | | | | | |
| 107 | SMART_ACTION_SUMMON_CREATURE_GROUP | Summon a creature summon group defined in `creature_summon_groups`. | groupId | attackInvoker (0/1) | attackScriptOwner (0/1) | | | |
| 108 | SMART_ACTION_SET_POWER | Set a power type to an absolute value. | PowerType (0=mana, 1=rage, 3=energy, etc.) | NewPowerValue | | | | |
| 109 | SMART_ACTION_ADD_POWER | Add to a power type. | PowerType | AmountToAdd | | | | |
| 110 | SMART_ACTION_REMOVE_POWER | Remove from a power type. | PowerType | AmountToRemove | | | | |
| 111 | SMART_ACTION_GAME_EVENT_STOP | Stop a world game event. | game_event.eventEntry | | | | | |
| 112 | SMART_ACTION_GAME_EVENT_START | Start a world game event. | game_event.eventEntry | | | | | |
| 113 | SMART_ACTION_START_CLOSEST_WAYPOINT | Start waypoint movement on whichever of two paths has the nearest node. | PathID1 | PathID2 | repeat (0/1) | forcedMovement (0=walk, 1=run, 2=flight) | | |
| 114 | SMART_ACTION_RISE_UP | Move the NPC upward a distance (flying/hovering). | Distance (yards) | | | | | |
| 115 | SMART_ACTION_RANDOM_SOUND | Play a random sound from up to 4 options. | SoundID1 | SoundID2 | SoundID3 | SoundID4 | onlySelf (0/1) | Distance |
| 116 | SMART_ACTION_SET_CORPSE_DELAY | Set how long the corpse persists before despawning. | Timer (seconds) | | | | | |
| 117 | SMART_ACTION_DISABLE_EVADE | Prevent (or re-enable) the NPC from evading. | 0=re-enable evade, 1=disable evade | | | | | |
| 118 | SMART_ACTION_GO_SET_GO_STATE | Set a GameObject's GO state. | State | | | | | |
| 119 | SMART_ACTION_SET_CAN_FLY | Set the NPC's can-fly flag. | 0=disable, 1=enable | | | | | |
| 120 | SMART_ACTION_REMOVE_AURAS_BY_TYPE | Remove all auras of a specific aura type. | AuraType | | | | | |
| 121 | SMART_ACTION_SET_SIGHT_DIST | Set the NPC's sight/detection range. | SightDistance (yards) | | | | | |
| 122 | SMART_ACTION_FLEE | Make the NPC flee from combat for a duration. | FleeTime (ms) | | | | | |
| 123 | SMART_ACTION_ADD_THREAT | Directly add or subtract flat threat from a target. | ThreatToAdd | ThreatToSubtract | | | | |
| 124 | SMART_ACTION_LOAD_EQUIPMENT | Load equipment from a `creature_equip_template` entry. | EquipID | force (0/1) | | | | |
| 125 | SMART_ACTION_TRIGGER_RANDOM_TIMED_EVENT | Trigger a random timed event within an ID range. | EventIDMin | EventIDMax | | | | |
| 126 | SMART_ACTION_REMOVE_ALL_GAMEOBJECTS | Remove all GameObjects summoned by this NPC. No params. | | | | | | |
| 127 | SMART_ACTION_REMOVE_MOVEMENT | Stop and clear current movement generator. No params. | | | | | | |
| 128 | SMART_ACTION_PLAY_ANIMKIT | Play an animation kit. | AnimKitID | | | | | |
| 129 | SMART_ACTION_SCENE_PLAY | Play a scene. | SceneID | | | | | |
| 130 | SMART_ACTION_SCENE_CANCEL | Cancel a scene. | SceneID | | | | | |
| 131 | SMART_ACTION_SPAWN_SPAWNGROUP | Spawn a spawngroup. | SpawnGroupID | | | | | |
| 132 | SMART_ACTION_DESPAWN_SPAWNGROUP | Despawn a spawngroup. | SpawnGroupID | | | | | |
| 133 | SMART_ACTION_RESPAWN_BY_SPAWNID | Respawn a specific spawn by its spawnID. | SpawnType (0=creature, 1=GO) | SpawnID | | | | |
| 134 | SMART_ACTION_INVOKER_CAST | Cast a spell where the invoker is the caster (useful for triggering player spells). | SpellID | CastFlags | TriggerFlags | LimitTargets | | |
| 135 | SMART_ACTION_PLAY_CINEMATIC | Play a cinematic for the target player. | CinematicID | | | | | |
| 136 | SMART_ACTION_SET_MOVEMENT_SPEED | Set a specific movement speed type. | MovementType (0=walk, 1=run, 2=runback, 3=swim, 4=swimback, 5=turn, 6=flight, 7=flightback, 8=pitch) | SpeedInteger | SpeedFraction (combined: Speed = integer + fraction/10000) | | | |
| 142 | SMART_ACTION_SET_HEALTH_PCT | Set the NPC's health to a specific percentage. | Percent (1–100) | | | | | |
| 201 | SMART_ACTION_MOVE_TO_POS_TARGET | Move to a target's position (AC extension). | PointID | disableForceDestination (0/1) | | | | |
| 203 | SMART_ACTION_EXIT_VEHICLE | Eject target from vehicle. No params. | | | | | | |
| 204 | SMART_ACTION_SET_UNIT_MOVEMENT_FLAGS | Set unit movement flags. | flags | | | | | |
| 205 | SMART_ACTION_SET_COMBAT_DISTANCE | Set the combat engagement distance. | combatDistance (yards) | | | | | |
| 206 | SMART_ACTION_DISMOUNT | Dismount the target. No params. | | | | | | |
| 207 | SMART_ACTION_SET_HOVER | Enable or disable hover movement. | 0=disable, 1=enable | | | | | |
| 208 | SMART_ACTION_ADD_IMMUNITY | Add a spell immunity. | Type | ID | Value | | | |
| 209 | SMART_ACTION_REMOVE_IMMUNITY | Remove a spell immunity. | Type | ID | Value | | | |
| 210 | SMART_ACTION_FALL | Make the NPC fall (disable flight/hover). No params. | | | | | | |
| 211 | SMART_ACTION_SET_EVENT_FLAG_RESET | Control whether phase resets when the NPC resets. | allowPhaseReset (0/1) | | | | | |
| 212 | SMART_ACTION_STOP_MOTION | Stop movement and optionally expire the movement generator. | stopMoving (0/1) | movementExpired (0/1) | | | | |
| 213 | SMART_ACTION_NO_ENVIRONMENT_UPDATE | Suppress environment update. No params. | | | | | | |
| 214 | SMART_ACTION_ZONE_UNDER_ATTACK | Mark zone as under attack. No params. | | | | | | |
| 215 | SMART_ACTION_LOAD_GRID | Force-load the grid at target coordinates. No params. | | | | | | |
| 216 | SMART_ACTION_MUSIC | Play music (zone-wide). | SoundID | onlySelf (0/1) | Type (0=start, 1=stop, 2=resume) | | | |
| 217 | SMART_ACTION_RANDOM_MUSIC | Play random music from up to 4 options. | SoundID1 | SoundID2 | SoundID3 | SoundID4 | onlySelf (0/1) | Type (0/1/2) |
| 218 | SMART_ACTION_CUSTOM_CAST | Cast a spell with custom basepoint overrides. | SpellID | CastFlags | bp0 | bp1 | bp2 | |
| 219 | SMART_ACTION_CONE_SUMMON | Summon creatures in a cone pattern. | CreatureEntry | Duration (ms) | DistBetweenRings | DistBetweenSummons | ConeLength | ConeWidth (degrees, 1–360) |
| 220 | SMART_ACTION_PLAYER_TALK | Send a text from `acore_string` table to a player. | acore_string.id | yell (0=chat, 1=yell) | | | | |
| 221 | SMART_ACTION_VORTEX_SUMMON | Summon creatures in a vortex/spiral pattern. | CreatureEntry | Duration (ms) | SpiralScaling (a) | SpiralAppearance (k) | MaxRange (r_max) | PhiDelta |
| 222 | SMART_ACTION_CU_ENCOUNTER_START | Signal encounter start (for custom instance tracking). No params. | | | | | | |
| 223 | SMART_ACTION_DO_ACTION | Execute a defined action by ID on the target. | ActionID | | | | | |
| 224 | SMART_ACTION_ATTACK_STOP | Stop attacking without evading. No params. | | | | | | |
| 225 | SMART_ACTION_SET_GUID | Store a GUID into the script's data store. | 0=store self GUID, 1=store invoker GUID | Index | | | | |
| 226 | SMART_ACTION_SCRIPTED_SPAWN | Control the NPC's scripted spawn state. | State (0=off, 1=on, 2=reset) | MinSpawnTimer (s) | MaxSpawnTimer (s) | RespawnDelay (s) | CorpseDelay (s) | DontDespawn (0/1) |
| 227 | SMART_ACTION_SET_SCALE | Set the NPC's display scale. | Scale as percentage (100=normal, 200=double size) | | | | | |
| 228 | SMART_ACTION_SUMMON_RADIAL | Summon creatures in a radial ring pattern. | CreatureEntry | Duration (ms) | Repetitions | StartAngle | StepAngle | Distance |
| 229 | SMART_ACTION_PLAY_SPELL_VISUAL | Play a spell visual effect at target. | VisualID | | | | | |
| 230 | SMART_ACTION_FOLLOW_GROUP | Make all members of a follow group follow or stop. | FollowState (0=stop, 1=start) | SmartFollowType | Distance/100 (yards) | | | |
| 231 | SMART_ACTION_SET_ORIENTATION_TARGET | Set orientation toward a specific target type. | Type (0=self to target, 1=target to self, 2=target to target, 3=target to home) | TargetType | TargetParam1 | TargetParam2 | TargetParam3 | TargetParam4 |
| 232 | SMART_ACTION_WAYPOINT_START | Start waypoint movement along a path. (Preferred for new scripts.) | PathID | repeat (0/1) | pathSource (0=waypoint_data, 1=script_waypoint) | | | |
| 233 | SMART_ACTION_WAYPOINT_DATA_RANDOM | Start waypoint movement on a random path from two options. | PathID1 | PathID2 | repeat (0/1) | | | |
| 234 | SMART_ACTION_MOVEMENT_STOP | Stop current movement. No params. | | | | | | |
| 235 | SMART_ACTION_MOVEMENT_PAUSE | Pause current movement for a duration. | Timer (ms) | | | | | |
| 236 | SMART_ACTION_MOVEMENT_RESUME | Resume paused movement. | timerOverride (ms, 0=use original) | | | | | |
| 237 | SMART_ACTION_WORLD_SCRIPT | Fire a world script event. | EventID | Param | | | | |
| 238 | SMART_ACTION_DISABLE_REWARD | Disable specific reward types when the NPC is killed. | reputation (0/1) | loot (0/1) | | | | |
| 239 | SMART_ACTION_SET_ANIM_TIER | Set the NPC's animation tier (standing pose). | AnimTier (0–4) | | | | | |
| 240 | SMART_ACTION_SET_GOSSIP_MENU | Dynamically change the gossip menu ID. | gossipMenuId | | | | | |
| 241 | SMART_ACTION_SUMMON_GAMEOBJECT_GROUP | Summon a group of GameObjects defined in a summon group table. | groupId | | | | | |

### Timed Action List Notes (SMART_ACTION_CALL_TIMED_ACTIONLIST)

A Timed Action List is a `smart_scripts` entry with `source_type=9`. It allows scheduling a series of delayed actions independent of the main NPC event loop.

- The `entryorguid` value must be `creatureEntry × 100` for the first list, `creatureEntry × 100 + 1` for a second list, etc.
- `action_param1` in `CALL_TIMED_ACTIONLIST` passes this multiplied value.
- Rows inside the timed action list have `source_type=9` and their `event_type` is `SMART_EVENT_UPDATE_IC` (timer-based) — the timers run in sequence.
- `timerUpdateType` (param2): 0=update both in and out of combat, 1=only OOC, 2=only IC.
- Useful for multi-phase spellcasting sequences where you want predictable ordering.

---

## SMART_TARGET Types

All 36 target types (0–29 standard, 200–207 AzerothCore extensions).

| ID | Name | Description | Param1 | Param2 | Param3 | Param4 | Uses X/Y/Z/O |
|---|---|---|---|---|---|---|---|
| 0 | SMART_TARGET_NONE | No target. Use for self-contained actions. | | | | | No |
| 1 | SMART_TARGET_SELF | The NPC running the script. | | | | | No |
| 2 | SMART_TARGET_VICTIM | The NPC's current combat target (top of threat list). | | | | | No |
| 3 | SMART_TARGET_HOSTILE_SECOND_AGGRO | Second-highest threat list target. | MaxRange (0=unlimited) | PlayerOnly (0/1) | PowerType+1 (0=any, 1=mana, 2=rage…) | Missing AuraSpellID (0=any) | No |
| 4 | SMART_TARGET_HOSTILE_LAST_AGGRO | Lowest-threat target (last on threat list). | MaxRange (0=unlimited) | PlayerOnly (0/1) | PowerType+1 | Missing AuraSpellID | No |
| 5 | SMART_TARGET_HOSTILE_RANDOM | Random unit from the threat list. | MaxRange (0=unlimited) | PlayerOnly (0/1) | PowerType+1 | Missing AuraSpellID | No |
| 6 | SMART_TARGET_HOSTILE_RANDOM_NOT_TOP | Random threat list target excluding the current top threat. | MaxRange (0=unlimited) | PlayerOnly (0/1) | PowerType+1 | Missing AuraSpellID | No |
| 7 | SMART_TARGET_ACTION_INVOKER | The unit that caused the current event to fire (see Invoker-Aware Events). | | | | | No |
| 8 | SMART_TARGET_POSITION | A specific world position. No unit is targeted — used with positional actions. | | | | | Yes (required) |
| 9 | SMART_TARGET_CREATURE_RANGE | All creatures of a given entry within a distance range. | creature_template.entry (0=any) | MinDist (yards) | MaxDist (yards) | LivingState (0=any, 1=alive, 2=dead) | No |
| 10 | SMART_TARGET_CREATURE_GUID | A specific creature by database GUID. | creature.guid | creature_template.entry | getFromHashMap (0/1) | | No |
| 11 | SMART_TARGET_CREATURE_DISTANCE | All creatures of a given entry within a max distance. | creature_template.entry (0=any) | MaxDist (yards) | LivingState (0=any, 1=alive, 2=dead) | | No |
| 12 | SMART_TARGET_STORED | Targets previously saved by SMART_ACTION_STORE_TARGET_LIST. | varID | | | | No |
| 13 | SMART_TARGET_GAMEOBJECT_RANGE | All GameObjects of a given entry within a distance range. | gameobject_template.entry (0=any) | MinDist (yards) | MaxDist (yards) | | No |
| 14 | SMART_TARGET_GAMEOBJECT_GUID | A specific GameObject by database GUID. | gameobject.guid | gameobject_template.entry | getFromHashMap (0/1) | | No |
| 15 | SMART_TARGET_GAMEOBJECT_DISTANCE | All GameObjects of a given entry within a max distance. | gameobject_template.entry (0=any) | MaxDist (yards) | | | No |
| 16 | SMART_TARGET_INVOKER_PARTY | All party/raid members of the invoker. | | | | | No |
| 17 | SMART_TARGET_PLAYER_RANGE | Players within a distance range, optionally capped to N players. | MinDist (yards) | MaxDist (yards) | MaxCount (0=all) | | No |
| 18 | SMART_TARGET_PLAYER_DISTANCE | All players within a max distance. | MaxDist (yards) | | | | No |
| 19 | SMART_TARGET_CLOSEST_CREATURE | The single closest creature of a given entry. | creature_template.entry (0=any) | MaxDist (0–100 yards) | dead (0=alive, 1=dead) | | No |
| 20 | SMART_TARGET_CLOSEST_GAMEOBJECT | The single closest GameObject of a given entry. | gameobject_template.entry (0=any) | MaxDist (0–100 yards) | | | No |
| 21 | SMART_TARGET_CLOSEST_PLAYER | The single closest player. | MaxDist (yards) | | | | No |
| 22 | SMART_TARGET_ACTION_INVOKER_VEHICLE | The vehicle that the action invoker is riding. | | | | | No |
| 23 | SMART_TARGET_OWNER_OR_SUMMONER | The unit that owns or summoned this NPC. | useOwnerOfOwner (0=direct owner, 1=owner's owner) | | | | No |
| 24 | SMART_TARGET_THREAT_LIST | All units on the NPC's threat list. | MaxDist (0=any range) | | | | No |
| 25 | SMART_TARGET_CLOSEST_ENEMY | The closest enemy (hostile) unit. | MaxDist (yards) | PlayerOnly (0/1) | | | No |
| 26 | SMART_TARGET_CLOSEST_FRIENDLY | The closest friendly (allied) unit. | MaxDist (yards) | PlayerOnly (0/1) | | | No |
| 27 | SMART_TARGET_LOOT_RECIPIENTS | All players who have loot rights on this NPC. | | | | | No |
| 28 | SMART_TARGET_FARTHEST | The farthest unit meeting criteria from the threat list. | MaxDist (yards) | PlayerOnly (0/1) | IsInLOS (0/1) | MinDist (yards) | No |
| 29 | SMART_TARGET_VEHICLE_PASSENGER | A specific vehicle passenger by seat. | SeatNumber | | | | No |
| 201 | SMART_TARGET_PLAYER_WITH_AURA | Players within range who have (or lack) a specific aura. AC extension. | SpellID | Negative (0=has aura, 1=does not have aura) | MaxDist (yards) | MinDist (yards) | No |
| 202 | SMART_TARGET_RANDOM_POINT | A set of random points around the NPC or target. AC extension. | Range (yards) | Amount (number of points) | SelfAsMiddle (0/1) | | Yes (optional origin) |
| 203 | SMART_TARGET_ROLE_SELECTION | Players on the threat list selected by role. AC extension. | MaxRange (yards) | RoleMask (1=tanks, 2=healers, 4=DPS; combinable) | ResizeList (0/1) | | No |
| 204 | SMART_TARGET_SUMMONED_CREATURES | All creatures summoned by this NPC of a given entry. AC extension. | creature_template.entry (0=all summons) | | | | No |
| 205 | SMART_TARGET_INSTANCE_STORAGE | A unit stored in instance data storage. AC extension. | DataIndex | Type (1=creature, 2=GO) | | | No |
| 206 | SMART_TARGET_FORMATION | Members of a formation group. AC extension. | Type (0=all, 1=alive, 2=dead) | creature_template.entry (0=any member) | ExcludeSelf (0/1) | | No |

---

## Practical SmartAI Recipes

### Recipe 1: Patrol NPC with Player Greeting

An NPC that wanders along waypoints and greets the first player that approaches it out of combat.

```sql
-- Step 1: Enable SmartAI and set up greeting text
UPDATE creature_template SET AIName = 'SmartAI' WHERE entry = 10001;

INSERT INTO creature_text (CreatureID, GroupID, ID, Text, Type, Language, Probability, Emote, Duration, Sound, BroadcastTextId, TextRange, comment)
VALUES (10001, 0, 0, 'Greetings, traveler!', 12, 0, 100, 1, 0, 0, 0, 0, 'Patrol Guard - Greeting');

-- Step 2: Start waypoint path on spawn (path must exist in waypoint_data)
INSERT INTO smart_scripts (entryorguid, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags,
    event_param1, event_param2, event_param3, event_param4,
    action_type, action_param1, action_param2, action_param3, action_param4, action_param5, action_param6,
    target_type, target_param1, target_param2, target_param3, target_param4,
    target_x, target_y, target_z, target_o, comment)
VALUES
-- On spawn: start waypoint path 100, repeat
(10001, 0, 0, 0,  63, 0, 100, 0,  0,0,0,0,  232, 100, 1, 0, 0, 0, 0,  1, 0,0,0,0, 0,0,0,0, 'Patrol Guard - On Create - Start Waypoint Path'),
-- OOC LOS: player approaches within 10 yards → greet (not hostile, player only, cooldown 30–60 s)
(10001, 0, 1, 0,  10, 0, 100, 1,  1, 10, 30000, 60000, 0, 1,  1, 0, 0, 0, 0, 0,  7, 0,0,0,0, 0,0,0,0, 'Patrol Guard - OOC LOS Player - Talk Greeting');
-- Note: event_flags=1 (NOT_REPEATABLE) prevents spamming the same greeting
-- event_param1=1 means HostilityMode=1 (not hostile = player)
-- action_type=1 (TALK), action_param1=0 (GroupID 0 = "Greetings, traveler!")
-- target_type=7 (ACTION_INVOKER = the approaching player)
```

### Recipe 2: Combat Rotation with Health-Based Ability

An NPC that casts a random spell on a timer in combat and uses a powerful ability when dropping below 30% HP.

```sql
UPDATE creature_template SET AIName = 'SmartAI' WHERE entry = 10002;

INSERT INTO smart_scripts (entryorguid, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags,
    event_param1, event_param2, event_param3, event_param4,
    action_type, action_param1, action_param2, action_param3, action_param4, action_param5, action_param6,
    target_type, target_param1, target_param2, target_param3, target_param4,
    target_x, target_y, target_z, target_o, comment)
VALUES
-- In combat update: cast a spell every 8-15 seconds
(10002, 0, 0, 0,  0, 0, 100, 0,  3000, 5000, 8000, 15000, 0, 0,  11, 12579, 0, 0, 0, 0, 0,  2, 0,0,0,0, 0,0,0,0, 'Mob - IC Timer - Cast Firebolt'),
-- 50% health: cast enrage (once only)
(10002, 0, 1, 0,  2, 0, 100, 1,  50, 50, 0, 0,  11, 8599, 0, 0, 0, 0, 0,  1, 0,0,0,0, 0,0,0,0, 'Mob - At 50% HP - Cast Enrage'),
-- 30% health: cast a desperate strike (once only)
(10002, 0, 2, 0,  2, 0, 100, 1,  30, 30, 0, 0,  11, 22887, 0, 0, 0, 0, 0,  2, 0,0,0,0, 0,0,0,0, 'Mob - At 30% HP - Cast Desperate Strike'),
-- On aggro: yell battle cry
(10002, 0, 3, 0,  4, 0, 100, 1,  0,0,0,0,  1, 0, 0, 0, 0, 0, 0,  1, 0,0,0,0, 0,0,0,0, 'Mob - On Aggro - Talk Group 0'),
-- On death: say death line
(10002, 0, 4, 0,  6, 0, 100, 0,  0,0,0,0,  1, 1, 0, 0, 0, 0, 0,  1, 0,0,0,0, 0,0,0,0, 'Mob - On Death - Talk Group 1');
```

### Recipe 3: Boss with Phase Transition, Empowerment, and Add Spawns

A boss that runs in phase 0 normally, transitions at 50% HP to phase 1 (different abilities + add spawn), and at 25% to phase 2.

```sql
UPDATE creature_template SET AIName = 'SmartAI' WHERE entry = 20001;

INSERT INTO smart_scripts (entryorguid, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags,
    event_param1, event_param2, event_param3, event_param4,
    action_type, action_param1, action_param2, action_param3, action_param4, action_param5, action_param6,
    target_type, target_param1, target_param2, target_param3, target_param4,
    target_x, target_y, target_z, target_o, comment)
VALUES
-- === PHASE 0 (any phase, always fires before transition) ===
-- Aggro yell + disable evade during fight
(20001, 0, 0, 1,  4, 0, 100, 1,  0,0,0,0,  1, 0, 0, 0, 0, 0, 0,  1, 0,0,0,0, 0,0,0,0, 'Boss - On Aggro - Talk 0'),
(20001, 0, 1, 0,  61, 0, 100, 0,  0,0,0,0,  117, 1, 0, 0, 0, 0, 0,  1, 0,0,0,0, 0,0,0,0, 'Boss - Link - Disable Evade'),

-- Phase 0 rotation: Cleave every 7-12 seconds
(20001, 0, 2, 0,  0, 1, 100, 0,  4000, 6000, 7000, 12000, 0, 0,  11, 15284, 0, 0, 0, 0, 0,  2, 0,0,0,0, 0,0,0,0, 'Boss - Phase1 IC - Cast Cleave'),

-- At 50% HP: transition to phase 2, yell, spawn adds
(20001, 0, 3, 4,  2, 0, 100, 1,  50, 50, 0, 0,  22, 2, 0, 0, 0, 0, 0,  1, 0,0,0,0, 0,0,0,0, 'Boss - At 50% HP - Set Phase 2'),
(20001, 0, 4, 5,  61, 0, 100, 0,  0,0,0,0,  1, 2, 0, 0, 0, 0, 0,  1, 0,0,0,0, 0,0,0,0, 'Boss - Link - Talk Phase 2'),
(20001, 0, 5, 0,  61, 0, 100, 0,  0,0,0,0,  12, 20002, 1, 30000, 1, 0, 0,  8, 0,0,0,0, -123.4, 456.7, 89.0, 0, 'Boss - Link - Summon Adds'),

-- Phase 2 (event_phase_mask=4 = phase 2) rotation: Shadowbolt
(20001, 0, 6, 0,  0, 4, 100, 0,  2000, 4000, 5000, 9000, 0, 0,  11, 9613, 0, 0, 0, 0, 0,  2, 0,0,0,0, 0,0,0,0, 'Boss - Phase2 IC - Cast Shadowbolt'),

-- At 25% HP: transition to phase 3, enrage
(20001, 0, 7, 8,  2, 0, 100, 1,  25, 25, 0, 0,  22, 3, 0, 0, 0, 0, 0,  1, 0,0,0,0, 0,0,0,0, 'Boss - At 25% HP - Set Phase 3'),
(20001, 0, 8, 0,  61, 0, 100, 0,  0,0,0,0,  75, 1, 0, 0, 0, 0, 0,  1, 0,0,0,0, 0,0,0,0, 'Boss - Link - Add Aura Enrage'),

-- Phase 3 (event_phase_mask=8) rotation: more aggressive
(20001, 0, 9, 0,  0, 8, 100, 0,  1000, 2000, 3000, 5000, 0, 0,  11, 22887, 0, 0, 0, 0, 0,  2, 0,0,0,0, 0,0,0,0, 'Boss - Phase3 IC - Cast Mortal Strike'),

-- Death: re-enable evade, death yell, despawn adds
(20001, 0, 10, 0,  6, 0, 100, 0,  0,0,0,0,  117, 0, 0, 0, 0, 0, 0,  1, 0,0,0,0, 0,0,0,0, 'Boss - On Death - Re-enable Evade');
```

**Note on phase masks in this example:**
- Rows with `event_phase_mask=1` are active in phase 1 (the default starting phase after `SET_EVENT_PHASE 1` — but if you never call SET_EVENT_PHASE, the initial phase is 0, and `event_phase_mask=0` rows always fire). Adjust to match your phase numbering convention.
- The example uses `event_phase_mask=1` for initial, `=4` for second phase, `=8` for enrage phase.

### Recipe 4: Escort Quest NPC

An NPC that walks a waypoint path, says different lines at different waypoints, pauses to fight enemies, and succeeds the quest on completion.

```sql
UPDATE creature_template SET AIName = 'SmartAI' WHERE entry = 30001;

-- Waypoint path must exist in waypoint_data table: path 30001 with points 1, 2, 3, 4, 5

INSERT INTO smart_scripts (entryorguid, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags,
    event_param1, event_param2, event_param3, event_param4,
    action_type, action_param1, action_param2, action_param3, action_param4, action_param5, action_param6,
    target_type, target_param1, target_param2, target_param3, target_param4,
    target_x, target_y, target_z, target_o, comment)
VALUES
-- On spawn: be passive (players start escort via quest/gossip), set walk
(30001, 0, 0, 0,  63, 0, 100, 0,  0,0,0,0,  8, 0, 0, 0, 0, 0, 0,  1, 0,0,0,0, 0,0,0,0, 'Escort NPC - On Create - Set Passive'),
-- Quest acceptance starts the waypoints (player uses quest item or gossip option → separate C++ or Eluna hook calls WAYPOINT_START)
-- But we can respond to accepted quest:
(30001, 0, 1, 0,  19, 0, 100, 1,  12345, 0, 0, 0,  232, 30001, 0, 0, 0, 0, 0,  1, 0,0,0,0, 0,0,0,0, 'Escort NPC - Quest Accepted - Start Waypoint'),
(30001, 0, 2, 0,  19, 0, 100, 1,  12345, 0, 0, 0,  8, 2, 0, 0, 0, 0, 0,  1, 0,0,0,0, 0,0,0,0, 'Escort NPC - Quest Accepted - Set Aggressive'),
-- Waypoint 1: say intro line
(30001, 0, 3, 0,  108, 0, 100, 0,  1, 30001, 0, 0,  1, 0, 0, 0, 0, 0, 0,  1, 0,0,0,0, 0,0,0,0, 'Escort NPC - WP 1 - Talk Group 0'),
-- Waypoint 3: pause and say middle-of-journey line
(30001, 0, 4, 0,  108, 0, 100, 0,  3, 30001, 0, 0,  1, 1, 0, 0, 0, 0, 0,  1, 0,0,0,0, 0,0,0,0, 'Escort NPC - WP 3 - Talk Group 1'),
-- Waypoint 5 (final): complete quest, set passive, despawn
(30001, 0, 5, 6,  108, 0, 100, 0,  5, 30001, 0, 0,  1, 2, 0, 0, 0, 0, 0,  1, 0,0,0,0, 0,0,0,0, 'Escort NPC - WP 5 Final - Talk Group 2'),
(30001, 0, 6, 7,  61, 0, 100, 0,  0,0,0,0,  15, 12345, 0, 0, 0, 0, 0,  27, 0,0,0,0, 0,0,0,0, 'Escort NPC - Link - Complete Quest'),
(30001, 0, 7, 0,  61, 0, 100, 0,  0,0,0,0,  41, 5000, 0, 0, 0, 0, 0,  1, 0,0,0,0, 0,0,0,0, 'Escort NPC - Link - Despawn After 5s'),
-- In combat: fight back (defensive)
(30001, 0, 8, 0,  4, 0, 100, 1,  0,0,0,0,  8, 2, 0, 0, 0, 0, 0,  1, 0,0,0,0, 0,0,0,0, 'Escort NPC - On Aggro - Set Aggressive'),
-- After evade: return to passive and resume waypoint
(30001, 0, 9, 0,  7, 0, 100, 0,  0,0,0,0,  8, 0, 0, 0, 0, 0, 0,  1, 0,0,0,0, 0,0,0,0, 'Escort NPC - On Evade - Set Passive');
-- target_type=27 (SMART_TARGET_LOOT_RECIPIENTS) used for quest credit to all who participated
```

### Recipe 5: Gossip NPC with Quest Offering

An NPC that opens a custom gossip menu and conditionally offers a quest.

```sql
UPDATE creature_template SET AIName = 'SmartAI', npcflag = 1 WHERE entry = 40001;
-- npcflag=1 = GOSSIP

-- Ensure gossip menu entry exists in gossip_menu and gossip_menu_option tables

INSERT INTO smart_scripts (entryorguid, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags,
    event_param1, event_param2, event_param3, event_param4,
    action_type, action_param1, action_param2, action_param3, action_param4, action_param5, action_param6,
    target_type, target_param1, target_param2, target_param3, target_param4,
    target_x, target_y, target_z, target_o, comment)
VALUES
-- Gossip hello: send gossip menu 1234 with npc_text 5678
(40001, 0, 0, 0,  64, 0, 100, 0,  0, 0, 0, 0,  98, 1234, 5678, 0, 0, 0, 0,  7, 0,0,0,0, 0,0,0,0, 'Gossip NPC - Hello - Send Menu'),
-- Gossip option 0 selected (menuID=1234, optionID=0): offer quest 99999
(40001, 0, 1, 0,  62, 0, 100, 0,  1234, 0, 0, 0,  7, 99999, 0, 0, 0, 0, 0,  7, 0,0,0,0, 0,0,0,0, 'Gossip NPC - Option 0 - Offer Quest'),
-- After offering quest, close gossip
(40001, 0, 2, 0,  62, 0, 100, 0,  1234, 0, 0, 0,  72, 0, 0, 0, 0, 0, 0,  7, 0,0,0,0, 0,0,0,0, 'Gossip NPC - Option 0 - Close Gossip');
-- Note: two rows with same gossip event will both fire. Use link chaining if you want guaranteed ordering:
-- id=1, link=2 → id=2 is SMART_EVENT_LINK for close gossip
```

---

## Debugging SmartAI

### GM Commands

```
.npc set debugai on          -- Enable SmartAI debug output for targeted creature
.npc set debugai off         -- Disable
.reload smart_scripts        -- Reload smart_scripts table without server restart
.reload creature_text        -- Also reload creature_text if you changed NPC dialogue
```

The debug output is sent to the GM's chat and printed to the console/log at `DEBUG` level (the `scripts.ai` log channel). It shows:
- Which events are firing and why
- Which actions are executing
- What target was selected and its GUID
- Parameter values being used

### Common Mistakes and How to Spot Them

| Symptom | Likely Cause |
|---|---|
| Event never fires | Wrong `event_type`, or `event_phase_mask` excludes current phase, or `event_flags=1` already fired once |
| Action fires but nothing happens | Invalid `target_type` returning null (no valid target), or action param references invalid entry/spell |
| Script runs in all difficulties when you only want heroic | Forgot to set difficulty `event_flags` (2/4/8/16) |
| NPC speaks but wrong text | `action_param1` (GroupID) does not match `creature_text.GroupID` for this entry |
| Phase never changes | `SET_EVENT_PHASE` target is wrong; must target `SMART_TARGET_SELF (1)` |
| Linked row does not fire | The linked row does not have `event_type = 61` (SMART_EVENT_LINK) |
| Timed action list not executing | `entryorguid` for `source_type=9` must be `creatureEntry × 100`; the creature template AIName must be `SmartAI` |
| OOC_LOS fires in combat | OOC_LOS (10) is out-of-combat only; use IC_LOS (26) for in-combat line-of-sight |
| `SMART_TARGET_ACTION_INVOKER` returns null | The triggering event is not in the invoker-aware events list |
| Spell cast does nothing but NPC has mana | `triggeredFlags=0` applies full triggered mask; if you want a normal cast with mana cost, set specific flags |
| NPC evades immediately after phase transition | `SMART_ACTION_DISABLE_EVADE` was not called; health threshold transitions can trigger evade checks |

### Test Cycle Without Server Restart

1. Edit `smart_scripts` rows in the database directly.
2. In-game: `.reload smart_scripts`
3. Kill and respawn the NPC (`.npc delete` then repopulate, or use `.reload creature` for individual spawns).
4. Enable debug: `.npc set debugai on` while targeting the NPC.
5. Trigger the event you want to test.
6. Read debug output in GM chat.

### Log Channels

SmartAI logs to two channels in `Logger.conf`:

```ini
Logger.scripts.ai=3,Console Server        # AI debug messages (level 3=debug)
Logger.sql.sql=2,Console Server           # SQL validation errors (level 2=info)
```

SQL validation errors (invalid spell IDs, missing creature entries, etc.) appear at startup in `sql.sql`. If a reference is invalid, the entire row is loaded but the action/event will silently fail at runtime.

---

## Cross-References

- `creature_template.AIName` — must be `'SmartAI'` for entry-based scripts
- `creature_text` — NPC dialogue used by `SMART_ACTION_TALK` (GroupID, ID, Text, Type, Sound)
- `waypoint_data` — path data referenced by `SMART_ACTION_WAYPOINT_START` (pathID → point ID → X/Y/Z/delay/moveType)
- `creature_summon_groups` — group spawn definitions for `SMART_ACTION_SUMMON_CREATURE_GROUP`
- `gossip_menu` / `gossip_menu_option` — menu data for `SMART_ACTION_SEND_GOSSIP_MENU` and `SMART_EVENT_GOSSIP_SELECT`
- `npc_text` — NPC gossip text pages referenced by `SMART_ACTION_SEND_GOSSIP_MENU` param2
- `areatrigger_scripts` — must contain `'SmartTrigger'` for areatrigger source_type scripts
- `gameobject_template.AIName` — must be `'SmartGameObjectAI'` for GO scripts
- `acore_string` — server-side string table for `SMART_ACTION_PLAYER_TALK`
- `game_event` — event entries for `SMART_EVENT_GAME_EVENT_START/END` and `SMART_ACTION_GAME_EVENT_START/STOP`
- `spell_dbc` / `Spell.dbc` — spell IDs used in SMART_ACTION_CAST, SMART_EVENT_SPELLHIT, etc.
- `quest_template` — quest IDs for SMART_EVENT_ACCEPTED_QUEST, REWARD_QUEST, SMART_ACTION_FAIL_QUEST, etc.
- AzerothCore source: `src/server/game/AI/SmartScripts/SmartScript.cpp` — runtime execution logic
- AzerothCore source: `src/server/game/AI/SmartScripts/SmartScriptMgr.h` — all enum definitions and struct layouts
- AzerothCore source: `src/server/game/AI/SmartScripts/SmartScriptMgr.cpp` — loading and validation logic
- `kb_azerothcore_dev.md` — AzerothCore C++ module development, hooks, script base classes
- `kb_eluna_api.md` — Eluna Lua API for when SmartAI is insufficient and Lua scripting is preferred
