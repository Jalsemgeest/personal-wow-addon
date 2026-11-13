-- Syl's Tools: main window. A sidebar lists modules; each module builds its own page.
-- Open with /syl or from the minimap addon menu.

local _, ns = ...
local ST = (ns and ns.ST) or SylsTools
local Wd = ST.Widgets

local UI = {}
ST.UI = UI

local WIDTH, HEIGHT, SIDEBAR = 760, 520, 150
local frame, content
local navButtons, pages = {}, {}

local function savePosition(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    ST.db.ui.point = { point, "UIParent", relPoint, x, y }
end

local function build()
    if frame then return end
    frame = CreateFrame("Frame", "SylsToolsFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", savePosition)
    local p = ST.db.ui.point
    frame:SetPoint(p[1], UIParent, p[3], p[4], p[5])
    frame:Hide()
    -- Close with Escape.
    if UISpecialFrames then table.insert(UISpecialFrames, "SylsToolsFrame") end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", frame, "TOP", 0, -5)
    title:SetText(ST.title .. "  |cff888888v" .. ST.version .. "|r")

    -- Sidebar
    local sidebar = CreateFrame("Frame", nil, frame)
    sidebar:SetPoint("TOPLEFT", 10, -30)
    sidebar:SetPoint("BOTTOMLEFT", 10, 10)
    sidebar:SetWidth(SIDEBAR)
    local sbg = sidebar:CreateTexture(nil, "BACKGROUND")
    sbg:SetAllPoints()
    sbg:SetColorTexture(0, 0, 0, 0.35)

    local prev
    for _, key in ipairs(ST.moduleOrder) do
        local m = ST.modules[key]
        local b = CreateFrame("Button", nil, sidebar)
        b:SetSize(SIDEBAR - 8, 32)
        if prev then b:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -4) else b:SetPoint("TOPLEFT", 4, -4) end
        b.hl = b:CreateTexture(nil, "BACKGROUND")
        b.hl:SetAllPoints()
        b.hl:SetColorTexture(Wd.COLOR_ACCENT[1], Wd.COLOR_ACCENT[2], Wd.COLOR_ACCENT[3], 0.25)
        b.hl:Hide()
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        local icon = b:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetPoint("LEFT", 4, 0)
        icon:SetTexture(m.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        text:SetText(m.title)
        b:SetScript("OnClick", function() UI:Select(key) end)
        navButtons[key] = b
        prev = b
    end

    local more = sidebar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    more:SetPoint("BOTTOM", 0, 8)
    more:SetText("More tools coming soon")

    content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 12, -6)
    content:SetPoint("BOTTOMRIGHT", -14, 12)
end

function UI:Select(key)
    build()
    local m = ST.modules[key]
    if not m then return end
    if not pages[key] and m.BuildPanel then
        local page = CreateFrame("Frame", nil, content)
        page:SetAllPoints()
        m:BuildPanel(page)
        pages[key] = page
    end
    for k, page in pairs(pages) do
        if k == key then page:Show() else page:Hide() end
    end
    for k, b in pairs(navButtons) do
        if k == key then b.hl:Show() else b.hl:Hide() end
    end
    ST.db.ui.lastModule = key
    self.selected = key
end

function UI:Show(key)
    build()
    frame:Show()
    self:Select(key or ST.db.ui.lastModule or ST.moduleOrder[1])
end

function UI:Hide() if frame then frame:Hide() end end

function UI:IsShown() return frame ~= nil and frame:IsShown() end

function UI:Toggle(key)
    if self:IsShown() and (not key or key == self.selected) then
        self:Hide()
    else
        self:Show(key)
    end
end

function UI:Frame() return frame end
