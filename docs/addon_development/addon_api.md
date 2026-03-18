# WoW 3.3.5a Addon API Reference

Complete reference for addon development targeting WoW patch 3.3.5a (Wrath of the Lich King).

> **Namespace note**: Modern (post-8.0) APIs use `C_*` namespaces (e.g., `C_ChatInfo.SendAddonMessage`). In 3.3.5a all functions are global — no `C_` prefix exists. Where the wiki documents a modern equivalent alongside a WotLK-era name, the WotLK name is used here.

---

## Table of Contents

1. [TOC File Format](#1-toc-file-format)
2. [Addon Loading Process](#2-addon-loading-process)
3. [XML UI Definition](#3-xml-ui-definition)
4. [CreateFrame](#4-createframe)
5. [Frame Methods](#5-frame-methods)
6. [Anchor System](#6-anchor-system)
7. [Script Handlers](#7-script-handlers)
8. [Texture Methods](#8-texture-methods)
9. [FontString Methods](#9-fontstring-methods)
10. [Button Methods](#10-button-methods)
11. [EditBox Methods](#11-editbox-methods)
12. [ScrollFrame Methods](#12-scrollframe-methods)
13. [StatusBar Methods](#13-statusbar-methods)
14. [Slider Methods](#14-slider-methods)
15. [Event System](#15-event-system)
16. [Unit Functions](#16-unit-functions)
17. [Unit Tokens](#17-unit-tokens)
18. [Spell Functions](#18-spell-functions)
19. [Item & Bag Functions](#19-item--bag-functions)
20. [Combat Log](#20-combat-log)
21. [Chat & Communication](#21-chat--communication)
22. [API Function Categories](#22-api-function-categories)
23. [Common Patterns](#23-common-patterns)

---

## 1. TOC File Format

The `.toc` file must have the same name as its containing folder:
```
MyAddon/
  MyAddon.toc
  MyAddon.lua
  MyAddon.xml
```

### Metadata Fields

```
## Interface: 30300
## Title: My Addon
## Author: AuthorName
## Notes: What this addon does
## Version: 1.0.0
## Dependencies: AddonA, AddonB
## OptionalDeps: AddonC, AddonD
## SavedVariables: MyAddonDB
## SavedVariablesPerCharacter: MyAddonCharDB
## LoadOnDemand: 0
## DefaultState: enabled
```

| Field | Description |
|-------|-------------|
| `## Interface: 30300` | WoW build number. 3.3.5a = `30300` |
| `## Title: Name` | Display name shown in the addon list; supports `|c` color codes |
| `## Author: Name` | Author name (informational only) |
| `## Notes: Text` | Tooltip text shown on hover in addon list |
| `## Version: 1.0` | Addon version string |
| `## Dependencies: A, B` | Required addons that MUST load before this one (comma-separated) |
| `## RequiredDeps: A, B` | Alias for Dependencies |
| `## OptionalDeps: A, B` | Load before this addon IF they are present, but not required |
| `## LoadWith: A` | Load this addon when addon A loads (used with LoadOnDemand) |
| `## SavedVariables: Var1, Var2` | Global Lua variables saved per-account across sessions |
| `## SavedVariablesPerCharacter: Var1` | Global Lua variables saved per character |
| `## LoadOnDemand: 1` | Delay loading until `LoadAddOn("MyAddon")` is called explicitly |
| `## DefaultState: disabled` | Addon starts disabled; user must enable manually |
| `## X-Website: url` | Custom metadata, any `X-` prefix is allowed |

### File List

After metadata, list files to load in order (top to bottom). Use backslash for subdirectories:

```
## Interface: 30300
## Title: My Addon

libs\LibStub\LibStub.lua
libs\CallbackHandler-1.0\CallbackHandler-1.0.lua
locales\enUS.lua
MyAddon.xml
MyAddon.lua
modules\combat.lua
modules\ui.lua
```

- XML files can include additional Lua/XML via `<Script>` and `<Include>` tags without listing them in the TOC.
- Lines starting with `#` are comments.
- Blank lines are ignored.

---

## 2. Addon Loading Process

### Event Sequence on Login

```
[Files execute top-to-bottom as listed in TOC]
    → XML OnLoad scripts fire as frames are created
    → SavedVariables are restored to their global names

ADDON_LOADED fires (once per addon, with addon name as arg1)
    → FIRST safe point to read SavedVariables
    → Initialize defaults if SavedVars are nil

VARIABLES_LOADED fires
    → CVar and keybinding data available
    → Unreliable ordering; prefer ADDON_LOADED or PLAYER_LOGIN

PLAYER_LOGIN fires
    → Most game world data is available
    → Safe for most initialization

PLAYER_ENTERING_WORLD fires (also fires on every zone transition/reload)
    → arg1: isInitialLogin (bool)
    → arg2: isReloadingUi (bool)
    → Talent data available on reload

[Player is now in world]
```

### Key Timing Rules

- **SavedVariables** are available only after `ADDON_LOADED` fires for your addon.
- `ADDON_LOADED` fires once per addon load, passing the addon name as its first argument. Check `event == "ADDON_LOADED" and arg1 == "MyAddon"` or use vararg `...`.
- `PLAYER_ENTERING_WORLD` fires on every loading screen (login, reload UI, instance transitions) — guard one-time init with a boolean flag.
- OnLoad scripts in XML fire as each frame is parsed, before any events.
- Dependencies listed in the TOC cause those addons to fully load (including their `ADDON_LOADED`) before this addon's files begin executing.

### Minimal Initialization Pattern

```lua
local MyAddon = {}
local frame = CreateFrame("Frame")

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == "MyAddon" then
        -- SafeVars now available; set defaults
        MyAddonDB = MyAddonDB or {}
        MyAddon:OnAddonLoaded()
    elseif event == "PLAYER_LOGIN" then
        MyAddon:OnPlayerLogin()
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadUI = ...
        MyAddon:OnEnteringWorld(isInitialLogin, isReloadUI)
    end
end)
```

---

## 3. XML UI Definition

### File Header

```xml
<Ui xmlns="http://www.blizzard.com/wow/ui/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.blizzard.com/wow/ui/ ..\FrameXML\UI.xsd">

    <!-- frames go here -->

</Ui>
```

### Frame Definition

```xml
<Frame name="MyAddonFrame" parent="UIParent" hidden="false">
    <Size>
        <AbsDimension x="200" y="100"/>
    </Size>
    <Anchors>
        <Anchor point="CENTER" relativeTo="UIParent" relativePoint="CENTER">
            <Offset>
                <AbsDimension x="0" y="0"/>
            </Offset>
        </Anchor>
    </Anchors>
    <Layers>
        <Layer level="ARTWORK">
            <Texture name="$parentBG">
                <Size><AbsDimension x="200" y="100"/></Size>
                <Anchors>
                    <Anchor point="TOPLEFT"/>
                </Anchors>
                <Color r="0" g="0" b="0" a="0.8"/>
            </Texture>
            <FontString name="$parentText" inherits="GameFontNormal" text="Hello">
                <Anchors>
                    <Anchor point="CENTER"/>
                </Anchors>
            </FontString>
        </Layer>
    </Layers>
    <Scripts>
        <OnLoad>
            -- inline Lua; 'self' is the frame
            self:RegisterEvent("PLAYER_LOGIN")
        </OnLoad>
        <OnEvent>
            -- self, event, arg1, arg2 ...
        </OnEvent>
        <OnShow function="MyAddonFrame_OnShow"/>
    </Scripts>
</Frame>
```

### Virtual Templates (Reusable)

```xml
<Frame name="MyButtonTemplate" virtual="true">
    <Size><AbsDimension x="120" y="22"/></Size>
    <Layers>
        <Layer level="OVERLAY">
            <FontString name="$parentText" inherits="GameFontNormal">
                <Anchors><Anchor point="CENTER"/></Anchors>
            </FontString>
        </Layer>
    </Layers>
</Frame>

<!-- Usage: -->
<Button name="MyButton1" inherits="MyButtonTemplate UIPanelButtonTemplate">
    <Anchors>
        <Anchor point="TOPLEFT" relativeTo="MyAddonFrame" relativePoint="TOPLEFT">
            <Offset><AbsDimension x="10" y="-10"/></Offset>
        </Anchor>
    </Anchors>
</Button>
```

### Key XML Attributes

| Attribute | Values | Description |
|-----------|--------|-------------|
| `name` | string | Creates a global Lua variable with this name |
| `$parent` | prefix in name | Expands to parent frame's name |
| `parent` | frame name | Explicit parent (default is enclosing frame) |
| `hidden` | true/false | Initial visibility state |
| `virtual` | true/false | Template only; not instantiated |
| `inherits` | template names | Comma-separated list of templates to inherit |
| `frameStrata` | see strata list | Rendering layer |
| `frameLevel` | number | Sub-level within strata |
| `toplevel` | true/false | Always on top within strata |
| `movable` | true/false | Can be dragged |
| `resizable` | true/false | Can be resized |
| `enableMouse` | true/false | Receives mouse events |
| `enableKeyboard` | true/false | Receives keyboard events |
| `clampedToScreen` | true/false | Cannot be dragged off screen |
| `id` | number | Frame ID, accessible via GetID()/SetID() |

### Layer Levels

```
BACKGROUND   -- Drawn first (bottom)
BORDER
ARTWORK      -- Default for most content
OVERLAY
HIGHLIGHT    -- Drawn last (top); used for hover effects
```

### Size Specifications

```xml
<!-- Absolute pixel size -->
<Size><AbsDimension x="200" y="100"/></Size>

<!-- Relative to parent (0.0 to 1.0) -->
<Size><RelDimension x="1.0" y="0.5"/></Size>
```

### Include External Files

```xml
<Ui xmlns="http://www.blizzard.com/wow/ui/">
    <Script file="MyAddon.lua"/>
    <Include file="frames\MyFrames.xml"/>
</Ui>
```

---

## 4. CreateFrame

```lua
frame = CreateFrame(frameType [, name [, parent [, template [, id]]]])
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `frameType` | string | Widget type (see list below) |
| `name` | string or nil | Global name for the frame; nil for anonymous |
| `parent` | frame or nil | Parent frame object (not a string) |
| `template` | string or nil | Comma-separated virtual XML template names |
| `id` | number or nil | Numeric ID assigned to the frame |

### All Frame Types (3.3.5a)

| Type | Description |
|------|-------------|
| `"Frame"` | Base container frame |
| `"Button"` | Clickable button |
| `"CheckButton"` | Toggle button (checkbox) |
| `"EditBox"` | Text input field |
| `"ScrollFrame"` | Scrollable content container |
| `"StatusBar"` | Progress/health/mana bar |
| `"Slider"` | Draggable value slider |
| `"SimpleHTML"` | HTML-formatted text display |
| `"MessageFrame"` | Scrolling message display (like chat) |
| `"Cooldown"` | Circular cooldown sweep overlay |
| `"GameTooltip"` | Tooltip window |
| `"Model"` | 3D model viewer |
| `"PlayerModel"` | Player character model |
| `"DressUpModel"` | Dressing room model |
| `"TabardModel"` | Tabard preview model |
| `"CinematicModel"` | Cinematic 3D model |
| `"ColorSelect"` | Color picker widget |
| `"MovieFrame"` | Video playback |
| `"Browser"` | Web browser frame (limited) |
| `"OffScreenFrame"` | Off-screen render target |

### Usage Examples

```lua
-- Anonymous frame for event handling
local f = CreateFrame("Frame", nil, UIParent)
f:SetSize(200, 100)
f:SetPoint("CENTER")

-- Named button inheriting a template
local btn = CreateFrame("Button", "MyAddonButton", UIParent, "UIPanelButtonTemplate")
btn:SetSize(120, 22)
btn:SetPoint("CENTER", UIParent, "CENTER", 0, -50)
btn:SetText("Click Me")

-- StatusBar for a health bar
local bar = CreateFrame("StatusBar", nil, UIParent)
bar:SetSize(200, 20)
bar:SetPoint("CENTER")
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetMinMaxValues(0, 100)
bar:SetValue(75)

-- EditBox
local eb = CreateFrame("EditBox", nil, UIParent, "InputBoxTemplate")
eb:SetSize(200, 20)
eb:SetPoint("CENTER")
eb:SetAutoFocus(false)
```

---

## 5. Frame Methods

### Sizing & Positioning

```lua
frame:SetSize(width, height)
frame:GetSize()                          -- returns width, height
frame:SetWidth(width)
frame:GetWidth()
frame:SetHeight(height)
frame:GetHeight()

frame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
frame:GetPoint([index])                  -- returns point, relativeTo, relativePoint, xOfs, yOfs
frame:ClearAllPoints()
frame:SetAllPoints([relativeTo])         -- fill parent

frame:GetLeft()                          -- screen coordinates
frame:GetRight()
frame:GetTop()
frame:GetBottom()
frame:GetCenter()                        -- returns x, y
frame:GetRect()                          -- returns left, bottom, width, height
```

### Visibility

```lua
frame:Show()
frame:Hide()
frame:SetShown(bool)
frame:IsShown()                          -- visible in hierarchy
frame:IsVisible()                        -- actually rendered
```

### Parenting & Hierarchy

```lua
frame:SetParent(parentFrame)
frame:GetParent()
frame:GetChildren()                      -- returns child frames (vararg)
frame:GetNumChildren()
frame:GetNumRegions()
frame:GetRegions()                       -- returns textures and fontstrings
```

### Strata & Levels

```lua
-- Frame strata (rendering layer order):
-- BACKGROUND < LOW < MEDIUM < HIGH < DIALOG < FULLSCREEN
-- < FULLSCREEN_DIALOG < TOOLTIP
frame:SetFrameStrata(strata)             -- string from list above
frame:GetFrameStrata()
frame:SetFrameLevel(level)              -- number; higher = drawn on top within strata
frame:GetFrameLevel()
frame:SetToplevel(bool)                 -- always on top within strata
frame:Raise()                           -- move to top within strata
frame:Lower()                           -- move to bottom within strata
```

### Alpha & Scale

```lua
frame:SetAlpha(alpha)                   -- 0.0 to 1.0
frame:GetAlpha()
frame:GetEffectiveAlpha()               -- alpha including parent alpha
frame:SetScale(scale)
frame:GetScale()
frame:GetEffectiveScale()
frame:SetIgnoreParentAlpha(bool)
frame:SetIgnoreParentScale(bool)
```

### Input & Mouse

```lua
frame:EnableMouse(bool)
frame:EnableMouseWheel(bool)
frame:EnableKeyboard(bool)
frame:IsMouseOver([top, bottom, left, right])
frame:RegisterForDrag("LeftButton", "RightButton")
frame:SetMovable(bool)
frame:StartMoving()
frame:StopMovingOrSizing()
frame:SetResizable(bool)
frame:SetClampedToScreen(bool)
frame:SetClampRectInsets(left, right, top, bottom)
```

### Hit Testing

```lua
frame:SetHitRectInsets(left, right, top, bottom)
frame:GetHitRectInsets()
```

### IDs

```lua
frame:SetID(id)
frame:GetID()
```

### Child Creation

```lua
local tex = frame:CreateTexture([name [, layer [, inherits [, sublevel]]]])
local fs  = frame:CreateFontString([name [, layer [, inherits]]])
local line = frame:CreateLine([name [, layer [, inherits [, sublevel]]]])
```

### Backdrop (WotLK era global function pattern)

```lua
frame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile     = true,
    tileSize = 32,
    edgeSize = 32,
    insets   = { left=11, right=12, top=12, bottom=11 },
})
frame:SetBackdropColor(r, g, b [, a])
frame:SetBackdropBorderColor(r, g, b [, a])
```

### Event Registration

```lua
frame:RegisterEvent("EVENT_NAME")
frame:UnregisterEvent("EVENT_NAME")
frame:RegisterAllEvents()
frame:UnregisterAllEvents()
frame:IsEventRegistered("EVENT_NAME")    -- returns bool
```

### Scripts

```lua
frame:SetScript("OnEvent", function(self, event, ...) end)
frame:GetScript("OnEvent")              -- returns current handler or nil
frame:HookScript("OnEvent", function(self, event, ...) end)  -- addon-safe hook
```

---

## 6. Anchor System

### Anchor Point Names

```
TOPLEFT      TOP      TOPRIGHT
LEFT         CENTER   RIGHT
BOTTOMLEFT   BOTTOM   BOTTOMRIGHT
```

### SetPoint Signature

```lua
frame:SetPoint(point)
frame:SetPoint(point, relativeTo)
frame:SetPoint(point, relativeTo, relativePoint)
frame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
frame:SetPoint(point, xOfs, yOfs)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `point` | string | Anchor point on this frame |
| `relativeTo` | frame or string | Frame to anchor to; string resolves to global frame name; nil defaults to parent |
| `relativePoint` | string | Anchor point on `relativeTo`; defaults to `point` if omitted |
| `xOfs` | number | Horizontal pixel offset; positive = right |
| `yOfs` | number | Vertical pixel offset; positive = up |

### Common Patterns

```lua
-- Center on parent
frame:SetPoint("CENTER")

-- Top-left corner of parent with 10px inset
frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)

-- Below another frame with 5px gap
frame:SetPoint("TOP", otherFrame, "BOTTOM", 0, -5)

-- Right side, vertically centered
frame:SetPoint("LEFT", parent, "RIGHT", 5, 0)

-- Fill parent completely
frame:SetAllPoints(parent)
-- or
frame:SetPoint("TOPLEFT", parent, "TOPLEFT")
frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT")
```

### Multiple Anchors

Frames can have multiple anchor points to stretch/fill:

```lua
-- Stretch horizontally, fixed height at top
frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -5)
frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -5, -5)
frame:SetHeight(20)
```

---

## 7. Script Handlers

Scripts are set with `frame:SetScript("HandlerName", func)` or defined inline in XML.

The first argument `self` is always the frame the script is attached to.

### Universal Frame Handlers

| Handler | Signature | When it fires |
|---------|-----------|---------------|
| `OnLoad` | `(self)` | When the frame is first created (XML only, or when template fires) |
| `OnShow` | `(self)` | When the frame becomes visible |
| `OnHide` | `(self)` | When the frame is hidden |
| `OnEvent` | `(self, event, ...)` | When a registered event fires |
| `OnUpdate` | `(self, elapsed)` | Every frame; `elapsed` is seconds since last frame |
| `OnSizeChanged` | `(self, width, height)` | When frame size changes |
| `OnEnter` | `(self, motion)` | Mouse cursor enters the frame |
| `OnLeave` | `(self, motion)` | Mouse cursor leaves the frame |
| `OnMouseDown` | `(self, button)` | Mouse button pressed over frame; `button`: "LeftButton", "RightButton", "MiddleButton" |
| `OnMouseUp` | `(self, button)` | Mouse button released |
| `OnMouseWheel` | `(self, delta)` | Mouse wheel; `delta`: 1 (up) or -1 (down) |
| `OnDragStart` | `(self, button)` | Drag begins on frame |
| `OnDragStop` | `(self)` | Drag ends |
| `OnReceiveDrag` | `(self)` | Something dragged onto frame |
| `OnKeyDown` | `(self, key)` | Key pressed (requires EnableKeyboard) |
| `OnKeyUp` | `(self, key)` | Key released |
| `OnChar` | `(self, char)` | Character typed |

### Button-Specific Handlers

| Handler | Signature | When it fires |
|---------|-----------|---------------|
| `OnClick` | `(self, button, down)` | Button clicked; `button`: "LeftButton" etc.; `down`: true on press |
| `OnDoubleClick` | `(self, button)` | Double click |

### EditBox-Specific Handlers

| Handler | Signature | When it fires |
|---------|-----------|---------------|
| `OnTextChanged` | `(self, userInput)` | Text modified; `userInput`: true if user typed |
| `OnTextSet` | `(self)` | Text set programmatically via SetText |
| `OnEditFocusGained` | `(self)` | EditBox received keyboard focus |
| `OnEditFocusLost` | `(self)` | EditBox lost keyboard focus |
| `OnEnterPressed` | `(self)` | Enter key pressed in EditBox |
| `OnEscapePressed` | `(self)` | Escape key pressed; typically clears focus |
| `OnTabPressed` | `(self)` | Tab key pressed |
| `OnSpacePressed` | `(self)` | Space key pressed |
| `OnArrowPressed` | `(self, key)` | Arrow key pressed; key = "UP"/"DOWN"/"LEFT"/"RIGHT" |
| `OnInputLanguageChanged` | `(self, language)` | Input language changed |
| `OnCursorChanged` | `(self, x, y, w, h)` | Text cursor moved |

### ScrollFrame Handlers

| Handler | Signature | When it fires |
|---------|-----------|---------------|
| `OnHorizontalScroll` | `(self, offset)` | Horizontal scroll position changed |
| `OnVerticalScroll` | `(self, offset)` | Vertical scroll position changed |
| `OnScrollRangeChanged` | `(self, xrange, yrange)` | Scroll range changed (content resized) |

### StatusBar Handlers

| Handler | Signature | When it fires |
|---------|-----------|---------------|
| `OnValueChanged` | `(self, value)` | Bar value changed |
| `OnMinMaxChanged` | `(self, min, max)` | Min/max bounds changed |

### Slider Handlers

| Handler | Signature | When it fires |
|---------|-----------|---------------|
| `OnValueChanged` | `(self, value, userInput)` | Slider moved; `userInput`: true if dragged |

### OnUpdate Usage

```lua
-- Throttled update (run logic only every 0.1 seconds)
local timer = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    timer = timer + elapsed
    if timer >= 0.1 then
        timer = 0
        -- do work
    end
end)
```

---

## 8. Texture Methods

Textures are child regions of frames, created with `frame:CreateTexture()`.

### Creation

```lua
local tex = frame:CreateTexture([name [, layer [, inheritTemplate [, sublevel]]]])
-- layer: "BACKGROUND", "BORDER", "ARTWORK", "OVERLAY", "HIGHLIGHT"
-- sublevel: -8 to 7 within the layer
```

### Texture Source

```lua
tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")  -- file path
tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark", "CLAMP", "CLAMP", "LINEAR")
tex:SetColorTexture(r, g, b [, a])      -- solid color texture
tex:SetAtlas("atlasName")               -- named atlas region
tex:GetTexture()                        -- returns file path or nil
```

### Texture Coordinates (Cropping)

```lua
-- SetTexCoord(left, right, top, bottom) — values 0.0 to 1.0
tex:SetTexCoord(0, 1, 0, 1)            -- full texture
tex:SetTexCoord(0, 0.5, 0, 0.5)        -- top-left quarter
tex:GetTexCoord()                       -- returns left, right, top, bottom
tex:ResetTexCoord()
```

### Color & Alpha

```lua
tex:SetVertexColor(r, g, b [, a])       -- tint the texture
tex:GetVertexColor()                    -- returns r, g, b, a
tex:SetAlpha(alpha)                     -- 0.0 to 1.0
tex:GetAlpha()
```

### Blend Mode

```lua
-- Modes: "BLEND" (default), "ADD", "MOD", "ALPHAKEY", "DISABLE"
tex:SetBlendMode("ADD")
tex:GetBlendMode()
```

### Desaturation & Effects

```lua
tex:SetDesaturated(bool)
tex:IsDesaturated()
tex:SetRotation(radians)
tex:GetRotation()
```

### Gradient

```lua
-- orientation: "HORIZONTAL" or "VERTICAL"
-- minColor and maxColor are color tables {r, g, b [, a]}
tex:SetGradient("HORIZONTAL", {r=0,g=0,b=0}, {r=1,g=1,b=1})
```

### Tiling

```lua
tex:SetHorizTile(bool)
tex:SetVertTile(bool)
```

### Positioning (inherited from Region)

```lua
tex:SetPoint(point [, relativeTo [, relativePoint]] [, xOfs, yOfs])
tex:ClearAllPoints()
tex:SetAllPoints([relativeTo])
tex:SetSize(x, y)
tex:SetWidth(w)
tex:SetHeight(h)
tex:GetWidth()
tex:GetHeight()
tex:Show()
tex:Hide()
tex:IsShown()
tex:SetDrawLayer(layer [, sublevel])
tex:GetDrawLayer()
```

---

## 9. FontString Methods

FontStrings are text-rendering regions, created with `frame:CreateFontString()`.

### Creation

```lua
local fs = frame:CreateFontString([name [, layer [, inherits]]])
-- Commonly inherits a font template:
local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
```

### Built-in Font Templates (WotLK)

```
GameFontNormal          GameFontNormalSmall     GameFontNormalLarge
GameFontHighlight       GameFontHighlightSmall  GameFontHighlightLarge
GameFontDisable         GameFontDisableSmall    GameFontDisableLarge
GameFontGreen           GameFontRed             GameFontWhite
GameFontNormalHuge      GameFontNormalMed1      GameFontNormalMed2
```

### Text Content

```lua
fs:SetText(text)                        -- supports UI escape sequences
fs:GetText()                            -- returns string or nil
fs:SetFormattedText(formatStr, ...)     -- like string.format
fs:ClearText()
```

### Font Properties

```lua
-- SetFont(fontFile, fontSize, flags)
-- flags: "" (none), "OUTLINE", "THICKOUTLINE", "MONOCHROME", or combinations
fs:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
fs:GetFont()                            -- returns fontFile, fontSize, flags

fs:SetFontObject(fontObject)            -- use a Font object by reference
fs:GetFontObject()

fs:SetTextColor(r, g, b [, a])
fs:GetTextColor()                       -- returns r, g, b, a

fs:SetShadowColor(r, g, b [, a])
fs:GetShadowColor()
fs:SetShadowOffset(x, y)
fs:GetShadowOffset()
```

### Justification

```lua
-- SetJustifyH: "LEFT", "CENTER", "RIGHT"
fs:SetJustifyH("LEFT")
fs:GetJustifyH()

-- SetJustifyV: "TOP", "MIDDLE", "BOTTOM"
fs:SetJustifyV("TOP")
fs:GetJustifyV()
```

### Line Control

```lua
fs:SetWordWrap(bool)
fs:CanWordWrap()
fs:SetNonSpaceWrap(bool)
fs:CanNonSpaceWrap()
fs:SetMaxLines(n)                       -- 0 = unlimited
fs:GetMaxLines()
fs:GetNumLines()
fs:IsTruncated()                        -- true if text is cut off
fs:SetSpacing(spacing)
fs:GetSpacing()
```

### Dimensions

```lua
fs:GetStringWidth()                     -- pixel width of rendered text
fs:GetStringHeight()                    -- pixel height of rendered text
fs:GetWrappedWidth()
fs:GetUnboundedStringWidth()
```

### Positioning (inherited from Region)

```lua
fs:SetPoint(...)
fs:ClearAllPoints()
fs:SetSize(x, y)
fs:SetWidth(w)
fs:SetHeight(h)
fs:Show()
fs:Hide()
fs:SetAlpha(a)
fs:SetDrawLayer(layer)
```

### Color Escape Sequences

```lua
-- In text strings:
-- |cAARRGGBB  -- set color (AA=alpha hex, RR/GG/BB = color hex)
-- |r          -- reset to default color
-- |Htype:value|h[display text]|h  -- hyperlink
-- |T path:size|t  -- inline texture
-- |n  -- newline

fs:SetText("|cFFFF0000Red text|r and normal text")
```

---

## 10. Button Methods

### Text

```lua
btn:SetText(text)
btn:GetText()
btn:SetFormattedText(fmt, ...)
btn:GetTextWidth()
btn:GetTextHeight()
btn:GetFontString()                     -- returns the internal FontString
btn:SetFontString(fs)                   -- replace internal FontString
```

### Textures (Normal / Pushed / Highlight / Disabled)

```lua
btn:SetNormalTexture(asset)
btn:SetPushedTexture(asset)
btn:SetHighlightTexture(asset [, blendMode])
btn:SetDisabledTexture(asset)
btn:GetNormalTexture()
btn:GetPushedTexture()
btn:GetHighlightTexture()
btn:GetDisabledTexture()
btn:ClearNormalTexture()
btn:ClearPushedTexture()
btn:ClearHighlightTexture()
btn:ClearDisabledTexture()
```

### Font Objects

```lua
btn:SetNormalFontObject(font)
btn:SetHighlightFontObject(font)
btn:SetDisabledFontObject(font)
btn:GetNormalFontObject()
btn:GetHighlightFontObject()
btn:GetDisabledFontObject()
```

### State

```lua
btn:Enable()
btn:Disable()
btn:IsEnabled()                         -- returns bool
btn:SetEnabled(bool)
btn:GetButtonState()                    -- "NORMAL", "PUSHED", "DISABLED"
btn:SetButtonState(state [, lock])      -- state: "NORMAL", "PUSHED", "DISABLED"
```

### Interaction

```lua
-- Register which mouse buttons trigger OnClick
-- Valid: "LeftButton", "RightButton", "MiddleButton", "Button4", "Button5"
btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
btn:RegisterForClicks("LeftButtonDown", "LeftButtonUp")

-- Programmatically click the button
btn:Click([button [, isDown]])          -- button defaults to "LeftButton"

-- Offset text position when button is pressed
btn:SetPushedTextOffset(xOfs, yOfs)
btn:GetPushedTextOffset()
```

### Highlight

```lua
btn:LockHighlight()                     -- force highlight on
btn:UnlockHighlight()
```

---

## 11. EditBox Methods

### Text

```lua
eb:SetText(text)
eb:GetText()
eb:GetDisplayText()
eb:Insert(text)                         -- insert at cursor position
eb:GetNumber()                          -- numeric value of text, or 0
eb:SetNumber(n)
eb:GetNumLetters()
eb:HasText()                            -- returns bool
```

### Focus

```lua
eb:SetFocus()
eb:ClearFocus()
eb:HasFocus()                           -- returns bool
eb:SetAutoFocus(bool)                   -- grab focus when shown
eb:IsAutoFocus()
```

### Cursor

```lua
eb:SetCursorPosition(pos)               -- 0-based character index
eb:GetCursorPosition()
eb:SetBlinkSpeed(seconds)
eb:GetBlinkSpeed()
```

### Selection

```lua
eb:HighlightText([start [, stop]])      -- no args = select all
eb:ClearHighlightText()
eb:GetHighlightColor()
eb:SetHighlightColor(r, g, b [, a])
```

### Limits

```lua
eb:SetMaxLetters(n)                     -- 0 = unlimited
eb:GetMaxLetters()
eb:SetMaxBytes(n)
eb:GetMaxBytes()
```

### Configuration

```lua
eb:SetMultiLine(bool)
eb:IsMultiLine()
eb:SetPassword(bool)                    -- shows asterisks
eb:IsPassword()
eb:SetNumeric(bool)                     -- only allow numbers
eb:IsNumeric()
eb:SetEnabled(bool)
eb:Enable()
eb:Disable()
eb:IsEnabled()
```

### Insets & Display

```lua
eb:SetTextInsets(left, right, top, bottom)
eb:GetTextInsets()
eb:GetNumLines()
eb:GetInputLanguage()
```

### History (for chat-style inputs)

```lua
eb:SetHistoryLines(n)
eb:GetHistoryLines()
eb:AddHistoryLine(text)
eb:ClearHistory()
```

---

## 12. ScrollFrame Methods

```lua
-- Set the frame that scrolls
sf:SetScrollChild(childFrame)
sf:GetScrollChild()

-- Vertical scrolling
sf:SetVerticalScroll(offset)            -- pixels from top
sf:GetVerticalScroll()
sf:GetVerticalScrollRange()             -- max scroll value

-- Horizontal scrolling
sf:SetHorizontalScroll(offset)
sf:GetHorizontalScroll()
sf:GetHorizontalScrollRange()

-- Recalculate scroll child bounds
sf:UpdateScrollChildRect()
```

### Typical ScrollFrame Setup

```lua
local sf = CreateFrame("ScrollFrame", "MyScrollFrame", parent)
sf:SetSize(200, 300)
sf:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -5)

local content = CreateFrame("Frame", nil, sf)
content:SetSize(200, 1)          -- height grows with content
sf:SetScrollChild(content)

-- Add items to content
local y = 0
for i = 1, 20 do
    local row = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    row:SetText("Row " .. i)
    y = y + 16
end
content:SetHeight(y)

-- Scroll handler
sf:SetScript("OnVerticalScroll", function(self, offset)
    self:SetVerticalScroll(offset)
end)
sf:SetScript("OnScrollRangeChanged", function(self, xrange, yrange)
    -- update scrollbar thumb size
end)
```

---

## 13. StatusBar Methods

```lua
bar:SetValue(value)
bar:GetValue()
bar:SetMinMaxValues(min, max)
bar:GetMinMaxValues()                   -- returns min, max
bar:SetStatusBarColor(r, g, b [, a])
bar:GetStatusBarColor()                 -- returns r, g, b, a
bar:SetStatusBarTexture(asset)
bar:GetStatusBarTexture()               -- returns texture object
bar:SetOrientation(orientation)         -- "HORIZONTAL" (default) or "VERTICAL"
bar:GetOrientation()
bar:SetReverseFill(bool)                -- fill from right/top instead of left/bottom
bar:GetReverseFill()
```

---

## 14. Slider Methods

```lua
slider:SetValue(value)
slider:GetValue()
slider:SetMinMaxValues(min, max)
slider:GetMinMaxValues()                -- returns min, max
slider:SetValueStep(step)              -- snap interval
slider:GetValueStep()
slider:SetOrientation(orientation)     -- "HORIZONTAL" or "VERTICAL"
slider:GetOrientation()
slider:Enable()
slider:Disable()
slider:IsEnabled()
slider:SetThumbTexture(asset)
slider:GetThumbTexture()
slider:SetObeyStepOnDrag(bool)
```

---

## 15. Event System

### Registration

```lua
frame:RegisterEvent("EVENT_NAME")
frame:UnregisterEvent("EVENT_NAME")
frame:RegisterAllEvents()
frame:UnregisterAllEvents()
frame:IsEventRegistered("EVENT_NAME")
```

### Handler

```lua
frame:SetScript("OnEvent", function(self, event, ...)
    local arg1, arg2, arg3 = ...
    if event == "PLAYER_LOGIN" then
        -- handle
    elseif event == "UNIT_HEALTH" then
        local unitId = arg1
        local hp = UnitHealth(unitId)
    end
end)
```

### Key Events Reference (WotLK 3.3.5a)

#### Addon Lifecycle

| Event | Arguments | Description |
|-------|-----------|-------------|
| `ADDON_LOADED` | addonName | Addon files and SavedVariables loaded |
| `VARIABLES_LOADED` | — | CVars and keybindings loaded |
| `PLAYER_LOGIN` | — | Game world data available |
| `PLAYER_LOGOUT` | — | Player logging out |
| `PLAYER_ENTERING_WORLD` | — | Loading screen complete (also fires on zone change) |
| `PLAYER_LEAVING_WORLD` | — | Loading screen starting |
| `UI_ERROR_MESSAGE` | message | System error message |
| `UI_INFO_MESSAGE` | message | System info message |

#### Player State

| Event | Arguments | Description |
|-------|-----------|-------------|
| `PLAYER_TARGET_CHANGED` | — | Target changed |
| `PLAYER_FOCUS_CHANGED` | — | Focus target changed |
| `PLAYER_REGEN_DISABLED` | — | Entered combat |
| `PLAYER_REGEN_ENABLED` | — | Left combat |
| `PLAYER_DEAD` | — | Player died |
| `PLAYER_ALIVE` | — | Player resurrected |
| `PLAYER_UNGHOST` | — | Player released as ghost |
| `PLAYER_LEVEL_UP` | newLevel | Level gained |
| `PLAYER_XP_UPDATE` | unitId | XP changed |
| `PLAYER_MONEY` | — | Money amount changed |

#### Unit Events

| Event | Arguments | Description |
|-------|-----------|-------------|
| `UNIT_HEALTH` | unitId | Unit health changed |
| `UNIT_MAXHEALTH` | unitId | Unit max health changed |
| `UNIT_POWER_UPDATE` | unitId, powerType | Unit power (mana/rage/energy) changed |
| `UNIT_MAXPOWER` | unitId, powerType | Unit max power changed |
| `UNIT_DISPLAYPOWER` | unitId | Unit power type changed |
| `UNIT_NAME_UPDATE` | unitId | Unit name changed |
| `UNIT_PORTRAIT_UPDATE` | unitId | Unit portrait changed |
| `UNIT_LEVEL` | unitId | Unit level changed |
| `UNIT_FACTION` | unitId | Unit faction changed |
| `UNIT_AURA` | unitId | Unit buff/debuff added or removed |
| `UNIT_ENTERED_VEHICLE` | unitId | Unit entered vehicle |
| `UNIT_EXITED_VEHICLE` | unitId | Unit exited vehicle |
| `UNIT_PET` | unitId | Unit's pet changed |
| `UNIT_CLASSIFICATION_CHANGED` | unitId | Elite/rare status changed |

#### Spellcasting Events

| Event | Arguments | Description |
|-------|-----------|-------------|
| `UNIT_SPELLCAST_START` | unitId, spellName, rank, lineID, spellID | Cast started |
| `UNIT_SPELLCAST_STOP` | unitId, spellName, rank, lineID, spellID | Cast cancelled |
| `UNIT_SPELLCAST_SUCCEEDED` | unitId, spellName, rank, lineID, spellID | Cast completed |
| `UNIT_SPELLCAST_FAILED` | unitId, spellName, rank, lineID, spellID | Cast failed |
| `UNIT_SPELLCAST_INTERRUPTED` | unitId, spellName, rank, lineID, spellID | Cast interrupted |
| `UNIT_SPELLCAST_DELAYED` | unitId, spellName, rank, lineID, spellID | Cast delayed |
| `UNIT_SPELLCAST_CHANNEL_START` | unitId, spellName, rank, lineID, spellID | Channel started |
| `UNIT_SPELLCAST_CHANNEL_UPDATE` | unitId, spellName, rank, lineID, spellID | Channel updated |
| `UNIT_SPELLCAST_CHANNEL_STOP` | unitId, spellName, rank, lineID, spellID | Channel ended |

#### Combat

| Event | Arguments | Description |
|-------|-----------|-------------|
| `COMBAT_LOG_EVENT_UNFILTERED` | (none; use CombatLogGetCurrentEventInfo()) | All combat events |
| `PLAYER_COMBAT_XP_GAIN` | amount | XP from killing |
| `PLAYER_FLAGS_CHANGED` | unitId | PvP flag changed |

#### Cooldowns & Actions

| Event | Arguments | Description |
|-------|-----------|-------------|
| `SPELL_UPDATE_COOLDOWN` | — | Spell cooldown changed |
| `SPELL_UPDATE_USABLE` | — | Spell usable state changed |
| `ACTIONBAR_UPDATE_COOLDOWN` | — | Action bar cooldown changed |
| `ACTIONBAR_UPDATE_STATE` | — | Action state changed |
| `ACTIONBAR_UPDATE_USABLE` | — | Action usability changed |
| `ACTIONBAR_SLOT_CHANGED` | slot | Action in slot changed |

#### Bag & Inventory

| Event | Arguments | Description |
|-------|-----------|-------------|
| `BAG_UPDATE` | bagId | Bag contents changed |
| `BAG_UPDATE_COOLDOWN` | — | Bag item cooldown updated |
| `ITEM_LOCK_CHANGED` | bagId, slotId | Item lock state changed |
| `PLAYER_EQUIPMENT_CHANGED` | slotId, hasNewItem | Equipment slot changed |
| `BANKFRAME_OPENED` | — | Bank window opened |
| `BANKFRAME_CLOSED` | — | Bank window closed |
| `PLAYERBANKSLOTS_CHANGED` | slotId | Bank slot contents changed |

#### Group & Raid

| Event | Arguments | Description |
|-------|-----------|-------------|
| `PARTY_MEMBERS_CHANGED` | — | Party composition changed |
| `PARTY_LEADER_CHANGED` | — | Party leader changed |
| `PARTY_LOOT_METHOD_CHANGED` | — | Loot method changed |
| `RAID_ROSTER_UPDATE` | — | Raid composition changed |
| `GROUP_ROSTER_UPDATE` | — | Generic group update |

#### Chat

| Event | Arguments | Description |
|-------|-----------|-------------|
| `CHAT_MSG_SAY` | msg, author, lang, ... | Say message |
| `CHAT_MSG_YELL` | msg, author, lang, ... | Yell message |
| `CHAT_MSG_PARTY` | msg, author, lang, ... | Party chat |
| `CHAT_MSG_RAID` | msg, author, lang, ... | Raid chat |
| `CHAT_MSG_RAID_WARNING` | msg, author, ... | Raid warning |
| `CHAT_MSG_GUILD` | msg, author, lang, ... | Guild chat |
| `CHAT_MSG_OFFICER` | msg, author, lang, ... | Officer chat |
| `CHAT_MSG_WHISPER` | msg, author, lang, ... | Incoming whisper |
| `CHAT_MSG_WHISPER_INFORM` | msg, target, ... | Sent whisper |
| `CHAT_MSG_CHANNEL` | msg, author, lang, channel, ... | Channel message |
| `CHAT_MSG_EMOTE` | msg, author, ... | Emote |
| `CHAT_MSG_TEXT_EMOTE` | msg, author, ... | Text emote |
| `CHAT_MSG_SYSTEM` | msg | System message |
| `CHAT_MSG_ADDON` | prefix, msg, channel, sender | Addon communication |

#### Quest

| Event | Arguments | Description |
|-------|-----------|-------------|
| `QUEST_LOG_UPDATE` | — | Quest log changed |
| `QUEST_ACCEPTED` | index, questId | Quest accepted |
| `QUEST_TURNED_IN` | questId, xpReward, money | Quest completed |

#### UI

| Event | Arguments | Description |
|-------|-----------|-------------|
| `UPDATE_BINDINGS` | — | Keybindings changed |
| `MODIFIER_STATE_CHANGED` | key, state | Shift/Ctrl/Alt pressed/released |
| `UPDATE_MOUSEOVER_UNIT` | — | Mouse moved over new unit |
| `CURSOR_UPDATE` | — | Cursor item changed |
| `MERCHANT_SHOW` | — | Merchant window opened |
| `MERCHANT_CLOSED` | — | Merchant window closed |
| `LOOT_OPENED` | — | Loot window opened |
| `LOOT_CLOSED` | — | Loot window closed |

---

## 16. Unit Functions

### Health & Power

```lua
UnitHealth(unitId)                      -- current health
UnitHealthMax(unitId)                   -- max health
UnitPower(unitId [, powerType])         -- current power (mana/rage/energy/etc.)
UnitPowerMax(unitId [, powerType])      -- max power
UnitPowerType(unitId)                   -- returns powerType number, name
-- Power types: 0=mana, 1=rage, 2=focus, 3=energy, 4=happiness(pet),
--              5=runes, 6=runic power
```

### Identity

```lua
UnitName(unitId)                        -- returns name[, realm]
UnitClass(unitId)                       -- returns localizedClass, classFilename, classId
UnitRace(unitId)                        -- returns localizedRace, raceFilename, raceId
UnitSex(unitId)                         -- 1=unknown, 2=male, 3=female
UnitLevel(unitId)                       -- level number; -1 for bosses
UnitGUID(unitId)                        -- returns "Player-realm-id" or "Creature-..." string
UnitCreatureType(unitId)                -- "Beast", "Humanoid", etc.
UnitCreatureFamily(unitId)              -- "Wolf", "Cat", etc. (nil for non-beast)
UnitClassification(unitId)              -- "normal","elite","rareelite","worldboss","rare","trivial","minus"
```

### Existence & State

```lua
UnitExists(unitId)                      -- returns bool
UnitIsPlayer(unitId)                    -- returns bool
UnitIsUnit(unitId1, unitId2)            -- returns true if same entity
UnitIsDead(unitId)                      -- returns bool
UnitIsGhost(unitId)                     -- returns bool
UnitIsConnected(unitId)                 -- returns bool (for party/raid)
UnitIsVisible(unitId)                   -- returns bool
UnitOnTaxi(unitId)                      -- returns bool
UnitAffectingCombat(unitId)             -- returns bool
```

### Relationship

```lua
UnitReaction(unitId1, unitId2)          -- returns 1-8 (hostile to friendly)
UnitIsFriend(unitId1, unitId2)          -- returns bool
UnitIsEnemy(unitId1, unitId2)           -- returns bool
UnitPlayerControlled(unitId)            -- returns bool
UnitCanAttack(unitId1, unitId2)         -- returns bool
UnitIsPartyLeader(unitId)               -- returns bool
UnitInParty(unitId)                     -- returns bool
UnitInRaid(unitId)                      -- returns raid index or nil
```

### Buffs & Debuffs (WotLK era API)

```lua
-- UnitBuff(unitId, index [, filter])
-- Returns: name, rank, icon, count, debuffType, duration, expirationTime,
--          unitCaster, isStealable, shouldConsolidate, spellId
UnitBuff(unitId, index)
UnitDebuff(unitId, index [, filter])    -- same returns as UnitBuff

-- Find by spell name
UnitAura(unitId, index [, filter])      -- same returns

-- filter: "HELPFUL", "HARMFUL", "RAID", "CANCELABLE", "NOT_CANCELABLE"
```

---

## 17. Unit Tokens

Valid unit ID strings in WotLK 3.3.5a:

| Token | Description |
|-------|-------------|
| `"player"` | The logged-in player |
| `"target"` | Current target |
| `"focus"` | Focus target |
| `"mouseover"` | Unit under cursor |
| `"pet"` | Player's pet |
| `"vehicle"` | Player's vehicle |
| `"none"` | Always-empty token |
| `"party1"` – `"party4"` | Party members (not including player) |
| `"partypet1"` – `"partypet4"` | Party members' pets |
| `"raid1"` – `"raid40"` | Raid members by index |
| `"raidpet1"` – `"raidpet40"` | Raid members' pets |
| `"boss1"` – `"boss4"` | Active encounter bosses |
| `"arena1"` – `"arena5"` | Enemy arena team members |
| `"npc"` | Currently interacted NPC |

Append `"target"` to chain: `"targettarget"`, `"focustarget"`, `"mouseovertarget"`.

---

## 18. Spell Functions

```lua
-- GetSpellInfo (WotLK returns rank as 2nd value)
-- name, rank, icon, castTime, minRange, maxRange, spellId
local name, rank, icon, castTime, minRange, maxRange, spellId = GetSpellInfo(spellId)
local name, rank, icon, castTime, minRange, maxRange, spellId = GetSpellInfo("Spell Name")

GetSpellCooldown(spellId)               -- returns start, duration, enabled
GetSpellBaseCooldown(spellId)           -- base cooldown ignoring haste
GetSpellTexture(spellId)                -- returns icon path
GetSpellDescription(spellId)

-- Spellbook
GetNumSpellTabs()                       -- number of spellbook tabs
GetSpellTabInfo(tabIndex)               -- name, texture, offset, numSpells
GetSpellName(spellIndex, "BOOKTYPE_SPELL" or "BOOKTYPE_PET")   -- name, rank
GetSpellBookItemInfo(spellIndex, bookType)   -- type ("SPELL"/"FUTURESPELL"/"PETACTION"), spellId
GetSpellBookItemName(spellIndex, bookType)   -- name, rank
GetSpellBookItemTexture(spellIndex, bookType)

IsSpellInRange(spellName [, rank], unitId)  -- 1=in range, 0=out of range, nil=can't tell
IsUsableSpell(spellName [, rank])           -- returns isUsable, notEnoughMana

CastSpell(spellIndex, bookType)
CastSpellByName(spellName [, onSelf])
```

---

## 19. Item & Bag Functions

### Bags

```lua
GetContainerNumSlots(bagId)             -- number of slots in bag
GetContainerItemInfo(bagId, slotId)     -- icon, count, locked, quality, readable, lootable, link
GetContainerItemLink(bagId, slotId)     -- item link string or nil
GetContainerItemCooldown(bagId, slotId) -- start, duration, enabled
PickupContainerItem(bagId, slotId)
SplitContainerItem(bagId, slotId, count)
UseContainerItem(bagId, slotId)
-- bagId: 0=backpack, 1-4=bags, 5=keyring
-- BANK_CONTAINER = -1; BANK slot bags = 6-11 (approx)
```

### Items

```lua
GetItemInfo(itemId or itemName or itemLink)
-- returns: itemName, itemLink, itemRarity, itemLevel, itemMinLevel,
--          itemType, itemSubType, itemStackCount, itemEquipLoc,
--          itemIcon, itemSellPrice

GetItemQualityColor(quality)            -- returns r, g, b, hex
-- quality: 0=poor(grey), 1=common(white), 2=uncommon(green),
--          3=rare(blue), 4=epic(purple), 5=legendary(orange), 6=artifact

GetItemCooldown(itemId)                 -- start, duration, enabled
GetInventoryItemID(unitId, slotId)      -- itemId or nil
GetInventoryItemLink(unitId, slotId)    -- item link or nil
GetInventoryItemTexture(unitId, slotId)
GetInventoryItemCount(unitId, slotId)

-- Equipment slot IDs:
-- 1=HEAD, 2=NECK, 3=SHOULDER, 4=SHIRT, 5=CHEST, 6=WAIST,
-- 7=LEGS, 8=FEET, 9=WRIST, 10=HANDS, 11=FINGER1, 12=FINGER2,
-- 13=TRINKET1, 14=TRINKET2, 15=BACK, 16=MAINHAND, 17=OFFHAND,
-- 18=RANGED, 19=TABARD

HasKey()                                -- returns bool if keyring has keys
```

---

## 20. Combat Log

### In WotLK 3.3.5a

In 3.3.5a, the COMBAT_LOG_EVENT_UNFILTERED arguments are passed directly to the OnEvent handler (not via a separate function call — `CombatLogGetCurrentEventInfo()` was added in patch 8.0). Access them via `...`:

```lua
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, hideCaster,
              sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
              destGUID, destName, destFlags, destRaidFlags = ...
        -- remaining args depend on subevent
    end
end)
```

> **Important**: In 3.3.5a the CLEU passes all arguments as varargs directly. `CombatLogGetCurrentEventInfo()` does not exist. The `hideCaster` parameter also may not exist in 3.3.5a — check your private server's API; some omit it for WotLK compatibility.

### Base Parameters (all events)

| # | Name | Type | Description |
|---|------|------|-------------|
| 1 | timestamp | number | Unix time |
| 2 | subevent | string | Event type (see below) |
| 3 | hideCaster | bool | Source hidden |
| 4 | sourceGUID | string | Source GUID |
| 5 | sourceName | string | Source name |
| 6 | sourceFlags | number | Source unit flags |
| 7 | sourceRaidFlags | number | Source raid marker flags |
| 8 | destGUID | string | Destination GUID |
| 9 | destName | string | Destination name |
| 10 | destFlags | number | Destination unit flags |
| 11 | destRaidFlags | number | Destination raid marker flags |

### Event Subtypes

**Prefixes** (parameters 12–14 unless SWING):
- `SWING_*` — no prefix params
- `RANGE_*` — spellId, spellName, spellSchool
- `SPELL_*` — spellId, spellName, spellSchool
- `SPELL_PERIODIC_*` — spellId, spellName, spellSchool
- `ENVIRONMENTAL_*` — environmentalType

**Full event names** = prefix + suffix:

| Subevent | Extra Parameters |
|----------|-----------------|
| `*_DAMAGE` | amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing |
| `*_MISSED` | missType, isOffHand, amountMissed |
| `*_HEAL` | amount, overhealing, absorbed, critical |
| `*_ENERGIZE` | amount, overEnergize, powerType |
| `*_DRAIN` | amount, powerType, extraAmount |
| `*_LEECH` | amount, powerType, extraAmount |
| `*_INTERRUPT` | extraSpellId, extraSpellName, extraSchool |
| `*_DISPEL` | extraSpellId, extraSpellName, extraSchool, auraType |
| `*_DISPEL_FAILED` | extraSpellId, extraSpellName, extraSchool |
| `*_STOLEN` | extraSpellId, extraSpellName, extraSchool, auraType |
| `*_EXTRA_ATTACKS` | amount |
| `*_AURA_APPLIED` | auraType [, amount] |
| `*_AURA_REMOVED` | auraType [, amount] |
| `*_AURA_APPLIED_DOSE` | auraType, amount |
| `*_AURA_REMOVED_DOSE` | auraType, amount |
| `*_AURA_REFRESH` | auraType |
| `*_AURA_BROKEN` | auraType |
| `*_AURA_BROKEN_SPELL` | extraSpellId, extraSpellName, extraSchool, auraType |
| `*_CAST_START` | (none) |
| `*_CAST_SUCCESS` | (none) |
| `*_CAST_FAILED` | failedType |
| `*_INSTAKILL` | (none) |
| `*_SUMMON` | (none) |
| `*_RESURRECT` | (none) |
| `*_CREATE` | (none) |
| `UNIT_DIED` | (none) |
| `UNIT_DESTROYED` | (none) |
| `PARTY_KILL` | (none) |
| `ENCHANT_APPLIED` | spellName, itemID, itemName |
| `ENCHANT_REMOVED` | spellName, itemID, itemName |

### Miss Types
`ABSORB`, `BLOCK`, `DEFLECT`, `DODGE`, `EVADE`, `IMMUNE`, `MISS`, `PARRY`, `REFLECT`, `RESIST`

### Aura Types
`BUFF`, `DEBUFF`

### Spell Schools (bitmask)
`1`=Physical, `2`=Holy, `4`=Fire, `8`=Nature, `16`=Frost, `32`=Shadow, `64`=Arcane

### Source/Dest Flags (key bits)
```lua
-- Affiliation
COMBATLOG_OBJECT_AFFILIATION_MINE       = 0x00000001
COMBATLOG_OBJECT_AFFILIATION_PARTY      = 0x00000002
COMBATLOG_OBJECT_AFFILIATION_RAID       = 0x00000004
COMBATLOG_OBJECT_AFFILIATION_OUTSIDER   = 0x00000008
-- Reaction
COMBATLOG_OBJECT_REACTION_FRIENDLY      = 0x00000010
COMBATLOG_OBJECT_REACTION_NEUTRAL       = 0x00000020
COMBATLOG_OBJECT_REACTION_HOSTILE       = 0x00000040
-- Controller
COMBATLOG_OBJECT_CONTROL_PLAYER         = 0x00000100
COMBATLOG_OBJECT_CONTROL_NPC            = 0x00000200
-- Type
COMBATLOG_OBJECT_TYPE_PLAYER            = 0x00000400
COMBATLOG_OBJECT_TYPE_NPC               = 0x00000800
COMBATLOG_OBJECT_TYPE_PET               = 0x00001000
COMBATLOG_OBJECT_TYPE_GUARDIAN          = 0x00002000
COMBATLOG_OBJECT_TYPE_OBJECT            = 0x00004000
```

### Example: Tracking Heals

```lua
local healFrame = CreateFrame("Frame")
healFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
healFrame:SetScript("OnEvent", function(self, event, timestamp, subevent,
        hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
        destGUID, destName, destFlags, destRaidFlags, ...)
    if subevent == "SPELL_HEAL" or subevent == "SPELL_PERIODIC_HEAL" then
        local spellId, spellName, spellSchool, amount, overheal, absorbed, crit = ...
        if sourceGUID == UnitGUID("player") then
            -- player healed destName for amount
        end
    end
end)
```

---

## 21. Chat & Communication

### Sending Chat

```lua
SendChatMessage(msg, chatType [, language [, target]])
-- chatType: "SAY", "YELL", "PARTY", "RAID", "RAID_WARNING",
--           "GUILD", "OFFICER", "WHISPER", "CHANNEL", "EMOTE"
-- language: "Common", "Orcish", etc. (nil = default)
-- target: player name for WHISPER, channel number for CHANNEL
```

### Addon Messaging (WotLK 3.3.5a)

In 3.3.5a, the global function syntax is used (not `C_ChatInfo`):

```lua
-- Register prefix BEFORE trying to receive messages
-- Added in Patch 4.1; in 3.3.5a this function may NOT exist
-- Check your private server — some backport it, some don't
if RegisterAddonMessagePrefix then
    RegisterAddonMessagePrefix("MYADDON")
end

-- Send (always available in 3.3.5a)
-- SendAddonMessage(prefix, message, chatType [, target])
-- prefix: max 16 chars
-- message: max 255 chars
-- chatType: "PARTY", "RAID", "GUILD", "OFFICER", "WHISPER", "BATTLEGROUND"
SendAddonMessage("MYADDON", "hello:world", "PARTY")
SendAddonMessage("MYADDON", "hello", "WHISPER", "PlayerName")

-- Receive via CHAT_MSG_ADDON event
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    if event == "CHAT_MSG_ADDON" and prefix == "MYADDON" then
        -- parse message
    end
end)
```

> **3.3.5a Note**: `RegisterAddonMessagePrefix` was added in patch 4.1.0 (live). On most WotLK private servers, it does NOT exist and is not needed — all `CHAT_MSG_ADDON` messages are delivered without prefix registration. Check your server's API.

### Rate Limiting

Use **ChatThrottleLib** (embedded library) to avoid getting throttled:

```lua
-- ChatThrottleLib:SendAddonMessage(prio, prefix, text, chatType, target, callbackFn, cbArg)
ChatThrottleLib:SendAddonMessage("NORMAL", "MYADDON", data, "RAID")
```

---

## 22. API Function Categories

### Player & Character

```lua
GetPlayerMapPosition("player")          -- x, y (0-1)
GetPlayerFacing()                       -- radians
IsStealthed()
IsMounted()
IsFlying()
UnitInBattleground("player")
GetXPExhaustion()                       -- rested XP
GetRestState()                          -- 1=rested, 2=normal
GetCombatRating(combatRatingIndex)
GetCombatRatingBonus(combatRatingIndex)
GetArmorPenetration()
GetDodgeChance()
GetParryChance()
GetBlockChance()
GetSpellHitModifier()
GetSpellCritChance()
GetRangedCritChance()
GetCritChance()
GetMastery()                            -- not in 3.3.5a (added Cata)
```

### Talents (WotLK)

```lua
GetNumTalentTabs()                      -- always 3
GetNumTalents(tabIndex)
GetTalentInfo(tabIndex, talentIndex)    -- name, iconTexture, tier, column, currentRank, maxRank, isExceptional, available
GetTalentTabInfo(tabIndex)              -- name, iconTexture, pointsSpent, background
GetActiveTalentGroup()                  -- 1 or 2 (dual spec)
GetNumTalentGroups()                    -- 1 or 2
GetPreviewTalent(tabIndex, talentIndex) -- for in-preview builds
LearnTalent(tabIndex, talentIndex)
```

### Party & Raid

```lua
GetNumPartyMembers()                    -- 0-4
GetNumRaidMembers()                     -- 0-40
GetRaidRosterInfo(raidIndex)            -- name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML
IsInRaid()
IsInGroup()
UnitInParty(unitId)
UnitInRaid(unitId)                      -- raid index or nil
GetPartyLeaderIndex()
GetRaidTargetIndex(unitId)              -- 1-8 or nil
SetRaidTarget(unitId, index)
PromoteToLeader(name)
KickPlayer(name)
LeaveParty()
AcceptGroup()
DeclineGroup()
InviteUnit(name)
```

### Guild

```lua
GetNumGuildMembers()                    -- online, total
GetGuildInfo(unitId)                    -- guildName, guildRankName, guildRankIndex
GetGuildRosterInfo(index)               -- name, rankName, rankIndex, level, classDisplayName, zone, publicNote, officerNote, isOnline, status, class, achievementPoints, achievementRank, isMobile
IsInGuild()
GuildInvite(name)
GuildKick(name)
GuildLeave()
GuildPromote(name)
GuildDemote(name)
```

### Quest

```lua
GetNumQuestLogEntries()
GetQuestLogTitle(index)                 -- title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questId, startEvent, displayQuestId, isOnMap, hasLocalPOI, isTask, isStory
GetQuestLogIndexByID(questId)
GetQuestLogSelection()
SelectQuestLogEntry(index)
GetQuestLogQuestText()                  -- questDescription, questObjectives
GetNumQuestLeaderBoards()
GetQuestLogLeaderBoard(index)           -- text, type, finished
AbandonQuest()
GetAbandonQuestName()
QuestLogPushQuest()                     -- share quest with party
IsQuestComplete(questId)
GetQuestTimers()                        -- questId, seconds remaining (vararg pairs)
```

### Map & Minimap

```lua
GetCurrentMapAreaID()
GetCurrentMapContinent()
GetCurrentMapZone()
SetMapToCurrentZone()
GetMapZones(continentIndex)             -- zone names
GetPlayerMapPosition(unitId)            -- x, y (0.0-1.0)
GetNumMapLandmarks()
GetMapLandmarkInfo(index)               -- name, description, textureIndex, x, y
GetMiniMapBattlefieldFlagTexture(index)
GetNumBattlefieldFlagPositions()
GetBattlefieldFlagPosition(index)
```

### Auction House

```lua
GetNumAuctionItems(type)                -- type: "list", "bidder", "owner"
GetAuctionItemInfo(type, index)         -- name, texture, count, quality, canUse, level, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId, hasAllInfo
GetAuctionItemLink(type, index)
SortAuctionItems(type, sort)
PlaceAuctionBid(type, index, bid)
PostAuction(minBid, buyoutPrice, runTime, stackSize, numStacks)
CancelAuction(index)
StartAuction(minBid, buyoutPrice, runTime, stackSize, numStacks)
BrowseAuctionItems(name, minLevel, maxLevel, invTypeIndex, classIndex, subclassIndex, page, isUsable, qualityIndex)
```

### Spellbook & Abilities

```lua
HasPetSpells()
GetPetActionInfo(index)
GetPetActionSlotUsable(index)
GetPetActionCooldown(index)
PetAttack()
PetFollow()
PetStay()
PetAggressive()
PetDefensive()
PetPassive()
```

### Miscellaneous Globals

```lua
-- Time
GetTime()                               -- game client time (seconds, float)
date([format [, time]])                 -- Lua date (WoW provides this)

-- Sound
PlaySound(soundId)
PlaySoundFile("Interface\\...")
StopSound(handle)

-- Camera
GetCameraZoom()
SetCameraZoom(zoom)

-- Cursor
GetCursorInfo()                         -- type, id, ... of dragged item
ResetCursor()
SetCursor("Interface\\...")

-- Screen
GetScreenWidth()
GetScreenHeight()
GetPhysicalScreenSize()

-- Locale
GetLocale()                             -- "enUS", "deDE", "frFR", etc.

-- Versions
GetBuildInfo()                          -- version, build, date, tocversion

-- Error handling
seterrorhandler(function(msg) end)
geterrorhandler()
```

---

## 23. Common Patterns

### Frame with Dragging

```lua
local f = CreateFrame("Frame", "MyFrame", UIParent)
f:SetSize(300, 200)
f:SetPoint("CENTER")
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetClampedToScreen(true)

f:SetScript("OnDragStart", function(self) self:StartMoving() end)
f:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)

-- Save position
f:SetScript("OnHide", function(self)
    local point, _, relPoint, x, y = self:GetPoint()
    MyDB.pos = {point, relPoint, x, y}
end)

-- Restore position
if MyDB and MyDB.pos then
    local p = MyDB.pos
    f:ClearAllPoints()
    f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end
```

### Health Bar

```lua
local function CreateHealthBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(200, 16)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0, 1, 0)
    bar:SetMinMaxValues(0, 1)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetVertexColor(0, 0.3, 0)

    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER")

    bar:SetScript("OnValueChanged", function(self, value)
        local min, max = self:GetMinMaxValues()
        text:SetText(math.floor(value) .. " / " .. math.floor(max))
    end)

    return bar
end
```

### Tooltip on Hover

```lua
btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Title", 1, 1, 1)
    GameTooltip:AddLine("Description text.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)
```

### SafeAddonDB Pattern

```lua
local DEFAULTS = {
    enabled = true,
    scale   = 1.0,
    pos     = {"CENTER", "CENTER", 0, 0},
}

local function InitDB()
    MyAddonDB = MyAddonDB or {}
    for k, v in pairs(DEFAULTS) do
        if MyAddonDB[k] == nil then
            MyAddonDB[k] = v
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, name)
    if name == "MyAddon" then
        InitDB()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
```

### Cooldown Tracking

```lua
local f = CreateFrame("Frame")
f:RegisterEvent("SPELL_UPDATE_COOLDOWN")
f:SetScript("OnEvent", function(self, event)
    local start, duration, enabled = GetSpellCooldown(spellId)
    if duration > 1.5 then  -- > 1.5 avoids GCD
        local remaining = start + duration - GetTime()
        -- update cooldown display
    end
end)
```

### Unit Aura Scanner

```lua
local function GetAura(unitId, spellName, filter)
    filter = filter or "HELPFUL"
    for i = 1, 40 do
        local name, rank, icon, count, debuffType, duration, expirationTime,
              unitCaster, isStealable, _, spellId = UnitAura(unitId, i, filter)
        if not name then break end
        if name == spellName then
            return name, count, duration, expirationTime, spellId
        end
    end
end
```

### CLEU Damage Meter Skeleton

```lua
local dmg = {}

local f = CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:SetScript("OnEvent", function(self, event, timestamp, subevent,
        hideCaster, srcGUID, srcName, srcFlags, srcRaidFlags,
        dstGUID, dstName, dstFlags, dstRaidFlags, ...)

    local isPlayerSrc = bit.band(srcFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) > 0
        or bit.band(srcFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0

    if isPlayerSrc and (
        subevent == "SPELL_DAMAGE" or
        subevent == "SPELL_PERIODIC_DAMAGE" or
        subevent == "SWING_DAMAGE"
    ) then
        local amount
        if subevent == "SWING_DAMAGE" then
            amount = select(1, ...)
        else
            amount = select(4, ...)  -- skip spellId, spellName, school
        end
        dmg[srcName] = (dmg[srcName] or 0) + (amount or 0)
    end
end)
```

---

*Data sourced from warcraft.wiki.gg and wowwiki-archive.fandom.com. Verified against WotLK 3.3.5a (build 12340) private server conventions. Some post-3.3.5a functions (C_* namespaces, GetCombatLogCurrentEventInfo, RegisterAddonMessagePrefix) are noted where they differ.*
