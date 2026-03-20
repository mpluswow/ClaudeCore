-- =============================================================================
-- Daily Tasks System — Database Installation
-- Module:   daily-tasks
-- File:     sql/install.sql
-- Database: claude_scripts
--
-- Run this file once to set up the database and all required tables.
-- Both the world DB connection and character DB connection need access to
-- claude_scripts. In a default AzerothCore install both connections use the
-- same MySQL user ('acore'@'localhost'), so one GRANT covers both.
--
-- Usage:
--   mysql -u root -p < install.sql
--
-- To uninstall:
--   DROP DATABASE IF EXISTS claude_scripts;  -- removes all custom module data
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Create database
-- ---------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS claude_scripts
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Grant access to the AzerothCore database user.
-- Replace 'acore'@'localhost' if your installation uses a different user.
-- Check your worldserver.conf: WorldDatabaseInfo / CharacterDatabaseInfo lines.
-- The format is: host;port;user;password;database — the 'user' field is what
-- you need here.
-- ---------------------------------------------------------------------------
GRANT ALL PRIVILEGES ON claude_scripts.* TO 'acore'@'localhost';
-- Uncomment if your server allows remote connections:
-- GRANT ALL PRIVILEGES ON claude_scripts.* TO 'acore'@'%';
FLUSH PRIVILEGES;

-- ---------------------------------------------------------------------------
-- Table: ds_task_pool
-- Purpose: Admin-managed pool of available daily task templates.
--          Populated manually (see sample_tasks.sql). The Lua script reads
--          this table to pick random tasks for players. It is never written
--          to at runtime — only by admins adding/disabling tasks.
--
-- Columns:
--   id                  Auto-increment primary key.
--   task_type           Numeric type constant:
--                         1 = kill_creature   (kill N creatures by entry ID)
--                         2 = complete_dungeon(kill boss Y while in map X)
--                         3 = complete_raid   (kill boss Y while in map X)
--                         4 = complete_quest  (complete quest by ID)
--                         5 = travel_zone     (enter zone or area by ID)
--                         6 = pvp_kills       (kill N players in PvP)
--   target_id           Primary target identifier:
--                         kill_creature   → creature_template.entry
--                         complete_dungeon→ instance_template.map (dungeon)
--                         complete_raid   → instance_template.map (raid)
--                         complete_quest  → quest_template.entry
--                         travel_zone     → zone or area ID (AreaTable.dbc)
--                         pvp_kills       → 0 (unused)
--   target_secondary_id For dungeon/raid only: the specific boss creature entry
--                       that must die to count as completion. 0 for all other
--                       task types.
--   display_name        Short name shown in the addon UI (e.g. "Slay Defias").
--   description         Longer description shown in the addon tooltip.
--   required_count      How many times the objective must be met:
--                         kill_creature   → number of kills needed
--                         dungeon/raid    → always 1 (boss must die once)
--                         quest           → always 1
--                         travel_zone     → always 1
--                         pvp_kills       → number of player kills
--   reward_gold         Copper to give on completion (0 = no gold reward).
--                       100 copper = 1 silver, 10000 copper = 1 gold.
--   reward_item_entry   item_template.entry to give (0 = no item reward).
--   reward_item_count   Stack size of item reward.
--   min_level           Player must be >= this level to receive the task.
--   max_level           Player must be <= this level to receive the task.
--   weight              Relative probability weight for random selection.
--                       Higher = selected more often. Default 100.
--   is_active           1 = included in random selection, 0 = disabled.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claude_scripts.ds_task_pool (
    id                  INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    task_type           TINYINT UNSIGNED  NOT NULL,
    target_id           INT UNSIGNED      NOT NULL DEFAULT 0,
    target_secondary_id INT UNSIGNED      NOT NULL DEFAULT 0,
    display_name        VARCHAR(100)      NOT NULL,
    description         VARCHAR(255)      NOT NULL DEFAULT '',
    required_count      SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    reward_gold         INT UNSIGNED      NOT NULL DEFAULT 0,
    reward_item_entry   INT UNSIGNED      NOT NULL DEFAULT 0,
    reward_item_count   TINYINT UNSIGNED  NOT NULL DEFAULT 1,
    min_level           TINYINT UNSIGNED  NOT NULL DEFAULT 1,
    max_level           TINYINT UNSIGNED  NOT NULL DEFAULT 80,
    weight              SMALLINT UNSIGNED NOT NULL DEFAULT 100,
    is_active           TINYINT UNSIGNED  NOT NULL DEFAULT 1,
    PRIMARY KEY (id),
    INDEX idx_active_level (is_active, min_level, max_level)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Daily task template pool (admin-managed)';

-- ---------------------------------------------------------------------------
-- Table: ds_player_daily
-- Purpose: Per-player task assignments for the current day.
--          Rows are deleted and re-inserted at each daily reset.
--          Key columns are cached from ds_task_pool at assignment time so
--          the event handlers never need to JOIN back to the pool on every
--          creature kill or zone change.
--
-- Columns:
--   guid                Character GUID (characters.guid).
--   task_id             Which pool entry was selected (ds_task_pool.id).
--   task_type           Cached from pool — avoids JOIN in hot event paths.
--   target_id           Cached from pool.
--   target_secondary_id Cached from pool.
--   display_name        Cached from pool.
--   description         Cached from pool.
--   required            Copied from pool.required_count at assignment time.
--   progress            Current progress counter. Never exceeds required.
--   completed           1 when progress >= required.
--   reward_given        1 after the reward was delivered (prevents double-give
--                       on reload or edge cases).
--   reward_gold         Cached from pool.
--   reward_item_entry   Cached from pool.
--   reward_item_count   Cached from pool.
--   assigned_date       Server date when tasks were assigned ("YYYY-MM-DD").
--                       Used by the reset logic to detect a new day.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claude_scripts.ds_player_daily (
    guid                INT UNSIGNED      NOT NULL,
    task_id             INT UNSIGNED      NOT NULL,
    task_type           TINYINT UNSIGNED  NOT NULL,
    target_id           INT UNSIGNED      NOT NULL DEFAULT 0,
    target_secondary_id INT UNSIGNED      NOT NULL DEFAULT 0,
    display_name        VARCHAR(100)      NOT NULL,
    description         VARCHAR(255)      NOT NULL DEFAULT '',
    required            SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    progress            SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    completed           TINYINT UNSIGNED  NOT NULL DEFAULT 0,
    reward_given        TINYINT UNSIGNED  NOT NULL DEFAULT 0,
    reward_gold         INT UNSIGNED      NOT NULL DEFAULT 0,
    reward_item_entry   INT UNSIGNED      NOT NULL DEFAULT 0,
    reward_item_count   TINYINT UNSIGNED  NOT NULL DEFAULT 1,
    assigned_date       DATE              NOT NULL,
    PRIMARY KEY (guid, task_id),
    INDEX idx_guid_date (guid, assigned_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Per-player daily task assignments and progress';

-- ---------------------------------------------------------------------------
-- Table: ds_player_meta
-- Purpose: Persistent per-player statistics across days.
--          Never deleted — accumulates over the player's lifetime.
--
-- Columns:
--   guid                    Character GUID.
--   streak                  Consecutive days on which ALL daily tasks were
--                           completed. Resets to 0 if a day is missed.
--   last_full_completion    Date of the last day all tasks were finished.
--                           NULL = never completed a full day.
--   total_completed         Lifetime count of individual tasks completed
--                           (not full days — individual task completions).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claude_scripts.ds_player_meta (
    guid                    INT UNSIGNED NOT NULL,
    streak                  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    last_full_completion    DATE DEFAULT NULL,
    total_completed         INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (guid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Per-player daily task lifetime statistics';
