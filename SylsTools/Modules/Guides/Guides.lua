-- Syl's Tools > Class Guides
-- Beginner-friendly "how do I play this role?" guides: reference text only.
-- The only thing they read about your character is which abilities you have
-- (your spellbook, plus trainer levels for ones you don't have yet). They
-- don't look at talents, combat, targets or cooldowns, and never suggest
-- buttons in real time. You pick the role you want to read about.
-- Abilities you know are shown in full colour;
-- ones you haven't learned yet are greyed out with the level they unlock at.
--
-- Guides are plain data files in Modules/Guides/Data/<Class>.lua:
--   G:Register({
--     class = "WARRIOR", key = "tank", title = "Tank", subtitle = "Protection",
--     role = "TANK",
--     intro = "What this role is about...",
--     sections = {
--       { title = "Pulling", intro = "optional text", entries = {
--           { spell = 100, name = "Charge", stance = "Battle", text = "How/when to use it." },
--           { spell = 23922, name = "Shield Slam", talent = true, text = "..." },
--           { tip = true, level = 10, text = "General advice, no button attached." },
--       } },
--     },
--   })
-- `name` is a fallback in case the spell ID differs on this client; matching
-- against your spellbook is done by name, so any rank counts.

local _, ns = ...
local ST = (ns and ns.ST) or SylsTools
local API = ST.API
local Book = ST.Spellbook

local G = ST:NewModule("guides", {
    title = "Class Guides",
    icon = "Interface\\Icons\\INV_Misc_Book_11",
    defaults = { hideUnknown = false },
    charDefaults = { choice = nil },
})
ns.Guides = G

G.byClass = {}   -- [classFile] = { guide, ... }

function G:Register(guide)
    assert(guide.class and guide.key, "guide needs class and key")
    local list = self.byClass[guide.class] or {}
    self.byClass[guide.class] = list
    list[#list + 1] = guide
end

function G:PlayerClass()
    local _, classFile = UnitClass("player")
    return classFile
end

function G:GuidesFor(classFile)
    return self.byClass[classFile or self:PlayerClass()] or {}
end

function G:Current()
    local guides = self:GuidesFor()
    if #guides == 0 then return nil end
    local want = self.cdb.choice
    for _, g in ipairs(guides) do
        if g.key == want then return g end
    end
    return guides[1]
end

function G:Choose(key)
    self.cdb.choice = key
    ST:Fire("ST_GUIDE_CHANGED")
end

---------------------------------------------------------------------------
-- Model: entry -> display row
---------------------------------------------------------------------------
local function spellName(e)
    return (e.spell and API.GetSpellName(e.spell)) or e.name
end

function G:EntryState(e)
    local name = spellName(e)
    local known = name and Book:Knows(name) or (e.spell and Book:Knows(e.spell)) or false
    local level = e.level
    local S = ST:GetModule("spells")
    if not known and name and S and S.db then
        level = S:LevelFor(name) or level
    end
    return name, known, level
end

function G:BuildRows(guide)
    local rows = {}
    if not guide then
        local classes = {}
        for c in pairs(self.byClass) do classes[#classes + 1] = c:sub(1, 1) .. c:sub(2):lower() end
        table.sort(classes)
        rows[1] = { kind = "text", text = "There's no guide for your class yet - more are on the way!\n\nGuides so far: "
            .. (#classes > 0 and table.concat(classes, ", ") or "none") }
        return rows
    end

    local knownCount, total = 0, 0
    for _, sec in ipairs(guide.sections) do
        for _, e in ipairs(sec.entries) do
            if e.spell or e.name then
                total = total + 1
                local _, known = self:EntryState(e)
                if known then knownCount = knownCount + 1 end
            end
        end
    end

    rows[#rows + 1] = { kind = "text", text = guide.intro }
    rows[#rows + 1] = { kind = "text", text = string.format(
        "|cff888888You have %d of the %d abilities in this guide. Greyed-out ones unlock later - hover any ability for its tooltip.|r",
        knownCount, total) }

    local lvl = UnitLevel and UnitLevel("player") or 1
    for _, sec in ipairs(guide.sections) do
        local secRows = {}
        for _, e in ipairs(sec.entries) do
            if e.spell or e.name then
                local name, known, level = self:EntryState(e)
                if known or not self.db.hideUnknown then
                    local title = name or "?"
                    if e.stance then title = title .. "  |cff888888(" .. e.stance .. " Stance)|r" end
                    if not known then
                        if e.talent then
                            title = title .. "  |cff888888- talent|r"
                        elseif level and level > 0 then
                            title = title .. string.format("  |cff888888- unlocks at level %d|r", level)
                        else
                            title = title .. "  |cff888888- not learned yet|r"
                        end
                    end
                    secRows[#secRows + 1] = { kind = "item", spellID = e.spell, title = title, body = e.text,
                        icon = (e.spell and API.GetSpellIcon(e.spell)) or e.icon, dim = not known }
                end
            elseif not (e.level and lvl < e.level and self.db.hideUnknown) then
                secRows[#secRows + 1] = { kind = "text", text = "|cffffd100Tip:|r " .. e.text }
            end
        end
        if #secRows > 0 then
            rows[#rows + 1] = { kind = "header", text = sec.title }
            if sec.intro then rows[#rows + 1] = { kind = "text", text = sec.intro } end
            for _, r in ipairs(secRows) do rows[#rows + 1] = r end
        end
    end
    if guide.credit then rows[#rows + 1] = { kind = "text", text = "|cff888888" .. guide.credit .. "|r" } end
    return rows
end

G:Command("open", "- open the guide for your class", function() ST:Toggle("guides") end)
