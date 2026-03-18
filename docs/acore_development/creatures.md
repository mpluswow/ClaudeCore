# Creature System

Complete reference for creature templates, spawning, AI, vendors, trainers, gossip, and boss mechanics in AzerothCore (WotLK 3.3.5a).

---

## Table of Contents

1. [creature_template Table](#creature_template-table)
2. [npcflag Bitmask](#npcflag-bitmask)
3. [unit_flags Bitmask](#unit_flags-bitmask)
4. [unit_flags2 Bitmask](#unit_flags2-bitmask)
5. [dynamicflags Bitmask](#dynamicflags-bitmask)
6. [type_flags Bitmask](#type_flags-bitmask)
7. [flags_extra Bitmask](#flags_extra-bitmask)
8. [mechanic_immune_mask Bitmask](#mechanic_immune_mask-bitmask)
9. [spell_school_immune_mask Bitmask](#spell_school_immune_mask-bitmask)
10. [Creature AI System](#creature-ai-system)
11. [Creature Spawning & Lifecycle](#creature-spawning--lifecycle)
12. [creature_addon Table](#creature_addon-table)
13. [Waypoint System](#waypoint-system)
14. [Creature Stats & Scaling](#creature-stats--scaling)
15. [Vendor Setup](#vendor-setup)
16. [Trainer Setup](#trainer-setup)
17. [Gossip System](#gossip-system)
18. [Boss Mechanics](#boss-mechanics)
19. [Cross-References](#cross-references)

---

## creature_template Table

Every spawned creature references a `creature_template` row. Columns marked **override-able** can be overridden per-spawn in the `creature` table.

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `entry` | MEDIUMINT UNSIGNED | PRI | Unique template ID. Referenced everywhere as creature entry. |
| `difficulty_entry_1` | MEDIUMINT UNSIGNED | 0 | Template entry used on difficulty 1 (Heroic / 25-man). 0 = same as base. |
| `difficulty_entry_2` | MEDIUMINT UNSIGNED | 0 | Template entry used on difficulty 2. |
| `difficulty_entry_3` | MEDIUMINT UNSIGNED | 0 | Template entry used on difficulty 3. |
| `KillCredit1` | INT UNSIGNED | 0 | Alternate creature entry that grants quest kill-credit for this creature. |
| `KillCredit2` | INT UNSIGNED | 0 | Second alternate quest kill-credit entry. |
| `name` | char(100) | — | Display name shown over creature. |
| `subname` | char(100) | NULL | Subtitle in angle brackets (e.g., `<Innkeeper>`). |
| `IconName` | char(100) | NULL | Cursor icon hint: `Directions`, `Speak`, `Buy`, `Repair`, `Attack`, `Taxi`, etc. |
| `gossip_menu_id` | MEDIUMINT UNSIGNED | 0 | Links to `gossip_menu.MenuID`. |
| `minlevel` | TINYINT UNSIGNED | 1 | Minimum creature level. Set equal to `maxlevel` for a fixed level. |
| `maxlevel` | TINYINT UNSIGNED | 1 | Maximum creature level. Core picks random value in [min,max] on spawn. |
| `exp` | SMALLINT | 0 | Expansion tier: 0=Classic, 1=TBC, 2=WotLK. Affects stat scaling tables. |
| `faction` | SMALLINT UNSIGNED | 0 | Faction template ID from `FactionTemplate.dbc`. Controls hostile/friendly behavior and guards calling-for-help. |
| `npcflag` | INT UNSIGNED | 0 | NPC interaction bitmask. See [npcflag Bitmask](#npcflag-bitmask). **Override-able.** |
| `speed_walk` | FLOAT | 1.0 | Walk speed multiplier (base = 2.5 yards/sec). |
| `speed_run` | FLOAT | 1.14286 | Run speed multiplier (base = 7.0 yards/sec for humanoids). |
| `speed_swim` | FLOAT | 1.0 | Swim speed multiplier. |
| `speed_flight` | FLOAT | 1.0 | Flight speed multiplier. |
| `detection_range` | FLOAT | 20.0 | Detection radius in yards for line-of-sight aggro. |
| `scale` | FLOAT | 1.0 | Model size multiplier. 0 = use DBC default. |
| `rank` | TINYINT UNSIGNED | 0 | 0=Normal, 1=Elite, 2=Rare Elite, 3=Boss, 4=Rare. Affects health/XP. |
| `dmgschool` | TINYINT | 0 | Melee damage school: 0=Physical, 1=Holy, 2=Fire, 3=Nature, 4=Frost, 5=Shadow, 6=Arcane. |
| `BaseAttackTime` | INT UNSIGNED | 2000 | Melee swing timer in milliseconds. |
| `RangeAttackTime` | INT UNSIGNED | 2000 | Ranged attack timer in milliseconds. |
| `BaseVariance` | FLOAT | 1.0 | Melee damage variance multiplier (±%). |
| `RangeVariance` | FLOAT | 1.0 | Ranged damage variance multiplier. |
| `unit_class` | TINYINT UNSIGNED | 0 | Class for stat lookup: 1=Warrior, 2=Paladin, 4=Rogue, 8=Mage. |
| `unit_flags` | INT UNSIGNED | 0 | Unit behavior flags. See [unit_flags Bitmask](#unit_flags-bitmask). **Override-able.** |
| `unit_flags2` | INT UNSIGNED | 0 | Extended unit flags. See [unit_flags2 Bitmask](#unit_flags2-bitmask). |
| `dynamicflags` | INT UNSIGNED | 0 | Visual state flags. See [dynamicflags Bitmask](#dynamicflags-bitmask). **Override-able.** |
| `family` | TINYINT | 0 | Pet family ID from `CreatureFamily.dbc` (1=Wolf, 2=Cat, 26=Owl, 45=Core Hound, etc.). 0 = not a pet. |
| `type` | TINYINT UNSIGNED | 0 | Creature type: 1=Beast, 2=Dragonkin, 3=Demon, 4=Elemental, 5=Giant, 6=Undead, 7=Humanoid, 8=Critter, 9=Mechanical, 10=Not specified, 11=Totem, 12=Non-combat pet, 14=Gas Cloud. |
| `type_flags` | INT UNSIGNED | 0 | Type capability bitmask. See [type_flags Bitmask](#type_flags-bitmask). |
| `lootid` | MEDIUMINT UNSIGNED | 0 | Links to `creature_loot_template.Entry`. 0 = no drops. |
| `pickpocketloot` | MEDIUMINT UNSIGNED | 0 | Links to `pickpocketing_loot_template.Entry`. |
| `skinloot` | MEDIUMINT UNSIGNED | 0 | Links to `skinning_loot_template.Entry`. |
| `PetSpellDataId` | MEDIUMINT UNSIGNED | 0 | `CreatureSpellData.dbc` ID defining pet action bar spells. |
| `VehicleId` | MEDIUMINT UNSIGNED | 0 | Vehicle template ID from `Vehicle.dbc`. 0 = not a vehicle. |
| `mingold` | MEDIUMINT UNSIGNED | 0 | Minimum gold drop in copper (100 copper = 1 silver, 10000 = 1 gold). |
| `maxgold` | MEDIUMINT UNSIGNED | 0 | Maximum gold drop in copper. |
| `AIName` | char(64) | '' | Built-in AI class name. See [AIName values](#ainame-values). |
| `MovementType` | TINYINT UNSIGNED | 0 | Default movement: 0=Idle, 1=Random wander, 2=Waypoint. |
| `HoverHeight` | FLOAT | 1.0 | Hover altitude in yards when gravity-disabled (flight). |
| `HealthModifier` | FLOAT | 1.0 | Multiplier applied to base HP from CreatureClassLevelStats. |
| `ManaModifier` | FLOAT | 1.0 | Multiplier applied to base mana. |
| `ArmorModifier` | FLOAT | 1.0 | Multiplier applied to base armor. |
| `DamageModifier` | FLOAT | 1.0 | Multiplier applied to base damage. |
| `ExperienceModifier` | FLOAT | 1.0 | Multiplier applied to XP reward. |
| `RacialLeader` | TINYINT UNSIGNED | 0 | 1 = racial leader; killing grants 100 PvP honor regardless of level. |
| `movementId` | INT UNSIGNED | 0 | `CreatureMovementInfo.dbc` ID; movement flags sent to client. |
| `RegenHealth` | TINYINT UNSIGNED | 1 | 1 = health regens when out of combat; 0 = no regen (static boss HP). |
| `mechanic_immune_mask` | INT UNSIGNED | 0 | Bitmask of immune spell mechanics. See [mechanic_immune_mask](#mechanic_immune_mask-bitmask). |
| `spell_school_immune_mask` | INT UNSIGNED | 0 | Bitmask of immune spell schools. See [spell_school_immune_mask](#spell_school_immune_mask-bitmask). |
| `flags_extra` | INT UNSIGNED | 0 | Miscellaneous server-side creature flags. See [flags_extra Bitmask](#flags_extra-bitmask). |
| `ScriptName` | char(64) | '' | C++ CreatureScript name registered with `RegisterCreatureScript`. |
| `VerifiedBuild` | SMALLINT | 0 | WDB build verification: -1=placeholder, 0=unverified, >0=verified build. |

### AIName Values

| AIName | Description |
|--------|-------------|
| *(empty string)* | Default reactive AI: attacks players in range. |
| `NullCreatureAI` | No AI. Creature stands still and does nothing. Useful for display creatures. |
| `AggressorAI` | Standard aggressor; attacks anything hostile in range. |
| `ReactorAI` | Attacks only when attacked first. |
| `GuardAI` | Town guard AI; calls assistance and chases criminals. |
| `PetAI` | Used by player-owned pets. Manages follow/attack/passive states. |
| `TotemAI` | Used by player-summoned totems. Minimal movement. |
| `CombatAI` | Casts spells from `creature_template_spell` on a timer. |
| `SmartAI` | Data-driven AI configured via `smart_scripts` table. Preferred for complex logic. |
| `EventAI` | Legacy event-driven AI from `creature_ai_scripts`. Mostly superseded by SmartAI. |

### ScriptName

When `ScriptName` is set (e.g., `boss_onyxia`), the core looks up a `CreatureScript` registered via:

```cpp
void AddSC_boss_onyxia()
{
    RegisterCreatureScript(boss_onyxia);
}
```

The `AddSC_*` function must be called from a module's `Loader.cpp`. `ScriptName` takes precedence over `AIName` — if a C++ script is found, `AIName` is ignored.

---

## npcflag Bitmask

Controls which interaction icons appear and which server-side behaviors are active. Multiple flags combine by addition (e.g., Gossip + Vendor = 1 + 128 = 129).

| Flag Name | Decimal | Hex | Description |
|-----------|---------|-----|-------------|
| UNIT_NPC_FLAG_NONE | 0 | 0x00000000 | No special NPC interaction. |
| UNIT_NPC_FLAG_GOSSIP | 1 | 0x00000001 | Shows speech bubble; opens gossip dialog. |
| UNIT_NPC_FLAG_QUESTGIVER | 2 | 0x00000002 | Shows quest icon; can give/complete quests. |
| UNIT_NPC_FLAG_UNK1 | 4 | 0x00000004 | Unknown / unused. |
| UNIT_NPC_FLAG_UNK2 | 8 | 0x00000008 | Unknown / unused. |
| UNIT_NPC_FLAG_TRAINER | 16 | 0x00000010 | Opens trainer window with learnable spells. |
| UNIT_NPC_FLAG_TRAINER_CLASS | 32 | 0x00000020 | Class-specific trainer (uses same window). |
| UNIT_NPC_FLAG_TRAINER_PROFESSION | 64 | 0x00000040 | Profession trainer. |
| UNIT_NPC_FLAG_VENDOR | 128 | 0x00000080 | Opens vendor buy/sell window. |
| UNIT_NPC_FLAG_VENDOR_AMMO | 256 | 0x00000100 | Ammo vendor sub-type. |
| UNIT_NPC_FLAG_VENDOR_FOOD | 512 | 0x00000200 | Food vendor sub-type. |
| UNIT_NPC_FLAG_VENDOR_POISON | 1024 | 0x00000400 | Poison vendor sub-type (Rogue). |
| UNIT_NPC_FLAG_VENDOR_REAGENT | 2048 | 0x00000800 | Reagent vendor sub-type. |
| UNIT_NPC_FLAG_REPAIRER | 4096 | 0x00001000 | Can repair items. |
| UNIT_NPC_FLAG_FLIGHTMASTER | 8192 | 0x00002000 | Opens flight-path taxi map. |
| UNIT_NPC_FLAG_SPIRITHEALER | 16384 | 0x00004000 | Ghost resurrection NPC. |
| UNIT_NPC_FLAG_SPIRITGUIDE | 32768 | 0x00008000 | Spirit guide in graveyard. |
| UNIT_NPC_FLAG_INNKEEPER | 65536 | 0x00010000 | Sets hearthstone bind point. |
| UNIT_NPC_FLAG_BANKER | 131072 | 0x00020000 | Opens bank window. |
| UNIT_NPC_FLAG_PETITIONER | 262144 | 0x00040000 | Guild/arena charter petitioner. |
| UNIT_NPC_FLAG_TABARDDESIGNER | 524288 | 0x00080000 | Opens guild tabard designer. |
| UNIT_NPC_FLAG_BATTLEMASTER | 1048576 | 0x00100000 | Queues player for battleground. |
| UNIT_NPC_FLAG_AUCTIONEER | 2097152 | 0x00200000 | Opens auction house. |
| UNIT_NPC_FLAG_STABLEMASTER | 4194304 | 0x00400000 | Opens pet stable window. |
| UNIT_NPC_FLAG_GUILD_BANKER | 8388608 | 0x00800000 | Opens guild bank. |
| UNIT_NPC_FLAG_SPELLCLICK | 16777216 | 0x01000000 | Triggers `npc_spellclick_spells` on right-click (vehicle boarding, etc.). |
| UNIT_NPC_FLAG_PLAYER_VEHICLE | 33554432 | 0x02000000 | NPC is a player vehicle mount. |
| UNIT_NPC_FLAG_MAILBOX | 67108864 | 0x04000000 | Opens mailbox. |

**Common combinations:**

```sql
-- Generic gossip vendor that also repairs
UPDATE creature_template SET npcflag = 1+128+4096 WHERE entry = 12345;
-- = 4225

-- Questgiver and vendor
UPDATE creature_template SET npcflag = 2+128 WHERE entry = 12346;
-- = 130
```

---

## unit_flags Bitmask

Controls fundamental unit behavior and visibility. Set in `creature_template.unit_flags`.

| Flag Name | Decimal | Hex | Description |
|-----------|---------|-----|-------------|
| UNIT_FLAG_SERVER_CONTROLLED | 1 | 0x00000001 | Unit is under server control (set automatically). |
| UNIT_FLAG_NON_ATTACKABLE | 2 | 0x00000002 | Cannot be attacked. Does not prevent auto-attack initiation by the unit itself. |
| UNIT_FLAG_DISABLE_MOVE | 4 | 0x00000004 | Prevents movement entirely. |
| UNIT_FLAG_PVP_ATTACKABLE | 8 | 0x00000008 | Can be attacked in PvP. |
| UNIT_FLAG_RENAME | 16 | 0x00000010 | Can be renamed (used for pets). |
| UNIT_FLAG_PREPARATION | 32 | 0x00000020 | PvP preparation state. |
| UNIT_FLAG_UNK_6 | 64 | 0x00000040 | Unknown. |
| UNIT_FLAG_NOT_ATTACKABLE_1 | 128 | 0x00000080 | Not attackable flag variant. |
| UNIT_FLAG_IMMUNE_TO_PC | 256 | 0x00000100 | Immune to attacks from players. |
| UNIT_FLAG_IMMUNE_TO_NPC | 512 | 0x00000200 | Immune to attacks from NPCs. |
| UNIT_FLAG_LOOTING | 1024 | 0x00000400 | Creature is being looted. |
| UNIT_FLAG_PET_IN_COMBAT | 2048 | 0x00000800 | Pet is in combat. |
| UNIT_FLAG_PVP | 4096 | 0x00001000 | Flagged for PvP. |
| UNIT_FLAG_SILENCED | 8192 | 0x00002000 | Cannot cast spells. |
| UNIT_FLAG_CANNOT_SWIM | 16384 | 0x00004000 | Unit will not enter water. |
| UNIT_FLAG_UNK_15 | 32768 | 0x00008000 | Unknown. |
| UNIT_FLAG_NON_ATTACKABLE_2 | 65536 | 0x00010000 | Not attackable; does not react to combat. |
| UNIT_FLAG_PACIFIED | 131072 | 0x00020000 | Cannot auto-attack but can cast. |
| UNIT_FLAG_STUNNED | 262144 | 0x00040000 | Stunned state. |
| UNIT_FLAG_IN_COMBAT | 524288 | 0x00080000 | Currently in combat. |
| UNIT_FLAG_TAXI_FLIGHT | 1048576 | 0x00100000 | On taxi/flight path. |
| UNIT_FLAG_DISARMED | 2097152 | 0x00200000 | Cannot use melee weapons. |
| UNIT_FLAG_CONFUSED | 4194304 | 0x00400000 | Confused movement state. |
| UNIT_FLAG_FLEEING | 8388608 | 0x00800000 | Running away (fear). |
| UNIT_FLAG_PLAYER_CONTROLLED | 16777216 | 0x01000000 | Under player control (mind control, charm). |
| UNIT_FLAG_NOT_SELECTABLE | 33554432 | 0x02000000 | Cannot be targeted or selected by players. |
| UNIT_FLAG_SKINNABLE | 67108864 | 0x04000000 | Can be skinned after death. |
| UNIT_FLAG_MOUNT | 134217728 | 0x08000000 | Visual mount state. |
| UNIT_FLAG_UNK_28 | 268435456 | 0x10000000 | Unknown. |
| UNIT_FLAG_PREVENT_EMOTES_FROM_CHAT_TEXT | 536870912 | 0x20000000 | Suppresses emote text. |
| UNIT_FLAG_SHEATHE | 1073741824 | 0x40000000 | Weapon sheathed. |

**Common combinations for quest/event creatures:**
```sql
-- Completely passive display NPC (no attack, no select)
unit_flags = 2 + 33554432  -- = 33554434

-- Immune to all player attacks during event
unit_flags = 256  -- IMMUNE_TO_PC
```

---

## unit_flags2 Bitmask

Extended flags introduced in WotLK.

| Flag Name | Decimal | Hex | Description |
|-----------|---------|-----|-------------|
| UNIT_FLAG2_FEIGN_DEATH | 1 | 0x00000001 | Visual feign death state. |
| UNIT_FLAG2_UNK1 | 2 | 0x00000002 | Unknown. |
| UNIT_FLAG2_IGNORE_REPUTATION | 4 | 0x00000004 | Ignore faction reputation for interaction. |
| UNIT_FLAG2_COMPREHEND_LANG | 8 | 0x00000008 | Understands all languages. |
| UNIT_FLAG2_MIRROR_IMAGE | 16 | 0x00000010 | Is a mirror image. |
| UNIT_FLAG2_INSTANTLY_APPEAR_MODEL | 32 | 0x00000020 | Skips spawn-in animation. |
| UNIT_FLAG2_FORCE_MOVEMENT | 64 | 0x00000040 | Force movement (used by vehicles). |
| UNIT_FLAG2_DISARM_OFFHAND | 128 | 0x00000080 | Off-hand weapon disarmed. |
| UNIT_FLAG2_DISABLE_PRED_STATS | 256 | 0x00000100 | Disables predicted stats display. |
| UNIT_FLAG2_DISARM_RANGED | 1024 | 0x00000400 | Ranged weapon disarmed. |
| UNIT_FLAG2_REGENERATE_POWER | 2048 | 0x00000800 | Regenerates power (mana/rage/energy). |
| UNIT_FLAG2_RESTRICT_PARTY_INTERACTION | 4096 | 0x00001000 | Can only interact with party members. |
| UNIT_FLAG2_PREVENT_SPELL_CLICK | 8192 | 0x00002000 | Blocks spellclick interaction. |
| UNIT_FLAG2_ALLOW_ENEMY_INTERACT | 16384 | 0x00004000 | Allows hostile players to interact. |
| UNIT_FLAG2_CANNOT_TURN | 32768 | 0x00008000 | Cannot rotate to face targets. |
| UNIT_FLAG2_UNK2 | 65536 | 0x00010000 | Unknown. |
| UNIT_FLAG2_PLAY_DEATH_ANIM | 131072 | 0x00020000 | Plays death animation instead of corpse. |
| UNIT_FLAG2_ALLOW_CHEAT_SPELLS | 262144 | 0x00040000 | Allows GM/cheat spells to be cast. |

---

## dynamicflags Bitmask

Controls runtime visual state visible to clients. **Override-able** per spawn.

| Flag Name | Decimal | Hex | Description |
|-----------|---------|-----|-------------|
| UNIT_DYNFLAG_NONE | 0 | 0x00000000 | Normal state. |
| UNIT_DYNFLAG_LOOTABLE | 1 | 0x00000001 | Shows loot sparkle; allows looting. |
| UNIT_DYNFLAG_TRACK_UNIT | 2 | 0x00000002 | Arrow tracking indicator. |
| UNIT_DYNFLAG_TAPPED | 4 | 0x00000004 | Gray nameplate; already tagged by another player. |
| UNIT_DYNFLAG_TAPPED_BY_PLAYER | 8 | 0x00000008 | Tagged by the local player. |
| UNIT_DYNFLAG_SPECIALINFO | 16 | 0x00000010 | Shows special tooltip info. |
| UNIT_DYNFLAG_DEAD | 32 | 0x00000020 | Dead visual state (lying down, despawning). |
| UNIT_DYNFLAG_REFER_A_FRIEND | 64 | 0x00000040 | RAF bonus indicator. |
| UNIT_DYNFLAG_TAPPED_BY_ALL_THREAT_LIST | 128 | 0x00000080 | Tapped by everyone on threat list. |

---

## type_flags Bitmask

Capability and classification flags for the creature type.

| Flag Name | Decimal | Hex | Description |
|-----------|---------|-----|-------------|
| CREATURE_TYPE_FLAG_TAMEABLE_PET | 1 | 0x00000001 | Can be tamed by a Hunter. |
| CREATURE_TYPE_FLAG_GHOST_VISIBLE | 2 | 0x00000002 | Visible to ghosts/spirit healers. |
| CREATURE_TYPE_FLAG_BOSS_MOB | 4 | 0x00000004 | Immune to flee; no leash. |
| CREATURE_TYPE_FLAG_DO_NOT_PLAY_WOUND_PARRY_ANIMATION | 8 | 0x00000008 | Suppresses wound parry anim. |
| CREATURE_TYPE_FLAG_HIDE_FACTION_TOOLTIP | 16 | 0x00000010 | Hides faction name in tooltip. |
| CREATURE_TYPE_FLAG_SPELL_ATTACKABLE | 32 | 0x00000020 | Can be hit by certain spell types. |
| CREATURE_TYPE_FLAG_CAN_INTERACT_WHILE_DEAD | 64 | 0x00000040 | Interactable while in dead state. |
| CREATURE_TYPE_FLAG_HERB_SKINNING_SKILL | 128 | 0x00000080 | Requires herbalism to skin. |
| CREATURE_TYPE_FLAG_MINING_SKINNING_SKILL | 256 | 0x00000100 | Requires mining to skin. |
| CREATURE_TYPE_FLAG_DO_NOT_LOG_DEATH | 512 | 0x00000200 | Suppresses death logging. |
| CREATURE_TYPE_FLAG_MOUNTED_COMBAT_ALLOWED | 1024 | 0x00000400 | Player can attack while mounted. |
| CREATURE_TYPE_FLAG_CAN_ASSIST | 2048 | 0x00000800 | Can assist allied creatures. |
| CREATURE_TYPE_FLAG_IS_PET_BAR_USED | 4096 | 0x00001000 | Shows pet action bar for this creature. |
| CREATURE_TYPE_FLAG_MASK_UID | 8192 | 0x00002000 | Masks creature UID in combat log. |
| CREATURE_TYPE_FLAG_ENGINEERING_SKINNING_SKILL | 16384 | 0x00004000 | Requires engineering to skin. |
| CREATURE_TYPE_FLAG_EXOTIC_PET | 32768 | 0x00008000 | Requires Beast Mastery talent to tame. |

---

## flags_extra Bitmask

Server-side behavioral modifiers not sent to the client.

| Flag Name | Decimal | Hex | Description |
|-----------|---------|-----|-------------|
| CREATURE_FLAG_EXTRA_INSTANCE_BIND | 1 | 0x00000001 | Binds players to instance on aggro. |
| CREATURE_FLAG_EXTRA_CIVILIAN | 2 | 0x00000002 | Civilian; guards will assist if attacked. |
| CREATURE_FLAG_EXTRA_NO_PARRY | 4 | 0x00000004 | Cannot parry. |
| CREATURE_FLAG_EXTRA_NO_PARRY_HASTEN | 8 | 0x00000008 | Parry does not accelerate attack. |
| CREATURE_FLAG_EXTRA_NO_BLOCK | 16 | 0x00000010 | Cannot block. |
| CREATURE_FLAG_EXTRA_NO_CRUSH | 32 | 0x00000020 | Cannot crush (no crushing blow). |
| CREATURE_FLAG_EXTRA_NO_XP_AT_KILL | 64 | 0x00000040 | Grants no XP on kill. |
| CREATURE_FLAG_EXTRA_TRIGGER | 128 | 0x00000080 | Invisible trigger creature; no combat. |
| CREATURE_FLAG_EXTRA_NO_TAUNT | 256 | 0x00000100 | Immune to taunt effects. |
| CREATURE_FLAG_EXTRA_WORLDEVENT | 512 | 0x00000200 | World event creature; no aggro. |
| CREATURE_FLAG_EXTRA_GUARD | 1024 | 0x00000400 | City guard; assists nearby civilians. |
| CREATURE_FLAG_EXTRA_NO_CRIT | 131072 | 0x00020000 | Cannot land critical hits. |
| CREATURE_FLAG_EXTRA_NO_SKILLGAIN | 262144 | 0x00040000 | Killing does not grant weapon skill. |
| CREATURE_FLAG_EXTRA_TAUNT_DIMINISH | 524288 | 0x00080000 | Taunt has diminishing returns. |
| CREATURE_FLAG_EXTRA_ALL_DIMINISH | 1048576 | 0x00100000 | All CC has diminishing returns. |
| CREATURE_FLAG_EXTRA_NO_PLAYER_DAMAGE_REQ | 2097152 | 0x00200000 | No player damage required for loot/XP. |
| CREATURE_FLAG_EXTRA_MODULE | 16777216 | 0x01000000 | Reserved for module use. |
| CREATURE_FLAG_EXTRA_DONT_CALL_ASSISTANCE | 33554432 | 0x02000000 | Will not call nearby creatures for help. |
| CREATURE_FLAG_EXTRA_IGNORE_FEIGN_DEATH | 67108864 | 0x04000000 | Ignores player feign death. |
| CREATURE_FLAG_EXTRA_IMMUNITY_KNOCKBACK | 1073741824 | 0x40000000 | Immune to knockback effects. |

---

## mechanic_immune_mask Bitmask

Controls which CC mechanic types the creature is immune to. The values below are the **bit positions** (1 << N); combine with OR/addition.

| Mechanic Name | Decimal | Hex | Description |
|---------------|---------|-----|-------------|
| MECHANIC_NONE | 1 | 0x00000001 | No mechanic (generic immunity). |
| MECHANIC_CHARM | 2 | 0x00000002 | Immune to charm/mind control. |
| MECHANIC_DISORIENTED | 4 | 0x00000004 | Immune to disorientation. |
| MECHANIC_DISARM | 8 | 0x00000008 | Immune to disarm. |
| MECHANIC_DISTRACT | 16 | 0x00000010 | Immune to distractions. |
| MECHANIC_FEAR | 32 | 0x00000020 | Immune to fear effects. |
| MECHANIC_GRIP | 64 | 0x00000040 | Immune to Death Grip. |
| MECHANIC_ROOT | 128 | 0x00000080 | Immune to root effects. |
| MECHANIC_SLOW_ATTACK | 256 | 0x00000100 | Immune to attack speed slow. |
| MECHANIC_SILENCE | 512 | 0x00000200 | Immune to silence. |
| MECHANIC_SLEEP | 1024 | 0x00000400 | Immune to sleep. |
| MECHANIC_SNARE | 2048 | 0x00000800 | Immune to movement snares. |
| MECHANIC_STUN | 4096 | 0x00001000 | Immune to stun. |
| MECHANIC_FREEZE | 8192 | 0x00002000 | Immune to freeze (e.g., Frost Nova). |
| MECHANIC_KNOCKOUT | 16384 | 0x00004000 | Immune to knockout. |
| MECHANIC_BLEED | 32768 | 0x00008000 | Immune to bleed effects. |
| MECHANIC_BANDAGE | 65536 | 0x00010000 | Immune to bandage. |
| MECHANIC_POLYMORPH | 131072 | 0x00020000 | Immune to polymorph. |
| MECHANIC_BANISH | 262144 | 0x00040000 | Immune to banish. |
| MECHANIC_SHIELD | 524288 | 0x00080000 | Immune to shield effects. |
| MECHANIC_SHACKLE | 1048576 | 0x00100000 | Immune to shackle undead. |
| MECHANIC_MOUNT | 2097152 | 0x00200000 | Immune to mount effects. |
| MECHANIC_PERSUADE | 4194304 | 0x00400000 | Immune to persuade. |
| MECHANIC_TURN | 8388608 | 0x00800000 | Immune to turn undead. |
| MECHANIC_HORROR | 16777216 | 0x01000000 | Immune to horror. |
| MECHANIC_INVULNERABILITY | 33554432 | 0x02000000 | Immune to invulnerability effects. |
| MECHANIC_INTERRUPT | 67108864 | 0x04000000 | Immune to spell interrupt. |
| MECHANIC_DAZE | 134217728 | 0x08000000 | Immune to daze. |
| MECHANIC_DISCOVERY | 268435456 | 0x10000000 | Immune to discovery effects. |
| MECHANIC_IMMUNE_SHIELD | 536870912 | 0x20000000 | Divine shield-type immunity. |
| MECHANIC_SAPPED | 1073741824 | 0x40000000 | Immune to sap. |

**Example — fully CC-immune boss:**
```sql
-- Immune to stun + fear + root + polymorph + charm + silence
UPDATE creature_template SET mechanic_immune_mask = 4096+32+128+131072+2+512 WHERE entry = 99999;
-- = 135842
```

---

## spell_school_immune_mask Bitmask

| School | Decimal | Hex | Description |
|--------|---------|-----|-------------|
| SPELL_SCHOOL_MASK_NORMAL | 1 | 0x01 | Physical damage immunity. |
| SPELL_SCHOOL_MASK_HOLY | 2 | 0x02 | Holy school immunity. |
| SPELL_SCHOOL_MASK_FIRE | 4 | 0x04 | Fire school immunity. |
| SPELL_SCHOOL_MASK_NATURE | 8 | 0x08 | Nature school immunity. |
| SPELL_SCHOOL_MASK_FROST | 16 | 0x10 | Frost school immunity. |
| SPELL_SCHOOL_MASK_SHADOW | 32 | 0x20 | Shadow school immunity. |
| SPELL_SCHOOL_MASK_ARCANE | 64 | 0x40 | Arcane school immunity. |

---

## Creature AI System

### AI Class Hierarchy

```
UnitAI                          (abstract base)
└── CreatureAI                  (creature-specific base; has Creature* me)
    ├── NullCreatureAI          (AIName = "NullCreatureAI"; does nothing)
    ├── TriggerAI               (invisible trigger objects)
    ├── ReactorAI               (AIName = "ReactorAI"; counter-attacks only)
    ├── AggressorAI             (AIName = "AggressorAI"; attacks in range)
    ├── GuardAI                 (AIName = "GuardAI"; city guard behavior)
    ├── PetAI                   (AIName = "PetAI"; player pet logic)
    ├── TotemAI                 (AIName = "TotemAI"; player totems)
    └── ScriptedAI              (base for custom C++ scripts)
        ├── BossAI              (ScriptedAI + InstanceScript ptr + SummonList)
        ├── SmartAI             (AIName = "SmartAI"; data-driven)
        └── EventAI             (AIName = "EventAI"; legacy data-driven)
```

### SmartAI vs EventAI vs CreatureScript

| Approach | When to Use | Configured In |
|----------|-------------|---------------|
| **SmartAI** | Complex NPCs, questgivers, event NPCs, simple bosses. No recompile needed. | `smart_scripts` table |
| **EventAI** | Legacy content migration only. Avoid for new work. | `creature_ai_scripts` table |
| **CreatureScript** | Progression bosses, custom mechanics, anything needing precise C++ control. | `.cpp` module file |
| **AllCreatureScript** | Server-wide hooks that must fire for every creature (e.g., analytics, custom death logging). | `.cpp` module file |

### CreatureAI Virtual Methods

All methods below are virtual; override in your `CreatureScript` subclass. The most important ones are listed first.

```cpp
// --- Core combat lifecycle ---
void JustEngagedWith(Unit* who);        // First hostile action against creature
void Reset();                           // Called on evade/respawn; reset all state here
void EnterEvadeMode(EvadeReason why);   // Combat dropped; creature returns to spawn
void JustDied(Unit* killer);            // After death; award loot, fire events
void KilledUnit(Unit* victim);          // Creature killed another unit

// --- Spawn/summon lifecycle ---
void JustRespawned();                   // After respawn from DB
void JustSummoned(Creature* summon);    // This creature summoned another
void IsSummonedBy(WorldObject* summoner); // This creature was summoned
void SummonedCreatureDies(Creature* summon, Unit* killer);
void SummonedCreatureDespawn(Creature* summon);

// --- Spell hooks ---
void SpellHit(Unit* caster, SpellInfo const* spell);        // Spell landed on this creature
void SpellHitTarget(Unit* target, SpellInfo const* spell);  // This creature's spell hit target
void OnSpellCast(SpellInfo const* spell);
void OnSpellFailed(SpellInfo const* spell);
void OnChannelFinished(SpellInfo const* spell);

// --- Movement hooks ---
void MovementInform(uint32 movementType, uint32 id); // Waypoint/charge/path reached
void MoveInLineOfSight(Unit* who);      // Unit entered detection range

// --- Periodic update ---
void UpdateAI(uint32 diff);             // Called every world tick; main AI loop

// --- Damage ---
void DamageTaken(Unit* attacker, uint32& damage, DamageEffectType, SpellSchoolMask);
void HealReceived(Unit* healer, uint32& healAmount);
void OnHealthDepleted(Unit* attacker, bool isKill); // Pre-death hook

// --- Interaction ---
bool GossipHello(Player* player);
bool GossipSelect(Player* player, uint32 menuId, uint32 gossipListId);
bool QuestAccept(Player* player, Quest const* quest);
bool QuestReward(Player* player, Quest const* quest, uint32 opt);
```

### Evade Reason Enum

| Value | Name | When Triggered |
|-------|------|----------------|
| 0 | `EVADE_REASON_NO_HOSTILES` | No valid targets on threat list. |
| 1 | `EVADE_REASON_BOUNDARY` | Creature left its defined boundary. |
| 2 | `EVADE_REASON_SEQUENCE_BREAK` | Script logic forced evade. |
| 3 | `EVADE_REASON_NO_PATH` | Cannot pathfind back to target. |
| 4 | `EVADE_REASON_OTHER` | Generic fallback. |

### Registering a CreatureScript

```cpp
// In your module's script file:
class boss_example : public CreatureScript
{
public:
    boss_example() : CreatureScript("boss_example") { }

    struct boss_exampleAI : public BossAI
    {
        boss_exampleAI(Creature* creature) : BossAI(creature, DATA_EXAMPLE_BOSS) { }

        void Reset() override
        {
            _Reset();
            events.Reset();
        }

        void JustEngagedWith(Unit* /*who*/) override
        {
            _JustEngagedWith();
            events.ScheduleEvent(EVENT_SPELL_FIREBALL, 5s);
        }

        void UpdateAI(uint32 diff) override
        {
            if (!UpdateVictim())
                return;

            events.Update(diff);
            while (uint32 eventId = events.ExecuteEvent())
            {
                switch (eventId)
                {
                    case EVENT_SPELL_FIREBALL:
                        DoCastVictim(SPELL_FIREBALL);
                        events.Repeat(8s, 12s);
                        break;
                }
            }
            DoMeleeAttackIfReady();
        }

        void JustDied(Unit* /*killer*/) override
        {
            _JustDied();
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return GetInstanceAI<boss_exampleAI>(creature, sMyInstanceScript);
    }
};

void AddSC_boss_example()
{
    new boss_example();
    // Or with RegisterCreatureScript macro:
    // RegisterCreatureScript(boss_example);
}
```

### AllCreatureScript

`AllCreatureScript` hooks fire for **every** creature in the world, not just specific entries. Use when you need server-wide observation.

```cpp
class MyAllCreatureScript : public AllCreatureScript
{
public:
    MyAllCreatureScript() : AllCreatureScript("MyAllCreatureScript") { }

    // Fires when any creature dies
    void OnAllCreatureDeath(Creature* creature) override { ... }

    // Fires when any creature respawns
    void OnAllCreatureRespawn(Creature* creature) override { ... }

    // Fires on every UpdateAI tick for all creatures
    void OnAllCreatureUpdate(Creature* creature, uint32 diff) override { ... }
};
```

Do **not** use `AllCreatureScript::OnAllCreatureUpdate` for expensive logic — it runs every tick for every creature. Use it only for lightweight flags/checks.

---

## Creature Spawning & Lifecycle

### creature Table (Spawned Instances)

Each row is one physical spawn of a creature in the world.

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `guid` | INT UNSIGNED | PRI (auto) | Unique spawn GUID. |
| `id1` | INT UNSIGNED | 0 | Primary `creature_template.entry`. |
| `id2` | INT UNSIGNED | 0 | Secondary template (random selection between id1/id2/id3 on spawn). |
| `id3` | INT UNSIGNED | 0 | Tertiary template. |
| `map` | SMALLINT UNSIGNED | 0 | Map ID where creature spawns. |
| `zoneId` | SMALLINT UNSIGNED | 0 | Zone ID (auto-filled by core on startup). |
| `areaId` | SMALLINT UNSIGNED | 0 | Sub-zone/area ID (auto-filled). |
| `spawnMask` | TINYINT UNSIGNED | 1 | Difficulty bitmask: 1=10N, 2=25N, 4=10H, 8=25H, 15=all. For non-instanced: 1=normal world. |
| `phaseMask` | SMALLINT UNSIGNED | 1 | Phase bitmask. 1=default phase; higher bits = phase variants. |
| `equipment_id` | TINYINT UNSIGNED | 1 | `creature_equip_template.ID`: -1=random, 0=naked, 1+=specific set. |
| `position_x` | FLOAT | 0 | X coordinate. |
| `position_y` | FLOAT | 0 | Y coordinate. |
| `position_z` | FLOAT | 0 | Z coordinate (height). |
| `orientation` | FLOAT | 0 | Facing in radians: 0=North (East?), π=South. Use in-game `.npc info` to get coords. |
| `spawntimesecs` | INT UNSIGNED | 120 | Respawn delay in seconds. 0 = no respawn. |
| `wander_distance` | FLOAT | 5.0 | Radius in yards for `MovementType=1` (random wander). |
| `currentwaypoint` | INT UNSIGNED | 0 | **Do not set.** Core-managed current waypoint. |
| `curhealth` | INT UNSIGNED | 1 | **Do not set.** Core-managed current HP (1 = use template max). |
| `curmana` | INT UNSIGNED | 0 | **Do not set.** Core-managed current mana. |
| `MovementType` | TINYINT UNSIGNED | 0 | Overrides template: 0=Idle, 1=Random, 2=Waypoint. |
| `npcflag` | INT UNSIGNED | 0 | Per-spawn npcflag override (combined with template). |
| `unit_flags` | INT UNSIGNED | 0 | Per-spawn unit_flags override. |
| `dynamicflags` | INT UNSIGNED | 0 | Per-spawn dynamicflags override. |
| `ScriptName` | CHAR | NULL | Per-spawn script override. |
| `VerifiedBuild` | INT | NULL | Sniff build source. |
| `CreateObject` | TINYINT UNSIGNED | 0 | 0=normal spawn position, 1=precise position (no terrain snap). |
| `comment` | TEXT | NULL | Developer notes; not read by core. |

### Spawning via C++

```cpp
// SummonCreature — preferred method inside scripts
Creature* summon = me->SummonCreature(
    ENTRY_ID,           // creature_template.entry
    x, y, z,           // position
    orientation,        // facing (radians)
    TEMPSUMMON_TIMED_DESPAWN,  // summon type
    30000               // duration in ms (for timed types)
);

// Summon types (TempSummonType enum):
// TEMPSUMMON_TIMED_OR_DEAD_DESPAWN    — despawn after timer OR death
// TEMPSUMMON_TIMED_DESPAWN            — despawn after timer regardless
// TEMPSUMMON_TIMED_OR_CORPSE_DESPAWN  — despawn after timer OR corpse decay
// TEMPSUMMON_CORPSE_DESPAWN           — despawn on corpse creation
// TEMPSUMMON_CORPSE_TIMED_DESPAWN     — despawn N ms after death
// TEMPSUMMON_DEAD_DESPAWN             — despawn immediately on death
// TEMPSUMMON_MANUAL_DESPAWN           — only removed by explicit DespawnOrUnsummon()

// Despawn
summon->DespawnOrUnsummon();               // Immediate
summon->DespawnOrUnsummon(5000);           // After 5 seconds
```

### Respawn Mechanics

- `spawntimesecs` is the **minimum** time before the creature can respawn after death.
- Respawn is jittered by ±10% to prevent synchronized waves.
- In **instanced** zones, creatures respawn on instance reset, not on `spawntimesecs`.
- `RegenHealth = 0` in the template prevents health regen while alive, but does not affect respawn.
- `creature.curhealth` is written by the core on crash/shutdown; always insert as `1`.

### Summon from SQL (Static Spawn)

```sql
INSERT INTO creature (id1, map, position_x, position_y, position_z, orientation, spawntimesecs, wander_distance, MovementType)
VALUES (12345, 0, -8923.96, -132.48, 82.41, 1.39, 300, 0, 0);
```

---

## creature_addon Table

Applies persistent aura/visual effects and movement state to specific spawn GUIDs or to all spawns of a template entry. Two separate tables:

- `creature_addon` — keyed by `guid` (per-spawn overrides)
- `creature_template_addon` — keyed by `entry` (template-level defaults)

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `guid` / `entry` | INT / MEDIUMINT UNSIGNED | PRI | Spawn GUID or template entry. |
| `path_id` | INT UNSIGNED | 0 | `waypoint_data.id` to follow. Must match `MovementType=2`. |
| `mount` | MEDIUMINT UNSIGNED | 0 | Display model ID of mount (from `CreatureDisplayInfo.dbc`). Overrides `UNIT_FIELD_MOUNTDISPLAYID`. |
| `bytes1` | INT UNSIGNED | 0 | Stand state and animation byte. See table below. |
| `bytes2` | INT UNSIGNED | 0 | Sheath state. 0=unarmed, 1=melee drawn, 2=ranged drawn. |
| `emote` | INT UNSIGNED | 0 | Continuous emote ID from `Emotes.dbc`. |
| `aiAnimKit` | SMALLINT SIGNED | 0 | AI animation kit ID. |
| `movementAnimKit` | SMALLINT SIGNED | 0 | Movement animation kit ID. |
| `meleeAnimKit` | SMALLINT SIGNED | 0 | Melee animation kit ID. |
| `visibilityDistanceType` | TINYINT UNSIGNED | 0 | 0=Normal, 1=Tiny, 2=Small, 3=Large, 4=Gigantic, 5=Infinite. |
| `auras` | TEXT | NULL | Space-separated spell IDs to apply permanently on spawn. |

### bytes1 (Stand State) Values

| Value | State |
|-------|-------|
| 0 | Standing (default). |
| 1 | Sitting on ground. |
| 2 | Sitting in chair. |
| 3 | Sleeping (lying on ground). |
| 4 | Sitting in low chair. |
| 5 | Sitting in medium chair. |
| 6 | Sitting in high chair. |
| 7 | Dead (empty health bar; use with dead emote). |
| 8 | Kneeling. |
| 9 | Submerged (underground). |
| 54432 | Hover mode (gravity disabled). |
| 50331648 | Hover mode variant 2. |

### auras Examples

```sql
-- Creature permanently invisible (but detectable) + on-fire visual
UPDATE creature_template_addon SET auras = '16380 42587' WHERE entry = 12345;

-- Single permanent aura
UPDATE creature_addon SET auras = '18950' WHERE guid = 987654;
```

---

## Waypoint System

### waypoint_data Table

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `id` | INT UNSIGNED | PRI | Path ID. Convention: `creature_spawn_guid * 10`. |
| `point` | MEDIUMINT UNSIGNED | PRI | Point sequence number. Starts at 1, increments by 1. |
| `position_x` | FLOAT | 0 | X coordinate of this waypoint. |
| `position_y` | FLOAT | 0 | Y coordinate. |
| `position_z` | FLOAT | 0 | Z coordinate. |
| `orientation` | FLOAT | NULL | Creature facing at this point. NULL = face direction of travel. |
| `delay` | INT UNSIGNED | 0 | Pause time in milliseconds at this point before continuing. |
| `move_type` | INT | 0 | 0=Walk, 1=Run, 2=Fly. |
| `action` | INT | 0 | `waypoint_scripts.id` to execute on arrival. 0 = no action. |
| `action_chance` | SMALLINT | 100 | Percentage chance (0–100) the action fires. |
| `wpguid` | INT UNSIGNED | 0 | **Do not set.** Used internally by `.wp show on` visualization mode. |

### Creating a Waypoint Path

```sql
-- Path ID = spawn GUID * 10 (e.g., GUID 1234 → path 12340)
INSERT INTO waypoint_data (id, point, position_x, position_y, position_z, orientation, delay, move_type)
VALUES
  (12340, 1, -8923.96, -132.48, 82.41, NULL, 0,    0),
  (12340, 2, -8930.00, -140.00, 82.41, NULL, 2000, 0),
  (12340, 3, -8910.00, -145.00, 83.00, NULL, 0,    1);

-- Attach path to spawn
UPDATE creature SET MovementType = 2 WHERE guid = 1234;
UPDATE creature_addon SET path_id = 12340 WHERE guid = 1234;
```

Paths loop by default. The creature returns to point 1 after reaching the last point.

---

## Creature Stats & Scaling

### How Base Stats Are Computed

1. The core looks up **`creature_classlevelstats`** using `unit_class` and creature level.
2. It reads base HP and base mana from that table.
3. It multiplies by `HealthModifier` / `ManaModifier` from `creature_template`.
4. `rank` adds a further multiplier (Elite ×2–4, Boss ×5–10 depending on config).
5. `DamageModifier` scales melee/ranged auto-attack damage similarly.

### creature_template_resistance Table

Override resistances per school beyond what auras provide. Note: `School=0` (Physical/Armor) is **not** stored here; use `ArmorModifier`.

| Column | Type | Description |
|--------|------|-------------|
| `CreatureID` | MEDIUMINT UNSIGNED | `creature_template.entry`. |
| `School` | TINYINT UNSIGNED | 1=Holy, 2=Fire, 3=Nature, 4=Frost, 5=Shadow, 6=Arcane. |
| `Resistance` | SMALLINT SIGNED | Base resistance value. Can be negative (vulnerability). |
| `VerifiedBuild` | SMALLINT SIGNED | Verification status. |

```sql
-- Make creature immune to fire (high resistance)
INSERT INTO creature_template_resistance (CreatureID, School, Resistance)
VALUES (12345, 2, 9999);

-- Add fire vulnerability
INSERT INTO creature_template_resistance (CreatureID, School, Resistance)
VALUES (12345, 2, -100);
```

### creature_template_spell Table

Defines up to 8 spells on the creature's actionbar. Used for vehicle passengers and mind-controlled creature spells.

| Column | Type | Description |
|--------|------|-------------|
| `CreatureID` | MEDIUMINT UNSIGNED | `creature_template.entry`. |
| `Index` | TINYINT UNSIGNED | Slot 0–7 on actionbar. |
| `Spell` | MEDIUMINT UNSIGNED | Spell ID. |
| `VerifiedBuild` | SMALLINT SIGNED | Verification status. |

For **CombatAI**, these slots are also used to define spells the AI casts during combat with timer-based logic from `creature_ai_scripts`.

---

## Vendor Setup

### npc_vendor Table

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `entry` | MEDIUMINT UNSIGNED | PRI | `creature_template.entry` of the vendor. |
| `slot` | SMALLINT SIGNED | 0 | Display order position. 0 = auto-ordered. Positive = fixed position top-to-bottom, left-to-right. |
| `item` | MEDIUMINT SIGNED | PRI | `item_template.entry` to sell. |
| `maxcount` | TINYINT UNSIGNED | 0 | Max stock. 0 = unlimited. Combined with `incrtime` for restocking. |
| `incrtime` | INT UNSIGNED | 0 | Seconds between stock replenishments when `maxcount > 0`. |
| `ExtendedCost` | MEDIUMINT UNSIGNED | PRI | `ItemExtendedCost.dbc` ID for non-gold currency. 0 = gold only. Used for honor, arena points, badge items. |

**Notes:**
- Maximum 150 items per vendor (client hardcoded limit).
- Gold price comes from `item_template.BuyPrice`; `npc_vendor` does not override it.
- `ExtendedCost` IDs are DBC-derived: use `SELECT * FROM item_extended_cost.dbc` or a DBC viewer to find the ID for a specific token/honor cost.

### Adding Items to a Vendor

```sql
-- Add unlimited item 49623 (Battered Hilt) for gold only
INSERT INTO npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost)
VALUES (28690, 0, 49623, 0, 0, 0);

-- Add limited stock item that restocks every 10 minutes
INSERT INTO npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost)
VALUES (28690, 0, 2455, 5, 600, 0);

-- Add badge-purchased item (ExtendedCost 3285 = 1x Emblem of Frost)
INSERT INTO npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost)
VALUES (28690, 0, 50359, 0, 0, 3285);
```

### creature_equip_template Table

Controls weapon display for vendor/guard/NPC models.

| Column | Type | Description |
|--------|------|-------------|
| `CreatureID` | MEDIUMINT UNSIGNED | `creature_template.entry`. |
| `ID` | TINYINT UNSIGNED | Equipment set index (start at 1). Referenced by `creature.equipment_id`. |
| `ItemID1` | MEDIUMINT UNSIGNED | Main-hand weapon item entry. |
| `ItemID2` | MEDIUMINT UNSIGNED | Off-hand weapon/shield item entry. |
| `ItemID3` | MEDIUMINT UNSIGNED | Ranged weapon item entry. |

---

## Trainer Setup

Trainers use two tables: `trainer` (NPC greeting and type) and `trainer_spell` (actual spells).

### trainer Table

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `Id` | INT UNSIGNED | PRI | Trainer ID (referenced by `creature_default_trainer.TrainerId`). |
| `Type` | TINYINT UNSIGNED | 2 | 0=Class, 1=Mount, 2=Tradeskill, 3=Pet. |
| `Requirement` | MEDIUMINT UNSIGNED | 0 | For Type 0/3: `ChrClasses.dbc` class ID. For Type 1: race ID. For Type 2: prerequisite spell ID. |
| `Greeting` | MEDIUMTEXT | — | Text shown when trainer window opens. Not gossip text. |
| `VerifiedBuild` | INT | 0 | Sniff verification status. |

### trainer_spell Table

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `TrainerId` | INT UNSIGNED | PRI | References `trainer.Id`. |
| `SpellId` | INT UNSIGNED | PRI | `Spell.dbc` spell ID to teach. |
| `MoneyCost` | INT UNSIGNED | 0 | Cost in copper (10000 = 1 gold). |
| `ReqSkillLine` | INT UNSIGNED | 0 | Required skill line ID from `SkillLine.dbc`. 0 = none. |
| `ReqSkillRank` | INT UNSIGNED | 0 | Minimum skill points in `ReqSkillLine`. |
| `ReqAbility1` | INT UNSIGNED | 0 | Prerequisite spell 1 the player must already know. |
| `ReqAbility2` | INT UNSIGNED | 0 | Prerequisite spell 2. |
| `ReqAbility3` | INT UNSIGNED | 0 | Prerequisite spell 3. |
| `ReqLevel` | TINYINT UNSIGNED | 0 | Minimum player character level. |
| `VerifiedBuild` | INT | 0 | Sniff build source. |

### Adding Spells to a Trainer

```sql
-- Step 1: Find or create a trainer record
INSERT INTO trainer (Id, Type, Requirement, Greeting)
VALUES (9001, 2, 0, 'What would you like to learn?');

-- Step 2: Add spells
INSERT INTO trainer_spell (TrainerId, SpellId, MoneyCost, ReqSkillLine, ReqSkillRank, ReqAbility1, ReqLevel)
VALUES
  (9001, 818,   50000, 171, 0,   0,  5),   -- Basic Fishing, 5 silver, level 5
  (9001, 7620,  10000, 171, 75,  818, 20);  -- Journeyman Fishing, 1 silver, need Apprentice first

-- Step 3: Link trainer to creature
-- Link trainer to creature via creature_default_trainer
INSERT INTO creature_default_trainer (CreatureId, TrainerId) VALUES (9999, 9001);
-- Set npcflag to include TRAINER
UPDATE creature_template SET npcflag = npcflag | 16, ScriptName = 'your_trainer_script' WHERE entry = 9999;
```

---

## Gossip System

### gossip_menu Table

Links a creature to its opening dialogue text.

| Column | Type | Description |
|--------|------|-------------|
| `MenuID` | SMALLINT UNSIGNED | PRI. Matches `creature_template.gossip_menu_id`. Custom IDs: use ≥ 90000. |
| `TextID` | MEDIUMINT UNSIGNED | `npc_text.ID` for the opening NPC message. |

### gossip_menu_option Table

Defines clickable options in the gossip window.

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `MenuID` | SMALLINT UNSIGNED | PRI | Parent menu this option belongs to. |
| `OptionID` | SMALLINT UNSIGNED | PRI | Sequential option index within the menu. |
| `OptionIcon` | SMALLINT UNSIGNED | 0 | Icon shown next to option text (see icons below). |
| `OptionText` | TEXT | NULL | Display text for the option. |
| `OptionBroadcastTextID` | MEDIUMINT | 0 | `broadcast_text` ID; overrides `OptionText` if set. |
| `OptionType` | TINYINT UNSIGNED | 0 | What happens when clicked. See OptionType table below. |
| `OptionNpcFlag` | INT UNSIGNED | 0 | Required `npcflag` bit for this option to appear. |
| `ActionMenuID` | MEDIUMINT UNSIGNED | 0 | Sub-menu `MenuID` to open. For nested menus. |
| `ActionPoiID` | MEDIUMINT UNSIGNED | 0 | Point-of-interest ID to highlight on minimap. |
| `BoxCoded` | TINYINT UNSIGNED | 0 | 1 = requires text input to confirm (coded box). |
| `BoxMoney` | INT UNSIGNED | 0 | Copper cost to select this option (100000 = 10 gold). |
| `BoxText` | TEXT | NULL | Confirmation text in the money/code box. |
| `BoxBroadcastTextID` | MEDIUMINT | 0 | Broadcast text override for `BoxText`. |
| `VerifiedBuild` | SMALLINT | 0 | Build verification. |

### OptionType Enum

| Value | Name | Effect |
|-------|------|--------|
| 0 | GOSSIP_OPTION_NONE | Fires `OnGossipSelect` in script; no built-in action. |
| 1 | GOSSIP_OPTION_GOSSIP | Opens a sub-menu or fires script. |
| 2 | GOSSIP_OPTION_QUESTGIVER | Opens quest list. |
| 3 | GOSSIP_OPTION_VENDOR | Opens vendor window. |
| 4 | GOSSIP_OPTION_TAXIVENDOR | Opens flight master map. |
| 5 | GOSSIP_OPTION_TRAINER | Opens trainer window. |
| 6 | GOSSIP_OPTION_SPIRITHEALER | Resurrects ghost. |
| 7 | GOSSIP_OPTION_SPIRITGUIDE | Guides to nearest graveyard. |
| 8 | GOSSIP_OPTION_INNKEEPER | Binds hearthstone. |
| 9 | GOSSIP_OPTION_BANKER | Opens bank. |
| 10 | GOSSIP_OPTION_PETITIONER | Opens guild/arena petition. |
| 11 | GOSSIP_OPTION_TABARDDESIGNER | Opens tabard designer. |
| 12 | GOSSIP_OPTION_BATTLEFIELD | Queues for battleground. |
| 13 | GOSSIP_OPTION_AUCTIONEER | Opens auction house. |
| 14 | GOSSIP_OPTION_STABLEPET | Opens pet stable. |
| 15 | GOSSIP_OPTION_ARMORER | Opens repair window. |
| 16 | GOSSIP_OPTION_UNLEARNTALENTS | Opens talent unlearn dialog. |
| 17 | GOSSIP_OPTION_UNLEARNPETTALENTS | Opens pet talent unlearn dialog. |
| 18 | GOSSIP_OPTION_LEARNDUALSPEC | Opens dual-specialization purchase. |
| 19 | GOSSIP_OPTION_OUTDOORPVP | Triggers outdoor PvP interaction. |

### npc_text Table

| Column | Type | Description |
|--------|------|-------------|
| `ID` | MEDIUMINT UNSIGNED | PRI. Referenced by `gossip_menu.TextID`. |
| `text0_0` – `text7_0` | LONGTEXT | Up to 8 male dialogue variants. |
| `text0_1` – `text7_1` | LONGTEXT | Corresponding female variants. |
| `lang0` – `lang7` | TINYINT UNSIGNED | Language ID (0 = universal). |
| `Probability0` – `Probability7` | FLOAT | Probability weight for each variant (0.0–1.0). Sum should equal 1.0. |
| `em0_0` – `em7_5` | SMALLINT UNSIGNED | Emote IDs to play in sequence during this text (6 slots per variant). |
| `VerifiedBuild` | SMALLINT | Build verification. |

Use `$B` for line breaks and `$N` for player name substitution in text fields.

### Gossip in C++ CreatureScript

```cpp
bool OnGossipHello(Player* player, Creature* creature) override
{
    // Clear any existing menu
    ClearGossipMenuFor(player);

    // Add options manually (alternative to DB gossip_menu_option)
    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Tell me about this place.", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
    AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "I'd like to browse your goods.", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_TRADE);

    // Show with npc_text ID 12345
    SendGossipMenuFor(player, 12345, creature->GetGUID());
    return true;
}

bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
{
    player->PlayerTalkClass->ClearMenus();

    switch (action)
    {
        case GOSSIP_ACTION_INFO_DEF + 1:
            SendGossipMenuFor(player, 12346, creature->GetGUID());
            break;
        case GOSSIP_ACTION_TRADE:
            player->GetSession()->SendListInventory(creature->GetGUID());
            CloseGossipMenuFor(player);
            break;
    }
    return true;
}
```

---

## Boss Mechanics

### BossAI Class

`BossAI` extends `ScriptedAI` with encounter-specific utilities. Every boss that is part of an instance **should** use `BossAI`.

```cpp
class BossAI : public ScriptedAI
{
protected:
    InstanceScript* const instance;  // Pointer to the instance script
    SummonList summons;              // Tracked summons for cleanup

    // These call into InstanceScript automatically:
    void _Reset();              // Resets boss state + despawns summons
    void _JustEngagedWith();    // Sets BOSS_STATE_IN_PROGRESS
    void _JustDied();           // Sets BOSS_STATE_DONE + fires achievement checks
    void _EnterEvadeMode();     // Sets BOSS_STATE_NOT_STARTED on wipe
};
```

### BossState Enum

| Value | Name | Description |
|-------|------|-------------|
| 0 | `NOT_STARTED` | Boss has not been engaged this reset. |
| 1 | `IN_PROGRESS` | Boss is currently in combat. |
| 2 | `FAIL` | Encounter failed (wipe). Rarely used directly. |
| 3 | `DONE` | Boss defeated this instance reset. |
| 4 | `SPECIAL` | Custom mid-encounter state (used for phase triggers). |
| 5 | `TO_BE_DECIDED` | State not yet determined (placeholder). |

### InstanceScript Integration

```cpp
// In the instance script header (e.g., instance_my_dungeon.h):
enum DataTypes
{
    DATA_BOSS_ONE = 0,
    DATA_BOSS_TWO = 1,
};

// In the instance script .cpp:
class instance_my_dungeon : public InstanceScript
{
    void OnCreatureCreate(Creature* creature) override
    {
        switch (creature->GetEntry())
        {
            case NPC_BOSS_ONE:
                bossOneGUID = creature->GetGUID();
                break;
        }
    }

    bool SetBossState(uint32 id, EncounterState state) override
    {
        if (!InstanceScript::SetBossState(id, state))
            return false;

        switch (id)
        {
            case DATA_BOSS_ONE:
                if (state == DONE)
                    HandleGameObject(someGateGUID, true); // Open door
                break;
        }
        return true;
    }
};

// In boss AI:
BossAI::BossAI(Creature* creature) : BossAI(creature, DATA_BOSS_ONE) { }
// DATA_BOSS_ONE is passed to the parent constructor which binds this AI to that encounter slot
```

### ScriptedAI Utility Methods

```cpp
// Spell casting helpers
DoCast(SpellId);                     // Cast on self
DoCastVictim(SpellId);               // Cast on current target
DoCastAOE(SpellId);                  // AoE cast
DoCastRandom(SpellId, float range);  // Cast on random target in range

// Target selection
SelectTarget(SelectTargetMethod, uint32 position, float dist, bool playerOnly);
// SelectTargetMethod: SELECT_TARGET_RANDOM, SELECT_TARGET_MAXTHREAT,
//                     SELECT_TARGET_MINTHREAT, SELECT_TARGET_MAXDISTANCE,
//                     SELECT_TARGET_MINDISTANCE, SELECT_TARGET_NEAREST

// Threat management
AddThreat(Unit* victim, float amount);
ModifyThreatByPercent(Unit* victim, int32 percent);
ResetThreatList();

// Difficulty helpers
bool IsHeroic();
bool Is25ManRaid();
Difficulty GetDifficulty();

// DUNGEON_MODE and RAID_MODE macros
uint32 spellId = DUNGEON_MODE(SPELL_NORMAL, SPELL_HEROIC);
uint32 damage  = RAID_MODE(10000, 20000, 12000, 25000); // 10N, 25N, 10H, 25H

// Health check events
ScheduleHealthCheckEvent(50, [this]() { /* Phase 2 at 50% HP */ });
ScheduleHealthCheckEvent({ 75, 50, 25 }, [this]() { /* Multi-threshold */ });

// Enrage timer
ScheduleEnrageTimer(600000, SPELL_ENRAGE); // 10-minute berserk
```

### SummonList Usage

```cpp
// In JustEngagedWith or via events:
if (Creature* add = me->SummonCreature(NPC_ADD, x, y, z, 0, TEMPSUMMON_CORPSE_DESPAWN))
    summons.Summon(add);

// Despawn all tracked summons (called automatically in _Reset/_JustDied)
summons.DespawnAll();

// Run action on all alive summons
summons.DoAction(ACTION_ACTIVATE);

// Lambda over all summons
summons.DoForAllSummons([](WorldObject* obj) {
    if (Creature* summon = obj->ToCreature())
        summon->AI()->SetData(DATA_PHASE, 2);
});
```

### creature_loot_template Table

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `Entry` | MEDIUMINT UNSIGNED | PRI | `creature_template.lootid`. Groups loot entries. |
| `Item` | MEDIUMINT UNSIGNED | PRI | `item_template.entry`. Positive = item; negative = reference to `reference_loot_template`. |
| `Reference` | MEDIUMINT UNSIGNED | 0 | If non-zero, redirects to `reference_loot_template.Entry` instead of rolling this row directly. |
| `Chance` | FLOAT | 100 | Drop chance percentage (0.0–100.0). Negative = reference to guaranteed drop group. |
| `QuestRequired` | TINYINT UNSIGNED | 0 | 1 = only drops if at least one group member has the associated quest. |
| `LootMode` | SMALLINT UNSIGNED | 1 | Bitmask matching `spawnMask` difficulty. 1=Normal, 2=Heroic, etc. |
| `GroupId` | TINYINT UNSIGNED | 0 | 0 = independent roll. 1+ = grouped (only one item from the group drops per kill). |
| `MinCount` | TINYINT UNSIGNED | 1 | Minimum number of this item to drop per roll. |
| `MaxCount` | TINYINT UNSIGNED | 1 | Maximum number. |
| `Comment` | VARCHAR(255) | NULL | Developer note; not read by core. |

```sql
-- Add a 5% chance to drop item 49623 in normal mode
INSERT INTO creature_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount)
VALUES (12345, 49623, 0, 5.0, 0, 1, 0, 1, 1);

-- Add a grouped drop: either item A or item B drops, each 50% (one or the other)
INSERT INTO creature_loot_template VALUES (12345, 11111, 0, 50.0, 0, 1, 1, 1, 1);
INSERT INTO creature_loot_template VALUES (12345, 22222, 0, 50.0, 0, 1, 1, 1, 1);
-- GroupId=1 means only one of the above drops

-- Quest item (only visible if player has quest)
INSERT INTO creature_loot_template VALUES (12345, 33333, 0, 100.0, 1, 1, 0, 1, 1);
```

---

## Cross-References

| Topic | Table / File | Notes |
|-------|-------------|-------|
| Faction behavior | `FactionTemplate.dbc` | Controls hostility/friendliness |
| Smart scripts | `smart_scripts` | SmartAI event-action pairs |
| Waypoint actions | `waypoint_scripts` | Scripts triggered at waypoint arrival |
| Broadcast text | `broadcast_text` | Used by `npc_text`, gossip, and creature emotes |
| Item extended costs | `ItemExtendedCost.dbc` | Badge/honor vendor pricing |
| Creature model | `CreatureDisplayInfo.dbc` | Model IDs for `creature_model_info` |
| Skill lines | `SkillLine.dbc` | `ReqSkillLine` IDs for trainer_spell |
| Spell mechanics | `Spell.dbc` | Spell IDs, school, mechanic fields |
| Instance states | `instance_*` source files | `EncounterState` enum, boss data IDs |
| Creature family | `CreatureFamily.dbc` | Pet family names and IDs |
| Equipment items | `Item.dbc` | Equipment item display IDs |
| Knowledge base | `kb_azerothcore_dev.md` | SmartAI event/action tables, full C++ hook reference |
| Eluna Lua API | `kb_eluna_api.md` | `RegisterCreatureEvent`, Lua-side creature hooks |
