# DailyTasks — WoW 3.3.5a Client Addon

Displays and tracks server-assigned daily tasks in real time.
Works with the **DailyTasks server Lua module** (`lua_scripts/daily-tasks/`).

---

## What it does

When you log in, the server assigns you a set of daily tasks (kill creatures, complete dungeons, finish quests, etc.). This addon:

- Opens a movable window showing one card per task.
- Updates progress bars in real time as you earn credit — no manual refresh needed.
- Shows a tooltip with task details when you hover over a card.
- Flashes the window gold border and prints a streak count when all tasks are done.
- Resets automatically at midnight alongside the server.

---

## Installation

Copy the `DailyTasks/` folder into your WoW client's `Interface/AddOns/` directory:

```
World of Warcraft/
└── Interface/
    └── AddOns/
        └── DailyTasks/
            ├── DailyTasks.toc
            ├── DailyTasks.lua
            └── README.md
```

Enable **Daily Tasks** at the character select screen under **AddOns**.

The server module must also be installed. See [`lua_scripts/daily-tasks/README.md`](../../acore_source/env/dist/bin/lua_scripts/daily-tasks/README.md).

---

## Usage

| Command | Effect |
|---------|--------|
| `/dt` | Toggle the task window on/off; prints task list to chat |
| `/dt hide` | Hide the window |
| `/dt test` | Load three dummy tasks for visual testing (no server needed) |

The window opens automatically when the server pushes your tasks on login.
You can drag it anywhere — position is saved per character.

---

## How it works

The server sends addon messages with the prefix `DailyTasks` over a whisper-to-self channel. The addon listens for `CHAT_MSG_ADDON` and handles five message types:

| Message | Meaning |
|---------|---------|
| `TASK~id~type~name~progress~required~completed` | One task definition (sent on login/reset) |
| `TASKEND` | All tasks received — refresh UI and show window |
| `PROG~id~progress~required~completed` | A task's progress changed |
| `DONE~streak` | All tasks for today are complete |
| `RESET` | Midnight reset — clear tasks before new ones arrive |

The addon is **display-only**. It never writes data back to the server.

---

## Task types and colours

| Type | Label | Colour |
|------|-------|--------|
| Kill creature | KILL | Red |
| Dungeon | DUNGEON | Purple |
| Raid | RAID | Pink |
| Quest | QUEST | Yellow |
| Travel to zone | EXPLORE | Cyan |
| PvP kills | PVP | Orange |

---

## Files

| File | Purpose |
|------|---------|
| `DailyTasks.toc` | Addon metadata — interface version, saved variables declaration |
| `DailyTasks.lua` | All addon logic: frame creation, message handler, slash command |

---

## Compatibility

- **WoW client:** 3.3.5a (build 12340)
- **Interface:** 30300
- **SavedVariablesPerCharacter:** `DT_Settings` (stores window position)
- **Requires:** AzerothCore with mod-ale (Eluna) and the DailyTasks server module
