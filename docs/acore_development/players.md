# Player System

> Comprehensive reference for WoW 3.3.5a (WotLK, AzerothCore) player architecture: database schema, stats system, race/class definitions, talent system, C++ hooks, and player manipulation APIs.

---

## Table of Contents

1. [characters Table](#1-characters-table)
2. [Player Stats System](#2-player-stats-system)
3. [Race & Class System](#3-race--class-system)
4. [Talent System](#4-talent-system)
5. [PlayerScript Hooks (C++)](#5-playerscript-hooks-c)
6. [Player Modification via C++](#6-player-modification-via-c)
7. [Chat Commands System](#7-chat-commands-system)
8. [GroupScript & GuildScript](#8-groupscript--guildscript)
9. [Honor & Arena System](#9-honor--arena-system)
10. [Achievement System](#10-achievement-system)
11. [Cross-References](#11-cross-references)

---

## 1. characters Table

**Database:** `characters`
**Primary key:** `guid`

This is the central row for every character. It is loaded into memory as a `Player` object on login and saved on logout/periodic save. Some columns are safe to modify directly via SQL while the server is down; others require in-process C++ calls because the server caches their values in memory.

### 1.1 Complete Column Reference

| Column | Type | Default | Description | Safe to Edit Offline? |
|--------|------|---------|-------------|----------------------|
| `guid` | INT UNSIGNED | 0 (PK) | Global unique character identifier | NO — primary key |
| `account` | INT UNSIGNED | 0 | Owner account ID (references `auth.account.id`) | Only when server is down |
| `name` | VARCHAR(12) | — | Character name, max 12 chars | With `at_login` rename flag |
| `race` | TINYINT UNSIGNED | 0 | Race ID (see §3.1). References `ChrRaces.dbc` | NO — requires full relog + recalc |
| `class` | TINYINT UNSIGNED | 0 | Class ID (see §3.2). References `ChrClasses.dbc` | NO |
| `gender` | TINYINT UNSIGNED | 0 | 0=Male, 1=Female, 2=Unknown | With `at_login` customize flag |
| `level` | TINYINT UNSIGNED | 0 | Character level (1–80) | YES — use `GiveLevel()` in-process to get stat recalc |
| `xp` | INT UNSIGNED | 0 | Experience points toward next level | YES (server is down) |
| `money` | INT UNSIGNED | 0 | Wealth in copper. 1 gold = 10000 copper | YES — but prefer `ModifyMoney()` |
| `skin` | TINYINT UNSIGNED | 0 | Skin color (`playerBytes % 256`) | With `at_login` customize flag |
| `face` | TINYINT UNSIGNED | 0 | Face style (`(playerBytes >> 8) % 256`) | With `at_login` customize flag |
| `hairStyle` | TINYINT UNSIGNED | 0 | Hair style (`(playerBytes >> 16) % 256`) | With `at_login` customize flag |
| `hairColor` | TINYINT UNSIGNED | 0 | Hair color (`(playerBytes >> 24) % 256`) | With `at_login` customize flag |
| `facialStyle` | TINYINT UNSIGNED | 0 | Facial hair / features (`playerBytes2 % 256`) | With `at_login` customize flag |
| `bankSlots` | TINYINT UNSIGNED | 0 | Number of purchased extra bank bag slots (0–6) | YES |
| `restState` | TINYINT UNSIGNED | 0 | Rested XP accumulation state | YES |
| `playerflags` | INT UNSIGNED | 0 | Bitmask of player flags (see §1.2) | With care |
| `position_x` | FLOAT | 0 | World X coordinate | YES (server down) |
| `position_y` | FLOAT | 0 | World Y coordinate | YES (server down) |
| `position_z` | FLOAT | 0 | World Z coordinate | YES (server down) |
| `map` | SMALLINT UNSIGNED | 0 | Map ID of current location | YES (server down) |
| `instance_id` | INT UNSIGNED | 0 | Current instance binding ID | YES (server down) |
| `instance_mode_mask` | TINYINT UNSIGNED | 0 | Dungeon difficulty bitmask: 0=Normal, 1=Heroic, 16=10-man raid, 32=25-man raid | YES |
| `orientation` | FLOAT | 0 | Facing direction in radians (North=0, South=π≈3.14159) | YES (server down) |
| `taximask` | TEXT | — | Space-separated list of known taxi node IDs | YES |
| `online` | TINYINT UNSIGNED | 0 | 1 if currently online, 0 if offline. Server manages this | NO — server-managed |
| `cinematic` | TINYINT UNSIGNED | 0 | 1 = opening cinematic has been shown | YES |
| `totaltime` | INT UNSIGNED | 0 | Total played time in seconds | YES |
| `leveltime` | INT UNSIGNED | 0 | Played time at current level in seconds | YES |
| `logout_time` | INT UNSIGNED | 0 | Unix timestamp of last logout | Server-managed |
| `is_logout_resting` | TINYINT UNSIGNED | 0 | 1 = logged out in a resting zone (inn/city) | Server-managed |
| `rest_bonus` | FLOAT | 0 | Accumulated rested XP bonus rate | YES |
| `resettalents_cost` | INT UNSIGNED | 0 | Copper cost of next talent reset | YES |
| `resettalents_time` | INT UNSIGNED | 0 | Unix timestamp of last talent reset (for decay timer) | YES |
| `trans_x` | FLOAT | 0 | X position relative to transport at save time | Server-managed |
| `trans_y` | FLOAT | 0 | Y position relative to transport | Server-managed |
| `trans_z` | FLOAT | 0 | Z position relative to transport | Server-managed |
| `trans_o` | FLOAT | 0 | Orientation relative to transport | Server-managed |
| `transguid` | MEDIUMINT | 0 | GUID of the transport the player is on | Server-managed |
| `extra_flags` | SMALLINT UNSIGNED | 0 | GM/debug feature bitmask (see §1.3) | With care |
| `stable_slots` | TINYINT UNSIGNED | 0 | Number of purchased hunter stable slots (0–4) | YES |
| `at_login` | SMALLINT UNSIGNED | 0 | Actions to perform on next login (see §1.4) | YES — primary admin tool |
| `zone` | SMALLINT UNSIGNED | 0 | Current zone ID | Server-managed |
| `death_expire_time` | INT UNSIGNED | 0 | Unix timestamp when character can be resurrected (spirit healer timer) | YES |
| `taxi_path` | TEXT | NULL | Current in-progress taxi path (TaxiPath.dbc reference) | Server-managed |
| `arenaPoints` | INT UNSIGNED | 0 | Unspent arena points | YES — prefer `ModifyArenaPoints()` |
| `totalHonorPoints` | INT UNSIGNED | 0 | Total lifetime honor accumulated | YES — prefer `ModifyHonorPoints()` |
| `todayHonorPoints` | INT UNSIGNED | 0 | Honor earned today | Server-managed |
| `yesterdayHonorPoints` | INT UNSIGNED | 0 | Honor earned yesterday | Server-managed |
| `totalKills` | INT UNSIGNED | 0 | Total PvP kills | YES |
| `todayKills` | SMALLINT UNSIGNED | 0 | PvP kills today | Server-managed |
| `yesterdayKills` | SMALLINT UNSIGNED | 0 | PvP kills yesterday | Server-managed |
| `chosenTitle` | INT UNSIGNED | 0 | Currently displayed title (bit index from CharTitles.dbc) | YES |
| `knownCurrencies` | BIGINT UNSIGNED | 0 | Bitmask of known currency types (BitIndex field) | YES |
| `watchedFaction` | INT UNSIGNED | 0 | Faction ID shown in the XP bar as tracked reputation | YES |
| `drunk` | TINYINT UNSIGNED | 0 | Intoxication level: 0=Sober, 1–49=Tipsy, 50–89=Drunk, 90–100=Smashed | YES |
| `health` | INT UNSIGNED | 0 | Current HP at time of last save | YES (server down) |
| `power1` | INT UNSIGNED | 0 | Mana | YES (server down) |
| `power2` | INT UNSIGNED | 0 | Rage (0–1000 internal, 0–100 displayed) | YES |
| `power3` | INT UNSIGNED | 0 | Focus (hunters only) | YES |
| `power4` | INT UNSIGNED | 0 | Energy | YES |
| `power5` | INT UNSIGNED | 0 | Happiness (hunter pets) | YES |
| `power6` | INT UNSIGNED | 0 | Runes (Death Knight) | YES |
| `power7` | INT UNSIGNED | 0 | Runic Power (Death Knight) | YES |
| `latency` | MEDIUMINT UNSIGNED | 0 | Last-known ping in milliseconds | Server-managed |
| `talentGroupsCount` | TINYINT UNSIGNED | 1 | Number of talent specs purchased: 1 (default) or 2 (dual spec) | YES — set 2 to grant dual spec |
| `activeTalentGroup` | TINYINT UNSIGNED | 0 | Active spec slot: 0 (primary) or 1 (secondary) | Server-managed |
| `exploredZones` | LONGTEXT | NULL | Bitmask data for explored map zones | Server-managed |
| `equipmentCache` | LONGTEXT | NULL | Serialized equipment and bag slot cache for character selection screen | Server-managed |
| `ammoId` | INT UNSIGNED | 0 | Item template ID of equipped ammo (hunters/warriors) | YES |
| `knownTitles` | LONGTEXT | NULL | Known titles encoded as six 16-bit integers | YES |
| `actionBars` | TINYINT UNSIGNED | 0 | Bitmask of visible extra action bars (bits 0–3 = bars 5–8) | YES |
| `grantableLevels` | TINYINT UNSIGNED | 0 | Levels grantable via Recruit-A-Friend system | YES |
| `order` | TINYINT | NULL | Character list display order; NULL = sort by guid | YES |
| `creation_date` | TIMESTAMP | CURRENT_TIMESTAMP | Character creation timestamp | Read-only |
| `deleteInfos_Account` | INT UNSIGNED | NULL | Account ID of a deleted character (for recovery) | YES |
| `deleteInfos_Name` | VARCHAR(12) | NULL | Name of deleted character | YES |
| `deleteDate` | INT UNSIGNED | NULL | Unix timestamp of deletion (used for purge scheduling) | YES |

### 1.2 playerflags Bitmask

| Bit | Hex | Name | Effect |
|-----|-----|------|--------|
| 0 | 0x01 | PLAYER_FLAGS_GROUP_LEADER | Shows leader crown |
| 1 | 0x02 | PLAYER_FLAGS_AFK | AFK flag |
| 2 | 0x04 | PLAYER_FLAGS_DND | Do Not Disturb |
| 3 | 0x08 | PLAYER_FLAGS_GM | Shows GM tag |
| 4 | 0x10 | PLAYER_FLAGS_GHOST | Spirit form after death |
| 5 | 0x20 | PLAYER_FLAGS_RESTING | Rested state indicator |
| 6 | 0x40 | PLAYER_FLAGS_UNK6 | Unknown/unused |
| 7 | 0x80 | PLAYER_FLAGS_FFA_PVP | Free-for-all PvP mode |
| 8 | 0x100 | PLAYER_FLAGS_CONTESTED_PVP | Contested zone PvP |
| 9 | 0x200 | PLAYER_FLAGS_IN_PVP | In PvP combat |
| 10 | 0x400 | PLAYER_FLAGS_HIDE_HELM | Hide helmet option |
| 11 | 0x800 | PLAYER_FLAGS_HIDE_CLOAK | Hide cloak option |
| 12 | 0x1000 | PLAYER_FLAGS_PARTIAL_PLAY_TIME | Partial play time flag |
| 13 | 0x2000 | PLAYER_FLAGS_NO_PLAY_TIME | Play time exhausted |
| 16 | 0x10000 | PLAYER_FLAGS_SANCTUARY | In sanctuary zone |
| 17 | 0x20000 | PLAYER_FLAGS_TAXI_BENCHMARK | Taxi benchmark mode |
| 18 | 0x40000 | PLAYER_FLAGS_PVP_TIMER | PvP timer active |

### 1.3 extra_flags Bitmask

| Bit | Hex | Name |
|-----|-----|------|
| 0 | 0x01 | PLAYER_EXTRA_GM_ON — GM mode active |
| 1 | 0x02 | PLAYER_EXTRA_ACCEPT_WHISPERS — GM accepts whispers |
| 2 | 0x04 | PLAYER_EXTRA_TAXICHEAT — fly anywhere via taxi |
| 3 | 0x08 | PLAYER_EXTRA_GM_INVISIBLE — invisible to players |
| 4 | 0x10 | PLAYER_EXTRA_GM_CHAT — GM tag in chat |
| 5 | 0x20 | PLAYER_EXTRA_HAS_310_FLYER — owns 310% mount |
| 6 | 0x40 | PLAYER_EXTRA_SPECTATOR_ON — arena spectator |
| 7 | 0x80 | PLAYER_EXTRA_INVISIBLE_STATUS — full-stealth GM |
| 8 | 0x100 | PLAYER_EXTRA_PVP_DEATH — death in PvP |

### 1.4 at_login Flags

These flags cause automatic actions when the character next logs in. Safe to set offline via SQL.

| Bit | Hex | Effect |
|-----|-----|--------|
| 0 | 0x01 | AT_LOGIN_RENAME — force name change |
| 1 | 0x02 | AT_LOGIN_RESET_SPELLS — reset all learned spells |
| 2 | 0x04 | AT_LOGIN_RESET_TALENTS — reset talent points |
| 3 | 0x08 | AT_LOGIN_CUSTOMIZE — allow appearance customization |
| 4 | 0x10 | AT_LOGIN_RESET_PET_TALENTS — reset pet talents |
| 5 | 0x20 | AT_LOGIN_FIRST — is first login (tutorial/cinematic) |
| 6 | 0x40 | AT_LOGIN_CHANGE_FACTION — allow faction change |
| 7 | 0x80 | AT_LOGIN_CHANGE_RACE — allow race change |

**Example usage:**
```sql
-- Force talent reset on next login:
UPDATE characters SET at_login = at_login | 4 WHERE guid = 12345;

-- Allow appearance customization:
UPDATE characters SET at_login = at_login | 8 WHERE guid = 12345;

-- Grant dual spec by setting talentGroupsCount:
UPDATE characters SET talentGroupsCount = 2 WHERE guid = 12345;
```

---

## 2. Player Stats System

### 2.1 player_levelstats Table

**Database:** `world`

Stores the five primary stats for each combination of class, race, and level. These are the *base* stats before gear, buffs, or racial bonuses.

| Column | Type | Description |
|--------|------|-------------|
| `race` | TINYINT UNSIGNED (PK) | Race ID (see §3.1) |
| `class` | TINYINT UNSIGNED (PK) | Class ID (see §3.2) |
| `level` | TINYINT UNSIGNED (PK) | Character level (1–80) |
| `str` | SMALLINT UNSIGNED | Base Strength |
| `agi` | SMALLINT UNSIGNED | Base Agility |
| `sta` | SMALLINT UNSIGNED | Base Stamina |
| `inte` | SMALLINT UNSIGNED | Base Intellect |
| `spi` | SMALLINT UNSIGNED | Base Spirit |

**Note:** This table contains one row per `(race, class, level)` triplet — 10 classes × 10 races (not all combinations valid) × 80 levels. Only valid race/class combos have rows. Custom stat tuning is done here.

### 2.2 player_classlevelstats Table

**Database:** `world`

Stores base HP and base mana per class per level. Does **not** include stamina/intellect bonuses — those stack on top.

| Column | Type | Description |
|--------|------|-------------|
| `class` | TINYINT UNSIGNED (PK) | Class ID (see §3.2) |
| `level` | TINYINT UNSIGNED (PK) | Character level (1–80) |
| `basehp` | INT UNSIGNED | Base health points at this level |
| `basemana` | INT UNSIGNED | Base mana at this level (0 for rage/energy users) |

**Warriors and rogues** have 0 base mana since they use Rage and Energy respectively.

### 2.3 How Stats Derive Combat Values

These are the formulas used by the AzerothCore engine. Coefficients are sourced from DBC files (`gtChanceToMeleeCrit.dbc`, `gtOCTRegenHP.dbc`, `gtRegenHPPerSpt.dbc`, etc.) and the game client data tables.

#### Stamina → Max Health

```
Max HP = basehp (from player_classlevelstats) + (Stamina × 10)
```

The first 20 points of Stamina grant 1 HP each. Points 21+ grant 10 HP each. In WotLK at level 80 all players are well above 20 Stamina, so effectively 10 HP per STA point.

#### Intellect → Max Mana

```
Max Mana = basemana (from player_classlevelstats) + (Intellect × 15)
```

The first 20 points of Intellect grant 1 mana each. Points 21+ grant 15 mana each. At level 80 effective rate is 15 mana per INT.

#### Strength → Melee Attack Power

Varies by class. Formulas (AP granted per 1 point of Strength):

| Class | Melee AP per STR |
|-------|-----------------|
| Warrior | 2 |
| Paladin | 2 |
| Death Knight | 2 |
| Hunter | 1 |
| Rogue | 1 |
| Shaman | 2 |
| Druid (Bear/Cat) | 2 |
| Druid (Caster) | 1 |
| Mage | 1 |
| Warlock | 1 |
| Priest | 1 |

#### Agility → Melee/Ranged Attack Power

| Class | Melee AP per AGI | Ranged AP per AGI |
|-------|-----------------|-------------------|
| Hunter | 1 | 2 |
| Rogue | 1 | 1 |
| Warrior | 0 | 0 |
| Druid (Cat) | 1 | 0 |
| All others | 0 | 0 |

#### Agility → Melee Crit Chance

Governed by `gtChanceToMeleeCrit.dbc`. Approximate values at level 80:

| Class | AGI per 1% Crit |
|-------|----------------|
| Warrior | ~33 AGI |
| Paladin | ~53 AGI |
| Hunter | ~53 AGI |
| Rogue | ~83 AGI |
| Druid | ~83 AGI |
| Shaman | ~53 AGI |
| Death Knight | ~33 AGI |

#### Agility → Dodge Chance

Governed by `gtChanceToDodge.dbc`. At level 80 roughly 30–45 AGI per 1% dodge depending on class. Rogues and Druids have the highest AGI-to-dodge conversion.

#### Intellect → Spell Crit Chance

Governed by `gtChanceToSpellCrit.dbc`. At level 80:

| Class | INT per 1% Spell Crit |
|-------|----------------------|
| Mage | ~166 INT |
| Priest | ~166 INT |
| Druid | ~166 INT |
| Shaman | ~166 INT |
| Warlock | ~166 INT |
| Paladin | ~166 INT |

#### Spirit → Mana Regeneration

Base mana regen (out of combat, per 5 seconds) uses `gtRegenMPPerSpt.dbc`:

```
MP5 = Spirit × (0.001 + sqrt(Intellect) × classCoefficient)
```

In-combat regeneration is a percentage of the base regen, modified by talents (e.g., Meditation for Priests/Druids gives 50% in-combat regen).

#### Spirit → Health Regeneration

```
HP5 (OOC) = Spirit × gtOCTRegenHP[class][level]
```

In-combat HP regen from spirit is near-zero for most classes without talents.

### 2.4 Gear Stats Stacking

Gear stats are **additive** on top of base stats. The pipeline is:

1. Load base stats from `player_levelstats` → `SetCreateStat()`
2. Load base HP/mana from `player_classlevelstats` → `SetCreateHealth()` / `SetCreateMana()`
3. Apply racial passive bonuses (flat stat bonuses from race)
4. Apply item stat bonuses from equipped gear: each `StatType`/`StatValue` pair in `item_template`
5. Apply aura (buff/debuff) modifiers
6. Calculate derived stats (AP, crit%, dodge%, max HP, max mana) from the final stat totals

The server recalculates all derived stats whenever `UpdateAllStats()` is called, which is triggered by equipping/unequipping items, level changes, and many talent/aura changes.

---

## 3. Race & Class System

### 3.1 Race IDs

| ID | Constant | Race | Faction | Starting Zone |
|----|----------|------|---------|--------------|
| 1 | RACE_HUMAN | Human | Alliance | Elwynn Forest |
| 2 | RACE_ORC | Orc | Horde | Durotar |
| 3 | RACE_DWARF | Dwarf | Alliance | Dun Morogh |
| 4 | RACE_NIGHTELF | Night Elf | Alliance | Teldrassil |
| 5 | RACE_UNDEAD_PLAYER | Undead (Forsaken) | Horde | Tirisfal Glades |
| 6 | RACE_TAUREN | Tauren | Horde | Mulgore |
| 7 | RACE_GNOME | Gnome | Alliance | Dun Morogh (Gnomeregan exile) |
| 8 | RACE_TROLL | Troll | Horde | Durotar (Echo Isles exile) |
| 10 | RACE_BLOODELF | Blood Elf | Horde | Eversong Woods |
| 11 | RACE_DRAENEI | Draenei | Alliance | Azuremyst Isle |

> Note: Race ID 9 (Goblin) does not exist in 3.3.5a — that was added in Cataclysm.

### 3.2 Class IDs

| ID | Constant | Class | Power |
|----|----------|-------|-------|
| 1 | CLASS_WARRIOR | Warrior | Rage |
| 2 | CLASS_PALADIN | Paladin | Mana |
| 3 | CLASS_HUNTER | Hunter | Mana / Focus (pet) |
| 4 | CLASS_ROGUE | Rogue | Energy |
| 5 | CLASS_PRIEST | Priest | Mana |
| 6 | CLASS_DEATH_KNIGHT | Death Knight | Runic Power |
| 7 | CLASS_SHAMAN | Shaman | Mana |
| 8 | CLASS_MAGE | Mage | Mana |
| 9 | CLASS_WARLOCK | Warlock | Mana |
| 11 | CLASS_DRUID | Druid | Mana / Rage (Bear) / Energy (Cat) |

> Note: Class ID 10 is not used in 3.3.5a. Monk (ID 10) was added in Mists of Pandaria.

### 3.3 Valid Race-Class Combinations (3.3.5a)

| | WAR | PAL | HUN | ROG | PRI | DK | SHA | MAG | WRL | DRU |
|---|:---:|:---:|:---:|:---:|:---:|:--:|:---:|:---:|:---:|:---:|
| Human | ✓ | ✓ | — | ✓ | ✓ | ✓ | — | ✓ | ✓ | — |
| Orc | ✓ | — | ✓ | ✓ | — | ✓ | ✓ | — | ✓ | — |
| Dwarf | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | — | — | — |
| Night Elf | ✓ | — | ✓ | ✓ | ✓ | ✓ | — | — | — | ✓ |
| Undead | ✓ | — | — | ✓ | ✓ | ✓ | — | ✓ | ✓ | — |
| Tauren | ✓ | — | ✓ | — | ✓ | ✓ | ✓ | — | — | ✓ |
| Gnome | ✓ | — | — | ✓ | — | ✓ | — | ✓ | ✓ | — |
| Troll | ✓ | — | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | — |
| Blood Elf | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | ✓ | ✓ | — |
| Draenei | ✓ | ✓ | ✓ | — | ✓ | ✓ | ✓ | ✓ | — | — |

Note: Death Knights can be any race that existed pre-WotLK (all 10 in the table above).

### 3.4 Racial Abilities

Key racials by race (spell IDs from Spell.dbc):

| Race | Ability | Spell ID | Effect |
|------|---------|----------|--------|
| Human | Every Man for Himself | 59752 | Remove all movement-impairing effects (PvP trinket equivalent) |
| Human | Diplomacy (passive) | 20599 | 10% bonus reputation gain |
| Human | The Human Spirit (passive) | 20598 | +3% Spirit |
| Orc | Blood Fury (Melee) | 20572 | +AP for 15s |
| Orc | Blood Fury (Caster) | 33697 | +SP for 15s |
| Orc | Hardiness (passive) | 20573 | 25% reduced stun duration |
| Orc | Command (passive) | 20575 | +5% pet damage |
| Dwarf | Stoneform | 20594 | Remove poison/disease/bleed, +10% armor for 8s |
| Dwarf | Gun Specialization (passive) | 20595 | +1% gun crit |
| Dwarf | Frost Resistance (passive) | 20596 | +10 frost resistance |
| Night Elf | Shadowmeld | 58984 | Stealth while stationary |
| Night Elf | Quickness (passive) | 20582 | +2% dodge |
| Night Elf | Wisp Spirit (passive) | 20585 | Move 75% faster as a ghost |
| Night Elf | Nature Resistance (passive) | 20583 | +10 nature resistance |
| Undead | Will of the Forsaken | 7744 | Remove fear/charm/sleep |
| Undead | Cannibalize | 20577 | Eat humanoid/undead corpses to regen 35% HP over 10s |
| Undead | Shadow Resistance (passive) | 20579 | +10 shadow resistance |
| Undead | Underwater Breathing (passive) | 5227 | 10× underwater breath |
| Tauren | War Stomp | 20549 | AoE stun up to 5 enemies for 2s |
| Tauren | Endurance (passive) | 20550 | +5% base HP |
| Tauren | Cultivation (passive) | 20552 | +15 herbalism skill |
| Tauren | Nature Resistance (passive) | 20551 | +10 nature resistance |
| Gnome | Escape Artist | 20589 | Escape immobilizing effects |
| Gnome | Expansive Mind (passive) | 20591 | +5% Intellect |
| Gnome | Arcane Resistance (passive) | 20592 | +10 arcane resistance |
| Gnome | Technologist (passive) | 20593 | +15 engineering skill |
| Troll | Berserking | 26297 | +10–30% attack/cast speed based on missing HP |
| Troll | Beast Slaying (passive) | 20557 | +5% damage vs beasts |
| Troll | Regeneration (passive) | 20555 | +10% HP regen, 10% in combat |
| Blood Elf | Arcane Torrent | 28730 (melee), 25046 (caster), 80483 (DK) | Silence nearby casters, restore resource |
| Blood Elf | Arcane Affinity (passive) | 28877 | +10 enchanting skill |
| Blood Elf | Magic Resistance (passive) | 28878 | Reduces chance to be hit by magic spells by 2% |
| Draenei | Gift of the Naaru | 59544 (various) | HoT heal based on max HP |
| Draenei | Heroic Presence (passive) | 6562 | +1% hit to all party/raid members nearby |
| Draenei | Shadow Resistance (passive) | 28770 | +10 shadow resistance |

---

## 4. Talent System

### 4.1 character_talent Table

**Database:** `characters`

Stores the talent spell IDs for each character spec. On spec switch the relevant rows are read and written to `character_spell`.

| Column | Type | Key | Description |
|--------|------|-----|-------------|
| `guid` | INT UNSIGNED | PK | Character GUID |
| `spell` | MEDIUMINT UNSIGNED | PK | Talent spell ID (from `Spell.dbc`) |
| `specMask` | TINYINT UNSIGNED | PK | Spec bitmask: 1=Spec1, 2=Spec2, 3=Both |

**specMask values:**

| Value | Meaning |
|-------|---------|
| 1 | Talent active in first spec only |
| 2 | Talent active in second spec only |
| 3 | Talent active in both specs |

### 4.2 character_glyphs Table

**Database:** `characters`

Stores glyph configurations per spec.

| Column | Type | Key | Description |
|--------|------|-----|-------------|
| `guid` | INT UNSIGNED | PK | Character GUID |
| `talentGroup` | TINYINT UNSIGNED | PK | 0 = first spec, 1 = second spec |
| `glyph1` | SMALLINT UNSIGNED | — | GlyphProperties.dbc ID, slot 1 |
| `glyph2` | SMALLINT UNSIGNED | — | GlyphProperties.dbc ID, slot 2 |
| `glyph3` | SMALLINT UNSIGNED | — | GlyphProperties.dbc ID, slot 3 |
| `glyph4` | SMALLINT UNSIGNED | — | GlyphProperties.dbc ID, slot 4 |
| `glyph5` | SMALLINT UNSIGNED | — | GlyphProperties.dbc ID, slot 5 |
| `glyph6` | SMALLINT UNSIGNED | — | GlyphProperties.dbc ID, slot 6 |

### 4.3 Dual Specialization System

Dual spec is gated by `characters.talentGroupsCount`:
- `talentGroupsCount = 1`: only spec slot 0 active (default)
- `talentGroupsCount = 2`: both spec slots active (player bought dual spec for 1000g, or admin granted)

Active spec is stored in `characters.activeTalentGroup` (0 or 1).

On spec switch the server:
1. Saves current talents from `character_spell` back to `character_talent` with the appropriate `specMask`
2. Loads the alternate spec's talents from `character_talent` into `character_spell`
3. Updates active glyphs from `character_glyphs` for the new `talentGroup`
4. Recalculates all stats and abilities

**To grant dual spec via SQL (server offline):**
```sql
UPDATE characters SET talentGroupsCount = 2 WHERE guid = ?;
```

### 4.4 Talent Tree Tab IDs by Class

Each class has three talent trees. The `TalentTab.dbc` stores tree IDs. Key assignments:

| Class | Tab 0 | Tab 1 | Tab 2 |
|-------|-------|-------|-------|
| Warrior | Arms (163) | Fury (164) | Protection (165) |
| Paladin | Holy (382) | Protection (383) | Retribution (381) |
| Hunter | Beast Mastery (361) | Marksmanship (363) | Survival (362) |
| Rogue | Assassination (182) | Combat (181) | Subtlety (183) |
| Priest | Discipline (201) | Holy (202) | Shadow (203) |
| Death Knight | Blood (398) | Frost (399) | Unholy (400) |
| Shaman | Elemental (261) | Enhancement (263) | Restoration (262) |
| Mage | Arcane (81) | Fire (41) | Frost (61) |
| Warlock | Affliction (302) | Demonology (303) | Destruction (301) |
| Druid | Balance (283) | Feral Combat (281) | Restoration (282) |

---

## 5. PlayerScript Hooks (C++)

All methods have empty default implementations in the base class. Override only what you need. Hooks marked `[[nodiscard]] bool` return `true` to allow default behavior, `false` to block/override it. The `bool` hooks marked `OnBefore*` or `Can*` are **gatekeepers** — returning `false` cancels the action.

### 5.1 Lifecycle & Login

```cpp
// Fires when player object is fully loaded from DB and added to world.
// Use for welcome messages, initializing module data.
virtual void OnPlayerLogin(Player* player);

// Fires on the very first login of a new character after creation.
virtual void OnPlayerFirstLogin(Player* player);

// Fires before the player object is removed from the world on logout.
// Last chance to save module-specific data.
virtual void OnPlayerBeforeLogout(Player* player);

// Fires after logout, player object still valid but removed from world.
virtual void OnPlayerLogout(Player* player);

// Fires when a character is first created (before entering world).
virtual void OnPlayerCreate(Player* player);

// Fires when a character is permanently deleted.
// Note: player object is gone; guid and accountId are passed directly.
virtual void OnPlayerDelete(ObjectGuid guid, uint32 accountId);

// Fires when a delete attempt fails (e.g. guild leader can't be deleted).
virtual void OnPlayerFailedDelete(ObjectGuid guid, uint32 accountId);

// Fires when the player object is loaded from DB (before OnLogin).
virtual void OnPlayerLoadFromDB(Player* player);

// Fires when the player data is saved to DB.
virtual void OnPlayerSave(Player* player);

// Fires on each server-side update tick for this player (every diff ms).
// WARNING: This fires extremely frequently. Keep code minimal.
virtual void OnPlayerUpdate(Player* player, uint32 p_time);

// Fires before the update tick. Same performance warning applies.
virtual void OnPlayerBeforeUpdate(Player* player, uint32 p_time);
```

### 5.2 Level, XP, and Talents

```cpp
// Fires when character gains a level.
// oldlevel is the previous level.
virtual void OnPlayerLevelChanged(Player* player, uint8 oldlevel);

// Fires when XP is granted to player.
// amount is a reference — can be modified to change XP awarded.
// victim is the creature killed (nullptr for non-kill XP sources).
// xpSource: 0=kill, 1=quest, 2=explore, 3=pet kill, 4=LFG bonus
virtual void OnPlayerGiveXP(Player* player, uint32& amount, Unit* victim, uint8 xpSource);

// Fires when free talent points count changes.
virtual void OnPlayerFreeTalentPointsChanged(Player* player, uint32 points);

// Fires when talents are reset (spent → refunded).
// noCost = true when GM resets for free.
virtual void OnPlayerTalentsReset(Player* player, bool noCost);

// Fires when player learns a specific talent rank.
virtual void OnPlayerLearnTalents(Player* player, uint32 talentId, uint32 talentRank, uint32 spellid);

// Gatekeeper: return false to prevent learning a specific talent.
[[nodiscard]] virtual bool OnPlayerCanLearnTalent(Player* player, TalentEntry const* talent, uint32 rank);

// Fires after active spec slot changes (dual spec switch).
virtual void OnPlayerAfterSpecSlotChanged(Player* player, uint8 newSlot);

// Fires before talent initialization for a level.
// talentPointsForLevel can be modified.
virtual void OnPlayerBeforeInitTalentForLevel(Player* player, uint8& level, uint32& talentPointsForLevel);

// Fires to recalculate total talent points for a given level.
virtual void OnPlayerCalculateTalentsPoints(Player const* player, uint32& talentPointsForLevel);

// Allows overriding the max level cap.
virtual void OnPlayerSetMaxLevel(Player* player, uint32& maxPlayerLevel);

// Gatekeeper: return false to prevent level gain.
virtual bool OnPlayerCanGiveLevel(Player* player, uint8 newLevel);
```

### 5.3 Money and Economy

```cpp
// Fires when money changes (gain or spend).
// amount is a reference — positive = gain, negative = loss.
// Modify amount to change how much they actually receive/spend.
virtual void OnPlayerMoneyChanged(Player* player, int32& amount);

// Fires before a player loots money from a loot object.
virtual void OnPlayerBeforeLootMoney(Player* player, Loot* loot);

// Fires before an item is bought from a vendor.
// item reference can be replaced with a different item entry.
virtual void OnPlayerBeforeBuyItemFromVendor(Player* player, ObjectGuid vendorguid,
    uint32 vendorslot, uint32& item, uint8 count, uint8 bag, uint8 slot);

// Fires before storing or equipping a new item just bought.
virtual void OnPlayerBeforeStoreOrEquipNewItem(Player* player, uint32 vendorslot,
    uint32& item, uint8 count, uint8 bag, uint8 slot,
    ItemTemplate const* pProto, Creature* pVendor,
    VendorItem const* crItem, bool bStore);

// Fires after storing or equipping a new item just bought.
virtual void OnPlayerAfterStoreOrEquipNewItem(Player* player, uint32 vendorslot,
    Item* item, uint8 count, uint8 bag, uint8 slot,
    ItemTemplate const* pProto, Creature* pVendor,
    VendorItem const* crItem, bool bStore);

// Fires when sending mail to another player.
// Return false to block the mail.
[[nodiscard]] virtual bool OnPlayerCanSendMail(Player* player, ObjectGuid receiverGuid,
    ObjectGuid mailbox, std::string& subject, std::string& body,
    uint32 money, uint32 COD, Item* item);

// Fires before vendor item list is sent to player.
// vendorEntry can be changed to show a different vendor's inventory.
virtual void OnPlayerSendListInventory(Player* player, ObjectGuid vendorGuid, uint32& vendorEntry);
```

### 5.4 Reputation

```cpp
// Fires when reputation changes.
// standing is a reference — can be modified.
// incremental: true = delta change, false = absolute set.
// Return false to cancel the reputation change.
virtual bool OnPlayerReputationChange(Player* player, uint32 factionID,
    int32& standing, bool incremental);

// Fires when reputation rank changes (e.g. Neutral → Friendly).
virtual void OnPlayerReputationRankChange(Player* player, uint32 factionID,
    ReputationRank newRank, ReputationRank oldRank, bool increased);

// Fires before reputation is awarded (quest/kill reward).
// amount is modifiable.
virtual void OnPlayerGiveReputation(Player* player, int32 factionID,
    float& amount, ReputationSource repSource);

// Fires to apply reputation price discounts at NPCs.
virtual void OnPlayerGetReputationPriceDiscount(Player const* player,
    Creature const* creature, float& discount);
virtual void OnPlayerGetReputationPriceDiscount(Player const* player,
    FactionTemplateEntry const* factionTemplate, float& discount);
```

### 5.5 Combat, Death, and PvP

```cpp
// Fires just as the player dies (before releasing spirit).
virtual void OnPlayerJustDied(Player* player);

// Fires when the player releases their ghost.
virtual void OnPlayerReleasedGhost(Player* player);

// Fires when the player is resurrected.
virtual void OnPlayerResurrect(Player* player, float restore_percent, bool applySickness);

// Fires before graveyard selection is made (for override).
virtual void OnPlayerBeforeChooseGraveyard(Player* player, TeamId teamId,
    bool nearCorpse, uint32& graveyardOverride);

// Gatekeeper: return false to prevent repop at graveyard.
[[nodiscard]] virtual bool OnPlayerCanRepopAtGraveyard(Player* player);

// Gatekeeper: return false to prevent resurrection.
virtual bool OnPlayerCanResurrect(Player* player);

// Fires when a player kills another player in PvP.
virtual void OnPlayerPVPKill(Player* killer, Player* killed);

// Fires when the player kills a creature.
virtual void OnPlayerCreatureKill(Player* killer, Creature* killed);

// Fires when a creature kills the player.
virtual void OnPlayerKilledByCreature(Creature* killer, Player* killed);

// Fires when the player's pet kills a creature.
virtual void OnPlayerCreatureKilledByPet(Player* petOwner, Creature* killed);

// Fires when the PvP flag (combat flag) changes.
virtual void OnPlayerPVPFlagChange(Player* player, bool state);

// Fires when player enters or leaves combat.
virtual void OnPlayerEnterCombat(Player* player, Unit* enemy);
virtual void OnPlayerLeaveCombat(Player* player);

// Fires when a duel is requested/started/ended.
virtual void OnPlayerDuelRequest(Player* target, Player* challenger);
virtual void OnPlayerDuelStart(Player* player1, Player* player2);
virtual void OnPlayerDuelEnd(Player* winner, Player* loser, DuelCompleteType type);
```

### 5.6 Chat and Communication

```cpp
// Fires before a chat message is sent.
// type is message type, lang is language, msg is modifiable string.
virtual void OnPlayerBeforeSendChatMessage(Player* player, uint32& type,
    uint32& lang, std::string& msg);

// Chat gatekeepers per channel type. Return false to block the message.
[[nodiscard]] virtual bool OnPlayerCanUseChat(Player* player, uint32 type,
    uint32 language, std::string& msg);
[[nodiscard]] virtual bool OnPlayerCanUseChat(Player* player, uint32 type,
    uint32 language, std::string& msg, Player* receiver);    // whisper
[[nodiscard]] virtual bool OnPlayerCanUseChat(Player* player, uint32 type,
    uint32 language, std::string& msg, Group* group);        // party/raid
[[nodiscard]] virtual bool OnPlayerCanUseChat(Player* player, uint32 type,
    uint32 language, std::string& msg, Guild* guild);        // guild
[[nodiscard]] virtual bool OnPlayerCanUseChat(Player* player, uint32 type,
    uint32 language, std::string& msg, Channel* channel);    // channel

// Fires when player performs an emote action.
virtual void OnPlayerEmote(Player* player, uint32 emote);
virtual void OnPlayerTextEmote(Player* player, uint32 textEmote,
    uint32 emoteNum, ObjectGuid guid);
```

### 5.7 Spells and Abilities

```cpp
// Fires when a spell is cast.
virtual void OnPlayerSpellCast(Player* player, Spell* spell, bool skipCheck);

// Fires when a spell is learned.
virtual void OnPlayerLearnSpell(Player* player, uint32 spellID);

// Fires when a spell is unlearned/forgotten.
virtual void OnPlayerForgotSpell(Player* player, uint32 spellID);
```

### 5.8 Zone, Map, and Teleport

```cpp
// Fires when the player's zone/area updates.
virtual void OnPlayerUpdateZone(Player* player, uint32 newZone, uint32 newArea);
virtual void OnPlayerUpdateArea(Player* player, uint32 oldArea, uint32 newArea);

// Fires when the player changes maps.
virtual void OnPlayerMapChanged(Player* player);

// Gatekeeper: return false to cancel the teleport.
[[nodiscard]] virtual bool OnPlayerBeforeTeleport(Player* player, uint32 mapid,
    float x, float y, float z, float orientation,
    uint32 options, Unit* target);

// Fires when player binds to an instance (enters with lock).
virtual void OnPlayerBindToInstance(Player* player, Difficulty difficulty,
    uint32 mapId, bool permanent);

// Fires when the player's faction updates (used by phasing mods).
virtual void OnPlayerUpdateFaction(Player* player);

// Gatekeeper: return false to prevent map entry.
[[nodiscard]] virtual bool OnPlayerCanEnterMap(Player* player, MapEntry const* entry,
    InstanceTemplate const* instance, MapDifficulty const* mapDiff, bool loginCheck);

// Gatekeeper: return false to prevent flying in a zone.
[[nodiscard]] virtual bool OnPlayerCanFlyInZone(Player* player, uint32 mapId,
    uint32 zoneId, SpellInfo const* bySpell);
```

### 5.9 Items and Inventory

```cpp
// Fires when the player equips an item.
virtual void OnPlayerEquip(Player* player, Item* it, uint8 bag, uint8 slot, bool update);

// Fires when the player unequips an item.
virtual void OnPlayerUnequip(Player* player, Item* it);

// Fires when an item is looted by the player.
virtual void OnPlayerLootItem(Player* player, Item* item, uint32 count, ObjectGuid lootguid);

// Fires when a new item is stored in inventory.
virtual void OnPlayerStoreNewItem(Player* player, Item* item, uint32 count);

// Fires when an item is created (crafted).
virtual void OnPlayerCreateItem(Player* player, Item* item, uint32 count);

// Fires when an item is received as a quest reward.
virtual void OnPlayerQuestRewardItem(Player* player, Item* item, uint32 count);

// Gatekeeper: return false to prevent opening an item (bag, box).
[[nodiscard]] virtual bool OnPlayerBeforeOpenItem(Player* player, Item* item);

// Gatekeeper: return false to prevent equipping an item.
[[nodiscard]] virtual bool OnPlayerCanEquipItem(Player* player, uint8 slot,
    uint16& dest, Item* pItem, bool swap, bool not_loading);

// Gatekeeper: return false to prevent unequipping.
[[nodiscard]] virtual bool OnPlayerCanUnequipItem(Player* player, uint16 pos, bool swap);

// Gatekeeper: return false to prevent using an item.
[[nodiscard]] virtual bool OnPlayerCanUseItem(Player* player,
    ItemTemplate const* proto, InventoryResult& result);

// Gatekeeper: return false to prevent selling an item.
[[nodiscard]] virtual bool OnPlayerCanSellItem(Player* player,
    Item* item, Creature* creature);
```

### 5.10 Quests

```cpp
// Fires when a quest is completed (turned in).
virtual void OnPlayerCompleteQuest(Player* player, Quest const* quest);

// Gatekeeper: return false to prevent quest completion/turn-in.
[[nodiscard]] virtual bool OnPlayerBeforeQuestComplete(Player* player, uint32 quest_id);

// Fires when a quest is abandoned.
virtual void OnPlayerQuestAbandon(Player* player, uint32 questId);

// Allows modification of XP reward from a quest.
virtual void OnPlayerQuestComputeXP(Player* player, Quest const* quest, uint32& xpValue);

// Fires when quest rate multiplier is calculated.
virtual void OnPlayerGetQuestRate(Player* player, float& result);

// Gatekeeper for monster kill credit toward a quest.
[[nodiscard]] virtual bool OnPlayerPassedQuestKilledMonsterCredit(Player* player,
    Quest const* qinfo, uint32 entry, uint32 real_entry, ObjectGuid guid);
```

### 5.11 Achievements

```cpp
// Fires when an achievement is completed.
virtual void OnPlayerAchievementComplete(Player* player, AchievementEntry const* achievement);

// Gatekeeper: return false to prevent achievement completion.
virtual bool OnPlayerBeforeAchievementComplete(Player* player,
    AchievementEntry const* achievement);

// Fires when an achievement criterion progresses.
virtual void OnPlayerCriteriaProgress(Player* player, AchievementCriteriaEntry const* criteria);

// Gatekeeper: return false to prevent criterion progress.
virtual bool OnPlayerBeforeCriteriaProgress(Player* player,
    AchievementCriteriaEntry const* criteria);

// Fires when achievement data is being saved to DB.
virtual void OnPlayerAchievementSave(CharacterDatabaseTransaction trans, Player* player,
    uint16 achId, CompletedAchievementData achiData);
virtual void OnPlayerCriteriaSave(CharacterDatabaseTransaction trans, Player* player,
    uint16 achId, CriteriaProgress criteriaData);
```

### 5.12 Gossip

```cpp
virtual void OnPlayerGossipSelect(Player* player, uint32 menu_id,
    uint32 sender, uint32 action);
virtual void OnPlayerGossipSelectCode(Player* player, uint32 menu_id,
    uint32 sender, uint32 action, const char* code);
```

### 5.13 Battleground and Arena

```cpp
virtual void OnPlayerAddToBattleground(Player* player, Battleground* bg);
virtual void OnPlayerRemoveFromBattleground(Player* player, Battleground* bg);
virtual void OnPlayerJoinBG(Player* player);
virtual void OnPlayerJoinArena(Player* player);

[[nodiscard]] virtual bool OnPlayerCanJoinInBattlegroundQueue(Player* player,
    ObjectGuid BattlemasterGuid, BattlegroundTypeId BGTypeID,
    uint8 joinAsGroup, GroupJoinBattlegroundResult& err);
[[nodiscard]] virtual bool OnPlayerCanJoinInArenaQueue(Player* player,
    ObjectGuid BattlemasterGuid, uint8 arenaslot, BattlegroundTypeId BGTypeID,
    uint8 joinAsGroup, uint8 IsRated, GroupJoinBattlegroundResult& err);
[[nodiscard]] virtual bool OnPlayerCanBattleFieldPort(Player* player, uint8 arenaType,
    BattlegroundTypeId BGTypeID, uint8 action);

virtual void OnPlayerGetArenaPersonalRating(Player* player, uint8 slot, uint32& result);
virtual void OnPlayerGetArenaTeamId(Player* player, uint8 slot, uint32& result);
virtual void OnPlayerGetMaxPersonalArenaRatingRequirement(Player const* player,
    uint32 minSlot, uint32& maxArenaRating) const;

// Honor reward override hooks
virtual void OnPlayerVictimRewardBefore(Player* player, Player* victim,
    uint32& killer_title, int32& victim_rank);
virtual void OnPlayerVictimRewardAfter(Player* player, Player* victim,
    uint32& killer_title, int32& victim_rank, float& honor_f);
```

### 5.14 Skill and Stat Calculation

```cpp
// Fires when max skill value is queried (weapon/profession skills).
virtual void OnPlayerGetMaxSkillValue(Player* player, uint32 skill,
    int32& result, bool IsPure);
virtual void OnPlayerGetMaxSkillValueForLevel(Player* player, uint16& result);

// Allows blocking a skill update.
virtual bool OnPlayerCanUpdateSkill(Player* player, uint32 skillId);

// Fires before/after a skill value changes.
virtual void OnPlayerBeforeUpdateSkill(Player* player, uint32 skillId,
    uint32& value, uint32 max, uint32 step);
virtual void OnPlayerUpdateSkill(Player* player, uint32 skillId,
    uint32 value, uint32 max, uint32 step, uint32 newValue);

// Fires after max power (mana/rage/energy) is recalculated.
virtual void OnPlayerAfterUpdateMaxPower(Player* player, Powers& power, float& value);

// Fires after max health is recalculated.
virtual void OnPlayerAfterUpdateMaxHealth(Player* player, float& value);

// Fires before/after attack power is recalculated.
virtual void OnPlayerBeforeUpdateAttackPowerAndDamage(Player* player,
    float& level, float& val2, bool ranged);
virtual void OnPlayerAfterUpdateAttackPowerAndDamage(Player* player,
    float& level, float& base_attPower, float& attPowerMod,
    float& attPowerMultiplier, bool ranged);

// Fires to apply custom item stat values (scaling gear).
virtual void OnPlayerCustomScalingStatValueBefore(Player* player,
    ItemTemplate const* proto, uint8 slot, bool apply, uint32& CustomScalingStatValue);
virtual void OnPlayerCustomScalingStatValue(Player* player, ItemTemplate const* proto,
    uint32& statType, int32& val, uint8 itemProtoStatNumber,
    uint32 ScalingStatValue, ScalingStatValuesEntry const* ssv);

// Fires before item mods are applied.
virtual void OnPlayerApplyItemModsBefore(Player* player, uint8 slot, bool apply,
    uint8 itemProtoStatNumber, uint32 statType, int32& val);

// Fires before enchantment mods are applied.
virtual void OnPlayerApplyEnchantmentItemModsBefore(Player* player, Item* item,
    EnchantmentSlot slot, bool apply, uint32 enchant_spell_id, uint32& enchant_amount);

// Druid feral AP bonus override.
virtual void OnPlayerGetFeralApBonus(Player* player, int32& feral_bonus,
    int32 dpsMod, ItemTemplate const* proto, ScalingStatValuesEntry const* ssv);

// Gathering/crafting/fishing skill override hooks.
virtual void OnPlayerUpdateGatheringSkill(Player* player, uint32 skill_id,
    uint32 current, uint32 gray, uint32 green, uint32 yellow, uint32& gain);
virtual void OnPlayerUpdateCraftingSkill(Player* player,
    SkillLineAbilityEntry const* skill, uint32 current_level, uint32& gain);
[[nodiscard]] virtual bool OnPlayerUpdateFishingSkill(Player* player,
    int32 skill, int32 zone_skill, int32 chance, int32 roll);
```

### 5.15 Group and Trade

```cpp
// Gatekeeper: return false to prevent group invite.
[[nodiscard]] virtual bool OnPlayerCanGroupInvite(Player* player, std::string& membername);

// Gatekeeper: return false to prevent accepting a group invite.
[[nodiscard]] virtual bool OnPlayerCanGroupAccept(Player* player, Group* group);

// Gatekeeper: return false to prevent initiating trade.
[[nodiscard]] virtual bool OnPlayerCanInitTrade(Player* player, Player* target);

// Gatekeeper: return false to prevent setting a specific trade item.
[[nodiscard]] virtual bool OnPlayerCanSetTradeItem(Player* player,
    Item* tradedItem, uint8 tradeSlot);

// Fires when player queues for LFG.
virtual void OnPlayerQueueRandomDungeon(Player* player, uint32& rDungeonId);
[[nodiscard]] virtual bool OnPlayerCanJoinLfg(Player* player, uint8 roles,
    std::set<uint32>& dungeons, const std::string& comment);
```

### 5.16 Loot and Drops

```cpp
virtual void OnPlayerAfterCreatureLoot(Player* player);
virtual void OnPlayerAfterCreatureLootMoney(Player* player);
virtual void OnPlayerBeforeFillQuestLootItem(Player* player, LootItem& item);
virtual void OnPlayerGroupRollRewardItem(Player* player, Item* item,
    uint32 count, RollVote voteType, Roll* roll);

// Gatekeeper for auction bid.
[[nodiscard]] virtual bool OnPlayerCanPlaceAuctionBid(Player* player, AuctionEntry* auction);
```

### 5.17 Pet and Summon

```cpp
virtual void OnPlayerBeforeTempSummonInitStats(Player* player,
    TempSummon* tempSummon, uint32& duration);
virtual void OnPlayerBeforeGuardianInitStatsForLevel(Player* player,
    Guardian* guardian, CreatureTemplate const* cinfo, PetType& petType);
virtual void OnPlayerAfterGuardianInitStatsForLevel(Player* player, Guardian* guardian);
virtual void OnPlayerBeforeLoadPetFromDB(Player* player, uint32& petentry,
    uint32& petnumber, bool& current, bool& forceLoadFromDB);
```

---

## 6. Player Modification via C++

### 6.1 Level

```cpp
// Unit base method — sets the level field and fires OnPlayerLevelChanged hook.
void SetLevel(uint8 lvl, bool showLevelChange = true);

// Player method — runs full level-up sequence: stat recalc, talent points,
// spell learning, health/mana to full, achievement credit, XP bar reset.
void GiveLevel(uint8 level);

// Grant XP (may trigger level-up if enough).
void GiveXP(uint32 xp, Unit* victim, float group_rate = 1.0f, bool isLFGReward = false);
```

**When to use each:**
- `GiveLevel()` is preferred for full level-up with all side effects.
- `SetLevel()` is lower-level and skips some Player-specific initialization.
- For custom XP rewards, call `GiveXP()` so that the `OnPlayerGiveXP` hook fires and XP modifiers apply.

### 6.2 Money

```cpp
uint32 GetMoney() const;                                  // Returns copper amount
bool ModifyMoney(int32 amount, bool sendError = true);    // +/- copper; fires OnPlayerMoneyChanged hook
void SetMoney(uint32 value);                              // Directly sets copper (bypasses hooks)
```

**Gold conversion:**
```cpp
// 1 gold = 10000 copper
// 1 silver = 100 copper
const int32 ONE_GOLD   = 10000;
const int32 ONE_SILVER = 100;

player->ModifyMoney(50 * ONE_GOLD);   // Give 50 gold
player->ModifyMoney(-5 * ONE_GOLD);   // Remove 5 gold
```

### 6.3 Spells

```cpp
// Learn a spell. temporary = true means it won't be saved to DB.
void learnSpell(uint32 spellId, bool temporary = false, bool learnFromSkill = false);

// Remove a spell. removeSpecMask: 0=from active spec, 1=spec1, 2=spec2, 3=both.
// onlyTemporary = true removes only temporary spells.
void removeSpell(uint32 spellId, uint8 removeSpecMask, bool onlyTemporary);

// Check if player knows a spell.
bool HasSpell(uint32 spell) const;
```

### 6.4 Items

```cpp
// Add item to player's inventory. Returns true on success.
// If inventory is full the item is mailed to the player.
bool AddItem(uint32 itemId, uint32 count);
```

For more control (specific bag/slot, item properties):
```cpp
Item* item = Item::CreateItem(itemId, count, player);
if (item)
{
    uint16 dest;
    InventoryResult result = player->CanStoreItem(NULL_BAG, NULL_SLOT, dest, item, false);
    if (result == EQUIP_ERR_OK)
        player->StoreItem(dest, item, true);
    else
        delete item;
}
```

### 6.5 Teleport

```cpp
// Teleport to map/coordinates. Returns true if teleport initiated.
// options bitmask: TELE_TO_GM_MODE=0x01, TELE_TO_NOT_LEAVE_TRANSPORT=0x02,
//                  TELE_TO_NOT_UNSUMMON_PET=0x04, TELE_TO_SPELL=0x08
bool TeleportTo(uint32 mapid, float x, float y, float z, float orientation,
                uint32 options = 0, Unit* target = nullptr, bool newInstance = false);

// Teleport to a WorldLocation struct:
bool TeleportTo(WorldLocation const& loc, uint32 options = 0);
```

**Common map IDs:**

| Map ID | Name |
|--------|------|
| 0 | Eastern Kingdoms |
| 1 | Kalimdor |
| 530 | Outland (Burning Crusade) |
| 571 | Northrend (WotLK) |
| 369 | Deeprun Tram |
| 533 | Naxxramas |
| 574 | Utgarde Keep |
| 631 | Icecrown Citadel |

### 6.6 Phase System

```cpp
// Set the phase mask. update = true sends the change to nearby clients.
// PHASEMASK_NORMAL = 0x00000001 (default phase)
// PHASEMASK_ANYWHERE = 0xFFFFFFFF (visible to all phases)
virtual void SetPhaseMask(uint32 newPhaseMask, bool update);

// Get current phase mask.
uint32 GetPhaseMask() const;

// Constants:
// PHASEMASK_NORMAL   = 0x00000001
// PHASEMASK_ANYWHERE = 0xFFFFFFFF
```

**Phase design:**
- Phase bits are checked with bitwise AND — a creature in phase 2 (0x02) and a player in phase 3 (0x03) CAN see each other because `0x02 & 0x03 = 0x02`.
- A player in phase 1 (0x01) cannot see a creature in phase 2 (0x02) because `0x01 & 0x02 = 0x00`.
- Setting `PHASEMASK_ANYWHERE` makes an object visible to all players regardless of phase.

```cpp
// Example: put player in a custom private phase 4:
player->SetPhaseMask(4, true);

// Restore to normal:
player->SetPhaseMask(PHASEMASK_NORMAL, true);
```

### 6.7 Reputation

```cpp
// Set reputation with a faction to a specific standing value.
// value is the raw reputation points (not rank — convert if needed).
void SetReputation(uint32 factionentry, float value);

// Get current reputation standing with a faction.
uint32 GetReputation(uint32 factionentry) const;
```

**Reputation thresholds:**

| Standing | Min Points | Max Points |
|----------|-----------|-----------|
| Hated | -42000 | -6001 |
| Hostile | -6000 | -3001 |
| Unfriendly | -3000 | -1 |
| Neutral | 0 | 2999 |
| Friendly | 3000 | 8999 |
| Honored | 9000 | 20999 |
| Revered | 21000 | 41999 |
| Exalted | 42000 | 42999 |

```cpp
// Set Stormwind (faction 72) to Exalted:
player->SetReputation(72, 42000.0f);
```

### 6.8 Honor and Arena Points

```cpp
void SetHonorPoints(uint32 value);
void ModifyHonorPoints(int32 value,
    CharacterDatabaseTransaction trans = CharacterDatabaseTransaction(nullptr));

void SetArenaPoints(uint32 value);
void ModifyArenaPoints(int32 value,
    CharacterDatabaseTransaction trans = CharacterDatabaseTransaction(nullptr));
```

---

## 7. Chat Commands System

### 7.1 CommandScript Architecture

Custom GM commands are added via `CommandScript`. Derive from it and override `GetCommands()`.

```cpp
#include "ScriptMgr.h"
#include "Chat.h"
#include "ChatCommand.h"
#include "Player.h"

// Using the Acore namespace shorthand:
using namespace Acore::ChatCommands;

class MyCommandScript : public CommandScript
{
public:
    MyCommandScript() : CommandScript("MyCommandScript") {}

    // Return the list of commands to register.
    std::vector<ChatCommandBuilder> GetCommands() const override
    {
        static std::vector<ChatCommandBuilder> commandTable =
        {
            // { "commandname", handler_function, security_level, console_allowed }
            { "mycmd",    HandleMyCmd,     SEC_GAMEMASTER,    Console::No  },
            { "mysubcmd", HandleMySubCmd,  SEC_ADMINISTRATOR, Console::Yes },
        };
        return commandTable;
    }

    // Handler: receives ChatHandler* and any trailing arguments as string_view.
    static bool HandleMyCmd(ChatHandler* handler, std::string_view args)
    {
        Player* target = handler->getSelectedPlayer();
        if (!target)
        {
            handler->SendSysMessage("No player selected.");
            return false;
        }
        handler->PSendSysMessage("Target: %s", target->GetName().c_str());
        return true;
    }

    static bool HandleMySubCmd(ChatHandler* handler, std::string_view args)
    {
        // Console-safe commands must not use getSelectedPlayer() since
        // there is no session when invoked from the console.
        handler->SendSysMessage("Sub command executed.");
        return true;
    }
};

void AddSC_MyCommandScript()
{
    new MyCommandScript();
}
```

### 7.2 Security Levels (AccountTypes)

| Constant | Value | Description |
|----------|-------|-------------|
| `SEC_PLAYER` | 0 | Normal player account |
| `SEC_MODERATOR` | 1 | Basic moderation (kick, mute) |
| `SEC_GAMEMASTER` | 2 | Standard GM powers (teleport, additem, .go) |
| `SEC_ADMINISTRATOR` | 3 | Advanced GM (npc add, reload, account set gmlevel) |
| `SEC_CONSOLE` | 4 | Server console only |

Set a player's GM level in the auth database:
```sql
-- Grant GM level 2 for account ID 5 on realm 1:
INSERT INTO account_access (id, gmlevel, RealmID) VALUES (5, 2, 1)
ON DUPLICATE KEY UPDATE gmlevel = 2;
```

Or via GM command in-game:
```
.account set gmlevel <player> <level> [realm]
```

### 7.3 ChatHandler Utility Methods

```cpp
// Send yellow system message to the command issuer:
handler->SendSysMessage("Message text");
handler->PSendSysMessage("Player: %s level %u", player->GetName().c_str(), player->GetLevel());

// Get the target player (selected or named in args):
Player* target = handler->getSelectedPlayer();
Player* target = handler->GetPlayer();  // command issuer themselves

// Get a player by name from args:
// (parse args manually with Acore::StringTo<uint32> or FindPlayerByName)
Player* named = ObjectAccessor::FindPlayerByName(std::string(args));

// Check if called from console (no session):
bool isConsole = !handler->GetSession();

// Notify player of error:
handler->SendErrorMessage("Something went wrong.");
```

### 7.4 Nested Sub-Commands

```cpp
std::vector<ChatCommandBuilder> GetCommands() const override
{
    static std::vector<ChatCommandBuilder> subTable =
    {
        { "add",    HandleMyAdd,    SEC_GAMEMASTER, Console::No },
        { "remove", HandleMyRemove, SEC_GAMEMASTER, Console::No },
    };

    static std::vector<ChatCommandBuilder> commandTable =
    {
        // Parent command with subcommands (no handler function — just routes to subtable)
        { "mymod", subTable },
    };
    return commandTable;
}
// Usage: .mymod add   / .mymod remove
```

---

## 8. GroupScript & GuildScript

### 8.1 GroupScript Hooks

```cpp
class GroupScript : public ScriptObject
{
public:
    GroupScript(const char* name);

    // Fires when a player is added to the group.
    virtual void OnAddMember(Group* group, ObjectGuid guid) {}

    // Fires when a player accepts an invite (pre-join step).
    virtual void OnInviteMember(Group* group, ObjectGuid guid) {}

    // Fires when a player is removed from the group.
    // method: GROUP_REMOVEMETHOD_DEFAULT, _KICK, _LEAVE, _DISBAND
    // kicker: GUID of the player who kicked (or empty if self-leave)
    // reason: kick reason string
    virtual void OnRemoveMember(Group* group, ObjectGuid guid,
        RemoveMethod method, ObjectGuid kicker, const char* reason) {}

    // Fires when the group leader changes.
    virtual void OnChangeLeader(Group* group,
        ObjectGuid newLeaderGuid, ObjectGuid oldLeaderGuid) {}

    // Fires when the group disbands.
    virtual void OnDisband(Group* group) {}

    // Fires when the group is first created.
    virtual void OnCreate(Group* group, Player* leader) {}

    // Gatekeeper: return false to prevent group from joining BG queue.
    [[nodiscard]] virtual bool CanGroupJoinBattlegroundQueue(
        Group const* group, Player* member, Battleground const* bgTemplate,
        uint32 MinPlayerCount, bool isRated, uint32 arenaSlot) { return true; }
};
```

### 8.2 GuildScript Hooks

```cpp
class GuildScript : public ScriptObject
{
public:
    GuildScript(const char* name);

    // Fires when a player is added to the guild.
    // plRank is a reference — can be modified to assign a different initial rank.
    virtual void OnAddMember(Guild* guild, Player* player, uint8& plRank) {}

    // Fires when a player is removed from the guild.
    // isDisbanding = true when the guild itself is disbanding.
    // isKicked = true when the player was kicked (not voluntary leave).
    virtual void OnRemoveMember(Guild* guild, Player* player,
        bool isDisbanding, bool isKicked) {}

    // Fires when the message of the day changes.
    virtual void OnMOTDChanged(Guild* guild, const std::string& newMotd) {}

    // Fires when the guild info text changes.
    virtual void OnInfoChanged(Guild* guild, const std::string& newInfo) {}

    // Fires when the guild is created.
    virtual void OnCreate(Guild* guild, Player* leader, const std::string& name) {}

    // Fires when the guild is disbanded.
    virtual void OnDisband(Guild* guild) {}

    // Fires when a member withdraws money from the guild bank.
    // amount is a reference — can be modified.
    // isRepair = true when the withdrawal is for repair costs.
    virtual void OnMemberWitdrawMoney(Guild* guild, Player* player,
        uint32& amount, bool isRepair) {}

    // Fires when a member deposits money into the guild bank.
    virtual void OnMemberDepositMoney(Guild* guild, Player* player, uint32& amount) {}

    // Fires when an item is moved within or between guild bank tabs.
    virtual void OnItemMove(Guild* guild, Player* player, Item* pItem,
        bool isSrcBank, uint8 srcContainer, uint8 srcSlotId,
        bool isDestBank, uint8 destContainer, uint8 destSlotId) {}

    // Fires for general guild log events (rank change, etc.).
    // eventType: GE_PROMOTION, GE_DEMOTION, GE_MOTD, GE_JOINED, GE_LEFT, GE_REMOVED
    virtual void OnEvent(Guild* guild, uint8 eventType,
        ObjectGuid::LowType playerGuid1, ObjectGuid::LowType playerGuid2,
        uint8 newRank) {}

    // Fires for guild bank log events.
    virtual void OnBankEvent(Guild* guild, uint8 eventType, uint8 tabId,
        ObjectGuid::LowType playerGuid, uint32 itemOrMoney,
        uint16 itemStackCount, uint8 destTabId) {}

    // Gatekeeper: return false to prevent sending bank list to session.
    [[nodiscard]] virtual bool CanGuildSendBankList(Guild const* guild,
        WorldSession* session, uint8 tabId, bool sendAllSlots) { return true; }
};
```

---

## 9. Honor & Arena System

### 9.1 Honor Points

Honor is stored in the `characters` table:

| Column | Description |
|--------|-------------|
| `totalHonorPoints` | Total lifetime honor accumulated (spendable) |
| `todayHonorPoints` | Honor earned today (added to total at daily reset) |
| `yesterdayHonorPoints` | Honor from yesterday (for display) |
| `totalKills` | Lifetime total honorable kills |
| `todayKills` | Kills today |
| `yesterdayKills` | Kills yesterday |

**C++ methods:**

```cpp
void SetHonorPoints(uint32 value);
void ModifyHonorPoints(int32 value, CharacterDatabaseTransaction trans = {});

uint32 GetHonorPoints() const { return GetUInt32Value(PLAYER_FIELD_HONOR_CURRENCY); }

// Award honor as if from a kill (processes through normal honor calculation):
RewardHonor(Unit* uVictim, uint32 groupsize, int32 honor = -1, bool pvptoken = false);
```

**SQL direct modification (server offline only):**

```sql
-- Set honor points:
UPDATE characters SET totalHonorPoints = 5000 WHERE guid = ?;

-- Add to today's honor (will be absorbed at daily reset):
UPDATE characters SET todayHonorPoints = todayHonorPoints + 500 WHERE guid = ?;
```

### 9.2 Arena Points

Arena points are stored in `characters.arenaPoints`. They are awarded at the weekly reset based on arena team ratings.

```cpp
void SetArenaPoints(uint32 value);
void ModifyArenaPoints(int32 value, CharacterDatabaseTransaction trans = {});

uint32 GetArenaPoints() const { return GetUInt32Value(PLAYER_FIELD_ARENA_CURRENCY); }
```

**Arena point calculation at weekly reset** (from `ArenaTeam::FinishWeek()`):
- Points awarded = f(personal_rating, team_games_played, team_games_won)
- Base formula: `Points = 1511.26 / (1 + 1639.28 * exp(-0.00412 * rating))`
- Scaled down if the team played < 10% of games as a specific member
- Capped at 5000 arena points total

### 9.3 CharacterPoints (DB Column Context)

`characters.totalHonorPoints` maps to `PLAYER_FIELD_HONOR_CURRENCY` (field 0).
`characters.arenaPoints` maps to `PLAYER_FIELD_ARENA_CURRENCY` (field 1).

These are both 32-bit unsigned integers in WotLK. In Cataclysm+ honor was redesigned; in 3.3.5a honor points are simply a currency with no decay.

---

## 10. Achievement System

### 10.1 character_achievement Table

**Database:** `characters`

| Column | Type | Description |
|--------|------|-------------|
| `guid` | INT UNSIGNED (PK) | Character GUID |
| `achievement` | SMALLINT UNSIGNED (PK) | Achievement ID from `Achievement.dbc` |
| `date` | INT UNSIGNED | Unix timestamp when achievement was earned |

**Note:** Deleting a "Realm First!" achievement requires a server restart to take effect (cached in world state).

### 10.2 character_achievement_progress Table

**Database:** `characters`

Tracks partial progress on achievements that require accumulating counts.

| Column | Type | Description |
|--------|------|-------------|
| `guid` | INT UNSIGNED (PK) | Character GUID |
| `criteria` | SMALLINT UNSIGNED (PK) | Criteria ID from `Achievement_Criteria.dbc` |
| `counter` | INT UNSIGNED | Current progress count |
| `date` | INT UNSIGNED | Unix timestamp of last progress update |

### 10.3 achievement_criteria_data Table

**Database:** `world`

Defines additional scripted conditions that must be met for an achievement criterion to count.

| Column | Type | Description |
|--------|------|-------------|
| `criteria_id` | MEDIUMINT (PK) | References `Achievement_Criteria.dbc` ID |
| `type` | TINYINT UNSIGNED (PK) | Condition type (see below) |
| `value1` | MEDIUMINT UNSIGNED | Type-dependent parameter 1 |
| `value2` | MEDIUMINT UNSIGNED | Type-dependent parameter 2 |
| `ScriptName` | CHAR(64) | Script handler for TYPE_SCRIPT conditions |

**Key `type` values:**

| Value | Name | value1 | value2 |
|-------|------|--------|--------|
| 0 | NONE | — | — |
| 1 | T_CREATURE | Creature entry | — |
| 2 | T_PLAYER_CLASS_RACE | Class mask | Race mask |
| 3 | T_PLAYER_LESS_HEALTH | Health % threshold | — |
| 4 | T_PLAYER_DEAD | Team (0=both) | — |
| 5 | T_AURA | Spell ID | Effect index |
| 6 | T_AREA | Area ID | — |
| 7 | T_VALUE1 | Comparison type | Value |
| 8 | T_T_AURA | Spell ID on target | Effect index |
| 11 | T_ACHIEVEMENT | Achievement ID required | — |
| 12 | T_RACE | Race mask | — |
| 13 | T_PLAYER_CLASS | Class mask | — |
| 14 | T_KNOWN_TITLE | Title bit index | — |
| 15 | T_SCRIPT | ScriptName controls | — |

### 10.4 Programmatic Achievement Credit via C++

```cpp
// Credit a completed achievement directly:
player->CompletedAchievement(sAchievementStore.LookupEntry(achievementId));

// Update progress on a criterion:
player->UpdateAchievementCriteria(ACHIEVEMENT_CRITERIA_TYPE_KILL_CREATURE, creatureEntry, 1);

// Common criteria types:
// ACHIEVEMENT_CRITERIA_TYPE_KILL_CREATURE         = 0
// ACHIEVEMENT_CRITERIA_TYPE_WIN_BG                = 1
// ACHIEVEMENT_CRITERIA_TYPE_REACH_LEVEL           = 5
// ACHIEVEMENT_CRITERIA_TYPE_COMPLETE_QUEST_COUNT  = 14
// ACHIEVEMENT_CRITERIA_TYPE_COMPLETE_QUESTS_IN_ZONE = 19
// ACHIEVEMENT_CRITERIA_TYPE_FALL_WITHOUT_DYING    = 26
// ACHIEVEMENT_CRITERIA_TYPE_HONORABLE_KILL        = 53

// Check if player has already completed an achievement:
if (player->HasAchieved(achievementId))
{
    // Already done
}

// Example: credit "Level 80" achievement (ID 467):
if (player->GetLevel() >= 80 && !player->HasAchieved(467))
    player->CompletedAchievement(sAchievementStore.LookupEntry(467));
```

---

## 11. Cross-References

### Within This Document Set

| Topic | File |
|-------|------|
| Module structure, script base classes, core DB schema | `acore_development/00_legacy_reference.md` |
| Creature/NPC scripting, SmartAI, item_template | `acore_development/00_legacy_reference.md` §6 |
| Eluna Lua player API (RegisterPlayerEvent hooks) | `kb_eluna_api.md` |
| WoW 3.3.5a client addon API (player unit functions) | `kb_addon_api_335a.md` |
| WoW taint system, memory offsets, binary unlocking | `kb_wow_internals.md` |

### Key Source Files (AzerothCore Repository)

| File | Contents |
|------|----------|
| `src/server/game/Entities/Player/Player.h` | Player class declaration, all method signatures |
| `src/server/game/Entities/Player/Player.cpp` | GiveLevel, GiveXP, stat init |
| `src/server/game/Entities/Player/PlayerUpdates.cpp` | UpdateAllStats, skill/rating updates |
| `src/server/game/Entities/Unit/Unit.h` | SetLevel, SetPhaseMask, base combat methods |
| `src/server/game/Scripting/ScriptDefines/PlayerScript.h` | All PlayerScript virtual hooks |
| `src/server/game/Scripting/ScriptDefines/GroupScript.h` | GroupScript virtual hooks |
| `src/server/game/Scripting/ScriptDefines/GuildScript.h` | GuildScript virtual hooks |
| `src/server/game/Scripting/ScriptDefines/CommandScript.h` | CommandScript base class |
| `src/server/game/Chat/Chat.h` | ChatHandler utility class |
| `src/server/shared/SharedDefines.h` | Classes, Races, Powers, Stats enums |
| `src/server/game/Entities/Object/Object.h` | SetPhaseMask, PhaseMasks enum |

### Key World Database Tables

| Table | Purpose |
|-------|---------|
| `player_levelstats` | Base stats (STR/AGI/STA/INT/SPI) per race/class/level |
| `player_classlevelstats` | Base HP/mana per class/level |
| `playercreateinfo` | Starting map/zone/position per race/class |
| `playercreateinfo_spell_custom` | Spells granted on character creation |
| `playercreateinfo_item` | Items granted on character creation |
| `player_xp_for_level` | XP required per level transition |

### Key Characters Database Tables

| Table | Purpose |
|-------|---------|
| `characters` | Primary character record |
| `character_talent` | Talent spell IDs per spec |
| `character_glyphs` | Glyph selections per spec |
| `character_spell` | All learned spells |
| `character_achievement` | Completed achievements |
| `character_achievement_progress` | Partial achievement progress |
| `character_reputation` | Reputation standing per faction |
| `character_inventory` | Item-to-slot mappings |
| `character_queststatus` | Active/completed quest tracking |
| `character_skills` | Skill levels and max values |
| `character_stats` | Snapshot of character stats at save |
| `character_aura` | Persistent auras (saved across logout) |

### DBC Files Relevant to Player System

| DBC | Contents |
|-----|----------|
| `ChrRaces.dbc` | Race IDs, faction, display info, base stats |
| `ChrClasses.dbc` | Class IDs, power types, display info |
| `Talent.dbc` | Talent definitions, tree positions, prerequisites |
| `TalentTab.dbc` | Talent tree IDs per class |
| `GlyphProperties.dbc` | Glyph spell associations |
| `Achievement.dbc` | Achievement IDs, names, criteria counts |
| `Achievement_Criteria.dbc` | Individual criteria definitions |
| `CharTitles.dbc` | Title IDs and display strings |
| `gtChanceToMeleeCrit.dbc` | AGI-to-crit coefficients per class/level |
| `gtChanceToDodge.dbc` | AGI-to-dodge coefficients per class/level |
| `gtChanceToSpellCrit.dbc` | INT-to-spell-crit coefficients per class/level |
| `gtOCTRegenHP.dbc` | Spirit-to-HP-regen coefficients per class/level |
| `gtRegenMPPerSpt.dbc` | Spirit-to-mana-regen coefficients per class/level |
| `Faction.dbc` | Faction IDs for reputation operations |

*Last updated: 2026-03-18*
