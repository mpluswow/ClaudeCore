# Daily Tasks System

A daily task module for **AzerothCore 3.3.5a (WotLK)** using mod-ale (Eluna).
Players receive a random set of daily tasks each day. Progress is tracked server-side in real time and pushed to a client addon via `SendAddonMessage`.

---

## Table of Contents

1. [Architecture](#1-architecture)
2. [Installation](#2-installation)
3. [Configuration](#3-configuration)
4. [Task Types](#4-task-types)
5. [Database Schema](#5-database-schema)
6. [Server Script Reference](#6-server-script-reference)
7. [Message Protocol](#7-message-protocol)
8. [Client Addon Reference](#8-client-addon-reference)
9. [GM Commands](#9-gm-commands)
10. [Adding Tasks](#10-adding-tasks)
11. [Reset Behaviour](#11-reset-behaviour)
12. [Extending](#12-extending)

---

## 1. Architecture

```
Server (mod-ale / Eluna)                   Client (WoW addon)
───────────────────────────────            ──────────────────────────────
dfp-daily-server.lua                       Interface/AddOns/DFP_Daily/
  │                                          ├─ DFP_Daily.toc
  ├─ Event hooks                             └─ DFP_Daily.lua
  │    LOGIN → assign/load tasks                  │
  │    KILL_CREATURE → progress               ├─ CHAT_MSG_ADDON handler
  │    COMPLETE_QUEST → progress              │    TASK / TASKEND → build task list + show frame
  │    UPDATE_ZONE → progress                 │    PROG → update progress bar + progText
  │    KILL_PLAYER (PvP) → progress           │    DONE → flash gold border, print streak
  │    COMMAND (.dt reload) → reset           │    RESET → clear task list
  │                                           │
  ├─ DB: claude_scripts tables               ├─ DTFrame (main window)
  │    ds_task_pool        (pool)             │    Header: gold accent, title, [x] button
  │    ds_player_daily     (active)           │    Content: N section cards (one per task)
  │    ds_player_meta      (lifetime)         │
  │                                           └─ DTTooltip (custom, matches window style)
  └─ SendAddonMessage ────────────────────►        Hover any card → task details
       prefix = "DFP_Daily"
       type   = 6 (WHISPER to self)
```

**Design principles:**
- Server is authoritative — the addon is display-only and never writes back to the server.
- All hot-path event handlers read from an in-memory Lua cache (`dtCache`), never the DB.
- DB writes are async (`CharDBExecute`), DB reads only happen on login/assign.

---

## 2. Installation

### 2a. Database setup (run once)

```bash
mysql -u root -p < sql/install.sql
```

Creates the `claude_scripts` database and three tables.

```bash
mysql -u root -p < sql/sample_tasks.sql   # optional but recommended
```

Adds a starter pool of tasks across all level ranges.

### 2b. Server script

Place `dfp-daily-server.lua` and `dfp-daily-client.lua` (empty stub) inside:

```
worldserver/
└── lua_scripts/
    └── dfp-daily/
        ├── dfp-daily-server.lua   ← active server logic
        └── dfp-daily-client.lua   ← empty stub (required for folder completeness)
```

### 2c. WoW client addon

Copy the `DFP_Daily/` folder to the WoW client:

```
World of Warcraft/
└── Interface/
    └── AddOns/
        └── DFP_Daily/
            ├── DFP_Daily.toc
            └── DFP_Daily.lua
```

Enable the addon at the character select screen under **AddOns**.

### 2d. Restart worldserver

```
worldserver  (restart)
```

Or during development only:

```
.reload ale
```

---

## 3. Configuration

All configuration is at the top of `dfp-daily-server.lua`:

```lua
local DT_DB            = "claude_scripts"   -- database name
local DT_TASKS_PER_DAY = 3                  -- tasks assigned per player per day
local DT_PREFIX        = "DFP_Daily"        -- addon message prefix (max 16 chars)
```

`DT_PREFIX` must be identical in both `dfp-daily-server.lua` and `DFP_Daily.lua`. Do not change it unless you update both files.

---

## 4. Task Types

| Constant | Value | target_id | target_secondary_id | required_count |
|---|---|---|---|---|
| `TYPE_KILL_CREATURE` | 1 | `creature_template.entry` | 0 | Kill count |
| `TYPE_DUNGEON`       | 2 | Dungeon map ID | Final boss entry | 1 |
| `TYPE_RAID`          | 3 | Raid map ID    | Final boss entry | 1 |
| `TYPE_QUEST`         | 4 | `quest_template.entry` | 0 | 1 |
| `TYPE_TRAVEL_ZONE`   | 5 | Zone or area ID | 0 | 1 |
| `TYPE_PVP_KILLS`     | 6 | 0 (unused) | 0 | Kill count |

### Dungeon / Raid completion

Completion fires when the creature with `target_secondary_id` dies while the player is on the map with `target_id`. Pick the final boss as `target_secondary_id`. Group member kills also count because `PLAYER_EVENT_ON_KILL_CREATURE` fires for each player who receives kill credit.

### Finding valid IDs

```sql
-- Creature entry
SELECT entry, name, minlevel, maxlevel FROM acore_world.creature_template WHERE name LIKE '%Defias%';

-- Quest entry
SELECT entry, Title, MinLevel FROM acore_world.quest_template WHERE Title LIKE '%peon%';

-- Dungeon/raid map IDs
SELECT map FROM acore_world.instance_template ORDER BY map;
-- 33=SFK, 36=Deadmines, 189=SM Cathedral, 533=Naxxramas, 574=UK, 576=Nexus,
-- 599=HoS, 603=Ulduar, 604=Gun'Drak, 624=VoA, 649=ToC

-- Boss entry
SELECT entry, name FROM acore_world.creature_template WHERE name LIKE '%VanCleef%';

-- Zone/area IDs (in-game):
-- /run print(GetZoneText(), GetSubZoneText())
-- PLAYER_EVENT_ON_UPDATE_ZONE fires with (newZone, newArea); target_id matches either.
```

---

## 5. Database Schema

### `claude_scripts.ds_task_pool`

Admin-managed static template pool. Never modified at runtime.

| Column | Type | Description |
|--------|------|-------------|
| `id` | INT AUTO_INCREMENT PK | Pool row ID |
| `task_type` | TINYINT | Task type (1–6, see §4) |
| `target_id` | INT | Primary target (creature/quest/map/zone) |
| `target_secondary_id` | INT | Secondary target (boss entry for dungeons/raids) |
| `display_name` | VARCHAR(64) | Short name shown in client (≤ 64 chars) |
| `description` | VARCHAR(255) | Longer description (used in server messages) |
| `required_count` | INT | Progress units needed to complete |
| `reward_gold` | INT | Reward in copper (e.g. 10000 = 1 gold) |
| `reward_item_entry` | INT | Item entry to give (0 = none) |
| `reward_item_count` | INT | Item quantity |
| `min_level` | INT | Minimum player level |
| `max_level` | INT | Maximum player level |
| `weight` | INT | Relative selection weight (reserved; ORDER BY RAND() currently) |
| `is_active` | TINYINT | 1 = available for selection, 0 = disabled |

### `claude_scripts.ds_player_daily`

Per-player daily task assignments. Rows are deleted and recreated at each daily reset. Key columns are copied from `ds_task_pool` at assignment time so event handlers never need a JOIN on hot paths.

| Column | Type | Description |
|--------|------|-------------|
| `id` | INT AUTO_INCREMENT PK | Row ID |
| `guid` | INT | Player GUID (from `player:GetGUIDLow()`) |
| `task_id` | INT | Pool row `id` (the template this task came from) |
| `task_type` | TINYINT | Copied from pool |
| `target_id` | INT | Copied from pool |
| `target_secondary_id` | INT | Copied from pool |
| `display_name` | VARCHAR(64) | Copied from pool |
| `description` | VARCHAR(255) | Copied from pool |
| `required` | INT | Copied from pool's `required_count` |
| `progress` | INT | Current progress (updated by events) |
| `completed` | TINYINT | 1 when progress ≥ required |
| `reward_given` | TINYINT | 1 after reward has been delivered |
| `reward_gold` | INT | Copied from pool |
| `reward_item_entry` | INT | Copied from pool |
| `reward_item_count` | INT | Copied from pool |
| `assigned_date` | DATE | Date the row was created (used to detect offline resets) |

### `claude_scripts.ds_player_meta`

Per-player lifetime statistics. Never deleted.

| Column | Type | Description |
|--------|------|-------------|
| `guid` | INT PK | Player GUID |
| `streak` | INT | Consecutive days with full completion |
| `last_full_completion` | DATE | Last date all tasks were completed |
| `total_completed` | INT | Lifetime total completed task sets |

---

## 6. Server Script Reference

### In-memory cache

```lua
dtCache[guid] = {
    date  = "YYYY-MM-DD",   -- assigned_date
    tasks = {               -- array of task records
        {
            task_id             = <int>,
            task_type           = <int>,
            target_id           = <int>,
            target_secondary_id = <int>,
            display_name        = <string>,
            description         = <string>,
            required            = <int>,
            progress            = <int>,
            completed           = <bool>,
            reward_given        = <bool>,
            reward_gold         = <int>,
            reward_item_entry   = <int>,
            reward_item_count   = <int>,
        }, ...
    }
}
```

**Rule:** Never store `Player` or `Creature` C++ objects in the cache. They become invalid between event calls and cause crashes. Store only primitive Lua values.

### Function reference

| Function | Purpose |
|----------|---------|
| `dtToday()` | Returns `os.date("%Y-%m-%d")` — current server date string |
| `dtEscape(s)` | Escapes single quotes in strings for safe SQL interpolation |
| `dtLoad(guid)` | Reads today's rows for `guid` from DB into `dtCache`. Returns `tasks` array. |
| `dtAssign(player)` | Deletes existing rows for player, selects `DT_TASKS_PER_DAY` tasks from pool filtered by level, inserts new rows, populates cache. Returns `tasks` array. |
| `dtSaveProgress(guid, task)` | Async UPDATE of `progress`, `completed`, `reward_given` for one task row. |
| `dtUpdateMeta(guid)` | UPSERT into `ds_player_meta` — increments streak + total_completed. |
| `dtGetStreak(guid)` | SELECT streak from meta table; returns 1 if no row exists. |
| `dtGiveReward(player, task)` | Delivers gold + item reward; sets `task.reward_given = true`; calls `dtSaveProgress`. |
| `dtCheckAllComplete(player)` | Checks if every task in cache is completed; if so, calls `dtUpdateMeta` + `dtSendAllComplete`. |
| `dtIncrementProgress(player, task, amount)` | Adds `amount` to `task.progress`, clamps to `task.required`, saves, sends PROG message, delivers reward + checks completion if newly done. |
| `dtResetPlayer(player)` | Clears cache entry, sends RESET message, calls `dtAssign` + `dtSendInit`. |
| `dtSendInit(player)` | Sends one TASK message per cached task then TASKEND. |
| `dtSendProgress(player, task)` | Sends one PROG message for the given task. |
| `dtSendReset(player)` | Sends RESET message. |
| `dtSendAllComplete(player, streak)` | Sends DONE~streak message. |

### mod-ale event constants

mod-ale does **not** export Eluna event constants as Lua globals. Use raw numbers sourced from `mod-ale/src/LuaEngine/Hooks.h`:

| Constant | Value | Eluna event |
|----------|-------|-------------|
| `EV_LOGIN`          | 3  | `PLAYER_EVENT_ON_LOGIN` |
| `EV_LOGOUT`         | 4  | `PLAYER_EVENT_ON_LOGOUT` |
| `EV_KILL_PLAYER`    | 6  | `PLAYER_EVENT_ON_KILL_PLAYER` |
| `EV_KILL_CREATURE`  | 7  | `PLAYER_EVENT_ON_KILL_CREATURE` |
| `EV_UPDATE_ZONE`    | 27 | `PLAYER_EVENT_ON_UPDATE_ZONE` |
| `EV_COMPLETE_QUEST` | 54 | `PLAYER_EVENT_ON_COMPLETE_QUEST` |
| `EV_COMMAND`        | 42 | `PLAYER_EVENT_ON_COMMAND` |

### Registered events

| Event | Handler behaviour |
|-------|-------------------|
| `EV_LOGIN` | Check DB for today's tasks; load if present, assign if absent; call `dtSendInit`. |
| `EV_LOGOUT` | Remove player's cache entry (`dtCache[guid] = nil`). |
| `EV_KILL_CREATURE` | Match `killed:GetEntry()` and `player:GetMapId()` against `TYPE_KILL_CREATURE` / `TYPE_DUNGEON` / `TYPE_RAID` tasks. Increment progress if matched. |
| `EV_COMPLETE_QUEST` | Match `quest:GetEntry()` against `TYPE_QUEST` tasks. |
| `EV_UPDATE_ZONE` | Match `newZone` or `newArea` against `TYPE_TRAVEL_ZONE` tasks. |
| `EV_KILL_PLAYER` | Match any `TYPE_PVP_KILLS` task; increment by 1. |
| `EV_COMMAND` | Handle `.dt reload` for GMs only; calls `dtResetPlayer`. |

### Midnight reset timer

```lua
CreateLuaEvent(function()
    local currentDate = dtToday()
    if currentDate == dtLastDate then return end
    dtLastDate = currentDate
    -- iterate GetPlayersInWorld(), reset all non-GM online players
end, 60000, 0)   -- fires every 60 seconds, 0 = repeat forever
```

---

## 7. Message Protocol

All messages use prefix `DFP_Daily` and `~` as field separator.
Sent as: `player:SendAddonMessage("DFP_Daily", msg, 6, player)`
— type `6` = WHISPER to self; received by client as `CHAT_MSG_ADDON` with channel `"WHISPER"`.

| Message | Format | When sent |
|---------|--------|-----------|
| `TASK`    | `TASK~id~type~name~progress~required~completed` | Once per task during Init/Reset |
| `TASKEND` | `TASKEND` | After all TASK messages; triggers client UI refresh + show |
| `PROG`    | `PROG~id~progress~required~completed` | When a single task's progress changes |
| `DONE`    | `DONE~streak` | When all tasks for the day are complete |
| `RESET`   | `RESET` | At midnight before new TASK+TASKEND sequence |

Field types:
- `id` = `task_id` INT — unique per player per day
- `type` = task type INT (1–6)
- `name` = display_name STRING (may contain spaces; no `~`)
- `progress`, `required`, `completed` = INT (completed = 0 or 1)
- `streak` = INT

**255-byte message limit**: The `TASK` message is the longest. `display_name` is capped at 64 chars in the schema, keeping typical TASK messages well under 255 bytes. Do not put `~` characters in `display_name` or `description`.

---

## 8. Client Addon Reference

**File:** `Interface/AddOns/DFP_Daily/DFP_Daily.lua`
**Version:** 3.3.0
**Interface:** 30300 (WoW 3.3.5a build 12340)
**SavedVariablesPerCharacter:** `DT_Settings`

### Saved variables

```lua
DT_Settings = {
    x = nil,    -- TOPLEFT X offset from UIParent (nil = default position)
    y = nil,    -- TOPLEFT Y offset from UIParent
}
```

Position is saved on `OnDragStop` and restored on load.

### Task type constants (must match server)

```lua
TYPE_KILL    = 1
TYPE_DUNGEON = 2
TYPE_RAID    = 3
TYPE_QUEST   = 4
TYPE_TRAVEL  = 5
TYPE_PVP     = 6
```

### State variables

```lua
DT_Tasks    = {}   -- active task list (populated by TASKEND)
DT_Incoming = {}   -- accumulates TASK messages before TASKEND
DT_Streak   = 0    -- streak count from last DONE message
```

### Layout constants

```lua
W        = 290   -- main frame width (px)
BPAD     = 8     -- content padding inside tooltip border
HDR_H    = 26    -- header row height
SEC_H    = 66    -- task section card height
SEC_GAP  = 5     -- gap between cards
SEC_IPAD = 8     -- inner padding inside each card
BAR_H    = 12    -- progress bar height
MAX_TASKS= 5     -- maximum number of cards allocated
```

### Frame hierarchy

```
DTFrame  ("DTFrame", UIParent, MEDIUM strata)
  ├─ dtAccent      Texture  — gold left-edge header accent (WHITE8X8)
  ├─ dtTitle       FontString — "Daily Tasks  0/3"
  ├─ dtClose       Button — [x] close button (text-based, turns red on hover)
  ├─ dtSep         Texture — 1px separator beneath header (WHITE8X8)
  └─ dtContent     Frame — task card container (resizes with DT_Refresh)
       ├─ dtSections[1]  Frame (SEC_H=66px, tooltip backdrop)
       │    ├─ stripe     Texture (4px colored left stripe, WHITE8X8)
       │    ├─ typeLabel  FontString — "KILL" etc. (GameFontNormalSmall, top-left)
       │    ├─ progText   FontString — "3 / 5" (GameFontNormalSmall, top-right)
       │    ├─ nameText   FontString — task name (GameFontHighlight)
       │    ├─ barBG      Texture — dark bar track (UI-StatusBar at ~6% brightness)
       │    └─ bar        StatusBar — coloured progress fill (UI-StatusBar)
       ├─ dtSections[2]  ...
       └─ ...up to MAX_TASKS

DTTooltip  (nil, UIParent, TOOLTIP strata) — custom, shared backdrop
  ├─ ttStripe     Texture — coloured left stripe
  ├─ ttName       FontString — task name in gold (GameFontNormal)
  ├─ ttType       FontString — type label in type colour (GameFontNormalSmall)
  ├─ ttSep1       Texture — separator (WHITE8X8, gold tint)
  ├─ ttDesc       FontString — description text, word-wrapped (GameFontHighlightSmall)
  ├─ ttSep2       Texture — separator
  ├─ ttProg       FontString — "Progress: 3 / 5" or "Status: Complete!" (GameFontNormalSmall)
  └─ ttPct        FontString — "60% complete" or "" (GameFontHighlightSmall)
```

### Backdrop: SHARED_BACKDROP

Both `DTFrame`, each `dtSections[i]`, and `DTTooltip` use the same backdrop definition:

```lua
local SHARED_BACKDROP = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true,
    tileSize = 8,
    edgeSize = 10,
    insets   = { left=3, right=3, top=3, bottom=3 },
}
```

Background colors:
- Main frame: `SetBackdropColor(0.03, 0.02, 0.01, 0.97)` — slightly darker
- Section cards: `SetBackdropColor(0.06, 0.05, 0.04, 0.95)` — slightly lighter (depth effect)
- Tooltip: `SetBackdropColor(0.03, 0.02, 0.01, 0.97)` — matches main frame

Border colors:
- Main frame + tooltip: `SetBackdropBorderColor(0.50, 0.40, 0.16, 1)` — gold
- Incomplete card: `SetBackdropBorderColor(0.30, 0.25, 0.12, 0.9)` — dark brown
- Complete card: `SetBackdropBorderColor(0.18, 0.52, 0.18, 0.9)` — green

### Frame sizing

```lua
local function ContentH(n)   -- height of n task cards + gaps
    if n <= 0 then return 0 end
    return n * SEC_H + (n - 1) * SEC_GAP
end

local function FrameH(n)     -- total frame height for n tasks
    return BPAD + HDR_H + 7 + ContentH(n) + BPAD
    --     8  +  26  + 7 +    content   +  8
end
-- FrameH(0) = 49px  (header only)
-- FrameH(3) = 49 + 3*66 + 2*5 = 257px
```

`DT_Refresh()` calls `DTFrame:SetHeight(FrameH(count))` and `dtContent:SetHeight(ContentH(count))` on every update.

### DT_Refresh() behaviour

1. Iterates `DT_Tasks` up to `MAX_TASKS`.
2. For each task: shows card, sets stripe/label/name/bar colours and progress text.
3. Hides unused cards.
4. Updates header title with `done/count` in yellow (incomplete) or green (all done).
5. Resizes frame and content container.

**Completed task style:** green border, green stripe, desaturated green bar at 100%, "Complete!" progText.
**In-progress bar colour:** interpolates red → green as fraction increases (`r = max(0, 1-frac*2)`, `g = min(1, frac*2)`).

### Tooltip display (DTTooltip_Show)

Called from each card's `OnEnter` script:

```lua
sec:SetScript("OnEnter", function(self)
    local task = DT_Tasks[self.taskIndex]
    if task then DTTooltip_Show(self, task) end
end)
sec:SetScript("OnLeave", function() DTTooltip:Hide() end)
```

Tooltip anchors `LEFT` of itself to `RIGHT` of the hovered card with an 8px gap. `SetClampedToScreen(true)` keeps it on screen.

### [x] close button

A plain `Button` frame (not a template) with:
- `WHITE8X8` background texture, tinted dark brown at rest
- A `FontString` showing `"x"` in grey; turns red on `OnEnter`
- `OnClick` calls `DTFrame:Hide()`

> **Do not use `UI-Panel-HideButton-Up` for a close icon.** In the WoW 3.3.5a client this texture renders as a horizontal dash (same visual as the minimize button), not an X. Use a text-based button instead.

### Slash command

```
/dt          — toggle frame visibility; prints task list to chat if tasks loaded
/dt hide     — hide the frame
/dt test     — load three dummy tasks and show the frame (for visual testing)
```

### WoW 3.3.5a compatibility notes

| Issue | Detail |
|-------|--------|
| `RegisterAddonMessagePrefix` | Added in live patch 4.1; may be nil on some 3.3.5a private server builds. Always guard: `if RegisterAddonMessagePrefix then ... end`. Omitting the guard causes the entire addon file to fail loading. |
| `\x` hex escape sequences | Lua 5.2+ only. Use decimal escapes (`\195\151` for ×) or ASCII equivalents. Lua 5.1 (WoW 3.3.5a) silently misparsed `\xNN` in some builds and explicitly errored in others. |
| `Frame:SetShown(bool)` | Added in Cataclysm. Use explicit `Show()` / `Hide()` instead. |
| `UIPanelCloseButton` template | Uses `UI-Panel-MinimizeButton-Up` — a horizontal dash, not an X. |
| `GameTooltip` styling | Cannot be restyled to match custom frame backdrops; use a custom `Frame` with `SHARED_BACKDROP` instead for visual consistency. |

---

## 9. GM Commands

| Command | Effect |
|---------|--------|
| `.dt reload` | Clears cache + DB rows, assigns fresh tasks, sends RESET + new TASK/TASKEND sequence. Useful for testing without waiting for midnight. |

---

## 10. Adding Tasks

All tasks are rows in `claude_scripts.ds_task_pool`. Set `is_active = 0` to disable without deleting.

### Example inserts

```sql
-- Kill 5 Murlocs (entry 288), levels 1-15, reward 50 silver
INSERT INTO claude_scripts.ds_task_pool
    (task_type, target_id, display_name, description,
     required_count, reward_gold, min_level, max_level, weight)
VALUES (1, 288, 'Murloc Slayer', 'Slay 5 Murlocs along the coastlines.',
        5, 5000, 1, 15, 100);

-- Complete Deadmines (map 36, VanCleef entry 639)
INSERT INTO claude_scripts.ds_task_pool
    (task_type, target_id, target_secondary_id, display_name, description,
     required_count, reward_gold, min_level, max_level, weight)
VALUES (2, 36, 639, 'Deadmines: VanCleef', 'Defeat VanCleef in the Deadmines.',
        1, 10000, 15, 30, 100);

-- Complete quest "Lazy Peons" (entry 35)
INSERT INTO claude_scripts.ds_task_pool
    (task_type, target_id, display_name, description,
     required_count, reward_gold, min_level, max_level, weight)
VALUES (4, 35, 'Lazy Peons', 'Complete the Lazy Peons quest.',
        1, 2000, 1, 12, 100);

-- Travel to Icecrown (zone ID 210)
INSERT INTO claude_scripts.ds_task_pool
    (task_type, target_id, display_name, description,
     required_count, reward_gold, min_level, max_level, weight)
VALUES (5, 210, 'March to Icecrown', 'Travel to Icecrown.',
        1, 5000, 68, 80, 100);

-- Get 5 PvP kills, levels 10-80, reward 1 gold
INSERT INTO claude_scripts.ds_task_pool
    (task_type, target_id, display_name, description,
     required_count, reward_gold, min_level, max_level, weight)
VALUES (6, 0, 'Blood Sport', 'Earn 5 honorable kills.',
        5, 10000, 10, 80, 100);
```

---

## 11. Reset Behaviour

| Scenario | What happens |
|----------|-------------|
| Player logs in, tasks exist for today | `dtLoad` → `dtSendInit` (tasks pushed to client) |
| Player logs in, no tasks for today | `dtAssign` → `dtSendInit` (new tasks created and pushed) |
| Player is online at midnight | Timer detects date change → `dtResetPlayer` for all online non-GM players → RESET + new TASK/TASKEND |
| Player was offline at midnight | Detected at next login: `assigned_date` ≠ today → treated as no tasks for today → `dtAssign` |

---

## 12. Extending

### Adding a new task type

1. Add a new `TYPE_*` constant in **both** `dfp-daily-server.lua` and `DFP_Daily.lua` (values must match).
2. Add an event hook in `dfp-daily-server.lua` with a `RegisterPlayerEvent(EV_*, ...)` call.
3. Add colour (`hex`, `r`, `g`, `b`) and label entries to `DT_TYPES` in `DFP_Daily.lua`.
4. Add a description entry to `DT_TYPE_DESC` in `DFP_Daily.lua`.
5. Insert pool entries with the new `task_type` value.

### Adding a new reward type

Currently rewards are gold + one item type. To add more:
1. Add columns to `ds_task_pool` and `ds_player_daily`.
2. Add SELECT/INSERT fields in `dtAssign`.
3. Add delivery logic in `dtGiveReward`.

### Replacing the client UI

`DT_Refresh()` and `DTTooltip_Show()` are the only UI-specific functions. The data model (`DT_Tasks`, `DT_Incoming`, event handler) is UI-independent.

To replace the UI:
1. Keep the event handler, `DT_Split`, `DT_Print`, and the `DT_Tasks`/`DT_Incoming` state variables.
2. Remove or rewrite the frame construction blocks.
3. Rewrite `DT_Refresh()` with your custom frame logic.
4. Rewrite or remove `DTTooltip_Show()`.

---

## File Structure

```
lua_scripts/dfp-daily/
├── dfp-daily-server.lua    Server logic: events, DB, SendAddonMessage
├── dfp-daily-client.lua    Empty stub
├── README.md               This file
└── sql/
    ├── install.sql         DB + table creation (run once)
    └── sample_tasks.sql    Starter task pool

Interface/AddOns/DFP_Daily/
├── DFP_Daily.toc           Addon metadata (Interface: 30300, SavedVariablesPerCharacter: DT_Settings)
└── DFP_Daily.lua           UI frame, message handler, /dt slash command
```

---

## License

GPL v2 — same as AzerothCore and mod-ale.
