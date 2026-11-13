-- Syl's Tools > Upcoming Spells: a tab on the edge of the spellbook that opens
-- a side panel listing upcoming spells. Works with the classic SpellBookFrame
-- and the modern PlayerSpellsFrame. Only HookScript is used on Blizzard frames
-- (no replaced functions), so it doesn't taint them.

local _, ns = ...
local ST = (ns and ns.ST) or SylsTools
local S = ns.Spells
local Wd = ST.Widgets

local Tab = { attached = {}, open = false }
S.Tab = Tab

local PANEL_W, LIST_W = 320, 280
local tab, panel, list, host

local BOOK_FRAMES = { "SpellBookFrame", "PlayerSpellsFrame" }
local BOOK_ADDONS = { Blizzard_PlayerSpells = true, Blizzard_SpellBook = true }

local function buildPanel()
    if panel then return end
    panel = CreateFrame("Frame", "SylsToolsUpcomingSpellsPanel", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(PANEL_W, 480)
    panel:SetFrameStrata("HIGH")
    panel:Hide()
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    title:SetText("Upcoming Spells")
    list = Wd.ScrollList(panel, LIST_W)
    list:SetPoint("TOPLEFT", 12, -30)
    list:SetPoint("BOTTOMRIGHT", -30, 10)
    panel:SetScript("OnShow", function() Tab:Refresh() end)
    panel:SetScript("OnHide", function()
        -- the close button only closes the panel; remember that choice
        if host and host:IsShown() then Tab.open = false end
    end)
end

function Tab:Refresh()
    if panel and panel:IsShown() then list:SetRows(S:BuildRows(S.db.levelsAhead)) end
end

function Tab:Toggle()
    buildPanel()
    self.open = not panel:IsShown()
    if self.open then
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", host or UIParent, "TOPRIGHT", 40, 0)
        panel:Show()
    else
        panel:Hide()
    end
end

local function buildTab()
    if tab then return end
    tab = CreateFrame("CheckButton", "SylsToolsSpellbookTab", UIParent)
    tab:SetSize(36, 36)
    tab:SetFrameStrata("HIGH")
    local bg = tab:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
    bg:SetSize(64, 64)
    bg:SetPoint("TOPLEFT", -3, 11)
    local icon = tab:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(S.icon)
    tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    tab:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
    tab:SetScript("OnClick", function(self)
        Tab:Toggle()
        self:SetChecked(Tab.open)
    end)
    Wd.SetTooltip(tab, "Upcoming Spells", "Syl's Tools: spells you can train now and what unlocks at future levels.")
    tab:Hide()
end

function Tab:OnBookShown(book)
    if not S.db.spellbookTab then return end
    host = book
    buildTab()
    tab:ClearAllPoints()
    tab:SetPoint("TOPLEFT", book, "TOPRIGHT", 0, -220)
    tab:SetChecked(self.open)
    tab:Show()
    if self.open then
        buildPanel()
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", book, "TOPRIGHT", 40, 0)
        panel:Show()
    end
end

function Tab:OnBookHidden(book)
    if host ~= book then return end
    local wasOpen = self.open
    if tab then tab:Hide() end
    if panel then panel:Hide() end
    self.open = wasOpen -- reopen next time the spellbook opens
end

function Tab:TryAttach()
    for _, name in ipairs(BOOK_FRAMES) do
        local book = _G[name]
        if book and book.HookScript and not self.attached[name] then
            self.attached[name] = true
            book:HookScript("OnShow", function(f) Tab:OnBookShown(f) end)
            book:HookScript("OnHide", function(f) Tab:OnBookHidden(f) end)
            if book:IsShown() then self:OnBookShown(book) end
        end
    end
end

ST:On("ST_READY", function() Tab:TryAttach() end)
ST:On("ADDON_LOADED", function(_, name)
    if BOOK_ADDONS[name] then Tab:TryAttach() end
end)
ST:On("ST_SETTINGS_CHANGED", function()
    if not S.db.spellbookTab then
        if tab then tab:Hide() end
        if panel then panel:Hide() end
    elseif host and host:IsShown() then
        Tab:OnBookShown(host)
    end
end)
for _, e in ipairs({ "ST_SPELLS_UPDATED", "SPELLS_CHANGED", "PLAYER_LEVEL_UP" }) do
    ST:On(e, function() Tab:Refresh() end)
end
