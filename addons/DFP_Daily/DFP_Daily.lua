-- =============================================================================
-- DFP_Daily.lua  v3.3.0
-- WoW 3.3.5a Client Addon
--
-- Server -> Client messages (prefix "DFP_Daily", sep "~"):
--   TASK~id~type~name~progress~required~completed
--   TASKEND  |  PROG~id~progress~required~completed
--   DONE~streak  |  RESET
--
-- Usage:  /dt [hide|test]
-- =============================================================================

local DT_PREFIX = "DFP_Daily"
if RegisterAddonMessagePrefix then
    RegisterAddonMessagePrefix(DT_PREFIX)
end

local TYPE_KILL    = 1
local TYPE_DUNGEON = 2
local TYPE_RAID    = 3
local TYPE_QUEST   = 4
local TYPE_TRAVEL  = 5
local TYPE_PVP     = 6

local DT_TYPES = {
    [TYPE_KILL]    = { hex="|cffff5555", r=1.00, g=0.33, b=0.33, label="KILL"    },
    [TYPE_DUNGEON] = { hex="|cffbb66ff", r=0.73, g=0.40, b=1.00, label="DUNGEON" },
    [TYPE_RAID]    = { hex="|cffff3388", r=1.00, g=0.20, b=0.53, label="RAID"    },
    [TYPE_QUEST]   = { hex="|cffffff44", r=1.00, g=1.00, b=0.27, label="QUEST"   },
    [TYPE_TRAVEL]  = { hex="|cff33ccff", r=0.20, g=0.80, b=1.00, label="EXPLORE" },
    [TYPE_PVP]     = { hex="|cffff8800", r=1.00, g=0.53, b=0.00, label="PVP"     },
}

local DT_TYPE_DESC = {
    [TYPE_KILL]    = "Slay the required number of enemies in the world.",
    [TYPE_DUNGEON] = "Enter the dungeon and defeat its final boss.",
    [TYPE_RAID]    = "Enter the raid and defeat its final boss.",
    [TYPE_QUEST]   = "Accept and complete the required quest.",
    [TYPE_TRAVEL]  = "Travel to the specified zone or area.",
    [TYPE_PVP]     = "Earn the required number of honorable kills.",
}

-- =============================================================================
-- SAVED VARIABLES & STATE
-- =============================================================================
DT_Settings = DT_Settings or { x=nil, y=nil }

local DT_Tasks    = {}
local DT_Incoming = {}
local DT_Streak   = 0

-- =============================================================================
-- SHARED BACKDROP
-- One definition used by the main window, every card, and the tooltip.
-- =============================================================================
local SHARED_BACKDROP = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true,
    tileSize = 8,
    edgeSize = 10,
    insets   = { left=3, right=3, top=3, bottom=3 },
}

-- =============================================================================
-- LAYOUT CONSTANTS
-- =============================================================================
local W        = 290    -- main frame width
local BPAD     = 8      -- content padding inside the border
local HDR_H    = 26     -- header height
local SEC_H    = 66     -- task card height
local SEC_GAP  = 5      -- gap between cards
local SEC_IPAD = 8      -- inner padding inside each card
local BAR_H    = 12     -- progress bar height
local MAX_TASKS= 5

local function ContentH(n)
    if n <= 0 then return 0 end
    return n * SEC_H + (n - 1) * SEC_GAP
end

local function FrameH(n)
    return BPAD + HDR_H + 7 + ContentH(n) + BPAD
end

-- =============================================================================
-- HELPERS
-- =============================================================================
local function DT_Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd700[Daily Tasks]|r " .. tostring(msg))
end

local function DT_Split(str, sep)
    local parts = {}
    local i = 1
    while i <= #str do
        local j = str:find(sep, i, true)
        if j then
            parts[#parts+1] = str:sub(i, j-1)
            i = j + #sep
        else
            parts[#parts+1] = str:sub(i)
            break
        end
    end
    return parts
end

-- =============================================================================
-- CUSTOM TOOLTIP
-- Same backdrop/colors as main window — appears to the right of hovered cards.
-- Created once, reused for all cards.
-- =============================================================================
local DTTooltip = CreateFrame("Frame", nil, UIParent)
DTTooltip:SetSize(210, 120)
DTTooltip:SetFrameStrata("TOOLTIP")
DTTooltip:SetClampedToScreen(true)
DTTooltip:Hide()

DTTooltip:SetBackdrop(SHARED_BACKDROP)
DTTooltip:SetBackdropColor(0.03, 0.02, 0.01, 0.97)
DTTooltip:SetBackdropBorderColor(0.50, 0.40, 0.16, 1)

-- Left stripe coloured per task type (matches card)
local ttStripe = DTTooltip:CreateTexture(nil, "ARTWORK")
ttStripe:SetWidth(4)
ttStripe:SetPoint("TOPLEFT",    DTTooltip, "TOPLEFT",    3, -3)
ttStripe:SetPoint("BOTTOMLEFT", DTTooltip, "BOTTOMLEFT", 3,  3)
ttStripe:SetTexture("Interface\\Buttons\\WHITE8X8")
DTTooltip.stripe = ttStripe

-- Task name (gold)
local ttName = DTTooltip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
ttName:SetPoint("TOPLEFT",  DTTooltip, "TOPLEFT",  14, -8)
ttName:SetPoint("TOPRIGHT", DTTooltip, "TOPRIGHT", -8, -8)
ttName:SetHeight(16)
ttName:SetJustifyH("LEFT")
ttName:SetWordWrap(false)
DTTooltip.ttName = ttName

-- Type label
local ttType = DTTooltip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ttType:SetPoint("TOPLEFT", DTTooltip, "TOPLEFT", 14, -26)
ttType:SetHeight(13)
ttType:SetJustifyH("LEFT")
DTTooltip.ttType = ttType

-- Separator 1
local ttSep1 = DTTooltip:CreateTexture(nil, "ARTWORK")
ttSep1:SetHeight(1)
ttSep1:SetPoint("TOPLEFT",  DTTooltip, "TOPLEFT",  10, -43)
ttSep1:SetPoint("TOPRIGHT", DTTooltip, "TOPRIGHT", -8, -43)
ttSep1:SetTexture("Interface\\Buttons\\WHITE8X8")
ttSep1:SetVertexColor(0.75, 0.60, 0.10, 0.35)

-- Description (wrappable, 2-line height)
local ttDesc = DTTooltip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
ttDesc:SetPoint("TOPLEFT",  DTTooltip, "TOPLEFT",  14, -49)
ttDesc:SetPoint("TOPRIGHT", DTTooltip, "TOPRIGHT", -8, -49)
ttDesc:SetHeight(28)
ttDesc:SetJustifyH("LEFT")
ttDesc:SetWordWrap(true)
DTTooltip.ttDesc = ttDesc

-- Separator 2
local ttSep2 = DTTooltip:CreateTexture(nil, "ARTWORK")
ttSep2:SetHeight(1)
ttSep2:SetPoint("TOPLEFT",  DTTooltip, "TOPLEFT",  10, -81)
ttSep2:SetPoint("TOPRIGHT", DTTooltip, "TOPRIGHT", -8, -81)
ttSep2:SetTexture("Interface\\Buttons\\WHITE8X8")
ttSep2:SetVertexColor(0.75, 0.60, 0.10, 0.35)

-- Progress / status line
local ttProg = DTTooltip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ttProg:SetPoint("TOPLEFT", DTTooltip, "TOPLEFT", 14, -87)
ttProg:SetHeight(14)
ttProg:SetJustifyH("LEFT")
DTTooltip.ttProg = ttProg

-- Percentage line
local ttPct = DTTooltip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
ttPct:SetPoint("TOPLEFT", DTTooltip, "TOPLEFT", 14, -103)
ttPct:SetHeight(12)
ttPct:SetJustifyH("LEFT")
DTTooltip.ttPct = ttPct

local function DTTooltip_Show(anchorFrame, task)
    local td = DT_TYPES[task.task_type] or { hex="|cffffffff", r=1, g=1, b=1, label="?" }

    if task.completed == 1 then
        DTTooltip.stripe:SetVertexColor(0.20, 0.75, 0.20, 1)
        DTTooltip.ttType:SetText("|cff55cc55" .. td.label .. "|r")
        DTTooltip.ttProg:SetText("|cff44ff44Status: Complete!|r")
        DTTooltip.ttPct:SetText("")
    else
        DTTooltip.stripe:SetVertexColor(td.r, td.g, td.b, 1)
        DTTooltip.ttType:SetText(td.hex .. td.label .. "|r")
        DTTooltip.ttProg:SetText(
            "Progress: |cffffff44" .. task.progress .. " / " .. task.required .. "|r"
        )
        local pct = math.floor(
            (task.required > 0) and (task.progress / task.required * 100) or 0
        )
        DTTooltip.ttPct:SetText("|cff888888" .. pct .. "% complete|r")
    end

    DTTooltip.ttName:SetText("|cffffd700" .. task.name .. "|r")
    DTTooltip.ttDesc:SetText(DT_TYPE_DESC[task.task_type] or "")

    DTTooltip:ClearAllPoints()
    DTTooltip:SetPoint("LEFT", anchorFrame, "RIGHT", 8, 0)
    DTTooltip:Show()
end

-- =============================================================================
-- MAIN FRAME
-- =============================================================================
local DTFrame = CreateFrame("Frame", "DTFrame", UIParent)
DTFrame:SetWidth(W)
DTFrame:SetHeight(FrameH(0))
DTFrame:SetMovable(true)
DTFrame:EnableMouse(true)
DTFrame:RegisterForDrag("LeftButton")
DTFrame:SetFrameStrata("MEDIUM")
DTFrame:SetClampedToScreen(true)
DTFrame:Hide()

DTFrame:SetBackdrop(SHARED_BACKDROP)
DTFrame:SetBackdropColor(0.03, 0.02, 0.01, 0.97)
DTFrame:SetBackdropBorderColor(0.50, 0.40, 0.16, 1)

if DT_Settings.x and DT_Settings.y then
    DTFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", DT_Settings.x, DT_Settings.y)
else
    DTFrame:SetPoint("LEFT", UIParent, "LEFT", 20, 100)
end

DTFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
DTFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local _, _, _, x, y = self:GetPoint()
    DT_Settings.x = x
    DT_Settings.y = y
end)

-- =============================================================================
-- HEADER
-- =============================================================================

local dtAccent = DTFrame:CreateTexture(nil, "ARTWORK")
dtAccent:SetWidth(3)
dtAccent:SetHeight(HDR_H - 6)
dtAccent:SetPoint("TOPLEFT", DTFrame, "TOPLEFT", BPAD, -(BPAD + 3))
dtAccent:SetTexture("Interface\\Buttons\\WHITE8X8")
dtAccent:SetVertexColor(1, 0.82, 0, 1)

local dtIcon = DTFrame:CreateTexture(nil, "ARTWORK")
dtIcon:SetSize(18, 18)
dtIcon:SetPoint("TOPLEFT", DTFrame, "TOPLEFT", BPAD + 8, -(BPAD + (HDR_H - 18) / 2))
dtIcon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
dtIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local dtTitle = DTFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
dtTitle:SetPoint("TOPLEFT",  DTFrame, "TOPLEFT",  BPAD + 8 + 18 + 4, -BPAD)
dtTitle:SetPoint("TOPRIGHT", DTFrame, "TOPRIGHT", -(BPAD + 20), -BPAD)
dtTitle:SetHeight(HDR_H)
dtTitle:SetJustifyH("LEFT")
dtTitle:SetJustifyV("MIDDLE")
dtTitle:SetText("|cffffd700Daily Tasks|r")

-- [X] close button — styled text button, turns red on hover
local dtClose = CreateFrame("Button", nil, DTFrame)
dtClose:SetSize(18, 18)
dtClose:SetPoint("TOPRIGHT", DTFrame, "TOPRIGHT", -(BPAD - 2), -(BPAD + (HDR_H - 18) / 2))

local closeBG = dtClose:CreateTexture(nil, "BACKGROUND")
closeBG:SetAllPoints()
closeBG:SetTexture("Interface\\Buttons\\WHITE8X8")
closeBG:SetVertexColor(0.30, 0.22, 0.10, 0.45)

local closeFS = dtClose:CreateFontString(nil, "OVERLAY", "GameFontNormal")
closeFS:SetAllPoints()
closeFS:SetJustifyH("CENTER")
closeFS:SetJustifyV("MIDDLE")
closeFS:SetText("|cffaaaaaa" .. "x" .. "|r")

dtClose:SetScript("OnEnter", function()
    closeBG:SetVertexColor(0.55, 0.10, 0.08, 0.80)
    closeFS:SetText("|cffff6060" .. "x" .. "|r")
end)
dtClose:SetScript("OnLeave", function()
    closeBG:SetVertexColor(0.30, 0.22, 0.10, 0.45)
    closeFS:SetText("|cffaaaaaa" .. "x" .. "|r")
end)
dtClose:SetScript("OnClick", function() DTFrame:Hide() end)

-- Separator line
local dtSep = DTFrame:CreateTexture(nil, "ARTWORK")
dtSep:SetHeight(1)
dtSep:SetPoint("TOPLEFT",  DTFrame, "TOPLEFT",  BPAD,  -(BPAD + HDR_H))
dtSep:SetPoint("TOPRIGHT", DTFrame, "TOPRIGHT", -BPAD, -(BPAD + HDR_H))
dtSep:SetTexture("Interface\\Buttons\\WHITE8X8")
dtSep:SetVertexColor(0.75, 0.60, 0.10, 0.40)

-- =============================================================================
-- CONTENT FRAME
-- =============================================================================
local dtContent = CreateFrame("Frame", nil, DTFrame)
dtContent:SetPoint("TOPLEFT",  DTFrame, "TOPLEFT",  BPAD,  -(BPAD + HDR_H + 7))
dtContent:SetPoint("TOPRIGHT", DTFrame, "TOPRIGHT", -BPAD, -(BPAD + HDR_H + 7))
dtContent:SetHeight(1)
DTFrame.taskContainer = dtContent

-- =============================================================================
-- SECTION CARDS  (one per task)
-- =============================================================================
local dtSections = {}

for i = 1, MAX_TASKS do
    local sec = CreateFrame("Frame", nil, dtContent)
    sec:SetHeight(SEC_H)
    sec:SetPoint("TOPLEFT",  dtContent, "TOPLEFT",  0, -(i-1) * (SEC_H + SEC_GAP))
    sec:SetPoint("TOPRIGHT", dtContent, "TOPRIGHT", 0, -(i-1) * (SEC_H + SEC_GAP))
    sec:Hide()

    sec:SetBackdrop(SHARED_BACKDROP)
    sec:SetBackdropColor(0.06, 0.05, 0.04, 0.95)
    sec:SetBackdropBorderColor(0.30, 0.25, 0.12, 0.9)

    local stripe = sec:CreateTexture(nil, "ARTWORK")
    stripe:SetWidth(4)
    stripe:SetPoint("TOPLEFT",    sec, "TOPLEFT",    3, -3)
    stripe:SetPoint("BOTTOMLEFT", sec, "BOTTOMLEFT", 3,  3)
    stripe:SetTexture("Interface\\Buttons\\WHITE8X8")
    sec.stripe = stripe

    local typeLabel = sec:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    typeLabel:SetPoint("TOPLEFT", sec, "TOPLEFT", 12, -SEC_IPAD)
    typeLabel:SetHeight(14)
    sec.typeLabel = typeLabel

    local progText = sec:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    progText:SetPoint("TOPRIGHT", sec, "TOPRIGHT", -SEC_IPAD, -SEC_IPAD)
    progText:SetHeight(14)
    progText:SetJustifyH("RIGHT")
    sec.progText = progText

    local nameText = sec:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameText:SetPoint("TOPLEFT",  sec, "TOPLEFT",  12, -(SEC_IPAD + 14 + 3))
    nameText:SetPoint("TOPRIGHT", sec, "TOPRIGHT", -SEC_IPAD, -(SEC_IPAD + 14 + 3))
    nameText:SetHeight(16)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    sec.nameText = nameText

    local barBG = sec:CreateTexture(nil, "BACKGROUND")
    barBG:SetHeight(BAR_H)
    barBG:SetPoint("BOTTOMLEFT",  sec, "BOTTOMLEFT",  12, SEC_IPAD)
    barBG:SetPoint("BOTTOMRIGHT", sec, "BOTTOMRIGHT", -SEC_IPAD, SEC_IPAD)
    barBG:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    barBG:SetVertexColor(0.06, 0.06, 0.06, 1)

    local bar = CreateFrame("StatusBar", nil, sec)
    bar:SetHeight(BAR_H)
    bar:SetPoint("BOTTOMLEFT",  sec, "BOTTOMLEFT",  12, SEC_IPAD)
    bar:SetPoint("BOTTOMRIGHT", sec, "BOTTOMRIGHT", -SEC_IPAD, SEC_IPAD)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    sec.bar = bar

    sec.taskIndex = i
    sec:EnableMouse(true)
    sec:SetScript("OnEnter", function(self)
        local task = DT_Tasks[self.taskIndex]
        if task then DTTooltip_Show(self, task) end
    end)
    sec:SetScript("OnLeave", function()
        DTTooltip:Hide()
    end)

    dtSections[i] = sec
end

-- =============================================================================
-- UI REFRESH
-- =============================================================================
local function DT_Refresh()
    local count = 0
    local done  = 0

    for i, task in ipairs(DT_Tasks) do
        local sec = dtSections[i]
        if not sec then break end

        count = count + 1
        sec:Show()

        local td = DT_TYPES[task.task_type] or { hex="|cffffffff", r=1, g=1, b=1, label="?" }

        if task.completed == 1 then
            done = done + 1
            sec:SetBackdropColor(0.04, 0.10, 0.04, 0.95)
            sec:SetBackdropBorderColor(0.18, 0.52, 0.18, 0.9)
            sec.stripe:SetVertexColor(0.20, 0.75, 0.20, 1)
            sec.typeLabel:SetText("|cff55cc55" .. td.label .. "|r")
            sec.nameText:SetText("|cff88cc88" .. task.name .. "|r")
            sec.bar:SetStatusBarColor(0.22, 0.72, 0.22, 1)
            sec.bar:SetValue(1)
            sec.progText:SetText("|cff44ff44Complete!|r")
        else
            sec:SetBackdropColor(0.06, 0.05, 0.04, 0.95)
            sec:SetBackdropBorderColor(0.30, 0.25, 0.12, 0.9)
            sec.stripe:SetVertexColor(td.r, td.g, td.b, 1)
            sec.typeLabel:SetText(td.hex .. td.label .. "|r")
            sec.nameText:SetText("|cffe8e0d0" .. task.name .. "|r")
            local frac = (task.required > 0) and (task.progress / task.required) or 0
            local r = math.max(0, 1 - frac * 2)
            local g = math.min(1, frac * 2)
            sec.bar:SetStatusBarColor(r + 0.05, g + 0.05, 0.05, 1)
            sec.bar:SetValue(frac)
            sec.progText:SetText(
                "|cffe8d460" .. task.progress .. " / " .. task.required .. "|r"
            )
        end
    end

    for i = count + 1, MAX_TASKS do
        if dtSections[i] then dtSections[i]:Hide() end
    end

    if count > 0 then
        local c = (done == count) and "|cff44ff44" or "|cffffff44"
        dtTitle:SetText("|cffffd700Daily Tasks|r  " .. c .. done .. "/" .. count .. "|r")
    else
        dtTitle:SetText("|cffffd700Daily Tasks|r")
    end

    local ch = ContentH(count)
    dtContent:SetHeight(math.max(ch, 1))
    DTFrame:SetHeight(FrameH(count))
end

-- =============================================================================
-- ADDON MESSAGE HANDLER
-- =============================================================================
local DTEventFrame = CreateFrame("Frame")
DTEventFrame:RegisterEvent("CHAT_MSG_ADDON")
DTEventFrame:SetScript("OnEvent", function(self, event, prefix, msg, msgType, sender)
    if prefix ~= DT_PREFIX then return end

    local parts = DT_Split(msg, "~")
    local kind  = parts[1]

    if kind == "TASK" then
        DT_Incoming[#DT_Incoming+1] = {
            id        = tonumber(parts[2]) or 0,
            task_type = tonumber(parts[3]) or 0,
            name      = parts[4] or "",
            progress  = tonumber(parts[5]) or 0,
            required  = tonumber(parts[6]) or 1,
            completed = tonumber(parts[7]) or 0,
        }

    elseif kind == "TASKEND" then
        DT_Tasks    = DT_Incoming
        DT_Incoming = {}
        DT_Refresh()
        DT_Print("Daily tasks loaded — " .. #DT_Tasks .. " task(s). Complete before midnight!")

    elseif kind == "PROG" then
        local taskId    = tonumber(parts[2])
        local progress  = tonumber(parts[3]) or 0
        local required  = tonumber(parts[4]) or 1
        local completed = tonumber(parts[5]) or 0
        for _, task in ipairs(DT_Tasks) do
            if task.id == taskId then
                task.progress  = progress
                task.required  = required
                task.completed = completed
                DT_Refresh()
                if completed == 1 then
                    DT_Print("Task complete: " .. task.name)
                else
                    DT_Print(task.name .. " - " .. progress .. " / " .. required)
                end
                break
            end
        end

    elseif kind == "DONE" then
        DT_Streak = tonumber(parts[2]) or 0
        DT_Print(string.format(
            "|cff00ff00All daily tasks complete!|r  Streak: |cffffff00%d|r day(s).", DT_Streak
        ))
        DTFrame:SetBackdropBorderColor(1, 0.84, 0, 1)
        local elapsed = 0
        local flash = CreateFrame("Frame")
        flash:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed >= 3 then
                DTFrame:SetBackdropBorderColor(0.50, 0.40, 0.16, 1)
                self:SetScript("OnUpdate", nil)
            end
        end)

    elseif kind == "RESET" then
        DT_Tasks    = {}
        DT_Incoming = {}
        DT_Refresh()
    end
end)

-- =============================================================================
-- SLASH COMMAND:  /dt [hide|test]
-- =============================================================================
SLASH_DFPDAILY1 = "/dt"
SlashCmdList["DFPDAILY"] = function(msg)
    msg = msg and msg:lower():match("^%s*(.-)%s*$") or ""

    if msg == "hide" then
        DTFrame:Hide()
        DT_Print("Frame hidden. /dt to show.")
        return
    end

    if msg == "test" then
        DT_Tasks = {
            { id=1, task_type=TYPE_KILL,    name="Kill 5 Defias Bandits", progress=3, required=5, completed=0 },
            { id=2, task_type=TYPE_DUNGEON, name="Deadmines: VanCleef",   progress=0, required=1, completed=0 },
            { id=3, task_type=TYPE_QUEST,   name="Lazy Peons",            progress=1, required=1, completed=1 },
        }
        DT_Refresh()
        DTFrame:Show()
        DT_Print("Test tasks loaded.")
        return
    end

    if DTFrame:IsShown() then
        DTFrame:Hide()
    else
        DTFrame:Show()
    end

    if #DT_Tasks == 0 then
        DT_Print("No tasks loaded yet.")
        return
    end

    DT_Print("Today's tasks:")
    for _, task in ipairs(DT_Tasks) do
        local status = task.completed == 1
            and "|cff00ff00DONE|r"
            or  string.format("|cffffff00%d/%d|r", task.progress, task.required)
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd700*|r " .. task.name .. " - " .. status)
    end
end
