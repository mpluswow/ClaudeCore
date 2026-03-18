# WoW Internals: Taint System, Protected API, and Binary Unlocking
## Reference for WoW 3.3.5a (Build 12340)

---

## Table of Contents

1. [The Taint System — Overview](#1-the-taint-system--overview)
2. [How Taint Propagates](#2-how-taint-propagates)
3. [Secure vs. Insecure Execution Environments](#3-secure-vs-insecure-execution-environments)
4. [Hardware Events (HW Restriction)](#4-hardware-events-hw-restriction)
5. [Protected Function Restriction Categories](#5-protected-function-restriction-categories)
6. [Key Restricted API Functions in WotLK 3.3.5a](#6-key-restricted-api-functions-in-wotlk-335a)
7. [Error Events: ADDON_ACTION_FORBIDDEN vs ADDON_ACTION_BLOCKED](#7-error-events-addon_action_forbidden-vs-addon_action_blocked)
8. [Taint Debugging API](#8-taint-debugging-api)
9. [Secure Addon Patterns — Working Within the System](#9-secure-addon-patterns--working-within-the-system)
10. [SecureHandler Frame Templates](#10-securehandler-frame-templates)
11. [SecureActionButtonTemplate — Full Reference](#11-secureactionbuttontemplate--full-reference)
12. [The RestrictedEnvironment — Available API Inside Secure Handlers](#12-the-restrictedenvironment--available-api-inside-secure-handlers)
13. [InCombatLockdown — Behavior and Usage](#13-incombatlockdown--behavior-and-usage)
14. [Binary Unlocking via Disassembly (romanh.de Technique)](#14-binary-unlocking-via-disassembly-romanhde-technique)
15. [Python Patcher — trevor403 Gist](#15-python-patcher--trevor403-gist)
16. [Memory Offsets for WoW 3.3.5a Build 12340](#16-memory-offsets-for-wow-335a-build-12340)
17. [Private Server Context — What Changes](#17-private-server-context--what-changes)

---

## 1. The Taint System — Overview

The WoW UI security model was introduced in **Patch 2.0** (The Burning Crusade pre-patch) and carried forward through WotLK 3.3.5a. Its stated purpose is to **mandate human decision-making, particularly in combat**, by preventing addon code from autonomously performing gameplay actions.

Before 2.0, addons could fully automate gameplay — casting spells, changing targets, managing inventory — all without player input. Blizzard explicitly addressed this:

> "Addons and macros will no longer be capable of casting spells or targeting units" automatically, though addons can still cast with user interaction.

The security model works by tracking whether the current Lua execution context originated from **trusted (Blizzard)** code or **untrusted (addon/script)** code. This tracking is called **taint**.

The honey pot analogy used in Blizzard's own documentation:
> "Addon code is always tainted/sticky, and anything you touch also becomes sticky. When Blizzard code touches tainted content, it becomes sticky too, causing errors when protected functions are called."

---

## 2. How Taint Propagates

Taint is tracked per Lua value and per execution path. The rules are:

### Taint Sources
- All code loaded from **third-party addons** (non-Blizzard) is tainted on load.
- All **SavedVariables** from addons are tainted.
- Code executed via **`/run`** or **`/script`** chat commands is tainted.
- Code executed via **`/script`** in macros is tainted.

### Propagation Rules
1. **New values inherit taint**: Any new data created by already-tainted execution is itself tainted.
2. **Reading tainted data taints execution**: If a tainted variable is read during execution, the entire execution path becomes tainted.
3. **All Lua value types can be tainted**: local variables, global variables, table keys, table values, function closures — all of them.
4. **Global assignment carries taint**: Writing to a global variable marks it with the taint of the writing execution path.
5. **Accessing a tainted value taints the result**: Even if the accessing code was secure, reading a tainted value makes the current execution tainted.

### What Starts Secure
- Blizzard FrameXML files (signed and loaded from MPQ).
- Blizzard-authored addons with signed TOCs.
- Event handler code fired by the game engine itself (not addon-initiated).
- Hardware event callbacks that the engine fires directly.

### Taint is Not Permanent for Execution Paths
Each Lua call has its own taint state at entry. `securecall()` (see Section 8) can isolate taint between callers and callees. But tainted *data* (variables, tables) retains its taint indefinitely unless overwritten by secure code.

---

## 3. Secure vs. Insecure Execution Environments

| Context | Secure? | Notes |
|---|---|---|
| Blizzard FrameXML event handlers | Yes | Signed code, loaded from MPQ |
| Addon event handlers | No | All addon code is tainted |
| `/run` or `/script` chat | No | User-executed scripts are insecure |
| Macro `/cast SpellName` | Yes (hardware) | Direct macro commands use hardware event path |
| `OnClick` on a SecureActionButtonTemplate | Yes | Secure frame handler, engine executes it |
| Code inside `SecureHandler*` attribute snippets | Yes (restricted) | Runs in RestrictedEnvironment |
| `hooksecurefunc` post-hook | Tainted | Hook runs with the taint of the hooking addon |
| `HookScript` post-hook | Tainted | Same — the hook itself is tainted |

**Key principle**: Even if Blizzard's `OnEvent` handler calls a function, if that function was overwritten by an addon (i.e., the global was tainted), the call becomes tainted.

---

## 4. Hardware Events (HW Restriction)

A **hardware event** is a direct, low-level input from the player — a mouse click, a key press, a mouse button down/up. The game engine marks these with a timestamp in memory.

Relevant memory offset for build 12340:
```
LAST_HARDWARE_ACTION_TIMESTAMP = 0x00B499A4
```

When a hardware event occurs, the engine sets this timestamp. API functions marked **HW** check whether the current execution was initiated close enough in time to a real hardware event. If the check fails, the call is blocked with `ADDON_ACTION_BLOCKED`.

### What Qualifies as a Hardware Event
- Clicking a button registered with `RegisterForClicks`.
- Pressing a key bound to an action (not `/run` triggered programmatically).
- Mouse button press/release on a frame.
- Using `/cast` or other commands **typed directly** in the chat box.

### What Does NOT Qualify
- Calls made from `OnUpdate` handlers (timer-driven, not hardware).
- Calls made from `OnEvent` handlers (event-driven, not hardware).
- Any call chain that originated from addon code without direct user input.
- Calls from `C_Timer.After` or coroutine-delayed code.

### Why This Matters
`AcceptBattlefieldPort()` is a canonical example. Without a hardware event in the call chain, it fails. An addon cannot auto-queue battlegrounds by calling it from `OnEvent`. The disassembly technique (Section 14) targets the binary check for exactly this condition.

---

## 5. Protected Function Restriction Categories

WoW's API documentation annotates functions with restriction flags. The categories relevant to 3.3.5a:

### PROTECTED
- **Cannot be called from addon code at all**, regardless of combat state or hardware events.
- Even calling them from a macro `/run` triggers `ADDON_ACTION_FORBIDDEN`.
- Only accessible from Blizzard's own FrameXML (signed) code.
- Examples: `TurnOrActionStart()`, `TurnOrActionStop()`, `JumpOrAscendStart()`, most movement APIs.

### HW (Hardware Event Required)
- Can be called from macros or direct `/cast` type commands (which qualify as hardware events).
- **Cannot** be called from addon event handlers, OnUpdate, or any timer-delayed code.
- Fires `ADDON_ACTION_BLOCKED` when called without a hardware event.
- Examples: `AcceptBattlefieldPort()`, `CastSpellByName()`, `TargetUnit()`, `UseContainerItem()`.

### NOCOMBAT
- Can only be called from **secure code while out of combat**.
- During combat (`InCombatLockdown()` returns true), calling these fires `ADDON_ACTION_BLOCKED`.
- Examples: `PickupAction(slot)`, `CreateMacro()`, frame layout/anchor changes from insecure code.

### SECUREFRAME
- Widget methods that cannot be called on **protected/secure frames** while in combat.
- Attempting to call `ProtectedFrame:Hide()` from addon code fires `ADDON_ACTION_BLOCKED`.
- The frame itself is locked against modification once combat begins.

### RESTRICTEDFRAME
- Widget APIs that can only be called from within the **RestrictedEnvironment** (inside SecureHandler snippets).
- Normal addon code cannot call these at all.

### NOSCRIPT
- Functions blocked specifically when called from `/run`, `/script`, or WeakAuras-style dynamic execution.
- Distinct from general taint — these are script-execution-context restricted.

---

## 6. Key Restricted API Functions in WotLK 3.3.5a

The following functions are restricted. This is not exhaustive but covers the most practically relevant ones for addon and private server development.

### Movement & Action (PROTECTED — Never callable from addons)
```
TurnOrActionStart()
TurnOrActionStop()
JumpOrAscendStart()
JumpOrAscendStop()
AscendStop()
DescendStop()
StrafeLeftStart()
StrafeLeftStop()
StrafeRightStart()
StrafeRightStop()
MoveForwardStart()
MoveForwardStop()
MoveBackwardStart()
MoveBackwardStop()
```

### Combat & Targeting (HW — Requires hardware event)
```
CastSpellByName(spellName [, onSelf])
CastSpellByID(spellID)
TargetUnit(unit)
AssistUnit(unit)
AttackTarget()
UseContainerItem(bag, slot [, onSelf])
UseInventoryItem(invSlot)
UseAction(slot [, unit [, button]])
CastPetAction(index [, unit])
SpellStopTargeting()
SpellStopCasting()
```

### Battleground / Group (HW — Requires hardware event)
```
AcceptBattlefieldPort(index [, acceptFlag])
JoinBattlefield(index)
LeaveBattlefield()
AcceptGroup()
DeclineGroup()
AcceptProposal()      -- LFG dungeon finder proposal
```

### Spells & Items (HW)
```
PickupSpell(spellID)
PickupItem(itemName)
PlaceAction(slot)
PickupAction(slot)    -- also NOCOMBAT
EquipItemByName(name)
DeleteCursorItem()
```

### Social & Chat (HW or PROTECTED)
```
SendChatMessage(msg, type [, language [, channel]])  -- HW in some contexts
SetCurrentTitle(titleIndex)                          -- HW
```

### Macro / Keybinding (NOCOMBAT)
```
CreateMacro(name, icon, body, perCharacter)
EditMacro(index, name, icon, body, perCharacter)
DeleteMacro(index)
SetBinding(key [, command])
SetBindingSpell(key, spellName)
SetBindingItem(key, itemName)
SetBindingMacro(key, macroName)
SaveBindings(bindingSet)
```

### Frame Layout (NOCOMBAT / SECUREFRAME)
```
-- These fail on protected frames in combat:
frame:Show()
frame:Hide()
frame:SetPoint(...)
frame:ClearAllPoints()
frame:SetSize(w, h)
frame:SetWidth(w)
frame:SetHeight(h)
frame:SetParent(parent)
```

---

## 7. Error Events: ADDON_ACTION_FORBIDDEN vs ADDON_ACTION_BLOCKED

These two events are fired on the default event frame when restricted functions are violated.

### ADDON_ACTION_FORBIDDEN
- **When it fires**: An addon called an API that is **always forbidden** to non-Blizzard code (PROTECTED restriction).
- **Payload**: `addonName, functionName`
- **Meaning**: The function cannot be called by addons under any circumstances without patching the binary.
- **Example trigger**: Addon tries to call `JumpOrAscendStart()` from Lua.

### ADDON_ACTION_BLOCKED
- **When it fires**: An addon called an API that is **conditionally blocked** — missing hardware event (HW), or in combat (NOCOMBAT), or on a protected frame (SECUREFRAME).
- **Payload**: `addonName, functionName`
- **Meaning**: The call could theoretically work (e.g., via a secure template or macro), but the current execution context doesn't meet the requirements.
- **Example trigger**: `AcceptBattlefieldPort()` called from `OnEvent` without a hardware event in the call chain.

### How to Register for These Events
```lua
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_ACTION_FORBIDDEN")
f:RegisterEvent("ADDON_ACTION_BLOCKED")
f:SetScript("OnEvent", function(self, event, addonName, funcName)
    print(event .. ": addon=" .. tostring(addonName) .. " func=" .. tostring(funcName))
end)
```

This is the standard taint-debugging registration pattern.

---

## 8. Taint Debugging API

WoW provides several functions to inspect and manage taint state:

### issecure()
```lua
local isSecure = issecure()
-- Returns true if the current execution path is secure (not tainted).
-- Returns false if tainted.
```

### issecurevariable([table,] varName)
```lua
local isSecure, taintSource = issecurevariable("FunctionName")
-- isSecure: true (1) if the variable is secure, nil if tainted
-- taintSource: name of the addon that tainted it, or nil
```

Behavior:
- Undefined variables return `true, nil` (secure by default).
- Any addon-overridden global returns `nil` even if the function itself is unprotected.
- Only works on globals; local variables cannot be checked.

```lua
-- Practical taint check pattern:
local function checkTaint(varName)
    local ok, source = issecurevariable(varName)
    if not ok then
        print(varName .. " is tainted by: " .. tostring(source))
    end
end
checkTaint("CastSpellByName")
checkTaint("TargetUnit")
```

### securecall(func, ...)
```lua
securecall(functionOrName, ...)
-- Calls function in a taint-isolated way.
-- If the current environment is secure and the called function is tainted,
-- the security state is restored after the call returns.
-- Has no meaningful effect when called from already-tainted code.
```

Key behavior: If code path is secure before calling `securecall`, it will remain secure after the call even if the called function itself is tainted. Useful when Blizzard code needs to call addon callbacks without polluting its own security state.

### forceinsecure()
```lua
forceinsecure()
-- Explicitly marks the current execution path as insecure/tainted.
-- Used inside Blizzard's own code (e.g., SecureHandlers.lua) to prevent
-- addon callbacks from running in secure context accidentally.
-- Calling this from already-insecure code has no effect.
```

### hooksecurefunc(funcName, hookFunc)
```lua
hooksecurefunc("SomeProtectedFunction", function(...)
    -- This runs AFTER the original function completes.
    -- The hook runs with the taint of the addon that registered it.
    -- The original function still runs securely first.
end)
```

Important: `hooksecurefunc` does NOT prevent the original from running securely. It runs your hook code after the original. The hook code itself is tainted (since it came from your addon), but it cannot affect the security of the original call.

### frame:HookScript(event, handler)
```lua
frame:HookScript("OnClick", function(self, ...)
    -- Post-hook for frame scripts, similar to hooksecurefunc.
    -- Hook runs with addon taint, but original runs first securely.
end)
```

---

## 9. Secure Addon Patterns — Working Within the System

### The Core Constraint
Addon code cannot directly call protected or HW-restricted functions. The solution is to **pre-configure secure frames with attributes** before combat, then let the game engine execute the actions when the player interacts.

### Pattern 1: Delegating Actions to Secure Buttons
Instead of calling `CastSpellByName("Fireball")` from an OnUpdate handler, create a SecureActionButtonTemplate button and simulate a click:

```lua
local btn = CreateFrame("Button", "MySecureButton", UIParent, "SecureActionButtonTemplate")
btn:SetAttribute("type", "spell")
btn:SetAttribute("spell", "Fireball")
btn:RegisterForClicks("AnyUp")
-- The user clicking this button will cast Fireball securely.
-- Addon code can change the spell attribute only out of combat:
if not InCombatLockdown() then
    btn:SetAttribute("spell", "Frostbolt")
end
```

### Pattern 2: Pre-Combat Configuration
All secure frame attribute changes must happen **before combat**. Check `InCombatLockdown()` before any configuration:

```lua
local function ConfigureButton(spellName)
    if InCombatLockdown() then
        -- Queue the change, apply it after combat ends
        pendingSpell = spellName
        return
    end
    myBtn:SetAttribute("spell", spellName)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_REGEN_ENABLED")  -- combat ended
f:SetScript("OnEvent", function()
    if pendingSpell then
        myBtn:SetAttribute("spell", pendingSpell)
        pendingSpell = nil
    end
end)
```

### Pattern 3: Targeting via SecureUnitButtonTemplate
```lua
local btn = CreateFrame("Button", "MyTargetButton", UIParent, "SecureUnitButtonTemplate")
btn:SetAttribute("unit", "focus")
btn:SetAttribute("*type1", "target")   -- left click targets unit
btn:SetAttribute("*type2", "focus")    -- right click sets focus
btn:RegisterForClicks("AnyUp")
RegisterUnitWatch(btn)  -- keeps the button updated
```

### Pattern 4: Macro Execution via SecureActionButtonTemplate
```lua
local btn = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
btn:SetAttribute("type", "macro")
btn:SetAttribute("macrotext", "/cast Fireball\n/stopcasting")
-- Max 255 characters for macrotext
```

### Pattern 5: Conditional Actions with Modifier Keys
```lua
local btn = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
-- Normal click = cast spell
btn:SetAttribute("type", "spell")
btn:SetAttribute("spell", "Frostbolt")
-- Shift+click = use item
btn:SetAttribute("shift-type", "item")
btn:SetAttribute("shift-item", "Mana Gem")
-- Alt+click = target
btn:SetAttribute("alt-type", "target")
btn:SetAttribute("alt-unit", "focus")
btn:RegisterForClicks("AnyUp")
```

---

## 10. SecureHandler Frame Templates

Introduced in Patch 3.0, SecureHandler templates allow addon code to run limited logic **inside** a secure context, using a restricted subset of the API. They replace the older SecureStateHeader behavior from 2.0.

Key files (available in the 3.3.5a interface file dump):
- `RestrictedEnvironment.lua` — defines the allowed API sandbox
- `RestrictedFrames.lua` — defines frame handle wrappers
- `RestrictedExecution.lua` — execution framework
- `SecureHandlers.lua` — template implementations
- `SecureHandlerTemplates.xml` — XML template definitions

### Base Template: SecureHandlerBaseTemplate
Provides four methods that all other templates inherit:

```lua
-- Execute a code snippet in the restricted environment
frame:Execute(body)

-- Wrap a widget script with restricted code running before/after
frame:WrapScript(targetFrame, scriptName, preBody [, postBody])

-- Remove the outermost wrapped handler
frame:UnwrapScript(targetFrame, scriptName)

-- Create a named reference to another frame, accessible inside snippets
frame:SetFrameRef(id, refFrame)
-- Inside snippets, retrieve with: local f = self:GetFrameRef("id")
```

### All Available Templates

| Template Name | Frame Type | Trigger Attribute | Event |
|---|---|---|---|
| `SecureHandlerBaseTemplate` | Frame | (base) | — |
| `SecureHandlerStateTemplate` | Frame | `_onstate-<statename>` | State transitions |
| `SecureHandlerAttributeTemplate` | Frame | `_onattributechanged` | Any attribute set |
| `SecureHandlerClickTemplate` | Button | `_onclick` | Mouse click |
| `SecureHandlerDoubleClickTemplate` | Button | `_ondoubleclick` | Double-click |
| `SecureHandlerDragTemplate` | Frame | `_ondragstart`, `_onreceivedrag` | Drag events |
| `SecureHandlerMouseUpDownTemplate` | Frame | `_onmouseup`, `_onmousedown` | Mouse buttons |
| `SecureHandlerMouseWheelTemplate` | Frame | `_onmousewheel` | Scroll wheel |
| `SecureHandlerEnterLeaveTemplate` | Frame | `_onenter`, `_onleave` | Mouseover |
| `SecureHandlerShowHideTemplate` | Frame | `_onshow`, `_onhide` | Visibility |

### Code Example: SecureHandlerClickTemplate
```lua
local frame = CreateFrame("Button", nil, UIParent, "SecureHandlerClickTemplate")
frame:SetSize(100, 30)
frame:SetPoint("CENTER")
frame:RegisterForClicks("AnyUp")

-- Attribute snippet runs in RestrictedEnvironment
frame:SetAttribute("_onclick", [=[
    -- 'self' is the frame handle, 'button' is "LeftButton"/"RightButton"/etc.
    if button == "RightButton" then
        self:Hide()
    end
    -- Can call restricted-environment functions here
]=])
```

### Code Example: SecureHandlerStateTemplate
```lua
-- Create a state driver that responds to combat state
local stateFrame = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
RegisterStateDriver(stateFrame, "combat", "[combat] incombat; default")

stateFrame:SetAttribute("_onstate-combat", [=[
    -- 'newstate' is "incombat" or "default"
    if newstate == "incombat" then
        -- perform secure action, e.g., change another frame's attributes
        local btn = self:GetFrameRef("actionButton")
        if btn then
            btn:SetAttribute("spell", "Frost Nova")
        end
    end
]=])

-- Register the action button as a reference
stateFrame:SetFrameRef("actionButton", mySecureButton)
```

### Code Example: Using Execute
```lua
-- Run restricted-environment code directly (useful for initialization)
frame:Execute([=[
    -- This runs in the restricted environment
    local target = self:GetFrameRef("target")
    target:SetAttribute("unit", "player")
]=])
```

---

## 11. SecureActionButtonTemplate — Full Reference

The most important secure template for gameplay addons. Introduced in Patch 2.0.

### Creating a Button
```lua
-- Lua
local btn = CreateFrame("Button", "MyBtn", UIParent, "SecureActionButtonTemplate")
btn:SetAttribute("type", "spell")
btn:SetAttribute("spell", "Fireball")
btn:RegisterForClicks("AnyUp", "AnyDown")

-- XML
<Button name="MyBtn" inherits="SecureActionButtonTemplate" parent="UIParent"
        registerForClicks="AnyUp, AnyDown">
  <Attributes>
    <Attribute name="type" value="spell" />
    <Attribute name="spell" value="Fireball" />
  </Attributes>
</Button>
```

### Action Types (the `type` attribute)

| type value | Required attributes | Action performed |
|---|---|---|
| `action` | `action` (number), optional `unit` | Executes action bar slot |
| `spell` | `spell` (name or ID), optional `unit` | Casts spell |
| `item` | `item` (name) OR `bag`+`slot`, optional `unit` | Uses/equips item |
| `macro` | `macro` (index) OR `macrotext` (string, 255 chars max) | Runs macro |
| `pet` | `action` (index), optional `unit` | Calls CastPetAction |
| `target` | `unit` | Changes target; `unit="none"` clears target |
| `focus` | `unit` | Sets focus target |
| `assist` | `unit` | Assists unit |
| `cancelaura` | `spell`, optional `unit`, `rank`, `index` | Cancels a buff |
| `stop` | — | Stops spell targeting |
| `click` | `clickbutton` (frame ref) | Clicks another button |

### Modifier Key Attribute Naming

Attribute names follow the pattern: `[modifier-]name[button]`
- Modifiers must appear in this order: `alt`, `ctrl`, `shift`
- Button number: `1`=left, `2`=right, `3`=middle, `4`/`5`=extra; `*`=all
- Examples:
  - `type1` — unmodified left click
  - `shift-type2` — Shift+right click
  - `alt-ctrl-type*` — Alt+Ctrl any button
  - `type*` — any unmodified click

### helpbutton / harmbutton Remapping
```lua
-- Remap clicks based on target hostility
btn:SetAttribute("helpbutton", "LeftButton")   -- friendly: map clicks to this button
btn:SetAttribute("harmbutton", "LeftButton")   -- hostile: map clicks to this button
```

### Useful Extra Attributes

| Attribute | Values | Purpose |
|---|---|---|
| `unit` | unit token | Target for the action (default: target) |
| `checkselfcast` | `true` | If SELFCAST modifier held, target player |
| `checkfocuscast` | `true` | If FOCUSCAST modifier held, target focus |
| `useOnKeyDown` | `true`/`false` | Override ActionButtonUseKeyDown CVar |
| `toggleForVehicle` | `true`/`false` | Swap pet/owner when in vehicle |

---

## 12. The RestrictedEnvironment — Available API Inside Secure Handlers

Code running inside SecureHandler attribute snippets has access only to a curated subset of the WoW API. This is the restricted environment.

### Available Global Functions
```lua
-- Comparison / type
select, tonumber, tostring, format, type

-- String operations
strsplit, strsub, strtrim, strmatch, strjoin, strfind, strrep, strupper, strlower
string.format, string.len, string.sub, string.rep, string.reverse, string.byte, string.char

-- Math (full stdlib)
math.abs, math.ceil, math.floor, math.max, math.min, math.mod, math.sqrt, math.sin, math.cos

-- Restricted table operations (not standard table.*)
rtable.pairs, rtable.insert, rtable.remove, rtable.sort, rtable.concat
-- Note: comparison functions cannot be passed to rtable.sort
```

### Available WoW API Functions (partial list)
```lua
-- Unit state queries
UnitExists("unit")
UnitIsDead("unit")
UnitIsGhost("unit")
UnitPlayerOrPetInParty("unit")
UnitPlayerOrPetInRaid("unit")

-- Player state
GetShapeshiftForm()
IsStealthed()
PlayerInCombat()      -- equivalent to InCombatLockdown() but for restricted env
PlayerInGroup()
PlayerInRaid()
PlayerIsChanneling()
IsMounted()
IsFlying()

-- Input state
IsAltKeyDown()
IsControlKeyDown()
IsShiftKeyDown()
IsLeftAltKeyDown()
IsRightAltKeyDown()
IsLeftControlKeyDown()
IsRightControlKeyDown()
IsLeftShiftKeyDown()
IsRightShiftKeyDown()
GetMouseButtonClicked()

-- Action bar
GetActionBarPage()
GetBonusBarOffset()
HasAction(slot)

-- Spell helpers
IsHarmfulSpell(spellName)
IsHelpfulSpell(spellName)
```

### Frame Handle Methods (inside snippets)
Frames are not raw userdata inside the restricted environment. They are handle objects accessed via `self` (the owning frame) or `self:GetFrameRef("id")`.

```lua
-- Information
frame:GetName()
frame:GetWidth()
frame:GetHeight()
frame:GetRect()     -- x, y, width, height
frame:GetScale()
frame:IsProtected()
frame:GetNumPoints()
frame:GetPoint(index)

-- Modification (most setters restricted to protected frames in combat)
frame:SetWidth(w)
frame:SetHeight(h)
frame:SetScale(s)
frame:SetAlpha(a)
frame:SetPoint(anchor, relativeTo, relativePoint, x, y)
frame:Show()
frame:Hide()

-- Attribute manipulation (core secure template mechanism)
frame:SetAttribute(name, value)
frame:GetAttribute(name)

-- Binding (secure)
frame:SetBindingClick(priority, key, frameName, button)
frame:SetBindingSpell(priority, key, spellName)
frame:SetBindingMacro(priority, key, macroName)
frame:SetBindingItem(priority, key, itemName)
frame:ClearBinding(key)
```

### control Table (execution control)
```lua
control:Run("body", ...)         -- execute snippet with self as owner frame
control:RunFor(handle, "body", ...) -- execute snippet with different frame as self
control:RunAttribute(name, ...)  -- invoke an attribute snippet from the owner
control:ChildUpdate(event, ...)  -- run snippets on protected child frames
```

---

## 13. InCombatLockdown — Behavior and Usage

```lua
local locked = InCombatLockdown()
-- Returns true when combat lockdown is active.
-- Returns false (or nil) when out of combat.
```

### When Combat Lockdown Activates
- The player enters combat (PLAYER_REGEN_DISABLED fires).
- It persists until combat ends (PLAYER_REGEN_ENABLED fires).

### What Lockdown Prevents
- Modifying attributes on **protected frames**.
- Showing/hiding/moving/resizing protected frames from addon code.
- Calling NOCOMBAT-restricted API functions.
- Creating new secure frames (best practice: create all frames at addon load time).

### What Lockdown Does NOT Prevent
- Reading attributes from protected frames.
- Calling non-restricted API functions.
- Triggering player interaction with already-configured secure buttons.
- Running code inside SecureHandler attribute snippets (those remain functional).

### Pattern: Deferred Reconfiguration
```lua
local pendingConfig = {}

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_REGEN_DISABLED")   -- entering combat
f:RegisterEvent("PLAYER_REGEN_ENABLED")    -- leaving combat
f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        -- Apply all queued changes now that lockdown lifted
        for _, fn in ipairs(pendingConfig) do fn() end
        pendingConfig = {}
    end
end)

local function SafeSetAttribute(frame, name, value)
    if InCombatLockdown() then
        table.insert(pendingConfig, function()
            frame:SetAttribute(name, value)
        end)
    else
        frame:SetAttribute(name, value)
    end
end
```

### Protected Frames vs. Normal Frames in Combat

| Frame Type | Out of Combat | In Combat |
|---|---|---|
| Normal (addon) frame | Full control | Full control |
| Protected frame (Blizzard) | Blizzard controls it | Blizzard controls it; addon cannot modify |
| SecureActionButtonTemplate (addon) | Configure freely | Cannot reconfigure; still clickable |

---

## 14. Binary Unlocking via Disassembly (romanh.de Technique)

**Source**: https://romanh.de/article/Unlocking-API-Functions-in-WoW-335a-using-a-Disassembler

**Author's disclaimer**: "Be always honest and don't use this hacky stuff to have an advantage against other players." This technique is for private server development and research only.

### Background: How WoW Registers Lua Functions

WoW uses Lua's standard C API to register functions. Each Lua-callable function is registered via the Lua C function `luaL_register(lua_State*, const char*, lua_CFunction)`. The registration table maps a string name (the Lua function name) to a C function pointer.

For restricted functions, WoW adds additional checks in the C function body:
- A **PROTECTED** check: validates that the current Lua execution state was initiated from signed Blizzard code.
- A **HW (hardware event) check**: validates that a hardware event timestamp is recent enough.

These checks are implemented as **conditional jump instructions** in x86 assembly. If the check fails, the conditional jump skips over the function body and returns early (or triggers the blocked callback). Replacing these jumps with NOPs (or unconditional jumps) bypasses the restriction.

### Step-by-Step: Using IDA Pro (32-bit)

**Target**: `Wow.exe` build 12340 (3.3.5a), 32-bit x86.

#### Step 1: Open the Binary
- Use IDA Pro in 32-bit mode (the 3.3.5a client is 32-bit only).
- Load `Wow.exe` and wait for full analysis.

#### Step 2: Find the Function Name in the String Table
- Open the String Table: `View → Open Subviews → Strings` (or `Shift+F12`).
- Search for the target function name, e.g., `AcceptBattlefieldPort`.
- Double-click the result to jump to the string in the data segment.

#### Step 3: Follow Cross-References
- With the cursor on the string, press `X` to view cross-references (XREFs).
- This shows where the string is used in code — typically in the `luaL_register` call table, and inside the C function that implements it.
- Follow the XREF into the function's implementation code.

#### Step 4: Locate the Restriction Check via Debugging
- Use IDA's debugger to attach to a running WoW process (or analyze statically).
- Set a breakpoint at the function entry.
- Call the Lua function from an addon (it will be blocked) to hit the breakpoint.
- Step through the assembly to find the conditional jump that gates execution.

The author describes the hardware event check: "The second jump instruction interrupts the function if it is not a hardware event."

The check typically looks like (pseudocode):
```asm
; Check hardware event timestamp
mov eax, [hardwareEventTimestamp]
cmp eax, [currentTimestamp]
jz  <function_body>          ; jump if hardware event is recent — this is what you NOP
; else fall through to return/error path
```

For the PROTECTED check (Blizzard code validation):
```asm
; Check if execution context is trusted
call checkSecureContext      ; internal function
test eax, eax
jnz <function_body>          ; jump if secure — this is what you NOP
; else return early
```

#### Step 5: Patch the Conditional Jump(s)
Replace conditional jump instructions with:
- **NOP** (`0x90`) — fills the bytes with no-operations.
- **Unconditional JMP** (`0xEB xx`) — always takes the branch.

#### Step 6: Apply the Patch with DIF-Patcher
The author used **DIF-Patcher** (an open-source binary patching utility) to apply the changes to `Wow.exe` without full recompilation. The patcher takes a diff file specifying the offset and new bytes.

### Tools Required
- **IDA Pro** (32-bit disassembler/debugger) — the industry standard.
- **DIF-Patcher** — open-source binary patcher (compiled from source).
- Text editor for the diff/patch file.
- A running WoW 3.3.5a client for live debugging.

### Result
After patching, Lua functions that were PROTECTED or HW-restricted can be called from normal addon code:
- `AcceptBattlefieldPort()` can be called from event handlers without user input.
- Other HW-restricted functions become callable from OnUpdate, OnEvent, etc.
- The proof-of-concept demonstrated was an **AutoQueueBG addon** that automatically queued for battlegrounds when they became available.

---

## 15. Python Patcher — trevor403 Gist

**Source**: https://gist.github.com/trevor403/90363a9edafd19094d844b1fbfdbb76e

A Python script using the `pefile` library to patch `Wow.exe` directly. Two patches are applied:

### Patch 1: Lua Unlock (Bypass PROTECTED/HW check)
```
File section offset: 0x5191C0 + 0x12
Change: 0x74 → 0xEB
```
- `0x74` = `JE` (Jump if Equal / Jump if Zero) — the conditional jump that fails the security check.
- `0xEB` = `JMP` (unconditional short jump) — always proceeds to the function body.
- This effectively says: "always treat execution as having passed the security check."

### Patch 2: Hide Popup (Suppress the "blocked" UI error dialog)
```
File section offset: 0x513530 + 0x10
Change: 0x0F 0x85 0xF6 0x00 0x00 0x00 → 0xE9 0xF7 0x00 0x00 0x00 0x90
```
- `0x0F 0x85` = `JNZ rel32` (Jump if Not Zero, 6-byte form) — conditional near jump.
- `0xE9` = `JMP rel32` (unconditional near jump, 5 bytes) + `0x90` NOP padding.
- This suppresses the `ADDON_ACTION_BLOCKED` dialog that would otherwise pop up.

### Script Approach
```python
import pefile

UNLOCK_OFFSET = 0x5191C0 + 0x12
POPUP_OFFSET  = 0x513530 + 0x10

pe = pefile.PE("Wow.exe")
# Locate the file offset for the virtual address offset
# Verify expected bytes before patching
# Apply byte changes
# Save as Wow-unprotected.exe
```

The script verifies expected byte values before applying patches (as a sanity check that the correct build is being patched). Output is saved as `Wow-unprotected.exe`.

### Note on Offsets
These are **file offsets within PE sections**, not virtual addresses. The PE header is used to map them to the correct location in the binary. For the virtual address equivalents, add the section's virtual address base (typically `0x00400000` for WoW's image base).

---

## 16. Memory Offsets for WoW 3.3.5a Build 12340

These are verified static offsets for WoW 3.3.5a build 12340 (the standard WotLK private server build). All addresses are virtual addresses with image base `0x00400000`.

**Source**: `github.com/AzDeltaQQ/WotLKRotations/blob/main/offsets.py`

### Lua C API Function Addresses
These are the addresses of the Lua C library functions as embedded in Wow.exe:

```
LUA_GETTOP           = 0x0084DBD0
LUA_SETTOP           = 0x0084DBF0
LUA_PUSHSTRING       = 0x0084E350
LUA_PUSHINTEGER      = 0x0084E2D0
LUA_PUSHNUMBER       = 0x0084E2A0
LUA_TOLSTRING        = 0x0084E0E0
LUA_TONUMBER         = 0x0084E030
LUA_TOINTEGER        = 0x0084E070
LUA_TYPE             = 0x0084DEB0
LUA_PCALL            = 0x0084EC50
LUA_PUSHBOOLEAN      = 0x0084E4D0
LUA_PUSHCCLOSURE     = 0x0084E400
LUA_TOBOOLEAN        = 0x0044E2C0   -- note: lower address, may be different section
LUA_TOCFUNCTION      = 0x0084E1C0
LUA_GETFIELD_BY_STACK_KEY = 0x0084F3B0
LUA_RAWGET_HELPER    = 0x00854510
LUA_GLOBALSINDEX     = -10002       -- constant (LUA_GLOBALSINDEX = -10002)
```

### WoW Custom / FrameScript Functions
```
FRAMESCRIPT_EXECUTE  = 0x00819210   -- FrameScript_Execute(script, name, tainted)
WOW_SETFIELD         = 0x0084E900
WOW_GETGLOBALSTRINGVARIABLE = 0x00818010
```

### Lua State
```
LUA_STATE            = 0x00D3F78C   -- static pointer to the main Lua state
```

### Hardware Event Timestamp
```
LAST_HARDWARE_ACTION_TIMESTAMP = 0x00B499A4
-- Write a recent timestamp here to spoof hardware event checks at runtime
-- (alternative to binary patching — requires external memory writer)
```

### Object Manager & Player
```
STATIC_CLIENT_CONNECTION = 0x00C79CE0
OBJECT_MANAGER_OFFSET    = 0x2ED0   -- offset from client connection
FIRST_OBJECT_OFFSET      = 0xAC     -- offset from object manager
LOCAL_GUID_OFFSET        = 0xC0
LOCAL_PLAYER_GUID_STATIC = 0x00BD07A8
LOCAL_TARGET_GUID_STATIC = 0x00BD07B0
LAST_TARGET_GUID         = 0x00BD07B8
MOUSE_OVER_GUID          = 0x00BD07A0
COMBO_POINTS             = 0x00BD084D
```

### Spell Functions
```
SPELL_CAST_SPELL         = 0x0080DA40
SPELL_C_GET_SPELL_COOLDOWN = 0x00807980
SPELL_C_GET_SPELL_RANGE  = 0x00802C30
SPELL_COOLDOWN_PTR       = 0x00D3F5AC
```

### Spellbook
```
SPELLBOOK_START_ADDRESS          = 0x00BE5D88
SPELLBOOK_SPELL_COUNT_ADDRESS    = 0x00BE8D9C
SPELLBOOK_SLOT_MAP_ADDRESS       = 0x00BE6D88
SPELLBOOK_KNOWN_SPELL_COUNT_ADDRESS = 0x00BE8D98
```

### Object Property Offsets (from object pointer)
```
OBJECT_TYPE              = 0x14
OBJECT_GUID              = 0x30
OBJECT_UNIT_FIELDS       = 0x08     -- descriptor pointer
OBJECT_DESCRIPTOR_OFFSET = 0x08
OBJECT_POS_X             = 0x79C
OBJECT_POS_Y             = 0x798
OBJECT_POS_Z             = 0x7A0
OBJECT_ROTATION          = 0x7A8
NEXT_OBJECT_OFFSET       = 0x3C
```

### Unit Field Descriptor Offsets (multiply field index by 4)
```
UNIT_FIELD_HEALTH       = 0x60      -- (0x18 * 4)
UNIT_FIELD_MAXHEALTH    = 0x80      -- (0x20 * 4)
UNIT_FIELD_ENERGY       = 0x64      -- (0x19 * 4)
UNIT_FIELD_MAXENERGY    = 0x84      -- (0x21 * 4)
UNIT_FIELD_LEVEL        = 0xD8      -- (0x36 * 4)
UNIT_FIELD_POWERS       = 0x4C
UNIT_FIELD_MAXPOWERS    = 0x6C
UNIT_FIELD_FLAGS        = 0xEC
UNIT_FIELD_TARGET_GUID  = 0x48
UNIT_FIELD_SUMMONEDBY   = 0x38
UNIT_FIELD_BYTES_0      = 0x5C      -- race/class/gender/power type
UNIT_FIELD_POWER_TYPE   = 0x47      -- byte offset into BYTES_0
UNIT_FIELD_MAXPOWER1    = 0x84
UNIT_FIELD_MAXPOWER2    = 0x88
UNIT_FIELD_MAXPOWER3    = 0x8C
UNIT_FIELD_MAXPOWER4    = 0x90
UNIT_FIELD_MAXPOWER5    = 0x94
UNIT_FIELD_MAXPOWER6    = 0x98
UNIT_FIELD_MAXPOWER7    = 0x9C
```

### Casting State (from unit pointer)
```
OBJECT_CASTING_SPELL_ID    = 0xA6C
OBJECT_CHANNEL_SPELL_ID    = 0xA80
UNIT_CASTING_ID_OFFSET     = 0xC08
UNIT_CHANNEL_ID_OFFSET     = 0xC20
```

### Aura Offsets (from unit pointer)
```
AURA_COUNT_1_OFFSET     = 0xDD0
AURA_COUNT_2_OFFSET     = 0xC54
AURA_TABLE_1_OFFSET     = 0xC50
AURA_TABLE_2_OFFSET     = 0xC58
AURA_STRUCT_SIZE        = 0x18
AURA_STRUCT_SPELL_ID_OFFSET = 0x08
```

### Name Store
```
NAME_STORE_BASE         = 0x00C5D940
NAME_MASK_OFFSET        = 0x24
NAME_BASE_OFFSET        = 0x1C
NAME_NODE_NEXT_OFFSET   = 0x0C
NAME_NODE_NAME_OFFSET   = 0x20
```

### Camera
```
CAMERA_BASE_PTR_OFFSET  = 0x00C7B5A8
CAMERA_OFFSET1          = 0x6B04
CAMERA_OFFSET2          = 0xE8
CAMERA_PITCH_OFFSET     = 0x34
CAMERA_YAW_OFFSET       = 0x30
```

### FrameScript_Execute Function Signature
```c
int __cdecl FrameScript_Execute(
    const char *script,      // Lua code string to execute
    const char *scriptName,  // Name for error reporting
    const char *tainted      // NULL or taint source string
);
```

To execute arbitrary Lua from C/C++ code injected into the process, call `FRAMESCRIPT_EXECUTE` with the script text and `NULL` for the taint parameter (or a source name for debugging).

---

## 17. Private Server Context — What Changes

On a private server running **AzerothCore** or **TrinityCore**, the server-side enforcement of these restrictions does not exist (there is no server-side Lua or taint checking for client behavior). However:

### Client-Side Restrictions Still Apply
The taint system and protected function checks are implemented entirely in the **WoW.exe client binary**. The server has no knowledge of whether the client called `AcceptBattlefieldPort` via a button click or an addon auto-call. This means:

1. If you want addons on your private server to bypass HW/PROTECTED restrictions, you must either:
   - Patch `Wow.exe` using the binary techniques described above, **or**
   - Use SecureHandler templates and require players to click buttons, **or**
   - Use Eluna (serverside Lua) to perform the action server-side instead.

2. Patches to `Wow.exe` only affect clients that have applied the patch. Unpatched clients still experience all restrictions normally.

3. For **server operators**, the recommended approach is to use Eluna scripts to handle actions that would otherwise require protected function calls on the client — avoid pushing players toward binary patching.

### Useful Eluna Equivalents
Some things that require protected client API can be triggered server-side:

| Client restricted action | Eluna server-side equivalent |
|---|---|
| Auto-queue battleground | `player:BattlegroundQueueJoin(bgTypeId)` |
| Force group accept | Custom gossip/NPC interaction |
| Teleport | `player:Teleport(mapId, x, y, z, o)` |
| Item give | `player:AddItem(entry, count)` |

### Custom Server Interface Files
If running a private server with a custom client, you can modify the Lua interface files (`.lua` files in the `Interface/` directory) to call protected functions from within Blizzard-signed FrameXML. Since these files are loaded as trusted code, they execute in secure context. This is the cleanest approach for server-specific UI modifications.

---

## References

- **romanh.de article**: https://romanh.de/article/Unlocking-API-Functions-in-WoW-335a-using-a-Disassembler
- **trevor403 Python patcher gist**: https://gist.github.com/trevor403/90363a9edafd19094d844b1fbfdbb76e
- **Warcraft Wiki — Secure Execution and Tainting**: https://warcraft.wiki.gg/wiki/Secure_Execution_and_Tainting
- **Warcraft Wiki — SecureHandlers**: https://warcraft.wiki.gg/wiki/SecureHandlers
- **Warcraft Wiki — SecureActionButtonTemplate**: https://warcraft.wiki.gg/wiki/SecureActionButtonTemplate
- **Warcraft Wiki — Restricted API functions category**: https://warcraft.wiki.gg/wiki/Category:API_functions/restricted
- **AddOn Studio — RestrictedEnvironment**: https://addonstudio.org/wiki/WoW:RestrictedEnvironment
- **AddOn Studio — issecurevariable**: https://addonstudio.org/wiki/WoW:API_issecurevariable
- **WoW 3.3.5a interface files (wowgaming)**: https://github.com/wowgaming/3.3.5-interface-files
- **AzDeltaQQ WotLK offsets**: https://github.com/AzDeltaQQ/WotLKRotations/blob/main/offsets.py
