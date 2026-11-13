-- Syl's Tools > Fishing: settings & status page in the main window.

local _, ns = ...
local ST = (ns and ns.ST) or SylsTools
local F = ns.Fishing
local Wd = ST.Widgets

local COL_W = 270
local EMPTY_MAIN = "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand"
local EMPTY_OFF = "Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand"
local POLE_ICON = "Interface\\Icons\\INV_Fishingpole_02"

local Panel = {}
F.Panel = Panel

local function fmtTime(s)
    s = math.ceil(s)
    if s >= 60 then return string.format("%d:%02d", math.floor(s / 60), s % 60) end
    return s .. "s"
end

function F:BuildPanel(page)
    local P = Panel
    P.page = page

    local left = CreateFrame("Frame", nil, page)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(COL_W)
    local right = CreateFrame("Frame", nil, page)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(COL_W)

    -----------------------------------------------------------------------
    -- Weapon swap
    -----------------------------------------------------------------------
    local h1 = Wd.Header(left, "Weapon Swap")
    h1:SetPoint("TOPLEFT", 0, 0)

    local yours = Wd.Label(left, "Your weapons", "GameFontDisableSmall")
    yours:SetPoint("TOPLEFT", h1, "BOTTOMLEFT", 0, -12)

    P.mainSlot = Wd.ItemSlot(left, 40, "Main Hand", EMPTY_MAIN)
    P.mainSlot:SetPoint("TOPLEFT", yours, "BOTTOMLEFT", 6, -14)
    P.offSlot = Wd.ItemSlot(left, 40, "Off Hand", EMPTY_OFF)
    P.offSlot:SetPoint("LEFT", P.mainSlot, "RIGHT", 22, 0)

    local arrow = left:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(28, 28)
    arrow:SetPoint("LEFT", P.offSlot, "RIGHT", 18, 0)
    arrow:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")

    P.poleSlot = Wd.ItemSlot(left, 40, "Fishing Pole", POLE_ICON)
    P.poleSlot:SetPoint("LEFT", arrow, "RIGHT", 18, 0)

    P.swapButton = Wd.Button(left, "Equip Fishing Pole", COL_W - 10, function() F.Gear:Toggle() end)
    P.swapButton:SetHeight(30)
    P.swapButton:SetPoint("TOPLEFT", P.mainSlot, "BOTTOMLEFT", -6, -26)

    P.gearStatus = Wd.Label(left, "", "GameFontHighlightSmall", COL_W - 10)
    P.gearStatus:SetPoint("TOPLEFT", P.swapButton, "BOTTOMLEFT", 2, -6)

    P.autoCheck = Wd.Check(left, "Re-equip weapons when done fishing",
        function() return F.cdb.autoRestore end,
        function(v) F.Gear:SetAutoRestore(v) end,
        "After you stop fishing and don't cast again for the time below, your weapons go back on automatically. Casting again cancels the countdown.")
    P.autoCheck:SetPoint("TOPLEFT", P.gearStatus, "BOTTOMLEFT", -4, -22)

    P.delay = Wd.Stepper(left, "Wait after last cast",
        function() return F.cdb.restoreDelay end,
        function(v) F.Gear:SetDelay(v) end, 15, "%ds")
    P.delay:SetPoint("TOPLEFT", P.autoCheck, "BOTTOMLEFT", 4, -2)
    P.delay:SetWidth(COL_W - 10)

    -----------------------------------------------------------------------
    -- One-key fishing
    -----------------------------------------------------------------------
    local h2 = Wd.Header(left, "One-Key Fishing")
    h2:SetPoint("TOPLEFT", P.delay, "BOTTOMLEFT", -4, -18)

    P.keyButton = Wd.KeyBind(left, 170,
        function() return F.cdb.key end,
        function(key) F.OneButton:SetKey(key) end)
    P.keyButton:SetPoint("TOPLEFT", h2, "BOTTOMLEFT", 0, -12)
    local clear = Wd.Button(left, "Clear", 70, function() F.OneButton:SetKey(nil) end)
    clear:SetPoint("LEFT", P.keyButton, "RIGHT", 6, 0)

    P.keyStatus = Wd.Label(left, "", "GameFontHighlightSmall", COL_W - 10)
    P.keyStatus:SetPoint("TOPLEFT", P.keyButton, "BOTTOMLEFT", 2, -6)

    P.forceCheck = Wd.Check(left, "Always on (even without a pole)",
        function() return F.cdb.modeManual end,
        function(v) F.OneButton:SetForced(v) end,
        "Normally one-key fishing is only active while a fishing pole is equipped.")
    P.forceCheck:SetPoint("TOPLEFT", P.keyStatus, "BOTTOMLEFT", -4, -20)

    -----------------------------------------------------------------------
    -- Bobber alerts
    -----------------------------------------------------------------------
    local h3 = Wd.Header(right, "Bobber Alerts")
    h3:SetPoint("TOPLEFT", 0, 0)

    local checks = {
        { "Show fishing HUD while casting", function() return F.db.alert.enabled end,
          function(v) F.db.alert.enabled = v end,
          "A large panel with a countdown appears while your line is out." },
        { "Flash screen when cast expires", function() return F.db.alert.flashOnExpire end,
          function(v) F.db.alert.flashOnExpire = v end, nil },
        { "Show icon over the bobber", function() return F.db.softTarget end,
          function(v) F.db.softTarget = v; F.OneButton:UpdateSoftTarget() end,
          "Turns on the game's soft-target icon so the bobber is easy to spot. Settings are restored when fishing mode ends." },
        { "Boost splash sound while fishing", function() return F.db.sound.focus end,
          function(v) F.db.sound.focus = v; if not v then F.Alert:RestoreSound() end end,
          "Raises effects volume, mutes music and ambience, and keeps sound on in the background. Restored when you're done." },
    }
    P.checks = {}
    local anchor = h3
    for i, c in ipairs(checks) do
        local cb = Wd.Check(right, c[1], c[2], c[3], c[4])
        cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", i == 1 and -4 or 0, i == 1 and -10 or 0)
        P.checks[i] = cb
        anchor = cb
    end

    local move = Wd.Button(right, "Move HUD", 110, function() F.Alert:ToggleUnlock() end)
    move:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, -8)
    local test = Wd.Button(right, "Test Alert", 110, function() F.Alert:Bite() end)
    test:SetPoint("LEFT", move, "RIGHT", 8, 0)

    -----------------------------------------------------------------------
    -- Session stats
    -----------------------------------------------------------------------
    local h4 = Wd.Header(right, "This Session")
    h4:SetPoint("TOPLEFT", move, "BOTTOMLEFT", -4, -20)

    P.stats = Wd.Label(right, "", "GameFontHighlight", COL_W)
    P.stats:SetPoint("TOPLEFT", h4, "BOTTOMLEFT", 0, -10)
    P.stats:SetSpacing(3)

    P.items = Wd.Label(right, "", "GameFontHighlightSmall", COL_W)
    P.items:SetPoint("TOPLEFT", P.stats, "BOTTOMLEFT", 0, -8)
    P.items:SetSpacing(2)

    local reset = Wd.Button(right, "Reset Session", 110, function()
        F.Tracker:NewSession()
        Panel:Refresh()
    end)
    reset:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 0)
    local zone = Wd.Button(right, "Zone Stats", 110, function() F.Tracker:PrintZone() end)
    zone:SetPoint("LEFT", reset, "RIGHT", 8, 0)

    -- Keep countdowns live while visible.
    local acc = 0
    page:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 0.25 then return end
        acc = 0
        Panel:RefreshStatus()
    end)
    page:SetScript("OnShow", function() Panel:Refresh() end)
    Panel:Refresh()
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------
function Panel:RefreshStatus()
    if not self.page then return end
    local Gear = F.Gear
    local main, off = Gear:Saved()
    self.mainSlot:SetItem(main)
    self.offSlot:SetItem(off)
    local pole, poleEquipped = Gear:Pole()
    self.poleSlot:SetItem(pole)

    local status
    if poleEquipped then
        self.swapButton:SetText("Re-equip My Weapons")
        local remaining = Gear:RestoreRemaining()
        if Gear.pendingAfterCombat then
            status = "|cffff8080In combat|r - weapons go back on when combat ends."
        elseif remaining then
            status = string.format("Re-equipping weapons in |cffffd100%s|r. Cast again to cancel.", fmtTime(remaining))
        elseif F.State:IsFishing() then
            status = "Fishing..."
        elseif F.cdb.autoRestore then
            status = string.format("Weapons go back on %s after your last cast.", fmtTime(F.cdb.restoreDelay))
        else
            status = "Auto re-equip is off."
        end
        if not main then status = "|cffff8080No weapons recorded yet|r - equip them once and they'll be remembered." end
    else
        self.swapButton:SetText("Equip Fishing Pole")
        if pole then
            status = main and "Your current weapons are remembered automatically." or "Equip your weapons once so they can be remembered."
        else
            status = "|cffff8080No fishing pole in your bags.|r"
        end
    end
    if ST.API.InCombat() then status = status .. "\n|cffff8080Can't swap gear in combat.|r" end
    self.gearStatus:SetText(status)

    local key = F.cdb.key
    local active = F.OneButton:IsActive()
    if not key then
        self.keyStatus:SetText("Pick a key to cast and reel with the same button.")
    elseif active then
        self.keyStatus:SetText(string.format(
            "|cff55ff55Active|r - press |cffffd100%s|r to cast, and again when the bobber splashes.", key))
    else
        self.keyStatus:SetText(string.format(
            "|cff888888Inactive|r - equip a fishing pole to turn on. %s keeps its normal binding until then.", key))
    end
end

function Panel:Refresh()
    if not self.page then return end
    self.autoCheck:Refresh()
    self.delay:Refresh()
    self.forceCheck:Refresh()
    self.keyButton:Refresh()
    for _, cb in ipairs(self.checks) do cb:Refresh() end
    self:RefreshStatus()

    local T = F.Tracker
    local s = T.session
    local rate = s.casts > 0 and (100 * s.catches / s.casts) or 0
    local lines = {
        string.format("Casts: |cffffffff%d|r    Catches: |cffffffff%d|r (%.0f%%)", s.casts, s.catches, rate),
        string.format("Got away: |cffffffff%d|r    Per hour: |cffffffff%.0f|r", s.escaped, T:CatchesPerHour()),
    }
    local rank, maxRank = T:GetFishingSkill()
    if rank then
        local gain = s.skillStart and rank - s.skillStart or 0
        lines[#lines + 1] = string.format("Skill: |cffffffff%d/%d|r%s", rank, maxRank or 0,
            gain > 0 and string.format(" |cff55ff55(+%d)|r", gain) or "")
    end
    self.stats:SetText(table.concat(lines, "\n"))

    local itemLines = {}
    for i, e in ipairs(T.SortedItems(s.items)) do
        if i > 8 then break end
        itemLines[#itemLines + 1] = string.format("%dx %s", e.count, e.link or ("item:" .. e.id))
    end
    self.items:SetText(#itemLines > 0 and table.concat(itemLines, "\n") or "|cff888888Nothing caught yet.|r")
end

for _, event in ipairs({ "ST_GEAR_CHANGED", "ST_MODE_CHANGED", "ST_CATCH", "ST_FISHING_START",
                         "ST_FISHING_STOP", "ST_SETTINGS_CHANGED", "PLAYER_REGEN_DISABLED",
                         "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED" }) do
    ST:On(event, function()
        if Panel.page and Panel.page:IsShown() then Panel:Refresh() end
    end)
end
