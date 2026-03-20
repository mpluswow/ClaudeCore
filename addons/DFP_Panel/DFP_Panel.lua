-- =============================================================================
-- DFP_Panel.lua  v1.2.0
-- Dreamforge hub panel — 2×2 grid of feature modules.
-- Minimap button (drag to reposition) toggles the main window.
-- Slash: /dfp
-- =============================================================================

-- =============================================================================
-- SAVED VARIABLES & SHARED BACKDROP
-- =============================================================================
DFP_Settings = DFP_Settings or {
    minimapAngle = 200,   -- degrees; position on minimap ring
    x            = nil,
    y            = nil,
}

local SHARED_BACKDROP = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, tileSize = 8, edgeSize = 10,
    insets   = { left=3, right=3, top=3, bottom=3 },
}

-- =============================================================================
-- PANEL DEFINITIONS
-- icon: swap any path for a different look — missing textures show nothing.
-- active=true  → clickable, full colour, hover highlight
-- active=false → greyed out, mouse disabled
-- =============================================================================
local PANELS = {
    {
        name   = "Daily Tasks",
        status = "ACTIVE",
        color  = { r=1.00, g=0.84, b=0.00 },
        icon   = "Interface\\Icons\\INV_Misc_Note_01",
        active = true,
        onClick = function()
            if SlashCmdList["DFPDAILY"] then
                SlashCmdList["DFPDAILY"]("")
            end
        end,
    },
    {
        name   = "Bounties",
        status = "COMING SOON",
        color  = { r=1.00, g=0.33, b=0.33 },
        icon   = "Interface\\Icons\\INV_Misc_Coin_01",
        active = false,
    },
    {
        name   = "Guild Wars",
        status = "COMING SOON",
        color  = { r=0.33, g=0.53, b=1.00 },
        icon   = "Interface\\Icons\\INV_Sword_04",
        active = false,
    },
    {
        name   = "Auction House",
        status = "ACTIVE",
        color  = { r=0.20, g=0.85, b=0.65 },
        icon   = "Interface\\Icons\\INV_Misc_Coin_01",
        active = true,
        onClick = function()
            if SlashCmdList["DFPAH"] then
                SlashCmdList["DFPAH"]("")
            end
        end,
    },
}

-- =============================================================================
-- LAYOUT CONSTANTS
-- WIN_W = BPAD + CELL_W + CELL_GAP + CELL_W + BPAD
-- =============================================================================
local BPAD     = 12
local HDR_H    = 30
local CELL_GAP = 10
local CELL_H   = 130
local WIN_W    = 360
local CELL_W   = (WIN_W - 2 * BPAD - CELL_GAP) / 2   -- 163

local function WinH()
    return BPAD + HDR_H + 8 + (2 * CELL_H) + CELL_GAP + BPAD
end

-- =============================================================================
-- MAIN WINDOW
-- =============================================================================
local DFPFrame = CreateFrame("Frame", "DFPFrame", UIParent)
DFPFrame:SetSize(WIN_W, WinH())
DFPFrame:SetMovable(true)
DFPFrame:EnableMouse(true)
DFPFrame:RegisterForDrag("LeftButton")
DFPFrame:SetFrameStrata("MEDIUM")
DFPFrame:SetClampedToScreen(true)
DFPFrame:Hide()

DFPFrame:SetBackdrop(SHARED_BACKDROP)
DFPFrame:SetBackdropColor(0.03, 0.02, 0.01, 0.97)
DFPFrame:SetBackdropBorderColor(0.50, 0.40, 0.16, 1)

if DFP_Settings.x and DFP_Settings.y then
    DFPFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", DFP_Settings.x, DFP_Settings.y)
else
    DFPFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
end

DFPFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
DFPFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local _, _, _, x, y = self:GetPoint()
    DFP_Settings.x = x
    DFP_Settings.y = y
end)

-- Header gold accent stripe
local dfpAccent = DFPFrame:CreateTexture(nil, "ARTWORK")
dfpAccent:SetWidth(3)
dfpAccent:SetHeight(HDR_H - 6)
dfpAccent:SetPoint("TOPLEFT", DFPFrame, "TOPLEFT", BPAD, -(BPAD + 3))
dfpAccent:SetTexture("Interface\\Buttons\\WHITE8X8")
dfpAccent:SetVertexColor(1, 0.82, 0, 1)

-- Header icon
local dfpIcon = DFPFrame:CreateTexture(nil, "ARTWORK")
dfpIcon:SetSize(20, 20)
dfpIcon:SetPoint("TOPLEFT", DFPFrame, "TOPLEFT", BPAD + 8, -(BPAD + (HDR_H - 20) / 2))
dfpIcon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
dfpIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

-- Title (offset right of icon)
local dfpTitle = DFPFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
dfpTitle:SetPoint("TOPLEFT",  DFPFrame, "TOPLEFT",  BPAD + 8 + 20 + 5, -BPAD)
dfpTitle:SetPoint("TOPRIGHT", DFPFrame, "TOPRIGHT", -(BPAD + 22),       -BPAD)
dfpTitle:SetHeight(HDR_H)
dfpTitle:SetJustifyH("LEFT")
dfpTitle:SetJustifyV("MIDDLE")
dfpTitle:SetText("|cffffd700Dreamforge|r")

-- [x] close button (text-based)
local dfpClose = CreateFrame("Button", nil, DFPFrame)
dfpClose:SetSize(18, 18)
dfpClose:SetPoint("TOPRIGHT", DFPFrame, "TOPRIGHT", -(BPAD - 2), -(BPAD + (HDR_H - 18) / 2))

local closeBG = dfpClose:CreateTexture(nil, "BACKGROUND")
closeBG:SetAllPoints()
closeBG:SetTexture("Interface\\Buttons\\WHITE8X8")
closeBG:SetVertexColor(0.30, 0.22, 0.10, 0.45)

local closeFS = dfpClose:CreateFontString(nil, "OVERLAY", "GameFontNormal")
closeFS:SetAllPoints()
closeFS:SetJustifyH("CENTER")
closeFS:SetJustifyV("MIDDLE")
closeFS:SetText("|cffaaaaaa" .. "x" .. "|r")

dfpClose:SetScript("OnEnter", function()
    closeBG:SetVertexColor(0.55, 0.10, 0.08, 0.80)
    closeFS:SetText("|cffff6060" .. "x" .. "|r")
end)
dfpClose:SetScript("OnLeave", function()
    closeBG:SetVertexColor(0.30, 0.22, 0.10, 0.45)
    closeFS:SetText("|cffaaaaaa" .. "x" .. "|r")
end)
dfpClose:SetScript("OnClick", function() DFPFrame:Hide() end)

-- Header separator
local dfpSep = DFPFrame:CreateTexture(nil, "ARTWORK")
dfpSep:SetHeight(1)
dfpSep:SetPoint("TOPLEFT",  DFPFrame, "TOPLEFT",  BPAD,  -(BPAD + HDR_H))
dfpSep:SetPoint("TOPRIGHT", DFPFrame, "TOPRIGHT", -BPAD, -(BPAD + HDR_H))
dfpSep:SetTexture("Interface\\Buttons\\WHITE8X8")
dfpSep:SetVertexColor(0.75, 0.60, 0.10, 0.40)

-- =============================================================================
-- PANEL GRID  (2 columns × 2 rows)
-- Card layout (top → bottom, CELL_H = 130):
--   3px  top stripe
--   10px gap
--   36px icon (32x32 centered)
--   6px  gap
--   18px name (GameFontNormal)
--   8px  gap
--   1px  divider
--   8px  gap
--   13px status label
--   bottom padding
-- =============================================================================
local GRID_TOP = BPAD + HDR_H + 8

for i, panel in ipairs(PANELS) do
    local col = (i - 1) % 2
    local row = math.floor((i - 1) / 2)

    local xOff = BPAD + col * (CELL_W + CELL_GAP)
    local yOff = GRID_TOP + row * (CELL_H + CELL_GAP)

    local cell = CreateFrame("Button", nil, DFPFrame)
    cell:SetSize(CELL_W, CELL_H)
    cell:SetPoint("TOPLEFT", DFPFrame, "TOPLEFT", xOff, -yOff)

    cell:SetBackdrop(SHARED_BACKDROP)

    local cr, cg, cb = panel.color.r, panel.color.g, panel.color.b

    if panel.active then
        cell:SetBackdropColor(0.06, 0.05, 0.04, 0.95)
        cell:SetBackdropBorderColor(0.40, 0.32, 0.12, 0.9)
    else
        cell:SetBackdropColor(0.04, 0.04, 0.04, 0.90)
        cell:SetBackdropBorderColor(0.20, 0.18, 0.16, 0.6)
    end

    -- Top colour stripe
    local stripe = cell:CreateTexture(nil, "ARTWORK")
    stripe:SetHeight(3)
    stripe:SetPoint("TOPLEFT",  cell, "TOPLEFT",  3, -3)
    stripe:SetPoint("TOPRIGHT", cell, "TOPRIGHT", -3, -3)
    stripe:SetTexture("Interface\\Buttons\\WHITE8X8")
    if panel.active then
        stripe:SetVertexColor(cr, cg, cb, 1)
    else
        stripe:SetVertexColor(cr * 0.30, cg * 0.30, cb * 0.30, 0.7)
    end

    -- Icon (32×32, centred horizontally, top at y=-13)
    local icon = cell:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOP", cell, "TOP", 0, -13)
    icon:SetTexture(panel.icon)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if not panel.active then
        icon:SetVertexColor(0.35, 0.35, 0.35, 0.6)
    end

    -- Panel name (below icon, y=-55 from top)
    local nameFS = cell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameFS:SetPoint("TOPLEFT",  cell, "TOPLEFT",  6, -55)
    nameFS:SetPoint("TOPRIGHT", cell, "TOPRIGHT", -6, -55)
    nameFS:SetHeight(18)
    nameFS:SetJustifyH("CENTER")
    if panel.active then
        nameFS:SetText("|cffe8e0d0" .. panel.name .. "|r")
    else
        nameFS:SetText("|cff484844" .. panel.name .. "|r")
    end

    -- Divider
    local divider = cell:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT",  cell, "TOPLEFT",  10, -82)
    divider:SetPoint("TOPRIGHT", cell, "TOPRIGHT", -10, -82)
    divider:SetTexture("Interface\\Buttons\\WHITE8X8")
    if panel.active then
        divider:SetVertexColor(cr, cg, cb, 0.18)
    else
        divider:SetVertexColor(0.22, 0.20, 0.18, 0.20)
    end

    -- Status label (bottom)
    local statusFS = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusFS:SetPoint("BOTTOMLEFT",  cell, "BOTTOMLEFT",  6, 12)
    statusFS:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -6, 12)
    statusFS:SetHeight(13)
    statusFS:SetJustifyH("CENTER")
    if panel.active then
        statusFS:SetText(
            "|cff" .. string.format("%02x%02x%02x",
                math.floor(cr * 255), math.floor(cg * 255), math.floor(cb * 255)
            ) .. panel.status .. "|r"
        )
    else
        statusFS:SetText("|cff333330" .. panel.status .. "|r")
    end

    -- Interaction (active panels only)
    if panel.active and panel.onClick then
        cell:SetScript("OnClick", panel.onClick)
        cell:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.10, 0.09, 0.07, 0.95)
            self:SetBackdropBorderColor(cr * 0.9, cg * 0.9, cb * 0.9, 1)
        end)
        cell:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.06, 0.05, 0.04, 0.95)
            self:SetBackdropBorderColor(0.40, 0.32, 0.12, 0.9)
        end)
    else
        cell:EnableMouse(false)
    end
end

-- =============================================================================
-- MINIMAP BUTTON
-- Uses MiniMap-TrackingBorder (same ring minimap tracking buttons use).
-- Left-click: toggle main window.  Drag: reposition around minimap ring.
-- =============================================================================
local MINIMAP_RADIUS = 84

local function DFP_UpdateMinimapPos()
    local angle = math.rad(DFP_Settings.minimapAngle or 200)
    DFPMinimapBtn:SetPoint(
        "CENTER", Minimap, "CENTER",
        math.cos(angle) * MINIMAP_RADIUS + 0,
        math.sin(angle) * MINIMAP_RADIUS - 0
    )
end

DFPMinimapBtn = CreateFrame("Button", "DFPMinimapBtn", Minimap)
DFPMinimapBtn:SetSize(31, 31)
DFPMinimapBtn:SetFrameStrata("MEDIUM")
DFPMinimapBtn:SetMovable(true)
DFPMinimapBtn:RegisterForDrag("LeftButton")
DFPMinimapBtn:RegisterForClicks("LeftButtonUp")

-- Icon inside the ring — BACKGROUND layer so the ring renders on top.
local mmIcon = DFPMinimapBtn:CreateTexture(nil, "BACKGROUND")
mmIcon:SetSize(20, 20)
mmIcon:SetPoint("CENTER", DFPMinimapBtn, "CENTER", 0, 0)
mmIcon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
mmIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

-- Ring border — OVERLAY layer, same CENTER anchor as the icon so both are
-- guaranteed to share the exact same reference point.
local mmBorder = DFPMinimapBtn:CreateTexture(nil, "OVERLAY")
mmBorder:SetSize(53, 53)
mmBorder:SetPoint("CENTER", DFPMinimapBtn, "CENTER", 0, 0)
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

-- Hover highlight
local mmHL = DFPMinimapBtn:CreateTexture(nil, "HIGHLIGHT")
mmHL:SetSize(31, 31)
mmHL:SetPoint("CENTER", DFPMinimapBtn, "CENTER", 0, 0)
mmHL:SetBlendMode("ADD")
mmHL:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

DFPMinimapBtn:SetScript("OnClick", function()
    if DFPFrame:IsShown() then
        DFPFrame:Hide()
    else
        DFPFrame:Show()
    end
end)

DFPMinimapBtn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my  = Minimap:GetCenter()
        local scale   = UIParent:GetEffectiveScale()
        local cx, cy  = GetCursorPosition()
        cx, cy = cx / scale, cy / scale
        DFP_Settings.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
        DFP_UpdateMinimapPos()
    end)
end)

DFPMinimapBtn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

DFPMinimapBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cffffd700Dreamforge|r")
    GameTooltip:AddLine("|cffaaaaaa Left-click to toggle|r", 1, 1, 1)
    GameTooltip:AddLine("|cffaaaaaa Drag to reposition|r",   1, 1, 1)
    GameTooltip:Show()
end)

DFPMinimapBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

DFP_UpdateMinimapPos()

-- =============================================================================
-- SLASH COMMAND:  /dfp
-- =============================================================================
SLASH_DFPPANEL1 = "/dfp"
SlashCmdList["DFPPANEL"] = function()
    if DFPFrame:IsShown() then
        DFPFrame:Hide()
    else
        DFPFrame:Show()
    end
end
