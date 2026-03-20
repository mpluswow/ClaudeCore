-- =============================================================================
-- DFP Daily — Server Script
-- Module:   dfp-daily
-- File:     dfp-daily-server.lua
-- Version:  2.0.0
--
-- Overview:
--   Server-side game logic for the daily task system. Communicates with the
--   WoW client addon (Interface/AddOns/DFP_Daily/) via SendAddonMessage.
--   No AIO dependency — uses direct addon messaging (WHISPER to self).
--
-- Communication protocol:
--   Server → Client via:  player:SendAddonMessage(PREFIX, msg, 6, player)
--   Message format:       "MSGTYPE~field1~field2~..."
--   Separator:            "~" (tilde)
--
--   Message types sent to client:
--     TASK~id~type~name~progress~required~completed
--       Sent once per task during Init. Multiple TASK messages = full task list.
--     TASKEND
--       Signals that all TASK messages for the current Init have been sent.
--     PROG~id~progress~required~completed
--       Sent when a single task's progress changes.
--     DONE~streak
--       Sent when all tasks for the day are complete.
--     RESET
--       Sent at midnight reset before the new TASK+TASKEND sequence.
--
-- Dependencies:
--   - mod-ale (AzerothCore Lua Engine)
--   - claude_scripts database (see sql/install.sql)
-- =============================================================================

-- =============================================================================
-- CONFIGURATION
-- =============================================================================
local DT_DB            = "claude_scripts"
local DT_TASKS_PER_DAY = 3
local DT_PREFIX        = "DFP_Daily"    -- Must match DT_PREFIX in DFP_Daily.lua client addon
local DT_MAX_LEVEL     = 80             -- Highest level supported by the task pool (WotLK cap)

-- Task type constants (must match ds_task_pool.task_type values)
local TYPE_KILL_CREATURE = 1
local TYPE_DUNGEON       = 2
local TYPE_RAID          = 3
local TYPE_QUEST         = 4
local TYPE_TRAVEL_ZONE   = 5
local TYPE_PVP_KILLS     = 6

-- =============================================================================
-- mod-ale PLAYER EVENT CONSTANTS
-- mod-ale does not register Eluna event constants as Lua globals.
-- Raw enum values from mod-ale/src/LuaEngine/Hooks.h:
-- =============================================================================
local EV_LOGIN         = 3   -- PLAYER_EVENT_ON_LOGIN
local EV_LOGOUT        = 4   -- PLAYER_EVENT_ON_LOGOUT
local EV_KILL_PLAYER   = 6   -- PLAYER_EVENT_ON_KILL_PLAYER
local EV_KILL_CREATURE = 7   -- PLAYER_EVENT_ON_KILL_CREATURE
local EV_UPDATE_ZONE   = 27  -- PLAYER_EVENT_ON_UPDATE_ZONE
local EV_COMPLETE_QUEST= 54  -- PLAYER_EVENT_ON_COMPLETE_QUEST
local EV_COMMAND       = 42  -- PLAYER_EVENT_ON_COMMAND

-- =============================================================================
-- IN-MEMORY CACHE
-- =============================================================================
-- dtCache[guid] = { date="YYYY-MM-DD", tasks={ {task fields...}, ... } }
-- Never store Player/Creature C++ objects here — only plain Lua values.
local dtCache = {}

-- =============================================================================
-- HELPERS
-- =============================================================================

local function dtToday()
    return os.date("%Y-%m-%d")
end

local function dtEscape(s)
    return tostring(s):gsub("'", "''")
end

-- =============================================================================
-- SEND HELPERS
-- player:SendAddonMessage(prefix, msg, type, receiver)
--   prefix   = addon identifier string (max 16 chars)
--   msg      = payload string (max 255 bytes)
--   type     = 6 (CHAT_MSG_WHISPER — sends privately to the player from themselves)
--   receiver = the same player object
-- The WoW client receives this as CHAT_MSG_ADDON with type "WHISPER".
-- =============================================================================

-- Send one TASK line per task, then TASKEND.
local function dtSendInit(player)
    local guid = player:GetGUIDLow()
    local c    = dtCache[guid]
    if not c then return end

    for _, t in ipairs(c.tasks) do
        local msg = string.format("TASK~%d~%d~%s~%d~%d~%d",
            t.task_id,
            t.task_type,
            t.display_name,
            t.progress,
            t.required,
            t.completed and 1 or 0
        )
        player:SendAddonMessage(DT_PREFIX, msg, 6, player)
    end

    player:SendAddonMessage(DT_PREFIX, "TASKEND", 6, player)
end

-- Send a single progress update.
local function dtSendProgress(player, task)
    local msg = string.format("PROG~%d~%d~%d~%d",
        task.task_id,
        task.progress,
        task.required,
        task.completed and 1 or 0
    )
    player:SendAddonMessage(DT_PREFIX, msg, 6, player)
end

-- Notify client of midnight reset before sending new tasks.
local function dtSendReset(player)
    player:SendAddonMessage(DT_PREFIX, "RESET", 6, player)
end

-- Notify client that all tasks for the day are done.
local function dtSendAllComplete(player, streak)
    local msg = string.format("DONE~%d", streak)
    player:SendAddonMessage(DT_PREFIX, msg, 6, player)
end

-- =============================================================================
-- DATABASE: LOAD
-- =============================================================================
local function dtLoad(guid)
    local today = dtToday()
    local sql = string.format(
        "SELECT task_id, task_type, target_id, target_secondary_id, "..
        "display_name, description, required, progress, completed, "..
        "reward_given, reward_gold, reward_item_entry, reward_item_count "..
        "FROM %s.ds_player_daily "..
        "WHERE guid = %d AND assigned_date = '%s'",
        DT_DB, guid, today
    )

    local result = CharDBQuery(sql)
    local tasks  = {}

    if result then
        repeat
            local task = {
                task_id             = result:GetUInt32(0),
                task_type           = result:GetUInt32(1),
                target_id           = result:GetUInt32(2),
                target_secondary_id = result:GetUInt32(3),
                display_name        = result:GetString(4),
                description         = result:GetString(5),
                required            = result:GetUInt32(6),
                progress            = result:GetUInt32(7),
                completed           = result:GetUInt32(8) == 1,
                reward_given        = result:GetUInt32(9) == 1,
                reward_gold         = result:GetUInt32(10),
                reward_item_entry   = result:GetUInt32(11),
                reward_item_count   = result:GetUInt32(12),
            }
            tasks[#tasks + 1] = task
        until not result:NextRow()
    end

    dtCache[guid] = { date = today, tasks = tasks }
    return tasks
end

-- =============================================================================
-- DATABASE: ASSIGN
-- =============================================================================
local function dtAssign(player)
    local guid  = player:GetGUIDLow()
    local level = player:GetLevel()
    local today = dtToday()

    -- Clamp to the highest level the task pool supports.
    -- Players above DT_MAX_LEVEL (e.g. level 81 on a custom server) would
    -- match no tasks if the pool only has entries up to max_level = 80.
    local effectiveLevel = math.min(level, DT_MAX_LEVEL)

    local sql = string.format(
        "SELECT id, task_type, target_id, target_secondary_id, "..
        "display_name, description, required_count, "..
        "reward_gold, reward_item_entry, reward_item_count "..
        "FROM %s.ds_task_pool "..
        "WHERE is_active = 1 AND min_level <= %d AND max_level >= %d "..
        "ORDER BY RAND() LIMIT %d",
        DT_DB, effectiveLevel, effectiveLevel, DT_TASKS_PER_DAY
    )

    local result = WorldDBQuery(sql)

    -- Only wipe the player's existing rows once we know new ones are coming.
    -- If the pool query returns nothing (e.g. empty pool, wrong levels),
    -- the player keeps their current tasks rather than ending up with nothing.
    if not result then
        PrintInfo("[DFP Daily] WARNING: task pool returned 0 rows for level "
            .. effectiveLevel .. " (guid=" .. guid .. "). Keeping existing tasks.")
        dtCache[guid] = dtCache[guid] or { date = today, tasks = {} }
        return dtCache[guid].tasks
    end

    CharDBExecute(string.format(
        "DELETE FROM %s.ds_player_daily WHERE guid = %d",
        DT_DB, guid
    ))

    local tasks  = {}

    repeat
        local pool_id    = result:GetUInt32(0)
        local ttype      = result:GetUInt32(1)
        local target_id  = result:GetUInt32(2)
        local target_sec = result:GetUInt32(3)
        local name       = result:GetString(4)
        local desc       = result:GetString(5)
        local req        = result:GetUInt32(6)
        local rgold      = result:GetUInt32(7)
        local ritem      = result:GetUInt32(8)
        local rcount     = result:GetUInt32(9)

        CharDBExecute(string.format(
            "INSERT INTO %s.ds_player_daily "..
            "(guid, task_id, task_type, target_id, target_secondary_id, "..
            "display_name, description, required, progress, completed, "..
            "reward_given, reward_gold, reward_item_entry, reward_item_count, assigned_date) "..
            "VALUES (%d, %d, %d, %d, %d, '%s', '%s', %d, 0, 0, 0, %d, %d, %d, '%s')",
            DT_DB,
            guid, pool_id, ttype, target_id, target_sec,
            dtEscape(name), dtEscape(desc), req,
            rgold, ritem, rcount, today
        ))

        tasks[#tasks + 1] = {
            task_id             = pool_id,
            task_type           = ttype,
            target_id           = target_id,
            target_secondary_id = target_sec,
            display_name        = name,
            description         = desc,
            required            = req,
            progress            = 0,
            completed           = false,
            reward_given        = false,
            reward_gold         = rgold,
            reward_item_entry   = ritem,
            reward_item_count   = rcount,
        }
    until not result:NextRow()

    dtCache[guid] = { date = today, tasks = tasks }
    return tasks
end

-- =============================================================================
-- DATABASE: SAVE PROGRESS (async)
-- =============================================================================
local function dtSaveProgress(guid, task)
    CharDBExecute(string.format(
        "UPDATE %s.ds_player_daily "..
        "SET progress = %d, completed = %d, reward_given = %d "..
        "WHERE guid = %d AND task_id = %d",
        DT_DB,
        task.progress,
        task.completed   and 1 or 0,
        task.reward_given and 1 or 0,
        guid, task.task_id
    ))
end

-- =============================================================================
-- DATABASE: UPDATE META
-- =============================================================================
local function dtUpdateMeta(guid)
    CharDBExecute(string.format(
        "INSERT INTO %s.ds_player_meta (guid, streak, last_full_completion, total_completed) "..
        "VALUES (%d, 1, '%s', 1) "..
        "ON DUPLICATE KEY UPDATE "..
        "streak = streak + 1, "..
        "last_full_completion = VALUES(last_full_completion), "..
        "total_completed = total_completed + 1",
        DT_DB, guid, dtToday()
    ))
end

local function dtGetStreak(guid)
    local result = CharDBQuery(string.format(
        "SELECT streak FROM %s.ds_player_meta WHERE guid = %d",
        DT_DB, guid
    ))
    return (result and result:GetUInt32(0)) or 1
end

-- =============================================================================
-- REWARD DELIVERY
-- =============================================================================
local function dtGiveReward(player, task)
    if task.reward_given then return end
    task.reward_given = true

    if task.reward_gold > 0 then
        player:ModifyMoney(task.reward_gold)
    end
    if task.reward_item_entry > 0 then
        player:AddItem(task.reward_item_entry, task.reward_item_count)
    end

    dtSaveProgress(player:GetGUIDLow(), task)
    player:SendBroadcastMessage(string.format(
        "|cff00ff00[Daily Tasks]|r Complete: %s", task.display_name
    ))
end

local function dtCheckAllComplete(player)
    local guid = player:GetGUIDLow()
    local c = dtCache[guid]
    if not c or #c.tasks == 0 then return end

    for _, t in ipairs(c.tasks) do
        if not t.completed then return end
    end

    dtUpdateMeta(guid)
    local streak = dtGetStreak(guid)
    player:SendBroadcastMessage(string.format(
        "|cff00ff00[Daily Tasks]|r All tasks complete! Streak: %d day(s).", streak
    ))
    dtSendAllComplete(player, streak)
end

-- =============================================================================
-- PROGRESS INCREMENT
-- =============================================================================
local function dtIncrementProgress(player, task, amount)
    if task.completed then return end

    task.progress = task.progress + amount
    if task.progress >= task.required then
        task.progress  = task.required
        task.completed = true
    end

    dtSaveProgress(player:GetGUIDLow(), task)
    dtSendProgress(player, task)

    if task.completed then
        dtGiveReward(player, task)
        dtCheckAllComplete(player)
    end
end

-- =============================================================================
-- DAILY RESET
-- =============================================================================
local function dtResetPlayer(player)
    local guid = player:GetGUIDLow()
    dtCache[guid] = nil
    dtSendReset(player)
    dtAssign(player)
    dtSendInit(player)
end

-- =============================================================================
-- EVENT: PLAYER LOGIN
-- =============================================================================
RegisterPlayerEvent(EV_LOGIN, function(event, player)
    local guid  = player:GetGUIDLow()
    local level = player:GetLevel()
    local today = dtToday()
    PrintInfo("[DFP Daily] LOGIN guid=" .. guid .. " level=" .. level .. " date=" .. today)

    local check = CharDBQuery(string.format(
        "SELECT COUNT(*) FROM %s.ds_player_daily WHERE guid = %d AND assigned_date = '%s'",
        DT_DB, guid, today
    ))

    local count = check and check:GetUInt32(0) or 0
    PrintInfo("[DFP Daily] existing tasks count=" .. count)

    if count > 0 then
        dtLoad(guid)
        PrintInfo("[DFP Daily] loaded from DB")
    else
        dtAssign(player)
        local c = dtCache[guid]
        PrintInfo("[DFP Daily] assigned " .. (c and #c.tasks or 0) .. " tasks")
    end

    dtSendInit(player)
    PrintInfo("[DFP Daily] dtSendInit called")
end)

-- =============================================================================
-- EVENT: PLAYER LOGOUT
-- =============================================================================
RegisterPlayerEvent(EV_LOGOUT, function(event, player)
    dtCache[player:GetGUIDLow()] = nil
end)

-- =============================================================================
-- EVENT: CREATURE KILL
-- =============================================================================
RegisterPlayerEvent(EV_KILL_CREATURE, function(event, player, killed)
    local guid  = player:GetGUIDLow()
    local c     = dtCache[guid]
    if not c then return end

    local killedEntry = killed:GetEntry()
    local mapId       = player:GetMapId()

    for _, task in ipairs(c.tasks) do
        if not task.completed then
            if task.task_type == TYPE_KILL_CREATURE
            and killedEntry == task.target_id then
                dtIncrementProgress(player, task, 1)

            elseif task.task_type == TYPE_DUNGEON
            and mapId       == task.target_id
            and killedEntry == task.target_secondary_id then
                dtIncrementProgress(player, task, task.required)

            elseif task.task_type == TYPE_RAID
            and mapId       == task.target_id
            and killedEntry == task.target_secondary_id then
                dtIncrementProgress(player, task, task.required)
            end
        end
    end
end)

-- =============================================================================
-- EVENT: QUEST COMPLETE
-- =============================================================================
RegisterPlayerEvent(EV_COMPLETE_QUEST, function(event, player, quest)
    local guid = player:GetGUIDLow()
    local c    = dtCache[guid]
    if not c then return end

    local questEntry = quest:GetEntry()

    for _, task in ipairs(c.tasks) do
        if not task.completed
        and task.task_type == TYPE_QUEST
        and questEntry == task.target_id then
            dtIncrementProgress(player, task, 1)
        end
    end
end)

-- =============================================================================
-- EVENT: ZONE UPDATE
-- =============================================================================
RegisterPlayerEvent(EV_UPDATE_ZONE, function(event, player, newZone, newArea)
    local guid = player:GetGUIDLow()
    local c    = dtCache[guid]
    if not c then return end

    for _, task in ipairs(c.tasks) do
        if not task.completed
        and task.task_type == TYPE_TRAVEL_ZONE
        and (newZone == task.target_id or newArea == task.target_id) then
            dtIncrementProgress(player, task, 1)
        end
    end
end)

-- =============================================================================
-- EVENT: PVP KILL
-- =============================================================================
RegisterPlayerEvent(EV_KILL_PLAYER, function(event, player, killed)
    local guid = player:GetGUIDLow()
    local c    = dtCache[guid]
    if not c then return end

    for _, task in ipairs(c.tasks) do
        if not task.completed
        and task.task_type == TYPE_PVP_KILLS then
            dtIncrementProgress(player, task, 1)
        end
    end
end)

-- =============================================================================
-- MIDNIGHT RESET TIMER
-- =============================================================================
local dtLastDate = dtToday()

CreateLuaEvent(function()
    local currentDate = dtToday()
    if currentDate == dtLastDate then return end

    dtLastDate = currentDate
    PrintInfo("[DFP Daily] Date rollover — resetting online players.")

    local players = GetPlayersInWorld()
    if players then
        for _, player in ipairs(players) do
            if player and player:IsInWorld() and not player:IsGM() then
                dtResetPlayer(player)
            end
        end
    end
end, 60000, 0)

-- =============================================================================
-- GM COMMAND: .dt reload
-- =============================================================================
RegisterPlayerEvent(EV_COMMAND, function(event, player, command)
    if command ~= "dt reload" then return end
    if not player:IsGM() then return end
    dtResetPlayer(player)
    player:SendBroadcastMessage("[DFP Daily] Tasks reloaded.")
    return false
end)

PrintInfo("[DFP Daily] Server v2.0 loaded. DB=" .. DT_DB .. ", Tasks/day=" .. DT_TASKS_PER_DAY)
