# Script Hooks Reference

Complete reference for all AzerothCore C++ script hook types. Derived directly from source headers in
`src/server/game/Scripting/ScriptDefines/`.

---

## 1. Script System Overview

### How ScriptMgr Works

ScriptMgr is the global dispatcher for all script events. It maintains a `ScriptRegistry<T>` for every
script type. When the server calls a hook (e.g., "player logged in"), ScriptMgr iterates every registered
script of the matching type and calls the corresponding virtual method on each.

**Registration pattern:**

```cpp
// In your AddSC_*() function (called from the module loader):
new MyWorldScript();        // heap-allocates and self-registers in ScriptRegistry<WorldScript>
new MyPlayerScript();
new MyCommandScript();
```

Alternatively, for entity-bound scripts use the typed macros:
```cpp
RegisterSpellScript(spell_my_module_effect);
RegisterCreatureAI(npc_my_boss_ai);      // same as: new GenericCreatureScript<npc_my_boss_ai>("npc_my_boss_ai")
RegisterInstanceScript(instance_my_raid, 532);
```

### Hook Dispatch Macros (ScriptMgrMacros.h)

Three core dispatch templates are used internally by ScriptMgr:

| Macro / Template | Behavior |
|---|---|
| `ExecuteScript<T>(fn)` | Calls `fn(script)` on every registered T. All scripts run regardless of return value. |
| `IsValidBoolScript<T>(fn)` | Returns `Optional<bool>`. Stops at first script returning `true`, returns `nullopt` if list empty. |
| `CALL_ENABLED_HOOKS(T, hookEnum, action)` | Iterates scripts that opted into a specific hook enum value. |
| `CALL_ENABLED_BOOLEAN_HOOKS(T, hookEnum, action)` | Returns `false` if any script returns `true` from `action`. Default: `true`. |
| `CALL_ENABLED_BOOLEAN_HOOKS_WITH_DEFAULT_FALSE(T, hookEnum, action)` | Returns `true` if any script returns `true`. Default: `false`. |

**Key implication:** For `void` hooks, all registered scripts receive the call. For `bool` hooks, the first
script that returns `true` (or `false` depending on semantics) typically short-circuits, but this depends
on the specific ScriptMgr call site. When in doubt: if multiple modules each implement a `bool` gate hook,
they can conflict. Design your bool-returning hooks to return the default unless you specifically want to
change the outcome.

### Single-Entity Scripts vs All-Entity Scripts

| Type | How it attaches | When hooks fire |
|---|---|---|
| `CreatureScript` | `ScriptName` field in `creature_template` DB table | Only for creatures with matching script name |
| `GameObjectScript` | `ScriptName` in `gameobject_template` | Only for GOs with matching script name |
| `ItemScript` | `ScriptName` in `item_template` | Only for items with matching script name |
| `SpellScriptLoader` | `ScriptName` in `spell_script_names` | Only for spells with matching script name |
| `InstanceMapScript` | Constructor passes `mapId` | Only for that specific map ID |
| `AreaTriggerScript` | `ScriptName` in `areatrigger_scripts` | Only for that area trigger |
| `AllCreatureScript` | No DB binding — fires globally | Every creature in the world |
| `AllGameObjectScript` | No DB binding | Every game object |
| `AllItemScript` | No DB binding | Every item |
| `PlayerScript` | No DB binding | Every player |
| `WorldScript` | No DB binding | Global world events |
| `ModuleScript` | No DB binding | Module lifecycle |

**Rule of thumb:** Use `AllXxxScript` types only for hooks that would be inefficient to add to every
creature/item/GO via DB script names. Be mindful that `OnAllCreatureUpdate` fires every world tick for
every loaded creature — even a trivial operation per creature can cause measurable overhead at scale.

### Selective Hook Registration (enabledHooks)

Many script types accept a `std::vector<uint16> enabledHooks` in their constructor. By passing the hook
enum values you actually implement, you tell ScriptMgr to only include your script in those specific
`EnabledHooks` lists. This avoids iterating scripts that do nothing for a given event. Always pass the
relevant hooks when your script only implements a subset.

```cpp
// Only register for the login and logout hooks, skip all others
MyPlayerScript() : PlayerScript("my_player_script", {
    PLAYERHOOK_ON_LOGIN,
    PLAYERHOOK_ON_LOGOUT
}) {}
```

---

## 2. Complete Script Type Catalog

---

### Player Group

---

### PlayerScript

Registration: `new MyPlayerScript()` in `AddSC_*()`.
Attach to: fires for all players (no DB binding).
Base class: `class MyScript : public PlayerScript`

`PlayerScript` has the largest hook surface of any script type. See Section 3 for full signatures.
The constructor accepts an optional `std::vector<uint16> enabledHooks` using `PlayerHook` enum values.

**Summary table of all hooks:**

| Method | When it fires | Return |
|---|---|---|
| `OnPlayerJustDied(Player*)` | After player death is processed | void |
| `OnPlayerCalculateTalentsPoints(Player const*, uint32& talentPointsForLevel)` | During talent point calculation | void |
| `OnPlayerReleasedGhost(Player*)` | When player clicks release spirit | void |
| `OnPlayerSendInitialPacketsBeforeAddToMap(Player*, WorldPacket&)` | Before player added to map on login | void |
| `OnPlayerBattlegroundDesertion(Player*, BattlegroundDesertionType const)` | When player deserts a BG | void |
| `OnPlayerCompleteQuest(Player*, Quest const*)` | After quest is turned in | void |
| `OnPlayerPVPKill(Player* killer, Player* killed)` | Player kills another player | void |
| `OnPlayerPVPFlagChange(Player*, bool state)` | PvP flag toggled | void |
| `OnPlayerCreatureKill(Player* killer, Creature* killed)` | Player kills a creature | void |
| `OnPlayerCreatureKilledByPet(Player* owner, Creature* killed)` | Player's pet kills a creature | void |
| `OnPlayerKilledByCreature(Creature* killer, Player* killed)` | Player is killed by a creature | void |
| `OnPlayerLevelChanged(Player*, uint8 oldLevel)` | Right after level is applied | void |
| `OnPlayerFreeTalentPointsChanged(Player*, uint32 points)` | Right before free point change | void |
| `OnPlayerTalentsReset(Player*, bool noCost)` | Right before talent reset | void |
| `OnPlayerAfterSpecSlotChanged(Player*, uint8 newSlot)` | After dual-spec switch | void |
| `OnPlayerBeforeUpdate(Player*, uint32 p_time)` | Start of Player::Update | void |
| `OnPlayerUpdate(Player*, uint32 p_time)` | End of Player::Update | void |
| `OnPlayerMoneyChanged(Player*, int32& amount)` | Before money modification; modify `amount` to change how much | void |
| `OnPlayerBeforeLootMoney(Player*, Loot*)` | Before looted money is added | void |
| `OnPlayerGiveXP(Player*, uint32& amount, Unit* victim, uint8 xpSource)` | Before XP is added; modify `amount` | void |
| `OnPlayerReputationChange(Player*, uint32 factionID, int32& standing, bool incremental)` | Before rep change | bool — return false to suppress |
| `OnPlayerReputationRankChange(Player*, uint32 factionID, ReputationRank newRank, ReputationRank oldRank, bool increased)` | When rep rank changes | void |
| `OnPlayerGiveReputation(Player*, int32 factionID, float& amount, ReputationSource)` | Before rep given; modify `amount` | void |
| `OnPlayerLearnSpell(Player*, uint32 spellID)` | After player learns a spell | void |
| `OnPlayerForgotSpell(Player*, uint32 spellID)` | After player unlearns a spell | void |
| `OnPlayerDuelRequest(Player* target, Player* challenger)` | Duel requested | void |
| `OnPlayerDuelStart(Player* p1, Player* p2)` | After 3s countdown, duel begins | void |
| `OnPlayerDuelEnd(Player* winner, Player* loser, DuelCompleteType)` | Duel ends | void |
| `OnPlayerBeforeSendChatMessage(Player*, uint32& type, uint32& lang, std::string& msg)` | Before chat is dispatched | void |
| `OnPlayerEmote(Player*, uint32 emote)` | Emote opcode | void |
| `OnPlayerTextEmote(Player*, uint32 textEmote, uint32 emoteNum, ObjectGuid guid)` | Text emote opcode | void |
| `OnPlayerSpellCast(Player*, Spell*, bool skipCheck)` | In Spell::Cast | void |
| `OnPlayerLoadFromDB(Player*)` | During character data load | void |
| `OnPlayerLogin(Player*)` | After player logs in | void |
| `OnPlayerBeforeLogout(Player*)` | Before logout processing | void |
| `OnPlayerLogout(Player*)` | After player logs out | void |
| `OnPlayerCreate(Player*)` | Character creation | void |
| `OnPlayerDelete(ObjectGuid, uint32 accountId)` | Character deleted | void |
| `OnPlayerFailedDelete(ObjectGuid, uint32 accountId)` | Character delete failed | void |
| `OnPlayerSave(Player*)` | Before character save | void |
| `OnPlayerBindToInstance(Player*, Difficulty, uint32 mapId, bool permanent)` | Instance bind | void |
| `OnPlayerUpdateZone(Player*, uint32 newZone, uint32 newArea)` | Zone changed | void |
| `OnPlayerUpdateArea(Player*, uint32 oldArea, uint32 newArea)` | Area changed (more precise) | void |
| `OnPlayerMapChanged(Player*)` | After moving to new map | void |
| `OnPlayerBeforeTeleport(Player*, uint32 mapid, float x, float y, float z, float o, uint32 options, Unit* target)` | Before teleport | bool — return false to block |
| `OnPlayerUpdateFaction(Player*)` | Team/faction set on player | void |
| `OnPlayerAddToBattleground(Player*, Battleground*)` | Added to BG | void |
| `OnPlayerQueueRandomDungeon(Player*, uint32& rDungeonId)` | Queues RDF; modify dungeon ID | void |
| `OnPlayerRemoveFromBattleground(Player*, Battleground*)` | Removed from BG | void |
| `OnPlayerAchievementComplete(Player*, AchievementEntry const*)` | Achievement completed | void |
| `OnPlayerBeforeAchievementComplete(Player*, AchievementEntry const*)` | Before achievement completion | bool — return false to disable |
| `OnPlayerCriteriaProgress(Player*, AchievementCriteriaEntry const*)` | Criteria progress | void |
| `OnPlayerBeforeCriteriaProgress(Player*, AchievementCriteriaEntry const*)` | Before criteria progress | bool — return false to disable |
| `OnPlayerAchievementSave(CharacterDatabaseTransaction, Player*, uint16 achId, CompletedAchievementData)` | Achievement saved to DB | void |
| `OnPlayerCriteriaSave(CharacterDatabaseTransaction, Player*, uint16 achId, CriteriaProgress)` | Criteria saved to DB | void |
| `OnPlayerGossipSelect(Player*, uint32 menu_id, uint32 sender, uint32 action)` | Player gossip option selected | void |
| `OnPlayerGossipSelectCode(Player*, uint32 menu_id, uint32 sender, uint32 action, const char* code)` | Player gossip with code | void |
| `OnPlayerBeingCharmed(Player*, Unit* charmer, uint32 oldFactionId, uint32 newFactionId)` | Player is charmed | void |
| `OnPlayerAfterSetVisibleItemSlot(Player*, uint8 slot, Item*)` | Visible item slot changed | void |
| `OnPlayerAfterMoveItemFromInventory(Player*, Item*, uint8 bag, uint8 slot, bool update)` | Item moved in inventory | void |
| `OnPlayerEquip(Player*, Item*, uint8 bag, uint8 slot, bool update)` | Item equipped | void |
| `OnPlayerUnequip(Player*, Item*)` | Item unequipped | void |
| `OnPlayerJoinBG(Player*)` | Entered BG queue | void |
| `OnPlayerJoinArena(Player*)` | Entered arena queue | void |
| `OnPlayerGetMaxPersonalArenaRatingRequirement(Player const*, uint32 minSlot, uint32& maxArenaRating)` | Arena rating requirement calc | void |
| `OnPlayerLootItem(Player*, Item*, uint32 count, ObjectGuid lootguid)` | Item looted | void |
| `OnPlayerBeforeFillQuestLootItem(Player*, LootItem&)` | Before quest loot item filled | void |
| `OnPlayerStoreNewItem(Player*, Item*, uint32 count)` | After looting/master loot | void |
| `OnPlayerCreateItem(Player*, Item*, uint32 count)` | After crafting item | void |
| `OnPlayerQuestRewardItem(Player*, Item*, uint32 count)` | Quest reward received | void |
| `OnPlayerCanPlaceAuctionBid(Player*, AuctionEntry*)` | Bidding on auction | bool — return false to block |
| `OnPlayerGroupRollRewardItem(Player*, Item*, uint32 count, RollVote, Roll*)` | Roll reward received | void |
| `OnPlayerBeforeOpenItem(Player*, Item*)` | Before item opened | bool — return false to block |
| `OnPlayerBeforeQuestComplete(Player*, uint32 quest_id)` | Before quest turned in | bool — return false to block |
| `OnPlayerQuestComputeXP(Player*, Quest const*, uint32& xpValue)` | XP computed for quest; modify `xpValue` | void |
| `OnPlayerBeforeDurabilityRepair(Player*, ObjectGuid npcGUID, ObjectGuid itemGUID, float& discountMod, uint8 guildBank)` | Before repair; modify discount | void |
| `OnPlayerBeforeBuyItemFromVendor(Player*, ObjectGuid vendorguid, uint32 vendorslot, uint32& item, uint8 count, uint8 bag, uint8 slot)` | Before vendor purchase | void |
| `OnPlayerBeforeStoreOrEquipNewItem(Player*, uint32 vendorslot, uint32& item, uint8 count, uint8 bag, uint8 slot, ItemTemplate const*, Creature*, VendorItem const*, bool bStore)` | Before store/equip from vendor | void |
| `OnPlayerAfterStoreOrEquipNewItem(Player*, uint32 vendorslot, Item*, uint8 count, uint8 bag, uint8 slot, ItemTemplate const*, Creature*, VendorItem const*, bool bStore)` | After store/equip from vendor | void |
| `OnPlayerAfterUpdateMaxPower(Player*, Powers& power, float& value)` | After max power updated | void |
| `OnPlayerAfterUpdateMaxHealth(Player*, float& value)` | After max health updated | void |
| `OnPlayerBeforeUpdateAttackPowerAndDamage(Player*, float& level, float& val2, bool ranged)` | Before attack power calc | void |
| `OnPlayerAfterUpdateAttackPowerAndDamage(Player*, float& level, float& base_attPower, float& attPowerMod, float& attPowerMultiplier, bool ranged)` | After attack power calc | void |
| `OnPlayerBeforeInitTalentForLevel(Player*, uint8& level, uint32& talentPointsForLevel)` | Before talents initialized for level | void |
| `OnPlayerFirstLogin(Player*)` | Very first login (new character) | void |
| `OnPlayerSetMaxLevel(Player*, uint32& maxPlayerLevel)` | Max level set; modify to override | void |
| `OnPlayerCanJoinInBattlegroundQueue(Player*, ObjectGuid masterguid, BattlegroundTypeId, uint8 joinAsGroup, GroupJoinBattlegroundResult& err)` | Before BG queue join | bool — return false to block |
| `OnPlayerShouldBeRewardedWithMoneyInsteadOfExp(Player*)` | Check if money rewarded instead of XP | bool — return true to enable |
| `OnPlayerBeforeTempSummonInitStats(Player*, TempSummon*, uint32& duration)` | Temp summon init stats | void |
| `OnPlayerBeforeGuardianInitStatsForLevel(Player*, Guardian*, CreatureTemplate const*, PetType&)` | Guardian/pet stats init | void |
| `OnPlayerAfterGuardianInitStatsForLevel(Player*, Guardian*)` | After guardian stats init | void |
| `OnPlayerBeforeLoadPetFromDB(Player*, uint32& petentry, uint32& petnumber, bool& current, bool& forceLoadFromDB)` | Before loading pet from DB | void |
| `OnPlayerCanJoinInArenaQueue(Player*, ObjectGuid masterguid, uint8 arenaslot, BattlegroundTypeId, uint8 joinAsGroup, uint8 IsRated, GroupJoinBattlegroundResult& err)` | Before arena queue join | bool — return false to block |
| `OnPlayerCanBattleFieldPort(Player*, uint8 arenaType, BattlegroundTypeId, uint8 action)` | Before entering BG/arena | bool — return false to block |
| `OnPlayerCanGroupInvite(Player*, std::string& membername)` | Before group invite | bool — return false to block |
| `OnPlayerCanGroupAccept(Player*, Group*)` | Before accepting group invite | bool — return false to block |
| `OnPlayerCanSellItem(Player*, Item*, Creature*)` | Before selling item | bool — return false to block |
| `OnPlayerCanSendMail(Player*, ObjectGuid receiver, ObjectGuid mailbox, std::string& subject, std::string& body, uint32 money, uint32 COD, Item*)` | Before mail send | bool — return false to block |
| `OnPlayerPetitionBuy(Player*, Creature*, uint32& charterid, uint32& cost, uint32& type)` | Petition purchase | void |
| `OnPlayerPetitionShowList(Player*, Creature*, uint32& CharterEntry, uint32& CharterDisplayID, uint32& CharterCost)` | Petition list shown | void |
| `OnPlayerRewardKillRewarder(Player*, KillRewarder*, bool isDungeon, float& rate)` | Kill reward rate | void |
| `OnPlayerCanGiveMailRewardAtGiveLevel(Player*, uint8 level)` | Mail reward check | bool — return false to block |
| `OnPlayerDeleteFromDB(CharacterDatabaseTransaction, uint32 guid)` | Character deleted from DB | void |
| `OnPlayerCanRepopAtGraveyard(Player*)` | Before repop at graveyard | bool — return false to block |
| `OnPlayerIsClass(Player const*, Classes, ClassContext)` | Class check; return Optional<bool> to override | Optional\<bool\> |
| `OnPlayerGetMaxSkillValue(Player*, uint32 skill, int32& result, bool IsPure)` | Max skill value query | void |
| `OnPlayerHasActivePowerType(Player const*, Powers)` | Power type active check | bool |
| `OnPlayerUpdateGatheringSkill(Player*, uint32 skill_id, uint32 current, uint32 gray, uint32 green, uint32 yellow, uint32& gain)` | Before gathering skill gain | void |
| `OnPlayerUpdateCraftingSkill(Player*, SkillLineAbilityEntry const*, uint32 current_level, uint32& gain)` | Before crafting skill gain | void |
| `OnPlayerUpdateFishingSkill(Player*, int32 skill, int32 zone_skill, int32 chance, int32 roll)` | Fishing skill check | bool |
| `OnPlayerCanAreaExploreAndOutdoor(Player*)` | Area explore permission | bool |
| `OnPlayerVictimRewardBefore(Player*, Player* victim, uint32& killer_title, int32& victim_rank)` | Before honor/kill reward calc | void |
| `OnPlayerVictimRewardAfter(Player*, Player* victim, uint32& killer_title, int32& victim_rank, float& honor_f)` | After honor/kill reward calc | void |
| `OnPlayerCustomScalingStatValueBefore(Player*, ItemTemplate const*, uint8 slot, bool apply, uint32& CustomScalingStatValue)` | Custom scaling stat | void |
| `OnPlayerCustomScalingStatValue(Player*, ItemTemplate const*, uint32& statType, int32& val, uint8 itemProtoStatNumber, uint32 ScalingStatValue, ScalingStatValuesEntry const*)` | Custom scaling stat value | void |
| `OnPlayerApplyItemModsBefore(Player*, uint8 slot, bool apply, uint8 itemProtoStatNumber, uint32 statType, int32& val)` | Before item mod applied | void |
| `OnPlayerApplyEnchantmentItemModsBefore(Player*, Item*, EnchantmentSlot, bool apply, uint32 enchant_spell_id, uint32& enchant_amount)` | Before enchantment mod | void |
| `OnPlayerApplyWeaponDamage(Player*, uint8 slot, ItemTemplate const*, float& minDamage, float& maxDamage, uint8 damageIndex)` | Weapon damage calc | void |
| `OnPlayerCanArmorDamageModifier(Player*)` | Armor modifier check | bool |
| `OnPlayerGetFeralApBonus(Player*, int32& feral_bonus, int32 dpsMod, ItemTemplate const*, ScalingStatValuesEntry const*)` | Feral AP bonus | void |
| `OnPlayerCanApplyWeaponDependentAuraDamageMod(Player*, Item*, WeaponAttackType, AuraEffect const*, bool apply)` | Weapon aura damage mod | bool |
| `OnPlayerCanApplyEquipSpell(Player*, SpellInfo const*, Item*, bool apply, bool form_change)` | Equip spell permission | bool |
| `OnPlayerCanApplyEquipSpellsItemSet(Player*, ItemSetEffect*)` | Item set equip spell permission | bool |
| `OnPlayerCanCastItemCombatSpell(Player*, Unit* target, WeaponAttackType, uint32 procVictim, uint32 procEx, Item*, ItemTemplate const*)` | Combat item spell check | bool |
| `OnPlayerCanCastItemUseSpell(Player*, Item*, SpellCastTargets const&, uint8 cast_count, uint32 glyphIndex)` | Item use spell check | bool |
| `OnPlayerApplyAmmoBonuses(Player*, ItemTemplate const*, float& currentAmmoDPS)` | Ammo DPS bonus | void |
| `OnPlayerCanEquipItem(Player*, uint8 slot, uint16& dest, Item*, bool swap, bool not_loading)` | Equip check | bool |
| `OnPlayerCanUnequipItem(Player*, uint16 pos, bool swap)` | Unequip check | bool |
| `OnPlayerCanUseItem(Player*, ItemTemplate const*, InventoryResult& result)` | Item use check | bool |
| `OnPlayerCanSaveEquipNewItem(Player*, Item*, uint16 pos, bool update)` | Save equip check | bool |
| `OnPlayerCanApplyEnchantment(Player*, Item*, EnchantmentSlot, bool apply, bool apply_dur, bool ignore_condition)` | Enchantment apply check | bool |
| `OnPlayerGetQuestRate(Player*, float& result)` | Quest XP rate | void |
| `OnPlayerPassedQuestKilledMonsterCredit(Player*, Quest const*, uint32 entry, uint32 real_entry, ObjectGuid)` | Kill credit check | bool |
| `OnPlayerCheckItemInSlotAtLoadInventory(Player*, Item*, uint8 slot, uint8& err, uint16& dest)` | Inventory load slot check | bool |
| `OnPlayerNotAvoidSatisfy(Player*, DungeonProgressionRequirements const*, uint32 target_map, bool report)` | Avoid-satisfy override | bool |
| `OnPlayerNotVisibleGloballyFor(Player*, Player const*)` | Visibility check | bool |
| `OnPlayerGetArenaPersonalRating(Player*, uint8 slot, uint32& result)` | Arena personal rating | void |
| `OnPlayerGetArenaTeamId(Player*, uint8 slot, uint32& result)` | Arena team ID | void |
| `OnPlayerIsFFAPvP(Player*, bool& result)` | FFA PvP state query | void |
| `OnPlayerFfaPvpStateUpdate(Player*, bool result)` | FFA PvP bit changed | void |
| `OnPlayerIsPvP(Player*, bool& result)` | PvP state query | void |
| `OnPlayerGetMaxSkillValueForLevel(Player*, uint16& result)` | Max skill for level | void |
| `OnPlayerNotSetArenaTeamInfoField(Player*, uint8 slot, ArenaTeamInfoType, uint32 value)` | Arena team field set prevention | bool |
| `OnPlayerCanJoinLfg(Player*, uint8 roles, std::set<uint32>& dungeons, const std::string& comment)` | LFG join check | bool |
| `OnPlayerCanEnterMap(Player*, MapEntry const*, InstanceTemplate const*, MapDifficulty const*, bool loginCheck)` | Map entry check | bool |
| `OnPlayerCanInitTrade(Player*, Player* target)` | Trade initiation check | bool |
| `OnPlayerCanSetTradeItem(Player*, Item*, uint8 tradeSlot)` | Trade item slot check | bool |
| `OnPlayerSetServerSideVisibility(Player*, ServerSideVisibilityType&, AccountTypes&)` | Server-side visibility | void |
| `OnPlayerSetServerSideVisibilityDetect(Player*, ServerSideVisibilityType&, AccountTypes&)` | Server-side visibility detect | void |
| `OnPlayerResurrect(Player*, float restore_percent, bool applySickness)` | Player resurrected | void |
| `OnPlayerBeforeChooseGraveyard(Player*, TeamId, bool nearCorpse, uint32& graveyardOverride)` | Before graveyard selection | void |
| `OnPlayerCanUseChat(Player*, uint32 type, uint32 language, std::string& msg)` | Default chat check | bool |
| `OnPlayerCanUseChat(Player*, uint32 type, uint32 language, std::string& msg, Player* receiver)` | Whisper chat check | bool |
| `OnPlayerCanUseChat(Player*, uint32 type, uint32 language, std::string& msg, Group*)` | Group chat check | bool |
| `OnPlayerCanUseChat(Player*, uint32 type, uint32 language, std::string& msg, Guild*)` | Guild chat check | bool |
| `OnPlayerCanUseChat(Player*, uint32 type, uint32 language, std::string& msg, Channel*)` | Channel chat check | bool |
| `OnPlayerLearnTalents(Player*, uint32 talentId, uint32 talentRank, uint32 spellid)` | After talent learned | void |
| `OnPlayerEnterCombat(Player*, Unit* enemy)` | Player enters combat | void |
| `OnPlayerLeaveCombat(Player*)` | Player leaves combat | void |
| `OnPlayerQuestAbandon(Player*, uint32 questId)` | Quest abandoned | void |
| `OnPlayerCanFlyInZone(Player*, uint32 mapId, uint32 zoneId, SpellInfo const*)` | Flying permission check | bool |
| `AnticheatSetCanFlybyServer(Player*, bool apply)` | Anticheat: set fly flag | void |
| `AnticheatSetUnderACKmount(Player*)` | Anticheat: mounting state | void |
| `AnticheatSetRootACKUpd(Player*)` | Anticheat: root ack | void |
| `AnticheatSetJumpingbyOpcode(Player*, bool jump)` | Anticheat: jump state | void |
| `AnticheatUpdateMovementInfo(Player*, MovementInfo const&)` | Anticheat: movement info | void |
| `AnticheatHandleDoubleJump(Player*, Unit* mover)` | Anticheat: double jump check | bool |
| `AnticheatCheckMovementInfo(Player*, MovementInfo const&, Unit* mover, bool jump)` | Anticheat: movement validation | bool |
| `OnPlayerCanSendErrorAlreadyLooted(Player*)` | Suppress "already looted" error | bool |
| `OnPlayerAfterCreatureLoot(Player*)` | After item taken from creature | void |
| `OnPlayerAfterCreatureLootMoney(Player*)` | After creature money looted | void |
| `OnPlayerCanUpdateSkill(Player*, uint32 skillId)` | Skill update permission | bool |
| `OnPlayerBeforeUpdateSkill(Player*, uint32 skillId, uint32& value, uint32 max, uint32 step)` | Before skill update | void |
| `OnPlayerUpdateSkill(Player*, uint32 skillId, uint32 value, uint32 max, uint32 step, uint32 newValue)` | After skill updated | void |
| `OnPlayerCanResurrect(Player*)` | Resurrection permission | bool |
| `OnPlayerCanGiveLevel(Player*, uint8 newLevel)` | Level-up permission | bool |
| `OnPlayerSendListInventory(Player*, ObjectGuid vendorGuid, uint32& vendorEntry)` | Vendor list shown | void |
| `OnPlayerGetReputationPriceDiscount(Player const*, Creature const*, float& discount)` | Reputation discount calc | void |
| `OnPlayerGetReputationPriceDiscount(Player const*, FactionTemplateEntry const*, float& discount)` | Faction reputation discount | void |

---

### Creature Group

---

### CreatureScript

Registration: `new MyCreatureScript("npc_script_name")` or macro `RegisterCreatureAI(ai_class_name)`.
Attach to: `ScriptName` field in `creature_template` DB table. Only fires for creatures with that name.
DB Bound: yes (`IsDatabaseBound() = true`).
Base class: `class MyScript : public CreatureScript`

The primary hook is `GetAI()` — all creature behavior lives in the AI class, not in the Script class itself.

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `OnGossipHello` | `(Player*, Creature*)` | Player opens gossip window | bool — return true to handle (close default menu) |
| `OnGossipSelect` | `(Player*, Creature*, uint32 sender, uint32 action)` | Gossip option selected | bool — return true to close |
| `OnGossipSelectCode` | `(Player*, Creature*, uint32 sender, uint32 action, const char* code)` | Gossip with input code | bool |
| `OnQuestAccept` | `(Player*, Creature*, Quest const*)` | Quest accepted | bool |
| `OnQuestSelect` | `(Player*, Creature*, Quest const*)` | Quest selected in menu | bool |
| `OnQuestComplete` | `(Player*, Creature*, Quest const*)` | Quest completed | bool |
| `OnQuestReward` | `(Player*, Creature*, Quest const*, uint32 opt)` | Quest reward selected | bool |
| `GetDialogStatus` | `(Player*, Creature*)` | Quest icon over NPC requested | uint32 (dialog status constant) |
| `GetAI` | `(Creature*)` | Creature spawns and needs an AI | `CreatureAI*` |
| `OnFfaPvpStateUpdate` | `(Creature*, bool)` | FFA PvP bit changed on creature | void |

**Helper templates/macros:**

```cpp
// Simple AI — class is instantiated directly:
RegisterCreatureAI(npc_my_boss);
// Equivalent to:
new GenericCreatureScript<npc_my_boss>("npc_my_boss");

// Factory pattern (when AI constructor needs custom args):
RegisterCreatureAIWithFactory(npc_my_boss, MyBossFactory);
```

`UpdatableScript<Creature>` (mixed in via inheritance) adds:
- `OnUpdate(Creature*, uint32 diff)` — called each creature update tick (only when script has the matching `ScriptName`)

---

### AllCreatureScript

Registration: `new MyAllCreatureScript("name")`.
Attach to: all creatures (no DB binding).
Base class: `class MyScript : public AllCreatureScript`

No `enabledHooks` constructor variant — all hooks always active. Be selective about what you implement here.

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `OnAllCreatureUpdate` | `(Creature*, uint32 diff)` | End of every creature's Update() | void |
| `OnBeforeCreatureSelectLevel` | `(CreatureTemplate const*, Creature*, uint8& level)` | Before creature level is set | void |
| `OnCreatureSelectLevel` | `(CreatureTemplate const*, Creature*)` | After level selection completes | void |
| `OnCreatureAddWorld` | `(Creature*)` | Creature added to world | void |
| `OnCreatureRemoveWorld` | `(Creature*)` | Creature removed from world | void |
| `OnCreatureSaveToDB` | `(Creature*)` | After creature saved to DB | void |
| `CanCreatureGossipHello` | `(Player*, Creature*)` | Player opens gossip — fires for ALL creatures | bool — return true to disable default gossip |
| `CanCreatureGossipSelect` | `(Player*, Creature*, uint32 sender, uint32 action)` | Gossip option selected | bool — return true to disable |
| `CanCreatureGossipSelectCode` | `(Player*, Creature*, uint32 sender, uint32 action, const char* code)` | Gossip with code | bool |
| `CanCreatureQuestAccept` | `(Player*, Creature*, Quest const*)` | Quest accepted | bool |
| `CanCreatureQuestReward` | `(Player*, Creature*, Quest const*, uint32 opt)` | Quest rewarded | bool |
| `GetCreatureAI` | `(Creature*)` | AI needed (for any creature) | `CreatureAI*` |
| `OnFfaPvpStateUpdate` | `(Creature*, bool)` | FFA PvP bit changed | void |

---

### Spell Group

---

### SpellScriptLoader

Registration: `RegisterSpellScript(spell_class_name)` or `RegisterSpellAndAuraScriptPair(spell_class, aura_class)`.
Attach to: `spell_script_names` DB table. Only fires for spells with matching script name.
DB Bound: yes.

`SpellScriptLoader` itself only has two methods — all the real work happens in `SpellScript` and `AuraScript` classes:

| Method | Return |
|---|---|
| `GetSpellScript()` | `SpellScript*` — return `new MySpellScript()` |
| `GetAuraScript()` | `AuraScript*` — return `new MyAuraScript()` |

**Registration macros:**

```cpp
RegisterSpellScript(spell_my_effect);
RegisterSpellAndAuraScriptPair(spell_my_effect, aura_my_effect);

// With constructor arguments:
RegisterSpellScriptWithArgs(spell_my_effect, "spell_my_effect", arg1, arg2);
```

`SpellScript` and `AuraScript` are not `ScriptObject` subclasses — they have their own hook registration
system using `PrepareSpellScript()` / `PrepareAuraScript()` macros. See `05b_spell_scripting.md` for the
full SpellScript/AuraScript hook system.

---

### AllSpellScript

Registration: `new MyAllSpellScript("name", {ALLSPELLHOOK_ON_CAST, ...})`.
Attach to: all spells globally.
DB Bound: no.
Base class: `class MyScript : public AllSpellScript`

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `OnCalcMaxDuration` | `(Aura const*, int32& maxDuration)` | Aura max duration calculated | void |
| `OnSpellCheckCast` | `(Spell*, bool strict, SpellCastResult& res)` | Spell cast check | void |
| `CanPrepare` | `(Spell*, SpellCastTargets const*, AuraEffect const* triggeredByAura)` | Before spell prepare | bool |
| `CanScalingEverything` | `(Spell*)` | Check if spell scales everything | bool — default false |
| `CanSelectSpecTalent` | `(Spell*)` | Spec talent selection check | bool |
| `OnScaleAuraUnitAdd` | `(Spell*, Unit*, uint32 effectMask, bool checkIfValid, bool implicit, uint8 auraScaleMask, TargetInfo&)` | Aura scaled to unit | void |
| `OnRemoveAuraScaleTargets` | `(Spell*, TargetInfo&, uint8 auraScaleMask, bool& needErase)` | Aura scale targets removed | void |
| `OnBeforeAuraRankForLevel` | `(SpellInfo const*, SpellInfo const* latestSpellInfo, uint8 level)` | Before aura rank for level | void |
| `OnDummyEffect` | `(WorldObject*, uint32 spellID, SpellEffIndex, GameObject*)` | Dummy effect on GO | void |
| `OnDummyEffect` | `(WorldObject*, uint32 spellID, SpellEffIndex, Creature*)` | Dummy effect on creature | void |
| `OnDummyEffect` | `(WorldObject*, uint32 spellID, SpellEffIndex, Item*)` | Dummy effect on item | void |
| `OnSpellCastCancel` | `(Spell*, Unit* caster, SpellInfo const*, bool bySelf)` | Cast cancelled | void |
| `OnSpellCast` | `(Spell*, Unit* caster, SpellInfo const*, bool skipCheck)` | Spell cast | void |
| `OnSpellPrepare` | `(Spell*, Unit* caster, SpellInfo const*)` | Spell prepared | void |

Alias: `SpellSC = AllSpellScript` (old name, kept for compatibility).

---

### World Group

---

### WorldScript

Registration: `new MyWorldScript("name", {WORLDHOOK_ON_STARTUP, ...})`.
Attach to: global world events.
DB Bound: no.
Base class: `class MyScript : public WorldScript`

| Method | Signature | When it fires |
|---|---|---|
| `OnOpenStateChange` | `(bool open)` | World open/closed state changes |
| `OnAfterConfigLoad` | `(bool reload)` | After worldserver.conf is (re)loaded |
| `OnLoadCustomDatabaseTable` | `()` | When custom DB tables are loaded |
| `OnBeforeConfigLoad` | `(bool reload)` | Before worldserver.conf is (re)loaded |
| `OnMotdChange` | `(std::string& newMotd, LocaleConstant& locale)` | MOTD changed |
| `OnShutdownInitiate` | `(ShutdownExitCode, ShutdownMask)` | Shutdown begins |
| `OnShutdownCancel` | `()` | Shutdown cancelled |
| `OnUpdate` | `(uint32 diff)` | Every world tick — keep lightweight |
| `OnStartup` | `()` | World fully started |
| `OnShutdown` | `()` | World actually shutting down |
| `OnAfterUnloadAllMaps` | `()` | After all maps unloaded |
| `OnBeforeFinalizePlayerWorldSession` | `(uint32& cacheVersion)` | Before player session finalized; modify cache version |
| `OnBeforeWorldInitialized` | `()` | After scripts loaded, before world init |

---

### GlobalScript

Registration: `new MyGlobalScript("name", {GLOBALHOOK_..., ...})`.
Attach to: various global systems (loot, spells, phases, instances).
DB Bound: no.
Base class: `class MyScript : public GlobalScript`

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `OnItemDelFromDB` | `(CharacterDatabaseTransaction, ObjectGuid::LowType itemGuid)` | Item deleted from DB | void |
| `OnMirrorImageDisplayItem` | `(Item const*, uint32& display)` | Mirror image item display | void |
| `OnAfterRefCount` | `(Player const*, LootStoreItem*, Loot&, bool canRate, uint16 lootMode, uint32& maxcount, LootStore const&)` | After ref count computed | void |
| `OnAfterCalculateLootGroupAmount` | `(Player const*, Loot&, uint16 lootMode, uint32& groupAmount, LootStore const&)` | After loot group amount | void |
| `OnBeforeDropAddItem` | `(Player const*, Loot&, bool canRate, uint16 lootMode, LootStoreItem*, LootStore const&)` | Before item added to drop | void |
| `OnItemRoll` | `(Player const*, LootStoreItem const*, float& chance, Loot&, LootStore const&)` | Item roll chance | bool |
| `OnBeforeLootEqualChanced` | `(Player const*, std::list<LootStoreItem*>, Loot&, LootStore const&)` | Before equal-chance loot | bool |
| `OnInitializeLockedDungeons` | `(Player*, uint8& level, uint32& lockData, lfg::LFGDungeonData const*)` | LFG dungeon lock init | void |
| `OnAfterInitializeLockedDungeons` | `(Player*)` | After LFG lock init | void |
| `OnBeforeUpdateArenaPoints` | `(ArenaTeam*, std::map<ObjectGuid, uint32>& ap)` | Before arena points distributed | void |
| `OnAfterUpdateEncounterState` | `(Map*, EncounterCreditType, uint32 creditEntry, Unit*, Difficulty, std::list<DungeonEncounter const*> const*, uint32 dungeonCompleted, bool updated)` | Dungeon encounter updated | void |
| `OnBeforeWorldObjectSetPhaseMask` | `(WorldObject const*, uint32& oldPhaseMask, uint32& newPhaseMask, bool& useCombinedPhases, bool& update)` | Before phase set | void |
| `OnIsAffectedBySpellModCheck` | `(SpellInfo const* affectSpell, SpellInfo const* checkSpell, SpellModifier const*)` | Spell mod check | bool |
| `OnSpellHealingBonusTakenNegativeModifiers` | `(Unit const*, Unit const*, SpellInfo const*, float& val)` | Healing negative modifier | bool |
| `OnLoadSpellCustomAttr` | `(SpellInfo*)` | After spell DBC corrections loaded | void |
| `OnAllowedForPlayerLootCheck` | `(Player const*, ObjectGuid source)` | Check if player can see loot item | bool |
| `OnAllowedToLootContainerCheck` | `(Player const*, ObjectGuid source)` | Check if player can loot container | bool |
| `OnInstanceIdRemoved` | `(uint32 instanceId)` | Instance ID removed (reset) | void |
| `OnBeforeSetBossState` | `(uint32 id, EncounterState newState, EncounterState oldState, Map* instance)` | Boss state changes | void |
| `AfterInstanceGameObjectCreate` | `(Map* instance, GameObject*)` | GO created by instance | void |

---

### DatabaseScript

Registration: `new MyDatabaseScript("name", {DATABASEHOOK_..., ...})`.
Attach to: database loading events.
DB Bound: no.
Base class: `class MyScript : public DatabaseScript`

| Method | Signature | When it fires |
|---|---|---|
| `OnAfterDatabasesLoaded` | `(uint32 updateFlags)` | All DB data loaded at startup |
| `OnAfterDatabaseLoadCreatureTemplates` | `(std::vector<CreatureTemplate*> creatureTemplates)` | After creature template data loaded; may fire multiple times |

Use `OnAfterDatabasesLoaded` for one-time initialization that requires the DB to be fully loaded.
Use `OnAfterDatabaseLoadCreatureTemplates` to modify creature template data programmatically after load.

---

### Map/Instance Group

---

### InstanceMapScript

Registration: `RegisterInstanceScript(InstanceScriptClass, mapId)` or `new MyInstanceScript("name", mapId)`.
Attach to: specific map ID (instances only). DB Bound: yes.
Base class: `class MyScript : public InstanceMapScript`

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `GetInstanceScript` | `(InstanceMap*)` | Instance map created | `InstanceScript*` — return `new MyInstanceAI(map)` |

`InstanceScript` itself (the AI class, not the script loader) contains the boss data, door/encounter
management, and Save/Load methods. `InstanceMapScript` is only the factory.

`MapScript<InstanceMap>` is also inherited, providing:
- `OnCreate(InstanceMap*)` — map created
- `OnDestroy(InstanceMap*)` — map destroyed
- `OnLoadGridMap(InstanceMap*, GridTerrainData*, uint32 gx, uint32 gy)` — grid loaded
- `OnUnloadGridMap(...)` — grid unloaded
- `OnPlayerEnter(InstanceMap*, Player*)` — player enters
- `OnPlayerLeave(InstanceMap*, Player*)` — player leaves
- `OnUpdate(InstanceMap*, uint32 diff)` — map update tick

---

### WorldMapScript

Registration: `new MyWorldMapScript("name", mapId)`.
Attach to: specific non-instance, non-battleground map. DB Bound: no (fires after load).
Base class: `class MyScript : public WorldMapScript`

Inherits `MapScript<Map>` — same hooks as InstanceMapScript but for open-world maps.

---

### BattlegroundMapScript

Registration: `new MyBGMapScript("name", mapId)`.
Attach to: specific battleground map. DB Bound: no.
Base class: `class MyScript : public BattlegroundMapScript`

Inherits `MapScript<BattlegroundMap>` — same MapScript hooks as above.

---

### AllMapScript

Registration: `new MyAllMapScript("name", {ALLMAPHOOK_..., ...})`.
Attach to: all maps globally.
DB Bound: no.
Base class: `class MyScript : public AllMapScript`

| Method | Signature | When it fires |
|---|---|---|
| `OnPlayerEnterAll` | `(Map*, Player*)` | Player enters any map |
| `OnPlayerLeaveAll` | `(Map*, Player*)` | Player leaves any map |
| `OnBeforeCreateInstanceScript` | `(InstanceMap*, InstanceScript**, bool load, std::string data, uint32 completedEncounterMask)` | Before instance script created |
| `OnDestroyInstance` | `(MapInstanced*, Map*)` | Instance destroyed |
| `OnCreateMap` | `(Map*)` | Any map created |
| `OnDestroyMap` | `(Map*)` | Any map destroyed |
| `OnMapUpdate` | `(Map*, uint32 diff)` | Every map update tick |

---

### Item Group

---

### ItemScript

Registration: `new MyItemScript("item_script_name")`.
Attach to: `ScriptName` in `item_template`. DB Bound: yes.
Base class: `class MyScript : public ItemScript`

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `OnQuestAccept` | `(Player*, Item*, Quest const*)` | Quest accepted from item | bool |
| `OnUse` | `(Player*, Item*, SpellCastTargets const&)` | Item used | bool — return true to prevent default use |
| `OnRemove` | `(Player*, Item*)` | Item destroyed | bool |
| `OnCastItemCombatSpell` | `(Player*, Unit* victim, SpellInfo const*, Item*)` | Combat proc spell — return false to prevent | bool |
| `OnExpire` | `(Player*, ItemTemplate const*)` | Item expires | bool |
| `OnGossipSelect` | `(Player*, Item*, uint32 sender, uint32 action)` | Item gossip selected | void |
| `OnGossipSelectCode` | `(Player*, Item*, uint32 sender, uint32 action, const char* code)` | Item gossip with code | void |

---

### AllItemScript

Registration: `new MyAllItemScript("name")`.
Attach to: all items globally. No `enabledHooks` constructor.
Base class: `class MyScript : public AllItemScript`

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `CanItemQuestAccept` | `(Player*, Item*, Quest const*)` | Quest accepted from any item | bool — return false to block |
| `CanItemUse` | `(Player*, Item*, SpellCastTargets const&)` | Any item used — return true to block default use | bool |
| `CanItemRemove` | `(Player*, Item*)` | Any item destroyed | bool — return false to block |
| `CanItemExpire` | `(Player*, ItemTemplate const*)` | Any item expires | bool — return false to block |
| `OnItemGossipSelect` | `(Player*, Item*, uint32 sender, uint32 action)` | Any item gossip selected | void |
| `OnItemGossipSelectCode` | `(Player*, Item*, uint32 sender, uint32 action, const char* code)` | Any item gossip with code | void |

---

### GameObject Group

---

### GameObjectScript

Registration: `new MyGOScript("go_script_name")` or `RegisterGameObjectAI(ai_class_name)`.
Attach to: `ScriptName` in `gameobject_template`. DB Bound: yes.
Base class: `class MyScript : public GameObjectScript`

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `OnGossipHello` | `(Player*, GameObject*)` | Player opens GO gossip | bool |
| `OnGossipSelect` | `(Player*, GameObject*, uint32 sender, uint32 action)` | GO gossip option | bool |
| `OnGossipSelectCode` | `(Player*, GameObject*, uint32 sender, uint32 action, const char* code)` | GO gossip with code | bool |
| `OnQuestAccept` | `(Player*, GameObject*, Quest const*)` | Quest accepted from GO | bool |
| `OnQuestReward` | `(Player*, GameObject*, Quest const*, uint32 opt)` | Quest rewarded at GO | bool |
| `GetDialogStatus` | `(Player*, GameObject*)` | Dialog status request | uint32 |
| `OnDestroyed` | `(GameObject*, Player*)` | Destructible GO destroyed | void |
| `OnDamaged` | `(GameObject*, Player*)` | Destructible GO damaged | void |
| `OnModifyHealth` | `(GameObject*, Unit* attackerOrHealer, int32& change, SpellInfo const*)` | GO health modified | void |
| `OnLootStateChanged` | `(GameObject*, uint32 state, Unit*)` | Loot state changed | void |
| `OnGameObjectStateChanged` | `(GameObject*, uint32 state)` | GO state changed | void |
| `GetAI` | `(GameObject*)` | AI needed | `GameObjectAI*` |

`UpdatableScript<GameObject>` adds `OnUpdate(GameObject*, uint32 diff)`.

---

### AllGameObjectScript

Registration: `new MyAllGOScript("name")`.
Attach to: all game objects globally.
Base class: `class MyScript : public AllGameObjectScript`

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `OnGameObjectAddWorld` | `(GameObject*)` | Any GO added to world | void |
| `OnGameObjectSaveToDB` | `(GameObject*)` | Any GO saved to DB | void |
| `OnGameObjectRemoveWorld` | `(GameObject*)` | Any GO removed from world | void |
| `OnGameObjectUpdate` | `(GameObject*, uint32 diff)` | Any GO update tick | void |
| `CanGameObjectGossipHello` | `(Player*, GameObject*)` | Player opens any GO gossip | bool |
| `CanGameObjectGossipSelect` | `(Player*, GameObject*, uint32 sender, uint32 action)` | Any GO gossip option | bool |
| `CanGameObjectGossipSelectCode` | `(Player*, GameObject*, uint32 sender, uint32 action, const char* code)` | Any GO gossip with code | bool |
| `CanGameObjectQuestAccept` | `(Player*, GameObject*, Quest const*)` | Quest from any GO | bool |
| `CanGameObjectQuestReward` | `(Player*, GameObject*, Quest const*, uint32 opt)` | Quest reward at any GO | bool |
| `OnGameObjectDestroyed` | `(GameObject*, Player*)` | Any destructible GO destroyed | void |
| `OnGameObjectDamaged` | `(GameObject*, Player*)` | Any destructible GO damaged | void |
| `OnGameObjectModifyHealth` | `(GameObject*, Unit*, int32& change, SpellInfo const*)` | Any GO health modified | void |
| `OnGameObjectLootStateChanged` | `(GameObject*, uint32 state, Unit*)` | Any GO loot state changed | void |
| `OnGameObjectStateChanged` | `(GameObject*, uint32 state)` | Any GO state changed | void |
| `GetGameObjectAI` | `(GameObject*)` | AI needed for any GO | `GameObjectAI*` |

---

### Social Group

---

### GroupScript

Registration: `new MyGroupScript("name", {GROUPHOOK_..., ...})`.
Attach to: all groups globally. DB Bound: no.
Base class: `class MyScript : public GroupScript`

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `OnAddMember` | `(Group*, ObjectGuid)` | Member added | void |
| `OnInviteMember` | `(Group*, ObjectGuid)` | Member invited | void |
| `OnRemoveMember` | `(Group*, ObjectGuid, RemoveMethod, ObjectGuid kicker, const char* reason)` | Member removed | void |
| `OnChangeLeader` | `(Group*, ObjectGuid newLeader, ObjectGuid oldLeader)` | Leader changed | void |
| `OnDisband` | `(Group*)` | Group disbanded | void |
| `CanGroupJoinBattlegroundQueue` | `(Group const*, Player* member, Battleground const*, uint32 MinPlayerCount, bool isRated, uint32 arenaSlot)` | Group tries to join BG queue | bool |
| `OnCreate` | `(Group*, Player* leader)` | Group created | void |

---

### GuildScript

Registration: `new MyGuildScript("name", {GUILDHOOK_..., ...})`.
Attach to: all guilds. DB Bound: no.
Base class: `class MyScript : public GuildScript`

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `OnAddMember` | `(Guild*, Player*, uint8& plRank)` | Member added; modify rank | void |
| `OnRemoveMember` | `(Guild*, Player*, bool isDisbanding, bool isKicked)` | Member removed | void |
| `OnMOTDChanged` | `(Guild*, const std::string& newMotd)` | MOTD changed | void |
| `OnInfoChanged` | `(Guild*, const std::string& newInfo)` | Guild info changed | void |
| `OnCreate` | `(Guild*, Player* leader, const std::string& name)` | Guild created | void |
| `OnDisband` | `(Guild*)` | Guild disbanded | void |
| `OnMemberWitdrawMoney` | `(Guild*, Player*, uint32& amount, bool isRepair)` | Money withdrawn from bank | void |
| `OnMemberDepositMoney` | `(Guild*, Player*, uint32& amount)` | Money deposited to bank | void |
| `OnItemMove` | `(Guild*, Player*, Item*, bool isSrcBank, uint8 srcContainer, uint8 srcSlotId, bool isDestBank, uint8 destContainer, uint8 destSlotId)` | Item moved in bank | void |
| `OnEvent` | `(Guild*, uint8 eventType, ObjectGuid::LowType playerGuid1, ObjectGuid::LowType playerGuid2, uint8 newRank)` | Guild event | void |
| `OnBankEvent` | `(Guild*, uint8 eventType, uint8 tabId, ObjectGuid::LowType playerGuid, uint32 itemOrMoney, uint16 itemStackCount, uint8 destTabId)` | Bank event | void |
| `CanGuildSendBankList` | `(Guild const*, WorldSession*, uint8 tabId, bool sendAllSlots)` | Bank list send check | bool |

---

### ArenaTeamScript

Registration: `new MyArenaTeamScript("name", {ARENATEAMHOOK_..., ...})`.
Attach to: arena teams globally. DB Bound: no.
Base class: `class MyScript : public ArenaTeamScript`

| Method | Signature | When it fires |
|---|---|---|
| `OnGetSlotByType` | `(const uint32 type, uint8& slot)` | Arena type → slot mapping |
| `OnGetArenaPoints` | `(ArenaTeam*, float& points)` | Arena points calculation |
| `OnTypeIDToQueueID` | `(const BattlegroundTypeId, const uint8 arenaType, uint32& queueTypeID)` | Queue ID mapping |
| `OnQueueIdToArenaType` | `(const BattlegroundQueueTypeId, uint8& ArenaType)` | Arena type mapping |
| `OnSetArenaMaxPlayersPerTeam` | `(const uint8 arenaType, uint32& maxPlayerPerTeam)` | Max players per team |

---

### ArenaScript

Registration: `new MyArenaScript("name", {ARENAHOOK_..., ...})`.
Attach to: arena globally. DB Bound: no.
Base class: `class MyScript : public ArenaScript`

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `CanAddMember` | `(ArenaTeam*, ObjectGuid)` | Adding member to team | bool |
| `OnGetPoints` | `(ArenaTeam*, uint32 memberRating, float& points)` | Points calculation | void |
| `OnBeforeArenaCheckWinConditions` | `(Battleground* const)` | Before win check | bool |
| `CanSaveToDB` | `(ArenaTeam*)` | Save to DB check | bool |
| `OnArenaStart` | `(Battleground*)` | Arena starts | void |
| `OnBeforeArenaTeamMemberUpdate` | `(ArenaTeam*, Player*, bool won, uint32 opponentMMR, int32 mmrChange)` | Before team member update — return true to skip default update | bool |
| `CanSaveArenaStatsForMember` | `(ArenaTeam*, ObjectGuid)` | Stats save check | bool |

---

### Combat Group

---

### UnitScript

Registration: `new MyUnitScript("name", true, {UNITHOOK_..., ...})`.
Attach to: all units globally. DB Bound: no.
Base class: `class MyScript : public UnitScript`

Note: `UnitScript` constructor takes `bool addToScripts = true`. Set to `false` to use as a mixin only.

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `OnHeal` | `(Unit* healer, Unit* receiver, uint32& gain)` | Healing dealt; modify gain | void |
| `OnDamage` | `(Unit* attacker, Unit* victim, uint32& damage)` | Damage dealt; modify damage | void |
| `ModifyPeriodicDamageAurasTick` | `(Unit* target, Unit* attacker, uint32& damage, SpellInfo const*)` | DoT tick; attacker may be null | void |
| `ModifyMeleeDamage` | `(Unit* target, Unit* attacker, uint32& damage)` | Melee damage | void |
| `ModifySpellDamageTaken` | `(Unit* target, Unit* attacker, int32& damage, SpellInfo const*)` | Spell damage taken | void |
| `ModifyHealReceived` | `(Unit* target, Unit* healer, uint32& heal, SpellInfo const*)` | Heal received | void |
| `DealDamage` | `(Unit* attacker, Unit* victim, uint32 damage, DamageEffectType)` | Damage dealing (return new amount) | uint32 |
| `OnBeforeRollMeleeOutcomeAgainst` | `(Unit const*, Unit const*, WeaponAttackType, int32& attackerMaxSkill, int32& victimMaxSkill, int32& attackerWeaponSkill, int32& victimDefense, int32& crit, int32& miss, int32& dodge, int32& parry, int32& block)` | Before melee outcome roll | void |
| `OnAuraApply` | `(Unit*, Aura*)` | Aura applied | void |
| `OnAuraRemove` | `(Unit*, AuraApplication*, AuraRemoveMode)` | Aura removed | void |
| `IfNormalReaction` | `(Unit const*, Unit const* target, ReputationRank&)` | Normal reaction check | bool |
| `CanSetPhaseMask` | `(Unit const*, uint32 newPhaseMask, bool update)` | Phase mask set | bool |
| `IsCustomBuildValuesUpdate` | `(Unit const*, uint8 updateType, ByteBuffer&, Player const*, uint16 index)` | Custom values update check | bool |
| `ShouldTrackValuesUpdatePosByIndex` | `(Unit const*, uint8 updateType, uint16 index)` | Track values pos | bool |
| `OnPatchValuesUpdate` | `(Unit const*, ByteBuffer&, BuildValuesCachePosPointers&, Player* target)` | Patch values update | void |
| `OnUnitUpdate` | `(Unit*, uint32 diff)` | Unit update tick | void |
| `OnDisplayIdChange` | `(Unit*, uint32 displayId)` | Display ID changed | void |
| `OnUnitEnterEvadeMode` | `(Unit*, uint8 evadeReason)` | Unit enters evade mode | void |
| `OnUnitEnterCombat` | `(Unit*, Unit* victim)` | Unit enters combat | void |
| `OnUnitDeath` | `(Unit*, Unit* killer)` | Unit dies | void |
| `OnUnitSetShapeshiftForm` | `(Unit*, uint8 form)` | Shapeshift form set | void |

---

### FormulaScript

Registration: `new MyFormulaScript("name", {FORMULAHOOK_..., ...})`.
Attach to: game formula/calculation hooks. DB Bound: no.
Base class: `class MyScript : public FormulaScript`

| Method | Signature | When it fires |
|---|---|---|
| `OnHonorCalculation` | `(float& honor, uint8 level, float multiplier)` | Honor amount calculated |
| `OnGrayLevelCalculation` | `(uint8& grayLevel, uint8 playerLevel)` | Gray level calculated (no XP boundary) |
| `OnColorCodeCalculation` | `(XPColorChar& color, uint8 playerLevel, uint8 mobLevel)` | XP color code calculated |
| `OnZeroDifferenceCalculation` | `(uint8& diff, uint8 playerLevel)` | Zero XP difference |
| `OnBaseGainCalculation` | `(uint32& gain, uint8 playerLevel, uint8 mobLevel, ContentLevels)` | Base XP gain |
| `OnGainCalculation` | `(uint32& gain, Player*, Unit*)` | Final XP gain |
| `OnGroupRateCalculation` | `(float& rate, uint32 count, bool isRaid)` | Group XP rate |
| `OnAfterArenaRatingCalculation` | `(Battleground* const, int32& winnerMMRChange, int32& loserMMRChange, int32& winnerChange, int32& loserChange)` | Arena rating changes |
| `OnBeforeUpdatingPersonalRating` | `(int32& mod, uint32 type)` | Personal rating modification |

---

### Content Group

---

### GameEventScript

Registration: `new MyGameEventScript("name", {GAMEEVENTHOOK_..., ...})`.
Attach to: all game events. DB Bound: no.
Base class: `class MyScript : public GameEventScript`

| Method | Signature | When it fires |
|---|---|---|
| `OnStart` | `(uint16 EventID)` | Game event starts |
| `OnStop` | `(uint16 EventID)` | Game event stops |
| `OnEventCheck` | `(uint16 EventID)` | Game event check runs |

---

### AreaTriggerScript

Registration: `new MyAreaTriggerScript("areatrigger_script_name")`.
Attach to: `areatrigger_scripts` DB table. DB Bound: yes.
Base class: `class MyScript : public AreaTriggerScript`

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `OnTrigger` | `(Player*, AreaTrigger const*)` | Player activates area trigger | bool — return true to indicate handled |

**OnlyOnceAreaTriggerScript** is a subclass where `_OnTrigger` only fires once per player/instance:
- `_OnTrigger(Player*, AreaTrigger const*)` — override this instead of `OnTrigger`
- `ResetAreaTriggerDone(InstanceScript*, uint32 triggerId)` — manually reset
- `ResetAreaTriggerDone(Player const*, AreaTrigger const*)` — reset per-player

---

### Module Group

---

### ModuleScript

Registration: `new MyModuleScript("name")`.
Attach to: nothing specific — this is a base class for module-defined script types.
DB Bound: no.
Base class: `class MyScript : public ModuleScript`

```cpp
// From ModuleScript.h:
class ModuleScript : public ScriptObject
{
protected:
    ModuleScript(const char* name);
};
```

`ModuleScript` has **no virtual hooks** of its own. Its purpose is to provide a named, typed base class for
module-specific script objects. A module defines its own interface by extending `ModuleScript` with
custom virtual methods, then other parts of the module implement those methods.

**ModuleScript vs WorldScript:**

| | WorldScript | ModuleScript |
|---|---|---|
| Has built-in hooks | Yes (startup, update, config load, etc.) | No built-in hooks |
| Purpose | React to world lifecycle events | Define module-to-module interfaces |
| Config loading | Use `OnAfterConfigLoad(bool reload)` | N/A — use WorldScript for config |
| Initialization | Use `OnStartup()` | N/A |
| Per-tick work | Use `OnUpdate(uint32 diff)` | N/A |

For module development, you almost always want **WorldScript** for lifecycle events. Use `ModuleScript`
only when building a module that other modules can extend (i.e., you are creating a plugin system within
a plugin).

**Correct hook for common module needs:**

| Need | Use |
|---|---|
| Load config at startup and on `.reload config` | `WorldScript::OnAfterConfigLoad(bool reload)` |
| Initialize after DB is loaded | `DatabaseScript::OnAfterDatabasesLoaded(uint32)` |
| Per-world-tick work | `WorldScript::OnUpdate(uint32 diff)` |
| Cleanup on shutdown | `WorldScript::OnShutdown()` |
| Run code once after all scripts loaded | `WorldScript::OnBeforeWorldInitialized()` |
| React to player login for all players | `PlayerScript::OnPlayerLogin(Player*)` |

---

### Command Group

---

### CommandScript

Registration: `new MyCommandScript("name")`.
Attach to: chat command system. DB Bound: no.
Base class: `class MyScript : public CommandScript`

```cpp
class CommandScript : public ScriptObject
{
public:
    [[nodiscard]] virtual std::vector<Acore::ChatCommands::ChatCommandBuilder> GetCommands() const = 0;
};
```

`GetCommands()` is the only method — it returns a `ChatCommandTable` defining the commands this script
provides. Commands are registered into the global command map automatically.

**ChatCommandBuilder constructor signatures:**

```cpp
// Simple command with handler function:
ChatCommandBuilder(
    const char* name,
    TypedHandler& handler,    // bool (*)(ChatHandler*, ...)
    uint32 securityLevel,     // SEC_PLAYER/SEC_MODERATOR/SEC_GAMEMASTER/SEC_ADMINISTRATOR
    Console allowConsole      // Console::Yes or Console::No
);

// Command with help string:
ChatCommandBuilder(
    const char* name,
    TypedHandler& handler,
    AcoreStrings help,        // language string ID for help text
    uint32 securityLevel,
    Console allowConsole
);

// Sub-command group (no handler, only children):
ChatCommandBuilder(
    const char* name,
    std::vector<ChatCommandBuilder> const& subCommands
);
```

**Security levels** (`AccountTypes` enum in `Common.h`):

| Constant | Value | Meaning |
|---|---|---|
| `SEC_PLAYER` | 0 | Any logged-in player |
| `SEC_MODERATOR` | 1 | GM Level 1 — can use minor tools |
| `SEC_GAMEMASTER` | 2 | GM Level 2 — standard GM commands |
| `SEC_ADMINISTRATOR` | 3 | GM Level 3 — admin-level commands |
| `SEC_CONSOLE` | 4 | Console only (never seen in commands list) |

**Handler function signatures** (modern typed interface):

```cpp
// No extra args:
static bool HandleMyCommand(ChatHandler* handler);

// With typed args (auto-parsed from command string):
static bool HandleMyCommand(ChatHandler* handler, uint32 someId, std::string_view name);
static bool HandleMyCommand(ChatHandler* handler, Optional<Player*> target);
```

**Legacy handler signature** (still supported for compatibility):
```cpp
static bool HandleMyCommand(ChatHandler* handler, char const* args);
```

**Sending output to the GM:**

```cpp
handler->PSendSysMessage("Player {} not found.", playerName);   // printf-style, localized
handler->SendSysMessage(LANG_SOME_STRING_ID);                   // localized string by ID
handler->PSendSysMessage(LANG_SOME_TEMPLATE, arg1, arg2);       // localized with format args
```

**Complete example — `.dreamforge reload` command:**

```cpp
#include "Chat.h"
#include "CommandScript.h"
#include "ScriptMgr.h"
#include "Player.h"

using namespace Acore::ChatCommands;

class dreamforge_commandscript : public CommandScript
{
public:
    dreamforge_commandscript() : CommandScript("dreamforge_commandscript") {}

    ChatCommandTable GetCommands() const override
    {
        // Sub-command table for ".dreamforge"
        static ChatCommandTable dreamforgeCommandTable =
        {
            { "reload", HandleDreamforgeReload, SEC_ADMINISTRATOR, Console::Yes },
            { "info",   HandleDreamforgeInfo,   SEC_GAMEMASTER,    Console::No  },
        };

        // Top-level entry
        static ChatCommandTable commandTable =
        {
            { "dreamforge", dreamforgeCommandTable },
        };

        return commandTable;
    }

    static bool HandleDreamforgeReload(ChatHandler* handler)
    {
        // Reload module config
        sConfigMgr->Reload();
        handler->SendSysMessage("Dreamforge: config reloaded.");
        return true;
    }

    static bool HandleDreamforgeInfo(ChatHandler* handler)
    {
        Player* player = handler->GetSession()->GetPlayer();
        handler->PSendSysMessage("Dreamforge running. Player: {}.", player->GetName());
        return true;
    }
};

void AddSC_dreamforge_commands()
{
    new dreamforge_commandscript();
}
```

---

### AllCommandScript

Registration: `new MyAllCommandScript("name", {ALLCOMMANDHOOK_..., ...})`.
Attach to: all command processing.
DB Bound: no.
Alias: `CommandSC = AllCommandScript`.
Base class: `class MyScript : public AllCommandScript`

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `OnHandleDevCommand` | `(Player*, bool& enable)` | `.dev` command handled | void |
| `OnTryExecuteCommand` | `(ChatHandler&, std::string_view cmdStr)` | Before any command executes | bool — return false to block |
| `OnBeforeIsInvokerVisible` | `(std::string name, CommandPermissions, ChatHandler const&)` | Before checking if command is visible | bool — return false to hide |

---

### Other Script Types

---

### AccountScript

Registration: `new MyAccountScript("name", {ACCOUNTHOOK_..., ...})`.
Attach to: account events. DB Bound: no.
Base class: `class MyScript : public AccountScript`

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `OnAccountLogin` | `(uint32 accountId)` | Account logged in | void |
| `OnBeforeAccountDelete` | `(uint32 accountId)` | Before account deleted | void |
| `OnLastIpUpdate` | `(uint32 accountId, std::string ip)` | IP updated on login | void |
| `OnFailedAccountLogin` | `(uint32 accountId)` | Login attempt failed | void |
| `OnEmailChange` | `(uint32 accountId)` | Email changed | void |
| `OnFailedEmailChange` | `(uint32 accountId)` | Email change failed | void |
| `OnPasswordChange` | `(uint32 accountId)` | Password changed | void |
| `OnFailedPasswordChange` | `(uint32 accountId)` | Password change failed | void |
| `CanAccountCreateCharacter` | `(uint32 accountId, uint8 charRace, uint8 charClass)` | Character creation check | bool — return false to block |

---

### AchievementScript

Registration: `new MyAchievementScript("name", {ACHIEVEMENTHOOK_..., ...})`.
Attach to: achievement system globally. DB Bound: no.
Base class: `class MyScript : public AchievementScript`

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `SetRealmCompleted` | `(AchievementEntry const*)` | Global achievement completed | void |
| `IsCompletedCriteria` | `(AchievementMgr*, AchievementCriteriaEntry const*, AchievementEntry const*, CriteriaProgress const*)` | Criteria completion check | bool |
| `IsRealmCompleted` | `(AchievementGlobalMgr const*, AchievementEntry const*, SystemTimePoint completionTime)` | Realm achievement check | bool |
| `OnBeforeCheckCriteria` | `(AchievementMgr*, std::list<AchievementCriteriaEntry const*> const*)` | Before criteria check | void |
| `CanCheckCriteria` | `(AchievementMgr*, AchievementCriteriaEntry const*)` | Criteria check permission | bool |

---

### AchievementCriteriaScript

Registration: `new MyAchievementCriteriaScript("criteria_script_name")`.
Attach to: `ScriptName` in `achievement_criteria_data`. DB Bound: yes.
Base class: `class MyScript : public AchievementCriteriaScript`

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `OnCheck` | `(Player* source, Unit* target, uint32 criteria_id)` | Criteria checked for player | bool — return false to fail check |

---

### ConditionScript

Registration: `new MyConditionScript("condition_script_name")`.
Attach to: `ScriptName` in condition data. DB Bound: yes.
Base class: `class MyScript : public ConditionScript`

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `OnConditionCheck` | `(Condition*, ConditionSourceInfo&)` | Condition evaluated | bool — return false to fail |

---

### LootScript

Registration: `new MyLootScript("name", {LOOTHOOK_ON_LOOT_MONEY})`.
Attach to: loot system globally. DB Bound: no.
Base class: `class MyScript : public LootScript`

| Method | Signature | When it fires |
|---|---|---|
| `OnLootMoney` | `(Player*, uint32 gold)` | Before money looted from corpse |

---

### MailScript

Registration: `new MyMailScript("name", {MAILHOOK_ON_BEFORE_MAIL_DRAFT_SEND_MAIL_TO})`.
Attach to: mail system. DB Bound: no.
Base class: `class MyScript : public MailScript`

| Method | Signature | When it fires |
|---|---|---|
| `OnBeforeMailDraftSendMailTo` | `(MailDraft*, MailReceiver const&, MailSender const&, MailCheckMask&, uint32& deliver_delay, uint32& custom_expiration, bool& deleteMailItemsFromDB, bool& sendMail)` | Before mail sent; modify all ref params to alter behavior |

---

### MiscScript

Registration: `new MyMiscScript("name", {MISCHOOK_..., ...})`.
Attach to: miscellaneous object lifecycle. DB Bound: no.
Base class: `class MyScript : public MiscScript`

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `OnConstructObject` | `(Object*)` | Object constructed | void |
| `OnDestructObject` | `(Object*)` | Object destructed | void |
| `OnConstructPlayer` | `(Player*)` | Player object constructed | void |
| `OnDestructPlayer` | `(Player*)` | Player object destructed | void |
| `OnConstructGroup` | `(Group*)` | Group constructed | void |
| `OnDestructGroup` | `(Group*)` | Group destructed | void |
| `OnConstructInstanceSave` | `(InstanceSave*)` | InstanceSave constructed | void |
| `OnDestructInstanceSave` | `(InstanceSave*)` | InstanceSave destructed | void |
| `OnItemCreate` | `(Item*, ItemTemplate const*, Player const* owner)` | Item created | void |
| `CanApplySoulboundFlag` | `(Item*, ItemTemplate const*)` | Soulbound application check | bool |
| `CanItemApplyEquipSpell` | `(Player*, Item*)` | Equip spell application | bool |
| `CanSendAuctionHello` | `(WorldSession const*, ObjectGuid, Creature*)` | AH hello packet | bool |
| `ValidateSpellAtCastSpell` | `(Player*, uint32& oldSpellId, uint32& spellId, uint8& castCount, uint8& castFlags)` | Spell validation at cast | void |
| `ValidateSpellAtCastSpellResult` | `(Player*, Unit* mover, Spell*, uint32 oldSpellId, uint32 spellId)` | Spell result validation | void |
| `OnAfterLootTemplateProcess` | `(Loot*, LootTemplate const*, LootStore const&, Player* owner, bool personal, bool noEmptyError, uint16 lootMode)` | After loot template processed | void |
| `OnPlayerSetPhase` | `(AuraEffect const*, AuraApplication const*, uint8 mode, bool apply, uint32& newPhase)` | Player phase set | void |
| `OnInstanceSave` | `(InstanceSave*)` | Instance saved | void |
| `GetDialogStatus` | `(Player*, Object* questgiver)` | Dialog status queried | void |

---

### MovementHandlerScript

Registration: `new MyMovementHandlerScript("name", {MOVEMENTHOOK_ON_PLAYER_MOVE})`.
Attach to: player movement. DB Bound: no.
Base class: `class MyScript : public MovementHandlerScript`

| Method | Signature | When it fires |
|---|---|---|
| `OnPlayerMove` | `(Player*, MovementInfo, uint32 opcode)` | Player sends any movement opcode — fires on every movement packet |

**Warning:** This fires on every movement packet for every player. Even lightweight code here can
accumulate significant overhead.

---

### PetScript

Registration: `new MyPetScript("name", {PETHOOK_..., ...})`.
Attach to: pet system globally. DB Bound: no.
Base class: `class MyScript : public PetScript`

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `OnInitStatsForLevel` | `(Guardian*, uint8 petlevel)` | Guardian/pet stats init for level | void |
| `OnCalculateMaxTalentPointsForLevel` | `(Pet*, uint8 level, uint8& points)` | Pet talent points calc | void |
| `CanUnlearnSpellSet` | `(Pet*, uint32 level, uint32 spell)` | Spell unlearn from set check | bool |
| `CanUnlearnSpellDefault` | `(Pet*, SpellInfo const*)` | Spell unlearn default check | bool |
| `CanResetTalents` | `(Pet*)` | Pet talent reset check | bool |
| `OnPetAddToWorld` | `(Pet*)` | Pet added to world | void |

---

### VehicleScript

Registration: `new MyVehicleScript("name")`.
Attach to: vehicle system. DB Bound: no.
Base class: `class MyScript : public VehicleScript`

| Method | Signature | When it fires |
|---|---|---|
| `OnInstall` | `(Vehicle*)` | Vehicle installed (aura applied) |
| `OnUninstall` | `(Vehicle*)` | Vehicle uninstalled |
| `OnReset` | `(Vehicle*)` | Vehicle resets |
| `OnInstallAccessory` | `(Vehicle*, Creature* accessory)` | Accessory installed |
| `OnAddPassenger` | `(Vehicle*, Unit*, int8 seatId)` | Passenger added |
| `OnRemovePassenger` | `(Vehicle*, Unit*)` | Passenger removed |

---

### WeatherScript

Registration: `new MyWeatherScript("zone_script_name")`.
Attach to: zone name in weather system. DB Bound: yes.
Base class: `class MyScript : public WeatherScript`

`UpdatableScript<Weather>` adds `OnUpdate(Weather*, uint32 diff)`.

| Method | Signature | When it fires |
|---|---|---|
| `OnChange` | `(Weather*, WeatherState state, float grade)` | Weather changes in the zone |

---

### TransportScript

Registration: `new MyTransportScript("transport_script_name")`.
Attach to: specific transport. DB Bound: yes.
Base class: `class MyScript : public TransportScript`

`UpdatableScript<Transport>` adds `OnUpdate(Transport*, uint32 diff)`.

| Method | Signature | When it fires |
|---|---|---|
| `OnAddPassenger` | `(Transport*, Player*)` | Player boards transport |
| `OnAddCreaturePassenger` | `(Transport*, Creature*)` | Creature boards transport |
| `OnRemovePassenger` | `(Transport*, Player*)` | Player exits transport |
| `OnRelocate` | `(Transport*, uint32 waypointId, uint32 mapId, float x, float y, float z)` | Transport moves to waypoint |

---

### DynamicObjectScript

Registration: `new MyDynObjScript("name")`.
Attach to: dynamic objects. DB Bound: no.
Base class: `class MyScript : public DynamicObjectScript`

Only inherits `UpdatableScript<DynamicObject>`:
- `OnUpdate(DynamicObject*, uint32 diff)` — DynObj update tick

---

### WorldObjectScript

Registration: `new MyWorldObjectScript("name", {WORLDOBJECTHOOK_..., ...})`.
Attach to: all world objects. DB Bound: no.
Base class: `class MyScript : public WorldObjectScript`

| Method | Signature | When it fires |
|---|---|---|
| `OnWorldObjectDestroy` | `(WorldObject*)` | Any WorldObject destroyed |
| `OnWorldObjectCreate` | `(WorldObject*)` | Any WorldObject created |
| `OnWorldObjectSetMap` | `(WorldObject*, Map*)` | WorldObject placed on map |
| `OnWorldObjectResetMap` | `(WorldObject*)` | WorldObject removed from map |
| `OnWorldObjectUpdate` | `(WorldObject*, uint32 diff)` | Any WorldObject update tick |

---

### ServerScript

Registration: `new MyServerScript("name", {SERVERHOOK_..., ...})`.
Attach to: network layer. DB Bound: no.
Base class: `class MyScript : public ServerScript`

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `OnNetworkStart` | `()` | Socket I/O started | void |
| `OnNetworkStop` | `()` | Socket I/O stopped | void |
| `OnSocketOpen` | `(shared_ptr<WorldSocket> const&)` | Client connects | void |
| `OnSocketClose` | `(shared_ptr<WorldSocket> const&)` | Client disconnects | void |
| `CanPacketSend` | `(WorldSession*, WorldPacket const&)` | Before packet sent to client | bool — return false to suppress packet |
| `CanPacketReceive` | `(WorldSession*, WorldPacket const&)` | Valid packet received from client | bool — return false to discard |

---

### TicketScript

Registration: `new MyTicketScript("name", {TICKETHOOK_..., ...})`.
Attach to: GM ticket system. DB Bound: no.
Base class: `class MyScript : public TicketScript`

| Method | Signature | When it fires |
|---|---|---|
| `OnTicketCreate` | `(GmTicket*)` | Ticket created |
| `OnTicketUpdateLastChange` | `(GmTicket*)` | Ticket updated |
| `OnTicketClose` | `(GmTicket*)` | Ticket closed |
| `OnTicketStatusUpdate` | `(GmTicket*)` | Ticket status changed |
| `OnTicketResolve` | `(GmTicket*)` | Ticket resolved |

---

### BattlefieldScript

Registration: `new MyBattlefieldScript("name", {BATTLEFIELDHOOK_..., ...})`.
Attach to: world PvP battlefields (Wintergrasp). DB Bound: no.
Base class: `class MyScript : public BattlefieldScript`

| Method | Signature | When it fires |
|---|---|---|
| `OnBattlefieldPlayerEnterZone` | `(Battlefield*, Player*)` | Player enters BF zone — before team assignment |
| `OnBattlefieldPlayerLeaveZone` | `(Battlefield*, Player*)` | Player leaves BF zone — after cleanup |
| `OnBattlefieldPlayerJoinWar` | `(Battlefield*, Player*)` | Player joins active war |
| `OnBattlefieldPlayerLeaveWar` | `(Battlefield*, Player*)` | Player leaves active war |
| `OnBattlefieldBeforeInvitePlayerToWar` | `(Battlefield*, Player*)` | Before player invited to war — reassign team here |

---

### AllBattlegroundScript

Registration: `new MyAllBGScript("name", {ALLBATTLEGROUNDHOOK_..., ...})`.
Attach to: all battlegrounds. DB Bound: no.
Alias: `BGScript = AllBattlegroundScript`.
Base class: `class MyScript : public AllBattlegroundScript`

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `OnBattlegroundStart` | `(Battleground*)` | BG starts | void |
| `OnBattlegroundEndReward` | `(Battleground*, Player*, TeamId winnerTeamId)` | End reward for each player | void |
| `OnBattlegroundUpdate` | `(Battleground*, uint32 diff)` | BG update tick | void |
| `OnBattlegroundAddPlayer` | `(Battleground*, Player*)` | Player added to BG | void |
| `OnBattlegroundBeforeAddPlayer` | `(Battleground*, Player*)` | Before player added | void |
| `OnBattlegroundRemovePlayerAtLeave` | `(Battleground*, Player*)` | Player leaves BG | void |
| `OnQueueUpdate` | `(BattlegroundQueue*, uint32 diff, BattlegroundTypeId, BattlegroundBracketId, uint8 arenaType, bool isRated, uint32 arenaRating)` | Queue update | void |
| `OnQueueUpdateValidity` | `(same as above)` | Queue update validity check | bool |
| `OnAddGroup` | `(BattlegroundQueue*, GroupQueueInfo*, uint32& index, Player* leader, Group*, BattlegroundTypeId, PvPDifficultyEntry const*, uint8 arenaType, bool isRated, bool isPremade, uint32 arenaRating, uint32 mmRating, uint32 arenaTeamId, uint32 opponentsTeamId)` | Group added to queue | void |
| `CanFillPlayersToBG` | `(BattlegroundQueue*, Battleground*, BattlegroundBracketId)` | Fill players check | bool |
| `IsCheckNormalMatch` | `(BattlegroundQueue*, Battleground* bgTemplate, BattlegroundBracketId, uint32 minPlayers, uint32 maxPlayers)` | Normal match check | bool — default false |
| `CanSendMessageBGQueue` | `(BattlegroundQueue*, Player* leader, Battleground*, PvPDifficultyEntry const*)` | BG queue message check | bool |
| `OnBeforeSendJoinMessageArenaQueue` | `(BattlegroundQueue*, Player* leader, GroupQueueInfo*, PvPDifficultyEntry const*, bool isRated)` | Before arena join message | bool — return false to suppress |
| `OnBeforeSendExitMessageArenaQueue` | `(BattlegroundQueue*, GroupQueueInfo*)` | Before arena exit message | bool — return false to suppress |
| `OnBattlegroundEnd` | `(Battleground*, TeamId winner)` | After BG ends | void |
| `OnBattlegroundDestroy` | `(Battleground*)` | Before BG destroyed | void |
| `OnBattlegroundCreate` | `(Battleground*)` | After BG created | void |
| `CanAddGroupToMatchingPool` | `(BattlegroundQueue*, GroupQueueInfo*, uint32 poolPlayerCount, Battleground*, BattlegroundBracketId)` | Before group added to selection pool | bool — return false to skip group |
| `GetPlayerMatchmakingRating` | `(ObjectGuid, BattlegroundTypeId, float& outRating)` | Provide player MMR rating | bool — return true if rating was set |

---

### BattlegroundScript

Registration: `new MyBGScript("battleground_script_name")`.
Attach to: specific BG by script name. DB Bound: yes.
Base class: `class MyScript : public BattlegroundScript`

| Method | Return |
|---|---|
| `GetBattleground()` | `Battleground*` — pure virtual, must return fully valid BG object |

---

### OutdoorPvPScript

Registration: `new MyOutdoorPvPScript("outdoorpvp_script_name")`.
Attach to: outdoor PvP zone. DB Bound: yes.
Base class: `class MyScript : public OutdoorPvPScript`

| Method | Return |
|---|---|
| `GetOutdoorPvP()` | `OutdoorPvP*` — pure virtual, return the OutdoorPvP instance |

---

### ALEScript

Registration: `new MyALEScript("name")`.
Attach to: ALE (AzerothCore Lua Engine) module. No DB binding.
Base class: `class MyScript : public ALEScript`

`ALEScript` provides two hooks used internally by the Lua engine module:

| Method | Signature | When it fires | Return |
|---|---|---|---|
| `OnWeatherChange` | `(Weather*, WeatherState, float grade)` | Weather changes | void |
| `CanAreaTrigger` | `(Player*, AreaTrigger const*)` | Area trigger fires | bool — return true to handle via Lua |

This script type is used only by the mod-ale module itself. Module developers writing regular C++ modules
do not need to use or extend `ALEScript`.

---

## 3. PlayerScript — Extra Detail

### Full Method Signatures Reference

All methods are virtual with default no-op implementations. The class uses selective hook registration
via the `enabledHooks` constructor.

**Constructor:**
```cpp
PlayerScript(const char* name, std::vector<uint16> enabledHooks = std::vector<uint16>());
```

**Parameter semantics for key hooks:**

**`OnPlayerGiveXP(Player* player, uint32& amount, Unit* victim, uint8 xpSource)`**
- `amount` is by reference — multiply or set to 0 to modify XP
- `victim` may be null for non-kill XP sources
- `xpSource` identifies the source type (kill, quest, explore, etc.)

**`OnPlayerMoneyChanged(Player* player, int32& amount)`**
- `amount` is signed — can be negative (money removal)
- Called before modification; `amount = 0` cancels the transaction

**`OnPlayerReputationChange(Player*, uint32 factionID, int32& standing, bool incremental)`**
- `incremental = true`: `standing` is the delta being added
- `incremental = false`: `standing` is the new absolute value
- Return `false` to suppress the reputation change

**`OnPlayerBeforeTeleport(Player*, uint32 mapid, float x, float y, float z, float o, uint32 options, Unit* target)`**
- Return `false` to cancel the teleport

**`OnPlayerCanUseChat(...)` — overloaded for 5 chat channel types:**
```cpp
// Default/say/yell:
bool OnPlayerCanUseChat(Player*, uint32 type, uint32 language, std::string& msg)
// Whisper:
bool OnPlayerCanUseChat(Player*, uint32 type, uint32 language, std::string& msg, Player* receiver)
// Group:
bool OnPlayerCanUseChat(Player*, uint32 type, uint32 language, std::string& msg, Group*)
// Guild:
bool OnPlayerCanUseChat(Player*, uint32 type, uint32 language, std::string& msg, Guild*)
// Channel:
bool OnPlayerCanUseChat(Player*, uint32 type, uint32 language, std::string& msg, Channel*)
```
All return `false` to suppress the message.

### Bool-Return Hooks — Can Cancel Behavior

These hooks return `bool` to prevent the default behavior. Return value semantics vary:

**Return `false` to CANCEL/BLOCK:**
- `OnPlayerReputationChange` — false blocks rep change
- `OnPlayerBeforeTeleport` — false cancels teleport
- `OnPlayerBeforeAchievementComplete` — false disables achievement
- `OnPlayerBeforeCriteriaProgress` — false disables criteria
- `OnPlayerCanPlaceAuctionBid` — false blocks bid
- `OnPlayerBeforeOpenItem` — false blocks item open
- `OnPlayerBeforeQuestComplete` — false blocks turn-in
- `OnPlayerCanJoinInBattlegroundQueue` — false blocks queue join
- `OnPlayerCanJoinInArenaQueue` — false blocks arena queue
- `OnPlayerCanBattleFieldPort` — false blocks BG port
- `OnPlayerCanGroupInvite` — false blocks invite
- `OnPlayerCanGroupAccept` — false blocks accept
- `OnPlayerCanSellItem` — false blocks sale
- `OnPlayerCanSendMail` — false blocks mail
- `OnPlayerCanGiveMailRewardAtGiveLevel` — false blocks mail reward
- `OnPlayerCanRepopAtGraveyard` — false blocks repop
- `OnPlayerCanJoinLfg` — false blocks LFG queue
- `OnPlayerCanEnterMap` — false blocks map entry
- `OnPlayerCanInitTrade` — false blocks trade start
- `OnPlayerCanSetTradeItem` — false blocks item in trade
- `OnPlayerCanUseChat` (all variants) — false blocks chat
- `OnPlayerCanFlyInZone` — false blocks flight
- `OnPlayerCanResurrect` — false blocks resurrection
- `OnPlayerCanGiveLevel` — false blocks level-up
- `OnPlayerCanEquipItem` — false blocks equip
- `OnPlayerCanUnequipItem` — false blocks unequip
- `OnPlayerCanUseItem` — false blocks item use
- `OnPlayerCanApplyEnchantment` — false blocks enchantment

**Return `true` to BLOCK (inverted logic for legacy `Can*` functions):**
- `OnPlayerCanAreaExploreAndOutdoor` — false blocks area explore

**Return `true` to ENABLE:**
- `OnPlayerShouldBeRewardedWithMoneyInsteadOfExp` — true gives money instead of XP

### Combat vs Out-of-Combat Hooks

**Fire during combat (potentially every frame at high activity):**
- `OnPlayerBeforeUpdate` / `OnPlayerUpdate` — every world tick
- `OnPlayerSpellCast` — every spell cast
- `OnPlayerEnterCombat` / `OnPlayerLeaveCombat`

**Fire out of combat / session events:**
- `OnPlayerLogin`, `OnPlayerLogout`, `OnPlayerCreate`, `OnPlayerDelete`
- `OnPlayerLevelChanged`, `OnPlayerTalentsReset`, `OnPlayerAfterSpecSlotChanged`
- `OnPlayerLearnSpell`, `OnPlayerForgotSpell`
- `OnPlayerUpdateZone`, `OnPlayerUpdateArea`, `OnPlayerMapChanged`

**Fire for gear/inventory interactions:**
- `OnPlayerEquip`, `OnPlayerUnequip`
- `OnPlayerLootItem`, `OnPlayerStoreNewItem`
- `OnPlayerBeforeBuyItemFromVendor`, `OnPlayerAfterStoreOrEquipNewItem`

### Thread Safety

AzerothCore's world update runs on a single world thread. All `PlayerScript` hooks fire on that world
thread. There is no additional synchronization needed unless you access data from background threads
(e.g., a database async callback, a network thread). If your hook launches async work, protect shared
state with mutexes.

`OnPlayerSendInitialPacketsBeforeAddToMap` fires during session handling which may have different
threading context — check any data you access here.

---

## 4. ModuleScript — Special Coverage

`ModuleScript` is intentionally minimal by design:

```cpp
class ModuleScript : public ScriptObject
{
protected:
    ModuleScript(const char* name);
    // No virtual hooks.
};
```

**Purpose:** Act as a named type for module-defined extension interfaces. When module A wants to allow
module B to hook into it, module A defines a class extending `ModuleScript` with custom virtual methods,
and module B implements a subclass of that.

**For standard module lifecycle, use `WorldScript`:**

```cpp
class MyModuleWorldScript : public WorldScript
{
public:
    MyModuleWorldScript() : WorldScript("my_module_world", {
        WORLDHOOK_ON_BEFORE_CONFIG_LOAD,
        WORLDHOOK_ON_AFTER_CONFIG_LOAD,
        WORLDHOOK_ON_STARTUP,
        WORLDHOOK_ON_SHUTDOWN,
        WORLDHOOK_ON_UPDATE,
    }) {}

    void OnBeforeConfigLoad(bool reload) override
    {
        // First call: initial config load (reload = false)
        // Subsequent calls: `.reload config` (reload = true)
        // Good place to read sConfigMgr->GetOption<bool>("MyModule.Enable", false)
        // but NOT to initialize systems that need the DB
    }

    void OnAfterConfigLoad(bool reload) override
    {
        // Same timing — use either Before or After depending on whether
        // you need to see the old or new config values
    }

    void OnStartup() override
    {
        // World fully started, DB loaded, all scripts registered.
        // Use this for one-time initialization.
        // Note: sWorld->GetDBVersion() is available here.
    }

    void OnUpdate(uint32 diff) override
    {
        // Runs every world tick (typically 100ms unless server is lagging).
        // Keep this lightweight — accumulate time and only act every N seconds.
    }

    void OnShutdown() override
    {
        // Cleanup: flush caches, save state, etc.
    }
};
```

**For initialization after DB is fully loaded, use `DatabaseScript`:**

```cpp
class MyModuleDatabaseScript : public DatabaseScript
{
public:
    MyModuleDatabaseScript() : DatabaseScript("my_module_db", {
        DATABASEHOOK_ON_AFTER_DATABASES_LOADED
    }) {}

    void OnAfterDatabasesLoaded(uint32 updateFlags) override
    {
        // All three databases are loaded and available here.
        // Load custom tables, build caches from DB, etc.
    }
};
```

**Correct hook selection:**

| Situation | Hook |
|---|---|
| Read config values | `WorldScript::OnBeforeConfigLoad` or `OnAfterConfigLoad` |
| Initialize after DB loaded | `DatabaseScript::OnAfterDatabasesLoaded` |
| React to `.reload config` | `WorldScript::OnAfterConfigLoad(reload == true)` |
| Per-tick timer work | `WorldScript::OnUpdate(diff)` |
| Cleanup on shutdown | `WorldScript::OnShutdown()` |
| React to all player logins | `PlayerScript::OnPlayerLogin` |
| React to creature spawn globally | `AllCreatureScript::OnCreatureAddWorld` |

---

## 5. CommandScript — How to Add GM Commands

### ChatCommandBuilder Structure

The `ChatCommandBuilder` type wraps either a command handler function + permissions, or a sub-command
table. Both are held in a `std::variant`.

```cpp
namespace Acore::ChatCommands {
    using ChatCommandTable = std::vector<ChatCommandBuilder>;

    struct ChatCommandBuilder {
        // Leaf command with typed handler:
        template <typename TypedHandler>
        ChatCommandBuilder(const char* name, TypedHandler& handler,
                           uint32 securityLevel, Console allowConsole);

        // Leaf command with typed handler + help string:
        template <typename TypedHandler>
        ChatCommandBuilder(const char* name, TypedHandler& handler,
                           AcoreStrings help,
                           uint32 securityLevel, Console allowConsole);

        // Sub-command group (no handler, just children):
        ChatCommandBuilder(const char* name,
                           std::vector<ChatCommandBuilder> const& subCommands);
    };
}
```

### Security Levels

```
SEC_PLAYER       = 0  — visible to all players (e.g., .commands, .help)
SEC_MODERATOR    = 1  — minor GM access (e.g., .gps, .appear)
SEC_GAMEMASTER   = 2  — standard GM (e.g., .npc add, .go, .revive)
SEC_ADMINISTRATOR= 3  — admin-level (e.g., .server shutdown, .debug)
SEC_CONSOLE      = 4  — console only, not visible in-game
```

### Defining Sub-Commands

Sub-command tables are static locals inside `GetCommands()`:

```cpp
// Creates: .mymod info     and .mymod reload
ChatCommandTable GetCommands() const override
{
    static ChatCommandTable subTable =
    {
        { "info",   HandleInfo,   SEC_GAMEMASTER, Console::No  },
        { "reload", HandleReload, SEC_ADMINISTRATOR, Console::Yes },
    };

    // "" entry creates an unnamed handler for the parent command itself
    static ChatCommandTable mainTable =
    {
        { "",       HandleDefault, SEC_GAMEMASTER, Console::No },  // .mymod <no subcommand>
        { "mymod",  subTable },                                     // .mymod info / .mymod reload
    };

    return mainTable;
}
```

### The ChatHandler Interface

The `ChatHandler*` passed to every handler provides:

```cpp
// Output to the invoking GM:
handler->PSendSysMessage("fmt {} arg", value);        // formatted, localized
handler->SendSysMessage("plain text");                 // literal string
handler->SendSysMessage(LANG_SOME_STRING);             // localized by ID

// Get invoking player (null if console):
Player* invoker = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;

// Target selection (uses selected target or target player from args):
Player* target = handler->getSelectedPlayer();
Creature* creature = handler->getSelectedCreature();
Unit* unit = handler->getSelectedUnit();

// Localization:
const char* localStr = handler->GetAcoreString(LANG_SOME_ID);
std::string nameLink = handler->GetNameLink(player);  // [Name] clickable link

// Authority check:
bool isGM = handler->IsConsole() || handler->GetSession()->GetSecurity() >= SEC_GAMEMASTER;
```

**`PSendSysMessage` vs `SendSysMessage`:**
- `PSendSysMessage(fmt, ...)` — takes a format string with `{}` placeholders (libfmt style). Use for
  runtime-constructed messages.
- `SendSysMessage(str)` — takes a literal string or localized string constant. Use for fixed messages.
- Both display in the System Message chat frame (yellow text) to the GM.

### Complete Example: `.dreamforge reload`

See the example in Section 2 (CommandScript) above for a full working implementation.

---

## 6. AllCreatureScript vs CreatureScript

### AllCreatureScript: Global Scope, Performance Cost

```
AllCreatureScript fires for EVERY creature in the world.
```

- `OnAllCreatureUpdate` fires every world tick for every loaded creature.
  On a populated server with thousands of creatures, this can be a significant overhead.
- `CanCreatureGossipHello` fires when ANY player opens a gossip with ANY creature — not just
  creatures with your script name.
- `GetCreatureAI` is called when any creature spawns and needs an AI object.

**Use AllCreatureScript when:**
- You need to intercept events for creatures you do not control (e.g., all creatures of a certain type)
- You are building a framework (like ALE) that routes events to a scripting engine

**Avoid AllCreatureScript when:**
- You only care about specific NPCs — use `CreatureScript` with a DB `ScriptName` instead
- Your hook contains database queries, complex logic, or memory allocation per call

### CreatureScript: Targeted, Efficient

```
CreatureScript fires ONLY for creatures whose creature_template.ScriptName matches.
```

The creature entry in `creature_template` must have the `ScriptName` field set:
```sql
UPDATE creature_template SET ScriptName = 'npc_my_boss' WHERE entry = 12345;
```

Then your script registers under that exact name:
```cpp
class npc_my_boss : public CreatureScript
{
public:
    npc_my_boss() : CreatureScript("npc_my_boss") {}
    CreatureAI* GetAI(Creature* creature) const override { return new npc_my_bossAI(creature); }
};
```

### Hooks Exclusive to AllCreatureScript

These hooks exist only in `AllCreatureScript`, not in `CreatureScript`:

| Hook | Note |
|---|---|
| `OnAllCreatureUpdate(Creature*, uint32 diff)` | Per-frame for all creatures |
| `OnBeforeCreatureSelectLevel(CreatureTemplate const*, Creature*, uint8& level)` | Pre-level selection |
| `OnCreatureSelectLevel(CreatureTemplate const*, Creature*)` | Post-level selection |
| `OnCreatureAddWorld(Creature*)` | Any creature added to world |
| `OnCreatureRemoveWorld(Creature*)` | Any creature removed from world |
| `OnCreatureSaveToDB(Creature*)` | Any creature saved |
| `OnFfaPvpStateUpdate(Creature*, bool)` | FFA PvP bit changed on creature |

`CreatureScript` has the corresponding gossip/quest hooks for its bound creature only, plus `GetAI()`.

---

## 7. Hook Execution Order

### Multiple Scripts for the Same Hook

When multiple scripts of the same type implement the same hook, they are iterated in **registration
order** — the order in which `new MyScript()` was called during `AddSC_*()`.

For **void hooks** (`void OnXxx(...)`):
- All scripts receive the call, in registration order
- No script can prevent others from receiving it

For **bool hooks** (`[[nodiscard]] virtual bool OnXxx(...)`):

The behavior depends on which dispatch macro ScriptMgr uses internally:

- `CALL_ENABLED_BOOLEAN_HOOKS(type, hookEnum, action)`:
  - Iterates all scripts for that hook
  - Returns `false` as soon as any script's action evaluates to `true`
  - Default return if no scripts: `true` (permissive)
  - Effect: any single script can block the action

- `CALL_ENABLED_BOOLEAN_HOOKS_WITH_DEFAULT_FALSE(type, hookEnum, action)`:
  - Returns `true` as soon as any script's action evaluates to `true`
  - Default return if no scripts: `false`
  - Effect: any single script can enable the action

- `IsValidBoolScript<T>(fn)`:
  - Returns `Optional<bool>` — stops at first script returning `true`
  - Returns `nullopt` if no scripts or none return `true`

### Practical Consequences

1. **Two modules both block the same `CanXxx` hook**: If module A returns `false` (blocking action),
   the ScriptMgr macro stops iterating and returns `false`. Module B never sees the call for that
   particular invocation. The action is blocked.

2. **Two modules both modify a `uint32& amount` parameter**: Both see the modified value in sequence —
   Module A sets `amount = amount * 2`, then Module B receives the already-doubled value and can
   modify it further. Order matters; the last modification wins.

3. **`GetAI()` returning non-null**: For `AllCreatureScript::GetCreatureAI()`, the first script to
   return a non-null AI wins (`GetReturnAIScript` template). Subsequent scripts in the list are not
   checked. This means only one `AllCreatureScript` can provide an AI for a given creature.

4. **Module load order**: Modules are loaded in the order determined by CMake/the module loader.
   Registration order within a single module follows the order of `new Script()` calls in `AddSC_*()`.
   Across modules, order is not strictly guaranteed — do not rely on it for critical logic.

### Cannot Cancel Already-Fired Void Hooks

Once a void hook fires and delivers to all scripts, there is no way to "undo" side effects from earlier
scripts in the chain. If module A does work in `OnPlayerLogin` and module B needs to conditionally
prevent that work, B must either:
- Be registered before A (and set a flag that A checks), or
- Both scripts check a shared condition before acting
