-- Syl's Tools > Upcoming Spells: page in the main window.

local _, ns = ...
local ST = (ns and ns.ST) or SylsTools
local S = ns.Spells
local Wd = ST.Widgets

local Panel = {}
S.Panel = Panel

function S:BuildPanel(page)
    Panel.page = page

    local h = Wd.Header(page, "Upcoming Spells")
    h:SetPoint("TOPLEFT", 0, 0)

    Panel.info = Wd.Label(page, "", "GameFontHighlightSmall", 540)
    Panel.info:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -10)

    Panel.tabCheck = Wd.Check(page, "Show a tab on my spellbook",
        function() return S.db.spellbookTab end,
        function(v) S.db.spellbookTab = v end)
    Panel.tabCheck:SetPoint("TOPLEFT", Panel.info, "BOTTOMLEFT", -4, -8)

    Panel.notifyCheck = Wd.Check(page, "Tell me what's new when I level up",
        function() return S.db.notifyLevelUp end,
        function(v) S.db.notifyLevelUp = v end)
    Panel.notifyCheck:SetPoint("LEFT", Panel.tabCheck, "RIGHT", 220, 0)

    Panel.allCheck = Wd.Check(page, "Show every level (not just the next 10)",
        function() return S.db.levelsAhead == 0 end,
        function(v) S.db.levelsAhead = v and 0 or 10 end)
    Panel.allCheck:SetPoint("TOPLEFT", Panel.tabCheck, "BOTTOMLEFT", 0, -2)

    Panel.list = Wd.ScrollList(page, 540)
    Panel.list:SetPoint("TOPLEFT", Panel.allCheck, "BOTTOMLEFT", 4, -10)
    Panel.list:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -24, 0)

    page:SetScript("OnShow", function() Panel:Refresh() end)
    Panel:Refresh()
end

function Panel:Refresh()
    if not self.page then return end
    self.tabCheck:Refresh()
    self.notifyCheck:Refresh()
    self.allCheck:Refresh()
    local data = S:TrainerData()
    if data then
        local when = (date and data.updated and data.updated > 0) and date("%b %d", data.updated) or "earlier"
        self.info:SetText(string.format(
            "From your class trainer (last visited %s). Visit again after the game updates to refresh it.", when))
    else
        self.info:SetText("|cffffd100Visit your class trainer once|r to fill in this list.")
    end
    self.list:SetRows(S:BuildRows(S.db.levelsAhead))
end

for _, e in ipairs({ "ST_SPELLS_UPDATED", "ST_SETTINGS_CHANGED", "SPELLS_CHANGED", "PLAYER_LEVEL_UP" }) do
    ST:On(e, function()
        if Panel.page and Panel.page:IsShown() then Panel:Refresh() end
    end)
end
