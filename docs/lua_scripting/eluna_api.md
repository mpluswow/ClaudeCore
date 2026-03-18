# Eluna / ALE API — Complete Reference

> AzerothCore 3.3.5a (mod-ale). Primary server-side scripting API.
> Scripts run in Lua 5.2. Source: azerothcore.org/eluna

---

## Script Setup

### File placement
- Scripts go in `lua_scripts/` directory next to `worldserver` binary
- All `.lua` files auto-loaded at startup; subdirectories supported
- **File names must be unique across all subdirectories** — load order not guaranteed
- Use `require("subdir/filename")` (no `.lua` extension)

### Config (`mod-ale.conf`)
| Key | Default | Purpose |
|-----|---------|---------|
| `ALE.Enabled` | `1` | Enable/disable engine |
| `ALE.TraceBack` | `1` | Detailed error output |
| `ALE.ScriptPath` | `"lua_scripts"` | Path relative to worldserver binary |

### Critical Rules
- **NEVER store C++ userdata (Player, Creature, etc.) in globals across events** — they're invalidated when hook returns. Store GUIDs instead.
- Safe to store persistently: `ALEQuery`, `WorldPacket`, uint64/int64 objects
- Always use `local` variables
- Reload: `.reload ale` in-game, or `ReloadALE()` in Lua (dev only)

---

## Class Hierarchy

```
Object
└── WorldObject
    ├── Unit
    │   ├── Player
    │   ├── Creature
    │   │   └── Pet
    │   └── (Vehicle via GetVehicleKit)
    ├── GameObject
    └── Corpse
Item
Map
BattleGround
Group
Guild
Aura
Spell
SpellInfo
WorldPacket
ALEQuery
Quest
ItemTemplate
Loot
Roll
Vehicle
Ticket
ChatHandler
```

---

## Object (base class)

| Method | Returns | Description |
|--------|---------|-------------|
| `GetEntry()` | number | Entry ID |
| `GetGUID()` | number (uint64) | Full 64-bit GUID |
| `GetGUIDLow()` | number | Low part of GUID (DB key) |
| `GetTypeId()` | number | TypeId enum |
| `GetScale()` | number | Size scale |
| `SetScale(scale)` | void | |
| `IsInWorld()` | boolean | Added to map? |
| `IsPlayer()` | boolean | |
| `ToPlayer()` | Player\|nil | Safe cast |
| `ToCreature()` | Creature\|nil | |
| `ToGameObject()` | GameObject\|nil | |
| `ToUnit()` | Unit\|nil | |
| `GetUInt32Value(index)` | number | Raw field access |
| `SetUInt32Value(index, val)` | void | |
| `HasFlag(index, flag)` | boolean | |
| `SetFlag(index, flag)` | void | |
| `RemoveFlag(index, flag)` | void | |

---

## WorldObject

| Method | Returns | Description |
|--------|---------|-------------|
| `GetX/Y/Z/O()` | number | Coordinates |
| `GetLocation()` | x,y,z,o | All at once |
| `GetMapId()` | number | |
| `GetInstanceId()` | number | |
| `GetAreaId()` | number | |
| `GetZoneId()` | number | |
| `GetMap()` | Map | |
| `GetName()` | string | |
| `GetPhaseMask()` | number | |
| `SetPhaseMask(phase, update)` | void | |
| `GetDistance(obj)` | number | 3D distance |
| `GetDistance2d(obj)` | number | 2D distance |
| `IsWithinDistInMap(obj, dist)` | boolean | Same map + distance |
| `IsWithinLoS(obj)` | boolean | Line of sight |
| `GetNearestPlayer(range)` | Player\|nil | |
| `GetNearestCreature(entry, range, hostile, dead)` | Creature\|nil | |
| `GetNearestGameObject(entry, range)` | GameObject\|nil | |
| `GetPlayersInRange(range, hostile)` | table | |
| `GetCreaturesInRange(range, entry, hostile, dead)` | table | |
| `SpawnCreature(entry, x, y, z, o, type, despawnMs)` | Creature | |
| `SummonGameObject(entry, x, y, z, o, respawnDelay)` | GameObject | |
| `PlayDirectSound(soundId, player)` | void | |
| `SendPacket(packet)` | void | To nearby players |
| `RegisterEvent(func, delay, repeats)` | eventId | Timed event on object |
| `RemoveEventById(eventId)` | void | |
| `RemoveEvents()` | void | |

---

## Unit

| Method | Returns | Description |
|--------|---------|-------------|
| `GetHealth()` | number | Current HP |
| `GetMaxHealth()` | number | |
| `GetHealthPct()` | number | HP % |
| `SetHealth(val)` | void | |
| `SetMaxHealth(val)` | void | |
| `HealthAbovePct(pct)` | boolean | |
| `HealthBelowPct(pct)` | boolean | |
| `GetPower(type)` | number | 0=mana,1=rage,3=energy,6=runic |
| `GetMaxPower(type)` | number | |
| `SetPower(type, amount)` | void | |
| `GetPowerType()` | number | |
| `GetLevel()` | number | |
| `SetLevel(level)` | void | |
| `GetClass()` | number | Class ID |
| `GetRace()` | number | Race ID |
| `GetGender()` | number | |
| `GetFaction()` | number | |
| `SetFaction(id)` | void | |
| `GetDisplayId()` | number | |
| `SetDisplayId(id)` | void | |
| `GetNativeDisplayId()` | number | |
| `DeMorph()` | void | Reset to native |
| `GetMountId()` | number | |
| `Mount(displayId)` | void | |
| `Dismount()` | void | |
| `GetSpeed(moveType)` | number | |
| `SetSpeed(moveType, speed, force)` | void | |
| `GetVictim()` | Unit\|nil | Current attack target |
| `IsAlive()` | boolean | |
| `IsDead()` | boolean | |
| `IsInCombat()` | boolean | |
| `IsCasting()` | boolean | |
| `IsCharmed()` | boolean | |
| `IsRooted()` | boolean | |
| `HasAura(spellId)` | boolean | |
| `GetAura(spellId)` | Aura\|nil | |
| `AddAura(spellId, target)` | void | |
| `RemoveAura(spellId)` | void | |
| `RemoveAllAuras()` | void | |
| `CastSpell(target, spellId)` | void | |
| `CastSpellAoF(x, y, z, spellId)` | void | |
| `CastCustomSpell(target, spellId, bp0, bp1, bp2, triggered)` | void | |
| `StopSpellCast()` | void | |
| `Attack(target)` | void | |
| `AttackStop()` | void | |
| `Kill(target)` | void | |
| `DealDamage(target, damage)` | void | |
| `GetThreat(unit)` | number | |
| `AddThreat(victim, amount)` | void | |
| `ClearThreatList()` | void | |
| `SetFacing(orientation)` | void | |
| `SetFacingToObject(obj)` | void | |
| `NearTeleport(x, y, z, o)` | void | Same-map teleport |
| `MoveChase(target)` | void | |
| `MoveFollow(target, dist, angle)` | void | |
| `MoveHome()` | void | |
| `MoveTo(x, y, z, dist, forward)` | void | |
| `MoveStop()` | void | |
| `MoveJump(x, y, z, zSpeed, speed)` | void | |
| `EmoteState(emote)` | void | Continuous |
| `PerformEmote(emote)` | void | One-shot |
| `SendUnitSay(msg, lang)` | void | |
| `SendUnitYell(msg, lang)` | void | |
| `SendUnitWhisper(msg, lang, player, boss)` | void | |

---

## Player

### Identification & Status
| Method | Returns |
|--------|---------|
| `GetName()` | string |
| `GetLevel()` | number |
| `GetGUIDLow()` | number (char DB key) |
| `GetAccountId()` | number |
| `GetAccountName()` | string |
| `GetTeam()` | number (0=Alliance, 1=Horde) |
| `IsAlliance()` | boolean |
| `IsHorde()` | boolean |
| `IsGM()` | boolean |

### Money
| Method | Returns |
|--------|---------|
| `GetCoinage()` | number (copper) |
| `SetCoinage(amount)` | void |
| `ModifyMoney(amount)` | void (positive=add, negative=remove) |

### XP & Level
| Method | Returns |
|--------|---------|
| `GetXP()` | number |
| `GiveXP(xp, victim)` | void |
| `GetTotalPlayedTime()` | number |
| `GetLevelPlayedTime()` | number |

### Items
| Method | Returns |
|--------|---------|
| `AddItem(entry, amount)` | Item\|nil |
| `RemoveItem(entry, amount)` | void |
| `HasItem(entry, count, check_bank)` | boolean |
| `GetItemByEntry(entry)` | Item\|nil |
| `GetItemByGUID(guid)` | Item\|nil |
| `GetItemByPos(bag, slot)` | Item\|nil |
| `GetItemCount(entry, in_bank)` | number |
| `GetEquippedItemBySlot(slot)` | Item\|nil |
| `EquipItem(item, slot)` | Item\|nil |
| `CanEquipItem(item, slot)` | boolean |

### Communication
| Method | Returns |
|--------|---------|
| `SendBroadcastMessage(msg)` | void |
| `SendAreaTriggerMessage(msg)` | void (yellow text) |
| `SendNotification(msg)` | void (error frame) |
| `SendAddonMessage(prefix, msg, type, receiver)` | void |
| `Say(text, lang)` | void |
| `Yell(text, lang)` | void |

### Quests
| Method | Returns |
|--------|---------|
| `AddQuest(entry)` | void |
| `RemoveQuest(entry)` | void |
| `CompleteQuest(entry)` | void |
| `FailQuest(entry)` | void |
| `HasQuest(entry)` | boolean |
| `GetQuestStatus(entry)` | number |
| `KilledMonsterCredit(entry, guid)` | void |

### Teleport
| Method | Returns |
|--------|---------|
| `Teleport(mapId, x, y, z, o)` | boolean |
| `GetHomebind()` | map, x, y, z |
| `SetBindPoint(x, y, z, mapId, areaId)` | void |

### Skills & Spells
| Method | Returns |
|--------|---------|
| `HasSkill(skillId)` | boolean |
| `GetSkillValue(skillId)` | number |
| `SetSkill(skillId, step, current, max)` | void |
| `HasSpell(spellId)` | boolean |
| `LearnSpell(spellId)` | void |
| `RemoveSpell(spellId)` | void |
| `HasSpellCooldown(spellId)` | boolean |
| `ResetSpellCooldown(spellId, update)` | void |
| `ResetAllCooldowns()` | void |

### Honor & PvP
| Method | Returns |
|--------|---------|
| `GetHonorPoints()` | number |
| `SetHonorPoints(amount)` | void |
| `ModifyHonorPoints(amount)` | void |
| `GetArenaPoints()` | number |
| `SetArenaPoints(amount)` | void |
| `ModifyArenaPoints(amount)` | void |
| `GetLifetimeKills()` | number |
| `InBattleground()` | boolean |
| `InArena()` | boolean |

### Reputation
| Method | Returns |
|--------|---------|
| `GetReputation(factionId)` | number |
| `SetReputation(factionId, amount)` | void |
| `GetReputationRank(factionId)` | number |

### Group & Guild
| Method | Returns |
|--------|---------|
| `GetGroup()` | Group\|nil |
| `IsInGroup()` | boolean |
| `GetGuild()` | Guild\|nil |
| `GetGuildId()` | number |
| `GetGuildName()` | string |
| `IsInGuild()` | boolean |

### Gossip
| Method | Returns |
|--------|---------|
| `GossipMenuAddItem(icon, msg, sender, intid, code, popupMsg, popupMoney)` | void |
| `GossipSendMenu(npc_text_id, unit, menuId)` | void |
| `GossipClearMenu()` | void |
| `GossipComplete()` | void |
| `GossipAddQuests(unit)` | void |

### Misc
| Method | Returns |
|--------|---------|
| `GetLatency()` | number (ms) |
| `GetPlayerIP()` | string |
| `SaveToDB()` | void |
| `KickPlayer()` | void |
| `ResurrectPlayer(pct, sickness)` | void |
| `GetSelection()` | Unit\|nil |
| `GetCorpse()` | Corpse\|nil |
| `DoRandomRoll(min, max)` | void |
| `RunCommand(command)` | void |

---

## Creature

| Method | Returns | Description |
|--------|---------|-------------|
| `GetEntry()` | number | Template entry ID |
| `GetScriptName()` | string | |
| `GetDBTableGUIDLow()` | number | Spawn GUID |
| `GetRank()` | number | 0=Normal,1=Elite,2=RareElite,3=Boss,4=Rare |
| `GetNPCFlags()` | number | |
| `SetNPCFlags(flags)` | void | |
| `GetReactState()` | number | |
| `SetReactState(state)` | void | |
| `GetHomePosition()` | x,y,z,o | Evade return point |
| `SetHomePosition(x,y,z,o)` | void | |
| `GetWaypointPath()` | number | |
| `SetCorpseDelay(delay)` | void | |
| `SetRespawnDelay(delay)` | void | |
| `GetLoot()` | Loot | |
| `HasLootRecipient()` | boolean | |
| `GetAITarget(select, exception, dist, aura)` | Unit\|nil | |
| `GetAITargets()` | table | All threat list entries |
| `SelectVictim()` | Unit | |
| `IsElite()` | boolean | |
| `IsWorldBoss()` | boolean | |
| `IsInEvadeMode()` | boolean | |
| `SetNoCallAssistance(on)` | void | |
| `SetInCombatWithZone()` | void | All players in instance |
| `Respawn()` | void | |
| `DespawnOrUnsummon(msDelay)` | void | |
| `AttackStart(target)` | void | |
| `MoveWaypoint()` | void | Resume waypoint path |
| `UpdateEntry(entry)` | void | Morph to other creature |
| `SetEquipmentSlots(s1, s2, s3)` | void | |
| `AllLootRemovedFromCorpse()` | void | |

---

## Item

| Method | Returns |
|--------|---------|
| `GetEntry()` | number |
| `GetOwner()` | Player |
| `GetCount()` | number |
| `SetCount(n)` | void |
| `GetQuality()` | number (0=Poor…6=Artifact) |
| `GetItemLevel()` | number |
| `GetRequiredLevel()` | number |
| `GetInventoryType()` | number |
| `GetBuyPrice()` | number |
| `GetSellPrice()` | number |
| `GetItemLink()` | string (chat hyperlink) |
| `GetItemTemplate()` | ItemTemplate |
| `IsSoulBound()` | boolean |
| `IsEquipped()` | boolean |
| `SetEnchantment(slot, enchantId)` | void |
| `ClearEnchantment(slot)` | void |
| `SaveToDB()` | void |

---

## Map

| Method | Returns |
|--------|---------|
| `GetMapId()` | number |
| `GetName()` | string |
| `GetInstanceId()` | number |
| `GetDifficulty()` | number |
| `GetPlayerCount()` | number |
| `GetPlayers()` | table |
| `GetCreatures()` | table |
| `GetHeight(x, y)` | number |
| `GetAreaId(x, y, z)` | number |
| `SetWeather(type, grade)` | void |
| `IsArena()` | boolean |
| `IsBattleground()` | boolean |
| `IsDungeon()` | boolean |
| `IsRaid()` | boolean |
| `IsHeroic()` | boolean |

---

## Global Functions

### Players & GUIDs
```lua
GetPlayerByName(name)           → Player|nil
GetPlayerByGUID(guid)           → Player|nil
GetPlayersInWorld(team, gmOnly) → table
GetPlayerCount()                → number
GetPlayerGUID(lowguid)          → uint64 (full GUID)
GetGUIDLow(guid)                → number
GetGUIDType(guid)               → number
GetUnitGUID(lowguid, entry)     → uint64
GetObjectGUID(lowguid, entry)   → uint64
```

### World & Maps
```lua
GetMapById(mapId, instanceId)   → Map|nil
GetItemTemplate(itemId)         → ItemTemplate
GetItemLink(entry, locale)      → string
GetSpellInfo(spellId)           → SpellInfo
GetQuest(questId)               → Quest
GetAreaName(areaId, locale)     → string
IsGameEventActive(id)           → boolean
StartGameEvent(id)
StopGameEvent(id)
GetActiveGameEvents()           → table
GetCurrTime()                   → number (ms)
GetGameTime()                   → number (seconds)
```

### Database
```lua
CharDBQuery(sql)                → ALEQuery|nil  (sync)
CharDBExecute(sql)              (async, no result)
CharDBQueryAsync(sql, callback) (async with callback)
WorldDBQuery(sql)               → ALEQuery|nil
WorldDBExecute(sql)
AuthDBQuery(sql)                → ALEQuery|nil
AuthDBExecute(sql)
```

### Communication
```lua
SendWorldMessage(msg)           -- broadcast to all players
SendMail(subject, text, receiverGUIDLow, senderGUIDLow, stationary, delay, money, cod, entry, amount)
RunCommand(cmd)                 -- server console command
SaveAllPlayers()
```

### Timed Events
```lua
CreateLuaEvent(func, delay, repeats)     → eventId  (delay in ms; 0 repeats = infinite)
CreateLuaEvent(func, {min,max}, repeats) → eventId  (random delay range)
RemoveEventById(eventId, all_events)
RemoveEvents()                           -- remove all global events
```

### Spawning
```lua
PerformIngameSpawn(type, entry, mapId, instanceId, x, y, z, o, save, despawn, phase)
-- type: 1=Creature, 2=GameObject
```

### Packets
```lua
CreatePacket(opcode, size)  → WorldPacket
```

### Logging
```lua
PrintInfo(...)    PrintError(...)    PrintDebug(...)    print(...)
```

### Bitwise
```lua
bit_and(a,b)  bit_or(a,b)  bit_xor(a,b)  bit_not(a)
bit_lshift(a,n)  bit_rshift(a,n)
```

---

## ALEQuery (Database Result)

```lua
local result = CharDBQuery("SELECT entry, name FROM creature_template WHERE entry = 100")
if result then
    repeat
        local entry = result:GetUInt32()   -- auto-advances column
        local name  = result:GetString()
    until not result:NextRow()
end
```

| Method | Returns |
|--------|---------|
| `GetString()` | string |
| `GetUInt8/16/32/64()` | number |
| `GetInt8/16/32/64()` | number |
| `GetFloat()` | number |
| `GetDouble()` | number |
| `GetBool()` | boolean |
| `GetRow()` | table (field→value for current row) |
| `IsNull()` | boolean |
| `GetRowCount()` | number |
| `GetColumnCount()` | number |
| `NextRow()` | boolean (false = no more rows) |

---

## Event Registration

### Pattern
```lua
local cancel = RegisterPlayerEvent(event, function, shots)
-- shots: 0 = unlimited (default), N = fire N times then auto-remove
cancel()  -- unbind
```

### RegisterPlayerEvent — Key Events
| Constant | Value | Extra Callback Params |
|----------|-------|-----------------------|
| `PLAYER_EVENT_ON_CHARACTER_CREATE` | 1 | |
| `PLAYER_EVENT_ON_LOGIN` | 3 | |
| `PLAYER_EVENT_ON_LOGOUT` | 4 | |
| `PLAYER_EVENT_ON_SPELL_CAST` | 5 | (spell, skipCheck) |
| `PLAYER_EVENT_ON_KILL_PLAYER` | 6 | (killed) |
| `PLAYER_EVENT_ON_KILL_CREATURE` | 7 | (killed) |
| `PLAYER_EVENT_ON_KILLED_BY_CREATURE` | 8 | (killer) |
| `PLAYER_EVENT_ON_GIVE_XP` | 12 | (amount, victim) |
| `PLAYER_EVENT_ON_LEVEL_CHANGE` | 13 | (oldLevel) |
| `PLAYER_EVENT_ON_MONEY_CHANGE` | 14 | (amount) |
| `PLAYER_EVENT_ON_REPUTATION_CHANGE` | 15 | (faction, standing, incremental) |
| `PLAYER_EVENT_ON_CHAT` | 18 | (msg, type, lang) |
| `PLAYER_EVENT_ON_SAVE` | 25 | |
| `PLAYER_EVENT_ON_UPDATE_ZONE` | 27 | (newZone, newArea) |
| `PLAYER_EVENT_ON_EQUIP` | 29 | (item, bag, slot) |
| `PLAYER_EVENT_ON_FIRST_LOGIN` | 30 | |
| `PLAYER_EVENT_ON_LOOT_ITEM` | 32 | (item) |
| `PLAYER_EVENT_ON_ENTER_COMBAT` | 33 | (enemy) |
| `PLAYER_EVENT_ON_LEAVE_COMBAT` | 34 | |
| `PLAYER_EVENT_ON_REPOP` | 35 | |
| `PLAYER_EVENT_ON_RESURRECT` | 36 | |
| `PLAYER_EVENT_ON_QUEST_ACCEPT` | 63 | (quest) |
| `PLAYER_EVENT_ON_COMPLETE_QUEST` | 54 | (quest) |
| `PLAYER_EVENT_ON_COMMAND` | 42 | (command) — return false to override |

### RegisterCreatureEvent
```lua
RegisterCreatureEvent(entry, event, function [, shots])
-- entry = 0 → all creatures
```
| Constant | Value | Extra Callback Params |
|----------|-------|-----------------------|
| `CREATURE_EVENT_ON_ENTER_COMBAT` | 1 | (target) |
| `CREATURE_EVENT_ON_LEAVE_COMBAT` | 2 | |
| `CREATURE_EVENT_ON_TARGET_DIED` | 3 | (victim) |
| `CREATURE_EVENT_ON_DIED` | 4 | (killer) |
| `CREATURE_EVENT_ON_SPAWN` | 5 | |
| `CREATURE_EVENT_ON_REACH_WP` | 6 | (wpId, pathId) |
| `CREATURE_EVENT_ON_AIUPDATE` | 7 | (diff) |
| `CREATURE_EVENT_ON_DAMAGE_TAKEN` | 9 | (attacker, damage) |
| `CREATURE_EVENT_ON_HIT_BY_SPELL` | 14 | (caster, spellId) |
| `CREATURE_EVENT_ON_SUMMONED` | 22 | (summoner) |
| `CREATURE_EVENT_ON_RESET` | 23 | |
| `CREATURE_EVENT_ON_REACH_HOME` | 24 | |
| `CREATURE_EVENT_ON_MOVE_IN_LOS` | 27 | (unit) |
| `CREATURE_EVENT_ON_QUEST_ACCEPT` | 31 | (player, quest) |
| `CREATURE_EVENT_ON_QUEST_REWARD` | 34 | (player, quest, opt) |
| `CREATURE_EVENT_ON_ADD` | 36 | (added to world) |
| `CREATURE_EVENT_ON_REMOVE` | 37 | (removed from world) |

### RegisterAllCreatureEvent
```lua
RegisterAllCreatureEvent(event, function [, shots])
-- Same constants as RegisterCreatureEvent; fires for ALL creatures
```

### RegisterGameObjectEvent
```lua
RegisterGameObjectEvent(entry, event, function [, shots])
```
| Constant | Value |
|----------|-------|
| `GAMEOBJECT_EVENT_ON_AIUPDATE` | 1 |
| `GAMEOBJECT_EVENT_ON_SPAWN` | 2 |
| `GAMEOBJECT_EVENT_ON_QUEST_ACCEPT` | 4 |
| `GAMEOBJECT_EVENT_ON_DESTROYED` | 7 |
| `GAMEOBJECT_EVENT_ON_LOOT_STATE_CHANGE` | 9 |
| `GAMEOBJECT_EVENT_ON_GO_STATE_CHANGED` | 10 |
| `GAMEOBJECT_EVENT_ON_USE` | 14 |

### RegisterItemEvent
```lua
RegisterItemEvent(entry, event, function [, shots])
```
| Constant | Value | Notes |
|----------|-------|-------|
| `ITEM_EVENT_ON_USE` | 2 | return false to block |
| `ITEM_EVENT_ON_QUEST_ACCEPT` | 3 | return true to handle |
| `ITEM_EVENT_ON_EXPIRE` | 4 | |
| `ITEM_EVENT_ON_REMOVE` | 5 | |

### RegisterServerEvent
```lua
RegisterServerEvent(event, function [, shots])
```
| Constant | Value |
|----------|-------|
| `WORLD_EVENT_ON_CONFIG_LOAD` | 9 |
| `WORLD_EVENT_ON_SHUTDOWN_INIT` | 11 |
| `WORLD_EVENT_ON_UPDATE` | 13 |
| `WORLD_EVENT_ON_STARTUP` | 14 |
| `WORLD_EVENT_ON_SHUTDOWN` | 15 |
| `ALE_EVENT_ON_LUA_STATE_CLOSE` | 16 |
| `MAP_EVENT_ON_PLAYER_ENTER` | 21 |
| `MAP_EVENT_ON_PLAYER_LEAVE` | 22 |
| `TRIGGER_EVENT_ON_TRIGGER` | 24 |
| `WEATHER_EVENT_ON_CHANGE` | 25 |
| `ADDON_EVENT_ON_MESSAGE` | 30 |
| `GAME_EVENT_START` | 34 |
| `GAME_EVENT_STOP` | 35 |

### RegisterGroupEvent
| Constant | Value |
|----------|-------|
| `GROUP_EVENT_ON_MEMBER_ADD` | 1 |
| `GROUP_EVENT_ON_MEMBER_REMOVE` | 3 |
| `GROUP_EVENT_ON_LEADER_CHANGE` | 4 |
| `GROUP_EVENT_ON_DISBAND` | 5 |
| `GROUP_EVENT_ON_CREATE` | 6 |

### RegisterGuildEvent
| Constant | Value |
|----------|-------|
| `GUILD_EVENT_ON_ADD_MEMBER` | 1 |
| `GUILD_EVENT_ON_REMOVE_MEMBER` | 2 |
| `GUILD_EVENT_ON_CREATE` | 5 |
| `GUILD_EVENT_ON_DISBAND` | 6 |
| `GUILD_EVENT_ON_MONEY_WITHDRAW` | 7 |
| `GUILD_EVENT_ON_MONEY_DEPOSIT` | 8 |

### RegisterBGEvent
| Constant | Value |
|----------|-------|
| `BG_EVENT_ON_START` | 1 |
| `BG_EVENT_ON_END` | 2 |
| `BG_EVENT_ON_CREATE` | 3 |

### RegisterMapEvent / RegisterInstanceEvent
```lua
RegisterMapEvent(map_id, event, function [, shots])
RegisterInstanceEvent(instance_id, event, function [, shots])
```
| Constant | Value | Callback |
|----------|-------|---------|
| `INSTANCE_EVENT_ON_INITIALIZE` | 1 | (event, instance_data, map) |
| `INSTANCE_EVENT_ON_LOAD` | 2 | |
| `INSTANCE_EVENT_ON_UPDATE` | 3 | (event, instance_data, map, diff) |
| `INSTANCE_EVENT_ON_PLAYER_ENTER` | 4 | (event, instance_data, map, player) |
| `INSTANCE_EVENT_ON_CREATURE_CREATE` | 5 | (event, instance_data, map, creature) |
| `INSTANCE_EVENT_ON_GAMEOBJECT_CREATE` | 6 | (event, instance_data, map, go) |

### Gossip Events
```lua
RegisterCreatureGossipEvent(entry, event, function)
RegisterGameObjectGossipEvent(entry, event, function)
RegisterItemGossipEvent(entry, event, function)
RegisterPlayerGossipEvent(menu_id, event, function)
```
| Constant | Value |
|----------|-------|
| `GOSSIP_EVENT_ON_HELLO` | 1 |
| `GOSSIP_EVENT_ON_SELECT` | 2 |

---

## Aura

| Method | Returns |
|--------|---------|
| `GetAuraId()` | number (spell ID) |
| `GetCaster()` | Unit |
| `GetOwner()` | Unit |
| `GetDuration()` | number (ms remaining) |
| `GetMaxDuration()` | number |
| `SetDuration(ms)` | void |
| `GetStackAmount()` | number |
| `SetStackAmount(n)` | void |
| `Remove()` | void |

---

## WorldPacket

```lua
local pkt = CreatePacket(opcode, size)
pkt:WriteULong(value)
pkt:WriteString("text")
player:SendPacket(pkt)
```

Write: `WriteByte/UByte/Short/UShort/Long/ULong/Float/Double/GUID/PackedGUID/String`
Read: `ReadByte/UByte/Short/UShort/Long/ULong/Float/Double/GUID/PackedGUID/String`
Info: `GetOpcode()`, `SetOpcode(op)`, `GetSize()`

---

## Common Patterns

```lua
-- Login greeting
RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, function(event, player)
    player:SendBroadcastMessage("Welcome, " .. player:GetName() .. "!")
end)

-- Creature combat events
RegisterCreatureEvent(12345, CREATURE_EVENT_ON_ENTER_COMBAT, function(event, creature, target)
    creature:SendUnitYell("For the Horde!", 0)
end)

RegisterCreatureEvent(12345, CREATURE_EVENT_ON_AIUPDATE, function(event, creature, diff)
    if creature:GetHealthPct() < 30 and not creature:HasAura(12345) then
        creature:CastSpell(creature, 12345)
    end
end)

-- Repeating timed event
CreateLuaEvent(function(id, delay, repeats)
    SendWorldMessage("Server announcement!")
end, 60000, 0)   -- every 60s, infinite

-- Safe cross-event GUID pattern
RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, function(event, player)
    local guid = player:GetGUID()   -- store GUID, not userdata
    CreateLuaEvent(function()
        local p = GetPlayerByGUID(guid)
        if p then p:SendBroadcastMessage("5 seconds later!") end
    end, 5000, 1)
end)

-- DB query
local result = CharDBQuery(
    string.format("SELECT data FROM custom_table WHERE guid = %d", player:GetGUIDLow())
)
if result then
    local val = result:GetString()
end

-- DB async query
CharDBQueryAsync(
    "SELECT entry, name FROM creature_template LIMIT 10",
    function(result)
        if result then
            repeat
                print(result:GetUInt32(), result:GetString())
            until not result:NextRow()
        end
    end
)

-- Gossip menu
RegisterCreatureGossipEvent(12345, GOSSIP_EVENT_ON_HELLO, function(event, player, creature)
    player:GossipClearMenu()
    player:GossipMenuAddItem(0, "Option 1", 1, 1)
    player:GossipMenuAddItem(0, "Option 2", 1, 2)
    player:GossipSendMenu(1, creature, 12345)
    return false
end)

RegisterCreatureGossipEvent(12345, GOSSIP_EVENT_ON_SELECT, function(event, player, creature, sender, intid, code)
    if intid == 1 then
        player:SendBroadcastMessage("You chose option 1!")
    end
    player:GossipComplete()
end)
```

---

## AIO Integration with Eluna

AIO (Addon I/O) runs on top of Eluna. The server-side script:
1. Calls `AIO.AddAddon([path, name])` at startup to register client addon files
2. Uses `AIO.Handle(player, name, handlerName, ...)` to trigger client-side handlers
3. Uses `AIO.AddHandlers(name, handlerTable)` to receive messages from the client

Server addon files are auto-distributed to connecting players and cached client-side.

*Last updated: 2026-03-17*
