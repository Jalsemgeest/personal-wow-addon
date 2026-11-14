-- Syl's Tools > Class Guides: page in the main window.

local _, ns = ...
local ST = (ns and ns.ST) or SylsTools
local G = ns.Guides
local Wd = ST.Widgets

local Panel = { buttons = {} }
G.Panel = Panel

function G:BuildPanel(page)
    Panel.page = page

    Panel.title = Wd.Header(page, "Class Guides")
    Panel.title:SetPoint("TOPLEFT", 0, 0)

    -- Role picker, one button per guide for your class (built on refresh).
    Panel.picker = CreateFrame("Frame", nil, page)
    Panel.picker:SetPoint("TOPLEFT", Panel.title, "BOTTOMLEFT", 0, -10)
    Panel.picker:SetSize(540, 26)

    Panel.hideCheck = Wd.Check(page, "Only show abilities I have",
        function() return G.db.hideUnknown end,
        function(v) G.db.hideUnknown = v end)
    Panel.hideCheck:SetPoint("TOPLEFT", Panel.picker, "BOTTOMLEFT", -4, -6)

    Panel.list = Wd.ScrollList(page, 540)
    Panel.list:SetPoint("TOPLEFT", Panel.hideCheck, "BOTTOMLEFT", 4, -8)
    Panel.list:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -24, 0)

    page:SetScript("OnShow", function() Panel:Refresh() end)
    Panel:Refresh()
end

function Panel:Refresh()
    if not self.page then return end
    local guides = G:GuidesFor()
    local current = G:Current()

    for i, g in ipairs(guides) do
        local b = self.buttons[i]
        if not b then
            b = Wd.Button(self.picker, "", 170, function(btn) G:Choose(btn.guideKey) end)
            b:SetPoint("LEFT", self.picker, "LEFT", (i - 1) * 178, 0)
            self.buttons[i] = b
        end
        b.guideKey = g.key
        local label = g.title .. (g.subtitle and (" |cff888888(" .. g.subtitle .. ")|r") or "")
        b:SetText(current == g and ("> " .. label .. " <") or label)
        b:Show()
    end
    for i = #guides + 1, #self.buttons do self.buttons[i]:Hide() end

    local className = UnitClass and UnitClass("player") or ""
    self.title:SetText(current and (className .. ": " .. current.title) or "Class Guides")
    self.hideCheck:Refresh()
    self.list:SetRows(G:BuildRows(current))
end

for _, e in ipairs({ "ST_GUIDE_CHANGED", "ST_SETTINGS_CHANGED", "SPELLS_CHANGED", "PLAYER_LEVEL_UP",
                     "ST_SPELLS_UPDATED" }) do
    ST:On(e, function()
        if Panel.page and Panel.page:IsShown() then Panel:Refresh() end
    end)
end
