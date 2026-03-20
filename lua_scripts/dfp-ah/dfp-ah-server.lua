-- =============================================================================
-- dfp-ah-server.lua  v1.1.0
-- DforgePanel — Auction House server module
--
-- Handles ".ah" command from any player.
-- Spawns a temporary auctioneer at the player's feet (one per player).
-- If the player already has an active auctioneer, reuses it instead of
-- spawning a new one — prevents NPC flooding from button spam or many players.
--
-- Why visible-first:
--   Setting display 11686 (invisible stalker) before the map tick caused the
--   client to receive a creature it treats as non-interactive, silently dropping
--   follow-up CMSGs.  With the real model the client registers the GUID
--   correctly.  Creature stays visible for the full AH session.
--
-- Trigger: player types ".ah" (dot command, works for all players when
--   AllowPlayerCommands = 1 in worldserver.conf).
--   Client-side: /ah slash command in DFP_AH addon sends ".ah" via SAY.
-- =============================================================================

-- ┌─────────────────────────────────────────────────────┐
-- │  CONFIGURATION                                       │
-- └─────────────────────────────────────────────────────┘

-- Alliance: entry 8719 (Auctioneer Fitch, faction 12 = Stormwind)
-- Horde:    entry 8673 (Auctioneer Thathung, faction 29 = Orgrimmar)
local ENTRY_AUCTIONEER_ALLIANCE = 8719
local ENTRY_AUCTIONEER_HORDE    = 8673

-- How long the creature stays alive (covers a full AH session).
local AH_DESPAWN_MS = 300000  -- 5 minutes

-- ┌─────────────────────────────────────────────────────┐
-- │  CONSTANTS  (do not edit)                            │
-- └─────────────────────────────────────────────────────┘

local UNIT_NPC_FLAG_AUCTIONEER = 0x200000  -- 2097152
local TEMPSUMMON_TIMED_DESPAWN = 3

-- NON_ATTACKABLE(2) + IMMUNE_TO_PC(256) + IMMUNE_TO_NPC(512)
local FLAGS_PASSIVE = 2 + 256 + 512

local EV_COMMAND = 42  -- PLAYER_EVENT_ON_COMMAND

-- ┌─────────────────────────────────────────────────────┐
-- │  STATE                                               │
-- └─────────────────────────────────────────────────────┘

-- Maps playerGUID (uint64) → creatureGUID (uint64).
-- Cleared lazily when GetWorldObject returns nil (creature despawned).
local playerAuctioneer = {}

-- ┌─────────────────────────────────────────────────────┐
-- │  COMMAND HANDLER                                     │
-- └─────────────────────────────────────────────────────┘

RegisterPlayerEvent(EV_COMMAND, function(event, player, command)
    if command ~= "ah" then return end

    local playerGUID = player:GetGUID()
    local playerKey  = tostring(playerGUID)  -- uint64 userdata can't be used as table key

    -- Reuse existing auctioneer if still on the map.
    local existingGUID = playerAuctioneer[playerKey]
    if existingGUID then
        local c = player:GetMap():GetWorldObject(existingGUID)
        if c then
            pcall(function() player:SendAuctionMenu(c) end)
            return false
        end
        -- Creature gone — clear stale entry and fall through to spawn.
        playerAuctioneer[playerKey] = nil
    end

    -- Spawn a new faction-correct auctioneer at the player's position.
    local x, y, z, o = player:GetX(), player:GetY(), player:GetZ(), player:GetO()
    local entry = (player:GetTeam() == 1) and ENTRY_AUCTIONEER_HORDE
                                           or ENTRY_AUCTIONEER_ALLIANCE

    local creature = player:SpawnCreature(entry, x, y, z, o,
                                          TEMPSUMMON_TIMED_DESPAWN, AH_DESPAWN_MS)
    if not creature then
        player:SendBroadcastMessage("|cffff4444[Dreamforge] Could not open Auction House.|r")
        return false
    end

    -- Keep it out of combat; leave it visible and selectable for the full session.
    creature:SetNPCFlags(UNIT_NPC_FLAG_AUCTIONEER)
    creature:SetUnitFlags(FLAGS_PASSIVE)
    creature:SetReactState(0)

    -- Store plain GUIDs — Eluna invalidates userdata after every event callback
    -- (InvalidateObjects bumps callstackid), so captured userdata would fail
    -- IsValid() in the timer.  Plain numbers survive across call stacks.
    local creatureGUID = creature:GetGUID()
    playerAuctioneer[playerKey] = creatureGUID

    -- Defer SendAuctionMenu by 200 ms so the client has processed
    -- SMSG_UPDATE_OBJECT (CREATE) before MSG_AUCTION_HELLO arrives.
    CreateLuaEvent(function(id, delay, calls, obj)
        local p = GetPlayerByGUID(playerGUID)
        if not p then return end
        local c = p:GetMap():GetWorldObject(creatureGUID)
        if not c then
            playerAuctioneer[playerKey] = nil
            return
        end
        pcall(function() p:SendAuctionMenu(c) end)
    end, 200, 1)

    return false  -- suppress default ".ah" handling
end)
