# dfp-ah — Dreamforge Auction House Module

Opens the Auction House from anywhere in the world via the `/ah` slash command — no need to travel to a city.

---

## Files

| File | Side | Description |
|------|------|-------------|
| `dfp-ah-server.lua` | Server | Handles `.ah` dot command, spawns/reuses auctioneer NPC, opens AH |
| `game_client/.../DFP_AH/DFP_AH.lua` | Client | Registers `/ah` slash command, sends `.ah` to server via SAY |
| `game_client/.../DFP_AH/DFP_AH.toc` | Client | Addon manifest |

---

## How It Works

```
Player types /ah (or clicks DforgePanel AH button)
    │
    ▼
DFP_AH.lua  →  SendChatMessage(".ah", "SAY")
    │
    ▼  (server receives SAY message starting with ".")
dfp-ah-server.lua  PLAYER_EVENT_ON_COMMAND (event 42)
    │
    ├─ Does playerAuctioneer[playerKey] exist?
    │   ├─ YES → GetWorldObject(existingGUID)
    │   │         ├─ Found → SendAuctionMenu(c)  [reuse, no new spawn]  ──► done
    │   │         └─ Gone  → clear entry, fall through to spawn
    │   └─ NO  → fall through to spawn
    │
    ▼
SpawnCreature(entry, x, y, z, o, TIMED_DESPAWN, 300000ms)
    │
    ├─ SetNPCFlags(AUCTIONEER)
    ├─ SetUnitFlags(NON_ATTACKABLE | IMMUNE_TO_PC | IMMUNE_TO_NPC)
    ├─ SetReactState(PASSIVE)
    └─ playerAuctioneer[playerKey] = creatureGUID
    │
    ▼  (200ms timer — waits for client to process SMSG_UPDATE_OBJECT CREATE)
CreateLuaEvent +200ms
    │
    └─ GetPlayerByGUID → GetWorldObject → SendAuctionMenu(c)
                                              │
                                              ▼
                                        Client receives MSG_AUCTION_HELLO
                                        AH frame opens
```

**Why the 200ms delay?** The client must process the creature's `SMSG_UPDATE_OBJECT (CREATE)` packet before it receives `MSG_AUCTION_HELLO`. Without the delay the client silently discards the AH hello because it has no record of that creature GUID yet.

**Why keep the NPC visible?** Setting the display to invisible or adding `NOT_SELECTABLE` immediately after `SendAuctionMenu` causes the WoW 3.3.5a client to close the AH frame — it detects that the interacting creature is no longer available. The NPC stays fully visible and selectable for its entire 5-minute lifespan.

---

## Configuration

Edit the constants at the top of `dfp-ah-server.lua`:

| Constant | Default | Description |
|----------|---------|-------------|
| `ENTRY_AUCTIONEER_ALLIANCE` | `8719` | Auctioneer Fitch (faction 12, Stormwind) |
| `ENTRY_AUCTIONEER_HORDE` | `8673` | Auctioneer Thathung (faction 29, Orgrimmar) |
| `AH_DESPAWN_MS` | `300000` | NPC lifetime in milliseconds (5 minutes) |

---

## NPC Deduplication

The module maintains a per-player GUID map at script scope:

```lua
local playerAuctioneer = {}  -- key: tostring(playerGUID), value: creatureGUID (uint64)
```

On each `.ah` command:
1. Check if an entry exists for the player.
2. Call `GetWorldObject(existingGUID)` — returns `nil` if the creature has despawned.
3. If found: call `SendAuctionMenu` immediately on the existing NPC. No spawn.
4. If not found: clear the stale entry, spawn a fresh NPC, store the new GUID.

**Result:** spamming the button never creates more than one NPC per player at a time.

**Why `tostring(playerGUID)`?** `GetGUID()` returns a `uint64` userdata object. Each call returns a new Lua object — two userdata values representing the same GUID are never `==` in Lua. Converting to string with `tostring()` produces a stable, comparable key.

---

## Faction Mapping

The NPC entry determines which Auction House the client opens — this is resolved server-side by `GetAuctionHouseEntryFromFactionTemplate` reading the NPC's native faction:

| NPC Entry | Name | Faction Template | AH House |
|-----------|------|-----------------|----------|
| 8719 | Auctioneer Fitch | 12 (Stormwind) | Alliance (house 2) |
| 8673 | Auctioneer Thathung | 29 (Orgrimmar) | Horde (house 6) |

Player team is checked via `player:GetTeam()`: returns `0` = Alliance, `1` = Horde.

---

## NPC Flags and Unit Flags

Applied immediately after spawn (before the 200ms timer):

| Flag | Value | Purpose |
|------|-------|---------|
| `UNIT_NPC_FLAG_AUCTIONEER` | `0x200000` | Marks the NPC as an auctioneer — required for `SendAuctionMenu` and for server validation of subsequent CMSG packets |
| `NON_ATTACKABLE` | `2` | Cannot be attacked |
| `IMMUNE_TO_PC` | `256` | Players cannot initiate combat |
| `IMMUNE_TO_NPC` | `512` | Other NPCs cannot initiate combat |

`NOT_SELECTABLE` (`33554432`) is intentionally **not** set — the WoW client needs the creature to remain selectable for the AH session to stay open.

---

## Eluna Event

| Event | Constant | Raw Value |
|-------|----------|-----------|
| `PLAYER_EVENT_ON_COMMAND` | `EV_COMMAND` | `42` |

The handler returns `false` to suppress AzerothCore's default `.ah` command handling (which requires GM privileges).

---

## Eluna Userdata Safety

Two plain `uint64` values are stored before the `CreateLuaEvent` closure is created:

```lua
local playerGUID   = player:GetGUID()   -- uint64, used by GetPlayerByGUID()
local creatureGUID = creature:GetGUID() -- uint64, used by GetWorldObject()
```

Eluna calls `InvalidateObjects()` after every event callback. Any `Player` or `Creature` userdata held in a closure will fail `IsValid()` when the timer fires. Plain `uint64` numbers survive across call stacks because they are plain Lua values, not C++ wrapper objects.

---

## Client Addon (DFP_AH)

**File:** `Interface/AddOns/DFP_AH/DFP_AH.lua`

```lua
SLASH_DFPAH1 = "/ah"
SlashCmdList["DFPAH"] = function()
    SendChatMessage(".ah", "SAY", nil, nil)
end
```

The DforgePanel AH button calls `SlashCmdList["DFPAH"]("")` directly rather than using `/ah` — this keeps the communication channel consistent and avoids the chat box opening.

**No AIO dependency.** The client sends a plain SAY chat message starting with `.` which AzerothCore routes to the dot-command handler.
