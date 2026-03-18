# Database Access

This document covers all patterns for accessing databases from AzerothCore C++ modules. Every source reference is drawn from the live codebase.

---

## 1. The Three Database Globals

```cpp
#include "DatabaseEnv.h"
```

`DatabaseEnv.h` is the single include that provides all three globals, the prepared statement types, query result types, and transaction helpers. Include it in every file that touches the database.

```
// From src/server/database/Database/DatabaseEnv.h
AC_DATABASE_API extern DatabaseWorkerPool<WorldDatabaseConnection>     WorldDatabase;
AC_DATABASE_API extern DatabaseWorkerPool<CharacterDatabaseConnection> CharacterDatabase;
AC_DATABASE_API extern DatabaseWorkerPool<LoginDatabaseConnection>     LoginDatabase;
```

### WorldDatabase — `acore_world`

Game content. Static reference data that ships with the server. Read often, written infrequently (mostly by GM commands or startup scripts).

**Read from a module:**
- `creature_template` — creature stats, name, level ranges, faction
- `item_template` — item stats, flags, spell triggers
- `quest_template` — quest data
- `gameobject_template` — GO types and data fields
- `spell_script_names`, `smart_scripts` — scripting assignments
- `npc_vendor`, `npc_trainer` — vendor/trainer content
- Custom `dreamforge_*` tables you create here

**Write from a module:**
- Only when you're creating or modifying world content at runtime (e.g., a command that adds a waypoint). Never write to DBC-mirror tables.

### CharacterDatabase — `acore_characters`

Per-player runtime state. Changes frequently. This is where all player progress lives.

**Read/write from a module:**
- `characters` — base character row (level, position, money, etc.)
- `character_aura` — active auras
- `character_spell` — known spells
- `character_queststatus`, `character_queststatus_rewarded` — quest progress
- `character_inventory`, `item_instance` — items
- `character_achievement`, `character_achievement_criteria_progress` — achievements
- Custom `dreamforge_*` player data tables you create here

**Write from a module:**
- On `OnLogin`, `OnLogout`, `OnSave` hooks to persist custom player data.
- Always use transactions when writing multiple related rows.

### LoginDatabase — `acore_auth`

Account-level data. Authentication, realm list, account bans. You rarely need to touch this from a module — only for account-level features like per-account settings.

**Do not write to LoginDatabase unless you have a genuine account-level feature.** Account bans, IP restrictions, and auth tokens live here.

---

## 2. Query Types — Overview

| Method | Blocks? | Returns result? | When to use |
|---|---|---|---|
| `Query(sql)` | Yes | Yes | Startup loading, GM commands, initialization |
| `Query(stmt)` | Yes | Yes | Same as above, with prepared statements |
| `Execute(sql)` | No (async) | No | Fire-and-forget writes during gameplay |
| `Execute(stmt)` | No (async) | No | Same as above, prepared |
| `DirectExecute(sql)` | Yes | No | Writes during startup that must complete before continuing |
| `AsyncQuery(sql)` | No | Via callback | Heavy reads that should not stall the world thread |
| `BeginTransaction` / `CommitTransaction` | No | No | Grouping multiple writes atomically |

**The golden rule for modules:**
- **Startup / map load / `OnServerStartup`**: use synchronous `Query()` and `DirectExecute()` — blocking is acceptable here.
- **Gameplay events (`OnLogin`, `OnKill`, `OnSpellCast`, etc.)**: use async `Execute()` for writes (fire-and-forget). For reads that must return data, use `Query()` sparingly, or `AsyncQuery()` with a callback.
- **Never block a packet handler or a map update for a synchronous database call** unless you are certain the query is trivial. Each synchronous query ties up a sync connection slot.

---

## 3. Raw (Ad-Hoc) Query — Complete Pattern

Raw queries use `Acore::StringFormat` internally (fmtlib `{}` style). The format arguments are substituted before the string reaches MySQL — they are **not** parameterized. This means the caller is responsible for escaping string values. For anything user-supplied, always use prepared statements instead.

### Single-row SELECT

```cpp
#include "DatabaseEnv.h"

void LoadCreatureInfo(uint32 entryId)
{
    QueryResult result = WorldDatabase.Query(
        "SELECT entry, name, minlevel, maxlevel FROM creature_template WHERE entry = {}",
        entryId
    );

    if (!result)
        return; // no rows

    Field* fields = result->Fetch();
    uint32 entry    = fields[0].Get<uint32>();
    std::string name = fields[1].Get<std::string>();
    uint8 minLevel  = fields[2].Get<uint8>();
    uint8 maxLevel  = fields[3].Get<uint8>();

    // use values...
}
```

### Multi-row SELECT

```cpp
void LoadAllDreamforgeData()
{
    QueryResult result = WorldDatabase.Query(
        "SELECT guid, score, last_seen FROM dreamforge_players"
    );

    if (!result)
        return;

    do
    {
        Field* fields = result->Fetch();
        uint32 guid    = fields[0].Get<uint32>();
        uint32 score   = fields[1].Get<uint32>();
        std::string ts = fields[2].Get<std::string>();

        // store or process...

    } while (result->NextRow());
}
```

### FetchTuple — compact alternative

When you know the exact column types, `FetchTuple<>` reads all fields in one call:

```cpp
QueryResult result = WorldDatabase.Query(
    "SELECT entry, name FROM creature_template WHERE entry = {}", entryId
);
if (!result)
    return;

auto [entry, name] = result->FetchTuple<uint32, std::string>();
```

### Range-based for loop (C++17)

`ResultSet` implements `begin()`/`end()` iterators. This advances `NextRow()` automatically:

```cpp
QueryResult result = WorldDatabase.Query("SELECT entry, name FROM creature_template LIMIT 100");
if (!result)
    return;

for (auto& row : *result)
{
    uint32 entry     = row[0].Get<uint32>();
    std::string name = row[1].Get<std::string>();
}
```

Note: `row[n]` is equivalent to `result->Fetch()[n]`.

### All Field::Get<T>() types

From `Field.h` — the template is enabled for each of these:

| C++ type | `Get<T>()` call | MySQL column types |
|---|---|---|
| `bool` | `Get<bool>()` | `TINYINT(1)` |
| `uint8` | `Get<uint8>()` | `TINYINT UNSIGNED` |
| `uint16` | `Get<uint16>()` | `SMALLINT UNSIGNED` |
| `uint32` | `Get<uint32>()` | `MEDIUMINT UNSIGNED`, `INT UNSIGNED` |
| `uint64` | `Get<uint64>()` | `BIGINT UNSIGNED` |
| `int8` | `Get<int8>()` | `TINYINT` |
| `int16` | `Get<int16>()` | `SMALLINT` |
| `int32` | `Get<int32>()` | `MEDIUMINT`, `INT` |
| `int64` | `Get<int64>()` | `BIGINT` |
| `float` | `Get<float>()` | `FLOAT` |
| `double` | `Get<double>()` | `DOUBLE`, `DECIMAL` |
| `std::string` | `Get<std::string>()` | `CHAR`, `VARCHAR`, `TEXT*`, `BLOB*` |
| `std::string_view` | `Get<std::string_view>()` | Same as above; valid only while result is alive |
| `Binary` (`std::vector<uint8>`) | `Get<Binary>()` | `BINARY`, `VARBINARY`, `BLOB*` |

**Aggregate function return types** (from `Field.h` comments):
- `MIN`, `MAX` — same type as the column
- `SUM`, `AVG` — `DECIMAL` — use `Get<double>()`
- `COUNT` — `BIGINT` — use `Get<uint64>()`

**Null check:** Always call `fields[n].IsNull()` before `Get<T>()` if the column is nullable and you need to distinguish NULL from zero/empty.

```cpp
if (!fields[2].IsNull())
    subname = fields[2].Get<std::string>();
```

---

## 4. Prepared Statements — Complete Pattern

Prepared statements are the **preferred approach** for any query that runs repeatedly during gameplay. Benefits:
- SQL injection is impossible — parameters are transmitted separately from query text
- The MySQL server parses and compiles the query once, then reuses the plan
- Type safety at the C++ level

### Step 1 — Declare the enum in your module header

Create a header for your module's statement IDs. Use the naming convention `{DB}_{SEL/INS/UPD/DEL/REP}_{Description}`.

```cpp
// modules/mod-dreamforge/src/DreamforgeDB.h
#pragma once
#include "MySQLConnection.h"

enum DreamforgeWorldStatements : uint32
{
    // Reads
    WORLD_SEL_DREAMFORGE_PLAYER,
    WORLD_SEL_DREAMFORGE_PLAYER_ALL,

    // Writes
    WORLD_REP_DREAMFORGE_PLAYER,    // REPLACE INTO
    WORLD_DEL_DREAMFORGE_PLAYER,

    MAX_DREAMFORGE_WORLD_STATEMENTS
};

enum DreamforgeCharStatements : uint32
{
    CHAR_SEL_DREAMFORGE_CUSTOM_DATA,
    CHAR_REP_DREAMFORGE_CUSTOM_DATA,
    CHAR_DEL_DREAMFORGE_CUSTOM_DATA,

    MAX_DREAMFORGE_CHAR_STATEMENTS
};
```

### Step 2 — Register statements at startup

Register in your module's `OnServerStartup` hook (or equivalent init function). The enum values from your module-local enum are cast to the global `WorldDatabaseStatements` / `CharacterDatabaseStatements` types via the `PreparedStatementIndex` typedef. Since modules can't add values to the core enum, there's a practical workaround: use raw queries for module-local tables, or cast past `MAX_WORLDDATABASE_STATEMENTS`.

The simplest production pattern is to register using the core's own `PrepareStatement` method by passing your enum values cast to the correct type. This works because `PreparedStatementIndex` is just `uint32` under the hood. **However**, you must ensure your enum values do not collide with core values. The safest approach: store your statements separately and call `WorldDatabase.PrepareStatements()` after adding them through the connection's `DoPrepareStatements` override. In practice, **most module authors simply use ad-hoc queries for module-local tables** and reserve prepared statements for queries against core tables.

The correct module pattern for WorldDatabase prepared statements:

```cpp
// In your module's loader or script init:
void RegisterDreamforgeStatements()
{
    // PrepareStatement signature: (index, sql, connectionFlags)
    // CONNECTION_SYNCH  — available to synchronous Query() calls
    // CONNECTION_ASYNC  — available to asynchronous Execute() and AsyncQuery() calls
    // Both flags may be OR'd together if needed on both connection types.

    WorldDatabase.PrepareStatement(
        WORLD_SEL_DREAMFORGE_PLAYER,
        "SELECT guid, score, title, last_seen FROM dreamforge_players WHERE guid = ?",
        CONNECTION_SYNCH
    );

    WorldDatabase.PrepareStatement(
        WORLD_REP_DREAMFORGE_PLAYER,
        "REPLACE INTO dreamforge_players (guid, score, title, last_seen) VALUES (?, ?, ?, NOW())",
        CONNECTION_ASYNC
    );

    CharacterDatabase.PrepareStatement(
        CHAR_SEL_DREAMFORGE_CUSTOM_DATA,
        "SELECT data_key, data_value FROM dreamforge_char_data WHERE guid = ?",
        CONNECTION_SYNCH
    );

    CharacterDatabase.PrepareStatement(
        CHAR_REP_DREAMFORGE_CUSTOM_DATA,
        "REPLACE INTO dreamforge_char_data (guid, data_key, data_value) VALUES (?, ?, ?)",
        CONNECTION_ASYNC
    );
}
```

`CONNECTION_SYNCH` statements can only be used with `WorldDatabase.Query(stmt)` (blocking).
`CONNECTION_ASYNC` statements can only be used with `WorldDatabase.Execute(stmt)` or `WorldDatabase.AsyncQuery(stmt)`.
If you use a `CONNECTION_ASYNC` statement with `Query()`, the server will assert/crash.

### Step 3 — Execute a synchronous prepared SELECT

```cpp
void LoadDreamforgePlayer(uint32 playerGuid)
{
    // GetPreparedStatement returns a fresh PreparedStatement* object.
    // It is NOT tied to MySQL yet — just a parameter buffer.
    // Memory is managed internally; do NOT delete it yourself.
    PreparedStatement* stmt = WorldDatabase.GetPreparedStatement(WORLD_SEL_DREAMFORGE_PLAYER);
    stmt->SetData(0, playerGuid); // index 0 = first '?'

    PreparedQueryResult result = WorldDatabase.Query(stmt);
    if (!result)
        return; // no row for this guid

    Field* fields = result->Fetch();
    uint32 guid   = fields[0].Get<uint32>();
    uint32 score  = fields[1].Get<uint32>();
    std::string title = fields[2].Get<std::string>();
    // fields[3] is last_seen — string or use Get<std::string>()
}
```

### SetData — all supported types

`SetData(uint8 index, T value)` accepts the following `T`:

| Type | Notes |
|---|---|
| `bool` | Stored as TINYINT |
| `uint8`, `uint16`, `uint32`, `uint64` | Unsigned integers |
| `int8`, `int16`, `int32`, `int64` | Signed integers |
| `float`, `double` | Floating point |
| `std::string_view`, `std::string` | Strings (copied internally) |
| `std::vector<uint8>` (`Binary`) | Raw binary blobs |
| `std::array<uint8, N>` | Fixed-size binary |
| `std::chrono::duration<...>` | Stored as uint32 seconds by default |
| Any `enum` type | Underlying integer type is used automatically |
| `nullptr` / `std::nullptr_t` | Stores SQL NULL |

**SetArguments** — set all parameters at once:

```cpp
stmt->SetArguments(playerGuid, score, title);
// equivalent to:
// stmt->SetData(0, playerGuid);
// stmt->SetData(1, score);
// stmt->SetData(2, title);
```

### CONNECTION_SYNCH vs CONNECTION_ASYNC

```
CONNECTION_SYNCH
  Used by: WorldDatabase.Query(stmt)
           WorldDatabase.DirectExecute(stmt)
  Thread:  Blocks the calling thread until MySQL returns.
  Pool:    Uses the synchronous connection pool (separate from async pool).
  When:    Startup loading, GM commands, any place where you need the result
           before proceeding.

CONNECTION_ASYNC
  Used by: WorldDatabase.Execute(stmt)
           WorldDatabase.AsyncQuery(stmt)
  Thread:  Enqueues to the async worker thread; returns immediately.
  Pool:    Uses the async connection pool.
  When:    Gameplay writes (OnLogin saves, OnKill updates, periodic flushes).
           The calling thread never blocks.
```

---

## 5. Execute — INSERT / UPDATE / DELETE

For writes that don't return a result set, use `Execute()` (async, preferred during gameplay) or `DirectExecute()` (synchronous, for startup).

### Ad-hoc Execute (format string)

```cpp
// Async — fire and forget. Preferred for gameplay writes.
WorldDatabase.Execute(
    "UPDATE dreamforge_players SET score = score + {} WHERE guid = {}",
    points, playerGuid
);

// Synchronous — blocks until complete. Only use at startup.
WorldDatabase.DirectExecute(
    "INSERT IGNORE INTO dreamforge_players (guid, score) VALUES ({}, 0)",
    playerGuid
);
```

**Warning:** String arguments in format-string queries are NOT escaped by the format call. If any argument comes from user input (player name, chat text), use `WorldDatabase.EscapeString(str)` first, or use a prepared statement.

### Prepared Execute

```cpp
// Async prepared execute — preferred for gameplay
PreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_REP_DREAMFORGE_CUSTOM_DATA);
stmt->SetData(0, playerGuid);
stmt->SetData(1, std::string("points"));
stmt->SetData(2, std::to_string(score));
CharacterDatabase.Execute(stmt); // enqueues; returns immediately

// Synchronous prepared execute — for startup only
PreparedStatement* stmt2 = WorldDatabase.GetPreparedStatement(WORLD_REP_DREAMFORGE_PLAYER);
stmt2->SetData(0, playerGuid);
stmt2->SetData(1, score);
stmt2->SetData(2, titleString);
WorldDatabase.DirectExecute(stmt2);
```

### ExecuteOrAppend — write to a transaction if one exists

```cpp
void SavePlayerData(Player* player, SQLTransaction<CharacterDatabaseConnection>* trans = nullptr)
{
    PreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_REP_DREAMFORGE_CUSTOM_DATA);
    stmt->SetData(0, player->GetGUID().GetCounter());
    stmt->SetData(1, std::string("score"));
    stmt->SetData(2, std::to_string(GetPlayerScore(player)));

    if (trans)
        CharacterDatabase.ExecuteOrAppend(*trans, stmt);
    else
        CharacterDatabase.Execute(stmt);
}
```

---

## 6. Transactions

Transactions group multiple statements into a single atomic operation. If any statement fails, all are rolled back. Always use transactions when writing more than one logically related row.

**The transaction object is a `std::shared_ptr<Transaction<T>>`** — aliased as:
- `CharacterTransaction` = `SQLTransaction<CharacterDatabaseConnection>`
- `WorldTransaction` = `SQLTransaction<WorldDatabaseConnection>`

### Basic pattern

```cpp
void SavePlayerOnLogout(Player* player)
{
    uint32 guid = player->GetGUID().GetCounter();

    CharacterTransaction trans = CharacterDatabase.BeginTransaction();

    // Statement 1: upsert core row
    PreparedStatement* stmt1 = CharacterDatabase.GetPreparedStatement(CHAR_REP_DREAMFORGE_CUSTOM_DATA);
    stmt1->SetData(0, guid);
    stmt1->SetData(1, std::string("score"));
    stmt1->SetData(2, std::to_string(GetPlayerScore(player)));
    trans->Append(stmt1);

    // Statement 2: timestamp
    PreparedStatement* stmt2 = CharacterDatabase.GetPreparedStatement(CHAR_REP_DREAMFORGE_CUSTOM_DATA);
    stmt2->SetData(0, guid);
    stmt2->SetData(1, std::string("last_logout"));
    stmt2->SetData(2, std::to_string(GameTime::GetGameTime().count()));
    trans->Append(stmt2);

    // Ad-hoc string also works:
    trans->Append("UPDATE dreamforge_players SET logins = logins + 1 WHERE guid = {}", guid);

    // Enqueue for async execution (does not block)
    CharacterDatabase.CommitTransaction(trans);
}
```

### Synchronous commit (startup only)

```cpp
WorldTransaction trans = WorldDatabase.BeginTransaction();
// ... append statements ...
WorldDatabase.DirectCommitTransaction(trans); // blocks until committed
```

### Async commit with result callback

```cpp
CharacterTransaction trans = CharacterDatabase.BeginTransaction();
// ... append statements ...

TransactionCallback callback = CharacterDatabase.AsyncCommitTransaction(trans);
callback.AfterComplete([](bool success)
{
    if (!success)
        LOG_ERROR("module.dreamforge", "Transaction failed!");
});
// Store callback somewhere that calls InvokeIfReady() on update tick,
// or use AddQueryCallback if available in your context.
```

### How many statements per transaction?

There's no hard limit but be sensible. One transaction per meaningful logical unit (e.g., all data for one player logout). Do not batch data for different players into one transaction — a failure would roll back all of them.

---

## 7. Custom Tables — The `dreamforge_` Prefix in `acore_world`

### The constraint

You cannot use `WorldDatabase` or `CharacterDatabase` to query the `claude_eluna` database. The `DatabaseWorkerPool` connects to a single database determined at startup via the connection string in `worldserver.conf`. You cannot switch databases mid-query with `USE claude_eluna`.

### The correct approach for Dreamforge modules

**Store all custom data in `acore_world` or `acore_characters` using a `dreamforge_` prefix.**

```sql
-- Example: in acore_world (for server-wide data, config, unlocks)
CREATE TABLE IF NOT EXISTS `dreamforge_players` (
    `guid`        INT UNSIGNED NOT NULL,
    `score`       INT UNSIGNED NOT NULL DEFAULT 0,
    `title`       VARCHAR(64) NOT NULL DEFAULT '',
    `tokens`      INT UNSIGNED NOT NULL DEFAULT 0,
    `last_seen`   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                  ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Example: in acore_characters (for per-character data that must survive character moves)
CREATE TABLE IF NOT EXISTS `dreamforge_char_data` (
    `guid`        INT UNSIGNED NOT NULL,
    `data_key`    VARCHAR(64) NOT NULL,
    `data_value`  TEXT NOT NULL,
    PRIMARY KEY (`guid`, `data_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

The `dreamforge_players` table goes in `acore_world` because it is server-wide static/aggregated data. The `dreamforge_char_data` table goes in `acore_characters` because it is per-character and may need to be consistent with character state.

### Rule: never pollute core tables

Do not add columns to `characters`, `creature_template`, or any other core table. If you need extra data on a character, put it in a separate `dreamforge_*` table keyed by `guid`.

---

## 8. QueryCallback — Async Pattern

Use async queries when you want to avoid blocking the world thread for a read. The result arrives on the DB worker thread and the callback fires when the main loop processes it.

### Ad-hoc async query

```cpp
// Returns a QueryCallback; must be registered with a callback processor or
// stored and polled via InvokeIfReady().
QueryCallback cb = WorldDatabase.AsyncQuery(
    "SELECT score FROM dreamforge_players WHERE guid = {}",
    playerGuid
);
cb.WithCallback([playerGuid](QueryResult result)
{
    if (!result)
        return;

    Field* fields = result->Fetch();
    uint32 score = fields[0].Get<uint32>();

    // WARNING: you are now on the DB worker thread (or callback dispatch thread).
    // You CANNOT safely access Player*, Creature*, Map*, or any game object here.
    // Schedule a delayed event or use the world update queue to re-enter safely.
    LOG_DEBUG("module.dreamforge", "Loaded score {} for guid {}", score, playerGuid);
});
```

### Prepared async query

```cpp
PreparedStatement* stmt = WorldDatabase.GetPreparedStatement(WORLD_SEL_DREAMFORGE_PLAYER);
stmt->SetData(0, playerGuid);

QueryCallback cb = WorldDatabase.AsyncQuery(stmt);
cb.WithPreparedCallback([](PreparedQueryResult result)
{
    if (!result)
        return;
    Field* fields = result->Fetch();
    // process...
});
```

### How QueryCallback is actually consumed

In AzerothCore, `QueryCallback` objects are typically stored in a `QueryCallbackProcessor` (or equivalent container) and polled on each world update tick. In WorldSession, this is done via `_queryProcessor`. If you need async DB in a player hook, the cleanest pattern is:

```cpp
// In a PlayerScript or SessionScript that has access to WorldSession:
_session->_queryProcessor.AddCallback(
    CharacterDatabase.AsyncQuery(stmt)
        .WithPreparedCallback([this](PreparedQueryResult result) {
            // Still on callback thread — schedule a world event
        })
);
```

For standalone module hooks (not on a session), the easiest safe pattern is to use `Execute()` for writes (you don't need the result) and synchronous `Query()` for reads at login/logout time (acceptable blocking cost). Reserve true async for heavy batch reads at startup.

### Thread safety rules for async callbacks

**You CAN safely do in an async callback:**
- Read from the `PreparedQueryResult` / `QueryResult` — it's yours until callback exits
- Write to a local variable or a thread-safe container (e.g., `std::atomic`, mutex-protected map)
- Call `LOG_*` macros — they are thread-safe
- Schedule a task via a lock-free queue back to the world thread

**You MUST NOT do in an async callback:**
- Dereference `Player*`, `Creature*`, `Unit*`, `Map*`, or any game object pointer — the object may have been deleted
- Call any method on `WorldSession*`
- Access `sObjectMgr`, `sSpellMgr`, or most singletons that have internal non-thread-safe state
- Send packets, add auras, give items, or trigger any game event

The safe pattern for "read DB then act on player" is:
1. Start async query
2. In callback, copy the data into a capture or a session-safe queue
3. On the next world update tick (map update, player update), retrieve queued data and act

---

## 9. Real Examples for Common Module Tasks

### Example 1: Save custom player data on logout (REPLACE INTO)

```cpp
class DreamforgePlayerScript : public PlayerScript
{
public:
    DreamforgePlayerScript() : PlayerScript("DreamforgePlayerScript") {}

    void OnLogout(Player* player) override
    {
        uint32 guid  = player->GetGUID().GetCounter();
        uint32 score = GetDreamforgeScore(player); // your lookup

        CharacterTransaction trans = CharacterDatabase.BeginTransaction();

        // REPLACE INTO handles both insert and update atomically
        PreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_REP_DREAMFORGE_CUSTOM_DATA);
        stmt->SetData(0, guid);
        stmt->SetData(1, std::string("score"));
        stmt->SetData(2, std::to_string(score));
        trans->Append(stmt);

        PreparedStatement* stmt2 = CharacterDatabase.GetPreparedStatement(CHAR_REP_DREAMFORGE_CUSTOM_DATA);
        stmt2->SetData(0, guid);
        stmt2->SetData(1, std::string("last_logout"));
        stmt2->SetData(2, std::to_string(GameTime::GetGameTime().count()));
        trans->Append(stmt2);

        CharacterDatabase.CommitTransaction(trans);
    }
};
```

Corresponding SQL:
```sql
-- In modules/mod-dreamforge/sql/base/db_characters/dreamforge_char_data.sql
CREATE TABLE IF NOT EXISTS `dreamforge_char_data` (
    `guid`       INT UNSIGNED NOT NULL,
    `data_key`   VARCHAR(64)  NOT NULL,
    `data_value` TEXT         NOT NULL,
    PRIMARY KEY (`guid`, `data_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### Example 2: Load custom player data on login (SELECT)

```cpp
void OnLogin(Player* player) override
{
    uint32 guid = player->GetGUID().GetCounter();

    PreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_DREAMFORGE_CUSTOM_DATA);
    stmt->SetData(0, guid);

    PreparedQueryResult result = CharacterDatabase.Query(stmt);
    if (!result)
        return; // new player, no data yet — use defaults

    do
    {
        Field* fields = result->Fetch();
        std::string key   = fields[0].Get<std::string>();
        std::string value = fields[1].Get<std::string>();

        if (key == "score")
            SetDreamforgeScore(player, std::stoul(value));
        else if (key == "title")
            SetDreamforgeTitle(player, value);

    } while (result->NextRow());
}
```

### Example 3: Query creature_template for a specific entry

```cpp
std::string GetCreatureName(uint32 entry)
{
    QueryResult result = WorldDatabase.Query(
        "SELECT name FROM creature_template WHERE entry = {}",
        entry
    );

    if (!result)
        return "Unknown";

    return result->Fetch()[0].Get<std::string>();
}
```

Or using the existing core prepared statement:

```cpp
std::string GetCreatureNamePrepared(uint32 entry)
{
    PreparedStatement* stmt = WorldDatabase.GetPreparedStatement(WORLD_SEL_CREATURE_TEMPLATE);
    stmt->SetData(0, entry);

    PreparedQueryResult result = WorldDatabase.Query(stmt);
    if (!result)
        return "Unknown";

    // WORLD_SEL_CREATURE_TEMPLATE selects the full row; name is at a known index
    // Check WorldDatabase.cpp for exact column order before hardcoding an index
    return result->Fetch()[6].Get<std::string>(); // 'name' is column 6 in creature_template
}
```

### Example 4: COUNT — return a single aggregate value

```cpp
uint32 CountDreamforgePlayers()
{
    QueryResult result = WorldDatabase.Query(
        "SELECT COUNT(*) FROM dreamforge_players"
    );

    if (!result)
        return 0;

    // COUNT(*) returns BIGINT — use Get<uint64>() then cast
    return static_cast<uint32>(result->Fetch()[0].Get<uint64>());
}
```

### Example 5: Conditional upsert (INSERT ... ON DUPLICATE KEY UPDATE)

```cpp
void IncrementPlayerScore(uint32 guid, uint32 points)
{
    // More efficient than REPLACE INTO for increments because
    // REPLACE INTO does DELETE + INSERT which resets AUTO_INCREMENT and
    // can break foreign keys.
    CharacterDatabase.Execute(
        "INSERT INTO dreamforge_players (guid, score) VALUES ({}, {})"
        " ON DUPLICATE KEY UPDATE score = score + {}",
        guid, points, points
    );
}
```

---

## 10. SQL File Conventions for Modules

### Directory layout

```
modules/mod-dreamforge/
    sql/
        base/
            db_world/
                01_dreamforge_players.sql       <- creates tables in acore_world
            db_characters/
                01_dreamforge_char_data.sql     <- creates tables in acore_characters
        updates/
            db_world/
                2025_01_15_add_tokens_column.sql  <- ALTER TABLE migrations
            db_characters/
                2025_01_20_add_index.sql
```

### How `acore-install` / `include.sh` applies SQL

The AzerothCore dashboard's `include.sh` hook runs during module install. The convention used by official modules is:

```bash
# modules/mod-dreamforge/include.sh
#!/bin/bash
source "$AC_PATH/azerothcore-wotlk/conf/config.sh"

# Apply base SQL if table doesn't exist yet
mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" "$WORLD_DB" < "$MODULE_PATH/sql/base/db_world/01_dreamforge_players.sql"
mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" "$CHAR_DB"  < "$MODULE_PATH/sql/base/db_characters/01_dreamforge_char_data.sql"
```

For modules that use the AzerothCore DB updater (the built-in system that reads `updates/` directories), place migration files in `sql/updates/db_world/` and `sql/updates/db_characters/`. These are applied automatically by the world server at startup if the `updates` table in each database records they haven't been applied yet.

The safe pattern is `CREATE TABLE IF NOT EXISTS` in base SQL, and `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` (MySQL 8.0+) or guard with a column-existence check in migration files.

### Full `dreamforge_players` table example

```sql
-- modules/mod-dreamforge/sql/base/db_world/01_dreamforge_players.sql
--
-- Dreamforge player registry in acore_world.
-- Keyed by character GUID. Updated on login/logout.
-- Do NOT use character GUID 0.

CREATE TABLE IF NOT EXISTS `dreamforge_players` (
    `guid`        INT UNSIGNED  NOT NULL COMMENT 'Character GUID (characters.guid)',
    `score`       INT UNSIGNED  NOT NULL DEFAULT 0 COMMENT 'Dreamforge score points',
    `tokens`      INT UNSIGNED  NOT NULL DEFAULT 0 COMMENT 'Spendable token balance',
    `title`       VARCHAR(64)   NOT NULL DEFAULT '' COMMENT 'Custom title string',
    `flags`       INT UNSIGNED  NOT NULL DEFAULT 0 COMMENT 'Bitfield for feature flags',
    `last_seen`   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
                                ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`guid`),
    INDEX `idx_score` (`score` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Dreamforge module player data';
```

```sql
-- modules/mod-dreamforge/sql/base/db_characters/01_dreamforge_char_data.sql
--
-- Flexible key-value store for character-level Dreamforge data.
-- Stored in acore_characters so it travels with the character.

CREATE TABLE IF NOT EXISTS `dreamforge_char_data` (
    `guid`        INT UNSIGNED  NOT NULL COMMENT 'Character GUID',
    `data_key`    VARCHAR(64)   NOT NULL COMMENT 'Data key identifier',
    `data_value`  TEXT          NOT NULL COMMENT 'JSON or plain string value',
    `updated_at`  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
                                ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`guid`, `data_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Dreamforge character key-value store';
```

### Naming rules summary

- All custom tables: `dreamforge_<name>` prefix
- All custom prepared statement enums: start after the core's `MAX_*` value or use an entirely separate enum with clear namespacing
- SQL files in `sql/base/`: idempotent (`IF NOT EXISTS`) — safe to run multiple times
- SQL files in `sql/updates/`: one change per file, never modify base files after initial commit

---

## Quick Reference

```cpp
// INCLUDE
#include "DatabaseEnv.h"

// SYNC QUERY (blocks)
QueryResult r = WorldDatabase.Query("SELECT ... WHERE x = {}", val);
if (!r) return;
do { Field* f = r->Fetch(); f[0].Get<uint32>(); } while (r->NextRow());

// PREPARED SYNC QUERY
PreparedStatement* s = WorldDatabase.GetPreparedStatement(MY_STMT_ENUM);
s->SetData(0, val);
PreparedQueryResult r = WorldDatabase.Query(s);

// ASYNC EXECUTE (non-blocking write)
CharacterDatabase.Execute("REPLACE INTO ... VALUES ({}, {})", a, b);

// PREPARED ASYNC EXECUTE
PreparedStatement* s = CharacterDatabase.GetPreparedStatement(MY_WRITE_STMT);
s->SetData(0, guid);
CharacterDatabase.Execute(s);

// TRANSACTION
CharacterTransaction t = CharacterDatabase.BeginTransaction();
t->Append(stmt1); t->Append(stmt2);
CharacterDatabase.CommitTransaction(t);

// ASYNC QUERY WITH CALLBACK
WorldDatabase.AsyncQuery("SELECT ...").WithCallback([](QueryResult r) {
    // WARNING: game objects not safe here
});
```
