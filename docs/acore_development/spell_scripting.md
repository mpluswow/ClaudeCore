# AzerothCore Spell Scripting API (C++)

SpellScript and AuraScript are the primary hooks for customizing spell behaviour in AzerothCore. SpellScript hooks run once per cast; AuraScript hooks run for the lifetime of the aura.

---

## SpellScript Registration Pattern

Every spell script class derives from `SpellScript` and uses two required macros:

```cpp
// Header-style declaration inside the class
PrepareSpellScript(spell_my_spell);

// Validate spell IDs exist at server startup
bool Validate(SpellInfo const* /*spellInfo*/) override
{
    return ValidateSpellInfo({ SPELL_FOO, SPELL_BAR });
}
```

`ValidateSpellInfo` takes an initializer list of spell IDs. If any ID is missing from the database the entire script is skipped at startup.

### Registration Macros

```cpp
// Single SpellScript (no aura)
RegisterSpellScript(spell_my_spell);

// Single AuraScript (no spell phase)
RegisterSpellScript(spell_my_aura);          // same macro, different base class

// Paired spell + aura for the same spell ID
RegisterSpellAndAuraScriptPair(spell_my_spell, spell_my_aura);
```

These macros live inside the module's `AddSC_` function:

```cpp
void AddSC_my_module()
{
    RegisterSpellScript(spell_my_damage);
    RegisterSpellAndAuraScriptPair(spell_my_dot, spell_my_dot_aura);
}
```

The `AddSC_` function must be declared in a header and called from the module's `loader.cpp`.

### Attaching to Spell IDs

Attachment is done through the spell_script_names database table, **not** in C++. The script name string (e.g. `"spell_my_damage"`) is inserted into the table with the target spell ID. The class name and string must match exactly.

```sql
INSERT INTO spell_script_names (spell_id, ScriptName) VALUES (12345, 'spell_my_damage');
```

---

## SpellScript Hooks — Complete List

All registrations go inside `void Register() override {}`.

| Hook list | Fn macro | Signature | When it fires |
|-----------|----------|-----------|---------------|
| `BeforeCast` | `SpellCastFn` | `void f()` | Before cast starts; caster/target not yet determined |
| `OnCast` | `SpellCastFn` | `void f()` | After successful cast setup |
| `AfterCast` | `SpellCastFn` | `void f()` | After all effects have processed |
| `OnCheckCast` | `SpellCheckCastFn` | `SpellCastResult f()` | Return `SPELL_CAST_OK` or a fail result to block |
| `BeforeHit` | `BeforeSpellHitFn` | `void f(SpellMissInfo missInfo)` | Before hit phase for each target |
| `OnHit` | `SpellHitFn` | `void f()` | During hit phase; use `GetHitDamage()`/`SetHitDamage()` here |
| `AfterHit` | `SpellHitFn` | `void f()` | After all hit-phase effects for current target |
| `OnEffectLaunch` | `SpellEffectFn` | `void f(SpellEffIndex)` | Effect projectile launched (before travel) |
| `OnEffectLaunchTarget` | `SpellEffectFn` | `void f(SpellEffIndex)` | Projectile launched toward specific target |
| `OnEffectHit` | `SpellEffectFn` | `void f(SpellEffIndex)` | Effect fires (area/non-targeted) |
| `OnEffectHitTarget` | `SpellEffectFn` | `void f(SpellEffIndex)` | Effect fires on a specific target |
| `OnObjectAreaTargetSelect` | `SpellObjectAreaTargetSelectFn` | `void f(std::list<WorldObject*>&)` | Modify or replace the AoE target list |
| `OnObjectTargetSelect` | `SpellObjectTargetSelectFn` | `void f(WorldObject*&)` | Replace a single target selection |
| `OnDestinationTargetSelect` | `SpellDestinationTargetSelectFn` | `void f(SpellDestination&)` | Modify the destination of a targeted location spell |

### Registration Syntax

```cpp
void Register() override
{
    OnCheckCast += SpellCheckCastFn(MySpell::CheckCast);
    BeforeCast   += SpellCastFn(MySpell::HandleBeforeCast);
    OnCast       += SpellCastFn(MySpell::HandleCast);
    AfterCast    += SpellCastFn(MySpell::HandleAfterCast);
    OnHit        += SpellHitFn(MySpell::HandleHit);
    AfterHit     += SpellHitFn(MySpell::HandleAfterHit);

    // Effect hooks require effect index + spell effect type
    OnEffectHitTarget += SpellEffectFn(MySpell::HandleEffect, EFFECT_0, SPELL_EFFECT_SCHOOL_DAMAGE);

    // Target select hooks require effect index + target type
    OnObjectAreaTargetSelect += SpellObjectAreaTargetSelectFn(MySpell::FilterTargets, EFFECT_0, TARGET_UNIT_SRC_AREA_ENEMY);
}
```

### Key SpellScript Getter/Setter Methods

```cpp
// Caster / target access
Unit*           GetCaster();
Unit*           GetOriginalCaster();
Unit*           GetHitUnit();       // valid only in OnHit / AfterHit / OnEffectHitTarget
Player*         GetHitPlayer();
Creature*       GetHitCreature();
SpellInfo const* GetSpellInfo();
SpellInfo const* GetTriggeringSpell();
Item*           GetCastItem();

// Target position
WorldLocation const* GetExplTargetDest();
WorldObject*         GetExplTargetWorldObject();
Unit*                GetExplTargetUnit();

// Damage / heal (OnHit / OnEffectHitTarget only)
int32  GetHitDamage();
void   SetHitDamage(int32 damage);
void   PreventHitDamage();
int32  GetHitHeal();
void   SetHitHeal(int32 heal);
void   PreventHitHeal();

// Aura result of the hit
Aura*  GetHitAura();
void   PreventHitAura();

// Effect value helpers
int32  GetEffectValue() const;
void   SetEffectValue(int32 value);

// Effect suppression
void   PreventHitEffect(SpellEffIndex effIndex);
void   PreventHitDefaultEffect(SpellEffIndex effIndex);

// Cast control
void   FinishCast(SpellCastResult result);
void   Cancel();
void   SetCustomCastResultMessage(SpellCustomErrors result);
```

---

## AuraScript Hooks — Complete List

| Hook list | Fn macro | Signature | When it fires |
|-----------|----------|-----------|---------------|
| `OnEffectApply` | `AuraEffectApplyFn` | `void f(AuraEffect const*, AuraEffectHandleModes)` | Effect applied to owner |
| `AfterEffectApply` | `AuraEffectApplyFn` | same | After default apply logic |
| `OnEffectRemove` | `AuraEffectRemoveFn` | `void f(AuraEffect const*, AuraEffectHandleModes)` | Effect being removed |
| `AfterEffectRemove` | `AuraEffectRemoveFn` | same | After default remove logic |
| `OnEffectPeriodic` | `AuraEffectPeriodicFn` | `void f(AuraEffect const*)` | Each periodic tick |
| `OnEffectUpdatePeriodic` | `AuraEffectUpdatePeriodicFn` | `void f(AuraEffect*)` | Periodic timer update (can change amount) |
| `DoEffectCalcAmount` | `AuraEffectCalcAmountFn` | `void f(AuraEffect*, int32& amount, bool& canBeRecalculated)` | When effect amount is (re)calculated |
| `DoEffectCalcPeriodic` | `AuraEffectCalcPeriodicFn` | `void f(AuraEffect const*, bool& isPeriodic, int32& amplitude)` | When periodic interval is calculated |
| `DoEffectCalcSpellMod` | `AuraEffectCalcSpellModFn` | `void f(AuraEffect const*, SpellModifier*&)` | Spell modifier calculation |
| `DoCheckProc` | `AuraCheckProcFn` | `bool f(ProcEventInfo&)` | Return false to deny proc |
| `DoCheckEffectProc` | `AuraCheckEffectProcFn` | `bool f(AuraEffect const*, ProcEventInfo&)` | Per-effect proc gate |
| `DoPrepareProc` | `AuraProcFn` | `void f(ProcEventInfo&)` | Before proc executes |
| `OnProc` | `AuraProcFn` | `void f(ProcEventInfo&)` | Proc fires (aura level) |
| `AfterProc` | `AuraProcFn` | `void f(ProcEventInfo&)` | After proc logic |
| `OnEffectProc` | `AuraEffectProcFn` | `void f(AuraEffect const*, ProcEventInfo&)` | Proc fires per effect |
| `AfterEffectProc` | `AuraEffectProcFn` | same | After per-effect proc |
| `OnDispel` | `AuraDispelFn` | `void f(DispelInfo*)` | Aura is being dispelled |
| `AfterDispel` | `AuraDispelFn` | same | After dispel |
| `DoCheckAreaTarget` | `AuraCheckAreaTargetFn` | `bool f(Unit*)` | Return false to exclude unit from aura area |

### Registration Syntax

```cpp
void Register() override
{
    // Apply/Remove require: effect index, SPELL_AURA_TYPE, handle mode mask
    OnEffectApply  += AuraEffectApplyFn(MyAura::OnApply, EFFECT_0, SPELL_AURA_DUMMY,
                          AURA_EFFECT_HANDLE_REAL);
    OnEffectRemove += AuraEffectRemoveFn(MyAura::OnRemove, EFFECT_0, SPELL_AURA_DUMMY,
                          AURA_EFFECT_HANDLE_REAL);

    // Periodic: effect index + SPELL_AURA_TYPE
    OnEffectPeriodic += AuraEffectPeriodicFn(MyAura::OnTick, EFFECT_0, SPELL_AURA_PERIODIC_DAMAGE);

    // Calc amount: effect index + SPELL_AURA_TYPE
    DoEffectCalcAmount += AuraEffectCalcAmountFn(MyAura::CalcAmount, EFFECT_0, SPELL_AURA_MOD_INCREASE_SPEED);

    // Proc handlers
    DoCheckProc  += AuraCheckProcFn(MyAura::CheckProc);
    OnEffectProc += AuraEffectProcFn(MyAura::HandleProc, EFFECT_0, SPELL_AURA_DUMMY);
}
```

### Key AuraScript Getter/Setter Methods

```cpp
// Identity
SpellInfo const* GetSpellInfo() const;
uint32           GetId() const;

// Caster / owner
Unit*            GetCaster() const;
ObjectGuid       GetCasterGUID() const;
WorldObject*     GetOwner() const;
Unit*            GetUnitOwner() const;     // nullptr if dynamic object
Unit*            GetTarget() const;        // the unit this AuraApplication is on

// Aura object
Aura*            GetAura() const;
AuraApplication const* GetTargetApplication() const;
AuraObjectType   GetType() const;          // UNIT_AURA_TYPE or DYNOBJ_AURA_TYPE

// Duration
int32  GetDuration() const;
void   SetDuration(int32 duration, bool withMods = false);
void   RefreshDuration();
int32  GetMaxDuration() const;
void   SetMaxDuration(int32 duration);
bool   IsExpired() const;
bool   IsPermanent() const;

// Stacks / charges
uint8  GetStackAmount() const;
void   SetStackAmount(uint8 num);
bool   ModStackAmount(int32 num, AuraRemoveMode removeMode = AURA_REMOVE_BY_DEFAULT);
uint8  GetCharges() const;
void   SetCharges(uint8 charges);
bool   DropCharge(AuraRemoveMode removeMode = AURA_REMOVE_BY_DEFAULT);

// Effects
bool         HasEffect(uint8 effIndex) const;
AuraEffect*  GetEffect(uint8 effIndex) const;

// Removal
void   Remove(AuraRemoveMode removeMode = AURA_REMOVE_BY_DEFAULT);

// Misc
bool   IsPassive() const;
bool   IsDeathPersistent() const;
void   PreventDefaultAction();  // suppress the built-in effect handler
```

---

## AuraEffectHandleModes

Passed as the fourth argument to apply/remove Fn macros.

| Value | Meaning |
|-------|---------|
| `AURA_EFFECT_HANDLE_REAL` (0x01) | Effect actually applied/removed from the unit (use for game-logic changes) |
| `AURA_EFFECT_HANDLE_SEND_FOR_CLIENT` (0x02) | Client packet is being sent for apply/remove |
| `AURA_EFFECT_HANDLE_CHANGE_AMOUNT` (0x04) | Amount changed while aura is already active |
| `AURA_EFFECT_HANDLE_REAPPLY` (0x08) | Aura reapplied (refreshed) while already present |
| `AURA_EFFECT_HANDLE_STAT` (0x10) | Stat recalculation pass |
| `AURA_EFFECT_HANDLE_SKILL` (0x20) | Skill recalculation pass |
| `AURA_EFFECT_HANDLE_SEND_FOR_CLIENT_MASK` | `REAL \| SEND_FOR_CLIENT` |
| `AURA_EFFECT_HANDLE_CHANGE_AMOUNT_MASK` | `REAL \| CHANGE_AMOUNT` |
| `AURA_EFFECT_HANDLE_CHANGE_AMOUNT_SEND_FOR_CLIENT_MASK` | All three above combined |
| `AURA_EFFECT_HANDLE_REAL_OR_REAPPLY_MASK` | `REAL \| REAPPLY` |

Use `AURA_EFFECT_HANDLE_REAL` when you only want your handler to run once when the aura is actually applied or removed. Use `AURA_EFFECT_HANDLE_REAL_OR_REAPPLY_MASK` when you also need to react to stack refreshes.

---

## Casting Spells via C++

```cpp
// Simple triggered cast (bypasses GCD, no cost)
caster->CastSpell(target, SPELL_ID, true);

// Untriggered cast (respects GCD, costs, channeling, etc.)
caster->CastSpell(target, SPELL_ID, false);

// With fine-grained trigger control
caster->CastSpell(target, SPELL_ID, TRIGGERED_IGNORE_GCD | TRIGGERED_IGNORE_SPELL_AND_CATEGORY_CD);

// Cast to a position
caster->CastSpell(x, y, z, SPELL_ID, true);
```

### TriggerCastFlags (combinable bitmask)

| Flag | Effect |
|------|--------|
| `TRIGGERED_NONE` | Normal cast, all rules apply |
| `TRIGGERED_IGNORE_GCD` | Skip global cooldown |
| `TRIGGERED_IGNORE_SPELL_AND_CATEGORY_CD` | Skip spell and category cooldown |
| `TRIGGERED_IGNORE_POWER_AND_REAGENT_COST` | No mana / reagent cost |
| `TRIGGERED_IGNORE_CAST_ITEM` | Don't consume a cast item |
| `TRIGGERED_IGNORE_CAST_IN_PROGRESS` | Cast while already casting |
| `TRIGGERED_IGNORE_AURA_INTERRUPT_FLAGS` | Don't trigger aura interrupts |
| `TRIGGERED_IGNORE_SHAPESHIFT` | Bypass form restrictions |
| `TRIGGERED_IGNORE_CASTER_AURAS` | Ignore aura requirements on caster |
| `TRIGGERED_DISALLOW_PROC_EVENTS` | Suppress proc events this cast would cause |
| `TRIGGERED_DONT_REPORT_CAST_ERROR` | Silent failure (no error message) |
| `TRIGGERED_FULL_MASK` | All standard triggered flags |

### Direct Aura Manipulation

```cpp
// Bypass cast entirely — places aura immediately
Aura* aura = target->AddAura(SPELL_ID, target);
if (aura)
{
    aura->SetStackAmount(3);
    aura->SetDuration(10000);   // milliseconds; -1 = permanent
}

// Remove aura
unit->RemoveAurasDueToSpell(SPELL_ID);
unit->RemoveAura(SPELL_ID, casterGUID);          // optional: restrict by caster
unit->RemoveAura(SPELL_ID, ObjectGuid::Empty, 0, AURA_REMOVE_BY_CANCEL);
unit->RemoveAurasByType(SPELL_AURA_MOD_STUN);

// Query auras
bool has   = unit->HasAura(SPELL_ID);
Aura* aura = unit->GetAura(SPELL_ID);
AuraEffect* eff = unit->GetAuraEffect(SPELL_ID, EFFECT_0);
AuraEffect* eff = unit->GetAuraEffectOfRankedSpell(SPELL_ID_RANK1, EFFECT_0);
```

### Cooldown Management

```cpp
// Player cooldowns
player->AddSpellCooldown(spellId, 0, GameTime::GetGameTimeMS() + 5000); // 5 s
player->AddSpellAndCategoryCooldowns(spellInfo, itemId, spell);          // full normal flow
player->RemoveSpellCooldown(spellId, true);  // true = send update packet to client
player->RemoveCategoryCooldown(categoryId);
player->ModifySpellCooldown(spellId, -1000); // reduce by 1 s
bool onCD = player->HasSpellCooldown(spellId);
uint32 remaining = player->GetSpellCooldownDelay(spellId); // ms remaining
```

---

## Complete Working Example

```cpp
#include "ScriptMgr.h"
#include "SpellScript.h"
#include "SpellAuraEffects.h"

enum MySpellIds
{
    SPELL_MY_MAIN    = 70001,
    SPELL_MY_PROC    = 70002,
    SPELL_MY_TRIGGER = 70003,
};

// ---- SpellScript: modify direct damage on hit ----

class spell_my_damage : public SpellScript
{
    PrepareSpellScript(spell_my_damage);

    bool Validate(SpellInfo const* /*spellInfo*/) override
    {
        return ValidateSpellInfo({ SPELL_MY_MAIN, SPELL_MY_TRIGGER });
    }

    SpellCastResult CheckCast()
    {
        if (!GetCaster()->IsAlive())
            return SPELL_FAILED_CASTER_DEAD;
        return SPELL_CAST_OK;
    }

    void HandleHit()
    {
        Unit* caster = GetCaster();
        Unit* target = GetHitUnit();
        if (!caster || !target)
            return;

        int32 damage = GetHitDamage();
        // +10 % if target is below 30 % health
        if (target->GetHealthPct() < 30.0f)
            AddPct(damage, 10);
        SetHitDamage(damage);
    }

    void HandleEffect(SpellEffIndex /*effIndex*/)
    {
        // Cast a bonus trigger spell on hit
        GetCaster()->CastSpell(GetHitUnit(), SPELL_MY_TRIGGER, true);
    }

    void Register() override
    {
        OnCheckCast += SpellCheckCastFn(spell_my_damage::CheckCast);
        OnHit       += SpellHitFn(spell_my_damage::HandleHit);
        OnEffectHitTarget += SpellEffectFn(spell_my_damage::HandleEffect,
            EFFECT_0, SPELL_EFFECT_SCHOOL_DAMAGE);
    }
};

// ---- AuraScript: periodic DoT + proc handler ----

class spell_my_dot_aura : public AuraScript
{
    PrepareAuraScript(spell_my_dot_aura);

    bool Validate(SpellInfo const* /*spellInfo*/) override
    {
        return ValidateSpellInfo({ SPELL_MY_PROC });
    }

    void OnApply(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        // Example: store a flag on apply
        if (Unit* target = GetTarget())
            target->SetInCombatWith(GetCaster());
    }

    void OnTick(AuraEffect const* aurEff)
    {
        Unit* caster = GetCaster();
        Unit* target = GetTarget();
        if (!caster || !target)
            return;

        // Deal bonus damage every 2nd tick
        if (aurEff->GetTickNumber() % 2 == 0)
        {
            int32 bonus = aurEff->GetAmount() / 2;
            caster->CastCustomSpell(SPELL_MY_TRIGGER, SPELLVALUE_BASE_POINT0,
                bonus, target, true);
        }
    }

    bool CheckProc(ProcEventInfo& eventInfo)
    {
        // Only proc on direct damage events
        return eventInfo.GetDamageInfo() != nullptr;
    }

    void HandleProc(AuraEffect const* aurEff, ProcEventInfo& eventInfo)
    {
        PreventDefaultAction();
        Unit* actor = eventInfo.GetActor();
        if (!actor)
            return;
        actor->CastSpell(actor, SPELL_MY_PROC, true);
    }

    void OnRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes mode)
    {
        // Only react to the real removal, not stat recalc passes
        if (mode != AURA_EFFECT_HANDLE_REAL)
            return;
        // cleanup logic here
    }

    void Register() override
    {
        OnEffectApply   += AuraEffectApplyFn(spell_my_dot_aura::OnApply,
            EFFECT_0, SPELL_AURA_PERIODIC_DAMAGE, AURA_EFFECT_HANDLE_REAL);
        OnEffectRemove  += AuraEffectRemoveFn(spell_my_dot_aura::OnRemove,
            EFFECT_0, SPELL_AURA_PERIODIC_DAMAGE, AURA_EFFECT_HANDLE_REAL);
        OnEffectPeriodic += AuraEffectPeriodicFn(spell_my_dot_aura::OnTick,
            EFFECT_0, SPELL_AURA_PERIODIC_DAMAGE);
        DoCheckProc  += AuraCheckProcFn(spell_my_dot_aura::CheckProc);
        OnEffectProc += AuraEffectProcFn(spell_my_dot_aura::HandleProc,
            EFFECT_0, SPELL_AURA_PERIODIC_DAMAGE);
    }
};

// ---- Module entry point ----

void AddSC_my_module_spells()
{
    RegisterSpellScript(spell_my_damage);
    RegisterSpellScript(spell_my_dot_aura);
}
```

---

## Damage Formula Reference

| Component | Formula |
|-----------|---------|
| Base damage roll | `basePoints + rand(1, dieSides)` |
| Multiplier | result × `BonusMultiplier` from SpellInfo |
| Direct nuke coefficient | `castTime(s) / 3.5` capped at 1.0 |
| DoT coefficient | `dotDuration(s) / 15.0` |
| AP contribution | `AP × coefficient` (typically 0.1–0.3 for melee procs) |

`SetHitDamage()` sets the value **before** school resistance, damage absorbs, and damage modifiers (like Resilience) are applied. It does not bypass those later reduction steps.

`SetEffectValue()` (called in `OnEffectHitTarget`) sets the raw value of a specific effect before the damage roll. Use `SetHitDamage()` after the roll if you want final flat adjustments.

---

## Cooldown System Notes

- **Category cooldowns** are shared among all spells in the same `SpellCategory`. Setting a CD on one spell sets it on all others in the category.
- `TRIGGERED_IGNORE_GCD` skips only the global cooldown, not the spell's personal CD.
- `TRIGGERED_IGNORE_SPELL_AND_CATEGORY_CD` skips both personal and category CDs.
- `SPELL_ATTR0_COOLDOWN_ON_EVENT` (`SpellAttributes` bit 0x80000000): the spell's cooldown does not start on cast; it starts when a specific game event fires (e.g., a hit lands).
- To give a player a spell and immediately set a custom cooldown:

```cpp
player->LearnSpell(SPELL_ID, false);
SpellInfo const* info = sSpellMgr->GetSpellInfo(SPELL_ID);
if (info)
    player->AddSpellCooldown(SPELL_ID, 0, GameTime::GetGameTimeMS() + 30000); // 30 s
```

---

## See Also

- `docs/acore_development/05_spell_system.md` — SpellInfo struct fields, SpellEffectInfo, AuraType and SpellEffect enums, DBC data layout
- `docs/kb_azerothcore_dev.md` — General module system, hooks overview, creature/player script base classes
