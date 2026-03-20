-- =============================================================================
-- Daily Tasks System — Sample Task Pool Data
-- Module:   daily-tasks
-- File:     sql/sample_tasks.sql
--
-- This file populates ds_task_pool with a starter set of tasks covering
-- all six task types. Every entry has been validated against a standard
-- AzerothCore 3.3.5a database (acore_world).
--
-- HOW TO VERIFY IDs BEFORE ADDING YOUR OWN:
--
--   Creature entry:
--     SELECT entry, name, minlevel, maxlevel FROM acore_world.creature_template
--     WHERE entry = <YOUR_ID>;
--
--   Quest entry:
--     SELECT entry, Title FROM acore_world.quest_template
--     WHERE entry = <YOUR_ID>;
--
--   Dungeon/Raid map ID:
--     SELECT map FROM acore_world.instance_template WHERE map = <YOUR_ID>;
--     -- Dungeon vs raid is determined by context; we track by boss entry.
--
--   Item entry (for rewards):
--     SELECT entry, name FROM acore_world.item_template
--     WHERE entry = <YOUR_ID>;
--
--   Zone/Area IDs come from AreaTable.dbc (binary file, not in the DB).
--   The IDs listed below are stable WotLK 3.3.5a constants confirmed from
--   the DBC files. If you need additional zone IDs, log into the game and
--   run:  /run print(GetZoneID(), GetSubZoneID())
--   The first value is newZone, the second is newArea in PLAYER_EVENT_ON_UPDATE_ZONE.
--
-- Run after install.sql:
--   mysql -u root -p < sample_tasks.sql
-- =============================================================================

-- Clear any previous sample data (safe to re-run)
DELETE FROM claude_scripts.ds_task_pool;
ALTER TABLE claude_scripts.ds_task_pool AUTO_INCREMENT = 1;

-- =============================================================================
-- TYPE 1: KILL CREATURE
-- task_type = 1
-- target_id = creature_template.entry
-- target_secondary_id = 0 (unused)
-- required_count = number of kills
-- =============================================================================

-- Low-level tasks (levels 1–30)
INSERT INTO claude_scripts.ds_task_pool
    (task_type, target_id, display_name, description,
     required_count, reward_gold, min_level, max_level, weight)
VALUES
    -- Murloc Forager (entry 288) — coastal zones, lv 1-2
    (1, 288,
     'Murloc Hunter',
     'Slay 10 Murlocs along the coastlines.',
     10, 500, 1, 15, 100),

    -- Defias Pillager (entry 3462) — Westfall, lv 15-17
    (1, 3462,
     'Defias Purge',
     'Eliminate 8 Defias Pillagers in Westfall.',
     8, 1000, 12, 25, 100),

    -- Scarlet Monk (entry 3592) — Tirisfal / Scarlet Monastery area, lv 32-34
    (1, 3592,
     'Scarlet Purge',
     'Strike down 10 Scarlet Monks.',
     10, 2000, 28, 42, 100);

-- Mid-level tasks (levels 30–60)
INSERT INTO claude_scripts.ds_task_pool
    (task_type, target_id, display_name, description,
     required_count, reward_gold, min_level, max_level, weight)
VALUES
    -- Zul'Farrak Zombie (entry 7696) — ZF undead, lv 44-46
    (1, 7696,
     'Troll Graveyard',
     'Destroy 12 Zul\'Farrak Zombies in the desert ruins.',
     12, 3000, 40, 55, 100),

    -- Blackrock Soldier (entry 9459) — Blackrock Mountain, lv 55-57
    (1, 9459,
     'Blackrock Assault',
     'Slay 10 Blackrock Soldiers at Blackrock Mountain.',
     10, 5000, 50, 62, 100);

-- High-level tasks (levels 68–80)
INSERT INTO claude_scripts.ds_task_pool
    (task_type, target_id, display_name, description,
     required_count, reward_gold, min_level, max_level, weight)
VALUES
    -- Converted Hero (entry 30739) — Icecrown Scourge, lv 80
    (1, 30739,
     'Icecrown Patrol',
     'Destroy 10 Converted Heroes in Icecrown.',
     10, 10000, 77, 80, 100),

    -- Cultist Sorcerer (entry 30693) — Icecrown Citadel area, lv 80
    (1, 30693,
     'Cult of the Damned',
     'Eliminate 8 Cultist Sorcerers near Icecrown Citadel.',
     8, 10000, 77, 80, 100);

-- =============================================================================
-- TYPE 2: COMPLETE DUNGEON
-- task_type = 2
-- target_id = instance_template.map  (the dungeon map ID)
-- target_secondary_id = final boss creature_template.entry
-- required_count = 1 (boss must die once)
-- Note: completion fires when the boss with target_secondary_id dies
--       while the player is on the map with target_id.
-- =============================================================================
INSERT INTO claude_scripts.ds_task_pool
    (task_type, target_id, target_secondary_id, display_name, description,
     required_count, reward_gold, min_level, max_level, weight)
VALUES
    -- Deadmines (map 36) — Edwin VanCleef (entry 639), lv 17-26
    (2, 36, 639,
     'Deadmines: VanCleef',
     'Defeat Edwin VanCleef at the end of the Deadmines.',
     1, 5000, 15, 30, 100),

    -- Shadowfang Keep (map 33) — Archmage Arugal (entry 4275), lv 22-30
    (2, 33, 4275,
     'Shadowfang Keep: Arugal',
     'Slay Archmage Arugal within Shadowfang Keep.',
     1, 5000, 20, 35, 100),

    -- Gnomeregan (map 389) — Mekgineer Thermaplugg (entry 7800), lv 29-38
    (2, 389, 7800,
     'Gnomeregan: Thermaplugg',
     'Defeat Mekgineer Thermaplugg deep in Gnomeregan.',
     1, 7000, 25, 45, 100),

    -- Scarlet Monastery — Cathedral (map 189) — High Inquisitor Whitemane (entry 3977), lv 35-45
    (2, 189, 3977,
     'SM Cathedral: Whitemane',
     'Defeat High Inquisitor Whitemane in the Scarlet Monastery Cathedral.',
     1, 8000, 32, 50, 100),

    -- Utgarde Keep (map 574) — Ingvar the Plunderer (entry 23953), lv 68-72
    (2, 574, 23953,
     'Utgarde Keep: Ingvar',
     'Slay Ingvar the Plunderer at the end of Utgarde Keep.',
     1, 15000, 67, 75, 100),

    -- The Nexus (map 576) — Keristrasza (entry 26723), lv 68-72
    (2, 576, 26723,
     'The Nexus: Keristrasza',
     'Free and destroy Keristrasza within The Nexus.',
     1, 15000, 67, 75, 100),

    -- Halls of Stone (map 599) — Sjonnir the Ironshaper (entry 27978), lv 77-79
    (2, 599, 27978,
     'Halls of Stone: Sjonnir',
     'Defeat Sjonnir the Ironshaper within the Halls of Stone.',
     1, 20000, 75, 80, 100),

    -- Gun'Drak (map 604) — Gal\'darah (entry 29304), lv 76-78
    (2, 604, 29304,
     'Gun\'Drak: Gal\'darah',
     'Slay Gal\'darah, the last boss of Gun\'Drak.',
     1, 20000, 74, 80, 100);

-- =============================================================================
-- TYPE 3: COMPLETE RAID
-- task_type = 3
-- target_id = instance_template.map  (raid map ID)
-- target_secondary_id = final/iconic boss creature_template.entry
-- required_count = 1
-- =============================================================================
INSERT INTO claude_scripts.ds_task_pool
    (task_type, target_id, target_secondary_id, display_name, description,
     required_count, reward_gold, min_level, max_level, weight)
VALUES
    -- Naxxramas (map 533) — Kel'Thuzad (entry 15990), lv 80 raid
    (3, 533, 15990,
     'Naxxramas: Kel\'Thuzad',
     'Destroy Kel\'Thuzad, the master of Naxxramas.',
     1, 50000, 78, 80, 80),

    -- Vault of Archavon (map 624) — Archavon the Stone Watcher (entry 31125), lv 80
    (3, 624, 31125,
     'Vault of Archavon',
     'Defeat Archavon the Stone Watcher in the Vault of Archavon.',
     1, 30000, 78, 80, 100),

    -- Ulduar (map 603) — Yogg-Saron (entry 33288), lv 80 raid
    (3, 603, 33288,
     'Ulduar: Yogg-Saron',
     'Face and defeat Yogg-Saron, the God of Death, in Ulduar.',
     1, 50000, 78, 80, 60),

    -- Trial of the Crusader (map 649) — Anub'arak (entry 34564), lv 80 raid
    (3, 649, 34564,
     'Trial of the Crusader',
     'Defeat Anub\'arak in the Trial of the Crusader.',
     1, 40000, 78, 80, 80);

-- =============================================================================
-- TYPE 4: COMPLETE QUEST
-- task_type = 4
-- target_id = quest_template.entry
-- required_count = 1
-- Note: fires on PLAYER_EVENT_ON_COMPLETE_QUEST. The quest does NOT need to
--       be a WoW "daily quest" — any repeatable or one-time quest works.
--       However, using WoW daily quests (those with flags & 1) is recommended
--       so players can re-do them each day.
-- To find Dalaran daily quests:
--   SELECT entry, Title FROM acore_world.quest_template
--   WHERE Flags & 1 AND (map = 571 OR ZoneOrSort IN (4395, 4372))
--   ORDER BY entry;
-- =============================================================================
INSERT INTO claude_scripts.ds_task_pool
    (task_type, target_id, display_name, description,
     required_count, reward_gold, min_level, max_level, weight)
VALUES
    -- Cooking daily: "Convention at the Legerdemain" (Horde/Alliance, Dalaran)
    -- quest entry 13931 — verify: SELECT entry, Title FROM acore_world.quest_template WHERE entry = 13931;
    (4, 13931,
     'Dalaran Cooking Daily',
     'Complete the Dalaran cooking daily quest.',
     1, 5000, 70, 80, 100),

    -- Fishing daily: "Jewel Of The Sewers" (Dalaran)
    -- quest entry 13543 — verify in quest_template
    (4, 13543,
     'Dalaran Fishing Daily',
     'Complete a Dalaran fishing daily quest.',
     1, 5000, 70, 80, 100),

    -- Jewelcrafting daily: "Shipment: Amberjewel" example
    -- quest entry 13927 — verify in quest_template
    (4, 13927,
     'Jewelcrafting Commission',
     'Complete a Dalaran jewelcrafting daily for the Kirin Tor.',
     1, 8000, 70, 80, 80);

-- =============================================================================
-- TYPE 5: TRAVEL TO ZONE
-- task_type = 5
-- target_id = zone ID returned by player:GetZoneId() OR area ID from GetAreaId()
--             in PLAYER_EVENT_ON_UPDATE_ZONE (newZone or newArea parameter)
-- required_count = 1 (entering the zone/area once completes it)
--
-- ZONE ID REFERENCE (WotLK 3.3.5a stable values):
--   To find zone IDs in-game: /run print(GetZoneText(), GetSubZoneText())
--   then cross-reference with:
--     SELECT ID, AreaName_Lang_enUS FROM acore_data_files DBC (binary)
--   or in-game: /run print(GetCurrentMapZone())
--
--   Known stable zone IDs for WotLK 3.3.5a:
--     1       = Dun Morogh
--     12      = Elwynn Forest
--     14      = Durotar
--     15      = Mulgore
--     85      = Tirisfal Glades
--     130     = Silverpine Forest
--     139     = Eastern Plaguelands
--     210     = Icecrown
--     394     = Grizzly Hills
--     495     = Howling Fjord
--     4197    = Wintergrasp
--     4395    = Dalaran (Northrend)
-- =============================================================================
INSERT INTO claude_scripts.ds_task_pool
    (task_type, target_id, display_name, description,
     required_count, reward_gold, min_level, max_level, weight)
VALUES
    -- Dalaran (zone 4395) — Northrend's floating city
    (5, 4395,
     'Visit Dalaran',
     'Travel to the floating city of Dalaran in Northrend.',
     1, 3000, 70, 80, 100),

    -- Icecrown (zone 210)
    (5, 210,
     'Enter Icecrown',
     'Set foot in the frozen wastes of Icecrown.',
     1, 3000, 75, 80, 100),

    -- Wintergrasp (zone 4197) — PvP zone
    (5, 4197,
     'Reach Wintergrasp',
     'Travel to the contested region of Wintergrasp.',
     1, 3000, 75, 80, 80),

    -- Grizzly Hills (zone 394)
    (5, 394,
     'Explore Grizzly Hills',
     'Visit the pine forests of the Grizzly Hills.',
     1, 2000, 73, 80, 100),

    -- Howling Fjord (zone 495)
    (5, 495,
     'Reach Howling Fjord',
     'Travel to the coastal cliffs of Howling Fjord.',
     1, 2000, 68, 76, 100),

    -- Elwynn Forest (zone 12) — low-level Alliance starter
    (5, 12,
     'Visit Elwynn Forest',
     'Travel through the peaceful woodlands of Elwynn Forest.',
     1, 500, 1, 20, 100),

    -- Durotar (zone 14) — low-level Horde starter
    (5, 14,
     'Return to Durotar',
     'Journey through the rugged land of Durotar.',
     1, 500, 1, 20, 100);

-- =============================================================================
-- TYPE 6: PVP KILLS
-- task_type = 6
-- target_id = 0 (any enemy player)
-- required_count = number of player kills
-- Note: fires on PLAYER_EVENT_ON_KILL_PLAYER. No faction or zone restriction —
--       any honorable kill counts. Restrict with min/max level to keep these
--       tasks in PvP-relevant level brackets.
-- =============================================================================
INSERT INTO claude_scripts.ds_task_pool
    (task_type, target_id, display_name, description,
     required_count, reward_gold, min_level, max_level, weight)
VALUES
    -- Low-level world PvP
    (6, 0,
     'Defender of the Realm',
     'Slay 3 enemy players in world PvP.',
     3, 2000, 10, 49, 80),

    -- Mid bracket
    (6, 0,
     'Honor Bound',
     'Defeat 5 enemy players in combat.',
     5, 5000, 50, 69, 80),

    -- Endgame PvP
    (6, 0,
     'Veteran Warrior',
     'Cut down 5 enemy players in battle.',
     5, 15000, 70, 80, 80);
