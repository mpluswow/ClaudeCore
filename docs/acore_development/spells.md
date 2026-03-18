# Spell System

Complete reference for AzerothCore spell data: SpellEntry/DBC fields, `spell_dbc` DB overrides, effect and aura enums, proc events, and linked spells.

---

## Table of Contents

1. [SpellEntry Key Fields](#1-spellentry-key-fields)
2. [spell_dbc Table](#2-spell_dbc-table)
3. [SpellEffects Enum](#3-spelleffects-enum)
4. [AuraTypes Enum](#4-auratypes-enum)
5. [Spell School Masks](#5-spell-school-masks)
6. [Dispel Types](#6-dispel-types)
7. [Mechanic Types](#7-mechanic-types)
8. [SpellAttr0–7 Key Flags](#8-spellattr07-key-flags)
9. [spell_proc Table](#9-spell_proc-table)
10. [spell_linked_spell Table](#10-spell_linked_spell-table)
11. [Cross-References](#11-cross-references)

---

## 1. SpellEntry Key Fields

These are the most important fields from `Spell.dbc` / `SpellInfo` used in scripting and DB work. DB overrides live in `spell_dbc`.

| Field | Type | Description |
|-------|------|-------------|
| `Id` | uint32 | Spell ID — primary key |
| `School` | uint32 | School mask (see §5) |
| `Category` | uint32 | Spell category for shared cooldowns |
| `Dispel` | uint32 | Dispel type (see §6) |
| `Mechanic` | uint32 | Mechanic type (see §7) |
| `Attributes` | uint32 | SpellAttr0 bitmask |
| `AttributesEx` | uint32 | SpellAttr1 bitmask |
| `AttributesEx2` | uint32 | SpellAttr2 bitmask |
| `AttributesEx3` | uint32 | SpellAttr3 bitmask |
| `AttributesEx4` | uint32 | SpellAttr4 bitmask |
| `AttributesEx5` | uint32 | SpellAttr5 bitmask |
| `AttributesEx6` | uint32 | SpellAttr6 bitmask |
| `AttributesEx7` | uint32 | SpellAttr7 bitmask |
| `CastingTimeIndex` | uint32 | Index into `SpellCastTimes.dbc` |
| `DurationIndex` | uint32 | Index into `SpellDuration.dbc` |
| `RangeIndex` | uint32 | Index into `SpellRange.dbc` |
| `PowerType` | int32 | 0=mana, 1=rage, 3=energy, 6=runic power |
| `ManaCost` | uint32 | Base mana/power cost |
| `ManaCostPercentage` | uint32 | Cost as % of base mana |
| `StackAmount` | uint32 | Max stack count (0 = not stackable) |
| `ProcFlags` | uint32 | Proc trigger conditions bitmask |
| `ProcChance` | uint32 | Proc chance in percent (101 = always) |
| `ProcCharges` | uint32 | Number of proc charges |
| `MaxLevel` | uint32 | Max caster level for spell scaling |
| `BaseLevel` | uint32 | Min base level for scaling |
| `SpellLevel` | uint32 | Level at which spell was learned |
| `Effect1`–`Effect3` | uint32 | SpellEffect IDs for each effect slot (see §3) |
| `EffectApplyAuraName1`–`3` | uint32 | AuraType for APPLY_AURA effects (see §4) |
| `EffectBasePoints1`–`3` | int32 | Base magnitude (actual value = BasePoints + 1) |
| `EffectDieSides1`–`3` | int32 | Dice sides for random component |
| `EffectRealPointsPerLevel1`–`3` | float | Points added per caster level |
| `EffectAmplitude1`–`3` | uint32 | Periodic tick interval in ms |
| `EffectTriggerSpell1`–`3` | uint32 | Spell triggered by TRIGGER_SPELL / PROC_TRIGGER |
| `EffectMiscValue1`–`3` | int32 | Effect-specific parameter (summon entry, aura misc, etc.) |
| `EffectRadiusIndex1`–`3` | uint32 | Index into `SpellRadius.dbc` |
| `SpellIconID` | uint32 | Icon texture ID |
| `SpellVisual` | uint32 | Visual effect ID |
| `SpellFamilyName` | uint32 | Class spell family (0=generic, 3=mage, 4=warrior, etc.) |
| `SpellFamilyFlags` | flag96 | 96-bit class flag mask for talent/proc matching |

---

## 2. spell_dbc Table

DB: `acore_world.spell_dbc`. Overrides any DBC field for a spell by ID. Only rows that exist here are applied — missing rows use DBC values unchanged.

| Column | Type | Description |
|--------|------|-------------|
| `ID` | INT UNSIGNED | Spell ID (PK, must match DBC entry) |
| `School` | TINYINT UNSIGNED | Override spell school mask |
| `Category` | SMALLINT UNSIGNED | Override category ID |
| `dispel` | TINYINT UNSIGNED | Override dispel type |
| `Mechanic` | TINYINT UNSIGNED | Override mechanic type |
| `Attributes` | INT UNSIGNED | Override SpellAttr0 |
| `AttributesEx` | INT UNSIGNED | Override SpellAttr1 |
| `AttributesEx2` | INT UNSIGNED | Override SpellAttr2 |
| `AttributesEx3` | INT UNSIGNED | Override SpellAttr3 |
| `AttributesEx4` | INT UNSIGNED | Override SpellAttr4 |
| `AttributesEx5` | INT UNSIGNED | Override SpellAttr5 |
| `AttributesEx6` | INT UNSIGNED | Override SpellAttr6 |
| `AttributesEx7` | INT UNSIGNED | Override SpellAttr7 |
| `Stances` | INT UNSIGNED | Bitmask of required stances/shapeshifts |
| `StancesNot` | INT UNSIGNED | Bitmask of forbidden stances |
| `Targets` | INT UNSIGNED | Allowed target flags |
| `TargetCreatureType` | SMALLINT UNSIGNED | Creature type mask restriction |
| `RequiresSpellFocus` | SMALLINT UNSIGNED | Required spell focus GO type |
| `FacingCasterFlags` | TINYINT UNSIGNED | Caster facing requirements |
| `CasterAuraState` | TINYINT UNSIGNED | Required caster aura state |
| `TargetAuraState` | TINYINT UNSIGNED | Required target aura state |
| `CasterAuraStateNot` | TINYINT UNSIGNED | Forbidden caster aura state |
| `TargetAuraStateNot` | TINYINT UNSIGNED | Forbidden target aura state |
| `CastingTimeIndex` | SMALLINT UNSIGNED | Index → SpellCastTimes.dbc |
| `RecoveryTime` | INT UNSIGNED | Cooldown in ms |
| `CategoryRecoveryTime` | INT UNSIGNED | Category cooldown in ms |
| `InterruptFlags` | TINYINT UNSIGNED | What interrupts the cast |
| `AuraInterruptFlags` | INT UNSIGNED | What removes the aura |
| `ChannelInterruptFlags` | INT UNSIGNED | What interrupts the channel |
| `procFlags` | INT UNSIGNED | Proc trigger flags |
| `procChance` | TINYINT UNSIGNED | Proc chance % (101=always) |
| `procCharges` | TINYINT UNSIGNED | Number of proc charges |
| `maxLevel` | TINYINT UNSIGNED | Level cap for scaling |
| `baseLevel` | TINYINT UNSIGNED | Base level for scaling |
| `spellLevel` | TINYINT UNSIGNED | Level the spell was learned |
| `DurationIndex` | SMALLINT UNSIGNED | Index → SpellDuration.dbc |
| `powerType` | TINYINT | Power type used |
| `manaCost` | INT UNSIGNED | Flat power cost |
| `manaCostPerlevel` | SMALLINT UNSIGNED | Extra cost per level above base |
| `manaPerSecond` | SMALLINT UNSIGNED | Mana drain per second during channel |
| `manaPerSecondPerLevel` | SMALLINT UNSIGNED | Per-level mana/sec scaling |
| `rangeIndex` | TINYINT UNSIGNED | Index → SpellRange.dbc |
| `speed` | FLOAT | Projectile speed |
| `StackAmount` | SMALLINT UNSIGNED | Max stack count |
| `Totem1` / `Totem2` | INT UNSIGNED | Required totem item IDs |
| `Reagent1`–`8` | INT | Required reagent item IDs |
| `ReagentCount1`–`8` | SMALLINT | Required reagent counts |
| `EquippedItemClass` | INT | Required equipped item class (-1=none) |
| `EquippedItemSubClassMask` | INT | Required item subclass mask |
| `EquippedItemInventoryTypeMask` | INT | Required inventory slot mask |
| `Effect1`–`3` | TINYINT UNSIGNED | SpellEffect IDs |
| `EffectDieSides1`–`3` | INT | Dice sides |
| `EffectRealPointsPerLevel1`–`3` | FLOAT | Points per caster level |
| `EffectBasePoints1`–`3` | INT | Base magnitude |
| `EffectMechanic1`–`3` | TINYINT UNSIGNED | Per-effect mechanic override |
| `EffectImplicitTargetA1`–`3` | TINYINT UNSIGNED | Primary targeting mode |
| `EffectImplicitTargetB1`–`3` | TINYINT UNSIGNED | Secondary targeting mode |
| `EffectRadiusIndex1`–`3` | TINYINT UNSIGNED | AoE radius index |
| `EffectApplyAuraName1`–`3` | SMALLINT UNSIGNED | AuraType for aura effects |
| `EffectAmplitude1`–`3` | INT | Periodic interval in ms |
| `EffectMultipleValue1`–`3` | FLOAT | Multiplier value (leech ratio etc.) |
| `EffectChainTarget1`–`3` | TINYINT UNSIGNED | Max chain jump targets |
| `EffectItemType1`–`3` | INT UNSIGNED | Item entry for CREATE_ITEM effect |
| `EffectMiscValue1`–`3` | INT | Misc parameter (summon entry, stat type, etc.) |
| `EffectMiscValueB1`–`3` | INT | Secondary misc parameter |
| `EffectTriggerSpell1`–`3` | INT UNSIGNED | Spell triggered by this effect |
| `EffectPointsPerComboPoint1`–`3` | FLOAT | Points added per combo point |
| `EffectSpellClassMaskA1`–`3` | INT UNSIGNED | Spell family mask (word A) |
| `EffectSpellClassMaskB1`–`3` | INT UNSIGNED | Spell family mask (word B) |
| `EffectSpellClassMaskC1`–`3` | INT UNSIGNED | Spell family mask (word C) |
| `SpellVisual` | INT UNSIGNED | Visual effect override |
| `SpellIconID` | SMALLINT UNSIGNED | Icon ID override |
| `ActiveIconID` | SMALLINT UNSIGNED | Active buff icon ID |
| `SpellName` | VARCHAR(100) | Override spell name |
| `Rank` | VARCHAR(32) | Rank string (e.g., "Rank 3") |
| `MaxTargetLevel` | TINYINT UNSIGNED | Max target level |
| `SpellFamilyName` | TINYINT UNSIGNED | Class spell family ID |
| `SpellFamilyFlags1`–`3` | INT UNSIGNED | 96-bit family flag words |
| `MaxAffectedTargets` | TINYINT UNSIGNED | AoE target cap |
| `DmgClass` | TINYINT UNSIGNED | 0=none, 1=magic, 2=melee, 3=ranged |
| `PreventionType` | TINYINT UNSIGNED | 0=none, 1=silence, 2=pacify |
| `DmgMultiplier1`–`3` | FLOAT | Per-effect damage multiplier |
| `TotemCategory1`–`2` | INT UNSIGNED | Required totem category |
| `AreaGroupId` | INT | Required area group |
| `SchoolMask` | INT UNSIGNED | Full school mask |
| `runeCostID` | INT UNSIGNED | Rune cost entry ID |
| `spellDifficultyID` | INT UNSIGNED | Scaling difficulty ID |

---

## 3. SpellEffects Enum

C++ constant: `SpellEffects`. DB field: `Effect1`–`3` in `spell_dbc`.

| ID | Constant | Description |
|----|----------|-------------|
| 0 | NONE | No effect |
| 1 | INSTAKILL | Kill target instantly |
| 2 | SCHOOL_DAMAGE | Direct school damage |
| 3 | DUMMY | Script hook only; no built-in logic |
| 4 | PORTAL_TELEPORT | Unused portal teleport |
| 5 | TELEPORT_UNITS | Teleport to coordinates |
| 6 | APPLY_AURA | Apply aura (type in EffectApplyAuraName) |
| 7 | ENVIRONMENTAL_DAMAGE | Environmental damage type |
| 8 | POWER_DRAIN | Drain power from target to caster |
| 9 | HEALTH_LEECH | Steal HP from target |
| 10 | HEAL | Direct heal |
| 11 | BIND | Bind player to location |
| 12 | PORTAL | Create portal object |
| 16 | QUEST_COMPLETE | Complete quest by ID |
| 17 | WEAPON_DAMAGE_NOSCHOOL | Flat weapon damage (physical) |
| 18 | RESURRECT | Resurrect target |
| 19 | ADD_EXTRA_ATTACKS | Grant extra attacks |
| 20 | DODGE | Guaranteed dodge |
| 21 | EVADE | Force evade |
| 22 | PARRY | Guaranteed parry |
| 23 | BLOCK | Guaranteed block |
| 24 | CREATE_ITEM | Create item (EffectItemType) |
| 25 | WEAPON | Weapon proficiency |
| 26 | DEFENSE | Defense skill bonus |
| 27 | PERSISTENT_AREA_AURA | Ground AoE aura (dynamic object) |
| 28 | SUMMON | Summon creature/object |
| 29 | LEAP | Leap to target |
| 30 | ENERGIZE | Restore power |
| 31 | WEAPON_PERCENT_DAMAGE | Weapon damage as % |
| 32 | TRIGGER_MISSILE | Launch triggered projectile spell |
| 33 | OPEN_LOCK | Lockpick / open |
| 35 | APPLY_AREA_AURA_PARTY | Aura affecting party members in radius |
| 36 | LEARN_SPELL | Teach spell to target |
| 37 | SPELL_DEFENSE | Unused |
| 38 | DISPEL | Dispel one aura type |
| 39 | LANGUAGE | Teach language |
| 40 | DUAL_WIELD | Enable dual wield |
| 41 | JUMP | Jump to position |
| 42 | JUMP_DEST | Jump to destination |
| 44 | SKILL_STEP | Increase skill |
| 45 | ADD_HONOR | Grant honor points |
| 53 | ENCHANT_ITEM | Apply permanent enchant |
| 54 | ENCHANT_ITEM_TEMPORARY | Apply temporary enchant |
| 55 | TAMECREATURE | Tame beast |
| 56 | SUMMON_PET | Summon player pet |
| 58 | WEAPON_DAMAGE | Weapon damage (with school) |
| 60 | PROFICIENCY | Grant weapon/armor proficiency |
| 61 | SEND_EVENT | Fire server-side event |
| 62 | POWER_BURN | Burn power, deal proportional damage |
| 63 | THREAT | Modify threat |
| 64 | TRIGGER_SPELL | Cast another spell immediately |
| 65 | APPLY_AREA_AURA_RAID | Aura affecting raid members in radius |
| 67 | HEAL_MAX_HEALTH | Heal to full HP |
| 68 | INTERRUPT_CAST | Interrupt target's cast |
| 69 | DISTRACT | Force target to face caster |
| 70 | PULL | Pull target to caster |
| 71 | PICKPOCKET | Pickpocket target |
| 77 | SCRIPT_EFFECT | Custom C++ script effect |
| 78 | ATTACK | Force melee attack |
| 80 | ADD_COMBO_POINTS | Grant combo points |
| 85 | SUMMON_PLAYER | Summon player |
| 90 | KILL_CREDIT | Grant quest kill credit |
| 92 | ENCHANT_HELD_ITEM | Enchant held item |
| 94 | SELF_RESURRECT | Self-resurrection (soulstone) |
| 95 | SKINNING | Skinning action |
| 96 | CHARGE | Charge to target |
| 98 | KNOCK_BACK | Knock target away |
| 99 | DISENCHANT | Disenchant item |
| 103 | REPUTATION | Grant reputation |
| 108 | DISPEL_MECHANIC | Dispel by mechanic type |
| 109 | RESURRECT_PET | Resurrect pet |
| 119 | APPLY_AREA_AURA_PET | Aura affecting pet in radius |
| 121 | NORMALIZED_WEAPON_DMG | Normalized weapon damage |
| 123 | SEND_TAXI | Send player on taxi |
| 128 | APPLY_AREA_AURA_FRIEND | Aura affecting friendly targets in radius |
| 129 | APPLY_AREA_AURA_ENEMY | Aura affecting enemy targets in radius |
| 136 | HEAL_PCT | Heal for % of max HP |
| 137 | ENERGIZE_PCT | Restore % of max power |
| 138 | LEAP_BACK | Leap backward (knockback self) |
| 142 | TRIGGER_SPELL_WITH_VALUE | Trigger spell, pass value to it |
| 143 | APPLY_AREA_AURA_OWNER | Aura affecting pet owner in radius |
| 146 | ACTIVATE_RUNE | Activate Death Knight rune |
| 149 | CHARGE_DEST | Charge to destination |
| 155 | TITAN_GRIP | Enable Titan's Grip (two 2H weapons) |
| 156 | ENCHANT_ITEM_PRISMATIC | Apply prismatic socket enchant |
| 157 | CREATE_ITEM_2 | Create item (alternate) |
| 158 | MILLING | Milling profession action |
| 161 | TALENT_SPEC_COUNT | Set number of talent specs |
| 162 | TALENT_SPEC_SELECT | Select active talent spec |
| 164 | REMOVE_AURA | Remove aura from target |

---

## 4. AuraTypes Enum

C++ constant: `AuraType`. DB field: `EffectApplyAuraName1`–`3`. Used with `SPELL_EFFECT_APPLY_AURA` (6).

| ID | Constant | Description |
|----|----------|-------------|
| 0 | NONE | No aura |
| 1 | BIND_SIGHT | Share caster's vision |
| 2 | MOD_POSSESS | Mind control target |
| 3 | PERIODIC_DAMAGE | DoT tick damage |
| 4 | DUMMY | Script hook aura |
| 5 | MOD_CONFUSE | Confuse (wander randomly) |
| 6 | MOD_CHARM | Charm (AI controlled by caster) |
| 7 | MOD_FEAR | Fear (flee) |
| 8 | PERIODIC_HEAL | HoT tick healing |
| 9 | MOD_ATTACKSPEED | Modify melee attack speed |
| 10 | MOD_THREAT | Flat threat modifier |
| 11 | MOD_TAUNT | Force target to attack caster |
| 12 | MOD_STUN | Stun (cannot act) |
| 13 | MOD_DAMAGE_DONE | Flat damage bonus (outgoing) |
| 14 | MOD_DAMAGE_TAKEN | Flat damage modifier (incoming) |
| 15 | DAMAGE_SHIELD | Return damage on melee hit |
| 16 | MOD_STEALTH | Enter stealth |
| 17 | MOD_STEALTH_DETECT | Increase stealth detection |
| 18 | MOD_INVISIBILITY | Enter invisibility |
| 19 | MOD_INVISIBILITY_DETECTION | Detect invisible units |
| 20 | OBS_MOD_HEALTH | Observe/modify health (used by some heals) |
| 21 | OBS_MOD_POWER | Observe/modify power |
| 22 | MOD_RESISTANCE | Flat resistance bonus |
| 23 | PERIODIC_TRIGGER_SPELL | Trigger spell on each tick |
| 24 | PERIODIC_ENERGIZE | Restore power on each tick |
| 25 | MOD_PACIFY | Pacify (cannot attack, can cast) |
| 26 | MOD_ROOT | Root (cannot move) |
| 27 | MOD_SILENCE | Silence (cannot cast) |
| 28 | REFLECT_SPELLS | Chance to reflect spells |
| 29 | MOD_STAT | Modify primary stat |
| 30 | MOD_SKILL | Modify skill value |
| 31 | MOD_INCREASE_SPEED | Increase run speed |
| 32 | MOD_INCREASE_MOUNTED_SPEED | Increase mounted speed |
| 33 | MOD_DECREASE_SPEED | Decrease movement speed (snare) |
| 34 | MOD_INCREASE_HEALTH | Flat max HP increase |
| 35 | MOD_INCREASE_ENERGY | Flat max power increase |
| 36 | MOD_SHAPESHIFT | Apply shapeshift form |
| 37 | EFFECT_IMMUNITY | Immunity to specific spell effect |
| 38 | STATE_IMMUNITY | Immunity to aura state |
| 39 | SCHOOL_IMMUNITY | Immunity to school damage |
| 40 | DAMAGE_IMMUNITY | Immunity to damage type |
| 41 | DISPEL_IMMUNITY | Immunity to dispel type |
| 42 | PROC_TRIGGER_SPELL | Trigger spell on proc condition |
| 43 | PROC_TRIGGER_DAMAGE | Deal damage on proc condition |
| 44 | TRACK_CREATURES | Track creature type on minimap |
| 45 | TRACK_RESOURCES | Track resources on minimap |
| 47 | MOD_PARRY_PERCENT | % parry chance modifier |
| 49 | MOD_DODGE_PERCENT | % dodge chance modifier |
| 52 | MOD_CRITICAL_HEALING_AMOUNT | Flat critical heal bonus |
| 53 | MOD_BLOCK_PERCENT | % block chance modifier |
| 54 | MOD_CRIT_PERCENT | % melee/ranged crit modifier |
| 56 | PERIODIC_LEECH | Drain HP on each tick (life drain) |
| 57 | MOD_HIT_CHANCE | % melee hit modifier |
| 58 | MOD_SPELL_HIT_CHANCE | % spell hit modifier |
| 59 | TRANSFORM | Transform appearance to creature model |
| 60 | MOD_SPELL_CRIT_CHANCE | % spell crit chance modifier |
| 61 | MOD_INCREASE_SWIM_SPEED | Increase swim speed |
| 62 | MOD_DAMAGE_DONE_CREATURE | Damage bonus vs creature type |
| 63 | MOD_PACIFY_SILENCE | Pacify and silence simultaneously |
| 64 | MOD_SCALE | Scale unit size |
| 65 | PERIODIC_HEALTH_FUNNEL | Transfer HP to caster periodically |
| 67 | PERIODIC_MANA_LEECH | Drain mana on each tick |
| 68 | MOD_CASTING_SPEED_NOT_STACK | Cast speed modifier (non-stacking) |
| 69 | FEIGN_DEATH | Feign death state |
| 70 | MOD_DISARM | Disarm main hand |
| 72 | MOD_RESISTANCE_EXCLUSIVE | Exclusive resistance modifier |
| 74 | SCHOOL_ABSORB | Absorb school damage (shields) |
| 77 | MOD_MANA_REGEN_INTERRUPT | Mana regen even when casting |
| 78 | MOD_HEALING_DONE | Flat healing power bonus |
| 79 | MOD_HEALING_DONE_PERCENT | % healing power bonus |
| 80 | MOD_TOTAL_STAT_PERCENTAGE | % modifier to total stat |
| 81 | MOD_MELEE_HASTE_PERCENT | % melee haste modifier |
| 84 | MOD_ATTACK_POWER | Flat attack power bonus |
| 85 | AURAS_VISIBLE | Force auras to be visible |
| 86 | MOD_RESISTANCE_PCT | % resistance modifier |
| 87 | MOD_MELEE_ATTACK_POWER_VERSUS | AP bonus vs creature type |
| 88 | MOD_TOTAL_THREAT | % total threat modifier |
| 89 | WATER_WALK | Walk on water |
| 90 | FEATHER_FALL | Slow fall |
| 91 | HOVER | Hover above ground |
| 92 | ADD_FLAT_MODIFIER | Add flat value to spell modifier |
| 93 | ADD_PCT_MODIFIER | Add % value to spell modifier |
| 97 | MOD_POWER_REGEN | Flat power regeneration bonus |
| 98 | CHANNEL_DEATH_ITEM | Create item on target death during channel |
| 99 | MOD_DAMAGE_PERCENT_TAKEN | % damage taken modifier |
| 100 | MOD_HEALTH_REGEN_PERCENT | % health regen modifier |
| 101 | PERIODIC_DAMAGE_PERCENT | DoT dealing % of max HP per tick |
| 104 | MOD_DETECT_RANGE | Modify aggro detection range |
| 105 | PREVENTS_FLEEING | Prevent target from fleeing |
| 107 | MOD_SPELL_DAMAGE_OF_STAT_PERCENT | Spell damage as % of a stat |
| 108 | MOD_SPELL_HEALING_OF_STAT_PERCENT | Spell healing as % of a stat |
| 113 | MOD_DEBUFF_RESISTANCE | Resistance to debuff mechanic |
| 118 | MOD_POWER_COST_SCHOOL | Modify power cost for school |
| 123 | MOD_RANGED_ATTACK_POWER | Flat ranged AP bonus |
| 124 | MOD_MELEE_DAMAGE_TAKEN | Flat melee damage taken modifier |
| 126 | RANGED_ATTACK_POWER_ATTACKER_BONUS | Attacker gains ranged AP from target |
| 129 | MOD_POSSESS_PET | Possess own pet |
| 130 | MOD_SPEED_ALWAYS | Speed modifier (stacks with everything) |
| 135 | MOD_FLIGHT_SPEED | Modify flying speed |
| 136 | MOD_FLIGHT_SPEED_MOUNTED | Modify mounted flying speed |
| 138 | MOD_FLIGHT_SPEED_NOT_STACK | Non-stacking flight speed modifier |
| 158 | MOD_RATING | Modify combat rating (hit, crit, haste, etc.) |
| 161 | MOD_ATTACKER_MELEE_HIT_CHANCE | Modify attacker's melee hit vs this unit |
| 176 | MOD_SPELL_DAMAGE_OF_ATTACK_POWER | Spell damage scales with AP |
| 180 | MOD_SPELL_HEALING_OF_ATTACK_POWER | Spell healing scales with AP |
| 189 | PROC_TRIGGER_SPELL_WITH_VALUE | Trigger spell on proc, passing magnitude |
| 192 | MECHANIC_IMMUNITY_MASK | Immunity to mechanic bitmask |
| 193 | PERIODIC_TRIGGER_SPELL_WITH_VALUE | Trigger spell on tick, passing value |
| 200 | SCREEN_EFFECT | Apply visual screen effect |
| 206 | PHASE | Place unit in phase |
| 224 | PERIODIC_DUMMY | Periodic script hook (no built-in logic) |
| 226 | OVERRIDE_SPELLS | Override spells in action bar |
| 240 | WORGEN_ALTERED_FORM | Worgen form flag |
| 255 | TRIGGER_SPELL_ON_EXPIRE | Trigger spell when aura expires |

---

## 5. Spell School Masks

Bitmask — multiple schools can be combined (e.g. Spellfire = FIRE|ARCANE = 68).

| Value | Name |
|-------|------|
| 1 | NORMAL (physical) |
| 2 | HOLY |
| 4 | FIRE |
| 8 | NATURE |
| 16 | FROST |
| 32 | SHADOW |
| 64 | ARCANE |

---

## 6. Dispel Types

| ID | Name | Notes |
|----|------|-------|
| 0 | NONE | Not dispellable |
| 1 | MAGIC | Dispel Magic, Mass Dispel |
| 2 | CURSE | Remove Curse |
| 3 | DISEASE | Cure Disease |
| 4 | POISON | Abolish Poison |
| 5 | STEALTH | Internal only |
| 6 | INVISIBILITY | Internal only |
| 7 | ALL | Matches any dispel type |
| 9 | ENRAGE | Consume Magic (warlock) |

---

## 7. Mechanic Types

| ID | Name | ID | Name |
|----|------|----|------|
| 0 | NONE | 16 | BANDAGE |
| 1 | CHARM | 17 | POLYMORPH |
| 2 | DISORIENTED | 18 | BANISH |
| 3 | DISARM | 19 | SHIELD |
| 4 | DISTRACT | 20 | SHACKLE |
| 5 | FEAR | 21 | MOUNT |
| 6 | GRIP | 22 | INFECTED |
| 7 | ROOT | 23 | TURN |
| 8 | SLOW_ATTACK | 24 | HORROR |
| 9 | SILENCE | 25 | INVULNERABILITY |
| 10 | SLEEP | 26 | INTERRUPT |
| 11 | SNARE | 27 | DAZE |
| 12 | STUN | 28 | DISCOVERY |
| 13 | FREEZE | 29 | IMMUNE_SHIELD |
| 14 | KNOCKOUT | 30 | SAPPED |
| 15 | BLEED | 31 | ENRAGED |

---

## 8. SpellAttr0–7 Key Flags

Only the most practically important flags for module/script dev. Full lists are in `src/server/shared/SharedDefines.h`.

### SpellAttr0

| Hex | Constant | Meaning |
|-----|----------|---------|
| `0x00000010` | IS_ABILITY | Shown as ability, not spell |
| `0x00000040` | PASSIVE | Passive aura — auto-applied |
| `0x00000080` | DO_NOT_DISPLAY | Hidden from spell book |
| `0x00000400` | ON_NEXT_SWING | Triggers on next melee swing |
| `0x00800000` | ALLOW_CAST_WHILE_DEAD | Can cast when dead |
| `0x01000000` | ALLOW_WHILE_MOUNTED | Can cast while mounted |
| `0x04000000` | AURA_IS_DEBUFF | Aura is classified as debuff |
| `0x20000000` | NO_IMMUNITIES | Bypasses immunity checks |
| `0x40000000` | HEARTBEAT_RESIST | Periodic resistance roll |
| `0x80000000` | NO_AURA_CANCEL | Aura cannot be cancelled by player |

### SpellAttr1

| Hex | Constant | Meaning |
|-----|----------|---------|
| `0x00000004` | IS_CHANNELED | Channeled spell |
| `0x00000020` | ALLOW_WHILE_STEALTHED | Can cast while stealthed |
| `0x00000040` | IS_SELF_CHANNELED | Self-targeted channel |
| `0x00000400` | NO_THREAT | Generates no threat |
| `0x00000800` | AURA_UNIQUE | Only one instance per caster |
| `0x00080000` | EXCLUDE_CASTER | AoE excludes caster |
| `0x02000000` | AURA_STAYS_AFTER_COMBAT | Aura persists out of combat |
| `0x10000000` | NO_AURA_ICON | No icon shown for aura |

### SpellAttr2

| Hex | Constant | Meaning |
|-----|----------|---------|
| `0x00000004` | IGNORE_LINE_OF_SIGHT | Ignores LoS check |
| `0x00000020` | AUTO_REPEAT | Auto-repeating spell (auto-shot) |
| `0x20000000` | CANT_CRIT | Spell cannot critically strike |

### SpellAttr3

| Hex | Constant | Meaning |
|-----|----------|---------|
| `0x00000020` | NO_DURABILITY_LOSS | No durability loss on death |
| `0x00000080` | DOT_STACKING_RULE | DoT creates independent stack per caster |
| `0x00040000` | ALWAYS_HIT | Spell cannot miss |
| `0x00100000` | ALLOW_AURA_WHILE_DEAD | Aura persists through death |

### SpellAttr4

| Hex | Constant | Meaning |
|-----|----------|---------|
| `0x00000040` | CANNOT_BE_STOLEN | Spell theft cannot take this aura |
| `0x00000080` | ALLOW_CAST_WHILE_CASTING | Can be cast while another spell is casting |
| `0x00004000` | DAMAGE_DOESNT_BREAK_AURAS | Damage will not break this aura (e.g. sleep) |
| `0x00010000` | NOT_IN_ARENA_OR_RATED_BG | Disabled in arenas/rated BGs |
| `0x00800000` | SUPPRESS_WEAPON_PROCS | Weapon enchant procs suppressed |

### SpellAttr5

| Hex | Constant | Meaning |
|-----|----------|---------|
| `0x00000008` | ALLOW_WHILE_STUNNED | Can be cast while stunned |
| `0x00002000` | SPELL_HASTE_AFFECTS_PERIODIC | Haste reduces periodic interval |
| `0x00020000` | ALLOW_WHILE_FLEEING | Can be cast while fleeing |
| `0x00040000` | ALLOW_WHILE_CONFUSED | Can be cast while confused |

### SpellAttr6

| Hex | Constant | Meaning |
|-----|----------|---------|
| `0x00000004` | NOT_AN_ATTACK | Does not trigger combat |
| `0x00000020` | DO_NOT_CONSUME_RESOURCES | Costs no resources (debug/GM) |
| `0x00008000` | NO_PUSHBACK | Immune to spell pushback |
| `0x01000000` | CAN_TARGET_UNTARGETABLE | Can hit untargetable units |

### SpellAttr7

| Hex | Constant | Meaning |
|-----|----------|---------|
| `0x00000010` | TREAT_AS_RAID_BUFF | Counted as raid-wide buff |
| `0x00000100` | HORDE_SPECIFIC_SPELL | Only usable by Horde |
| `0x00000200` | ALLIANCE_SPECIFIC_SPELL | Only usable by Alliance |
| `0x00000800` | CAN_CAUSE_INTERRUPT | Can interrupt spell cast |
| `0x00001000` | CAN_CAUSE_SILENCE | Can silence |
| `0x08000000` | BYPASS_NO_RESURRECTION_AURA | Ignores spirit of redemption restriction |

---

## 9. spell_proc Table

DB: `acore_world.spell_proc`. Overrides proc behavior for spells with `SPELL_AURA_PROC_TRIGGER_SPELL` (42) or `SPELL_AURA_PROC_TRIGGER_DAMAGE` (43). If no row exists, the spell uses `procFlags` and `procChance` from `spell_dbc`/DBC directly.

| Column | Type | Description |
|--------|------|-------------|
| `entry` | MEDIUMINT UNSIGNED | Spell ID (PK) |
| `SchoolMask` | TINYINT UNSIGNED | School that triggers the proc (0=any) |
| `SpellFamilyName` | SMALLINT UNSIGNED | Spell family the triggering spell must belong to |
| `SpellFamilyMask0` | INT UNSIGNED | Spell family flag word 0 filter |
| `SpellFamilyMask1` | INT UNSIGNED | Spell family flag word 1 filter |
| `SpellFamilyMask2` | INT UNSIGNED | Spell family flag word 2 filter |
| `procFlags` | INT UNSIGNED | Proc trigger condition bitmask (see below) |
| `procEx` | INT UNSIGNED | Extended proc condition (crit-only, non-crit, etc.) |
| `ppmRate` | FLOAT | Procs-per-minute rate (0 = use chance instead) |
| `CustomChance` | FLOAT | Override proc chance % (0 = use spell's procChance) |
| `Cooldown` | INT UNSIGNED | Internal cooldown between procs in ms |

### ProcFlags Bitmask

| Hex | Constant | Description |
|-----|----------|-------------|
| `0x00000000` | NONE | Never procs |
| `0x00000001` | KILLED | Unit was killed by aggressor |
| `0x00000002` | KILL | Killed another unit (XP/Honor eligible) |
| `0x00000004` | DONE_MELEE_AUTO_ATTACK | Landed a melee auto-attack |
| `0x00000008` | TAKEN_MELEE_AUTO_ATTACK | Received a melee auto-attack |
| `0x00000010` | DONE_SPELL_MELEE_DMG_CLASS | Cast a spell with melee damage class |
| `0x00000020` | TAKEN_SPELL_MELEE_DMG_CLASS | Hit by a melee-class spell |
| `0x00000040` | DONE_RANGED_AUTO_ATTACK | Fired a ranged auto-attack |
| `0x00000080` | TAKEN_RANGED_AUTO_ATTACK | Hit by a ranged auto-attack |
| `0x00000100` | DONE_SPELL_RANGED_DMG_CLASS | Cast a ranged damage class spell |
| `0x00000200` | TAKEN_SPELL_RANGED_DMG_CLASS | Hit by a ranged class spell |
| `0x00000400` | DONE_SPELL_NONE_DMG_CLASS_POS | Cast a positive non-damage spell |
| `0x00000800` | TAKEN_SPELL_NONE_DMG_CLASS_POS | Received a positive non-damage spell |
| `0x00001000` | DONE_SPELL_NONE_DMG_CLASS_NEG | Cast a negative non-damage spell |
| `0x00002000` | TAKEN_SPELL_NONE_DMG_CLASS_NEG | Hit by a negative non-damage spell |
| `0x00004000` | DONE_SPELL_MAGIC_DMG_CLASS_POS | Cast a positive magic spell |
| `0x00008000` | TAKEN_SPELL_MAGIC_DMG_CLASS_POS | Received a positive magic spell |
| `0x00010000` | DONE_SPELL_MAGIC_DMG_CLASS_NEG | Cast a negative magic spell |
| `0x00020000` | TAKEN_SPELL_MAGIC_DMG_CLASS_NEG | Hit by a negative magic spell |
| `0x00040000` | DONE_PERIODIC | Periodic damage or heal tick landed |
| `0x00080000` | TAKEN_PERIODIC | Received a periodic effect tick |
| `0x00100000` | TAKEN_DAMAGE | Took any damage |
| `0x00200000` | DONE_TRAP_ACTIVATION | Activated a trap |
| `0x00400000` | DONE_MAINHAND_ATTACK | Landed a main-hand melee attack |
| `0x00800000` | DONE_OFFHAND_ATTACK | Landed an off-hand melee attack |
| `0x01000000` | DEATH | Unit died |

### procEx Bitmask

| Hex | Meaning |
|-----|---------|
| `0x00000000` | Normal hit |
| `0x00000001` | No result (internal) |
| `0x00000002` | Miss |
| `0x00000004` | Dodge |
| `0x00000008` | Parry |
| `0x00000010` | Block |
| `0x00000020` | Evade |
| `0x00000040` | Immune |
| `0x00000080` | Deflect |
| `0x00000100` | Absorb |
| `0x00000200` | Reflect |
| `0x00000400` | Interrupt |
| `0x00010000` | Normal hit (positive filter) |
| `0x00020000` | Critical strike |
| `0x00040000` | Periodic only |
| `0x00080000` | On direct damage only |
| `0x00100000` | Not active aura (triggered) |

---

## 10. spell_linked_spell Table

DB: `world.spell_linked_spell`. Links two spells so that applying, removing, or casting one automatically triggers an effect on another.

| Column | Type | Description |
|--------|------|-------------|
| `spell_trigger` | MEDIUMINT SIGNED | Spell that triggers the link. **Negative**: fires when the aura from `abs(spell_trigger)` is **removed** |
| `spell_effect` | MEDIUMINT SIGNED | Spell to apply/cast/remove. **Negative**: removes the aura `abs(spell_effect)` from target instead of casting it |
| `type` | SMALLINT UNSIGNED | Link type (0/1/2 — see below) |
| `comment` | TEXT | Description of what this link does |

### Type Values

| Type | Name | Behavior |
|------|------|----------|
| 0 | CAST | When `spell_trigger` is **cast**, cast `spell_effect` on the same target |
| 1 | HIT | When `spell_trigger` **hits** the target, cast `spell_effect` |
| 2 | AURA | When aura from `spell_trigger` is **applied OR removed**, cast/remove `spell_effect` |

### Negative ID Logic

| Scenario | spell_trigger | spell_effect | Result |
|----------|--------------|-------------|--------|
| On removal of trigger aura | `-12345` | `67890` | When aura 12345 is removed from target, cast spell 67890 |
| Remove aura on trigger | `12345` | `-67890` | When spell 12345 hits, remove aura 67890 from target |
| Both negative | `-12345` | `-67890` | When aura 12345 is removed, also remove aura 67890 |

### SQL Examples

```sql
-- When spell 12 (Lightning Shield) is applied, also apply spell 324 (Lightning Shield visual):
INSERT INTO spell_linked_spell (spell_trigger, spell_effect, type, comment)
VALUES (12, 324, 2, 'Lightning Shield - apply visual aura on apply');

-- When spell 12 aura is removed, remove spell 324 aura too:
INSERT INTO spell_linked_spell (spell_trigger, spell_effect, type, comment)
VALUES (-12, -324, 2, 'Lightning Shield - remove visual aura on remove');

-- When casting spell 1234 (Heroism), apply exhaustion debuff 57723:
INSERT INTO spell_linked_spell (spell_trigger, spell_effect, type, comment)
VALUES (1234, 57723, 0, 'Heroism - apply Exhaustion on cast');
```

---

## 11. Cross-References

- **C++ SpellScript / AuraScript API** → `05b_spell_scripting.md`
- Script base class registration → `01_module_system.md`
- `spell_script_names` table (links spell IDs to script names) → `11_database_schema.md`
- Item spell triggers (`spelltrigger_1`–`5`) → `06_item_system.md`
- SmartAI SMART_ACTION_CAST / SMART_ACTION_ADD_AURA → `10_smartai_system.md`

---

*Last updated: 2026-03-18*
