# Item System

Complete reference for AzerothCore item system: `item_template`, loot tables, vendor setup, random enchants, and C++ item manipulation API.

---

## Table of Contents

1. [item_template — Core Fields](#1-item_template--core-fields)
2. [item_template — Enumerations](#2-item_template--enumerations)
3. [item_template — Stats (stat_type1–10)](#3-item_template--stats-stat_type110)
4. [item_template — Damage & Resistances](#4-item_template--damage--resistances)
5. [item_template — Spell Triggers (spellid_1–5)](#5-item_template--spell-triggers-spellid_15)
6. [item_template — Sockets & Gems](#6-item_template--sockets--gems)
7. [item_template — Flags Bitmasks](#7-item_template--flags-bitmasks)
8. [Loot System](#8-loot-system)
9. [Vendor & Extended Costs](#9-vendor--extended-costs)
10. [Random Enchants](#10-random-enchants)
11. [C++ Item API](#11-c-item-api)
12. [Cross-References](#12-cross-references)

---

## 1. item_template — Core Fields

Primary table: `world.item_template`. One row per item prototype.

| Column | Type | Description |
|--------|------|-------------|
| `entry` | MEDIUMINT UNSIGNED | Unique item ID. Referenced by loot tables, vendor, quest, etc. |
| `class` | TINYINT UNSIGNED | Item class category. See §2 Class enum. |
| `subclass` | TINYINT UNSIGNED | Sub-category within class. See §2 SubClass enum. |
| `SoundOverrideSubclass` | TINYINT SIGNED | Override weapon sound. -1 = use class default. Useful when a mace should play sword sounds. |
| `name` | VARCHAR(255) | Item display name. |
| `displayid` | MEDIUMINT UNSIGNED | References `ItemDisplayInfo.dbc` — controls 3D model and icon. |
| `Quality` | TINYINT UNSIGNED | Item quality/rarity. See §2 Quality enum. |
| `Flags` | BIGINT SIGNED | Primary item behavior bitmask. See §7. |
| `FlagsExtra` | INT UNSIGNED | Additional item property flags. See §7. |
| `flagsCustom` | INT UNSIGNED | AzerothCore-specific custom flags. See §7. |
| `BuyCount` | TINYINT UNSIGNED | Stack size when purchased from vendor (default: 1). |
| `BuyPrice` | BIGINT SIGNED | Cost to buy from vendor, in copper. 0 = cannot buy. |
| `SellPrice` | INT UNSIGNED | Value when sold to vendor, in copper. 0 = no sell value. |
| `InventoryType` | TINYINT UNSIGNED | Equipment slot. See §2 InventoryType enum. |
| `AllowableClass` | INT SIGNED | Class restriction bitmask. -1 = all classes. See §2. |
| `AllowableRace` | INT SIGNED | Race restriction bitmask. -1 = all races. See §2. |
| `ItemLevel` | SMALLINT UNSIGNED | Item level (ilvl). Affects tooltip and scaling. |
| `RequiredLevel` | TINYINT UNSIGNED | Minimum character level to equip/use. |
| `RequiredSkill` | SMALLINT UNSIGNED | Skill ID from `SkillLine.dbc` required to equip. |
| `RequiredSkillRank` | SMALLINT UNSIGNED | Minimum skill value for `RequiredSkill`. |
| `requiredspell` | MEDIUMINT UNSIGNED | Spell the player must know to equip/use this item. |
| `requiredhonorrank` | MEDIUMINT UNSIGNED | PvP honor rank requirement (pre-2.0 system, usually 0). |
| `RequiredCityRank` | MEDIUMINT UNSIGNED | City reputation rank required. Typically 0. |
| `RequiredReputationFaction` | SMALLINT UNSIGNED | Faction ID from `Faction.dbc` required. |
| `RequiredReputationRank` | SMALLINT UNSIGNED | Minimum reputation rank: 0=Hated … 7=Exalted. |
| `maxcount` | INT SIGNED | Max copies a player can own at once. 0 = unlimited. |
| `stackable` | INT SIGNED | Max stack size. 1 = cannot stack. |
| `ContainerSlots` | SMALLINT UNSIGNED | Number of bag slots (class=1 containers only). |
| `ScalingStatDistribution` | SMALLINT SIGNED | Heirloom scaling distribution ID from `ScalingStatDistribution.dbc`. |
| `ScalingStatValue` | INT UNSIGNED | The stat value at level 80 for heirloom scaling. |
| `armor` | SMALLINT UNSIGNED | Base armor value. |
| `holy_res` | TINYINT UNSIGNED | Holy resistance. |
| `fire_res` | TINYINT UNSIGNED | Fire resistance. |
| `nature_res` | TINYINT UNSIGNED | Nature resistance. |
| `frost_res` | TINYINT UNSIGNED | Frost resistance. |
| `shadow_res` | TINYINT UNSIGNED | Shadow resistance. |
| `arcane_res` | TINYINT UNSIGNED | Arcane resistance. |
| `delay` | SMALLINT UNSIGNED | Weapon attack speed in milliseconds (e.g., 2000 = 2.0 speed). |
| `ammo_type` | TINYINT UNSIGNED | Ammunition type consumed: 2=Arrow, 3=Bullet. |
| `RangedModRange` | FLOAT SIGNED | Range modifier for ranged weapons. |
| `bonding` | TINYINT UNSIGNED | Binding type. See §2. |
| `description` | VARCHAR(255) | Flavour text shown in orange on the tooltip. |
| `PageText` | MEDIUMINT UNSIGNED | References `page_text.entry` for readable books/letters. |
| `LanguageID` | TINYINT UNSIGNED | Language ID for page text. |
| `PageMaterial` | TINYINT UNSIGNED | Page background texture (0=None, 1=Parchment, 2=Stone, 3=Marble, 4=Silver, 5=Bronze, 6=Valentine, 7=Illidan). |
| `startquest` | MEDIUMINT UNSIGNED | Quest ID that this item begins when right-clicked. |
| `lockid` | MEDIUMINT UNSIGNED | Lock ID from `Lock.dbc`. Used for lockboxes and keys. |
| `Material` | TINYINT SIGNED | Material sound type. See §2. |
| `sheath` | TINYINT UNSIGNED | Weapon sheath position: 0=None, 1=Back, 2=Side, 3=Back2H, 4=OffBack, 5=OffHip, 6=TwoHand, 7=Shield. |
| `RandomProperty` | MEDIUMINT SIGNED | Random enchant property. References `ItemRandomProperties.dbc` via `item_enchantment_template`. Cannot combine with RandomSuffix. |
| `RandomSuffix` | MEDIUMINT UNSIGNED | Random stat suffix. References `ItemRandomSuffix.dbc` via `item_enchantment_template`. Cannot combine with RandomProperty. |
| `block` | MEDIUMINT UNSIGNED | Shield block value. |
| `itemset` | MEDIUMINT UNSIGNED | Set bonus ID from `ItemSet.dbc`. |
| `MaxDurability` | SMALLINT UNSIGNED | Maximum durability. 0 = indestructible. |
| `area` | MEDIUMINT UNSIGNED | AreaID from `AreaTable.dbc` restricting where item can be used. |
| `Map` | SMALLINT SIGNED | MapID restricting item to a specific map. |
| `BagFamily` | MEDIUMINT SIGNED | Bitmask — which bag types can hold this item. See §2. |
| `TotemCategory` | MEDIUMINT SIGNED | Totem/tool category from `TotemCategory.dbc` (e.g., mining pick, blacksmith hammer). |
| `GemProperties` | MEDIUMINT SIGNED | Gem property ID from `GemProperties.dbc`. |
| `socketBonus` | MEDIUMINT SIGNED | Enchantment ID applied when all sockets are filled. References `SpellItemEnchantment.dbc`. |
| `RequiredDisenchantSkill` | SMALLINT SIGNED | Minimum Enchanting skill to DE this item. -1 = cannot be disenchanted. |
| `ArmorDamageModifier` | FLOAT SIGNED | Modifier to armor damage calculation. Usually 0. |
| `duration` | INT UNSIGNED | Item duration in seconds. 0 = permanent. |
| `ItemLimitCategory` | SMALLINT SIGNED | Limit category ID from `ItemLimitCategory.dbc` (e.g., flasks). |
| `HolidayId` | INT UNSIGNED | Holiday ID from `Holidays.dbc`. Item only usable during this event. |
| `DisenchantID` | MEDIUMINT UNSIGNED | Loot template ID in `disenchant_loot_template` for DE results. |
| `FoodType` | TINYINT UNSIGNED | Pet food category: 0=None, 1=Meat, 2=Fish, 3=Cheese, 4=Bread, 5=Fungus, 6=Fruit, 7=Raw Meat, 8=Raw Fish. |
| `minMoneyLoot` | INT UNSIGNED | Minimum copper in a container's money loot. |
| `maxMoneyLoot` | INT UNSIGNED | Maximum copper in a container's money loot. |
| `ScriptName` | VARCHAR(64) | C++ `ItemScript` class name to attach custom logic. |
| `VerifiedBuild` | SMALLINT SIGNED | Client build number this entry was verified against. |

---

## 2. item_template — Enumerations

### Quality

| ID | Client Color | Name |
|----|-------------|------|
| 0 | Grey | Poor |
| 1 | White | Common |
| 2 | Green | Uncommon |
| 3 | Blue | Rare |
| 4 | Purple | Epic |
| 5 | Orange | Legendary |
| 6 | Red | Artifact |
| 7 | Gold | Heirloom |

### Class & SubClass

#### Class 0 — Consumable

| SubClass ID | Name |
|-------------|------|
| 0 | Consumable |
| 1 | Potion |
| 2 | Elixir |
| 3 | Flask |
| 4 | Scroll |
| 5 | Food & Drink |
| 6 | Item Enhancement |
| 7 | Bandage |
| 8 | Other |

#### Class 1 — Container

| SubClass ID | Name |
|-------------|------|
| 0 | Bag |
| 1 | Soul Bag |
| 2 | Herb Bag |
| 3 | Enchanting Bag |
| 4 | Engineering Bag |
| 5 | Gem Bag |
| 6 | Mining Bag |
| 7 | Leatherworking Bag |
| 8 | Inscription Bag |

#### Class 2 — Weapon

| SubClass ID | Name |
|-------------|------|
| 0 | One-Handed Axe |
| 1 | Two-Handed Axe |
| 2 | Bow |
| 3 | Gun |
| 4 | One-Handed Mace |
| 5 | Two-Handed Mace |
| 6 | Polearm |
| 7 | One-Handed Sword |
| 8 | Two-Handed Sword |
| 10 | Staff |
| 13 | Fist Weapon |
| 15 | Dagger |
| 16 | Thrown |
| 17 | Spear (obsolete) |
| 18 | Crossbow |
| 19 | Wand |
| 20 | Fishing Pole |

#### Class 3 — Gem

| SubClass ID | Name |
|-------------|------|
| 0 | Red |
| 1 | Blue |
| 2 | Yellow |
| 3 | Purple |
| 4 | Green |
| 5 | Orange |
| 6 | Meta |
| 7 | Simple |
| 8 | Prismatic |

#### Class 4 — Armor

| SubClass ID | Name |
|-------------|------|
| 0 | Miscellaneous |
| 1 | Cloth |
| 2 | Leather |
| 3 | Mail |
| 4 | Plate |
| 6 | Shield |
| 7 | Libram |
| 8 | Idol |
| 9 | Totem |
| 10 | Sigil |

#### Class 5 — Reagent

| SubClass ID | Name |
|-------------|------|
| 0 | Reagent |

#### Class 6 — Projectile

| SubClass ID | Name |
|-------------|------|
| 2 | Arrow |
| 3 | Bullet |

#### Class 7 — Trade Goods

| SubClass ID | Name |
|-------------|------|
| 0 | Trade Goods |
| 1 | Parts |
| 2 | Explosives |
| 3 | Devices |
| 4 | Jewelcrafting |
| 5 | Cloth |
| 6 | Leather |
| 7 | Metal & Stone |
| 8 | Meat |
| 9 | Herb |
| 10 | Elemental |
| 11 | Other Trade Goods |
| 12 | Enchanting |
| 13 | Materials |
| 14 | Armor Enchantment |
| 15 | Weapon Enchantment |

#### Class 9 — Recipe

| SubClass ID | Name |
|-------------|------|
| 0 | Book |
| 1 | Leatherworking |
| 2 | Tailoring |
| 3 | Engineering |
| 4 | Blacksmithing |
| 5 | Cooking |
| 6 | Alchemy |
| 7 | First Aid |
| 8 | Enchanting |
| 9 | Fishing |
| 10 | Jewelcrafting |
| 11 | Inscription |

#### Class 11 — Quiver

| SubClass ID | Name |
|-------------|------|
| 2 | Quiver |
| 3 | Ammo Pouch |

#### Class 12 — Quest

| SubClass ID | Name |
|-------------|------|
| 0 | Quest |

#### Class 13 — Key

| SubClass ID | Name |
|-------------|------|
| 0 | Key |
| 1 | Lockpick |

#### Class 15 — Miscellaneous

| SubClass ID | Name |
|-------------|------|
| 0 | Junk |
| 1 | Reagent |
| 2 | Pet |
| 3 | Holiday |
| 4 | Other |
| 5 | Mount |

#### Class 16 — Glyph

| SubClass ID | Class |
|-------------|-------|
| 1 | Warrior |
| 2 | Paladin |
| 3 | Hunter |
| 4 | Rogue |
| 5 | Priest |
| 6 | Death Knight |
| 7 | Shaman |
| 8 | Mage |
| 9 | Warlock |
| 11 | Druid |

---

### InventoryType

| ID | Slot Name | Notes |
|----|-----------|-------|
| 0 | Non-equippable | Bags, quest items, etc. |
| 1 | Head | |
| 2 | Neck | |
| 3 | Shoulder | |
| 4 | Body | Shirt slot |
| 5 | Chest | Chest armor |
| 6 | Waist | Belt |
| 7 | Legs | |
| 8 | Feet | Boots |
| 9 | Wrists | Bracers |
| 10 | Hands | Gloves |
| 11 | Finger | Ring |
| 12 | Trinket | |
| 13 | Weapon | One-hand (main or off) |
| 14 | Shield | Off-hand shield |
| 15 | Ranged | Bow, gun, crossbow (RANGED slot) |
| 16 | Cloak | Back slot |
| 17 | Two-Hand Weapon | Forces main-hand only, blocks off-hand |
| 18 | Bag | Container in bag slots 1–4 |
| 19 | Tabard | |
| 20 | Robe | Chest-slot robe (shows chest + legs) |
| 21 | Main Hand | Only equippable in main hand |
| 22 | Off Hand | Held off-hand (books, tomes) |
| 23 | Held in Off-Hand | Frill off-hand item |
| 24 | Ammo | Ammo slot (arrows/bullets) |
| 25 | Thrown | Thrown weapon slot |
| 26 | Ranged Right | Wand / totem (RANGED_RIGHT slot) |
| 27 | Quiver | Quiver/ammo pouch bag slot |
| 28 | Relic | Paladin/druid/shaman/DK class-specific slot |

---

### Bonding

| ID | Type |
|----|------|
| 0 | No Binding |
| 1 | Binds When Picked Up (BoP) |
| 2 | Binds When Equipped (BoE) |
| 3 | Binds When Used (BoU) |
| 4 | Quest Item |
| 5 | Quest Item (variant) |

---

### Material

| ID | Sound Type |
|----|-----------|
| -1 | Consumables (no equip sound) |
| 0 | Undefined |
| 1 | Metal |
| 2 | Wood |
| 3 | Liquid |
| 4 | Jewelry |
| 5 | Chain |
| 6 | Plate |
| 7 | Cloth |
| 8 | Leather |

---

### AllowableClass Bitmask

| Value | Class |
|-------|-------|
| 1 | Warrior |
| 2 | Paladin |
| 4 | Hunter |
| 8 | Rogue |
| 16 | Priest |
| 32 | Death Knight |
| 64 | Shaman |
| 128 | Mage |
| 256 | Warlock |
| 1024 | Druid |
| -1 | All Classes |

### AllowableRace Bitmask

| Value | Race |
|-------|------|
| 1 | Human |
| 2 | Orc |
| 4 | Dwarf |
| 8 | Night Elf |
| 16 | Undead |
| 32 | Tauren |
| 64 | Gnome |
| 128 | Troll |
| 512 | Blood Elf |
| 1024 | Draenei |
| -1 | All Races |

### BagFamily Bitmask

Controls which specialized bags can hold this item. Use 0 for normal bags.

| Value | Family |
|-------|--------|
| 1 | Arrows |
| 2 | Bullets |
| 4 | Soul Shards |
| 8 | Leatherworking Supplies |
| 16 | Inscription Supplies |
| 32 | Herbs |
| 64 | Enchanting Supplies |
| 128 | Engineering Supplies |
| 256 | Keys |
| 512 | Gems |
| 1024 | Mining Supplies |
| 2048 | Soulbound Equipment |
| 4096 | Vanity Pets |
| 8192 | Currency Tokens |
| 16384 | Quest Items |

---

## 3. item_template — Stats (stat_type1–10)

Ten stat slots: `stat_type1`…`stat_type10` (TINYINT UNSIGNED) paired with `stat_value1`…`stat_value10` (INT SIGNED). The value can be negative.

| ID | ITEM_MOD Constant | Display Name | Notes |
|----|-------------------|--------------|-------|
| 0 | ITEM_MOD_MANA | Mana | Flat mana |
| 1 | ITEM_MOD_HEALTH | Health | Flat HP |
| 3 | ITEM_MOD_AGILITY | Agility | |
| 4 | ITEM_MOD_STRENGTH | Strength | |
| 5 | ITEM_MOD_INTELLECT | Intellect | |
| 6 | ITEM_MOD_SPIRIT | Spirit | |
| 7 | ITEM_MOD_STAMINA | Stamina | |
| 12 | ITEM_MOD_DEFENSE_SKILL_RATING | Defense Rating | |
| 13 | ITEM_MOD_DODGE_RATING | Dodge Rating | |
| 14 | ITEM_MOD_PARRY_RATING | Parry Rating | |
| 15 | ITEM_MOD_BLOCK_RATING | Block Rating | |
| 16 | ITEM_MOD_HIT_MELEE_RATING | Melee Hit Rating | |
| 17 | ITEM_MOD_HIT_RANGED_RATING | Ranged Hit Rating | |
| 18 | ITEM_MOD_HIT_SPELL_RATING | Spell Hit Rating | |
| 19 | ITEM_MOD_CRIT_MELEE_RATING | Melee Crit Rating | |
| 20 | ITEM_MOD_CRIT_RANGED_RATING | Ranged Crit Rating | |
| 21 | ITEM_MOD_CRIT_SPELL_RATING | Spell Crit Rating | |
| 22 | ITEM_MOD_HIT_TAKEN_MELEE_RATING | Melee Hit Taken Rating | |
| 23 | ITEM_MOD_HIT_TAKEN_RANGED_RATING | Ranged Hit Taken Rating | |
| 24 | ITEM_MOD_HIT_TAKEN_SPELL_RATING | Spell Hit Taken Rating | |
| 25 | ITEM_MOD_CRIT_TAKEN_MELEE_RATING | Melee Crit Taken Rating | |
| 26 | ITEM_MOD_CRIT_TAKEN_RANGED_RATING | Ranged Crit Taken Rating | |
| 27 | ITEM_MOD_CRIT_TAKEN_SPELL_RATING | Spell Crit Taken Rating | |
| 28 | ITEM_MOD_HASTE_MELEE_RATING | Melee Haste Rating | |
| 29 | ITEM_MOD_HASTE_RANGED_RATING | Ranged Haste Rating | |
| 30 | ITEM_MOD_HASTE_SPELL_RATING | Spell Haste Rating | |
| 31 | ITEM_MOD_HIT_RATING | Hit Rating | Combined melee+ranged+spell |
| 32 | ITEM_MOD_CRIT_RATING | Crit Rating | Combined |
| 33 | ITEM_MOD_HIT_TAKEN_RATING | Hit Taken Rating | |
| 34 | ITEM_MOD_CRIT_TAKEN_RATING | Crit Taken Rating | |
| 35 | ITEM_MOD_RESILIENCE_RATING | Resilience Rating | |
| 36 | ITEM_MOD_HASTE_RATING | Haste Rating | Combined |
| 37 | ITEM_MOD_EXPERTISE_RATING | Expertise Rating | |
| 38 | ITEM_MOD_ATTACK_POWER | Attack Power | |
| 39 | ITEM_MOD_RANGED_ATTACK_POWER | Ranged Attack Power | |
| 40 | ITEM_MOD_FERAL_ATTACK_POWER | Feral Attack Power | Obsolete in WotLK |
| 41 | ITEM_MOD_SPELL_HEALING_DONE | Spell Healing Done | Obsolete; use 45 |
| 42 | ITEM_MOD_SPELL_DAMAGE_DONE | Spell Damage Done | Obsolete; use 45 |
| 43 | ITEM_MOD_MANA_REGENERATION | Mana Regen | MP5 value |
| 44 | ITEM_MOD_ARMOR_PENETRATION_RATING | Armor Penetration Rating | |
| 45 | ITEM_MOD_SPELL_POWER | Spell Power | Replaces 41+42 |
| 46 | ITEM_MOD_HEALTH_REGEN | Health Regen | HP5 value |
| 47 | ITEM_MOD_SPELL_PENETRATION | Spell Penetration | |
| 48 | ITEM_MOD_BLOCK_VALUE | Block Value | |

**Usage notes:**
- Unused stat slots must be set to `stat_type=0, stat_value=0`.
- Stamina (7), Intellect (5), Strength (4), Agility (3), Spirit (6) display in the top tooltip section.
- Ratings (IDs 12–47) display with the "X Rating" label and convert via a level-based formula.

---

## 4. item_template — Damage & Resistances

### Weapon Damage

Two damage ranges are supported (primary and secondary/elemental):

| Column | Type | Description |
|--------|------|-------------|
| `dmg_min1` | FLOAT | Primary damage minimum. |
| `dmg_max1` | FLOAT | Primary damage maximum. |
| `dmg_type1` | TINYINT UNSIGNED | Primary damage school (see below). |
| `dmg_min2` | FLOAT | Secondary damage minimum. 0 if unused. |
| `dmg_max2` | FLOAT | Secondary damage maximum. 0 if unused. |
| `dmg_type2` | TINYINT UNSIGNED | Secondary damage school. 0 = Physical. |

### Damage Schools (dmg_type)

| ID | School |
|----|--------|
| 0 | Physical |
| 1 | Holy |
| 2 | Fire |
| 3 | Nature |
| 4 | Frost |
| 5 | Shadow |
| 6 | Arcane |

### Resistances

| Column | Description |
|--------|-------------|
| `armor` | Physical armor value. |
| `holy_res` | Holy resistance. |
| `fire_res` | Fire resistance. |
| `nature_res` | Nature resistance. |
| `frost_res` | Frost resistance. |
| `shadow_res` | Shadow resistance. |
| `arcane_res` | Arcane resistance. |

---

## 5. item_template — Spell Triggers (spellid_1–5)

Five spell slots per item:

| Column Group | Type | Description |
|--------------|------|-------------|
| `spellid_X` | MEDIUMINT SIGNED | Spell entry from `Spell.dbc`. 0 = unused. |
| `spelltrigger_X` | TINYINT UNSIGNED | Activation condition (see below). |
| `spellcharges_X` | SMALLINT SIGNED | Charges: 0=unlimited, negative=charges consumed and item deleted when 0, positive=charges consumed. |
| `spellppmRate_X` | FLOAT SIGNED | Proc per minute rate. 0 = use spell's internal chance. |
| `spellcooldown_X` | INT SIGNED | Per-spell cooldown in ms. -1 = no cooldown. |
| `spellcategory_X` | SMALLINT UNSIGNED | Spell category ID for shared cooldowns. |
| `spellcategorycooldown_X` | INT SIGNED | Shared category cooldown in ms. -1 = none. |

### spelltrigger Values

| ID | Trigger Type | Description |
|----|-------------|-------------|
| 0 | ON_USE | Fires when the item is right-clicked/used. |
| 1 | ON_EQUIP | Passive aura applied while item is equipped. Fires on equip. |
| 2 | CHANCE_ON_HIT | Random proc on melee/ranged hit (uses `spellppmRate`). |
| 4 | SOULSTONE | Used for soulstone-type resurrection mechanics. |
| 5 | ON_USE_NO_DELAY | Same as ON_USE but bypasses global cooldown delay. |
| 6 | LEARN_SPELL | `spellid_X` is a spell the item teaches (recipe/book). |

**Example — use spell with 30s cooldown:**
```sql
UPDATE item_template SET
  spellid_1 = 12345,
  spelltrigger_1 = 0,
  spellcharges_1 = 0,
  spellcooldown_1 = 30000,
  spellcategorycooldown_1 = -1
WHERE entry = 99999;
```

**Example — ON_EQUIP passive:**
```sql
UPDATE item_template SET
  spellid_1 = 54321,
  spelltrigger_1 = 1,
  spellcharges_1 = 0,
  spellcooldown_1 = -1
WHERE entry = 99999;
```

---

## 6. item_template — Sockets & Gems

### Socket Columns

| Column | Type | Description |
|--------|------|-------------|
| `socketColor_1` | TINYINT SIGNED | Color of socket 1. See below. 0 = no socket. |
| `socketColor_2` | TINYINT SIGNED | Color of socket 2. 0 = no socket. |
| `socketColor_3` | TINYINT SIGNED | Color of socket 3. 0 = no socket. |
| `socketContent_1` | MEDIUMINT SIGNED | Default gem entry for socket 1 (usually 0). |
| `socketContent_2` | MEDIUMINT SIGNED | Default gem entry for socket 2 (usually 0). |
| `socketContent_3` | MEDIUMINT SIGNED | Default gem entry for socket 3 (usually 0). |
| `socketBonus` | MEDIUMINT SIGNED | `SpellItemEnchantment.dbc` ID applied when all sockets are correctly filled. |
| `GemProperties` | MEDIUMINT SIGNED | Gem property ID from `GemProperties.dbc`. Set on gem items, not socketed items. |

### socketColor Values

| Value | Color | Accepts |
|-------|-------|---------|
| 0 | None | No socket |
| 1 | Meta | Meta gems only |
| 2 | Red | Red + Prismatic |
| 4 | Yellow | Yellow + Prismatic |
| 8 | Blue | Blue + Prismatic |
| 14 | Prismatic | Any gem (2+4+8) |

---

## 7. item_template — Flags Bitmasks

### Flags (primary bitmask)

| Decimal | Hex | Flag Name | Description |
|---------|-----|-----------|-------------|
| 1 | 0x00000001 | ITEM_FLAG_NO_PICKUP | Item cannot be picked up by players. |
| 2 | 0x00000002 | ITEM_FLAG_CONJURED | Item is conjured; disappears after login/logout. |
| 4 | 0x00000004 | ITEM_FLAG_HAS_LOOT | Item can be opened (right-click opens loot window). |
| 8 | 0x00000008 | ITEM_FLAG_HEROIC_TOOLTIP | Shows "Heroic" tag on tooltip. |
| 16 | 0x00000010 | ITEM_FLAG_DEPRECATED | Item is deprecated/no longer available. |
| 32 | 0x00000020 | ITEM_FLAG_NO_USER_DESTROY | Cannot be destroyed by the player (except by specific spell). |
| 64 | 0x00000040 | ITEM_FLAG_PLAYERCAST | Item spells are cast by the player, not the item. |
| 128 | 0x00000080 | ITEM_FLAG_NO_EQUIP_COOLDOWN | Equipping this item does not trigger the equip cooldown. |
| 256 | 0x00000100 | ITEM_FLAG_MULTI_LOOT_QUEST | Quest item that multiple party members can loot. |
| 512 | 0x00000200 | ITEM_FLAG_IS_WRAPPED | Item is wrapped (gift). Right-click to unwrap. |
| 1024 | 0x00000400 | ITEM_FLAG_USES_RESOURCES | Item uses charges/resources. |
| 2048 | 0x00000800 | ITEM_FLAG_MULTI_DROP | All party members can loot this item. |
| 4096 | 0x00001000 | ITEM_FLAG_REFUNDABLE | Item can be refunded within the refund window. |
| 8192 | 0x00002000 | ITEM_FLAG_CHARTER | Arena or guild charter. |
| 16384 | 0x00004000 | ITEM_FLAG_HAS_TEXT | Item has page text. |
| 32768 | 0x00008000 | ITEM_FLAG_NO_DISENCHANT | Cannot be disenchanted. |
| 262144 | 0x00040000 | ITEM_FLAG_CAN_BE_PROSPECTED | Can be prospected by Jewelcrafters. |
| 524288 | 0x00080000 | ITEM_FLAG_UNIQUE_EQUIPPABLE | Only one copy can be equipped at a time (unique equip). |
| 2097152 | 0x00200000 | ITEM_FLAG_USABLE_IN_ARENA | Can be used in arenas. |
| 4194304 | 0x00400000 | ITEM_FLAG_THROWABLE | Throwable weapon. |
| 8388608 | 0x00800000 | ITEM_FLAG_USABLE_IN_SHAPESHIFT | Can be used while shapeshifted. |
| 33554432 | 0x02000000 | ITEM_FLAG_PROFESSION_RECIPE | Profession recipe (only learnable if qualified). |
| 67108864 | 0x04000000 | ITEM_FLAG_NOT_USEABLE_IN_ARENA | Cannot be used in arenas. |
| 134217728 | 0x08000000 | ITEM_FLAG_BOUND_TO_ACCOUNT | Bind-to-Account (heirloom behavior). |
| 268435456 | 0x10000000 | ITEM_FLAG_TRIGGERED_CAST | Spell is cast with triggered flag (no reagent cost). |
| 536870912 | 0x20000000 | ITEM_FLAG_CAN_BE_MILLED | Can be milled by Inscription (herbs). |

### FlagsExtra

| Decimal | Hex | Description |
|---------|-----|-------------|
| 1 | 0x001 | Horde Only — item restricted to Horde players. |
| 2 | 0x002 | Alliance Only — item restricted to Alliance players. |
| 4 | 0x004 | Requires gold in addition to ExtendedCost currencies. |
| 256 | 0x100 | Disables Need roll for this item in group loot. |
| 512 | 0x200 | Need roll disabled (alternative flag). |
| 16384 | 0x4000 | HAS_NORMAL_PRICE — item has a normal gold price alongside ExtendedCost. |
| 131072 | 0x20000 | Battle.net Account Bound. |
| 2097152 | 0x200000 | CANNOT_BE_TRANSMOG — cannot be used as transmog source. |
| 4194304 | 0x400000 | CANNOT_TRANSMOG — cannot be transmog target. |
| 8388608 | 0x800000 | CAN_TRANSMOG — can be transmog target. |

### flagsCustom (AzerothCore internal)

| Value | Name | Description |
|-------|------|-------------|
| 1 | ITEM_FLAGS_CU_DURATION_REAL_TIME | Duration ticks in real time, not just while online. |
| 2 | ITEM_FLAGS_CU_IGNORE_QUEST_STATUS | Item not deleted when associated quest is abandoned. |
| 4 | ITEM_FLAGS_CU_FOLLOW_LOOT_RULES | Follows standard loot rules even if set as FFA. |

---

## 8. Loot System

AzerothCore uses a family of `*_loot_template` tables that share the same column structure.

### Loot Table Types

| Table Name | Used By |
|------------|---------|
| `creature_loot_template` | Creature body loot |
| `gameobject_loot_template` | Chest/herb/ore GameObject loot |
| `item_loot_template` | Items that contain other items (bags, boxes) |
| `disenchant_loot_template` | Disenchanting results |
| `milling_loot_template` | Milling (Inscription herbs) |
| `prospecting_loot_template` | Prospecting (Jewelcrafting ore) |
| `pickpocketing_loot_template` | Rogue pickpocketing |
| `skinning_loot_template` | Skinning creatures |
| `fishing_loot_template` | Fishing zone loot |
| `spell_loot_template` | Spell-triggered loot |
| `reference_loot_template` | Reusable loot groups referenced by other templates |
| `mail_loot_template` | Mail attachment loot |

### Column Reference (all tables share this structure)

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `Entry` | INT UNSIGNED | 0 | Loot template ID. Must match the source (e.g., `creature_template.lootid`). |
| `Item` | INT UNSIGNED | 0 | Item entry from `item_template`. |
| `Reference` | INT | 0 | When non-zero, points to a `reference_loot_template.Entry`. This row becomes a reference call, not a direct item. |
| `Chance` | FLOAT | 0 | Drop probability 0.0–100.0. If 0, item is in a "zero-chance group" (see GroupId mechanics). Negative values not used on ACore. |
| `QuestRequired` | TINYINT | 0 | 1 = item only appears if the looter has an active quest requiring this item. |
| `LootMode` | SMALLINT UNSIGNED | 1 | Bitmask controlling which loot mode activates this row. See LootMode values. |
| `GroupId` | TINYINT UNSIGNED | 0 | Group ID. 0 = always rolls independently. 1–255 = belongs to a "pick one from group" pool. |
| `MinCount` | TINYINT UNSIGNED | 1 | Minimum stack size dropped. For References: minimum times the reference is rolled. |
| `MaxCount` | TINYINT UNSIGNED | 1 | Maximum stack size dropped. For References: maximum times the reference is rolled. |
| `Comment` | VARCHAR(255) | NULL | Documentation only, never read by the server. |

### Chance Mechanics

- **Independent roll (GroupId=0):** Each row is rolled independently. Chance=30 means 30% to drop each time.
- **Group roll (GroupId>0):** Only one item from the group can drop per loot event. The server picks at most one winner from all entries sharing the same Entry+GroupId.
  - If the group's total chance = 100%, one item from the group always drops.
  - If total < 100%, the loot may produce nothing from that group.
  - Entries with Chance=0 within a group get equal shares of whatever probability remains unallocated.

**Example — 3-item group totaling 100%:**
```sql
-- One of these three swords always drops from Entry=1234
INSERT INTO creature_loot_template (Entry, Item, Chance, GroupId) VALUES
(1234, 10001, 40.0, 1),  -- 40% chance for Sword A
(1234, 10002, 35.0, 1),  -- 35% chance for Sword B
(1234, 10003, 25.0, 1);  -- 25% chance for Sword C
```

### Reference Mechanics

The `Reference` field (non-zero) turns the row into a call to `reference_loot_template.Entry`. The referenced template's items are evaluated as if inserted inline.

- Reference rows use `MinCount`/`MaxCount` to determine how many times the reference is rolled (for repeating loot).
- References can be nested (a reference template can itself contain references).
- The `Chance` on a reference row controls the chance of rolling that reference at all.

```sql
-- Reference row: 50% chance to roll reference template 9000 once
INSERT INTO creature_loot_template (Entry, Item, Reference, Chance, MinCount, MaxCount) VALUES
(1234, 0, 9000, 50.0, 1, 1);

-- The reference template itself
INSERT INTO reference_loot_template (Entry, Item, Chance) VALUES
(9000, 20001, 60.0),
(9000, 20002, 40.0);
```

### LootMode Flags

| Value | Description |
|-------|-------------|
| 1 | Normal (default). Always active unless overridden. |
| 2 | Heroic / 10-man Heroic |
| 4 | 10-man Normal (raid) |
| 8 | 25-man Normal (raid) |
| 16 | 25-man Heroic (raid) |

Rows with `LootMode=8` only drop in 25-man normal. Rows with `LootMode=1` drop in all modes (bitwise AND with active mode). Combine values to make a row drop in multiple modes.

### QuestRequired

Setting `QuestRequired=1` makes the item a quest drop: it only appears in the loot window if the looter has an active quest that requires this item. Useful for items like "10 Wolf Pelts" that should not clog non-quest loot windows.

### creature_loot_template Linking

In `creature_template`, the field `lootid` (MEDIUMINT) references `creature_loot_template.Entry`. The `skinloot` field references `skinning_loot_template.Entry`.

### gameobject_loot_template Linking

In `gameobject_template`, field `data1` (for chest type GameObjects, type=3) references `gameobject_loot_template.Entry`.

### disenchant_loot_template Linking

In `item_template`, field `DisenchantID` references `disenchant_loot_template.Entry`. This is typically determined by item quality and level bracket — the AzerothCore core uses a lookup table in `disenchant_loot_template.dbc`-adjacent logic. You can add custom disenchant outcomes by setting a `DisenchantID` and populating the corresponding template rows.

### item_loot_template (Containers)

For bags and lockboxes with contents, `item_template.entry` is used as `item_loot_template.Entry`. The `maxMoneyLoot`/`minMoneyLoot` fields in `item_template` add a money component.

### milling_loot_template / prospecting_loot_template

- `milling_loot_template.Entry` matches the herb's `item_template.entry`. Item must have `Flags` bit `ITEM_FLAG_CAN_BE_MILLED` set.
- `prospecting_loot_template.Entry` matches the ore's `item_template.entry`. Item must have `Flags` bit `ITEM_FLAG_CAN_BE_PROSPECTED` set.

---

## 9. Vendor & Extended Costs

### npc_vendor Table

Links items to vendor NPCs.

| Column | Type | Description |
|--------|------|-------------|
| `entry` | MEDIUMINT UNSIGNED | Creature entry from `creature_template.entry`. |
| `slot` | SMALLINT SIGNED | Display position in vendor window. 0-based, top-to-bottom left-to-right. -1 = auto-sorted by server. |
| `item` | MEDIUMINT SIGNED | Item entry from `item_template.entry`. |
| `maxcount` | TINYINT UNSIGNED | Maximum copies vendor carries. 0 = unlimited stock. |
| `incrtime` | INT UNSIGNED | Restock timer in seconds (paired with `maxcount`). If `maxcount`=5 and `incrtime`=3600, vendor restocks 5 items per hour. |
| `ExtendedCost` | MEDIUMINT UNSIGNED | References `ItemExtendedCost.dbc` row ID. 0 = gold-only purchase. |

### ExtendedCost (non-gold currencies)

`ItemExtendedCost.dbc` is a client-side DBC file that defines currency costs. The DBC entry specifies costs in honor points, arena points, or badge/token items. You reference the DBC row's ID in `npc_vendor.ExtendedCost`.

**Key DBC columns (reference only — not modifiable via SQL):**
- `ID` — The value you put in `npc_vendor.ExtendedCost`
- `reqhonorpoints` — Honor point cost
- `reqarenapoints` — Arena point cost
- `reqitem1`–`reqitem5` — Currency item entries (e.g., Emblem of Frost)
- `reqitemcount1`–`reqitemcount5` — Required quantities of each currency item

To add a vendor item that costs honor or arena points:
1. Look up the appropriate DBC row ID in `ItemExtendedCost.dbc` using a DBC browser.
2. Set `npc_vendor.ExtendedCost` to that ID.
3. If the item should also cost gold, set `item_template.FlagsExtra` bit 4 (`0x004`).

**Example — honor vendor:**
```sql
-- Add item 40000 costing honor (ExtendedCost ID 1836 = 10000 honor)
INSERT INTO npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost)
VALUES (7809, 0, 40000, 0, 0, 1836);
```

**Example — badge vendor (e.g., 10 Emblems of Frost):**
```sql
-- ExtendedCost ID found by browsing DBC for the exact badge+count combination
INSERT INTO npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost)
VALUES (34769, 0, 50000, 0, 0, 3724);
```

**Unlimited stock with restock:** Set `maxcount=0, incrtime=0` for infinite stock. Set `maxcount=1, incrtime=86400` for a daily-restocked single item.

---

## 10. Random Enchants

### item_enchantment_template Table

| Column | Type | Description |
|--------|------|-------------|
| `entry` | MEDIUMINT UNSIGNED | Links to `item_template.RandomProperty` or `item_template.RandomSuffix`. Primary key (composite with `ench`). |
| `ench` | MEDIUMINT UNSIGNED | Enchantment ID. Points to `ItemRandomProperties.dbc` (if via RandomProperty) or `ItemRandomSuffix.dbc` (if via RandomSuffix). |
| `chance` | FLOAT UNSIGNED | Probability (0–100). All rows sharing an `entry` must sum to exactly 100.0. |

### RandomProperty vs RandomSuffix

| Field | DBC Reference | Behavior |
|-------|---------------|---------|
| `RandomProperty` | `ItemRandomProperties.dbc` | Named enchants: "of the Tiger", "of Power". Each DBC row defines specific stat bonuses. |
| `RandomSuffix` | `ItemRandomSuffix.dbc` | Stat-value suffixes: "of the Bear". Suffix stats scale with item level. |

Rules:
- An item can have `RandomProperty` OR `RandomSuffix`, never both (leave the other at 0).
- The server rolls a random enchant from `item_enchantment_template` when the item is first created.
- All `chance` values for a given `entry` must total exactly 100.0, or items may sometimes generate without an enchant.

**Example — item with 3 possible random properties:**
```sql
-- item_template: RandomProperty = 501
INSERT INTO item_enchantment_template (entry, ench, chance) VALUES
(501, 14,  40.0),  -- "of the Tiger" (from ItemRandomProperties.dbc row 14)
(501, 15,  35.0),  -- "of the Bear"
(501, 16,  25.0);  -- "of the Eagle"
-- Total: 100.0
```

---

## 11. C++ Item API

### Getting Item Prototypes

```cpp
// Get the ItemTemplate (static data) for an item entry
ItemTemplate const* proto = sObjectMgr->GetItemTemplate(itemEntry);
if (!proto)
    return; // Item entry doesn't exist

// Access fields
uint32 quality  = proto->Quality;
uint32 invType  = proto->InventoryType;
uint32 maxStack = proto->Stackable;
std::string name = proto->Name1; // primary locale
```

### Creating Item Objects

```cpp
// Create a new Item object (not yet in any container)
Item* item = Item::CreateItem(itemEntry, count, player);
if (!item)
    return; // creation failed (invalid entry or count)
```

### Giving Items to a Player

```cpp
// Add item to player inventory. Returns the Item* on success, nullptr on fail.
// (Uses StoreNewItemInBestSlots internally)
ItemPosCountVec dest;
InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, itemEntry, count);
if (msg == EQUIP_ERR_OK)
{
    Item* item = player->StoreNewItem(dest, itemEntry, true);
    // Sends ADD_ITEM packet automatically
}
else
{
    // Inventory full or other error — send to mailbox instead
    MailDraft("Item Delivery", "Your item.")
        .AddItem(Item::CreateItem(itemEntry, count, player))
        .SendMailTo(trans, MailReceiver(player), MailSender(MAIL_NORMAL, 0));
}
```

**Shorthand helpers (Eluna and many scripts use):**
```cpp
// From Player class — handles CanStore check internally, returns nullptr if bag full
player->AddItem(itemEntry, count); // Note: not always available; use StoreNewItem pattern above

// Simpler helper found in some ACore module examples:
player->SendItemRetrievalMail(itemEntry, count); // Mails item if bag is full
```

### Checking Item Counts

```cpp
// Check if player has at least 'count' of itemEntry (searches all bags including bank)
bool hasItem = player->HasItemCount(itemEntry, count, false); // false = don't check bank
bool hasInBank = player->HasItemCount(itemEntry, count, true); // true = include bank

// Get total count across all bags
uint32 total = player->GetItemCount(itemEntry, false);
```

### Removing Items

```cpp
// Remove 'count' copies of itemEntry from player.
// update=true sends the UPDATE_ITEM packet.
player->DestroyItemCount(itemEntry, count, true /*update*/, false /*unequip*/);
```

### Equipping Items

```cpp
// Find the best slot for an item and equip it
uint16 dest;
InventoryResult result = player->CanEquipNewItem(NULL_SLOT, dest, itemEntry, false);
if (result == EQUIP_ERR_OK)
    player->EquipNewItem(dest, itemEntry, true);
```

### ItemScript — Custom Item Logic

```cpp
class MyItemScript : public ItemScript
{
public:
    MyItemScript() : ItemScript("MyItemScript") {}

    // Fires when item is used (spelltrigger=0 or 5)
    bool OnUse(Player* player, Item* item, SpellCastTargets const& targets) override
    {
        // Return true to prevent the item spell from firing
        // Return false to allow normal spell cast
        player->CastSpell(player, 12345, true);
        return true; // we handled it
    }

    // Fires when item is equipped
    void OnEquip(Player* player, Item* item, bool /*inArena*/) override
    {
        player->CastSpell(player, SPELL_SOME_BUFF, true);
    }

    // Fires when item is unequipped
    void OnUnequip(Player* player, Item* item, bool /*inArena*/) override
    {
        player->RemoveAurasDueToSpell(SPELL_SOME_BUFF);
    }

    // Called when item is destroyed
    void OnDestroyed(Player* player, Item* item, uint8 count) override {}
};

void AddSC_MyItemScript()
{
    new MyItemScript();
}
```

Set `item_template.ScriptName = 'MyItemScript'` in the database.

---

## 12. Cross-References

| Topic | Location |
|-------|----------|
| Creature loot linking | `creature_template.lootid` → `creature_loot_template.Entry` |
| GameObject loot linking | `gameobject_template.data1` → `gameobject_loot_template.Entry` |
| Item disenchant results | `item_template.DisenchantID` → `disenchant_loot_template.Entry` |
| Vendor extended cost | `npc_vendor.ExtendedCost` → `ItemExtendedCost.dbc` |
| Random property names | `item_template.RandomProperty` → `item_enchantment_template.entry` → `ItemRandomProperties.dbc` |
| Random stat suffixes | `item_template.RandomSuffix` → `item_enchantment_template.entry` → `ItemRandomSuffix.dbc` |
| Socket bonus enchant | `item_template.socketBonus` → `SpellItemEnchantment.dbc` |
| Item set bonuses | `item_template.itemset` → `ItemSet.dbc` |
| Quest started by item | `item_template.startquest` → `quest_template.ID` |
| Conditions on loot | `conditions` table, SourceType=1 (CREATURE_LOOT)–12 |
| Quest item drops | `creature_loot_template.QuestRequired=1` |
| C++ Quest API | `07_quest_system.md` |
| SmartAI hooks | `kb_azerothcore_dev.md` |
| Eluna item API | `kb_eluna_api.md` |
