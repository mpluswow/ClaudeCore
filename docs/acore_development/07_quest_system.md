# Quest System

Complete reference for AzerothCore quest system: `quest_template`, objective mechanics, C++ quest scripting, quest chains, and the conditions system.

---

## Table of Contents

1. [quest_template — Core Fields](#1-quest_template--core-fields)
2. [quest_template — Flags & Enumerations](#2-quest_template--flags--enumerations)
3. [quest_template — Objectives](#3-quest_template--objectives)
4. [quest_template — Rewards](#4-quest_template--rewards)
5. [Quest Chains & Progression](#5-quest-chains--progression)
6. [Quest Script Hooks (C++)](#6-quest-script-hooks-c)
7. [NPC Quest Givers in C++](#7-npc-quest-givers-in-c)
8. [Quest Objective Types](#8-quest-objective-types)
9. [Conditions System](#9-conditions-system)
10. [Quest Chain Design Patterns](#10-quest-chain-design-patterns)
11. [Cross-References](#11-cross-references)

---

## 1. quest_template — Core Fields

Primary table: `world.quest_template`. One row per quest. The server also reads `quest_template_addon` for chaining fields.

### Identity & Classification

| Column | Type | Description |
|--------|------|-------------|
| `ID` | MEDIUMINT UNSIGNED | Unique quest ID. Referenced by NPCs, GOs, items. Primary key. |
| `QuestType` | TINYINT UNSIGNED | Quest behavior mode. See §2. |
| `QuestLevel` | SMALLINT | Quest difficulty level. Controls XP scaling. -1 = level-scaled. |
| `MinLevel` | TINYINT UNSIGNED | Minimum player level to accept the quest. |
| `QuestSortID` | SMALLINT | Quest log category. Positive = Zone ID. Negative = `QuestSort.dbc` entry (profession quests etc.). |
| `QuestInfoID` | SMALLINT UNSIGNED | Quest type badge from `QuestInfo.dbc` (e.g., Group, PvP, Raid, Dungeon, Legendary, Escort, Heroic). |
| `SuggestedGroupNum` | TINYINT UNSIGNED | Recommended group size shown in quest log. 0 = solo. |
| `AllowableRaces` | SMALLINT UNSIGNED | Race bitmask. Same values as `item_template.AllowableRace`. 0 = all. |
| `TimeAllowed` | INT UNSIGNED | Timed quest duration in seconds. 0 = no time limit. Countdown begins on accept. |
| `Unknown0` | TINYINT UNSIGNED | Reserved / unused. Always 0. |
| `VerifiedBuild` | SMALLINT | Client build number this row was verified against. |

### Prerequisites (Faction)

| Column | Type | Description |
|--------|------|-------------|
| `RequiredFactionId1` | SMALLINT UNSIGNED | Faction ID prerequisite 1 (from `Faction.dbc`). |
| `RequiredFactionId2` | SMALLINT UNSIGNED | Faction ID prerequisite 2. |
| `RequiredFactionValue1` | MEDIUMINT | Minimum reputation value for faction 1 (raw reputation points, not rank). |
| `RequiredFactionValue2` | MEDIUMINT | Minimum reputation value for faction 2. |

### Player Kill Requirement

| Column | Type | Description |
|--------|------|-------------|
| `RequiredPlayerKills` | TINYINT UNSIGNED | Number of enemy players to kill to complete the quest. |

### Starting Item

| Column | Type | Description |
|--------|------|-------------|
| `StartItem` | MEDIUMINT UNSIGNED | Item entry given to the player when they accept the quest. Deleted on quest abandon. |

### Text Content

| Column | Type | Description |
|--------|------|-------------|
| `LogTitle` | TEXT | Quest name displayed in the quest log and tracker. |
| `LogDescription` | TEXT | Objectives text shown in the quest log. If empty, quest auto-completes. |
| `QuestDescription` | TEXT | Main quest description text (shown in quest accept dialog). Supports placeholders: `$B`=line break, `$N`=player name, `$R`=race, `$C`=class, `$Gmale:female;`=gender. |
| `AreaDescription` | TEXT | Location hint text (shown below objectives). |
| `QuestCompletionLog` | TEXT | Text shown when player tries to turn in the quest but has not yet completed all objectives ("I need you to kill 10 more wolves..."). |
| `ObjectiveText1`–`ObjectiveText4` | TEXT | Override text for the corresponding `RequiredNpcOrGo` objective (shown in tracker). If empty, the server auto-generates "Kill X: 0/5". |

### Map Marker (Point of Interest)

| Column | Type | Description |
|--------|------|-------------|
| `POIContinent` | SMALLINT UNSIGNED | Map ID for the quest POI marker. |
| `POIx` | FLOAT | World X coordinate of the quest marker. |
| `POIy` | FLOAT | World Y coordinate of the quest marker. |
| `POIPriority` | MEDIUMINT UNSIGNED | Display priority for competing quest markers. Higher = shown first. |

---

## 2. quest_template — Flags & Enumerations

### QuestType

| Value | Behavior |
|-------|----------|
| 0 | Autocomplete — Quest is instantly complete on accept. No objectives. Turn in begins immediately. |
| 1 | Disabled — Quest exists in DB but is not available in-game. |
| 2 | Normal — Standard quest requiring objectives to be completed before turn-in (default). |

### Flags (QuestFlags bitmask)

| Value | Constant | Description |
|-------|----------|-------------|
| 0 | QUEST_FLAGS_NONE | No flags. |
| 1 | QUEST_FLAGS_STAY_ALIVE | Quest fails if the player dies. |
| 2 | QUEST_FLAGS_PARTY_ACCEPT | Used for escort quests and event-driven quests. Quest is shared with the party on accept. |
| 4 | QUEST_FLAGS_EXPLORATION | Quest is completed by entering an area trigger (AreaTrigger table). |
| 8 | QUEST_FLAGS_SHARABLE | Quest can be shared with party members via "Share Quest" button. |
| 16 | QUEST_FLAGS_HAS_CONDITION | Quest has additional conditions checked server-side. |
| 32 | QUEST_FLAGS_HIDE_REWARD_POI | Hides the reward POI marker on the map. |
| 64 | QUEST_FLAGS_RAID | Quest can be completed while in a raid group (normally blocked). |
| 128 | QUEST_FLAGS_TBC | Marks quest as a Burning Crusade quest (informational). |
| 256 | QUEST_FLAGS_NO_MONEY_FROM_XP | No money is awarded from quest XP conversion at max level. |
| 512 | QUEST_FLAGS_HIDDEN_REWARDS | Item and money rewards are hidden in the accept dialog (shown as "???"). |
| 1024 | QUEST_FLAGS_TRACKING | Tracking quest — automatically rewarded on first completion, never appears in quest log. Used for achievement tracking. |
| 2048 | QUEST_FLAGS_DEPRECATE_REPUTATION | Deprecated reputation flag. |
| 4096 | QUEST_FLAGS_DAILY | Daily quest. Can be repeated once per day. Sets `QUEST_STATUS_DAILY` after reward. |
| 8192 | QUEST_FLAGS_PVP | Forces PvP flag on the player while quest is in log. |
| 16384 | QUEST_FLAGS_UNAVAILABLE | Quest is unavailable (similar to disabled). |
| 32768 | QUEST_FLAGS_WEEKLY | Weekly quest. Resets on weekly server reset. |
| 65536 | QUEST_FLAGS_AUTOCOMPLETE | Quest auto-completes (no turn-in NPC needed). |
| 131072 | QUEST_FLAGS_DISPLAY_ITEM_IN_TRACKER | Show a specific item in the quest tracker. |
| 262144 | QUEST_FLAGS_OBJ_TEXT | Use the ObjectiveText fields for all objectives. |
| 524288 | QUEST_FLAGS_AUTO_ACCEPT | Quest is auto-accepted when the condition is met (e.g., entering area). |
| 2097152 | QUEST_FLAGS_PLAYER_CAST_ON_ACCEPT | Player casts the RewardSpell on quest accept. |
| 4194304 | QUEST_FLAGS_PLAYER_CAST_ON_COMPLETE | Player casts the RewardSpell on quest complete (vs. NPC casting it). |
| 2147483648 | QUEST_FLAGS_FAIL_ON_LOGOUT | Quest is failed if the player logs out. |

### SpecialFlags (quest_template_addon.SpecialFlags)

Stored in `quest_template_addon.SpecialFlags`, not in `quest_template.Flags`.

| Value | Constant | Description |
|-------|----------|-------------|
| 0 | — | None. |
| 1 | QUEST_SPECIAL_FLAGS_REPEATABLE | Quest is infinitely repeatable (not daily/weekly — can be re-done immediately after turn-in). |
| 2 | QUEST_SPECIAL_FLAGS_EXPLORATION_OR_EVENT | Quest requires an area trigger or script event to complete (complement to `QUEST_FLAGS_EXPLORATION`). |
| 4 | QUEST_SPECIAL_FLAGS_AUTO_ACCEPT | Quest is automatically accepted (no dialog). |
| 8 | QUEST_SPECIAL_FLAGS_DF_QUEST | Dungeon Finder daily quest. |
| 16 | QUEST_SPECIAL_FLAGS_MONTHLY | Monthly repeatable quest. |

---

## 3. quest_template — Objectives

### NPC Kill / GameObject Interaction Objectives

| Column | Type | Description |
|--------|------|-------------|
| `RequiredNpcOrGo1` | MEDIUMINT | Positive = `creature_template.entry` to kill. Negative = `gameobject_template.entry` to interact with. |
| `RequiredNpcOrGo2` | MEDIUMINT | Second NPC/GO objective. 0 = unused. |
| `RequiredNpcOrGo3` | MEDIUMINT | Third NPC/GO objective. 0 = unused. |
| `RequiredNpcOrGo4` | MEDIUMINT | Fourth NPC/GO objective. 0 = unused. |
| `RequiredNpcOrGoCount1` | SMALLINT UNSIGNED | How many kills or interactions required for objective 1. |
| `RequiredNpcOrGoCount2` | SMALLINT UNSIGNED | Count for objective 2. |
| `RequiredNpcOrGoCount3` | SMALLINT UNSIGNED | Count for objective 3. |
| `RequiredNpcOrGoCount4` | SMALLINT UNSIGNED | Count for objective 4. |

**Kill credit vs. GO interaction:**
- Positive value: The creature must be killed. Kill credit can be shared in a party.
- Negative value (e.g., -180): The GO with entry 180 must be activated (right-clicked/used). The GO's `questgiver` state must be enabled. The server fires `UpdateQuestGoCount` on GO interaction.

**Spell-cast objectives:** If `RequiredSpellCast` is non-zero for an objective slot, the player must cast that spell (usually on the target NPC/GO) rather than simply killing/interacting. See `quest_template_addon` for these fields.

### Item Collection Objectives

| Column | Type | Description |
|--------|------|-------------|
| `RequiredItemId1` | MEDIUMINT UNSIGNED | Item entry that must be collected. |
| `RequiredItemId2` | MEDIUMINT UNSIGNED | Second item. 0 = unused. |
| `RequiredItemId3` | MEDIUMINT UNSIGNED | Third item. 0 = unused. |
| `RequiredItemId4` | MEDIUMINT UNSIGNED | Fourth item. 0 = unused. |
| `RequiredItemId5` | MEDIUMINT UNSIGNED | Fifth item. 0 = unused. |
| `RequiredItemId6` | MEDIUMINT UNSIGNED | Sixth item. 0 = unused. |
| `RequiredItemCount1` | SMALLINT UNSIGNED | Required quantity for item 1. |
| `RequiredItemCount2` | SMALLINT UNSIGNED | Required quantity for item 2. |
| `RequiredItemCount3` | SMALLINT UNSIGNED | Required quantity for item 3. |
| `RequiredItemCount4` | SMALLINT UNSIGNED | Required quantity for item 4. |
| `RequiredItemCount5` | SMALLINT UNSIGNED | Required quantity for item 5. |
| `RequiredItemCount6` | SMALLINT UNSIGNED | Required quantity for item 6. |

**Notes:**
- Items tracked for a quest are not automatically added to the player's bags when creatures are killed. They drop via `creature_loot_template` with `QuestRequired=1`.
- The quest log tracks items as the player picks them up. When the player drops the items before turning in, the quest tracker resets to 0.

### Item Drop Helpers (not objectives, but pickups)

| Column | Type | Description |
|--------|------|-------------|
| `ItemDrop1`–`ItemDrop4` | MEDIUMINT UNSIGNED | Item entries that the server tells the client to look out for (shown in objectives tooltip). These are informational only — the actual drops come from `creature_loot_template`. |
| `ItemDropQuantity1`–`ItemDropQuantity4` | SMALLINT UNSIGNED | Max quantity of `ItemDrop` items to pick up (shown in tracker). |

### Objective Text Overrides

| Column | Type | Description |
|--------|------|-------------|
| `ObjectiveText1`–`ObjectiveText4` | TEXT | Custom text for the corresponding `RequiredNpcOrGo` objective slot. If empty, the client generates default text. |

---

## 4. quest_template — Rewards

### Experience & Money

| Column | Type | Description |
|--------|------|-------------|
| `RewardXPDifficulty` | TINYINT UNSIGNED | Index into `QuestXP.dbc` that sets base XP reward. Scales by quest level vs. player level. |
| `RewardMoney` | INT | Gold reward in copper. Positive = reward. Negative = cost (player must pay). |
| `RewardMoneyDifficulty` | INT UNSIGNED | References a money difficulty factor for level-scaling. Usually 0. |
| `RewardBonusMoney` | INT UNSIGNED | Bonus money awarded at maximum level instead of XP (XP → money conversion). |

### Items (Guaranteed)

All players receive these items on completion.

| Column | Type | Description |
|--------|------|-------------|
| `RewardItem1`–`RewardItem4` | MEDIUMINT UNSIGNED | Item entry IDs. 0 = unused. |
| `RewardAmount1`–`RewardAmount4` | SMALLINT UNSIGNED | Quantity of each guaranteed reward item. |

### Items (Choice)

Player picks one group from these items.

| Column | Type | Description |
|--------|------|-------------|
| `RewardChoiceItemID1`–`RewardChoiceItemID6` | MEDIUMINT UNSIGNED | Choosable item entries. 0 = unused. |
| `RewardChoiceItemQuantity1`–`RewardChoiceItemQuantity6` | SMALLINT UNSIGNED | Quantity of each choice item. |

### Spells

| Column | Type | Description |
|--------|------|-------------|
| `RewardDisplaySpell` | MEDIUMINT UNSIGNED | Spell ID shown in the quest completion dialog (visual only if `RewardSpell` is also set). |
| `RewardSpell` | INT | Spell cast on the player upon quest completion. If positive, it's a beneficial spell. Use this to teach skills, apply buffs, etc. |

### Reputation

Up to 5 faction reputation rewards:

| Column | Type | Description |
|--------|------|-------------|
| `RewardFactionID1`–`RewardFactionID5` | SMALLINT UNSIGNED | Faction entries from `Faction.dbc`. |
| `RewardFactionValue1`–`RewardFactionValue5` | MEDIUMINT | Raw reputation points awarded (can be negative for loss). |
| `RewardFactionOverride1`–`RewardFactionOverride5` | MEDIUMINT | If non-zero, overrides the scaling formula and gives this exact value in 1/100 units (divide by 100 for actual rep). |

### Honor & PvP

| Column | Type | Description |
|--------|------|-------------|
| `RewardHonor` | INT | Number of honorable kill equivalent honor points awarded. |
| `RewardKillHonor` | FLOAT | Kill honor multiplier (usually 0). |
| `RewardArenaPoints` | SMALLINT UNSIGNED | Arena points rewarded on completion. |

### Titles & Talents

| Column | Type | Description |
|--------|------|-------------|
| `RewardTitle` | TINYINT UNSIGNED | Title ID from `CharTitles.dbc` granted on completion. |
| `RewardTalents` | TINYINT UNSIGNED | Bonus talent points granted (used for Death Knight starting quests). |

### Chain Reward

| Column | Type | Description |
|--------|------|-------------|
| `RewardNextQuest` | MEDIUMINT UNSIGNED | Quest entry that immediately becomes available from the same NPC on turn-in. The follow-up quest pops up instantly without requiring another conversation. |

---

## 5. Quest Chains & Progression

These fields live in `quest_template_addon` (a companion table keyed by `ID`):

| Column | Type | Description |
|--------|------|-------------|
| `PrevQuestId` | MEDIUMINT SIGNED | Quest that must have been **rewarded** before this one becomes available. Positive = must be rewarded. Negative = must be taken but NOT yet rewarded (i.e., quest must be in-progress). |
| `NextQuestId` | MEDIUMINT UNSIGNED | Quest that this one unlocks (informational in DB; enforcement done via PrevQuestId on the next quest). |
| `ExclusiveGroup` | MEDIUMINT SIGNED | Mutual exclusion group. See below. |
| `SpecialFlags` | TINYINT UNSIGNED | Additional flags. See §2 SpecialFlags. |
| `BreadcrumbForQuestId` | MEDIUMINT UNSIGNED | This quest is a breadcrumb leading to another quest. Completing the target quest removes this breadcrumb. |
| `AllowableClasses` | MEDIUMINT UNSIGNED | Class bitmask: quest only available to these classes (same values as `AllowableClass` in items). |
| `SourceSpellID` | MEDIUMINT UNSIGNED | Spell that gives this quest when cast. |
| `RequiredSkillId` | SMALLINT UNSIGNED | Skill required (from `SkillLine.dbc`). |
| `RequiredSkillPoints` | SMALLINT UNSIGNED | Minimum skill value. |
| `RequiredMinRepFaction` | SMALLINT UNSIGNED | Faction ID for minimum reputation requirement. |
| `RequiredMaxRepFaction` | SMALLINT UNSIGNED | Faction ID for maximum reputation cap (quest only available below this rep). |
| `RequiredMinRepValue` | MEDIUMINT | Minimum reputation value (raw) for `RequiredMinRepFaction`. |
| `RequiredMaxRepValue` | MEDIUMINT | Maximum reputation value (raw) — quest hidden above this level. |

### PrevQuestId Mechanics

```
Quest A (ID=100) → Quest B (PrevQuestId=100) → Quest C (PrevQuestId=101)
```

- Quest B only appears after Quest A has been turned in (rewarded).
- Set `PrevQuestId=-100` on Quest B to require that Quest A be *in progress* (not yet completed) — used for branching where accepting B cancels A.

### ExclusiveGroup Mechanics

| ExclusiveGroup Value | Behavior |
|---------------------|----------|
| 0 | No exclusion (default). |
| Positive N | **One of the group completes the chain.** Quests sharing the same positive value are alternatives — completing any one makes the others unavailable. Example: Alliance vs. Horde version of the same quest both set ExclusiveGroup=5; player can only do one. |
| Negative N | **All must fail for the next to proceed.** Quests sharing the same negative value must all be abandoned/failed before the follow-up unlocks. Rarely used. |

**Example — faction-branching:**
```sql
-- Quest 200: Alliance version; Quest 201: Horde version
-- Player can only do one
UPDATE quest_template_addon SET ExclusiveGroup = 50 WHERE ID IN (200, 201);
```

### Daily & Weekly Reset

- `Flags & QUEST_FLAGS_DAILY (4096)`: Quest resets at the daily reset (03:00 server time by default).
- `Flags & QUEST_FLAGS_WEEKLY (32768)`: Quest resets on the weekly reset (Monday 03:00).
- `SpecialFlags & 16` (MONTHLY): Quest resets on the first of each month.

### Resetting a Quest for a Player via SQL

```sql
-- Remove completion record (allows re-accepting a rewarded quest for testing)
DELETE FROM character_queststatus_rewarded
WHERE guid = <charGuid> AND quest = <questId>;

-- Remove in-progress status
DELETE FROM character_queststatus
WHERE guid = <charGuid> AND quest = <questId>;

-- Remove daily completion flag
DELETE FROM character_queststatus_daily
WHERE guid = <charGuid> AND quest = <questId>;
```

The player must relog or use `.reload` commands for the change to take effect in an active session.

---

## 6. Quest Script Hooks (C++)

### QuestScript Class

Attach custom C++ logic to a quest via `QuestScript`. Register with the quest's ID.

```cpp
class MyQuestScript : public QuestScript
{
public:
    MyQuestScript() : QuestScript("MyQuestScript") {}

    // Called when a player accepts the quest.
    // 'quest' is the Quest const* (static data).
    void OnQuestAccept(Player* player, Quest const* quest) override
    {
        // Example: summon an escort NPC
        player->SummonCreature(1234, player->GetPositionX() + 2.0f,
                                     player->GetPositionY(),
                                     player->GetPositionZ(),
                                     0.0f, TEMPSUMMON_TIMED_DESPAWN, 300000);
    }

    // Called when the player turns in the quest.
    // 'opt' is the reward choice option index (0-based, matches RewardChoiceItemID slots).
    void OnQuestReward(Player* player, Quest const* quest, uint32 opt) override
    {
        switch (opt)
        {
            case 0: // Player chose RewardChoiceItemID1
                player->CastSpell(player, SPELL_CHOICE_A_BUFF, true);
                break;
            case 1: // Player chose RewardChoiceItemID2
                player->CastSpell(player, SPELL_CHOICE_B_BUFF, true);
                break;
        }
    }

    // Called when all quest objectives are complete (before turn-in).
    void OnQuestComplete(Player* player, Quest const* quest) override
    {
        // Fires when the quest tracker shows "Return to Quest Giver"
        // Useful for spawning a boss or triggering an event
    }

    // Called when the player abandons the quest.
    void OnQuestAbandon(Player* player, Quest const* quest) override
    {
        // Cleanup any summons, etc.
    }
};

void AddSC_MyQuestScript()
{
    new MyQuestScript();
}
```

**Attaching to a quest:**
```sql
UPDATE quest_template SET ScriptName = 'MyQuestScript' WHERE ID = 12345;
```

Wait — `quest_template` does not have a `ScriptName` column directly in the base AzerothCore schema. Quest scripts are typically registered by quest ID in the script loader. The registration is done via `sQuestDataStore->GetQuestScript(questId)` internally. In practice, use `quest_template_addon.ScriptName` if present in your build, or register via `RegisterQuestScript(questId, scriptObject)` pattern in your module.

### Manual Quest Credit

```cpp
// Grant kill credit for a quest creature objective
player->KilledMonster(creatureInfo, creatureGuid);
// or by entry only:
player->KilledMonsterCredit(creatureEntry, ObjectGuid::Empty);

// Grant GO use credit
player->SendQuestUpdateAddCredit(quest, goGuid, questObj, player->GetQuestObjectiveData(quest, objIndex) + 1);
// Simpler: use the helper
player->CastedCreatureOrGO(goEntry, goGuid, 0);
```

### Checking Quest Status

```cpp
// Check if player has a quest in progress
if (player->GetQuestStatus(questId) == QUEST_STATUS_INCOMPLETE)
    { /* quest in log, not done */ }

if (player->GetQuestStatus(questId) == QUEST_STATUS_COMPLETE)
    { /* ready to turn in */ }

if (player->IsQuestRewarded(questId))
    { /* player has already completed and turned in */ }

// Check if player can accept a quest
if (player->CanAddQuest(quest, false))
    { /* all prerequisites met */ }
```

### Programmatically Adding / Completing Quests

```cpp
// Force-add a quest to the player's log
player->AddQuest(quest, nullptr); // nullptr = no quest giver
player->AutoUnequipOffhandIfNeed();

// Force-complete all objectives
player->CompleteQuest(questId);

// Reward quest (skips turn-in)
player->RewardQuest(quest, 0 /*itemChoice*/, player /*questGiver*/, false /*announce*/);
```

---

## 7. NPC Quest Givers in C++

NPCs that offer and receive quests don't need a C++ script for basic functionality — they work via DB:

- `creature_questrelation` — links NPC entry to quest IDs it *offers*.
- `creature_involvedrelation` — links NPC entry to quest IDs it *receives* (turn-in).
- `gameobject_questrelation` / `gameobject_involvedrelation` — same for GameObjects.

```sql
-- NPC 12345 gives quest 9001 and receives quest 9001
INSERT INTO creature_questrelation (id, quest) VALUES (12345, 9001);
INSERT INTO creature_involvedrelation (id, quest) VALUES (12345, 9001);
```

### Combining Gossip and Quest in C++

When a quest giver also has custom gossip menus, use a `CreatureScript` that handles both:

```cpp
class npc_my_quest_giver : public CreatureScript
{
public:
    npc_my_quest_giver() : CreatureScript("npc_my_quest_giver") {}

    struct npc_my_quest_giverAI : public ScriptedAI
    {
        npc_my_quest_giverAI(Creature* c) : ScriptedAI(c) {}
    };

    CreatureAI* GetAI(Creature* c) const override
    {
        return new npc_my_quest_giverAI(c);
    }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        // Add standard quest greeting
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());

        // Add custom gossip options
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Tell me about the lore.", GOSSIP_SENDER_MAIN, 1);

        SendGossipMenuFor(player, creature->GetEntry(), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
    {
        player->PlayerTalkClass->ClearMenus();
        if (action == 1)
        {
            // Handle lore gossip
            SendGossipMenuFor(player, NPC_TEXT_LORE, creature->GetGUID());
        }
        return true;
    }

    // Called when player accepts a quest from this NPC
    bool OnQuestAccept(Player* player, Creature* creature, Quest const* quest) override
    {
        if (quest->GetQuestId() == QUEST_MY_ID)
        {
            creature->AI()->Talk(SAY_QUEST_ACCEPTED, player);
        }
        return false; // false = use default quest accept handler
    }

    // Called when player turns in a quest to this NPC
    bool OnQuestReward(Player* player, Creature* creature, Quest const* quest, uint32 opt) override
    {
        if (quest->GetQuestId() == QUEST_MY_ID)
        {
            creature->AI()->Talk(SAY_QUEST_COMPLETE, player);
        }
        return false;
    }
};

void AddSC_npc_my_quest_giver()
{
    new npc_my_quest_giver();
}
```

Set `creature_template.ScriptName = 'npc_my_quest_giver'`.

---

## 8. Quest Objective Types

### Kill Credit (RequiredNpcOrGo > 0)

The server listens for `Player::KilledMonster` events and increments the relevant quest counter. The counter is stored in `character_queststatus.mobcount1`–`mobcount4`.

**Important:** If multiple quest objectives share the same creature entry, only the first matching slot is credited.

**Kill credit items:** Some quests require killing a creature and looting a specific item (e.g., hearts, heads). The item itself is the tracked objective (`RequiredItemId`), not the kill. Set the item on `creature_loot_template` with `QuestRequired=1`.

### GO Interaction Credit (RequiredNpcOrGo < 0)

Negative entry = GO interaction. The server fires when the player activates a GO of that entry. The GO type must support activation (chests, buttons, levers, etc.).

The GO must be linked to the quest via the server's quest-GO activation logic. The activation fires `Player::SendQuestUpdateAddCredit` automatically for matching GO entries.

### Spell Cast Objectives (RequiredSpellCast in quest_template_addon)

When `quest_template_addon.RequiredSpellCast1`–`4` are set, the player must cast the specified spell (usually at the target creature/GO) to get credit. The kill-or-cast branching logic:

```
If RequiredSpellCast[i] != 0:
    → credit when spell is cast on the NPC/GO
Else:
    → credit when NPC is killed or GO is activated
```

### Exploration Objectives (AreaTrigger)

Quests with `Flags & QUEST_FLAGS_EXPLORATION (4)` are completed by entering an AreaTrigger zone. The trigger is defined in the `areatrigger_involvedrelation` table:

```sql
-- AreaTrigger 1234 completes quest 5678 when entered
INSERT INTO areatrigger_involvedrelation (id, quest) VALUES (1234, 5678);
```

The `AreaDescription` field in `quest_template` should describe the location to visit.

### Item Objectives

Items are tracked automatically as the player picks them up. The quest system checks `RequiredItemId`/`RequiredItemCount` on every item pickup. Items that fill quest slots are flagged with `ITEM_QUALITY_QUEST` in the client display.

To ensure items only drop for players who need them, set `QuestRequired=1` in `creature_loot_template`.

---

## 9. Conditions System

The `conditions` table gates many server systems behind per-player runtime checks. It is a general-purpose conditional logic framework.

### conditions Table Columns

| Column | Type | Description |
|--------|------|-------------|
| `SourceTypeOrReferenceId` | MEDIUMINT SIGNED | Identifies what system this condition belongs to. Negative = this is a reference template row (used by other conditions). See SourceType table. |
| `SourceGroup` | MEDIUMINT UNSIGNED | Meaning depends on SourceType. Typically a group ID, menu ID, or loot template entry. |
| `SourceEntry` | MEDIUMINT SIGNED | Specific entry within the source (e.g., quest ID, spell ID, item ID in loot). |
| `SourceId` | INT SIGNED | Extra discriminator. For SmartAI: `smart_scripts.source_type`. Usually 0. |
| `ElseGroup` | MEDIUMINT UNSIGNED | Logical grouping key. See AND/OR logic below. |
| `ConditionTypeOrReference` | MEDIUMINT SIGNED | What condition to check. Negative = reference to another condition row. See ConditionType table. |
| `ConditionTarget` | TINYINT UNSIGNED | Which object the condition applies to (0=implicit target/player, 1=second object in context). |
| `ConditionValue1` | INT UNSIGNED | Primary parameter. Meaning is ConditionType-specific. |
| `ConditionValue2` | INT UNSIGNED | Secondary parameter. |
| `ConditionValue3` | INT UNSIGNED | Tertiary parameter. |
| `NegativeCondition` | TINYINT UNSIGNED | 1 = invert the condition result (logical NOT). |
| `ErrorType` | MEDIUMINT UNSIGNED | Error message ID from `SharedDefines.h` shown when condition fails (for spells/gossip). 0 = default. |
| `ErrorTextId` | MEDIUMINT UNSIGNED | Custom broadcast text ID for failure message. |
| `ScriptName` | CHAR(64) | Script name for script-driven conditions. |
| `Comment` | VARCHAR(255) | Human-readable description. |

### AND / OR Logic (ElseGroup)

Conditions within the **same ElseGroup value** are AND-ed together (all must be true).
Conditions with **different ElseGroup values** (sharing the same SourceType/SourceGroup/SourceEntry) are OR-ed (any group passing = overall pass).

```
ElseGroup=0: (CONDITION_LEVEL >= 60) AND (CONDITION_QUESTREWARDED = 100)
ElseGroup=1: (CONDITION_ACHIEVEMENT = 500)
→ Final: (Level≥60 AND Quest100Rewarded) OR (Achievement500Done)
```

### SourceType Values

| ID | Constant | SourceGroup | SourceEntry | Notes |
|----|----------|-------------|-------------|-------|
| 0 | NONE | — | — | Reference template only. |
| 1 | CREATURE_LOOT | Loot template entry | Item ID | Gates creature loot drops. |
| 2 | DISENCHANT_LOOT | Loot template entry | Item ID | Gates disenchant results. |
| 3 | FISHING_LOOT | Loot template entry | Item ID | Gates fishing loot. |
| 4 | GAMEOBJECT_LOOT | Loot template entry | Item ID | Gates GO loot. |
| 5 | ITEM_LOOT | Loot template entry | Item ID | Gates container loot. |
| 6 | MAIL_LOOT | Loot template entry | Item ID | Gates mail attachment loot. |
| 7 | MILLING_LOOT | Loot template entry | Item ID | Gates milling results. |
| 8 | PICKPOCKETING_LOOT | Loot template entry | Item ID | Gates pickpocket loot. |
| 9 | PROSPECTING_LOOT | Loot template entry | Item ID | Gates prospecting results. |
| 10 | REFERENCE_LOOT | Loot template entry | Item ID | Conditions on reference templates. |
| 11 | SKINNING_LOOT | Loot template entry | Item ID | Gates skinning results. |
| 12 | SPELL_LOOT | Loot template entry | Item ID | Gates spell loot. |
| 13 | SPELL_IMPLICIT_TARGET | Effect mask (1/2/4 per effect index) | Spell ID | Filters valid spell targets. |
| 14 | GOSSIP_MENU | Menu ID | Text ID | Controls which gossip text is shown. |
| 15 | GOSSIP_MENU_OPTION | Menu ID | Option ID | Shows/hides gossip option. |
| 16 | CREATURE_TEMPLATE_VEHICLE | 0 | Creature entry | Vehicle ability availability. |
| 17 | SPELL | 0 | Spell ID | Prevents spell cast if condition fails. |
| 18 | SPELL_CLICK_EVENT | Creature entry | Spell ID | Gates spellclick (right-click interaction). |
| 19 | QUEST_AVAILABLE | 0 | Quest ID | Hides quest from player if condition fails. |
| 21 | VEHICLE_SPELL | Creature entry | Spell ID | Gates vehicle ability bar spell. |
| 22 | SMART_EVENT | Smart script ID+1 | EntryOrGuid | Conditions for SmartAI event firing. |
| 23 | NPC_VENDOR | Vendor entry | Item entry | Hides vendor item if condition fails. |
| 24 | SPELL_PROC | 0 | Aura spell ID | Conditions for aura proc to fire. |
| 28 | PLAYER_LOOT_TEMPLATE | Player loot entry | 0 | Player loot conditions. |
| 29 | CREATURE_VISIBILITY | 0 | 0 | Creature visibility conditions. |

### ConditionType Values (All)

| ID | Constant | Value1 | Value2 | Value3 |
|----|----------|--------|--------|--------|
| 0 | CONDITION_NONE | — | — | — |
| 1 | CONDITION_AURA | Spell ID | Effect index (0–2) | 0 |
| 2 | CONDITION_ITEM | Item entry | Count required | 0=bags only, 1=include bank |
| 3 | CONDITION_ITEM_EQUIPPED | Item entry | 0 | 0 |
| 4 | CONDITION_ZONEID | Zone ID | 0 | 0 |
| 5 | CONDITION_REPUTATION_RANK | Faction ID | Rank mask (1=Hated, 2=Hostile, 4=Unfriendly, 8=Neutral, 16=Friendly, 32=Honored, 64=Revered, 128=Exalted) | 0 |
| 6 | CONDITION_TEAM | Team ID (469=Alliance, 67=Horde) | 0 | 0 |
| 7 | CONDITION_SKILL | Skill ID | Required rank | 0 |
| 8 | CONDITION_QUESTREWARDED | Quest ID | 0 | 0 |
| 9 | CONDITION_QUESTTAKEN | Quest ID | 0 | 0 |
| 10 | CONDITION_DRUNKENSTATE | State (0=Sober, 1=Tipsy, 2=Drunk, 3=Smashed) | 0 | 0 |
| 11 | CONDITION_WORLD_STATE | World state index | Expected value | 0 |
| 12 | CONDITION_ACTIVE_EVENT | Event entry (`game_event.eventEntry`) | 0 | 0 |
| 13 | CONDITION_INSTANCE_INFO | Entry (script-specific) | Data value | Type (0=DATA, 1=GUID_DATA, 2=BOSS_STATE, 3=DATA64) |
| 14 | CONDITION_QUEST_NONE | Quest ID (not taken, not rewarded) | 0 | 0 |
| 15 | CONDITION_CLASS | Class mask (bitmask, see AllowableClass) | 0 | 0 |
| 16 | CONDITION_RACE | Race mask (bitmask, see AllowableRace) | 0 | 0 |
| 17 | CONDITION_ACHIEVEMENT | Achievement ID | 0 | 0 |
| 18 | CONDITION_TITLE | Title ID | 0 | 0 |
| 19 | CONDITION_SPAWNMASK | Spawn mask value | 0 | 0 |
| 20 | CONDITION_GENDER | Gender (0=Male, 1=Female, 2=None) | 0 | 0 |
| 21 | CONDITION_UNIT_STATE | UnitState enum value | 0 | 0 |
| 22 | CONDITION_MAPID | Map ID | 0 | 0 |
| 23 | CONDITION_AREAID | Area ID | 0 | 0 |
| 24 | CONDITION_CREATURE_TYPE | Creature type (1=Beast, 2=Dragonkin, etc.) | 0 | 0 |
| 25 | CONDITION_SPELL | Spell ID (player must know the spell) | 0 | 0 |
| 26 | CONDITION_PHASEMASK | Phasemask bitmask | 0 | 0 |
| 27 | CONDITION_LEVEL | Level value | Comparison (0=equal, 1=higher, 2=lower, 3=≥, 4=≤) | 0 |
| 28 | CONDITION_QUEST_COMPLETE | Quest ID (objectives done, not yet rewarded) | 0 | 0 |
| 29 | CONDITION_NEAR_CREATURE | Creature entry | Distance (yards) | 0=alive, 1=dead |
| 30 | CONDITION_NEAR_GAMEOBJECT | GO entry | Distance (yards) | 0=ignore state, 1=Ready, 2=Not Ready |
| 31 | CONDITION_OBJECT_ENTRY_GUID | TypeID (3=UNIT, 4=PLAYER, 5=GO, 7=CORPSE) | Entry (0=any) | GUID (0=any) |
| 32 | CONDITION_TYPE_MASK | TypeMask (8=UNIT, 16=PLAYER, 32=GO, 128=CORPSE) | 0 | 0 |
| 33 | CONDITION_RELATION_TO | Target index | Relation (0=SELF, 1=IN_PARTY, 2=IN_RAID_OR_PARTY, 3=OWNED_BY, 4=PASSENGER_OF, 5=CREATED_BY) | 0 |
| 34 | CONDITION_REACTION_TO | Target index | Rank mask (same as type 5) | 0 |
| 35 | CONDITION_DISTANCE_TO | Target index | Distance (yards) | Comparison (0=equal, 1=higher, 2=lower, 3=≥, 4=≤) |
| 36 | CONDITION_ALIVE | 0 (use NegativeCondition for dead check) | 0 | 0 |
| 37 | CONDITION_HP_VAL | HP value | Comparison | 0 |
| 38 | CONDITION_HP_PCT | Percentage (0–100) | Comparison | 0 |
| 39 | CONDITION_REALM_ACHIEVEMENT | Achievement ID | 0 | 0 |
| 40 | CONDITION_IN_WATER | 0 | 0 | 0 |
| 42 | CONDITION_STAND_STATE | Type (0=exact, 1=any type) | Stand state (0=Standing, 1=Sitting, etc.) | 0 |
| 43 | CONDITION_DAILY_QUEST_DONE | Quest ID | 0 | 0 |
| 44 | CONDITION_CHARMED | 0 | 0 | 0 |
| 45 | CONDITION_PET_TYPE | Pet type mask | 0 | 0 |
| 46 | CONDITION_TAXI | 0 (true if on taxi) | 0 | 0 |
| 47 | CONDITION_QUESTSTATE | Quest ID | State mask (1=Not taken, 2=Complete, 8=In progress, 32=Failed, 64=Rewarded) | 0 |
| 48 | CONDITION_QUEST_OBJECTIVE_PROGRESS | Quest ID | Objective ID | Required progress count |
| 49 | CONDITION_DIFFICULTY_ID | Difficulty ID value | 0 | 0 |
| 101 | CONDITION_QUEST_SATISFY_EXCLUSIVE | Quest ID | 0 | 0 |
| 102 | CONDITION_HAS_AURA_TYPE | Aura type enum value | 0 | 0 |
| 103 | CONDITION_WORLD_SCRIPT | WorldStateCondition enum | State value (0=NONE) | 0 |

### Common Condition Examples

**Gate quest availability (quest 5000) behind completing quest 4999:**
```sql
INSERT INTO conditions
  (SourceTypeOrReferenceId, SourceGroup, SourceEntry, ElseGroup,
   ConditionTypeOrReference, ConditionValue1, Comment)
VALUES
  (19, 0, 5000, 0,
   8, 4999, 'Quest 5000 requires quest 4999 rewarded');
```

**Gate creature loot item (12345) to players on quest (6789):**
```sql
-- This is handled via QuestRequired=1 in creature_loot_template, but conditions
-- allow more complex requirements:
INSERT INTO conditions
  (SourceTypeOrReferenceId, SourceGroup, SourceEntry, ElseGroup,
   ConditionTypeOrReference, ConditionValue1, Comment)
VALUES
  (1, 1000 /*loot template entry*/, 12345 /*item*/, 0,
   9, 6789, 'Only drops if player has quest 6789 in log');
```

**Gate gossip menu option behind reputation:**
```sql
INSERT INTO conditions
  (SourceTypeOrReferenceId, SourceGroup, SourceEntry, ElseGroup,
   ConditionTypeOrReference, ConditionValue1, ConditionValue2, Comment)
VALUES
  (15, 100 /*menu ID*/, 0 /*option ID*/, 0,
   5, 730 /*Undercity faction*/, 32 /*Honored+*/, 'Requires Honored with Undercity');
```

---

## 10. Quest Chain Design Patterns

### Simple Linear Chain

```sql
-- Quest A: no prerequisite
UPDATE quest_template_addon SET PrevQuestId = 0 WHERE ID = 100;

-- Quest B: requires A completed
UPDATE quest_template_addon SET PrevQuestId = 100 WHERE ID = 101;

-- Quest C: requires B completed
UPDATE quest_template_addon SET PrevQuestId = 101 WHERE ID = 102;
```

### Auto-chaining via RewardNextQuest

Use `quest_template.RewardNextQuest` to make the follow-up quest instantly appear at turn-in without the player needing to click again:

```sql
UPDATE quest_template SET RewardNextQuest = 101 WHERE ID = 100;
```

### Branching Quest (Choose Alliance or Horde Path)

```sql
-- Both 200 and 201 have the same PrevQuestId (100) and same ExclusiveGroup
-- Completing either one prevents the other
UPDATE quest_template_addon SET PrevQuestId = 100, ExclusiveGroup = 50 WHERE ID = 200;
UPDATE quest_template_addon SET PrevQuestId = 100, ExclusiveGroup = 50 WHERE ID = 201;

-- Quest 202 requires whichever branch was completed
-- Set PrevQuestId on 202 to the first branch quest; the core handles exclusive groups
```

### Daily Quest Setup

```sql
UPDATE quest_template SET Flags = Flags | 4096 WHERE ID = 300; -- QUEST_FLAGS_DAILY

-- NPC must offer it
INSERT IGNORE INTO creature_questrelation (id, quest) VALUES (12345, 300);
INSERT IGNORE INTO creature_involvedrelation (id, quest) VALUES (12345, 300);
```

### Repeatable (Infinite) Quest

```sql
-- SpecialFlags=1 (REPEATABLE) in quest_template_addon
UPDATE quest_template_addon SET SpecialFlags = 1 WHERE ID = 400;
```

The player can turn in and re-accept the quest immediately. The `character_queststatus_rewarded` record is deleted on each turn-in for repeatable quests.

### Timed Quest

```sql
-- 30 minute time limit (1800 seconds)
UPDATE quest_template SET TimeAllowed = 1800 WHERE ID = 500;
-- Set Flags |= 1 (STAY_ALIVE) if death should fail the quest
UPDATE quest_template SET Flags = Flags | 1 WHERE ID = 500;
```

### Escort Quest Pattern

1. Set `Flags & QUEST_FLAGS_PARTY_ACCEPT (2)`.
2. Create a SmartAI waypoint escort for the escort NPC.
3. Use `QuestScript::OnQuestAccept` to summon the escort NPC near the player.
4. At escort completion, call `player->KilledMonsterCredit(ESCORT_CREDIT_ENTRY)` to grant objective credit.

### Exploration Quest Pattern

```sql
-- Quest uses QUEST_FLAGS_EXPLORATION (4)
UPDATE quest_template SET Flags = Flags | 4 WHERE ID = 600;

-- AreaTrigger 888 completes quest 600
INSERT INTO areatrigger_involvedrelation (id, quest) VALUES (888, 600);
```

---

## 11. Cross-References

| Topic | Location |
|-------|----------|
| Quest givers (NPC side) | `creature_questrelation`, `creature_involvedrelation` |
| GO quest givers | `gameobject_questrelation`, `gameobject_involvedrelation` |
| Exploration triggers | `areatrigger_involvedrelation` |
| Quest item drops | `creature_loot_template.QuestRequired = 1` |
| Quest chain fields | `quest_template_addon` |
| Quest status storage | `character_queststatus`, `character_queststatus_rewarded`, `character_queststatus_daily` |
| Conditions system | `conditions` table (§9 above) |
| Item started quests | `item_template.startquest` |
| Starting items | `quest_template.StartItem` |
| SmartAI quest events | `kb_azerothcore_dev.md` — SMART_EVENT_ACCEPTED_QUEST, SMART_EVENT_REWARDED_QUEST |
| Eluna quest hooks | `kb_eluna_api.md` — PLAYER_EVENT_ON_QUEST_ACCEPT, PLAYER_EVENT_ON_QUEST_REWARD |
| Item system | `06_item_system.md` |
