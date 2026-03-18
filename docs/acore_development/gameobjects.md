# GameObject System

Complete reference for the AzerothCore (WotLK 3.3.5a) GameObject system: database schema, type definitions, C++ scripting API, and lifecycle management.

---

## Table of Contents

1. [gameobject_template Table](#gameobject_template-table)
2. [GAMEOBJECT_TYPE Enum](#gameobject_type-enum)
3. [data0–data23 Field Mappings Per Type](#data0data23-field-mappings-per-type)
   - [Type 0: DOOR](#type-0-door)
   - [Type 1: BUTTON](#type-1-button)
   - [Type 2: QUESTGIVER](#type-2-questgiver)
   - [Type 3: CHEST](#type-3-chest)
   - [Type 4: BINDER](#type-4-binder)
   - [Type 5: GENERIC](#type-5-generic)
   - [Type 6: TRAP](#type-6-trap)
   - [Type 7: CHAIR](#type-7-chair)
   - [Type 8: SPELL_FOCUS](#type-8-spell_focus)
   - [Type 9: TEXT](#type-9-text)
   - [Type 10: GOOBER](#type-10-goober)
   - [Type 11: TRANSPORT](#type-11-transport)
   - [Type 12: AREADAMAGE](#type-12-areadamage)
   - [Type 13: CAMERA](#type-13-camera)
   - [Type 14: MAP_OBJECT](#type-14-map_object)
   - [Type 15: MO_TRANSPORT](#type-15-mo_transport)
   - [Type 16: DUEL_ARBITER](#type-16-duel_arbiter)
   - [Type 17: FISHINGNODE](#type-17-fishingnode)
   - [Type 18: RITUAL](#type-18-ritual)
   - [Type 19: MAILBOX](#type-19-mailbox)
   - [Type 20: AUCTIONHOUSE](#type-20-auctionhouse)
   - [Type 21: GUARDPOST](#type-21-guardpost)
   - [Type 22: SPELLCASTER](#type-22-spellcaster)
   - [Type 23: MEETINGSTONE](#type-23-meetingstone)
   - [Type 24: FLAGSTAND](#type-24-flagstand)
   - [Type 25: FISHINGHOLE](#type-25-fishinghole)
   - [Type 26: FLAGDROP](#type-26-flagdrop)
   - [Type 27: MINI_GAME / CUSTOM_TELEPORT](#type-27-mini_game--custom_teleport)
   - [Type 28: LOTTERY_KIOSK](#type-28-lottery_kiosk)
   - [Type 29: CAPTURE_POINT](#type-29-capture_point)
   - [Type 30: AURA_GENERATOR](#type-30-aura_generator)
   - [Type 31: DUNGEON_DIFFICULTY](#type-31-dungeon_difficulty)
   - [Type 32: BARBER_CHAIR](#type-32-barber_chair)
   - [Type 33: DESTRUCTIBLE_BUILDING](#type-33-destructible_building)
   - [Type 34: GUILD_BANK](#type-34-guild_bank)
   - [Type 35: TRAPDOOR](#type-35-trapdoor)
4. [GOState and LootState Enums](#gostate-and-lootstate-enums)
5. [GameObjectScript C++ API](#gameobjectscript-c-api)
6. [GameObject Lifecycle in C++](#gameobject-lifecycle-in-c)
7. [gameobject Table (Spawned Instances)](#gameobject-table-spawned-instances)
8. [Cross-References](#cross-references)

---

## gameobject_template Table

Every spawned GameObject references a row here via `id → entry`. This table defines the type, model, and all type-specific parameters.

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `entry` | MEDIUMINT UNSIGNED | PRI/0 | Unique template ID. Referenced by `gameobject.id` and elsewhere. |
| `type` | TINYINT UNSIGNED | 0 | Object category. See [GAMEOBJECT_TYPE Enum](#gameobject_type-enum). |
| `displayId` | MEDIUMINT UNSIGNED | 0 | Visual model ID sent to the client (`GameObjectDisplayInfo.dbc`). |
| `name` | VARCHAR(100) | '' | Display name shown in the client UI. |
| `IconName` | VARCHAR(100) | '' | Cursor icon hint: `Taxi`, `Talk`, `Attack`, `Directions`, `Quest`. |
| `castBarCaption` | VARCHAR(100) | '' | Text shown in the object's interaction cast bar (e.g., "Opening…"). |
| `unk1` | VARCHAR(100) | '' | Unknown. Usually empty. |
| `size` | FLOAT | 1.0 | Scale multiplier applied to the display model. 1.0 = normal size. |
| `data0` | INT UNSIGNED | 0 | Type-specific parameter. See per-type tables below. |
| `data1` | INT UNSIGNED | 0 | Type-specific parameter. |
| `data2` | INT UNSIGNED | 0 | Type-specific parameter. |
| `data3` | INT UNSIGNED | 0 | Type-specific parameter. |
| `data4` | INT UNSIGNED | 0 | Type-specific parameter. |
| `data5` | INT UNSIGNED | 0 | Type-specific parameter. |
| `data6` | INT UNSIGNED | 0 | Type-specific parameter. |
| `data7` | INT UNSIGNED | 0 | Type-specific parameter. |
| `data8` | INT UNSIGNED | 0 | Type-specific parameter. |
| `data9` | INT UNSIGNED | 0 | Type-specific parameter. |
| `data10` | INT UNSIGNED | 0 | Type-specific parameter. |
| `data11` | INT UNSIGNED | 0 | Type-specific parameter. |
| `data12` | INT UNSIGNED | 0 | Type-specific parameter. |
| `data13` | INT UNSIGNED | 0 | Type-specific parameter. |
| `data14` | INT UNSIGNED | 0 | Type-specific parameter. |
| `data15` | INT UNSIGNED | 0 | Type-specific parameter. |
| `data16` | INT UNSIGNED | 0 | Type-specific parameter. |
| `data17` | INT UNSIGNED | 0 | Type-specific parameter. |
| `data18` | INT UNSIGNED | 0 | Type-specific parameter. |
| `data19` | INT UNSIGNED | 0 | Type-specific parameter. |
| `data20` | INT UNSIGNED | 0 | Type-specific parameter. |
| `data21` | INT UNSIGNED | 0 | Type-specific parameter. |
| `data22` | INT UNSIGNED | 0 | Type-specific parameter. |
| `data23` | INT UNSIGNED | 0 | Type-specific parameter. |
| `AIName` | char(64) | '' | Built-in AI class. Only valid value is `SmartGameObjectAI`. Overridden by `ScriptName`. |
| `ScriptName` | VARCHAR(64) | '' | C++ `GameObjectScript` name registered with `RegisterGameObjectScript`. Takes precedence over `AIName`. |
| `WDBVerified` | SMALLINT SIGNED | 1 | Database verification status. Negative = placeholder, 0 = unverified, positive = verified build number. |

**Notes:**
- `data0`–`data23` fields are defined as `INT UNSIGNED` but some types write them as signed or treat them as spell/lock IDs. Always consult the per-type mapping.
- `AIName = "SmartGameObjectAI"` enables SmartAI scripting from `smart_scripts` without requiring a C++ script. `ScriptName` always wins if both are set.
- The `displayId` must reference a valid `GameObjectDisplayInfo.dbc` entry or the object will be invisible.

---

## GAMEOBJECT_TYPE Enum

The `type` field maps to the following enum values. The numeric ID is sent to the client and used by the core to determine which `data0`–`data23` fields are meaningful.

| ID | Name | Description |
|----|------|-------------|
| 0 | `GAMEOBJECT_TYPE_DOOR` | Door or gate that opens/closes. |
| 1 | `GAMEOBJECT_TYPE_BUTTON` | Clickable button, often linked to a trap or door. |
| 2 | `GAMEOBJECT_TYPE_QUESTGIVER` | Quest NPC replacement — GO that offers quests. |
| 3 | `GAMEOBJECT_TYPE_CHEST` | Lootable container (chest, crate, pile of bones, etc.). |
| 4 | `GAMEOBJECT_TYPE_BINDER` | Hearthstone binder. Not used in retail WotLK data. |
| 5 | `GAMEOBJECT_TYPE_GENERIC` | Generic decorative/interactive object with no specialized logic. |
| 6 | `GAMEOBJECT_TYPE_TRAP` | Invisible or visible trap that casts a spell. |
| 7 | `GAMEOBJECT_TYPE_CHAIR` | Sittable chair. |
| 8 | `GAMEOBJECT_TYPE_SPELL_FOCUS` | Invisible focus point that enables certain spells to be cast. |
| 9 | `GAMEOBJECT_TYPE_TEXT` | Displays a book/page text when used. |
| 10 | `GAMEOBJECT_TYPE_GOOBER` | Catch-all interactive object: casts spells, triggers events, shows pages. |
| 11 | `GAMEOBJECT_TYPE_TRANSPORT` | Static elevator/lift transport (moves between floors within one map). |
| 12 | `GAMEOBJECT_TYPE_AREADAMAGE` | Area-of-effect damage zone. |
| 13 | `GAMEOBJECT_TYPE_CAMERA` | Triggers a cinematic sequence. |
| 14 | `GAMEOBJECT_TYPE_MAP_OBJECT` | Map decoration / static world object, no interaction. |
| 15 | `GAMEOBJECT_TYPE_MO_TRANSPORT` | Moving transport (boat, zeppelin) that crosses maps. |
| 16 | `GAMEOBJECT_TYPE_DUEL_ARBITER` | Duel flag. Exactly one instance in the world. |
| 17 | `GAMEOBJECT_TYPE_FISHINGNODE` | Fishing bobber. Exactly one template. |
| 18 | `GAMEOBJECT_TYPE_RITUAL` | Ritual summoning stone (warlock summoning). |
| 19 | `GAMEOBJECT_TYPE_MAILBOX` | Mailbox. No type-specific data needed. |
| 20 | `GAMEOBJECT_TYPE_AUCTIONHOUSE` | Auction House terminal. |
| 21 | `GAMEOBJECT_TYPE_GUARDPOST` | Guard post that spawns a creature. |
| 22 | `GAMEOBJECT_TYPE_SPELLCASTER` | Casts a spell on use (limited charges). |
| 23 | `GAMEOBJECT_TYPE_MEETINGSTONE` | Meeting/summoning stone (LFG system). |
| 24 | `GAMEOBJECT_TYPE_FLAGSTAND` | Capture-the-flag flag stand (WSG, EOTS). |
| 25 | `GAMEOBJECT_TYPE_FISHINGHOLE` | Fishing hole in open water. |
| 26 | `GAMEOBJECT_TYPE_FLAGDROP` | Dropped flag object (CTF). |
| 27 | `GAMEOBJECT_TYPE_MINI_GAME` | Re-used by AzerothCore as `CUSTOM_TELEPORT`. |
| 28 | `GAMEOBJECT_TYPE_LOTTERY_KIOSK` | Not used. |
| 29 | `GAMEOBJECT_TYPE_CAPTURE_POINT` | World PvP capture point (Halaa, Towers of Zangarmarsh). |
| 30 | `GAMEOBJECT_TYPE_AURA_GENERATOR` | Continuously applies an aura to nearby players. |
| 31 | `GAMEOBJECT_TYPE_DUNGEON_DIFFICULTY` | Portal / difficulty selector for instances. |
| 32 | `GAMEOBJECT_TYPE_BARBER_CHAIR` | Barber chair. |
| 33 | `GAMEOBJECT_TYPE_DESTRUCTIBLE_BUILDING` | Destructible building (Wintergrasp siege). |
| 34 | `GAMEOBJECT_TYPE_GUILD_BANK` | Guild bank terminal. No type data needed. |
| 35 | `GAMEOBJECT_TYPE_TRAPDOOR` | Trapdoor that can be opened/closed vertically. |

---

## data0–data23 Field Mappings Per Type

Each type interprets `data0`–`data23` differently. Fields not listed for a type are unused (should remain 0).

### Type 0: DOOR

Doors open/close via lock interaction or server trigger. `autoClose` resets them automatically.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `startOpen` | Boolean. 1 = door starts in open state. |
| data1 | `lockId` | `Lock.dbc` entry ID. 0 = no lock (always usable). |
| data2 | `autoClose` | Time in milliseconds before door auto-closes after opening. 0 = never. |
| data3 | `noDamageImmune` | Boolean. 1 = door can be damaged/destroyed. |
| data4 | `openTextId` | Broadcast text ID shown when opened. |
| data5 | `closeTextId` | Broadcast text ID shown when closed. |
| data6 | — | Ignored by pathfinding (internal flag). |
| data7 | `conditionId1` | Condition ID from `conditions` table. Must be true to interact. |
| data8 | `isOpaque` | Boolean. 1 = door blocks line of sight. |
| data9 | `giganticAOI` | Boolean. 1 = gigantic area-of-interest radius. |
| data10 | `infiniteAOI` | Boolean. 1 = infinite AOI (always visible). |

### Type 1: BUTTON

Buttons are single-click activators, often linked to trap GOs.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `startOpen` | Boolean. State the button begins in. |
| data1 | `lockId` | `Lock.dbc` entry ID. |
| data2 | `autoClose` | Milliseconds before button resets. |
| data3 | `linkedTrap` | `gameobject_template.entry` of a TRAP GO activated when button is pressed. |
| data4 | `noDamageImmune` | Boolean. |
| data5 | `large` | Boolean. Enlarged interaction radius. |
| data6 | `openTextId` | Broadcast text on activation. |
| data7 | `closeTextId` | Broadcast text on reset. |
| data8 | `losOK` | Boolean. 1 = player can interact without direct line-of-sight. |
| data9 | `conditionId1` | Condition ID. |

### Type 2: QUESTGIVER

A GO that behaves like a quest NPC.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `lockId` | `Lock.dbc` entry ID. |
| data1 | `questList` | Unknown quest list ID. |
| data2 | `pageMaterial` | `PageTextMaterial.dbc` ID for any page display. |
| data3 | `gossipId` | `gossip_menu_option.menu_id` for gossip interaction. |
| data4 | `customAnim` | Custom animation ID (1–4). |
| data5 | `noDamageImmune` | Boolean. |
| data6 | `openTextId` | `broadcast_text` ID displayed on interact. |
| data7 | `losOK` | Boolean. |
| data8 | `allowMounted` | Boolean. 1 = player can interact while mounted. |
| data9 | `large` | Boolean. |
| data10 | `conditionId1` | Condition ID. |
| data11 | `neverUsableWhileMounted` | Boolean. Overrides `allowMounted` if set. |

### Type 3: CHEST

Lootable containers. The most commonly customized GO type.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `lockId` | `Lock.dbc` entry ID. Required for locked chests. |
| data1 | `chestLoot` | `gameobject_loot_template.entry` — the loot table. |
| data2 | `chestRestockTime` | Seconds before the chest respawns (independent of `spawntimesecs` in the spawn row). |
| data3 | `consumable` | Boolean. 1 = chest despawns after looting (does not restock). |
| data4 | `minRestock` | Minimum number of successful loot attempts before depletion. |
| data5 | `maxRestock` | Maximum successful loot attempts. |
| data6 | `lootedEvent` | `event_scripts` ID fired when chest is looted. |
| data7 | `linkedTrap` | `gameobject_template.entry` of a TRAP activated on open. |
| data8 | `questId` | `quest_template.ID` — chest only accessible if player has this quest active. |
| data9 | `level` | Minimum player level required to loot. |
| data10 | `losOK` | Boolean. |
| data11 | `leaveLoot` | Boolean. 1 = loot remains in window after first pick. |
| data12 | `notInCombat` | Boolean. 1 = cannot be opened while in combat. |
| data13 | `logLoot` | Boolean. Server-side loot logging. |
| data14 | `openTextId` | Broadcast text on open. |
| data15 | `useGroupLootRules` | Boolean. 1 = use group loot distribution rules. |
| data16 | `floatingTooltip` | Boolean. Show floating tooltip in world. |
| data17 | `conditionId1` | Condition ID. |
| data18 | `xpLevel` | XP level reward. |
| data19 | `xpDifficulty` | XP difficulty multiplier. |
| data20 | `lootLevel` | Loot level override. |
| data21 | `groupXp` | Boolean. 1 = distribute XP to group. |
| data22 | `damageImmune` | Boolean. |
| data23 | `trivialSkillLow` | Low skill threshold for trivial skill-up. |

### Type 4: BINDER

Not used in WotLK. All data fields are 0.

### Type 5: GENERIC

Decoration or simple quest-interact objects.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `floatingTooltip` | Boolean. Show floating tooltip. |
| data1 | `highlight` | Boolean. Highlight on hover. |
| data2 | `serverOnly` | Always 0. |
| data3 | `large` | Boolean. Large interaction radius. |
| data4 | `floatOnWater` | Boolean. Object floats on water surface. |
| data5 | `questId` | `quest_template.ID` — required active quest to interact. |
| data6 | `conditionId1` | Condition ID. |
| data7 | `largeAOI` | Boolean. Large area of interest. |
| data8 | `useGarrisonOwnerGuildColors` | Boolean (unused in WotLK context). |

### Type 6: TRAP

Invisible or disguised objects that fire a spell when triggered.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `lockId` | `Lock.dbc` entry ID. |
| data1 | `level` | NPC-equivalent level used for spell scaling. |
| data2 | `diameter` | Trigger radius × 2 (i.e., full diameter in yards). |
| data3 | `spellId` | Spell fired when trap is triggered. |
| data4 | `charges` | 0 = no despawn; 1 = despawn after cast; 2 = bomb (area). |
| data5 | `cooldown` | Seconds between activations. |
| data6 | — | Unknown flag. |
| data7 | `startDelay` | Seconds before trap becomes active after spawn. |
| data8 | `serverOnly` | Always 0. |
| data9 | `stealthed` | Boolean. 1 = trap is stealthed/invisible to players. |
| data10 | `large` | Boolean. Large detection radius. |
| data11 | `stealthAffected` | Boolean. Stealth detection affects trigger radius. |
| data12 | `openTextId` | Broadcast text on trigger. |
| data13 | `closeTextId` | Broadcast text on reset. |
| data14 | `ignoreTotems` | Boolean. 1 = does not trigger on totems. |
| data15 | `conditionId1` | Condition ID. |
| data16 | `playerCast` | Boolean. Cast is attributed to the triggering player. |
| data17 | `summonerTriggered` | Boolean. Only triggered by the summoner. |
| data18 | `requireLOS` | Boolean. Requires line of sight to target. |

### Type 7: CHAIR

Sittable furniture.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `chairSlots` | Number of simultaneous players that can sit. |
| data1 | `height` | Seat height offset. |
| data2 | `onlyCreatorUse` | Boolean. Only the placing player can use. |
| data3 | `triggeredEvent` | Event script ID triggered on use. |
| data4 | `conditionId1` | Condition ID. |

### Type 8: SPELL_FOCUS

Invisible GO that enables certain spells (Demonic Circle, etc.) which require a specific focus object nearby.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `spellFocusType` | `SpellFocusObject.dbc` entry ID. Defines which spells use this focus. |
| data1 | `diameter` | Effective radius × 2 in yards. |
| data2 | `linkedTrap` | `gameobject_template.entry` of a linked trap. |
| data3 | `serverOnly` | Always 0. |
| data4 | `questId` | Required active quest to activate. |
| data5 | `large` | Boolean. |
| data6 | `floatingTooltip` | Boolean. |
| data7 | `floatOnWater` | Boolean. |
| data8 | `conditionId1` | Condition ID. |

### Type 9: TEXT

Displays a book or sign page text.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `pageId` | `page_text.entry` — the page chain to display. |
| data1 | `language` | `Languages.dbc` ID. Determines which players can read. |
| data2 | `pageMaterial` | `PageTextMaterial.dbc` ID for visual frame. |
| data3 | `allowMounted` | Boolean. |
| data4 | `conditionId1` | Condition ID. |
| data5 | `neverUsableWhileMounted` | Boolean. |

### Type 10: GOOBER

The most versatile interactive type. Used for quest items, special interactions, puzzle pieces.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `lockId` | `Lock.dbc` entry ID. |
| data1 | `questId` | `quest_template.ID` — required active quest. |
| data2 | `eventId` | `event_scripts` ID triggered on use. |
| data3 | `autoClose` | Milliseconds before GO returns to initial state. |
| data4 | `customAnim` | Custom animation played on use (1–4). |
| data5 | `consumable` | Boolean. 1 = despawns after use. |
| data6 | `cooldown` | Seconds between uses. |
| data7 | `pageId` | `page_text.entry` shown on use. |
| data8 | `language` | `Languages.dbc` ID for page. |
| data9 | `pageMaterial` | `PageTextMaterial.dbc` ID. |
| data10 | `spellId` | Spell cast on the using player. |
| data11 | `noDamageImmune` | Boolean. |
| data12 | `linkedTrap` | `gameobject_template.entry` of linked trap. |
| data13 | `large` | Boolean. Large interaction radius. |
| data14 | `openTextId` | Broadcast text on use. |
| data15 | `closeTextId` | Broadcast text on reset. |
| data16 | `losOK` | Boolean. Allow interaction without LOS. |
| data17 | — | Unused (data17 not mapped in wiki). |
| data18 | — | Unused. |
| data19 | `gossipId` | Gossip menu ID. Casts the spell when used via gossip. |
| data20 | `allowMultiInteract` | Boolean. Multiple players can interact simultaneously. |
| data21 | `floatOnWater` | Boolean. |
| data22 | `conditionId1` | Condition ID. |
| data23 | `playerCast` | Boolean. Spell attributed to player, not GO. |

### Type 11: TRANSPORT

Static elevator/lift that loops between floors on the same map (e.g., Throne of Tides elevator).

| Field | Name | Description |
|-------|------|-------------|
| data0 | `timeTo2ndFloor` | Travel time in ms to second floor. |
| data1 | `startOpen` | Initial state. |
| data2 | `autoClose` | Auto-close timer in ms. |
| data3 | `reached1stFloor` | Event fired on reaching floor 1. |
| data4 | `reached2ndFloor` | Event fired on reaching floor 2. |
| data5 | `spawnMap` | Map ID to spawn the transport on. |
| data6 | `timeTo3rdFloor` | Travel time to third floor (ms). |
| data7 | `reached3rdFloor` | Event fired on reaching floor 3. |
| data8–data21 | `timeToNthFloor` / `reachedNthFloor` | Continuation of floor timing/event pairs for up to ~11 floors. |
| data22 | `onlyChargeHeightCheck` | Boolean. |
| data23 | `onlyChargeTimeCheck` | Boolean. |

### Type 12: AREADAMAGE

Deals periodic damage in a radius.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `lockId` | Lock ID to open/activate. |
| data1 | `radius` | Damage radius in yards. |
| data2 | `damageMin` | Minimum damage per tick. |
| data3 | `damageMax` | Maximum damage per tick. |
| data4 | `damageSchool` | Damage school (0=Physical, 2=Fire, etc.). |
| data5 | `autoClose` | Auto-deactivation timer in ms. |
| data6 | `openTextId` | Broadcast text on activation. |
| data7 | `closeTextId` | Broadcast text on deactivation. |

### Type 13: CAMERA

Triggers a client-side cinematic.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `lockId` | Lock ID. |
| data1 | `cameraId` | Cinematic entry (`CinematicSequences.dbc`). |
| data2 | `eventId` | Server-side event script ID fired on use. |
| data3 | `openTextId` | Broadcast text. |
| data4 | `conditionId1` | Condition ID. |

### Type 14: MAP_OBJECT

Static map decoration. No interaction, no data fields. All `data0`–`data23` are unused.

### Type 15: MO_TRANSPORT

Moving transport that crosses map boundaries (boats, zeppelins, trams). Uses `TaxiPath.dbc` for routing.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `taxiPathId` | `TaxiPath.dbc` entry ID defining the movement path. |
| data1 | `moveSpeed` | Movement speed. |
| data2 | `accelRate` | Acceleration rate. |
| data3 | `startEventId` | Server event fired on departure. |
| data4 | `stopEventId` | Server event fired on arrival. |
| data5 | `transportPhysics` | Boolean. Enable transport physics. |
| data6 | `spawnMap` | Map ID where transport initially spawns. |
| data7 | `worldState1` | World state variable updated during transit. |
| data8 | `allowStopping` | Boolean. Transport can stop mid-path. |
| data9 | `initStopped` | Boolean. Transport starts in stopped state. |
| data10 | `trueInfiniteAOI` | Boolean. Always visible regardless of distance. |

### Type 16: DUEL_ARBITER

Exactly one GO exists with this type in the world (the duel flag). No meaningful `data` fields.

### Type 17: FISHINGNODE

Exactly one template. No meaningful `data` fields. The core handles all bobber logic directly.

### Type 18: RITUAL

Warlock summoning stone / ritual circle.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `casters` | Number of participants required. |
| data1 | `spellId` | Spell cast on ritual completion. |
| data2 | `animSpell` | Spell whose animation plays during ritual. |
| data3 | `ritualPersistent` | Boolean. GO persists after ritual completes. |
| data4 | `casterTargetSpell` | Spell cast on the target of the ritual. |
| data5 | `casterTargetSpellTargets` | Number of spell targets. |
| data6 | `castersGrouped` | Boolean. All casters must be in same group. |
| data7 | `ritualNoTargetCheck` | Boolean. Skip target requirement check. |
| data8 | `conditionId1` | Condition ID. |

### Type 19: MAILBOX

Standard mailbox. No type-specific `data` fields needed.

### Type 20: AUCTIONHOUSE

| Field | Name | Description |
|-------|------|-------------|
| data0 | `auctionHouseId` | `AuctionHouse.dbc` entry. Controls which auction house faction. |

### Type 21: GUARDPOST

Spawns a guard creature at the GO location.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `creatureId` | `creature_template.entry` of the guard to spawn. |
| data1 | `unk` | Unknown. Usually 0. |

### Type 22: SPELLCASTER

Single-purpose spell-casting station with limited charges.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `spellId` | Spell cast on using player. |
| data1 | `charges` | Number of uses before GO depletes. -1 = unlimited. |
| data2 | `partyOnly` | Boolean. Only group/raid members of creator can use. |
| data3 | `allowMounted` | Boolean. |
| data4 | `giganticAOI` | Boolean. |
| data5 | `conditionId1` | Condition ID. |
| data6 | `playerCast` | Boolean. Spell attributed to using player. |
| data7 | `neverUsableWhileMounted` | Boolean. |

### Type 23: MEETINGSTONE

Group Finder summoning stone.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `minLevel` | Minimum player level to use. |
| data1 | `maxLevel` | Maximum player level to use. |
| data2 | `areaId` | `AreaTable.dbc` area associated with this stone. |

### Type 24: FLAGSTAND

Capture-the-Flag home base / flag stand.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `lockId` | Lock ID. |
| data1 | `pickupSpell` | Spell cast on player when they pick up the flag. |
| data2 | `radius` | Capture/return radius in yards. |
| data3 | `returnAura` | Aura applied to flag carrier. |
| data4 | `returnSpell` | Spell cast when flag is returned. |
| data5 | `noDamageImmune` | Boolean. |
| data6 | `openTextId` | Broadcast text on flag pickup. |
| data7 | `losOK` | Boolean. |
| data8 | `conditionId1` | Condition ID. |
| data9 | `playerCast` | Boolean. |
| data10 | `giganticAOI` | Boolean. |
| data11 | `infiniteAOI` | Boolean. |
| data12 | `cooldown` | Cooldown in seconds. |

### Type 25: FISHINGHOLE

Fishing hole in open water with loot table.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `radius` | Radius of the fishing hole in yards. |
| data1 | `chestLoot` | `gameobject_loot_template.entry` for caught fish. |
| data2 | `minRestock` | Minimum fish per hole lifetime. |
| data3 | `maxRestock` | Maximum fish per hole lifetime. |
| data4 | `lockId` | Lock ID (rarely used). |

### Type 26: FLAGDROP

Dropped flag object for CTF battlegrounds.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `lockId` | Lock ID. |
| data1 | `eventId` | Event script fired on pickup. |
| data2 | `pickupSpell` | Spell cast on picking player. |
| data3 | `noDamageImmune` | Boolean. |
| data4 | `openTextId` | Broadcast text. |
| data5 | `playerCast` | Boolean. |
| data6 | `expireDuration` | Duration in ms before dropped flag auto-returns. |
| data7 | `giganticAOI` | Boolean. |
| data8 | `infiniteAOI` | Boolean. |
| data9 | `cooldown` | Cooldown in seconds. |

### Type 27: MINI_GAME / CUSTOM_TELEPORT

Re-purposed by AzerothCore core for custom GO teleporters.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `areatriggerTeleportId` | `areatrigger_teleport.id` — destination teleport record. |

### Type 28: LOTTERY_KIOSK

Not used in AzerothCore. All data fields are 0.

### Type 29: CAPTURE_POINT

World PvP capture points (Halaa, Towers of Zangarmarsh, etc.).

| Field | Name | Description |
|-------|------|-------------|
| data0 | `radius` | Capture interaction radius. |
| data1 | `spellId` | Unknown spell ID. |
| data2–data23 | Various | World state IDs, event IDs, and timing fields for capture mechanics. |

### Type 30: AURA_GENERATOR

Continuously applies an aura to all players within radius.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `startOpen` | Boolean. Active on spawn. |
| data1 | `radius` | Effect radius in yards. |
| data2 | `auraId1` | First spell ID to apply as aura. |
| data3 | `conditionId1` | Condition ID for first aura. |
| data4 | `auraId2` | Second spell ID. |
| data5 | `conditionId2` | Condition ID for second aura. |
| data6 | `serverOnly` | Boolean. Aura not sent to client. |

### Type 31: DUNGEON_DIFFICULTY

Instance portal with difficulty selection.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `mapId` | `Map.dbc` entry for the target instance. |
| data1 | `difficulty` | Normal difficulty ID. |
| data2 | `difficultyHeroic` | Heroic difficulty ID. |
| data3 | `difficultyEpic` | Epic difficulty ID. |
| data4 | `difficultyLegendary` | Legendary difficulty ID. |
| data5 | `heroicAttachment` | Entry of heroic version GO. |
| data6 | `challengeAttachment` | Entry of challenge version GO. |
| data7 | `difficultyAnimations` | Boolean. Show difficulty selection animation. |
| data8 | `largeAOI` | Boolean. |
| data9 | `giganticAOI` | Boolean. |
| data10 | `legacy` | Boolean. Legacy instance. |

### Type 32: BARBER_CHAIR

| Field | Name | Description |
|-------|------|-------------|
| data0 | `chairHeight` | Height of the sitting position. |
| data1 | `heightOffset` | Vertical offset adjustment. |
| data2 | `sitAnimKit` | Animation kit ID for the seated pose. |

### Type 33: DESTRUCTIBLE_BUILDING

Used in Wintergrasp siege warfare.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `intactNumHits` | Hits required to move from intact to damaged state. |
| data1 | `creditProxyCreature` | Creature entry credited for kill upon destruction. |
| data2 | `state1Name` | String/ID for state 1 name. |
| data3 | `intactEvent` | Event script ID on intact state entry. |
| data4 | `damagedDisplayId` | `GameObjectDisplayInfo` ID for damaged model. |
| data5 | `damagedNumHits` | Additional hits to move from damaged to destroyed. |
| data6–data8 | — | Empty/unused. |
| data9 | `damagedEvent` | Event script ID on damaged state entry. |
| data10 | `destroyedDisplayId` | Display ID for destroyed model. |
| data11–data13 | — | Empty/unused. |
| data14 | `destroyedEvent` | Event script ID on destruction. |
| data15 | — | Empty. |
| data16 | `debuildingTimeSecs` | Seconds before rebuild begins. |
| data17 | — | Empty. |
| data18 | `destructibleData` | `DestructibleModelData.dbc` entry ID. |
| data19 | `rebuildingEvent` | Event script ID at rebuild completion. |
| data20–data21 | — | Empty. |
| data22 | `damageEvent` | Event script fired on each damage hit. |
| data23 | — | Empty. |

### Type 34: GUILD_BANK

Standard guild bank terminal. No type-specific `data` fields. All `data0`–`data23` are 0.

### Type 35: TRAPDOOR

Vertical trapdoor that opens to reveal an entrance below.

| Field | Name | Description |
|-------|------|-------------|
| data0 | `whenToPause` | Pause condition (timing-based). |
| data1 | `startOpen` | Boolean. Starts in open position. |
| data2 | `autoClose` | Milliseconds before trapdoor closes. |
| data3 | `blocksPathsDown` | Boolean. Blocks pathfinding downward when closed. |
| data4 | `pathBlockerBump` | Boolean. Bump units off when closing. |

---

## GOState and LootState Enums

### GOState

Controls visual/interaction state sent to the client.

```cpp
enum GOState : uint8
{
    GO_STATE_ACTIVE             = 0, // In-use / activated state (open door, used button)
    GO_STATE_READY              = 1, // Default ready state (closed door, untouched chest)
    GO_STATE_ACTIVE_ALTERNATIVE = 2, // Alternate active state (some destructibles)
};
```

**Note:** `GO_STATE_DESTROYED` is not a separate enum value in WotLK; destruction is handled through `GameObjectFlags` (`GO_FLAG_DESTROYED`) rather than a state transition.

### LootState

Internal server-side state machine for interactable GOs (chests, doors, traps).

```cpp
enum LootState
{
    GO_NOT_READY        = 0, // Pre-initialization; not interactable.
    GO_READY            = 1, // Default; waiting for player interaction.
    GO_ACTIVATED        = 2, // Currently open/active (chest is open, trap is triggered).
    GO_JUST_DEACTIVATED = 3, // Transition state; about to reset to GO_READY.
};
```

**State transition sequence for a chest:**
```
GO_NOT_READY → GO_READY (spawned, door closes) → GO_ACTIVATED (player opens) → GO_JUST_DEACTIVATED → GO_READY (respawn)
```

### GameObjectFlags

Relevant flags set via `SetGameObjectFlag()` / `RemoveGameObjectFlag()`:

| Flag | Value | Description |
|------|-------|-------------|
| `GO_FLAG_IN_USE` | 0x00000001 | Currently being used/looted. |
| `GO_FLAG_LOCKED` | 0x00000002 | Locked; requires the correct lock/key. |
| `GO_FLAG_INTERACT_COND` | 0x00000004 | Interaction conditional (linked to condition). |
| `GO_FLAG_TRANSPORT` | 0x00000008 | Is a transport object. |
| `GO_FLAG_NOT_SELECTABLE` | 0x00000010 | Cannot be targeted or right-clicked. |
| `GO_FLAG_NODESPAWN` | 0x00000020 | Does not despawn. |
| `GO_FLAG_TRIGGERED` | 0x00000040 | Activated by trigger. |
| `GO_FLAG_DAMAGED` | 0x00000200 | Visual damaged state (destructibles). |
| `GO_FLAG_DESTROYED` | 0x00000400 | Visual destroyed state (destructibles). |

---

## GameObjectScript C++ API

### Class Overview

`GameObjectScript` inherits from `ScriptObject` and `UpdatableScript<GameObject>`. Register with `RegisterGameObjectScript("MyScriptName")` and set `ScriptName` in `gameobject_template`.

```cpp
class MyGoScript : public GameObjectScript
{
public:
    MyGoScript() : GameObjectScript("my_go_script") { }

    // Called when a player opens the gossip menu on this GO
    bool OnGossipHello(Player* player, GameObject* go) override;

    // Called when a gossip option is selected
    bool OnGossipSelect(Player* player, GameObject* go,
                        uint32 sender, uint32 action) override;

    // Called when a gossip option with a code input is selected
    bool OnGossipSelectCode(Player* player, GameObject* go,
                            uint32 sender, uint32 action,
                            const char* code) override;

    // Called when a player accepts a quest from this GO
    bool OnQuestAccept(Player* player, GameObject* go,
                       Quest const* quest) override;

    // Called when a player turns in a quest reward at this GO
    bool OnQuestReward(Player* player, GameObject* go,
                       Quest const* quest, uint32 opt) override;

    // Returns gossip dialog status for the player (cursor icon)
    uint32 GetDialogStatus(Player* player, GameObject* go) override;

    // Called when the GO is destroyed (HP reaches 0, type 33)
    void OnDestroyed(GameObject* go, Player* player) override;

    // Called when the GO takes damage (type 33)
    void OnDamaged(GameObject* go, Player* player) override;

    // Called when the GO's health is modified directly
    void OnModifyHealth(GameObject* go, Unit* attacker,
                        int32& change, SpellInfo const* spellInfo) override;

    // Called when LootState changes (includes "open" event for chests/doors)
    void OnLootStateChanged(GameObject* go, uint32 state, Unit* unit) override;

    // Called when GOState changes (visual state sent to client)
    void OnGameObjectStateChanged(GameObject* go, uint32 state) override;

    // Return a custom GameObjectAI subclass (advanced, rarely needed)
    GameObjectAI* GetAI(GameObject* go) const override;
};
```

### Attaching a Script

1. In C++, create a class inheriting `GameObjectScript` and register it:
   ```cpp
   void AddSC_my_go_script()
   {
       new MyGoScript();
   }
   ```
2. Call `AddSC_my_go_script()` from your module's `AddScripts()` function.
3. In the database, set `gameobject_template.ScriptName = "my_go_script"` for the desired entry.

### UpdatableScript — OnUpdate

Because `GameObjectScript` extends `UpdatableScript<GameObject>`, individual GO instances also receive `OnUpdate` ticks via the `GameObjectAI` path. For per-tick logic, override `GetAI()` and implement a `GameObjectAI` subclass:

```cpp
struct my_go_ai : public GameObjectAI
{
    my_go_ai(GameObject* go) : GameObjectAI(go) { }

    void UpdateAI(uint32 diff) override
    {
        // called every world update tick
    }
};
```

---

## GameObject Lifecycle in C++

### Spawning a GO Dynamically

```cpp
// Variant 1: explicit rotation quaternion
GameObject* go = map->SummonGameObject(
    entry,          // gameobject_template.entry
    x, y, z,        // position
    orientation,    // facing angle (radians)
    rot0, rot1, rot2, rot3,  // rotation quaternion (use 0,0,sin(o/2),cos(o/2))
    respawnTime,    // 0 = permanent, >0 = despawn after N seconds
    true            // checkTransport
);

// Variant 2: Position struct
GameObject* go = map->SummonGameObject(entry, pos, 0.f, 0.f, sinf(o/2), cosf(o/2), respawnTime);
```

**Notes:**
- `SummonGameObject` spawns a non-persistent GO (not saved to DB). Use `WorldDatabase` INSERT for permanent spawns.
- The rotation quaternion for a simple facing angle `o` is `(0, 0, sin(o/2), cos(o/2))`.

### Setting GO State

```cpp
go->SetGoState(GO_STATE_ACTIVE);           // open / activated
go->SetGoState(GO_STATE_READY);            // closed / ready
go->SetGoState(GO_STATE_ACTIVE_ALTERNATIVE); // alternate active

// Lock/unlock
go->SetGameObjectFlag(GO_FLAG_LOCKED);
go->RemoveGameObjectFlag(GO_FLAG_LOCKED);
```

### Setting Loot State

```cpp
go->SetLootState(GO_READY);            // close chest, ready for next loot
go->SetLootState(GO_ACTIVATED);        // force-open chest
go->SetLootState(GO_JUST_DEACTIVATED); // trigger reset cycle
```

### Activating/Using a GO

```cpp
go->Use(unit);  // Simulate a unit interacting with the GO (fires all interaction logic)
```

### Despawning and Deleting

```cpp
// Despawn and schedule respawn after N seconds (uses spawntimesecs if 0 is passed)
go->SetRespawnTime(30);        // respawn in 30 seconds
go->SetRespawnTime(0);         // use default spawntimesecs from DB
go->UpdateObjectVisibility();  // push state change to nearby clients

// Permanently remove from world without respawn
go->SetRespawnTime(0);
go->Delete();                  // removes from map and object store

// Mark as "not spawned" for respawn-from-DB objects:
go->SetRespawnTime(-1);        // starts despawned (negative in DB = starts despawned)
```

### Resetting a Chest

```cpp
// Force a chest to reset (close and become lootable again):
go->SetLootState(GO_JUST_DEACTIVATED);
go->SetGoState(GO_STATE_READY);
go->SetRespawnTime(0);
go->UpdateObjectVisibility();
```

### Checking GO Properties in C++

```cpp
uint32 entry   = go->GetEntry();
uint32 goType  = go->GetGOInfo()->type;       // GAMEOBJECT_TYPE_*
GOState state  = go->GetGoState();
LootState loot = go->getLootState();
Map* map       = go->GetMap();
float x = go->GetPositionX();
float y = go->GetPositionY();
float z = go->GetPositionZ();
float o = go->GetOrientation();
```

---

## gameobject Table (Spawned Instances)

Each row represents one spawned instance of a GO in the world. Multiple rows may share the same `id` (template entry), creating multiple copies.

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `guid` | INT UNSIGNED | PRI/NULL | Globally unique identifier for this spawn. Auto-incremented. |
| `id` | INT UNSIGNED | 0 | References `gameobject_template.entry`. |
| `map` | SMALLINT UNSIGNED | 0 | Map ID where this GO spawns. |
| `zoneId` | SMALLINT UNSIGNED | 0 | Zone ID. Auto-populated by server on startup if `AutoPopulateIntoDB` is enabled. |
| `areaId` | SMALLINT UNSIGNED | 0 | Sub-zone/area ID. Auto-populated on startup. |
| `spawnMask` | TINYINT UNSIGNED | 1 | Difficulty bitmask: 1=Normal/10-man, 2=25-man, 4=10-man heroic, 8=25-man heroic, 15=all. |
| `phaseMask` | SMALLINT UNSIGNED | 1 | Phase bitmask. 1 = default phase. Phased GOs are only visible to players in matching phases. |
| `position_x` | FLOAT SIGNED | 0 | X-axis world coordinate (East–West). |
| `position_y` | FLOAT SIGNED | 0 | Y-axis world coordinate (North–South). |
| `position_z` | FLOAT SIGNED | 0 | Z-axis world coordinate (altitude). |
| `orientation` | FLOAT SIGNED | 0 | Facing direction in radians. 0 = North, π = South. |
| `rotation0` | FLOAT SIGNED | 0 | Rotation quaternion X component. |
| `rotation1` | FLOAT SIGNED | 0 | Rotation quaternion Y component. |
| `rotation2` | FLOAT SIGNED | 0 | Rotation quaternion Z component. |
| `rotation3` | FLOAT SIGNED | 0 | Rotation quaternion W component. For simple facing: `sin(orientation/2)` and `cos(orientation/2)`. |
| `spawntimesecs` | INT SIGNED | 0 | Respawn time in seconds. 0 = does not respawn. Negative value = starts despawned, |respawn| = time to first spawn. |
| `animprogress` | TINYINT UNSIGNED | 0 | Animation progress value. Set to **100** for chests (open animation). |
| `state` | TINYINT UNSIGNED | 1 | Initial GOState. 1=GO_STATE_READY (closed/default), 0=GO_STATE_ACTIVE (open). |
| `ScriptName` | char(64) | '' | Per-spawn script name override. Overrides `gameobject_template.ScriptName` for this specific GUID. |
| `VerifiedBuild` | INT SIGNED | NULL | Build number this spawn was verified against. |
| `comment` | TEXT | NULL | Optional developer note about this spawn. |

**spawnMask values in detail:**

| Value | Meaning |
|-------|---------|
| 1 | 5-man Normal / 10-man Normal |
| 2 | 25-man Normal |
| 4 | 10-man Heroic |
| 8 | 25-man Heroic |
| 3 | 10N + 25N |
| 5 | 10N + 10H |
| 15 | All difficulties |

---

## Cross-References

- `gameobject_template.data1` for CHEST → `gameobject_loot_template.entry` — see loot system docs.
- `gameobject_template.data1` for DOOR → `Lock.dbc` — lock IDs and required items/spells.
- `gameobject_template.ScriptName` → `GameObjectScript` class — see C++ module dev docs.
- `gameobject_template.AIName = "SmartGameObjectAI"` → `smart_scripts` table — see SmartAI reference.
- `gameobject_template.data3` for GOOBER / `data6` for TRAP → `event_scripts` table.
- `gameobject_template.data7` for CHEST / `data3` for BUTTON → `gameobject_template.entry` (linked trap chain).
- `gameobject.phaseMask` → Phase system; cross-reference with `creature.phaseMask`.
- `gameobject.spawnMask` → Instance difficulty system; see `09_world_and_maps.md`.
- Areatrigger GO portals (type 27) → `areatrigger_teleport` table; see `09_world_and_maps.md`.
- Transport GOs (type 15) → `transports` table; see `09_world_and_maps.md`.
