# WoW 3.3.5a File Format Reference

> Knowledge base for Dreamforge. Covers all client data formats: MPQ, DBC, ADT, BLP, M2/skin, WDB.
> Source: wowdev.wiki

---

## Client Data Architecture

```
MPQ Archives → DBC files (static game definitions) → WDB files (server-cached data)
ADT terrain + M2/WMO models + BLP textures — all packed inside MPQs
```

### MPQ Load Order (patch stacking — highest priority wins)

```
common.MPQ          ← lowest
common-2.MPQ
expansion.MPQ
lichking.MPQ
patch.MPQ
patch-2.MPQ
patch-3.MPQ
patch-4.MPQ         ← highest priority, overrides everything
```

Locale MPQs (e.g., `enUS/locale-enUS.MPQ`, `enUS/patch-enUS-3.MPQ`) follow the same stacking order within their language folder.

**Modding rule:** Place custom files in a high-numbered patch (e.g., `patch-4.MPQ` or `patch-5.MPQ`) to guarantee they win all conflicts.

---

## MPQ Archive Format

### Header (V1 = WotLK, 0x20 bytes)

```c
struct MpqHeader {
    char     magic[4];        // "MPQ\x1A"
    uint32_t headerSize;      // 0x20 for V1
    uint32_t archiveSize;     // Total file size
    uint16_t formatVersion;   // 0 = V1
    uint16_t blockSize;       // Sector size = 512 × 2^blockSize
    uint32_t hashTablePos;    // Offset to hash table
    uint32_t blockTablePos;   // Offset to block table
    uint32_t hashTableSize;   // Number of hash table entries
    uint32_t blockTableSize;  // Number of block table entries
};
```

### Hash Table (16 bytes per entry, encrypted)

- Key: derived from `"(hash table)"`
- Fields: `Name1`, `Name2` (verification), `Locale` (0=neutral), `BlockIndex`
- BlockIndex `0xFFFFFFFF` = unused; `0xFFFFFFFE` = deleted
- Lookup uses linear probing: `start = hash(name, TABLE_OFFSET) & (table_size-1)`

### Block Table (16 bytes per entry, encrypted)

- Key: derived from `"(block table)"`
- Fields: `FilePosition`, `CompressedSize`, `UncompressedSize`, `Flags`

**Key flags:**

| Flag | Value | Meaning |
|------|-------|---------|
| `MPQ_FILE_IMPLODE` | 0x100 | PKware DCL compression |
| `MPQ_FILE_COMPRESS` | 0x200 | Multi-algorithm compression |
| `MPQ_FILE_ENCRYPTED` | 0x10000 | File is encrypted |
| `MPQ_FILE_FIX_KEY` | 0x20000 | Encryption key adjusted by position |
| `MPQ_FILE_SINGLE_UNIT` | 0x1000000 | No sector fragmentation |
| `MPQ_FILE_PATCH_FILE` | 0x100000 | PTCH binary patch |
| `MPQ_FILE_EXISTS` | 0x80000000 | Valid entry |

### Compression Methods (first byte of compressed sector)

| Byte | Method |
|------|--------|
| 0x02 | zlib/deflate (most files) |
| 0x10 | BZip2 |
| 0x01 | Huffman (audio) |
| 0x40 | ADPCM mono |
| 0x80 | ADPCM stereo |
| 0x04 | PKware Implode |
| 0x20 | Sparse/RLE |

### Special Internal Files

| File | Purpose |
|------|---------|
| `(listfile)` | Newline-separated filename list |
| `(attributes)` | CRC32/FILETIME/MD5 per file |
| `(signature)` | RSA digital signature |

### Tools

| Tool | Use |
|------|-----|
| **Ladik's MPQ Editor** | GUI — browse, extract, add, rebuild MPQs |
| **StormLib** | C/C++ library for programmatic MPQ access |
| **WinMPQ** | Older alternative GUI |

---

## DBC File Format

### Binary Header (20 bytes, magic = `"WDBC"`)

```c
struct DbcHeader {
    char     magic[4];           // "WDBC"
    uint32_t record_count;       // Number of rows
    uint32_t field_count;        // Number of columns
    uint32_t record_size;        // Bytes per row (= field_count × 4 typically)
    uint32_t string_block_size;  // Size of trailing string data
};
```

### File Layout

```
[20-byte header]
[records: record_count × record_size bytes]
[string_block: string_block_size bytes — null-terminated C strings]
```

### Field Types (all 4 bytes wide)

| Type | Notes |
|------|-------|
| `uint32_t` | Unsigned int |
| `int32_t` | Signed int |
| `float` | IEEE 754 |
| `stringref` | `uint32` offset into string_block — dereference as `&string_block[offset]` |

### Localized String Fields (WotLK, pre-Cataclysm)

Each localized field = **16 stringrefs + 1 bitmask** = 17 × 4 = **68 bytes**.

Locale order: enUS, koKR, frFR, deDE, enCN, enTW, esES, esMX, ruRU, jaJP, ptPT, itIT, + 4 unknown.

### Reading a DBC

```python
# Pseudocode
header = read(20)  # magic, records, fields, record_size, string_size
records = read(header.record_count * header.record_size)
strings = read(header.string_block_size)
# Access string: strings[record.field_offset:]  until \0
```

### Tools

| Tool | Use |
|------|-----|
| **WDBXEditor** | Modern GUI for DBC/DB2 editing (recommended) |
| **DBCExplorer** | Classic WotLK-era viewer |
| **MyDBCEditor** | Older WotLK tool |

### WotLK DBC Files — Complete List (244 files)

**Key DBCs for server modding:**

| DBC | Purpose |
|-----|---------|
| `Spell.dbc` | All spell definitions |
| `SpellEffect.dbc` | Spell effects |
| `SpellDuration.dbc` | Duration IDs |
| `SpellCastTimes.dbc` | Cast time IDs |
| `SpellRadius.dbc` | Area radius IDs |
| `SpellRange.dbc` | Range IDs |
| `SpellIcon.dbc` | Spell icons |
| `Item.dbc` | Item class/subclass/display linkage |
| `ItemDisplayInfo.dbc` | Item visual model |
| `ItemSet.dbc` | Set bonuses |
| `ItemExtendedCost.dbc` | Honor/arena point costs |
| `AreaTable.dbc` | Zone/area IDs, names, music |
| `Map.dbc` | Map IDs, names, type (instance/BG/world) |
| `MapDifficulty.dbc` | Heroic/raid difficulty settings |
| `DungeonEncounter.dbc` | Boss encounter IDs |
| `Faction.dbc` | Faction definitions |
| `FactionTemplate.dbc` | Creature faction templates |
| `ChrRaces.dbc` | Race definitions |
| `ChrClasses.dbc` | Class definitions |
| `Talent.dbc` | Talent tree data |
| `TalentTab.dbc` | Talent spec tabs |
| `SkillLine.dbc` | Skill IDs and names |
| `SkillLineAbility.dbc` | Skill-to-spell mappings |
| `TaxiNodes.dbc` | Flight path nodes |
| `TaxiPath.dbc` | Flight paths |
| `TaxiPathNode.dbc` | Waypoints along paths |
| `CreatureFamily.dbc` | Pet/creature families |
| `CreatureDisplayInfo.dbc` | Creature model/scale |
| `CreatureModelData.dbc` | Creature model file paths |
| `Holidays.dbc` | Seasonal event definitions |
| `LFGDungeons.dbc` | Dungeon finder dungeon list |
| `WorldMapArea.dbc` | World map region definitions |
| `LoadingScreens.dbc` | Zone loading screen images |
| `SoundEntries.dbc` | Sound file entries |
| `LiquidType.dbc` | Water/lava/slime types |
| `Vehicle.dbc` | Vehicle definitions |
| `VehicleSeat.dbc` | Seat configurations |
| `GemProperties.dbc` | Socket gem enchant links |
| `SpellItemEnchantment.dbc` | Enchant definitions |
| `CharTitles.dbc` | Player title names |
| `Achievement.dbc` | Achievement definitions |
| `AchievementCriteria.dbc` | Achievement criteria |
| `QuestSort.dbc` | Quest category names |
| `QuestInfo.dbc` | Quest type names |
| `BattlemasterList.dbc` | Battleground definitions |
| `PvpDifficulty.dbc` | BG bracket ranges |

Full 244-file alphabetical list: Achievement, AchievementCategory, AchievementCriteria, AnimationData, AreaGroup, AreaPOI, AreaTable, AreaTrigger, AttackAnimKits, AttackAnimTypes, AuctionHouse, BankBagSlotPrices, BannedAddOns, BarberShopStyle, BattlemasterList, CameraShakes, CfgCategories, CfgConfigs, CharacterFacialHairStyles, CharBaseInfo, CharHairGeosets, CharHairTextures, CharSections, CharStartOutfit, CharTitles, CharVariations, ChatChannels, ChatProfanity, ChrClasses, ChrRaces, CinematicCamera, CinematicSequences, CreatureDisplayInfo, CreatureDisplayInfoExtra, CreatureFamily, CreatureModelData, CreatureMovementInfo, CreatureSoundData, CreatureSpellData, CreatureType, CurrencyCategory, CurrencyTypes, DanceMoves, DestructibleModelData, DungeonEncounter, DungeonMap, DungeonMapChunk, EmotesText, EmotesTextData, EmotesTextSound, EnvironmentalDamage, Exhaustion, Faction, FactionGroup, FactionTemplate, FileData, FootprintTextures, FootstepTerrainLookup, GameObjectArtKit, GameObjectDisplayInfo, GameTips, GemProperties, GlyphProperties, GlyphSlot, GMSurveyAnswers, GMSurveySurveys, GroundEffectDoodad, GroundEffectTexture, GtBarberShopCostBase, GtChanceToMeleeCrit, GtCombatRatings, GtOCTClassCombatRatingScalar, GtRegenHPPerSpt, GtRegenMPPerSpt, HelmetGeosetVisData, HolidayDescriptions, HolidayNames, Holidays, Item, ItemBagFamily, ItemClass, ItemDisplayInfo, ItemExtendedCost, ItemLimitCategory, ItemRandomProperties, ItemRandomSuffix, ItemSet, ItemSubClass, ItemVisuals, LFGDungeons, LFGDungeonExpansion, LFGDungeonGroup, Light, LightFloatBand, LightIntBand, LightParams, LightSkybox, LiquidMaterial, LiquidType, LoadingScreens, Lock, LockType, MailTemplate, Map, MapDifficulty, Material, Movie, NameGen, NPCSounds, ObjectEffect, ObjectEffectGroup, ObjectEffectPackage, OverrideSpellData, PageTextMaterial, PaperDollItemFrame, ParticleColor, PowerDisplay, PvpDifficulty, QuestFactionReward, QuestInfo, QuestPOI, QuestSort, QuestXP, RandPropPoints, ScalingStatDistribution, ScalingStatValues, ScreenEffect, ServerMessages, SkillCostsData, SkillLine, SkillLineAbility, SkillLineCategory, SkillRaceClassInfo, SkillTiers, SoundAmbience, SoundEmitters, SoundEntries, SoundEntriesAdvanced, Spell, SpellAuraOptions, SpellAuraRestrictions, SpellCastingRequirements, SpellCastTimes, SpellCategory, SpellClassOptions, SpellCooldowns, SpellDescriptionVariables, SpellDifficulty, SpellDispelType, SpellDuration, SpellEffect, SpellEquippedItems, SpellFocusObject, SpellIcon, SpellInterrupts, SpellItemEnchantment, SpellItemEnchantmentCondition, SpellLevels, SpellMechanic, SpellMissile, SpellPower, SpellRadius, SpellRange, SpellRuneCost, SpellShapeshift, SpellShapeshiftForm, SpellTargetRestrictions, SpellTotems, SpellVisual, SpellVisualEffectName, SpellVisualKit, StableSlotPrices, SummonProperties, Talent, TalentTab, TaxiNodes, TaxiPath, TaxiPathNode, TerrainTypeSounds, TotemCategory, TransportAnimation, UISoundLookups, UnitBlood, Vehicle, VehicleSeat, VehicleUIIndicator, VideoHardware, WeaponImpactSounds, WeaponSwingSounds2, WeatherTable, WMOAreaTable, WorldChunkSounds, WorldMapArea, WorldMapContinent, WorldMapOverlay, WorldSafeLocs, WorldStateUI, ZoneIntroMusicTable, ZoneMusic

---

## ADT Terrain Format

### World Grid

- World = **64×64 tile grid** (most unused)
- Each tile = **533.33 yards** square
- Each tile divided into **16×16 chunks** (MCNK) = 256 per ADT
- Each chunk = **33.33 yards** square
- File path: `World/Maps/<MapName>/<MapName>_<X>_<Y>.adt`
- Coordinates: +X = North, +Y = West, Z = up; origin at map center

### Key Chunks

| Chunk | Purpose |
|-------|---------|
| `MVER` | Version (uint32) |
| `MHDR` | Offsets to all sub-chunks |
| `MCIN` | 256-entry index of MCNK offsets |
| `MTEX` | Null-separated texture filename list |
| `MMDX` | M2 model filename list |
| `MMID` | Offsets into MMDX |
| `MWMO` | WMO filename list |
| `MWID` | Offsets into MWMO |
| `MDDF` | Doodad (M2) placement records |
| `MODF` | WMO placement records |
| `MH2O` | Liquid data (WotLK replacement for MCLQ) |

### MCNK (per-chunk terrain data)

Each of the 256 MCNK chunks contains:

| Sub-chunk | Purpose |
|-----------|---------|
| `MCVT` | 145 height floats (9×9 outer + 8×8 inner vertices) |
| `MCNR` | 145 normal vectors |
| `MCLY` | Texture layer definitions (up to 4) |
| `MCAL` | Alpha blend maps for texture layers |
| `MCSH` | Shadow map (64-byte bitmask) |
| `MCCV` | Vertex color shading (WotLK+) |
| `MCRF` | Doodad/WMO reference indices |

### MCLY (texture layer, 16 bytes)

| Field | Description |
|-------|-------------|
| `textureId` | Index into MTEX filename list |
| `flags` | Animation rotation/speed, alpha compress, etc. |
| `offsetInMCAL` | Byte offset into MCAL block |
| `effectId` | GroundEffectTexture.dbc row |

### MDDF (M2 placement, per-model)

```c
struct SMDoodadDef {
    uint32_t nameId;    // Index → MMID → MMDX filename
    uint32_t uniqueId;
    C3Vector position;  // worldX = 32*533.333 - mddf.pos.x
    C3Vector rotation;  // Degrees
    uint16_t scale;     // 1024 = 1.0
    uint16_t flags;
};
```

### Tools

| Tool | Purpose |
|------|---------|
| **Noggit** | Open-source WoW ADT editor (terrain, textures, object placement) |
| **Noggit Red** | Newer fork with better tooling |
| **WoW Model Viewer** | View M2/ADT/WMO in-game assets |

---

## BLP Texture Format (BLP2 — WotLK)

### Header (1172 bytes total)

| Offset | Field | Notes |
|--------|-------|-------|
| 0x00 | `magic[4]` | `"BLP2"` |
| 0x04 | `version` | Always 1 |
| 0x08 | `colorEncoding` | 0=JPEG, 1=Palettized, 2=DXT, 3=BGRA |
| 0x09 | `alphaBitDepth` | 0, 1, 4, or 8 |
| 0x0A | `alphaType` | Selects DXT variant |
| 0x0B | `hasMipmaps` | 0=single, 1=multiple |
| 0x0C | `width` | |
| 0x10 | `height` | |
| 0x14 | `mipOffsets[16]` | Byte offsets to each mip level |
| 0x54 | `mipSizes[16]` | Byte sizes per mip level |
| 0x94 | `palette[256]` | BGRX (palettized) or JPEG header |

### DXT Variants (most WotLK textures)

| alphaType | Format | Block size | Alpha |
|-----------|--------|------------|-------|
| 0 | DXT1 (BC1) | 8 bytes/4×4 | 1-bit |
| 1 | DXT3 (BC2) | 16 bytes/4×4 | 4-bit explicit |
| 7 | DXT5 (BC3) | 16 bytes/4×4 | 8-bit interpolated |

Size formula: `ceil(W/4) × ceil(H/4) × bytes_per_block`

### Alpha Bit Depth

| Depth | Encoding |
|-------|----------|
| 0 | Fully opaque — no alpha stored |
| 1 | 8 pixels/byte, LSB-first |
| 4 | 2 pixels/byte (common for UI) |
| 8 | 1 byte/pixel |

### Tools

| Tool | Use |
|------|-----|
| **BLPConverter** | BLP ↔ PNG/DDS command-line conversion |
| **WC3 Image Extractor** | Classic BLP tool |
| **Photoshop BLP Plugin** | Edit BLP directly in Photoshop |

---

## M2 Model Format (WotLK version 264)

### File Set

| Extension | Purpose |
|-----------|---------|
| `.m2` | Main model: skeleton, bones, textures, animations, particles |
| `.skin` | LOD mesh: vertices, triangles, submeshes (4 files: `00–03.skin`) |
| `.anim` | External animation data (when sequence flag has bit clear for inline) |

### Version

- Magic: `MD20` (inline, WotLK)
- **Version 264 = Wrath of the Lich King** (3.3.5a, build 12340)

### Key Header Arrays

| Array | Content |
|-------|---------|
| `sequences` | Animation sequences (loop, duration, blend times) |
| `bones` | Bone hierarchy with translation/rotation/scale tracks |
| `vertices` | Geometry (position, normals, UV×2, bone weights×4) |
| `textures` | Texture type + filename |
| `materials` | Render flags + blending |
| `colors` | RGB animation tracks |
| `texture_weights` | Transparency (alpha) tracks |
| `particles` | Particle emitter definitions |
| `ribbons` | Ribbon/trail emitter definitions |

### Vertex Format

```c
struct M2Vertex {
    float    pos[3];           // XYZ (Z-up; client converts to Y-up)
    uint8_t  bone_weights[4];  // Sum = 255
    uint8_t  bone_indices[4];  // References into bone lookup
    float    normal[3];
    float    tex_coords[2][2]; // Two UV sets
};
```

### Bone Compression (WotLK)

Rotations stored as `M2CompQuat` — 4× uint16 (identity = `32767, 32767, 32767, 65535`):
```
x = (val - 32767) / 32767.0
w = val / 65535.0
```

### Animation Track (M2Track)

```c
struct M2Track<T> {
    uint16_t interpolation; // 0=instant, 1=linear, 2=bezier, 3=hermite
    int16_t  global_sequence; // -1=per-animation; ≥0=loops globally
    M2Array<M2Array<uint32_t>> timestamps; // Per-sequence keyframe times
    M2Array<M2Array<T>>        values;     // Per-sequence values
};
```

---

## WDB Client Cache Files

Located in `Cache/WDB/<locale>/` — NOT inside MPQs.

| File | Content |
|------|---------|
| `creaturecache.wdb` | Creature name/type data |
| `gameobjectcache.wdb` | GO display data |
| `itemcache.wdb` | Item display/stats data |
| `questcache.wdb` | Quest text/objectives |
| `npccache.wdb` | NPC name data |

WDB records are server-provided and cached locally; automatically invalidated on patch. Not used for server modding but explains why some data appears client-side only.

---

## Modding Workflow Summary

```
1. Extract files from MPQ → Ladik's MPQ Editor / StormLib
2. Edit DBC files         → WDBXEditor (open, modify rows, save)
3. Edit ADT terrain       → Noggit / Noggit Red
4. Edit textures          → BLPConverter → Photoshop → BLPConverter back
5. Edit models            → Blender with M2 import plugin / WoW Model Viewer
6. Pack into custom MPQ   → Ladik's MPQ Editor
7. Name it patch-5.MPQ    → Placed in Data/ folder, wins all conflicts
8. Distribute to players  → Drop in their Data/ folder
```

*Last updated: 2026-03-17*
