# DBC Access

DBC (DataBase Client) files are binary table files shipped with the WoW 3.3.5a client. Each file encodes a flat relational table with a fixed record format and an optional string block. Every row has a numeric ID in column 0 that acts as the primary key. AzerothCore loads every relevant DBC file into memory at world-server startup and exposes the data through typed `DBCStorage<T>` globals. Modules access these globals directly — no database query is needed.

---

## 1. Overview

### What DBC Files Are

DBC files use a binary format (`WDBC` magic, header with record count / field count / record size / string block size, then rows, then a string pool). Strings inside a record are stored as 32-bit offsets into the string block; after loading, AC resolves each offset to a `char const*` in memory. Localized strings are stored as 16 consecutive `char*` fields (one per client locale), plus a flags uint32.

### How AzerothCore Loads Them

`LoadDBCStores(const std::string& dataPath)` is called once during worldserver startup (from `World::SetInitialWorldSettings`). It:

1. Constructs the path `dataPath + "dbc/"` (typically pointing to `wow335a/acore_data_files/dbc/`).
2. Calls the templated `LoadDBC(...)` helper for every store. The helper:
   - Loads the base `.dbc` file into the store's index table.
   - Iterates available locales and calls `LoadStringsFrom` for each locale subdirectory to overlay localized strings.
   - Optionally calls `LoadFromDB` if there is a `*_dbc` override table in the world database (allowing server-side overrides without recompiling).
3. Verifies that the format string record size matches `sizeof(T)`; crashes with an assertion if not.

The DBC data path is set in `worldserver.conf` under `DataDir`.

### The `DBCStorage<T>` Template

```cpp
// Defined in src/server/shared/DataStores/DBCStore.h
template <class T>
class DBCStorage : public DBCStorageBase
{
public:
    T const* LookupEntry(uint32 id) const;   // O(1) array lookup, returns nullptr if id >= table size or slot is null
    T const* AssertEntry(uint32 id) const;   // Same but ASSERT-crashes on nullptr
    void     SetEntry(uint32 id, T* t);      // Replace/add an entry (used for DB overrides)
    uint32   GetNumRows() const;             // Size of the index array (not the count of valid rows)
    iterator begin();
    iterator end();
};
```

The index table is a flat pointer array: `_indexTable[id]` is a `T*` or `nullptr`. `GetNumRows()` returns the array's allocated size, not the count of non-null rows.

---

## 2. How to Access DBC Data in a Module

```cpp
#include "DBCStores.h"

// --- Look up by ID --- returns nullptr if not found
if (SpellEntry const* spell = sSpellStore.LookupEntry(spellId))
{
    uint32 school    = spell->SchoolMask;
    uint32 castIndex = spell->CastingTimeIndex;
    const char* name = spell->SpellName[0]; // enUS
}

// --- Assert entry (crashes if missing — use only when you know the ID is valid)
SpellEntry const* spell = sSpellStore.AssertEntry(spellId);

// --- Iterate all entries (range-for via begin()/end())
for (uint32 i = 0; i < sSpellStore.GetNumRows(); ++i)
{
    SpellEntry const* spell = sSpellStore.LookupEntry(i);
    if (!spell)
        continue;
    // process spell
}

// --- Iterate using range-for (iterator skips null slots)
for (SpellEntry const& spell : sSpellStore)
{
    // every spell here is valid
}
```

---

## 3. All DBC Stores — Complete Reference Table

Every `extern DBCStorage<T>` declared in `DBCStores.h`, with the corresponding `.dbc` file from the `LoadDBCStores` call list.

| Store Variable | Entry Struct | DBC File | Key Fields / Use Case |
|---|---|---|---|
| `sAchievementStore` | `AchievementEntry` | `Achievement.dbc` | Achievement definitions: ID, requiredFaction, mapID, name, categoryId, points, flags |
| `sAchievementCriteriaStore` | `AchievementCriteriaEntry` | `Achievement_Criteria.dbc` | Criteria for each achievement, typed union for 40+ criteria types |
| `sAchievementCategoryStore` | `AchievementCategoryEntry` | `Achievement_Category.dbc` | Category hierarchy: ID, parentCategory |
| `sAreaTableStore` | `AreaTableEntry` | `AreaTable.dbc` | Zone/area info: ID, mapid, zone (parent), exploreFlag, flags, area_level, area_name, team |
| `sAreaGroupStore` | `AreaGroupEntry` | `AreaGroup.dbc` | Groups of up to 6 area IDs, linked list via nextGroup |
| `sAreaPOIStore` | `AreaPOIEntry` | `AreaPOI.dbc` | Points of interest: id, coordinates, mapId, zoneId, worldState |
| `sAuctionHouseStore` | `AuctionHouseEntry` | `AuctionHouse.dbc` | Auction house definitions: houseId, faction, depositPercent, cutPercent |
| `sBankBagSlotPricesStore` | `BankBagSlotPricesEntry` | `BankBagSlotPrices.dbc` | Bank slot unlock costs: ID, price |
| `sBarberShopStyleStore` | `BarberShopStyleEntry` | `BarberShopStyle.dbc` | Barber shop hair/facial hair styles: Id, type, race, gender, hair_id |
| `sBattlemasterListStore` | `BattlemasterListEntry` | `BattlemasterList.dbc` | BG/arena queue definitions: id, mapid[8], type, name, maxGroupSize, HolidayWorldStateId |
| `sChatChannelsStore` | `ChatChannelsEntry` | `ChatChannels.dbc` | Default chat channel definitions: ChannelID, flags, pattern |
| `sCharStartOutfitStore` | `CharStartOutfitEntry` | `CharStartOutfit.dbc` | Starting gear per race/class/gender: Race, Class, Gender, ItemId[24] |
| `sCharTitlesStore` | `CharTitlesEntry` | `CharTitles.dbc` | Player titles: ID, nameMale[16], nameFemale[16], bit_index |
| `sChrClassesStore` | `ChrClassesEntry` | `ChrClasses.dbc` | Class definitions: ClassID, powerType, name[16], spellfamily, CinematicSequence, expansion |
| `sChrRacesStore` | `ChrRacesEntry` | `ChrRaces.dbc` | Race definitions: RaceID, Flags, FactionID, model_m, model_f, TeamID, alliance, name[16], expansion |
| `sCinematicCameraStore` | `CinematicCameraEntry` | `CinematicCamera.dbc` | Cinematic camera positions: ID, Model, SoundID, Origin, OriginFacing |
| `sCinematicSequencesStore` | `CinematicSequencesEntry` | `CinematicSequences.dbc` | Cinematic sequence → camera mapping: Id, cinematicCamera |
| `sCreatureDisplayInfoStore` | `CreatureDisplayInfoEntry` | `CreatureDisplayInfo.dbc` | Creature visual data: Displayid, ModelId, ExtendedDisplayInfoID, scale |
| `sCreatureDisplayInfoExtraStore` | `CreatureDisplayInfoExtraEntry` | `CreatureDisplayInfoExtra.dbc` | Extra humanoid display info: DisplayRaceID |
| `sCreatureFamilyStore` | `CreatureFamilyEntry` | `CreatureFamily.dbc` | Pet family data: ID, minScale, maxScale, skillLine[2], petFoodMask, petTalentType, Name[16] |
| `sCreatureModelDataStore` | `CreatureModelDataEntry` | `CreatureModelData.dbc` | Model collision data: Id, Flags, Scale, CollisionWidth, CollisionHeight, MountHeight |
| `sCreatureSpellDataStore` | `CreatureSpellDataEntry` | `CreatureSpellData.dbc` | Creature spell slots: ID, spellId[4] |
| `sCreatureTypeStore` | `CreatureTypeEntry` | `CreatureType.dbc` | Creature type IDs: ID |
| `sCurrencyTypesStore` | `CurrencyTypesEntry` | `CurrencyTypes.dbc` | Currency: ItemId (used as key), BitIndex |
| `sDestructibleModelDataStore` | `DestructibleModelDataEntry` | `DestructibleModelData.dbc` | GO phase display IDs: Id, DamagedDisplayId, DestroyedDisplayId, RebuildingDisplayId, SmokeDisplayId |
| `sDungeonEncounterStore` | `DungeonEncounterEntry` | `DungeonEncounter.dbc` | Boss encounter data: id, mapId, difficulty, encounterIndex, encounterName[16] |
| `sDurabilityCostsStore` | `DurabilityCostsEntry` | `DurabilityCosts.dbc` | Repair cost multipliers by item level: Itemlvl, multiplier[29] |
| `sDurabilityQualityStore` | `DurabilityQualityEntry` | `DurabilityQuality.dbc` | Quality modifier for repair costs: Id, quality_mod |
| `sEmotesStore` | `EmotesEntry` | `Emotes.dbc` | Emote mechanics: Id, Flags, EmoteType, UnitStandState |
| `sEmotesTextStore` | `EmotesTextEntry` | `EmotesText.dbc` | Text emote mapping: Id, textid |
| `sFactionStore` | `FactionEntry` | `Faction.dbc` | Faction reputation data: ID, reputationListID, BaseRepValue[4], team, name[16] |
| `sFactionTemplateStore` | `FactionTemplateEntry` | `FactionTemplate.dbc` | Faction combat behavior: ID, faction, ourMask, friendlyMask, hostileMask, enemyFaction[4], friendFaction[4] |
| `sGameObjectArtKitStore` | `GameObjectArtKitEntry` | `GameObjectArtKit.dbc` | GO art kit: ID |
| `sGameObjectDisplayInfoStore` | `GameObjectDisplayInfoEntry` | `GameObjectDisplayInfo.dbc` | GO display: Displayid, filename, bounding box min/max |
| `sGemPropertiesStore` | `GemPropertiesEntry` | `GemProperties.dbc` | Gem: ID, spellitemenchantement, color |
| `sGlyphPropertiesStore` | `GlyphPropertiesEntry` | `GlyphProperties.dbc` | Glyph definition: Id, SpellId, TypeFlags |
| `sGlyphSlotStore` | `GlyphSlotEntry` | `GlyphSlot.dbc` | Glyph slot: Id, TypeFlags, Order |
| `sGtBarberShopCostBaseStore` | `GtBarberShopCostBaseEntry` | `gtBarberShopCostBase.dbc` | Per-level barber cost base: cost (float) |
| `sGtCombatRatingsStore` | `GtCombatRatingsEntry` | `gtCombatRatings.dbc` | Combat rating denominators: ratio (float) |
| `sGtChanceToMeleeCritBaseStore` | `GtChanceToMeleeCritBaseEntry` | `gtChanceToMeleeCritBase.dbc` | Base melee crit chance: base (float) |
| `sGtChanceToMeleeCritStore` | `GtChanceToMeleeCritEntry` | `gtChanceToMeleeCrit.dbc` | Per-level melee crit ratio: ratio (float) |
| `sGtChanceToSpellCritBaseStore` | `GtChanceToSpellCritBaseEntry` | `gtChanceToSpellCritBase.dbc` | Base spell crit chance: base (float) |
| `sGtChanceToSpellCritStore` | `GtChanceToSpellCritEntry` | `gtChanceToSpellCrit.dbc` | Per-level spell crit ratio: ratio (float) |
| `sGtNPCManaCostScalerStore` | `GtNPCManaCostScalerEntry` | `gtNPCManaCostScaler.dbc` | NPC mana cost scaling: ratio (float) |
| `sGtOCTClassCombatRatingScalarStore` | `GtOCTClassCombatRatingScalarEntry` | `gtOCTClassCombatRatingScalar.dbc` | Class combat rating scalars (32 ratings): ratio (float) |
| `sGtOCTRegenHPStore` | `GtOCTRegenHPEntry` | `gtOCTRegenHP.dbc` | Out-of-combat HP regen: ratio (float) |
| `sGtRegenHPPerSptStore` | `GtRegenHPPerSptEntry` | `gtRegenHPPerSpt.dbc` | HP regen per spirit: ratio (float) |
| `sGtRegenMPPerSptStore` | `GtRegenMPPerSptEntry` | `gtRegenMPPerSpt.dbc` | MP regen per spirit: ratio (float) |
| `sHolidaysStore` | `HolidaysEntry` | `Holidays.dbc` | In-game holiday definitions: Id, Duration[10], Date[26], Region, Looping, CalendarFlags[10], TextureFilename, Priority, CalendarFilterType |
| `sItemStore` | `ItemEntry` | `Item.dbc` | Item client display info: ID, ClassID, SubclassID, Material, DisplayInfoID, InventoryType, SheatheType |
| `sItemBagFamilyStore` | `ItemBagFamilyEntry` | `ItemBagFamily.dbc` | Bag family: ID |
| `sItemDisplayInfoStore` | `ItemDisplayInfoEntry` | `ItemDisplayInfo.dbc` | Item display: ID, inventoryIcon |
| `sItemExtendedCostStore` | `ItemExtendedCostEntry` | `ItemExtendedCost.dbc` | Honor/arena/item purchase requirements: ID, reqhonorpoints, reqarenapoints, reqarenaslot, reqitem[5], reqitemcount[5], reqpersonalarenarating |
| `sItemLimitCategoryStore` | `ItemLimitCategoryEntry` | `ItemLimitCategory.dbc` | Equip limits (e.g., trinkets): ID, maxCount, mode |
| `sItemRandomPropertiesStore` | `ItemRandomPropertiesEntry` | `ItemRandomProperties.dbc` | Random property enchantments: ID, Enchantment[5], Name[16] |
| `sItemRandomSuffixStore` | `ItemRandomSuffixEntry` | `ItemRandomSuffix.dbc` | Random suffix enchantments: ID, Name[16], Enchantment[5], AllocationPct[5] |
| `sItemSetStore` | `ItemSetEntry` | `ItemSet.dbc` | Item set bonuses: name[16], itemId[10], spells[8], items_to_triggerspell[8], required_skill_id, required_skill_value |
| `sLFGDungeonStore` | `LFGDungeonEntry` | `LFGDungeons.dbc` | LFG dungeon data: ID, Name[16], MinLevel, MaxLevel, MapID, Difficulty, TypeID, GroupID |
| `sLiquidTypeStore` | `LiquidTypeEntry` | `LiquidType.dbc` | Liquid type: Id, Type, SpellId (damage/drowning spell) |
| `sLockStore` | `LockEntry` | `Lock.dbc` | Lock mechanisms: ID, Type[8], Index[8], Skill[8] |
| `sMailTemplateStore` | `MailTemplateEntry` | `MailTemplate.dbc` | Mail body text: ID, content[16] |
| `sMapStore` | `MapEntry` | `Map.dbc` | Map definitions: MapID, map_type, Flags, name[16], linked_zone, entrance_map/x/y, expansionID, maxPlayers |
| `sMapDifficultyMap` | `MapDifficulty` | `MapDifficulty.dbc` | Use `GetMapDifficultyData(mapId, difficulty)` — not a direct store |
| `sMovieStore` | `MovieEntry` | `Movie.dbc` | Movie: Id |
| `sNamesReservedStore` | `NamesReservedEntry` | `NamesReserved.dbc` | Reserved name patterns: Pattern |
| `sNamesProfanityStore` | `NamesProfanityEntry` | `NamesProfanity.dbc` | Profanity name patterns: Pattern |
| `sOverrideSpellDataStore` | `OverrideSpellDataEntry` | `OverrideSpellData.dbc` | Override action bar spells: id, spellId[10] |
| `sPowerDisplayStore` | `PowerDisplayEntry` | `PowerDisplay.dbc` | Custom power display: Id, PowerType |
| `sQuestSortStore` | `QuestSortEntry` | `QuestSort.dbc` | Quest sort categories: id |
| `sQuestXPStore` | `QuestXPEntry` | `QuestXP.dbc` | Quest XP reward by level: id, Exp[10] |
| `sQuestFactionRewardStore` | `QuestFactionRewEntry` | `QuestFactionReward.dbc` | Quest faction reward values: id, QuestRewFactionValue[10] |
| `sRandomPropertiesPointsStore` | `RandomPropertiesPointsEntry` | `RandPropPoints.dbc` | Random property point budgets by item level: itemLevel, Epic/Rare/UncommonPropertiesPoints[5] |
| `sScalingStatDistributionStore` | `ScalingStatDistributionEntry` | `ScalingStatDistribution.dbc` | Heirloom scaling: Id, StatMod[10], Modifier[10], MaxLevel |
| `sScalingStatValuesStore` | `ScalingStatValuesEntry` | `ScalingStatValues.dbc` | Per-level scaling values: Id, Level, ssdMultiplier[4], armorMod[4], dpsMod[6], spellPower |
| `sSkillLineStore` | `SkillLineEntry` | `SkillLine.dbc` | Skill definitions: id, categoryId, name[16], spellIcon, canLink |
| `sSkillLineAbilityStore` | `SkillLineAbilityEntry` | `SkillLineAbility.dbc` | Spell-to-skill mappings: ID, SkillLine, Spell, RaceMask, ClassMask, MinSkillLineRank, SupercededBySpell, AcquireMethod |
| `sSkillTiersStore` | `SkillTiersEntry` | `SkillTiers.dbc` | Skill tier max values: ID, Value[16] |
| `sSoundEntriesStore` | `SoundEntriesEntry` | `SoundEntries.dbc` | Sound: Id (most fields unused server-side) |
| `sSpellCastTimesStore` | `SpellCastTimesEntry` | `SpellCastTimes.dbc` | Cast time lookup: ID, CastTime (ms) |
| `sSpellCategoryStore` | `SpellCategoryEntry` | `SpellCategory.dbc` | Spell category flags: Id, Flags |
| `sSpellDifficultyStore` | `SpellDifficultyEntry` | `SpellDifficulty.dbc` | Difficulty-adjusted spell IDs: ID, SpellID[4] (10N/25N/10H/25H) |
| `sSpellDurationStore` | `SpellDurationEntry` | `SpellDuration.dbc` | Duration lookup: ID, Duration[3] |
| `sSpellFocusObjectStore` | `SpellFocusObjectEntry` | `SpellFocusObject.dbc` | Spell focus object: ID |
| `sSpellItemEnchantmentStore` | `SpellItemEnchantmentEntry` | `SpellItemEnchantment.dbc` | Enchantment data: ID, charges, type[3], amount[3], spellid[3], description[16], aura_id, slot, GemID, requiredSkill/Level |
| `sSpellItemEnchantmentConditionStore` | `SpellItemEnchantmentConditionEntry` | `SpellItemEnchantmentCondition.dbc` | Gem condition logic: ID, Color[5], Comparator[5], CompareColor[5], Value[5] |
| `sSpellRadiusStore` | `SpellRadiusEntry` | `SpellRadius.dbc` | Radius lookup: ID, RadiusMin, RadiusPerLevel, RadiusMax |
| `sSpellRangeStore` | `SpellRangeEntry` | `SpellRange.dbc` | Range lookup: ID, RangeMin[2], RangeMax[2] (hostile/friendly), Flags |
| `sSpellRuneCostStore` | `SpellRuneCostEntry` | `SpellRuneCost.dbc` | DK rune costs: ID, RuneCost[3] (blood/frost/unholy), runePowerGain |
| `sSpellShapeshiftFormStore` | `SpellShapeshiftFormEntry` | `SpellShapeshiftForm.dbc` | Shapeshift form data: ID, flags1, creatureType, attackSpeed, modelID_A, modelID_H, stanceSpell[8] |
| `sSpellStore` | `SpellEntry` | `Spell.dbc` | Full spell definitions (see Section 4) |
| `sSpellVisualStore` | `SpellVisualEntry` | `SpellVisual.dbc` | Spell missile data: HasMissile, MissileModel |
| `sStableSlotPricesStore` | `StableSlotPricesEntry` | `StableSlotPrices.dbc` | Stable slot costs: Slot, Price |
| `sSummonPropertiesStore` | `SummonPropertiesEntry` | `SummonProperties.dbc` | Summon behavior: Id, Category, Faction, Type, Slot, Flags |
| `sTalentStore` | `TalentEntry` | `Talent.dbc` | Talent definitions: TalentID, TalentTab, Row, Col, RankID[5], DependsOn, DependsOnRank |
| `sTalentTabStore` | `TalentTabEntry` | `TalentTab.dbc` | Talent tree tabs: TalentTabID, ClassMask, petTalentMask, tabpage |
| `sTaxiNodesStore` | `TaxiNodesEntry` | `TaxiNodes.dbc` | Flight points: ID, map_id, x/y/z, name[16], MountCreatureID[2] |
| `sTaxiPathStore` | `TaxiPathEntry` | `TaxiPath.dbc` | Flight paths: ID, from, to, price |
| `sTeamContributionPointsStore` | `TeamContributionPointsEntry` | `TeamContributionPoints.dbc` | Team contribution points value: value (float) |
| `sTotemCategoryStore` | `TotemCategoryEntry` | `TotemCategory.dbc` | Totem/tool categories: ID, categoryType, categoryMask |
| `sVehicleStore` | `VehicleEntry` | `Vehicle.dbc` | Vehicle movement data: m_ID, m_flags, m_seatID[8], turn/pitch speeds, camera offsets |
| `sVehicleSeatStore` | `VehicleSeatEntry` | `VehicleSeat.dbc` | Per-seat config: m_ID, m_flags, m_attachmentID, enter/exit/ride animation IDs, passenger offsets |
| `sWMOAreaTableStore` | `WMOAreaTableEntry` | `WMOAreaTable.dbc` | WMO area info: Id, rootId, adtId, groupId, Flags, areaId; use `GetWMOAreaTableEntryByTripple()` |
| `sWorldMapOverlayStore` | `WorldMapOverlayEntry` | `WorldMapOverlay.dbc` | World map overlays: ID, areatableID[4] |

**Not directly exposed as a public store (use helper functions instead):**
- `MapDifficultyMap sMapDifficultyMap` — use `GetMapDifficultyData(mapId, difficulty)`
- `WorldMapAreaEntry` — use `Zone2MapCoordinates()` / `Map2ZoneCoordinates()`
- Taxi path nodes — use `sTaxiPathNodesByPath`
- Taxi masks — use `sTaxiNodesMask`, `sHordeTaxiNodesMask`, `sAllianceTaxiNodesMask`, etc.

---

## 4. Key DBC Structs — Field Reference

### SpellEntry

The most important struct. All fields from `DBCStructure.h`, grouped by function.

**Basic identity**
| Field | Type | Notes |
|---|---|---|
| `Id` | `uint32` | Spell ID |
| `Category` | `uint32` | Spell category (shared cooldown group) |
| `Dispel` | `uint32` | Dispel type (magic, curse, poison, disease...) |
| `Mechanic` | `uint32` | Spell mechanic (stun, root, slow...) |
| `SpellFamilyName` | `uint32` | Spell class set / family (e.g., SPELLFAMILY_MAGE = 3) |
| `SpellFamilyFlags` | `flag96` | 96-bit mask identifying specific spells within the family |
| `DmgClass` | `uint32` | Defense type: 0=none, 1=magic, 2=melee, 3=ranged |
| `PreventionType` | `uint32` | 0=none, 1=silence, 2=pacify |
| `SchoolMask` | `uint32` | Damage school bitmask (1=phys, 2=holy, 4=fire, 8=nature, 16=frost, 32=shadow, 64=arcane) |

**Attributes**
| Field | Type | Notes |
|---|---|---|
| `Attributes` | `uint32` | Core spell flags (SPELL_ATTR0_*) |
| `AttributesEx` | `uint32` | Extended flags 1 (SPELL_ATTR1_*) |
| `AttributesEx2` | `uint32` | Extended flags 2 |
| `AttributesEx3` | `uint32` | Extended flags 3 |
| `AttributesEx4` | `uint32` | Extended flags 4 |
| `AttributesEx5` | `uint32` | Extended flags 5 |
| `AttributesEx6` | `uint32` | Extended flags 6 |
| `AttributesEx7` | `uint32` | Extended flags 7 |
| `Stances` | `uint32` | Required shapeshift form mask to cast |
| `StancesNot` | `uint32` | Shapeshift forms that block casting |

**Targeting**
| Field | Type | Notes |
|---|---|---|
| `Targets` | `uint32` | Valid target flags |
| `TargetCreatureType` | `uint32` | Required creature type mask |
| `RequiresSpellFocus` | `uint32` | SpellFocusObject.dbc ID required nearby |
| `FacingCasterFlags` | `uint32` | 0x1 = target must face caster |
| `CasterAuraState` | `uint32` | Required caster aura state |
| `TargetAuraState` | `uint32` | Required target aura state |
| `CasterAuraStateNot` | `uint32` | Excluded caster aura state |
| `TargetAuraStateNot` | `uint32` | Excluded target aura state |
| `CasterAuraSpell` | `uint32` | Caster must have this spell's aura |
| `TargetAuraSpell` | `uint32` | Target must have this spell's aura |
| `ExcludeCasterAuraSpell` | `uint32` | Caster must NOT have this aura |
| `ExcludeTargetAuraSpell` | `uint32` | Target must NOT have this aura |
| `MaxTargetLevel` | `uint32` | Max target level |
| `MaxAffectedTargets` | `uint32` | Chain/AoE target cap |
| `AreaGroupId` | `int32` | Required area group |

**Timing**
| Field | Type | Notes |
|---|---|---|
| `CastingTimeIndex` | `uint32` | Index into SpellCastTimes.dbc — use `sSpellCastTimesStore.LookupEntry(spell->CastingTimeIndex)->CastTime` |
| `RecoveryTime` | `uint32` | Cooldown in ms |
| `CategoryRecoveryTime` | `uint32` | Category cooldown in ms |
| `DurationIndex` | `uint32` | Index into SpellDuration.dbc |
| `RangeIndex` | `uint32` | Index into SpellRange.dbc |
| `StartRecoveryCategory` | `uint32` | GCD category |
| `StartRecoveryTime` | `uint32` | GCD time in ms |
| `InterruptFlags` | `uint32` | What movement/actions interrupt the cast |
| `AuraInterruptFlags` | `uint32` | What cancels this aura |
| `ChannelInterruptFlags` | `uint32` | What interrupts channeling |
| `Speed` | `float` | Missile/projectile speed |
| `MaxLevel` | `uint32` | Max level this spell scales to |
| `BaseLevel` | `uint32` | Min base level |
| `SpellLevel` | `uint32` | Level spell was learned |
| `StackAmount` | `uint32` | Max stack count |

**Costs**
| Field | Type | Notes |
|---|---|---|
| `PowerType` | `uint32` | 0=mana, 1=rage, 3=energy, 6=runic power, etc. |
| `ManaCost` | `uint32` | Flat mana/resource cost |
| `ManaCostPerlevel` | `uint32` | Additional cost per level |
| `ManaCostPercentage` | `uint32` | Cost as % of base mana |
| `ManaPerSecond` | `uint32` | Channeled drain per second |
| `ManaPerSecondPerLevel` | `uint32` | Additional drain per level |
| `RuneCostID` | `uint32` | SpellRuneCost.dbc ID for DK spells |
| `Reagent` | `int32[8]` | Required reagent item IDs |
| `ReagentCount` | `uint32[8]` | Required reagent counts |
| `Totem` | `uint32[2]` | Required totem item IDs |
| `TotemCategory` | `uint32[2]` | Required totem category IDs |
| `EquippedItemClass` | `int32` | Required equipped item class (-1 = none) |
| `EquippedItemSubClassMask` | `int32` | Required equipped item subclass mask |
| `EquippedItemInventoryTypeMask` | `int32` | Required equipped item inventory type mask |

**Effects** (indexed 0–2, `MAX_SPELL_EFFECTS = 3`)
| Field | Type | Notes |
|---|---|---|
| `Effect[3]` | `uint32[3]` | Effect type IDs (SPELL_EFFECT_*) |
| `EffectApplyAuraName[3]` | `uint32[3]` | Aura type for EFFECT_APPLY_AURA (SPELL_AURA_*) |
| `EffectBasePoints[3]` | `int32[3]` | Base damage/value (use `Spell::m_currentBasePoints` at runtime, not this directly) |
| `EffectDieSides[3]` | `int32[3]` | Dice sides for random component |
| `EffectRealPointsPerLevel[3]` | `float[3]` | Additional points per caster level |
| `EffectBonusMultiplier[3]` | `float[3]` | SP/AP coefficient for the effect (3.2+) |
| `EffectValueMultiplier[3]` | `float[3]` | Effect value multiplier |
| `EffectDamageMultiplier[3]` | `float[3]` | Chain damage amplitude |
| `EffectMechanic[3]` | `uint32[3]` | Per-effect mechanic |
| `EffectImplicitTargetA[3]` | `uint32[3]` | Primary implicit target type |
| `EffectImplicitTargetB[3]` | `uint32[3]` | Secondary implicit target type |
| `EffectRadiusIndex[3]` | `uint32[3]` | SpellRadius.dbc index |
| `EffectAmplitude[3]` | `uint32[3]` | Aura tick period (ms) |
| `EffectChainTarget[3]` | `uint32[3]` | Chain target count |
| `EffectItemType[3]` | `uint32[3]` | Item created by this effect |
| `EffectMiscValue[3]` | `int32[3]` | Misc value (aura modifier type, shapeshift form, etc.) |
| `EffectMiscValueB[3]` | `int32[3]` | Second misc value |
| `EffectTriggerSpell[3]` | `uint32[3]` | Triggered spell ID |
| `EffectPointsPerComboPoint[3]` | `float[3]` | Combo point scaling |
| `EffectSpellClassMask[3]` | `flag96[3]` | Spell family mask for what this effect modifies |

**Proc**
| Field | Type | Notes |
|---|---|---|
| `ProcFlags` | `uint32` | Trigger conditions bitmask (PROC_FLAG_*) |
| `ProcChance` | `uint32` | Proc chance % |
| `ProcCharges` | `uint32` | Number of charges |

**Visual / UI**
| Field | Type | Notes |
|---|---|---|
| `SpellVisual[2]` | `uint32[2]` | SpellVisual.dbc IDs |
| `SpellIconID` | `uint32` | SpellIcon.dbc ID for the spell book icon |
| `ActiveIconID` | `uint32` | SpellIcon.dbc ID for the aura buff icon |

**Text**
| Field | Type | Notes |
|---|---|---|
| `SpellName[16]` | `char const*[16]` | Localized spell name (index 0 = enUS) |
| `Rank[16]` | `char const*[16]` | Rank string, e.g. "Rank 1" |

---

### MapEntry

```
MapID          uint32   Map numeric ID
map_type       uint32   MAP_COMMON(0), MAP_INSTANCE(1), MAP_RAID(2), MAP_BATTLEGROUND(3), MAP_ARENA(4)
Flags          uint32   MAP_FLAG_* bitmask
name[16]       char const*[16]  Localized map name
linked_zone    uint32   Zone area ID for this map
multimap_id    uint32   Parent map for instances
entrance_map   int32    Map ID of entrance (-1 if none)
entrance_x     float    Entrance X coordinate
entrance_y     float    Entrance Y coordinate
expansionID    uint32   0=Vanilla, 1=TBC, 2=WotLK
maxPlayers     uint32   Default max players (fallback if not in MapDifficulty.dbc)
```

Helper methods on `MapEntry`:
- `IsDungeon()` — MAP_INSTANCE or MAP_RAID
- `IsNonRaidDungeon()` — MAP_INSTANCE only
- `Instanceable()` — instance, raid, BG, or arena
- `IsRaid()`, `IsBattleground()`, `IsBattleArena()`
- `IsWorldMap()` — open world (MAP_COMMON)
- `IsContinent()` — Eastern Kingdoms, Kalimdor, Outland, or Northrend
- `IsDynamicDifficultyMap()`
- `GetEntrancePos(mapid, x, y)`

---

### AreaTableEntry

```
ID              uint32           Area ID
mapid           uint32           Which map this area belongs to
zone            uint32           Parent zone ID (0 if this is a top-level zone)
exploreFlag     uint32           Exploration bit index
flags           uint32           AREA_FLAG_* bitmask (includes AREA_FLAG_SANCTUARY, AREA_FLAG_OUTLAND)
area_level      int32            Recommended level
area_name[16]   char const*[16]  Localized area name
team            uint32           Controlling team (2=horde, 4=alliance, 6=contested)
LiquidTypeOverride[4]  uint32[4] Liquid type overrides per liquid category
```

Helper methods: `IsSanctuary()`, `IsFlyable()`

---

### CreatureDisplayInfoEntry

```
Displayid              uint32   Display ID (key)
ModelId                uint32   CreatureModelData.dbc ID
ExtendedDisplayInfoID  uint32   CreatureDisplayInfoExtra.dbc ID (for humanoid mobs)
scale                  float    Model scale multiplier
```

Note: SoundID and texture fields are present in the DBC but commented out in the struct (not read server-side).

---

### ItemEntry (Item.dbc — client display info only)

```
ID               uint32   Item ID
ClassID          uint32   Item class (weapon, armor, etc.)
SubclassID       uint32   Item subclass
SoundOverrideSubclassID  int32  Sound override (-1 = use SubclassID)
Material         int32    Material type
DisplayInfoID    uint32   ItemDisplayInfo.dbc ID for the 3D model
InventoryType    uint32   Inventory slot type
SheatheType      uint32   Sheath animation type
```

This is the *client display* record. Full server-side item data (stats, bonuses, etc.) lives in the `item_template` world database table.

---

### ChrClassesEntry

```
ClassID            uint32         Class ID (1=warrior, 2=paladin, ...)
powerType          uint32         Primary resource (0=mana, 1=rage, 3=energy, 6=runic power)
name[16]           char const*[16] Localized class name (male)
spellfamily        uint32         SpellFamilyName value for this class
CinematicSequence  uint32         Intro cinematic ID
expansion          uint32         Expansion that introduced the class
```

---

### ChrRacesEntry

```
RaceID             uint32         Race ID (1=human, 2=orc, ...)
Flags              uint32         ChrRacesFlags bitmask (NOT_PLAYABLE, BARE_FEET, CAN_MOUNT)
FactionID          uint32         Faction template ID
model_m            uint32         Male display ID
model_f            uint32         Female display ID
TeamID             uint32         7=Alliance, 1=Horde
CinematicSequence  uint32         Intro cinematic ID
alliance           uint32         0=Alliance, 1=Horde, 2=not available
name[16]           char const*[16] Localized race name
expansion          uint32         0=Vanilla, 1=TBC, 2=WotLK
```

Helper: `HasFlag(ChrRacesFlags flag)`

Note: `FactionID`, `ExplorationSoundID`, `ClientPrefix`, `BaseLanguage`, `CreatureType`, `ResSicknessSpellID`, `SplashSoundID`, and `ClientFileString` fields are present in the DBC columns but not read into the struct (commented out as unused server-side).

---

### TalentEntry

```
TalentID      uint32      Talent ID
TalentTab     uint32      TalentTab.dbc row index
Row           uint32      Row in talent tree (0-based)
Col           uint32      Column in talent tree (0-based)
RankID[5]     uint32[5]   Spell IDs for ranks 1–5 (0 = not present)
DependsOn     uint32      Prerequisite talent ID
DependsOnRank uint32      Required rank of prerequisite
addToSpellBook uint32     Whether the highest rank appears in spell book
```

### TalentTabEntry

```
TalentTabID   uint32   Tab ID
ClassMask     uint32   Which class uses this tab (bitmask: 1<<(classId-1))
petTalentMask uint32   Pet talent mask
tabpage       uint32   Tab order index (0, 1, or 2)
```

Use `GetTalentTabPages(cls)` to get the three tab IDs for a given class. Use `GetTalentSpellCost(spellId)` and `GetTalentSpellPos(spellId)` for talent spell lookups.

---

### SkillLineEntry

```
id           uint32         Skill ID
categoryId   int32          Skill category
name[16]     char const*[16] Localized skill name
spellIcon    uint32         SpellIcon.dbc ID
canLink      uint32         Whether recipes can link to this skill
```

### SkillLineAbilityEntry

```
ID                   uint32   Row ID
SkillLine            uint32   SkillLine.dbc ID
Spell                uint32   Spell ID this entry grants
RaceMask             uint32   Race restriction mask (0 = all)
ClassMask            uint32   Class restriction mask (0 = all)
MinSkillLineRank     uint32   Minimum skill value to learn
SupercededBySpell    uint32   Spell that replaces this one (the "next rank")
AcquireMethod        uint32   0=trainer, 1=quest reward, 4=discovery
TrivialSkillLineRankHigh  uint32  Upper skill value where this becomes trivial (green → gray)
TrivialSkillLineRankLow   uint32  Lower skill value where this becomes trivial
```

Use `GetSkillLineAbilitiesBySkillLine(skillLine)` for an indexed lookup by skill line. Use `GetSkillRaceClassInfo(skill, race, class_)` for race/class availability checks.

---

### AchievementEntry

```
ID              uint32         Achievement ID
requiredFaction int32          -1=all, 0=horde, 1=alliance
mapID           int32          Required map (-1=none)
name[16]        std::array<char const*, 16>  Localized title
categoryId      uint32         Achievement_Category.dbc ID
points          uint32         Achievement points
flags           uint32         Achievement flags
count           uint32         Required criteria completions
refAchievement  uint32         Referenced achievement for criteria counting
```

---

### HolidaysEntry

```
Id                  uint32         Holiday ID
Duration[10]        uint32[10]     Duration in minutes for each phase
Date[26]            uint32[26]     Start dates (Unix timestamps from 2000-01-01)
Region              uint32         WoW region
Looping             uint32         Whether this holiday repeats
CalendarFlags[10]   uint32[10]     Calendar display flags
TextureFilename     char const*    UI texture filename
Priority            uint32         Calendar ordering priority
CalendarFilterType  int32          -1=Fishing Contest, 0=unknown, 1=Darkmoon, 2=Yearly
```

---

## 5. Localized String Access Pattern

DBC localized string fields are stored as `char const*[16]` arrays — one pointer per client locale. Locale index 0 is always `enUS`.

```cpp
// Direct index — enUS
const char* name = spell->SpellName[0];

// Using the world's default DBC locale setting
const char* name = spell->SpellName[sWorld->GetDefaultDbcLocale()];

// As std::string (safe for logging, comparisons)
std::string nameStr = spell->SpellName[LOCALE_enUS]; // LOCALE_enUS = 0

// Area name example
if (AreaTableEntry const* area = sAreaTableStore.LookupEntry(areaId))
{
    const char* areaName = area->area_name[LOCALE_enUS];
}
```

Locale index constants are defined in `SharedDefines.h` as `LocaleConstant` enum values: `LOCALE_enUS=0`, `LOCALE_koKR=1`, `LOCALE_frFR=2`, `LOCALE_deDE=3`, `LOCALE_zhCN=4`, `LOCALE_zhTW=5`, `LOCALE_esES=6`, `LOCALE_esMX=7`, `LOCALE_ruRU=8`.

If a locale's string is not loaded (no locale subdirectory found), the pointer falls back to `enUS`.

---

## 6. DBCStorage Methods

From `src/server/shared/DataStores/DBCStore.h`:

```cpp
// Returns nullptr if id >= _indexTableSize or slot is null (not found)
T const* LookupEntry(uint32 id) const;

// Same as LookupEntry, but ASSERT-crashes if result is nullptr
T const* AssertEntry(uint32 id) const;

// Returns the size of the internal pointer array — NOT a count of valid rows
// Some IDs in [0, GetNumRows()) will have no entry (LookupEntry returns nullptr)
uint32 GetNumRows() const;

// Replace or insert an entry (used for DB override loading)
void SetEntry(uint32 id, T* t);

// Range-for iterator — the iterator skips null (invalid) slots automatically
iterator begin();
iterator end();

// There is no HasRecord() method — use LookupEntry(id) != nullptr
```

**Important:** `GetNumRows()` returns the allocated index array size, not a count of populated rows. Always null-check the pointer returned by `LookupEntry`.

---

## 7. DBC Files on Disk

Location: `wow335a/acore_data_files/dbc/`

All 214 `.dbc` files present (plus `component.wow-enUS.txt`):

```
Achievement.dbc                    AchievementCriteria.dbc (→ Achievement_Criteria.dbc)
Achievement_Category.dbc           AnimationData.dbc
AreaGroup.dbc                      AreaPOI.dbc
AreaTable.dbc                      AreaTrigger.dbc
AttackAnimKits.dbc                 AttackAnimTypes.dbc
AuctionHouse.dbc                   BankBagSlotPrices.dbc
BannedAddOns.dbc                   BarberShopStyle.dbc
BattlemasterList.dbc               CameraShakes.dbc
Cfg_Categories.dbc                 Cfg_Configs.dbc
CharBaseInfo.dbc                   CharHairGeosets.dbc
CharHairTextures.dbc               CharSections.dbc
CharStartOutfit.dbc                CharTitles.dbc
CharVariations.dbc                 CharacterFacialHairStyles.dbc
ChatChannels.dbc                   ChatProfanity.dbc
ChrClasses.dbc                     ChrRaces.dbc
CinematicCamera.dbc                CinematicSequences.dbc
CreatureDisplayInfo.dbc            CreatureDisplayInfoExtra.dbc
CreatureFamily.dbc                 CreatureModelData.dbc
CreatureMovementInfo.dbc           CreatureSoundData.dbc
CreatureSpellData.dbc              CreatureType.dbc
CurrencyCategory.dbc               CurrencyTypes.dbc
DanceMoves.dbc                     DeathThudLookups.dbc
DeclinedWord.dbc                   DeclinedWordCases.dbc
DestructibleModelData.dbc          DungeonEncounter.dbc
DungeonMap.dbc                     DungeonMapChunk.dbc
DurabilityCosts.dbc                DurabilityQuality.dbc
Emotes.dbc                         EmotesText.dbc
EmotesTextData.dbc                 EmotesTextSound.dbc
EnvironmentalDamage.dbc            Exhaustion.dbc
Faction.dbc                        FactionGroup.dbc
FactionTemplate.dbc                FileData.dbc
FootprintTextures.dbc              FootstepTerrainLookup.dbc
GMSurveyAnswers.dbc                GMSurveyCurrentSurvey.dbc
GMSurveyQuestions.dbc              GMSurveySurveys.dbc
GMTicketCategory.dbc               GameObjectArtKit.dbc
GameObjectDisplayInfo.dbc          GameTables.dbc
GameTips.dbc                       GemProperties.dbc
GlyphProperties.dbc                GlyphSlot.dbc
GroundEffectDoodad.dbc             GroundEffectTexture.dbc
HelmetGeosetVisData.dbc            HolidayDescriptions.dbc
HolidayNames.dbc                   Holidays.dbc
Item.dbc                           ItemBagFamily.dbc
ItemClass.dbc                      ItemCondExtCosts.dbc
ItemDisplayInfo.dbc                ItemExtendedCost.dbc
ItemGroupSounds.dbc                ItemLimitCategory.dbc
ItemPetFood.dbc                    ItemPurchaseGroup.dbc
ItemRandomProperties.dbc           ItemRandomSuffix.dbc
ItemSet.dbc                        ItemSubClass.dbc
ItemSubClassMask.dbc               ItemVisualEffects.dbc
ItemVisuals.dbc                    LFGDungeonExpansion.dbc
LFGDungeonGroup.dbc                LFGDungeons.dbc
LanguageWords.dbc                  Languages.dbc
Light.dbc                          LightFloatBand.dbc
LightIntBand.dbc                   LightParams.dbc
LightSkybox.dbc                    LiquidMaterial.dbc
LiquidType.dbc                     LoadingScreenTaxiSplines.dbc
LoadingScreens.dbc                 Lock.dbc
LockType.dbc                       MailTemplate.dbc
Map.dbc                            MapDifficulty.dbc
Material.dbc                       Movie.dbc
MovieFileData.dbc                  MovieVariation.dbc
NPCSounds.dbc                      NameGen.dbc
NamesProfanity.dbc                 NamesReserved.dbc
ObjectEffect.dbc                   ObjectEffectGroup.dbc
ObjectEffectModifier.dbc           ObjectEffectPackage.dbc
ObjectEffectPackageElem.dbc        OverrideSpellData.dbc
Package.dbc                        PageTextMaterial.dbc
PaperDollItemFrame.dbc             ParticleColor.dbc
PetPersonality.dbc                 PetitionType.dbc
PowerDisplay.dbc                   PvpDifficulty.dbc
QuestFactionReward.dbc             QuestInfo.dbc
QuestSort.dbc                      QuestXP.dbc
RandPropPoints.dbc                 Resistances.dbc
ScalingStatDistribution.dbc        ScalingStatValues.dbc
ScreenEffect.dbc                   ServerMessages.dbc
SheatheSoundLookups.dbc            SkillCostsData.dbc
SkillLine.dbc                      SkillLineAbility.dbc
SkillLineCategory.dbc              SkillRaceClassInfo.dbc
SkillTiers.dbc                     SoundAmbience.dbc
SoundEmitters.dbc                  SoundEntries.dbc
SoundEntriesAdvanced.dbc           SoundFilter.dbc
SoundFilterElem.dbc                SoundProviderPreferences.dbc
SoundSamplePreferences.dbc         SoundWaterType.dbc
SpamMessages.dbc                   Spell.dbc
SpellCastTimes.dbc                 SpellCategory.dbc
SpellChainEffects.dbc              SpellDescriptionVariables.dbc
SpellDifficulty.dbc                SpellDispelType.dbc
SpellDuration.dbc                  SpellEffectCameraShakes.dbc
SpellFocusObject.dbc               SpellIcon.dbc
SpellItemEnchantment.dbc           SpellItemEnchantmentCondition.dbc
SpellMechanic.dbc                  SpellMissile.dbc
SpellMissileMotion.dbc             SpellRadius.dbc
SpellRange.dbc                     SpellRuneCost.dbc
SpellShapeshiftForm.dbc            SpellVisual.dbc
SpellVisualEffectName.dbc          SpellVisualKit.dbc
SpellVisualKitAreaModel.dbc        SpellVisualKitModelAttach.dbc
SpellVisualPrecastTransitions.dbc  StableSlotPrices.dbc
Startup_Strings.dbc                Stationery.dbc
StringLookups.dbc                  SummonProperties.dbc
Talent.dbc                         TalentTab.dbc
TaxiNodes.dbc                      TaxiPath.dbc
TaxiPathNode.dbc                   TeamContributionPoints.dbc
TerrainType.dbc                    TerrainTypeSounds.dbc
TotemCategory.dbc                  TransportAnimation.dbc
TransportPhysics.dbc               TransportRotation.dbc
UISoundLookups.dbc                 UnitBlood.dbc
UnitBloodLevels.dbc                Vehicle.dbc
VehicleSeat.dbc                    VehicleUIIndSeat.dbc
VehicleUIIndicator.dbc             VideoHardware.dbc
VocalUISounds.dbc                  WMOAreaTable.dbc
WeaponImpactSounds.dbc             WeaponSwingSounds2.dbc
Weather.dbc                        WorldChunkSounds.dbc
WorldMapArea.dbc                   WorldMapContinent.dbc
WorldMapOverlay.dbc                WorldMapTransforms.dbc
WorldSafeLocs.dbc                  WorldStateUI.dbc
WorldStateZoneSounds.dbc           WowError_Strings.dbc
ZoneIntroMusicTable.dbc            ZoneMusic.dbc
gtBarberShopCostBase.dbc           gtChanceToMeleeCrit.dbc
gtChanceToMeleeCritBase.dbc        gtChanceToSpellCrit.dbc
gtChanceToSpellCritBase.dbc        gtCombatRatings.dbc
gtNPCManaCostScaler.dbc            gtOCTClassCombatRatingScalar.dbc
gtOCTRegenHP.dbc                   gtOCTRegenMP.dbc
gtRegenHPPerSpt.dbc                gtRegenMPPerSpt.dbc
```

**Files present on disk but with NO AC store variable** (client-only, not loaded by the server):
`AnimationData.dbc`, `AreaTrigger.dbc`, `AttackAnimKits.dbc`, `AttackAnimTypes.dbc`, `BannedAddOns.dbc`, `CameraShakes.dbc`, `Cfg_Categories.dbc`, `Cfg_Configs.dbc`, `CharBaseInfo.dbc`, `CharHairGeosets.dbc`, `CharHairTextures.dbc`, `CharSections.dbc`, `CharVariations.dbc`, `CharacterFacialHairStyles.dbc`, `ChatProfanity.dbc`, `CreatureMovementInfo.dbc`, `CreatureSoundData.dbc`, `CurrencyCategory.dbc`, `DanceMoves.dbc`, `DeathThudLookups.dbc`, `DeclinedWord.dbc`, `DeclinedWordCases.dbc`, `DungeonMap.dbc`, `DungeonMapChunk.dbc`, `EmotesTextData.dbc`, `EmotesTextSound.dbc`, `EnvironmentalDamage.dbc`, `Exhaustion.dbc`, `FactionGroup.dbc`, `FileData.dbc`, `FootprintTextures.dbc`, `FootstepTerrainLookup.dbc`, all `GM*.dbc`, `GameTables.dbc`, `GameTips.dbc`, `GroundEffect*.dbc`, `HelmetGeosetVisData.dbc`, `HolidayDescriptions.dbc`, `HolidayNames.dbc`, `ItemClass.dbc`, `ItemCondExtCosts.dbc`, `ItemGroupSounds.dbc`, `ItemPetFood.dbc`, `ItemPurchaseGroup.dbc`, `ItemSubClass.dbc`, `ItemSubClassMask.dbc`, `ItemVisualEffects.dbc`, `ItemVisuals.dbc`, `LFGDungeonExpansion.dbc`, `LFGDungeonGroup.dbc`, `LanguageWords.dbc`, `Languages.dbc`, `LightFloatBand.dbc`, `LightIntBand.dbc`, `LightParams.dbc`, `LightSkybox.dbc`, `LiquidMaterial.dbc`, `LoadingScreens.dbc`, `LoadingScreenTaxiSplines.dbc`, `LockType.dbc`, `Material.dbc`, `MovieFileData.dbc`, `MovieVariation.dbc`, `NPCSounds.dbc`, `NameGen.dbc`, `ObjectEffect*.dbc`, `Package.dbc`, `PageTextMaterial.dbc`, `PaperDollItemFrame.dbc`, `ParticleColor.dbc`, `PetPersonality.dbc`, `PetitionType.dbc`, `QuestInfo.dbc`, `Resistances.dbc`, `ScreenEffect.dbc`, `ServerMessages.dbc`, `SheatheSoundLookups.dbc`, `SkillCostsData.dbc`, `SkillLineCategory.dbc`, all `Sound*.dbc` except `SoundEntries.dbc`, `SpamMessages.dbc`, `SpellChainEffects.dbc`, `SpellDescriptionVariables.dbc`, `SpellDispelType.dbc`, `SpellEffectCameraShakes.dbc`, `SpellIcon.dbc`, `SpellMechanic.dbc`, `SpellMissile.dbc`, `SpellMissileMotion.dbc`, `SpellVisualEffectName.dbc`, `SpellVisualKit.dbc`, `SpellVisualKit*.dbc`, `SpellVisualPrecastTransitions.dbc`, `Startup_Strings.dbc`, `Stationery.dbc`, `StringLookups.dbc`, `TerrainType.dbc`, `TerrainTypeSounds.dbc`, `TransportPhysics.dbc`, all `UI*.dbc`, `UnitBlood*.dbc`, `VehicleUIInd*.dbc`, `VideoHardware.dbc`, `VocalUISounds.dbc`, `Weapon*.dbc`, `Weather.dbc`, `WorldChunkSounds.dbc`, `WorldMapArea.dbc` (struct exists but public store is commented out), `WorldMapContinent.dbc`, `WorldMapTransforms.dbc`, `WorldSafeLocs.dbc`, `WorldStateUI.dbc`, `WorldStateZoneSounds.dbc`, `WowError_Strings.dbc`, `ZoneIntroMusicTable.dbc`, `ZoneMusic.dbc`, `gtOCTRegenMP.dbc` (commented out as unused).

---

## 8. Custom DBC Modifications

AzerothCore supports two mechanisms for overriding DBC data:

### Option A: Edit the .dbc file, restart the server

AC reads the DBC file fresh on every worldserver startup. To change values:
1. Edit the `.dbc` with **WDBXEditor** (mentioned in project tooling docs).
2. Restart the worldserver — changes take effect immediately.
3. No recompilation needed for fields that are already in the struct.

**Limitation:** If you add entirely new columns to a DBC struct, you must update the format string in `DBCfmt.h` and the `DBCStructure.h` struct definition, then recompile.

### Option B: World database override tables

Each `LoadDBC(...)` call specifies an optional `dbtable` string (e.g., `"spell_dbc"`). If that table exists in the world database, AC calls `LoadFromDB` after the file load, allowing per-row overrides without touching the file. This is the recommended approach for AzerothCore modules that ship new/modified entries.

### Key DBCs to Modify

| DBC | What to modify | Notes |
|---|---|---|
| `Spell.dbc` | Custom spells, modify existing spell parameters | Struct is complex; use DB override table `spell_dbc` for partial changes |
| `Item.dbc` | Custom item display data (model, icon, inventory type) | Server stats live in `item_template` DB table — edit both |
| `Achievement.dbc` | Custom achievements | Use `achievement_dbc` DB table |
| `SpellItemEnchantment.dbc` | Custom enchants | Use `spellitemenchantment_dbc` DB table |
| `SkillLineAbility.dbc` | Add spells to skills | Affects trainer UI |
| `ChrClasses.dbc` / `ChrRaces.dbc` | Class/race display info | Client must match; requires client-side MPQ patch |

**Important:** Any DBC that affects client rendering (spell visuals, item models, character customization) must also be patched on the client side (via a custom MPQ). Server-only logic fields (costs, durations, effects) only need the server file updated.

---

## 9. Practical Examples for Module Development

### 1. Get spell name and school from spell ID

```cpp
#include "DBCStores.h"

void PrintSpellInfo(uint32 spellId)
{
    SpellEntry const* spell = sSpellStore.LookupEntry(spellId);
    if (!spell)
    {
        LOG_ERROR("module", "Spell {} not found in DBC", spellId);
        return;
    }

    const char* name = spell->SpellName[LOCALE_enUS];  // enUS
    uint32 school = spell->SchoolMask;
    // school bits: 1=physical, 2=holy, 4=fire, 8=nature, 16=frost, 32=shadow, 64=arcane

    LOG_INFO("module", "Spell {}: name='{}', schoolMask={}", spellId, name ? name : "NULL", school);
}
```

### 2. Get area/zone name from area ID

```cpp
#include "DBCStores.h"

std::string GetAreaName(uint32 areaId)
{
    AreaTableEntry const* area = sAreaTableStore.LookupEntry(areaId);
    if (!area)
        return "Unknown Area";

    const char* name = area->area_name[LOCALE_enUS];
    return name ? name : "Unknown Area";
}

// Also: get the zone (top-level area) from a sub-area
uint32 GetZoneForArea(uint32 areaId)
{
    AreaTableEntry const* area = sAreaTableStore.LookupEntry(areaId);
    if (!area)
        return 0;
    return area->zone ? area->zone : areaId; // zone == 0 means this IS the zone
}
```

### 3. Check if a map is an instance

```cpp
#include "DBCStores.h"

bool MapIsInstance(uint32 mapId)
{
    MapEntry const* map = sMapStore.LookupEntry(mapId);
    if (!map)
        return false;
    return map->IsDungeon(); // true for MAP_INSTANCE and MAP_RAID
}

bool MapIsRaid(uint32 mapId)
{
    MapEntry const* map = sMapStore.LookupEntry(mapId);
    return map && map->IsRaid();
}

// Compact check used in scripts
if (MapEntry const* map = sMapStore.LookupEntry(mapId))
{
    if (map->Instanceable())
    {
        // Instance, raid, battleground, or arena
    }
}
```

### 4. Get creature display model scale from display ID

```cpp
#include "DBCStores.h"

float GetCreatureModelScale(uint32 displayId)
{
    CreatureDisplayInfoEntry const* displayInfo = sCreatureDisplayInfoStore.LookupEntry(displayId);
    if (!displayInfo)
        return 1.0f;
    return displayInfo->scale;
}

// Also: get the model data (collision dimensions, mount height) from a display
void PrintModelInfo(uint32 displayId)
{
    CreatureDisplayInfoEntry const* display = sCreatureDisplayInfoStore.LookupEntry(displayId);
    if (!display)
        return;

    CreatureModelDataEntry const* modelData = sCreatureModelDataStore.LookupEntry(display->ModelId);
    if (!modelData)
        return;

    LOG_INFO("module", "DisplayID {}: scale={}, collisionH={}, mountH={}",
        displayId, display->scale, modelData->CollisionHeight, modelData->MountHeight);
}
```

### 5. Iterate all spells with a specific effect (find all healing spells)

```cpp
#include "DBCStores.h"
#include "SharedDefines.h"  // for SPELL_EFFECT_*, SPELL_AURA_*

// Find all spells that apply SPELL_AURA_PERIODIC_HEAL (aura 10)
void FindAllHealingSpells()
{
    for (uint32 i = 0; i < sSpellStore.GetNumRows(); ++i)
    {
        SpellEntry const* spell = sSpellStore.LookupEntry(i);
        if (!spell)
            continue;

        for (uint8 eff = 0; eff < MAX_SPELL_EFFECTS; ++eff)
        {
            if (spell->Effect[eff] == SPELL_EFFECT_APPLY_AURA &&
                spell->EffectApplyAuraName[eff] == SPELL_AURA_PERIODIC_HEAL)
            {
                const char* name = spell->SpellName[LOCALE_enUS];
                LOG_INFO("module", "HoT spell {}: {}", spell->Id, name ? name : "???");
                break;
            }
        }
    }
}

// Find all spells belonging to a specific school (e.g., frost only)
void FindFrostSpells()
{
    for (SpellEntry const& spell : sSpellStore) // range-for skips null slots
    {
        if (spell.SchoolMask == SPELL_SCHOOL_MASK_FROST) // 16
        {
            // process frost spell
        }
    }
}

// Find all spells that trigger a specific spell
void FindSpellsThatTrigger(uint32 triggeredSpellId)
{
    for (uint32 i = 0; i < sSpellStore.GetNumRows(); ++i)
    {
        SpellEntry const* spell = sSpellStore.LookupEntry(i);
        if (!spell)
            continue;

        for (uint8 eff = 0; eff < MAX_SPELL_EFFECTS; ++eff)
        {
            if (spell->EffectTriggerSpell[eff] == triggeredSpellId)
            {
                LOG_INFO("module", "Spell {} triggers spell {}", spell->Id, triggeredSpellId);
            }
        }
    }
}
```

### Bonus: Look up cast time in milliseconds from a spell

```cpp
int32 GetSpellCastTimeMs(SpellEntry const* spell)
{
    if (!spell)
        return 0;
    SpellCastTimesEntry const* castTime = sSpellCastTimesStore.LookupEntry(spell->CastingTimeIndex);
    if (!castTime)
        return 0;
    return castTime->CastTime; // in milliseconds; 0 = instant
}
```

### Bonus: Look up spell duration

```cpp
// SpellDuration has Duration[3]: [0]=base, [1]=per-level addition, [2]=maximum
// Actual duration = Duration[0] + Duration[1]*casterLevel, capped at Duration[2]
// All values in milliseconds; -1 means permanent.
int32 GetSpellBaseDurationMs(SpellEntry const* spell)
{
    SpellDurationEntry const* dur = sSpellDurationStore.LookupEntry(spell->DurationIndex);
    if (!dur)
        return 0;
    return dur->Duration[0];
}
```
