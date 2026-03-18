# AzerothCore Database Schema

**Master reference for the three-database architecture of AzerothCore (WoW 3.3.5a / WotLK build 12340)**

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [acore_auth Database](#acore_auth-database)
3. [acore_characters Database](#acore_characters-database)
4. [acore_world Database](#acore_world-database)
   - [Creature Tables](#creature-tables)
   - [GameObject Tables](#gameobject-tables)
   - [Item Tables](#item-tables)
   - [Quest Tables](#quest-tables)
   - [NPC Service Tables](#npc-service-tables)
   - [Loot Tables](#loot-tables)
   - [Scripting Tables](#scripting-tables)
   - [Waypoint Tables](#waypoint-tables)
   - [Spell Override Tables](#spell-override-tables)
   - [Map and Instance Tables](#map-and-instance-tables)
   - [Event Tables](#event-tables)
   - [Conditions System](#conditions-system)
   - [Achievement Tables](#achievement-tables)
   - [Player Creation Tables](#player-creation-tables)
   - [Miscellaneous World Tables](#miscellaneous-world-tables)
5. [Custom Project Data (dreamforge_ prefix)](#custom-project-data-dreamforge_-prefix)
6. [Database Modification Best Practices](#database-modification-best-practices)
7. [Key Relationships and Foreign Keys](#key-relationships-and-foreign-keys)
8. [Reload Commands Reference](#reload-commands-reference)
9. [Cross-References](#cross-references)

---

## Architecture Overview

AzerothCore uses three separate MySQL databases. The worldserver process connects to all three; the authserver connects only to `acore_auth`.

| Database | Primary Role | Connected By |
|---|---|---|
| `acore_auth` | Account management, realm listing, authentication | authserver, worldserver |
| `acore_characters` | All live character state: inventory, quests, skills, mail, guilds | worldserver |
| `acore_world` | Static game data: creature/item/quest definitions, spawns, scripts | worldserver |

**Connection flow:**
1. Client authenticates against `authserver` → `acore_auth.account` is checked.
2. Client selects a realm → `acore_auth.realmlist` provides connection info.
3. Client enters world → `worldserver` loads static data from `acore_world`, reads/writes character state to `acore_characters`.

**Custom project data:** Dreamforge tables use a `dreamforge_` prefix inside `acore_world`. No separate database — see the [Custom Project Data](#custom-project-data-dreamforge_-prefix) section below.

---

## acore_auth Database

Stores authentication, account management, and realm configuration. Typically accessed at `localhost:3306`, database name `acore_auth`.

### Table Inventory

| Table | Purpose |
|---|---|
| `account` | Player accounts: credentials, email, expansion, locale |
| `account_access` | GM permission levels per realm per account |
| `account_banned` | Active and historical account ban records |
| `account_muted` | Mute records with expiry and reason |
| `acore_cms_subscriptions` | CMS/website integration subscription data |
| `autobroadcast` | Server-wide broadcast messages sent on a timer |
| `autobroadcast_locale` | Locale overrides for autobroadcast text |
| `build_info` | Client build number metadata |
| `crq_clients` | Cross-realm queue: connected client registry |
| `crq_content` | CRQ: queued content definitions |
| `crq_group_members` | CRQ: group member records |
| `crq_groups` | CRQ: group records |
| `crq_lfg_groups` | CRQ: LFG group state |
| `crq_lfg_members` | CRQ: LFG member state |
| `crq_lfg_notifications` | CRQ: LFG pending notifications |
| `crq_lfg_queue` | CRQ: LFG queue entries |
| `crq_members` | CRQ: member records |
| `crq_notifications` | CRQ: pending notifications |
| `crq_queue` | CRQ: general queue entries |
| `ip_banned` | IP address ban records |
| `logs` | General server logs |
| `logs_ip_actions` | IP-specific action history |
| `motd` | Message of the Day displayed at login |
| `motd_localized` | Locale-specific MOTD overrides |
| `realmcharacters` | Character count per account per realm |
| `realmlist` | Server realm entries: address, type, population flag |
| `secret_digest` | SRP6 authentication digest storage |
| `updates` | Applied database migration files |
| `updates_include` | Migration include-path tracking |
| `uptime` | Per-realm uptime records |

---

### account

The master account record. Every player has one row here.

| Column | Type | Description |
|---|---|---|
| `id` | INT UNSIGNED | Primary key; unique account ID |
| `username` | VARCHAR(32) | Login name (effective max 20 chars) |
| `salt` | BINARY(32) | Random 32-byte salt for SRP6 |
| `verifier` | BINARY(32) | SRP6 verifier derived from salt + username + password |
| `session_key` | BINARY(40) | Session authentication key |
| `totp_secret` | VARBINARY(128) | Authenticator secret (Base32); NULL if not set |
| `email` | VARCHAR(255) | Primary email address |
| `reg_mail` | VARCHAR(255) | Registration email address |
| `joindate` | TIMESTAMP | Account creation timestamp |
| `last_ip` | VARCHAR(15) | Last successful login IP |
| `last_attempt_ip` | VARCHAR(15) | IP of last login attempt (including failed) |
| `failed_logins` | INT UNSIGNED | Count of failed login attempts |
| `locked` | TINYINT UNSIGNED | 1 = IP-locked (only `last_ip` may log in) |
| `lock_country` | VARCHAR(2) | Country code restriction |
| `last_login` | TIMESTAMP | Last successful login timestamp |
| `online` | INT UNSIGNED | 1 = currently logged in |
| `expansion` | TINYINT UNSIGNED | Max expansion: 0=Classic, 1=TBC, 2=WotLK |
| `Flags` | INT UNSIGNED | Account feature flags |
| `mutetime` | BIGINT | Unix timestamp when mute expires (0 = not muted) |
| `mutereason` | VARCHAR(255) | Reason for mute |
| `muteby` | VARCHAR(50) | GM character name who applied the mute |
| `locale` | TINYINT UNSIGNED | Client language (0=enUS, 1=koKR, 2=frFR, 3=deDE, 4=zhCN, 5=zhTW, 6=esES, 7=esMX, 8=ruRU) |
| `os` | VARCHAR(3) | Client OS: `Win` or `Mac` |
| `recruiter` | INT UNSIGNED | Referring account ID for Recruit-A-Friend |
| `totaltime` | INT UNSIGNED | Cumulative playtime across all characters in seconds |

---

### account_access

Stores GM permission levels. An account can have different access levels on different realms.

| Column | Type | Description |
|---|---|---|
| `id` | INT UNSIGNED | Account ID referencing `account.id` |
| `gmlevel` | TINYINT UNSIGNED | Security level (0=player, 1=moderator, ..., 3=administrator) |
| `RealmID` | INT SIGNED | Realm this access applies to; -1 = all realms |
| `comment` | VARCHAR(255) | Optional note |

---

### realmlist

Each row is a registered realm (game server).

| Column | Type | Description |
|---|---|---|
| `id` | INT UNSIGNED | Realm ID |
| `name` | VARCHAR(32) | Realm display name |
| `address` | VARCHAR(255) | Public IP or hostname |
| `localAddress` | VARCHAR(255) | LAN IP for local connections |
| `localSubnetMask` | VARCHAR(255) | Subnet mask for local detection |
| `port` | SMALLINT UNSIGNED | Worldserver port (default 8085) |
| `icon` | TINYINT UNSIGNED | Realm type icon: 0=Normal, 1=PvP, 6=RP, 8=RP-PvP |
| `flag` | TINYINT UNSIGNED | Status flags: 1=Invalid, 2=Offline, 4=Maintenance, 32=Recommended, 64=New players |
| `timezone` | TINYINT UNSIGNED | Realm timezone index |
| `allowedSecurityLevel` | TINYINT UNSIGNED | Minimum account security to log in |
| `population` | FLOAT | Population indicator sent to client |
| `gamebuild` | INT UNSIGNED | Required client build (12340 for 3.3.5a) |

---

## acore_characters Database

Stores all mutable character state. Rows are read at login and written on logout/periodic saves. The worldserver also writes to this database in real-time for critical events (combat death, item transactions, etc.).

### Table Inventory

| Table | Purpose |
|---|---|
| **Core Character** | |
| `characters` | Master character record: position, stats, flags |
| `character_account_data` | Per-character client settings |
| `character_declinedname` | Declined name forms (Russian locale) |
| `character_homebind` | Hearthstone bind point |
| `character_stats` | Cached character stat snapshot |
| **Inventory and Items** | |
| `character_inventory` | Maps items to bag/slot positions |
| `item_instance` | Every item instance in the game |
| `item_refund_instance` | Refundable item tracking |
| `item_soulbound_trade_data` | Soulbound item trade window data |
| `item_loot_storage` | Temporary loot awaiting looting |
| `character_equipmentsets` | Saved gear sets |
| `character_action` | Action bar button assignments |
| `character_glyphs` | Glyph selections per spec |
| **Progression** | |
| `character_aura` | Persisted auras at logout |
| `character_spell` | All spells known by character |
| `character_spell_cooldown` | Active spell cooldown timers |
| `character_talent` | Talent point allocations |
| `character_skills` | Skill values and maximums |
| `character_queststatus` | In-progress quest state and objective counters |
| `character_queststatus_daily` | Daily quest completion tracking |
| `character_queststatus_weekly` | Weekly quest tracking |
| `character_queststatus_monthly` | Monthly quest tracking |
| `character_queststatus_seasonal` | Seasonal quest tracking |
| `character_queststatus_rewarded` | Completed/rewarded quests |
| `character_reputation` | Faction standing values |
| `character_achievement` | Completed achievements |
| `character_achievement_progress` | Partial achievement progress |
| `character_achievement_offline_updates` | Offline achievement updates |
| **Social and Guild** | |
| `character_social` | Friends and ignore list |
| `guild` | Guild records |
| `guild_member` | Guild membership |
| `guild_rank` | Rank definitions and permissions |
| `guild_bank_tab` | Bank tab names/icons |
| `guild_bank_item` | Items stored in guild bank |
| `guild_bank_right` | Per-rank guild bank permissions |
| `guild_bank_eventlog` | Guild bank transaction history |
| `guild_eventlog` | Guild event log (invites, promotions, etc.) |
| `guild_member_withdraw` | Daily withdrawal limit tracking |
| **Groups and Instances** | |
| `groups` | Group/raid records |
| `group_member` | Group membership |
| `instance` | Instance records |
| `instance_reset` | Instance reset timers |
| `character_instance` | Character-instance binding |
| `character_entry_point` | Entry position when zoning into instances |
| **Pets** | |
| `character_pet` | Hunter pets and warlock demons |
| `character_pet_declinedname` | Declined pet names |
| `pet_aura` | Pet active auras |
| `pet_spell` | Pet known spells |
| `pet_spell_cooldown` | Pet spell cooldowns |
| **Mail and Auction** | |
| `mail` | Mail messages |
| `mail_items` | Items attached to mail |
| `mail_server_character` | Per-character mail server tracking |
| `mail_server_template` | Server-generated mail templates |
| `mail_server_template_conditions` | Conditions for server mail templates |
| `mail_server_template_items` | Items attached to server mail templates |
| `auctionhouse` | Active auction house listings |
| **Arena and PvP** | |
| `arena_team` | Arena team records |
| `arena_team_member` | Arena team membership stats |
| `active_arena_season` | Current arena season |
| `character_arena_stats` | Per-character arena rating history |
| `character_battleground_random` | Random battleground daily flag |
| `battleground_deserters` | Deserter debuff tracking |
| `pvpstats_battlegrounds` | Battleground statistics |
| `pvpstats_players` | Per-player PvP statistics |
| **Administrative** | |
| `character_banned` | Character ban records |
| `gm_ticket` | Support ticket records |
| `gm_survey` | Post-ticket GM survey data |
| `gm_subsurvey` | Survey sub-section data |
| `warden_action` | Anti-cheat Warden action logs |
| `bugreport` | Bug reports submitted in-game |
| `lag_reports` | Player-submitted lag reports |
| `log_arena_fights` | Arena fight log |
| `log_arena_memberstats` | Arena member statistics log |
| `log_encounter` | Boss encounter log |
| `log_money` | Money transaction audit log |
| **Channels and Calendar** | |
| `channels` | Persistent chat channels |
| `channels_bans` | Channel ban records |
| `channels_rights` | Channel permission settings |
| `calendar_events` | Calendar entries |
| `calendar_invites` | Calendar event invitations |
| **World State** | |
| `creature_respawn` | Per-instance creature respawn timers |
| `gameobject_respawn` | Per-instance gameobject respawn timers |
| `corpse` | Player corpse data |
| `worldstates` | Persistent world state variable storage |
| `game_event_condition_save` | Event condition completion state |
| `game_event_save` | Game event active state |
| **Account-Level (in chars DB)** | |
| `account_data` | Account-level client configuration |
| `account_instance_times` | Account-wide instance lockout cache |
| `account_tutorial` | Tutorial flag completion |
| `addons` | Known client addon list |
| `banned_addons` | Blacklisted addons |
| `reserved_name` | Reserved character name list |
| **Misc** | |
| `petition` | Guild/arena team petition records |
| `petition_sign` | Petition signature records |
| `pool_quest_save` | Quest pool selection state |
| `quest_tracker` | Quest tracking statistics |
| `recovery_item` | Item recovery records |
| `character_brew_of_the_month` | Brew of the Month Club tracking |
| `character_settings` | Per-character plugin/module settings |
| `custom_transmogrification` | Transmogrification appearance data |
| `custom_transmogrification_sets` | Saved transmogrification sets |
| `custom_unlocked_appearances` | Unlocked transmog appearances |
| `lfg_data` | Dungeon Finder state |
| `mdq_player_daily` | Daily quest module per-player daily state |
| `mdq_player_totals` | Daily quest module per-player total progress |
| `mod_weekly_rewards_progress` | Weekly rewards module progress |
| `profanity_name` | Filtered/profanity name records |
| `world_state` | World state variable storage |
| `updates` | Applied DB migrations |
| `updates_include` | Migration include paths |

---

### characters

The master character record. One row per character. Read fully at login; written on logout and periodically.

| Column | Type | Description |
|---|---|---|
| `guid` | INT UNSIGNED | Character GUID (primary key); referenced throughout the database |
| `account` | INT UNSIGNED | Account ID from `acore_auth.account.id` |
| `name` | VARCHAR(12) | Character name (max 12 characters) |
| `race` | TINYINT UNSIGNED | Race ID from ChrRaces.dbc (1=Human, 2=Orc, 3=Dwarf, 4=NightElf, 5=Undead, 6=Tauren, 7=Gnome, 8=Troll, 10=BloodElf, 11=Draenei) |
| `class` | TINYINT UNSIGNED | Class ID from ChrClasses.dbc (1=Warrior, 2=Paladin, 3=Hunter, 4=Rogue, 5=Priest, 6=DK, 7=Shaman, 8=Mage, 9=Warlock, 11=Druid) |
| `gender` | TINYINT UNSIGNED | 0=Male, 1=Female, 2=Unknown |
| `level` | TINYINT UNSIGNED | Current character level (1-80) |
| `xp` | INT UNSIGNED | Experience points toward next level |
| `money` | INT UNSIGNED | Copper on hand |
| `skin` | TINYINT UNSIGNED | Skin color index |
| `face` | TINYINT UNSIGNED | Face style index |
| `hairStyle` | TINYINT UNSIGNED | Hair style index |
| `hairColor` | TINYINT UNSIGNED | Hair color index |
| `facialStyle` | TINYINT UNSIGNED | Facial hair/features index |
| `bankSlots` | TINYINT UNSIGNED | Number of purchased bank bag slots (0-6) |
| `restState` | TINYINT UNSIGNED | Rest XP state flag |
| `playerFlags` | INT UNSIGNED | Bitmask: GM visible, AFK, DND, PvP flagged, etc. |
| `position_x` | FLOAT | World X coordinate |
| `position_y` | FLOAT | World Y coordinate |
| `position_z` | FLOAT | World Z coordinate |
| `map` | SMALLINT UNSIGNED | Map ID where character is located |
| `instance_id` | INT UNSIGNED | Instance ID for instanced maps |
| `instance_mode_mask` | TINYINT UNSIGNED | Difficulty bitmask (normal/heroic/10-man/25-man) |
| `orientation` | FLOAT | Facing direction in radians (0=North, π=South) |
| `taximask` | TEXT | Known flight path nodes as space-separated integers |
| `online` | TINYINT UNSIGNED | 1=online, 0=offline |
| `cinematic` | TINYINT UNSIGNED | Whether opening cinematic has played |
| `totaltime` | INT UNSIGNED | Total playtime in seconds |
| `leveltime` | INT UNSIGNED | Time at current level in seconds |
| `logout_time` | INT UNSIGNED | Unix timestamp of last logout |
| `is_logout_resting` | TINYINT UNSIGNED | Was logged out in a rest area |
| `rest_bonus` | FLOAT | Accumulated rested XP bonus |
| `resettalents_cost` | INT UNSIGNED | Talent reset cost in copper |
| `resettalents_time` | INT UNSIGNED | Unix timestamp of next talent reset availability |
| `trans_x` | FLOAT | Position on transport (X) |
| `trans_y` | FLOAT | Position on transport (Y) |
| `trans_z` | FLOAT | Position on transport (Z) |
| `trans_o` | FLOAT | Orientation on transport |
| `transguid` | INT SIGNED | GUID of transport the character was on at logout |
| `extra_flags` | SMALLINT UNSIGNED | Extra GM feature and player attribute flags |
| `stable_slots` | TINYINT UNSIGNED | Purchased pet stable slot count (0-4) |
| `at_login` | SMALLINT UNSIGNED | Bitmask of pending login actions: 1=rename, 2=reset spells, 4=reset talents, 8=customize, 16=reset pet talents, 32=first login, 64=change faction, 128=change race |
| `zone` | SMALLINT UNSIGNED | Current zone ID |
| `death_expire_time` | INT UNSIGNED | Unix timestamp when ghost state expires (resurrection sickness timer) |
| `taxi_path` | TEXT | Active taxi path if logged out mid-flight |
| `arenaPoints` | INT UNSIGNED | Pending arena points |
| `totalHonorPoints` | INT UNSIGNED | Lifetime honor points |
| `todayHonorPoints` | INT UNSIGNED | Honor earned today |
| `yesterdayHonorPoints` | INT UNSIGNED | Honor earned yesterday |
| `totalKills` | INT UNSIGNED | Lifetime honorable kills |
| `todayKills` | SMALLINT UNSIGNED | Honorable kills today |
| `yesterdayKills` | SMALLINT UNSIGNED | Honorable kills yesterday |
| `chosenTitle` | INT UNSIGNED | Active title bit index |
| `knownCurrencies` | BIGINT UNSIGNED | Bitmask of visible currency tab items |
| `watchedFaction` | INT UNSIGNED | Faction tracked in reputation bar |
| `drunk` | TINYINT UNSIGNED | Intoxication level (0-100) |
| `health` | INT UNSIGNED | Current HP |
| `power1`-`power7` | INT UNSIGNED | Current resource values: Mana, Rage, Focus, Energy, Happiness, Runes, Runic Power |
| `latency` | INT UNSIGNED | Last measured ping in ms |
| `talentGroupsCount` | TINYINT UNSIGNED | Number of specs purchased (1 or 2) |
| `activeTalentGroup` | TINYINT UNSIGNED | Active spec index (0 or 1) |
| `exploredZones` | LONGTEXT | Bitmask of explored zone bits |
| `equipmentCache` | LONGTEXT | Snapshot of equipped gear for character list display |
| `ammoId` | INT UNSIGNED | Equipped ammo item template ID |
| `knownTitles` | LONGTEXT | Title unlock bitmask |
| `actionBars` | TINYINT UNSIGNED | Visible action bar bitmask |
| `grantableLevels` | TINYINT UNSIGNED | Recruit-A-Friend grantable level count |
| `order` | TINYINT SIGNED | Display order on character selection screen |
| `creation_date` | TIMESTAMP | Character creation timestamp |
| `deleteInfos_Account` | INT UNSIGNED | Account ID retained after character deletion |
| `deleteInfos_Name` | VARCHAR(12) | Name retained after deletion |
| `deleteDate` | INT UNSIGNED | Deletion Unix timestamp (used for purge delay) |
| `innTriggerId` | INT UNSIGNED | Area trigger ID of the inn where character is resting |
| `extraBonusTalentCount` | INT | Extra bonus talent points (e.g. from custom scripts) |

---

### character_inventory

Maps item instances to character bag/slot positions. One row per item slot occupied.

| Column | Type | Description |
|---|---|---|
| `guid` | INT UNSIGNED | Character GUID |
| `bag` | INT UNSIGNED | 0 = equipped/backpack; nonzero = GUID of the container bag |
| `slot` | TINYINT UNSIGNED | Position within bag or equipment slot ID |
| `item` | INT UNSIGNED | Item instance GUID referencing `item_instance.guid` |

**Slot layout when `bag = 0`:**

| Slot Range | Contents |
|---|---|
| 0-18 | Equipment slots (head through ranged/tabard) |
| 19-22 | Equipped bag slots |
| 23-38 | Main backpack (16 slots) |
| 39-66 | Main bank slots |
| 67-73 | Bank bag slots |
| 86-117 | Keyring |
| 118-135 | Currency tokens |

---

### item_instance

Every item that exists in the game world. Linked to `character_inventory`, `mail_items`, `auctionhouse`, `guild_bank_item`, etc.

| Column | Type | Description |
|---|---|---|
| `guid` | INT UNSIGNED | Unique item GUID (primary key) |
| `itemEntry` | MEDIUMINT UNSIGNED | Template ID from `item_template.entry` |
| `owner_guid` | INT UNSIGNED | Character GUID who owns this item |
| `creatorGuid` | INT UNSIGNED | GUID of character who crafted the item |
| `giftCreatorGuid` | INT UNSIGNED | GUID of character who gifted the item |
| `count` | INT UNSIGNED | Stack size (number of items in stack) |
| `duration` | INT SIGNED | Remaining duration in seconds |
| `charges` | TINYTEXT | Five charge counts for item spells, space-separated |
| `flags` | MEDIUMINT UNSIGNED | Item state flags |
| `enchantments` | TEXT | Enchantment data referencing SpellItemEnchantment.dbc |
| `randomPropertyId` | SMALLINT SIGNED | Random enchant property ID |
| `durability` | SMALLINT UNSIGNED | Current durability |
| `playedTime` | INT UNSIGNED | Time item has been equipped in seconds |
| `text` | TEXT | Written text content for books/letters |

---

### character_aura

Active auras persisted at logout. Reapplied when character logs in.

| Column | Type | Description |
|---|---|---|
| `guid` | INT UNSIGNED | Character GUID |
| `casterGuid` | BIGINT UNSIGNED | Full GUID of the caster |
| `itemGuid` | BIGINT UNSIGNED | GUID of item that applied the aura (if item-sourced) |
| `spell` | MEDIUMINT UNSIGNED | Spell ID of the aura |
| `effectMask` | TINYINT UNSIGNED | Bitmask of active effect indices (0=effect0, 1=effect1, 2=effect2) |
| `recalculateMask` | TINYINT UNSIGNED | Which effects need stat recalculation |
| `stackCount` | TINYINT UNSIGNED | Number of stacks |
| `amount0`-`amount2` | INT SIGNED | Current modifier values for each effect |
| `base_amount0`-`base_amount2` | INT SIGNED | Base modifier values before scaling |
| `maxDuration` | INT SIGNED | Maximum duration in milliseconds |
| `remainTime` | INT SIGNED | Remaining time in milliseconds; -1 = indefinite |
| `remainCharges` | TINYINT UNSIGNED | Remaining proc charges |

---

### character_queststatus

In-progress quests. One row per character per active quest.

| Column | Type | Description |
|---|---|---|
| `guid` | INT UNSIGNED | Character GUID |
| `quest` | MEDIUMINT UNSIGNED | Quest ID from `quest_template.ID` |
| `status` | TINYINT UNSIGNED | 0=none, 1=in progress, 2=completed, 3=failed |
| `explored` | TINYINT UNSIGNED | Whether the POI area was explored |
| `accepttime` | INT UNSIGNED | Unix timestamp of quest acceptance |
| `timer` | INT UNSIGNED | Remaining time for timed quests in milliseconds |
| `mobcount1`-`mobcount4` | SMALLINT UNSIGNED | Current kill/interaction count per objective |
| `itemcount1`-`itemcount6` | SMALLINT UNSIGNED | Current item collection count per objective |
| `playercount` | SMALLINT UNSIGNED | Player kill count for PvP objectives |

---

### character_reputation

One row per character per faction with tracked standing.

| Column | Type | Description |
|---|---|---|
| `guid` | INT UNSIGNED | Character GUID |
| `faction` | SMALLINT UNSIGNED | Faction ID from Faction.dbc |
| `standing` | INT SIGNED | Raw reputation value (base 0; Hated=-42000 to Exalted=42999 max per tier) |
| `flags` | TINYINT UNSIGNED | Bitmask: 1=visible, 2=at war, 4=hidden, 8=inactive, 16=watched |

---

### character_skills

| Column | Type | Description |
|---|---|---|
| `guid` | INT UNSIGNED | Character GUID |
| `skill` | SMALLINT UNSIGNED | Skill ID from SkillLine.dbc |
| `value` | SMALLINT UNSIGNED | Current skill value |
| `max` | SMALLINT UNSIGNED | Maximum skill value |

---

### character_talent

| Column | Type | Description |
|---|---|---|
| `guid` | INT UNSIGNED | Character GUID |
| `spell` | MEDIUMINT UNSIGNED | Talent spell ID |
| `spec` | TINYINT UNSIGNED | Spec index (0 or 1) this talent belongs to |

---

### character_glyphs

| Column | Type | Description |
|---|---|---|
| `guid` | INT UNSIGNED | Character GUID |
| `talentGroup` | TINYINT UNSIGNED | Spec index (0 or 1) |
| `glyph1`-`glyph6` | SMALLINT UNSIGNED | Glyph IDs from GlyphProperties.dbc (0 = empty) |

---

### character_homebind

| Column | Type | Description |
|---|---|---|
| `guid` | INT UNSIGNED | Character GUID |
| `mapId` | SMALLINT UNSIGNED | Map of the hearthstone bind point |
| `zoneId` | SMALLINT UNSIGNED | Zone of the bind point |
| `posX` | FLOAT | X coordinate |
| `posY` | FLOAT | Y coordinate |
| `posZ` | FLOAT | Z coordinate |

---

### character_social

| Column | Type | Description |
|---|---|---|
| `guid` | INT UNSIGNED | Character GUID of the list owner |
| `friend` | INT UNSIGNED | GUID of the listed character |
| `flags` | TINYINT UNSIGNED | 1=Friend, 2=Ignored |
| `note` | VARCHAR(48) | Optional friend note |

---

### guild

| Column | Type | Description |
|---|---|---|
| `guildid` | INT UNSIGNED | Guild GUID |
| `name` | VARCHAR(24) | Guild name |
| `leaderguid` | INT UNSIGNED | Character GUID of the guild master |
| `EmblemStyle` | TINYINT UNSIGNED | Tabard emblem design |
| `EmblemColor` | TINYINT UNSIGNED | Tabard emblem color |
| `BorderStyle` | TINYINT UNSIGNED | Tabard border design |
| `BorderColor` | TINYINT UNSIGNED | Tabard border color |
| `BackgroundColor` | TINYINT UNSIGNED | Tabard background color |
| `info` | TEXT | Guild information text (shown in guild info window) |
| `motd` | VARCHAR(128) | Guild message of the day |
| `createdate` | INT UNSIGNED | Unix timestamp of guild creation |
| `BankMoney` | BIGINT UNSIGNED | Guild bank balance in copper |

---

### mail

| Column | Type | Description |
|---|---|---|
| `id` | INT UNSIGNED | Unique mail ID |
| `messageType` | TINYINT UNSIGNED | 0=Normal, 1=Auction, 2=Creature, 3=Gameobject, 4=Item |
| `stationery` | TINYINT UNSIGNED | Visual stationery type |
| `mailTemplateId` | MEDIUMINT UNSIGNED | Template from MailTemplate.dbc if system mail |
| `sender` | INT UNSIGNED | Sender character GUID (or NPC entry for system mail) |
| `receiver` | INT UNSIGNED | Recipient character GUID |
| `subject` | VARCHAR(255) | Mail subject line |
| `body` | LONGTEXT | Mail body text |
| `has_items` | TINYINT UNSIGNED | 1 if mail has attached items |
| `expire_time` | INT UNSIGNED | Unix timestamp when mail expires |
| `deliver_time` | INT UNSIGNED | Unix timestamp when mail becomes available |
| `money` | INT UNSIGNED | Copper attached to the mail |
| `cod` | INT UNSIGNED | Cash-on-delivery amount in copper |
| `checked` | TINYINT UNSIGNED | Read/returned state flags |

---

## acore_world Database

Static game data loaded by the worldserver at startup. Modifying this database changes game content. Most tables can be reloaded without restart using `.reload` commands.

---

### Creature Tables

| Table | Purpose |
|---|---|
| `creature_template` | Base definition for every creature type |
| `creature` | World spawn instances with positions |
| `creature_addon` | Per-spawn visual and behavioral overrides |
| `creature_template_addon` | Per-template default visual overrides |
| `creature_template_locale` | Localized creature names and subtitles |
| `creature_template_movement` | Default movement parameters per template |
| `creature_movement_override` | Per-spawn movement overrides |
| `creature_equip_template` | Weapon/offhand/ranged equipment for spawns |
| `creature_template_resistance` | Elemental resistance values per template |
| `creature_template_spell` | Up to 8 spells known by a creature template |
| `creature_onkill_reputation` | Faction reputation on creature kill |
| `creature_formations` | Formation grouping for linked creature movement |
| `creature_text` | NPC dialogue lines with sound/emote data |
| `creature_text_locale` | Localized creature text |
| `creature_classlevelstats` | Base stat tables by class and level |
| `linked_respawn` | Links creature/GO respawn to another creature |

---

#### creature_template

Defines every creature type. Each row is a unique creature species/variant identified by `entry`.

| Column | Type | Description |
|---|---|---|
| `entry` | INT UNSIGNED | Primary key; unique creature template ID |
| `difficulty_entry_1` | INT UNSIGNED | Template entry used in heroic/25-man normal |
| `difficulty_entry_2` | INT UNSIGNED | Template entry for 10-man heroic |
| `difficulty_entry_3` | INT UNSIGNED | Template entry for 25-man heroic |
| `KillCredit1` | INT UNSIGNED | Alternative creature entry that grants quest credit |
| `KillCredit2` | INT UNSIGNED | Second alternative quest credit entry |
| `name` | CHAR(100) | Primary display name |
| `subname` | CHAR(100) | Subtitle shown in brackets below name |
| `IconName` | CHAR(100) | Cursor icon type on mouseover (Gossip, Trainer, Vendor, etc.) |
| `gossip_menu_id` | INT UNSIGNED | Default gossip menu; references `gossip_menu.MenuID` |
| `minlevel` | TINYINT UNSIGNED | Minimum level of the creature |
| `maxlevel` | TINYINT UNSIGNED | Maximum level (if range; otherwise same as minlevel) |
| `exp` | SMALLINT | Expansion tier: 0=Classic, 1=TBC, 2=WotLK |
| `faction` | SMALLINT UNSIGNED | Faction template ID from FactionTemplate.dbc |
| `npcflag` | INT UNSIGNED | NPC capability flags: 1=Gossip, 2=QuestGiver, 16=Trainer, 32=ClassTrainer, 64=ProfTrainer, 128=Vendor, 256=AmmoVendor, etc. |
| `speed_walk` | FLOAT | Walk speed multiplier |
| `speed_run` | FLOAT | Run speed multiplier |
| `speed_swim` | FLOAT | Swim speed multiplier |
| `speed_flight` | FLOAT | Fly speed multiplier |
| `detection_range` | FLOAT | Aggro detection radius |
| `scale` | FLOAT | Model scale factor (0 = use DBC default) |
| `rank` | TINYINT UNSIGNED | 0=Normal, 1=Elite, 2=Rare Elite, 3=Boss, 4=Rare |
| `dmgschool` | TINYINT | Melee damage school: 0=Physical, 1=Holy, 2=Fire, 3=Nature, 4=Frost, 5=Shadow, 6=Arcane |
| `BaseAttackTime` | INT UNSIGNED | Milliseconds between melee swings |
| `RangeAttackTime` | INT UNSIGNED | Milliseconds between ranged attacks |
| `BaseVariance` | FLOAT | Melee damage variance multiplier |
| `RangeVariance` | FLOAT | Ranged damage variance multiplier |
| `unit_class` | TINYINT UNSIGNED | Determines HP/mana pools: 1=Warrior, 2=Paladin, 4=Rogue, 8=Mage |
| `unit_flags` | INT UNSIGNED | Unit state flags (non-attackable, immune to PC, etc.) |
| `unit_flags2` | INT UNSIGNED | Additional flags (feign death, no actions, etc.) |
| `dynamicflags` | INT UNSIGNED | Visual flags: lootable, tapped, dead, track unit |
| `family` | TINYINT | Pet family for hunter pets (1=Wolf, 2=Cat, 3=Spider, etc.) |
| `type` | TINYINT UNSIGNED | Creature type: 1=Beast, 2=Dragonkin, 3=Demon, 4=Elemental, 5=Giant, 6=Undead, 7=Humanoid, 8=Critter, 9=Mechanical, 10=Not specified, 11=Totem, 12=Non-combat pet, 13=Gas Cloud |
| `type_flags` | INT UNSIGNED | Special properties: 1=Tameable, 2=Ghost visible, 4=Boss, 8=No XP, 16=No Loot, 32=No PvP credit, 64=Capture soul, 128=No corpse on BG death, 256=Visible to ghosts, 512=Skinnable, 1024=Herb, 2048=Mine |
| `lootid` | INT UNSIGNED | References `creature_loot_template.entry` |
| `pickpocketloot` | INT UNSIGNED | References `pickpocketing_loot_template.entry` |
| `skinloot` | INT UNSIGNED | References `skinning_loot_template.entry` |
| `PetSpellDataId` | INT UNSIGNED | CreatureSpellData.dbc entry for pet UI |
| `VehicleId` | INT UNSIGNED | Vehicle.dbc entry ID |
| `mingold` | INT UNSIGNED | Minimum money drop in copper |
| `maxgold` | INT UNSIGNED | Maximum money drop in copper |
| `AIName` | CHAR(64) | AI class name: `SmartAI`, `NullCreatureAI`, `AggressorAI`, `ReactorAI`, `GuardAI`, `PetAI`, `TotemAI`, etc. |
| `MovementType` | TINYINT UNSIGNED | 0=Idle (stand still), 1=Random wander, 2=Waypoint path |
| `HoverHeight` | FLOAT | Hover height above ground |
| `HealthModifier` | FLOAT | Multiplier applied to base HP |
| `ManaModifier` | FLOAT | Multiplier applied to base mana |
| `ArmorModifier` | FLOAT | Multiplier applied to base armor |
| `DamageModifier` | FLOAT | Multiplier applied to damage output |
| `ExperienceModifier` | FLOAT | Multiplier applied to XP reward |
| `RacialLeader` | TINYINT UNSIGNED | 1 = this creature is a racial leader |
| `movementId` | INT UNSIGNED | Movement DBC entry |
| `RegenHealth` | TINYINT UNSIGNED | 1 = creature regenerates health out of combat |
| `mechanic_immune_mask` | INT UNSIGNED | Bitmask of spell mechanic immunities (charm, confuse, fear, root, silence, sleep, snare, stun, etc.) |
| `spell_school_immune_mask` | INT UNSIGNED | Bitmask of spell school immunities |
| `flags_extra` | INT UNSIGNED | Extra flags: 1=No XP, 2=No Loot, 4=No Faction War participation, 8=No Parry, 16=No Parry Hasten, 32=No Spell Block, 64=No Crush, 128=Trigger NPC (invisible), 256=Civilian, 512=No Call for help, 1024=Active (always update), 2048=Guard, etc. |
| `ScriptName` | CHAR(64) | C++ script class name |
| `VerifiedBuild` | INT | NULL=unverified, positive=WDB build, -1=manual placeholder |

---

#### creature (spawn table)

One row per creature spawn in the world.

| Column | Type | Description |
|---|---|---|
| `guid` | INT UNSIGNED | Spawn GUID (unique per creature instance) |
| `id1` | INT UNSIGNED | Primary template entry (`creature_template.entry`) |
| `id2` | INT UNSIGNED | Secondary random template (optional) |
| `id3` | INT UNSIGNED | Tertiary random template (optional) |
| `map` | SMALLINT UNSIGNED | Map ID |
| `zoneId` | SMALLINT UNSIGNED | Zone ID (auto-populated) |
| `areaId` | SMALLINT UNSIGNED | Sub-area ID (auto-populated) |
| `spawnMask` | TINYINT UNSIGNED | Difficulty bitmask: 1=Normal, 2=Heroic, 4=10-man Normal, 8=25-man Normal, etc. |
| `phaseMask` | INT UNSIGNED | Phase bitmask controlling visibility |
| `equipment_id` | TINYINT UNSIGNED | References `creature_equip_template.CreatureID`; 0=none, -1=random |
| `position_x` | FLOAT | Spawn X coordinate |
| `position_y` | FLOAT | Spawn Y coordinate |
| `position_z` | FLOAT | Spawn Z coordinate |
| `orientation` | FLOAT | Spawn facing in radians |
| `spawntimesecs` | INT UNSIGNED | Respawn time in seconds |
| `wander_distance` | FLOAT | Random wander radius (for MovementType=1) |
| `currentwaypoint` | INT UNSIGNED | Current waypoint ID (always 0 at spawn) |
| `curhealth` | INT UNSIGNED | Saved health at last snapshot (usually 1) |
| `curmana` | INT UNSIGNED | Saved mana at last snapshot |
| `MovementType` | TINYINT UNSIGNED | 0=idle, 1=random, 2=waypoint (overrides template) |
| `npcflag` | INT UNSIGNED | Overrides template npcflag if nonzero |
| `unit_flags` | INT UNSIGNED | Overrides template unit_flags if nonzero |
| `dynamicflags` | INT UNSIGNED | Overrides template dynamicflags if nonzero |
| `ScriptName` | CHAR(64) | Overrides template ScriptName if set |
| `VerifiedBuild` | INT | Build verification |
| `CreateObject` | TINYINT UNSIGNED | Spawn accuracy category (sniffed data marker) |
| `Comment` | TEXT | Optional descriptive note |

---

### GameObject Tables

| Table | Purpose |
|---|---|
| `gameobject_template` | Base definition for every gameobject type |
| `gameobject` | World spawn instances with positions and state |
| `gameobject_addon` | Per-spawn visual overrides |
| `gameobject_questitem` | Items displayed in chest GO loot windows |
| `gameobject_template_locale` | Localized gameobject names |

---

#### gameobject_template

| Column | Type | Description |
|---|---|---|
| `entry` | INT UNSIGNED | Unique template ID |
| `type` | TINYINT UNSIGNED | GO type (see below) |
| `displayId` | INT UNSIGNED | Model ID from GameObjectDisplayInfo.dbc |
| `name` | VARCHAR(100) | Display name |
| `IconName` | VARCHAR(100) | Cursor icon override |
| `castBarCaption` | VARCHAR(100) | Text shown in cast bar while interacting |
| `unk1` | VARCHAR(100) | Unused field |
| `size` | FLOAT | Scale multiplier |
| `Data0`-`Data23` | INT | Type-specific parameters (behavior varies by type) |
| `AIName` | CHAR(64) | AI name; currently only `SmartGameObjectAI` supported |
| `ScriptName` | VARCHAR(64) | C++ script class name |
| `VerifiedBuild` | INT | Build verification |

**GO Type values:**

| Value | Name | data0-data23 role |
|---|---|---|
| 0 | DOOR | Lock ID, auto-close time, etc. |
| 1 | BUTTON | Lock ID, linked trap, etc. |
| 2 | QUESTGIVER | — |
| 3 | CHEST | Lock ID, loot template, restock time, min/max restock count, etc. |
| 5 | GENERIC | — |
| 6 | TRAP | Lock ID, spell ID, charges, cooldown, radius |
| 10 | GOOBER | Lock ID, questId, spell ID, etc. |
| 17 | FISHINGNODE | — |
| 22 | SPELLCASTER | Spell ID, charges, party-only |
| 25 | FISHINGHOLE | Max fish count, loot template, etc. |
| 33 | DESTRUCTIBLE_BUILDING | HP values, display IDs per damage state |
| 34 | GUILD_BANK | — |

---

#### gameobject (spawn table)

| Column | Type | Description |
|---|---|---|
| `guid` | INT UNSIGNED | Unique spawn GUID |
| `id` | INT UNSIGNED | Template entry from `gameobject_template.entry` |
| `map` | SMALLINT UNSIGNED | Map ID |
| `zoneId` | SMALLINT UNSIGNED | Zone ID |
| `areaId` | SMALLINT UNSIGNED | Sub-area ID |
| `spawnMask` | TINYINT UNSIGNED | Difficulty bitmask |
| `phaseMask` | INT UNSIGNED | Phase bitmask |
| `position_x` | FLOAT | X coordinate |
| `position_y` | FLOAT | Y coordinate |
| `position_z` | FLOAT | Z coordinate |
| `orientation` | FLOAT | Facing direction |
| `rotation0`-`rotation3` | FLOAT | Quaternion rotation components |
| `spawntimesecs` | INT SIGNED | Respawn time; 0=no despawn; negative=delayed spawn |
| `animprogress` | TINYINT UNSIGNED | Animation progress (100 for chests) |
| `state` | TINYINT UNSIGNED | Initial state: 0=open/active, 1=closed/inactive |
| `ScriptName` | CHAR(64) | Script override |
| `VerifiedBuild` | INT | Build verification |
| `Comment` | TEXT | Descriptive note |

---

### Item Tables

| Table | Purpose |
|---|---|
| `item_template` | Complete item definition for every item in the game |
| `item_template_locale` | Localized item names and descriptions |
| `item_enchantment_template` | Random enchantment group definitions |
| `itemextendedcost_dbc` | DBC mirror: non-gold currency costs (honor, arena points, tokens) |
| `item_set_names` | Item set names and bonus definitions |

---

#### item_template (key columns)

Full 80+ column table — key columns listed. See detailed column list in [Research Sources](#cross-references).

| Column | Type | Description |
|---|---|---|
| `entry` | INT UNSIGNED | Unique item ID |
| `class` | TINYINT UNSIGNED | Item class: 0=Consumable, 1=Container, 2=Weapon, 3=Gem, 4=Armor, 5=Reagent, 6=Projectile, 7=Trade Goods, 9=Recipe, 11=Quiver, 12=Quest, 13=Key, 15=Miscellaneous, 16=Glyph |
| `subclass` | TINYINT UNSIGNED | Sub-type within class |
| `name` | VARCHAR(255) | Item name |
| `displayid` | INT UNSIGNED | Model/icon ID from ItemDisplayInfo.dbc |
| `Quality` | TINYINT UNSIGNED | 0=Poor(grey), 1=Common(white), 2=Uncommon(green), 3=Rare(blue), 4=Epic(purple), 5=Legendary(orange), 6=Artifact(red), 7=Heirloom(gold) |
| `Flags` | INT UNSIGNED | Item behavior flags (conjured, openable, etc.) |
| `FlagsExtra` | INT UNSIGNED | Extra flags (Horde/Alliance only, etc.) |
| `BuyPrice` | BIGINT SIGNED | Purchase price in copper |
| `SellPrice` | INT UNSIGNED | Vendor sell price in copper |
| `InventoryType` | TINYINT UNSIGNED | Equipment slot ID |
| `AllowableClass` | INT SIGNED | Class bitmask (-1=all) |
| `AllowableRace` | INT SIGNED | Race bitmask (-1=all) |
| `ItemLevel` | SMALLINT UNSIGNED | Base item level |
| `RequiredLevel` | TINYINT UNSIGNED | Minimum equip level |
| `RequiredSkill` | SMALLINT UNSIGNED | Required skill ID |
| `RequiredSkillRank` | SMALLINT UNSIGNED | Required skill rank |
| `maxcount` | INT SIGNED | Max copies per player (0=unlimited) |
| `stackable` | INT SIGNED | Max stack size |
| `ContainerSlots` | SMALLINT UNSIGNED | Bag slot count if container |
| `stat_type1`-`stat_type10` | TINYINT UNSIGNED | Stat type IDs (3=Agility, 4=Strength, 5=Intellect, 6=Spirit, 7=Stamina, 32=SpellPower, etc.) |
| `stat_value1`-`stat_value10` | INT SIGNED | Stat values |
| `dmg_min1`, `dmg_max1` | FLOAT | Primary damage range |
| `dmg_min2`, `dmg_max2` | FLOAT | Secondary damage range |
| `dmg_type1`, `dmg_type2` | TINYINT UNSIGNED | Damage school |
| `armor` | SMALLINT UNSIGNED | Armor value |
| `delay` | SMALLINT UNSIGNED | Attack speed in milliseconds |
| `bonding` | TINYINT UNSIGNED | 0=No bind, 1=BoP, 2=BoE, 3=BoU, 4=Quest |
| `spellid_1`-`spellid_5` | INT SIGNED | Triggered spell IDs |
| `spelltrigger_1`-`spelltrigger_5` | TINYINT UNSIGNED | 0=Use, 1=Equip, 2=Proc, 4=Soulstone, 6=Learn |
| `spellcharges_1`-`spellcharges_5` | SMALLINT SIGNED | Charges (0=infinite) |
| `socketColor_1`-`socketColor_3` | TINYINT SIGNED | Socket gem type: 1=Meta, 2=Red, 4=Yellow, 8=Blue |
| `socketBonus` | INT SIGNED | Enchantment ID for socket match bonus |
| `GemProperties` | INT SIGNED | Gem property ID if this item is a gem |
| `RequiredDisenchantSkill` | SMALLINT SIGNED | -1=not disenchantable |
| `DisenchantID` | INT UNSIGNED | References `disenchant_loot_template.entry` |
| `FoodType` | TINYINT UNSIGNED | Pet food category (1-8) |
| `ScriptName` | VARCHAR(64) | Custom script class name |
| `VerifiedBuild` | INT | Build verification |

---

### Quest Tables

| Table | Purpose |
|---|---|
| `quest_template` | Complete quest definition |
| `quest_template_addon` | Additional fields not in WDB (prev/next chains, max level, class/race restrictions) |
| `quest_offer_reward` | "Quest Complete" NPC dialogue text |
| `quest_request_items` | "Quest Incomplete" NPC dialogue text |
| `quest_details` | Detailed quest description text |
| `quest_greeting` | NPC greeting text for quest givers |
| `creature_queststarter` | Which creatures offer which quests |
| `creature_questender` | Which creatures complete which quests |
| `gameobject_queststarter` | Which GOs offer quests |
| `gameobject_questender` | Which GOs complete quests |
| `quest_poi` | Quest map point-of-interest blobs |
| `quest_poi_points` | Individual POI coordinate points |

---

#### quest_template (key columns)

| Column | Type | Description |
|---|---|---|
| `ID` | INT UNSIGNED | Unique quest ID |
| `QuestType` | TINYINT UNSIGNED | 0=auto-complete, 1=disabled, 2=normal |
| `QuestLevel` | SMALLINT | Recommended level; -1=player's level |
| `MinLevel` | TINYINT UNSIGNED | Minimum player level to accept |
| `QuestSortID` | SMALLINT | Category: positive=zone, negative=questsort |
| `QuestInfoID` | SMALLINT UNSIGNED | Quest type from QuestInfo.dbc (1=Group, 21=Life, 41=PvP, 62=Raid, 63=Dungeon, 64=World Event, 65=Legendary, 67=Escort, 68=Heroic, 69=Raid10, 70=Raid25) |
| `SuggestedGroupNum` | TINYINT UNSIGNED | Recommended group size |
| `Flags` | INT UNSIGNED | Quest flags: 2=Sharable, 8=Raid, 64=Daily, 4096=Weekly, 16384=Auto-complete, etc. |
| `RewardNextQuest` | MEDIUMINT UNSIGNED | Quest ID automatically given on completion |
| `RewardXPDifficulty` | TINYINT UNSIGNED | XP tier index from QuestXP.dbc |
| `RewardMoney` | INT | Gold reward (positive) or cost (negative) in copper |
| `RewardSpell` | INT | Spell ID cast on completion |
| `RewardHonor` | INT | Honor points reward |
| `StartItem` | MEDIUMINT UNSIGNED | Item given at quest start (deleted on abandon) |
| `RewardItem1`-`RewardItem4` | MEDIUMINT UNSIGNED | Guaranteed reward item IDs |
| `RewardAmount1`-`RewardAmount4` | SMALLINT UNSIGNED | Guaranteed reward item quantities |
| `RewardChoiceItemID1`-`RewardChoiceItemID6` | MEDIUMINT UNSIGNED | Choice reward item IDs (player picks one) |
| `RewardChoiceItemQuantity1`-`6` | SMALLINT UNSIGNED | Choice item quantities |
| `RewardFactionID1`-`5` | SMALLINT UNSIGNED | Faction IDs for reputation rewards |
| `RewardFactionValue1`-`5` | MEDIUMINT | Reputation change amounts |
| `TimeAllowed` | INT UNSIGNED | Time limit in seconds (0=unlimited) |
| `AllowableRaces` | SMALLINT UNSIGNED | Race restriction bitmask |
| `LogTitle` | TEXT | Short title in quest log |
| `LogDescription` | TEXT | Objective summary |
| `QuestDescription` | TEXT | Full quest text with `$B` (line break), `$N` (player name), `$R` (race), `$C` (class) placeholders |
| `RequiredNpcOrGo1`-`4` | MEDIUMINT | Positive=creature entry, negative=GO entry to interact with |
| `RequiredNpcOrGoCount1`-`4` | SMALLINT UNSIGNED | Required kill/interaction count |
| `RequiredItemId1`-`6` | MEDIUMINT UNSIGNED | Required item IDs for turn-in |
| `RequiredItemCount1`-`6` | SMALLINT UNSIGNED | Required item counts |
| `ObjectiveText1`-`4` | TEXT | Custom objective label text in quest log |
| `VerifiedBuild` | SMALLINT | Build verification |

---

### NPC Service Tables

| Table | Purpose |
|---|---|
| `npc_vendor` | Vendor inventory: items each NPC sells |
| `trainer` | Trainer NPC records: greeting text and type |
| `trainer_locale` | Localized trainer greeting text |
| `trainer_spell` | Spells each trainer teaches with level/skill/cost requirements |
| `creature_default_trainer` | Maps creature template to trainer record |
| `npc_text` | NPC dialogue text blocks (up to 8 text options per entry) |
| `gossip_menu` | Gossip menu definitions linking NPC to text |
| `gossip_menu_option` | Individual gossip menu action buttons |
| `broadcast_text` | Server-broadcast and NPC emote text |
| `npc_spellclick_spells` | Spells cast when player right-clicks a creature |
| `vehicle_template_accessory` | Default passengers loaded into vehicle seats |
| `vehicle_accessory` | Per-spawn vehicle passenger overrides |

---

#### npc_vendor

| Column | Type | Description |
|---|---|---|
| `entry` | INT UNSIGNED | Creature template entry (NPC ID) |
| `slot` | SMALLINT SIGNED | Display position in vendor window (0=top) |
| `item` | INT UNSIGNED | Item template entry |
| `maxcount` | INT UNSIGNED | Max stock (0=unlimited) |
| `incrtime` | INT UNSIGNED | Restock interval in seconds |
| `ExtendedCost` | INT UNSIGNED | ItemExtendedCost.dbc entry for honor/arena/token costs |
| `VerifiedBuild` | INT | Build verification |

Note: Vendors are hard-capped at 150 items (15 pages).

---

### Loot Tables

All loot tables share the same column schema. The table prefix identifies the loot source.

| Table | Triggered by |
|---|---|
| `creature_loot_template` | Creature body loot (`creature_template.lootid`) |
| `pickpocketing_loot_template` | Pickpocket (`creature_template.pickpocketloot`) |
| `skinning_loot_template` | Skinning (`creature_template.skinloot`) |
| `gameobject_loot_template` | GO chest loot (`gameobject_template.data1` for CHEST type) |
| `item_loot_template` | Container item contents (`item_template.entry`) |
| `disenchant_loot_template` | Disenchanting (`item_template.DisenchantID`) |
| `fishing_loot_template` | Fishing catches (zone-based area ID) |
| `prospecting_loot_template` | Ore prospecting |
| `milling_loot_template` | Herb milling |
| `spell_loot_template` | Spell-created loot (some spells) |
| `reference_loot_template` | Shared loot groups referenced by other templates |

**Universal loot table columns:**

| Column | Type | Description |
|---|---|---|
| `Entry` | MEDIUMINT UNSIGNED | Template ID matching the trigger (e.g., creature_template.lootid) |
| `Item` | MEDIUMINT UNSIGNED | Item template entry to drop; negative value = reference into `reference_loot_template` |
| `Reference` | MEDIUMINT UNSIGNED | If nonzero, references a `reference_loot_template.Entry` to expand inline |
| `Chance` | FLOAT | Drop chance percentage (0-100). Negative = quest item (only for players on that quest) |
| `QuestRequired` | BOOL | If 1, item only drops for players who have the quest requiring it |
| `LootMode` | SMALLINT UNSIGNED | Bitmask controlling which loot modes produce this drop (1=Normal, 2=Heroic, etc.) |
| `GroupId` | TINYINT UNSIGNED | Items in the same group are mutually exclusive (only one from group drops per loot roll) |
| `MinCount` | TINYINT UNSIGNED | Minimum number of items dropped |
| `MaxCount` | TINYINT UNSIGNED | Maximum number of items dropped |
| `Comment` | VARCHAR(255) | Optional description |

**How loot works:**
- Items with `GroupId = 0` are rolled independently.
- Items sharing a nonzero `GroupId` compete: only one item from the group drops (using their relative chances).
- A `Reference` value points to `reference_loot_template` for reusable loot lists shared across many creatures.

---

### Scripting Tables

| Table | Purpose |
|---|---|
| `smart_scripts` | SmartAI event-action-target scripts for creatures/GOs |
| `areatrigger_scripts` | Script name bindings for area trigger events |
| `areatrigger_involvedrelation` | Areatrigger-to-quest mappings |
| `areatrigger_teleport` | Teleport destinations for area triggers |
| `areatrigger_tavern` | Rest area trigger definitions |
| `event_scripts` | Scripts fired by world events |
| `spell_scripts` | Scripts fired by spell effects |
| `waypoint_scripts` | Scripts executed at specific waypoints |
| `script_waypoint` | Waypoints defined for C++ script use |

---

#### smart_scripts

Powers the SmartAI system used by creatures with `AIName = 'SmartAI'` and GOs with `AIName = 'SmartGameObjectAI'`.

| Column | Type | Description |
|---|---|---|
| `entryorguid` | INT SIGNED | Positive = template entry; negative = specific spawn GUID |
| `source_type` | TINYINT UNSIGNED | 0=Creature, 1=GameObject, 2=AreaTrigger, 9=TimedActionList |
| `id` | SMALLINT UNSIGNED | Sequential script ID within the entryorguid/source_type pair |
| `link` | SMALLINT UNSIGNED | Links to another `id`; that id runs immediately after this one when link matches |
| `event_type` | TINYINT UNSIGNED | What triggers this script (see event type list below) |
| `event_phase_mask` | SMALLINT UNSIGNED | Bitmask of encounter phases when this fires (0=all phases) |
| `event_chance` | TINYINT UNSIGNED | Probability this event fires (0-100; default 100) |
| `event_flags` | SMALLINT UNSIGNED | 1=Not repeatable, 2-16=Difficulty restrictions, 128=Debug only |
| `event_param1`-`event_param6` | INT UNSIGNED | Event-specific parameters (timing, thresholds, spell IDs, etc.) |
| `action_type` | TINYINT UNSIGNED | What action to perform when event fires |
| `action_param1`-`action_param6` | INT UNSIGNED | Action-specific parameters |
| `target_type` | TINYINT UNSIGNED | Who receives the action |
| `target_param1`-`target_param4` | INT UNSIGNED | Target selection criteria |
| `target_x`, `target_y`, `target_z` | FLOAT | Absolute coordinates for position-based targets |
| `target_o` | FLOAT | Orientation for position-based targets |
| `comment` | TEXT | Recommended format: `"CreatureName - Event - Action"` |

**Key event_type values:**

| Value | Name | Meaning |
|---|---|---|
| 0 | UPDATE_IC | Fires every N-M ms during combat |
| 1 | UPDATE_OOC | Fires every N-M ms out of combat |
| 2 | HP_PCT_RANGE | Fires when HP enters a percentage range |
| 4 | AGGRO | Fires on entering combat |
| 6 | DEATH | Fires on creature death |
| 7 | EVADE | Fires when evading (resetting) |
| 8 | SPELLHIT | Fires when a specific spell hits the creature |
| 11 | RESPAWN | Fires on respawn |
| 25 | OOC_LOS | Fires when a unit enters LOS out of combat |
| 38 | FRIENDLY_HEALTH_PCT | Fires when a nearby friendly hits an HP threshold |
| 40 | WAYPOINT_REACHED | Fires at a specific waypoint |
| 59 | GAME_EVENT_START/END | Fires on game event start or stop |

**Key action_type values:**

| Value | Name | Meaning |
|---|---|---|
| 1 | TALK | Say a line from creature_text |
| 2 | SET_FACTION | Change faction |
| 11 | CAST | Cast a spell |
| 12 | SUMMON_CREATURE | Summon a creature |
| 18 | EMOTE | Play an emote |
| 22 | FAIL_QUEST | Fail a player's quest |
| 33 | SET_PHASE | Set encounter phase |
| 49 | MOVE_TO_POS | Move to coordinates |
| 66 | WP_START | Start waypoint path |
| 67 | WP_PAUSE | Pause at waypoint |
| 68 | WP_STOP | Stop waypoints |
| 87 | SET_DISABLE_GRAVITY | Enable/disable flight mode |

---

#### areatrigger_teleport

| Column | Type | Description |
|---|---|---|
| `ID` | MEDIUMINT UNSIGNED | AreaTrigger.dbc ID |
| `name` | TEXT | Human-readable description |
| `target_map` | SMALLINT UNSIGNED | Destination map ID |
| `target_position_x` | FLOAT | Destination X |
| `target_position_y` | FLOAT | Destination Y |
| `target_position_z` | FLOAT | Destination Z |
| `target_orientation` | FLOAT | Player facing on arrival |

---

### Waypoint Tables

| Table | Purpose |
|---|---|
| `waypoint_data` | Waypoint paths used by `creature_addon.path_id` |
| `waypoint_scripts` | Scripts executed at waypoint arrival |
| `waypoints` | Alternative waypoint storage (`.wp` command output) |
| `script_waypoint` | Waypoints for C++ scripted creatures |

---

#### waypoint_data

| Column | Type | Description |
|---|---|---|
| `id` | INT UNSIGNED | Path ID; referenced by `creature_addon.path_id` |
| `point` | MEDIUMINT UNSIGNED | Sequential point number within the path (starts at 1) |
| `position_x` | FLOAT | X coordinate |
| `position_y` | FLOAT | Y coordinate |
| `position_z` | FLOAT | Z coordinate |
| `orientation` | FLOAT | Facing on arrival (NULL = face direction of travel) |
| `delay` | INT UNSIGNED | Wait time at this point in milliseconds |
| `move_type` | INT | 0=Walk, 1=Run, 2=Fly |
| `action` | INT | Waypoint script action ID to trigger |
| `action_chance` | SMALLINT | Probability (0-100) the action fires |
| `wpguid` | INT UNSIGNED | Internal: GUID of the visual waypoint marker (set by server) |

---

### Spell Override Tables

| Table | Purpose |
|---|---|
| `spell_proc` | Override proc behavior for spells |
| `spell_linked_spell` | Link spells to trigger/suppress other spells |
| `spell_group` | Assign spells to exclusive stacking groups |
| `spell_group_stack_rules` | Define stacking rules for spell groups |
| `spell_area` | Restrict/enable spells in specific areas |
| `spell_bonus_data` | Override SP/AP scaling coefficients |
| `spell_script_names` | Bind spell IDs to C++ spell script classes |
| `spell_target_position` | Teleport destination coordinates for summon/teleport spells |
| `spell_ranks` | First-rank spell chains |
| `spell_required` | Prerequisite spell requirements |
| `spell_pet_auras` | Pet aura applications tied to owner spells |
| `spell_dbc` | DBC field overrides for existing spells |
| `spell_cooldown_overrides` | Cooldown override values per spell |
| `spell_custom_attr` | Custom attribute flags for spells |
| `spell_threat` | Custom threat generation values for spells |
| `spell_mixology` | Mixology bonus overrides for alchemy spells |
| `spell_enchant_proc_data` | Enchant proc rate overrides |
| `spell_jump_distance` | Jump/charge distance overrides |

---

#### spell_proc

| Column | Type | Description |
|---|---|---|
| `SpellId` | INT SIGNED | Spell ID to override proc behavior |
| `SchoolMask` | TINYINT UNSIGNED | Triggering spell school bitmask |
| `SpellFamilyName` | SMALLINT UNSIGNED | Spell family filter |
| `SpellFamilyMask0`-`2` | INT UNSIGNED | Family spell mask filters |
| `ProcFlags` | INT UNSIGNED | Which events trigger the proc |
| `SpellTypeMask` | INT UNSIGNED | 1=Damage, 2=Heal, 4=No-damage-or-heal |
| `SpellPhaseMask` | INT UNSIGNED | 1=Cast, 2=Hit, 4=Finish |
| `HitMask` | INT UNSIGNED | Hit type conditions (normal hit, crit, dodge, etc.) |
| `AttributesMask` | INT UNSIGNED | Special proc behavior flags |
| `DisableEffectsMask` | INT UNSIGNED | Disable specific effects from proccing |
| `ProcsPerMinute` | FLOAT | PPM rate (0=use Chance instead) |
| `Chance` | FLOAT | Flat chance percentage |
| `Cooldown` | INT UNSIGNED | Internal proc cooldown in milliseconds |
| `Charges` | TINYINT UNSIGNED | Charge override |

---

#### spell_linked_spell

| Column | Type | Description |
|---|---|---|
| `spell_trigger` | MEDIUMINT SIGNED | Trigger spell ID; negative = on aura removal |
| `spell_effect` | MEDIUMINT SIGNED | Effect spell ID; negative = remove aura |
| `type` | SMALLINT UNSIGNED | 0=Cast link, 1=Hit link, 2=Aura link |
| `comment` | TEXT | Description |

---

### Map and Instance Tables

| Table | Purpose |
|---|---|
| `instance_template` | Instance script and mount permission settings |
| `instance_encounters` | Boss encounters for lockout tracking |
| `game_tele` | Named teleport locations (`.tele` command) |
| `graveyard_zone` | Graveyard assignments per zone |
| `game_graveyard` | Graveyard position definitions |
| `game_weather` | Zone weather definitions |

---

#### instance_template

| Column | Type | Description |
|---|---|---|
| `map` | SMALLINT UNSIGNED | Map ID (primary key) |
| `parent` | SMALLINT UNSIGNED | Parent map ID for sub-instances |
| `script` | VARCHAR(128) | Instance C++ script class name |
| `allowMount` | TINYINT UNSIGNED | 1 = allow mounting inside this instance |

---

### Event Tables

| Table | Purpose |
|---|---|
| `game_event` | Event definitions with scheduling |
| `game_event_creature` | Creatures spawned during an event |
| `game_event_gameobject` | GOs spawned during an event |
| `game_event_npc_vendor` | Extra vendor items during an event |
| `game_event_pool` | Spawn pools associated with events |
| `game_event_condition` | Completion conditions for events |
| `game_event_condition_save` | (characters DB) Runtime state |
| `game_event_quest_condition` | Quest-to-event condition mappings |
| `game_event_prerequisite` | Event prerequisites |

---

#### game_event

| Column | Type | Description |
|---|---|---|
| `eventEntry` | TINYINT UNSIGNED | Unique event ID (keep sequential, no gaps) |
| `start_time` | TIMESTAMP | When the event first becomes active |
| `end_time` | TIMESTAMP | When the event ends (NULL defaults to 2 years) |
| `occurence` | BIGINT UNSIGNED | Minutes between event occurrences (note: typo in schema, one 'r') |
| `length` | BIGINT UNSIGNED | Duration in minutes (must be < occurrence) |
| `holiday` | MEDIUMINT UNSIGNED | Holiday ID from Holidays.dbc for calendar display |
| `holidayStage` | TINYINT UNSIGNED | Holiday stage |
| `description` | VARCHAR(255) | Console display text when event starts/stops |
| `world_event` | TINYINT UNSIGNED | 0=normal, 1=world event |
| `announce` | TINYINT UNSIGNED | 0=silent, 1=always announce, 2=use config |

---

### Conditions System

The `conditions` table is a universal conditional logic layer that can gate nearly any game system.

#### conditions

| Column | Type | Description |
|---|---|---|
| `SourceTypeOrReferenceId` | MEDIUMINT SIGNED | Which system uses this condition (see SourceType list); negative = reference template |
| `SourceGroup` | MEDIUMINT UNSIGNED | Groups related conditions (e.g., gossip menu option ID) |
| `SourceEntry` | MEDIUMINT SIGNED | Specific entry within the source system |
| `SourceId` | INT SIGNED | For SmartAI: source_type; 0 for other systems |
| `ElseGroup` | MEDIUMINT UNSIGNED | Rows with same ElseGroup are OR'd; different groups are AND'd |
| `ConditionTypeOrReference` | MEDIUMINT SIGNED | What to check (see ConditionType list); negative = reference |
| `ConditionTarget` | TINYINT UNSIGNED | Which object to check (0=unit using item/spell, 1=target) |
| `ConditionValue1` | INT UNSIGNED | Primary parameter (varies by type) |
| `ConditionValue2` | INT UNSIGNED | Secondary parameter |
| `ConditionValue3` | INT UNSIGNED | Tertiary parameter |
| `NegativeCondition` | TINYINT UNSIGNED | 1 = invert the result |
| `ErrorType` | MEDIUMINT UNSIGNED | Error spell ID for player feedback (spell source only) |
| `ErrorTextId` | MEDIUMINT UNSIGNED | Error message ID |
| `ScriptName` | CHAR(64) | Optional script name |
| `Comment` | VARCHAR(255) | Documentation |

**SourceType values:**

| Value | System |
|---|---|
| 0 | Reference templates |
| 1-12 | Loot templates (creature, disenchant, fishing, gameobject, item, mail, milling, pickpocketing, prospecting, reference, skinning, spell) |
| 13 | SPELL_IMPLICIT_TARGET |
| 14 | GOSSIP_MENU |
| 15 | GOSSIP_MENU_OPTION |
| 16 | CREATURE_TEMPLATE_VEHICLE |
| 17 | SPELL |
| 18 | SPELL_CLICK_EVENT |
| 19 | QUEST_AVAILABLE |
| 21 | VEHICLE_SPELL |
| 22 | SMART_EVENT |
| 23 | NPC_VENDOR |
| 24 | SPELL_PROC |
| 28 | PLAYER_LOOT_TEMPLATE |
| 29 | CREATURE_VISIBILITY |

**ConditionType values:**

| Value | Condition |
|---|---|
| 1 | AURA — player has a specific aura |
| 2 | ITEM — player has N of item in inventory |
| 3 | ITEM_EQUIPPED — player has item equipped |
| 4 | ZONEID — player is in zone |
| 5 | REPUTATION_RANK — player has faction rank |
| 6 | TEAM — player is Horde or Alliance |
| 7 | SKILL — player has skill at rank |
| 8 | QUESTREWARDED — quest is completed |
| 9 | QUESTTAKEN — quest is in progress |
| 15 | CLASS — player is specific class |
| 16 | RACE — player is specific race |
| 17 | ACHIEVEMENT — achievement completed |
| 22 | MAPID — player is on map |
| 23 | AREAID — player is in sub-area |
| 25 | SPELL — player knows spell |
| 27 | LEVEL — player meets level requirement |
| 29 | NEAR_CREATURE — near creature by entry |
| 30 | NEAR_GAMEOBJECT — near GO by entry |
| 36 | ALIVE — unit is alive |
| 38 | HP_PCT — unit HP is at percentage |
| 43 | DAILY_QUEST_DONE — daily quest completed today |
| 46 | TAXI — player is on a taxi |
| 47 | QUESTSTATE — quest is in specific state |
| 49 | DIFFICULTY_ID — in specific instance difficulty |

---

### Achievement Tables

| Table | Purpose |
|---|---|
| `achievement_criteria_data` | Extra criteria conditions for achievements |
| `achievement_dbc` | DBC override data for achievements |
| `achievement_reward` | Item/spell/title rewards for achievements |
| `achievement_reward_locale` | Localized achievement reward data |

---

### Player Creation Tables

| Table | Purpose |
|---|---|
| `playercreateinfo` | Starting map, zone, and position per race/class |
| `playercreateinfo_action` | Default action bar layout per race/class |
| `playercreateinfo_item` | Starting inventory items per race/class |
| `playercreateinfo_skills` | Initial skills per race/class |
| `playercreateinfo_spell_custom` | Custom starting spells |
| `player_class_stats` | Base stat table per class per level |
| `player_race_stats` | Base stat modifiers per race per level |
| `player_xp_for_level` | XP thresholds per level |
| `player_levelstats` | Stat gains per level per race/class combination |
| `player_factionchange_*` | Faction change item/quest/reputation mappings |
| `player_totem_model` | Totem model IDs per race/element |

---

### Miscellaneous World Tables

| Table | Purpose |
|---|---|
| `dungeon_access_requirements` | Instance entry requirements (item level, quest, achievement) |
| `dungeon_access_template` | Instance access template definitions |
| `disables` | Disable system: turn off spells, maps, achievements, features |
| `page_text` | Readable book/letter page content |
| `page_text_locale` | Localized page text |
| `command` | GM command permission levels |
| `version` | Database version tracking |
| `updates` | Applied migration file list |
| `updates_include` | Migration include paths |
| `transports` | Moving transport (ship/zeppelin) paths |
| `pool_template` | Pool definitions for spawn rotation |
| `pool_creature` | Creatures in a spawn pool |
| `pool_gameobject` | GOs in a spawn pool |
| `pool_pool` | Nested pool definitions |
| `pool_quest` | Quests in a daily quest pool |
| `creature_template_locale` | Localized creature names and subtitles |
| `gameobject_template_locale` | Localized GO names |
| `item_template_locale` | Localized item names/descriptions |
| `npc_text_locale` | Localized NPC dialogue |
| `page_text_locale` | Localized page text |
| `quest_template_locale` | Localized quest text |
| `achievement_reward_locale` | Localized achievement reward text |
| `broadcast_text_locale` | Localized broadcast text |
| `gossip_menu_option_locale` | Localized gossip options |
| `points_of_interest_locale` | Localized POI names |
| `points_of_interest` | Map POI marker definitions |
| `spell_area` | Area-specific spell grants/removals |
| `warden_checks` | Anti-cheat Warden check definitions |
| `module_string` | Module-defined string resources |
| `module_string_locale` | Localized module strings |

---

## Custom Project Data (dreamforge_ prefix)

All Dreamforge custom tables live inside `acore_world` with a `dreamforge_` prefix. No separate database. This keeps everything in one connection and survives worldserver restarts without extra configuration.

**Naming convention:** `dreamforge_<purpose>` — e.g. `dreamforge_player_data`, `dreamforge_reputation`.

**Access from C++ (module code):**
```cpp
// Read
QueryResult result = WorldDatabase.Query("SELECT value FROM dreamforge_player_data WHERE guid = {}", guid);

// Write
WorldDatabase.Execute("INSERT INTO dreamforge_player_data (guid, key_name, value_int) VALUES ({}, '{}', {})", guid, key, val);
```

**Access from Eluna (Lua scripts):**
```lua
-- WorldDatabase maps to acore_world
local result = WorldDBQuery("SELECT value_str FROM dreamforge_player_data WHERE guid = " .. guid .. " AND key_name = 'points'")
if result then
    local val = result:GetString(0)
end
```

**Example table definitions:**
```sql
-- Persistent per-player key/value store
CREATE TABLE IF NOT EXISTS dreamforge_player_data (
    guid         INT UNSIGNED     NOT NULL,
    key_name     VARCHAR(64)      NOT NULL,
    value_str    VARCHAR(255)     DEFAULT NULL,
    value_int    INT SIGNED       DEFAULT NULL,
    updated_at   TIMESTAMP        DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (guid, key_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Custom faction/reputation tracking
CREATE TABLE IF NOT EXISTS dreamforge_reputation (
    guid         INT UNSIGNED      NOT NULL,
    faction_id   SMALLINT UNSIGNED NOT NULL,
    value        INT SIGNED        NOT NULL DEFAULT 0,
    PRIMARY KEY (guid, faction_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

Tables are created via SQL migration files in `acore_source/data/sql/custom/` and loaded at startup.

---

## Database Modification Best Practices

### SQL Update File Naming

AzerothCore migration files follow the naming convention used in `data/sql/updates/`:

```
rev_YYYYMMDDHHMMSS_description.sql
# Example:
rev_20240315143000_add_custom_boss_spawns.sql
```

Never modify existing migration files. Always create new ones. The `updates` table tracks which files have been applied; the server will skip already-applied files at startup.

### Safe Custom Data Insertion

```sql
-- Safe insert: skip if entry already exists
INSERT IGNORE INTO acore_world.creature_template (entry, name, ...) VALUES (900001, 'My NPC', ...);

-- Safe upsert: insert or update on conflict
INSERT INTO acore_world.npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost)
VALUES (900001, 0, 35000, 0, 0, 0)
ON DUPLICATE KEY UPDATE maxcount = VALUES(maxcount);

-- Safe delete-then-insert pattern for replacing a full set
DELETE FROM acore_world.smart_scripts WHERE entryorguid = 900001 AND source_type = 0;
INSERT INTO acore_world.smart_scripts (entryorguid, source_type, id, ...) VALUES
(900001, 0, 0, ...),
(900001, 0, 1, ...);
```

### Custom Entry ID Ranges

Use high entry IDs to avoid conflicts with Blizzard content and upstream AzerothCore data:

| Content Type | Safe Custom Range |
|---|---|
| `creature_template.entry` | 900000-999999 |
| `item_template.entry` | 900000-999999 |
| `quest_template.ID` | 90000-99999 |
| `gameobject_template.entry` | 900000-999999 |
| `spell_dbc.Id` (spell override) | 900000-999999 |
| `gossip_menu.MenuID` | 90000-99999 |
| `npc_text.ID` | 900000-999999 |
| `creature.guid` (spawns) | Auto-increment; do not hard-code |

### Transaction Safety

Always wrap multi-table operations in transactions:

```sql
START TRANSACTION;

INSERT INTO acore_world.creature_template (entry, name, minlevel, maxlevel, faction, ...)
VALUES (900001, 'Dreamforge Guardian', 80, 80, 14, ...);

INSERT INTO acore_world.creature (id1, map, position_x, position_y, position_z, orientation, spawntimesecs)
VALUES (900001, 0, -8949.95, -132.49, 83.5312, 0.0, 300);

INSERT INTO acore_world.smart_scripts (entryorguid, source_type, id, event_type, action_type, comment)
VALUES (900001, 0, 0, 4, 1, 'Dreamforge Guardian - On Aggro - Talk');

COMMIT;
```

### INSERT IGNORE vs ON DUPLICATE KEY UPDATE

- Use `INSERT IGNORE` when adding new records that should not overwrite existing custom data.
- Use `ON DUPLICATE KEY UPDATE` when you want to update values while keeping existing rows.
- Prefer explicit column lists over `INSERT INTO table VALUES (...)` to survive future schema changes.

---

## Key Relationships and Foreign Keys

AzerothCore does not use foreign key constraints (for performance reasons), but logical relationships exist throughout:

### Creature Chain

```
creature_template.entry
  ├── creature.id1                        (spawns using this template)
  ├── smart_scripts.entryorguid           (scripts for this template)
  ├── npc_vendor.entry                    (vendor inventory)
  ├── creature_queststarter.id            (quests offered)
  ├── creature_questender.id              (quests completed)
  ├── creature_loot_template.Entry        (= creature_template.lootid)
  ├── pickpocketing_loot_template.Entry   (= creature_template.pickpocketloot)
  ├── skinning_loot_template.Entry        (= creature_template.skinloot)
  ├── creature_addon.entry                (visual overrides)
  ├── creature_equip_template.CreatureID  (equipment)
  └── creature_onkill_reputation.creature_id
```

### Item Chain

```
item_template.entry
  ├── item_instance.itemEntry             (all instances of this item)
  ├── character_inventory.item → item_instance.guid
  ├── creature_loot_template.Item         (appears in creature loot)
  ├── npc_vendor.item                     (sold by vendors)
  ├── quest_template.RewardItem*          (quest reward)
  ├── quest_template.RequiredItemId*      (quest requirement)
  ├── disenchant_loot_template.Entry      (= item_template.DisenchantID)
  └── item_loot_template.Entry            (= item_template.entry for containers)
```

### Quest Chain

```
quest_template.ID
  ├── character_queststatus.quest         (in-progress state)
  ├── character_queststatus_rewarded.quest
  ├── creature_queststarter.quest         (which NPCs offer it)
  ├── creature_questender.quest           (which NPCs complete it)
  ├── gameobject_queststarter.quest
  ├── gameobject_questender.quest
  ├── quest_template.RewardNextQuest      (→ next quest_template.ID)
  ├── conditions (SourceType=19)          (QUEST_AVAILABLE conditions)
  └── areatrigger_involvedrelation.quest
```

### SmartAI Chain

```
smart_scripts.entryorguid (positive)  →  creature_template.entry
smart_scripts.entryorguid (negative)  →  creature.guid (specific spawn)
smart_scripts.source_type = 1         →  gameobject_template.entry
smart_scripts.action_type = 1         →  creature_text.CreatureID / GroupID
smart_scripts.action_type = 11        →  spell IDs
smart_scripts.action_type = 66        →  waypoint_data.id (path)
```

### Loot Reference Chain

```
creature_loot_template.Item (negative)
  └── reference_loot_template.Entry     (shared loot list)
        └── reference_loot_template.Item → item_template.entry
```

### Character Data Chain

```
characters.guid
  ├── character_inventory.guid
  │     └── character_inventory.item → item_instance.guid
  ├── character_aura.guid
  ├── character_spell.guid
  ├── character_talent.guid
  ├── character_skills.guid
  ├── character_queststatus.guid
  ├── character_reputation.guid
  ├── character_achievement.guid
  ├── character_glyphs.guid
  ├── character_homebind.guid
  ├── character_social.guid
  ├── guild_member.guid → guild.guildid
  ├── arena_team_member.guid → arena_team.arenateamid
  └── mail.receiver (→ characters.guid)
```

---

## Reload Commands Reference

Most world DB tables can be reloaded live without restarting the worldserver:

```
.reload all_scripts          -- Reload all script tables
.reload creature_linked_respawn
.reload creature_loot_template
.reload gameobject_loot_template
.reload item_template
.reload quest_template
.reload smart_scripts
.reload spell_area
.reload spell_linked_spell
.reload spell_proc
.reload waypoints            -- Reload waypoint_data
.reload npc_vendor
.reload trainer
.reload conditions
.reload game_event
.reload areatrigger_teleport
.reload disables
.reload creature_template_locale
.reload gameobject_template_locale
.reload item_template_locale
.reload quest_template_locale
```

**Note:** Some tables (e.g., `creature_template`, `item_template`) require a full server restart or use of `.reload` with caution — reloading templates does not update already-spawned creatures in memory. Use `.respawn` on specific creatures or restart the worldserver to apply template changes fully.

```sql
-- After adding a new creature spawn, force server to load it:
-- In-game: .npc add <entry>  (places at GM position)
-- Or: .reload creature_linked_respawn then /reload
```

---

## Cross-References

| Topic | See Also |
|---|---|
| SmartAI event/action constants | `kb_azerothcore_dev.md` — SmartAI section |
| Eluna DB query API | `kb_eluna_api.md` — Database query methods |
| C++ module hooks | `kb_azerothcore_dev.md` — Hook reference |
| Creature script base classes | `kb_azerothcore_dev.md` — Script base classes |
| Custom Eluna data storage | `kb_eluna_api.md` — Persistent data patterns |
| DBC file formats and tools | `kb_file_formats.md` |
| Faction template IDs | FactionTemplate.dbc / in-game `.lookup faction` |
| Spell IDs | SpellWork tool or `spell_dbc` table |
| Map IDs | Maps.dbc or `.tele` command list |
| Official wiki | https://www.azerothcore.org/wiki/ |
| Database-world table list | https://www.azerothcore.org/wiki/database-world |
| Database-characters table list | https://www.azerothcore.org/wiki/database-characters |
| Database-auth table list | https://www.azerothcore.org/wiki/database-auth |
