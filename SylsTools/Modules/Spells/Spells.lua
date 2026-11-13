-- Syl's Tools > Upcoming Spells
-- "What do I get next level?" Shows the spells you can train now and the ones
-- coming at future levels, in a tab on your spellbook and in the Syl's Tools
-- window.
--
-- Data sources, both read straight from the game client (no bundled tables,
-- so it follows whatever WoW Forever's trainers actually teach):
--   1. Class trainer: when you open your class trainer, the full list (including
--      spells you're too low for) is recorded per class, account-wide, so your
--      alts of the same class benefit too.
--   2. Spellbook: if the client lists "future spells" in the spellbook, those
--      are included as well.

local _, ns = ...
local ST = (ns and ns.ST) or SylsTools
local Book = ST.Spellbook

local S = ST:NewModule("spells", {
    title = "Upcoming Spells",
    icon = "Interface\\Icons\\INV_Misc_Book_09",
    defaults = {
        trainer = {},          -- [classFile] = { updated = epoch, spells = { {name, rank, level, cost, icon} } }
        spellbookTab = true,   -- show the tab on the spellbook
        notifyLevelUp = true,  -- chat message on level-up listing new spells
        levelsAhead = 10,      -- how many future levels to list (0 = all)
    },
})
ns.Spells = S

local function playerClass()
    local _, classFile = UnitClass("player")
    return classFile or "UNKNOWN"
end

local function playerLevel()
    return UnitLevel and UnitLevel("player") or 1
end

function S:FormatMoney(copper)
    copper = copper or 0
    if copper <= 0 then return "free" end
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local out = {}
    if g > 0 then out[#out + 1] = g .. "g" end
    if s > 0 then out[#out + 1] = s .. "s" end
    if c > 0 then out[#out + 1] = c .. "c" end
    return table.concat(out, " ")
end

---------------------------------------------------------------------------
-- Trainer capture
---------------------------------------------------------------------------
local capturing = false
local FILTERS = { "available", "unavailable", "used" }

function S:CaptureTrainer()
    if capturing or not GetNumTrainerServices then return end
    if IsTradeskillTrainer and IsTradeskillTrainer() then return end
    capturing = true
    -- Show everything (including "too low level") while we read, then restore.
    local saved = {}
    if GetTrainerServiceTypeFilter and SetTrainerServiceTypeFilter then
        for _, f in ipairs(FILTERS) do
            saved[f] = GetTrainerServiceTypeFilter(f)
            SetTrainerServiceTypeFilter(f, 1)
        end
    end
    local spells = {}
    for i = 1, GetNumTrainerServices() do
        local name, rank, category = GetTrainerServiceInfo(i)
        if name and category ~= "header" then
            spells[#spells + 1] = {
                name = name,
                rank = (rank ~= "" and rank) or nil,
                level = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i) or 0,
                cost = GetTrainerServiceCost and (GetTrainerServiceCost(i)) or 0,
                icon = GetTrainerServiceIcon and GetTrainerServiceIcon(i) or nil,
            }
        end
    end
    if SetTrainerServiceTypeFilter then
        for _, f in ipairs(FILTERS) do
            SetTrainerServiceTypeFilter(f, saved[f] and 1 or 0)
        end
    end
    capturing = false
    if #spells == 0 then return end
    self.db.trainer[playerClass()] = { updated = time and time() or 0, spells = spells }
    ST:Fire("ST_SPELLS_UPDATED")
end

function S:TrainerData()
    return self.db.trainer[playerClass()]
end

---------------------------------------------------------------------------
-- Model
---------------------------------------------------------------------------
-- Returns a list of { name, rank, level, cost, icon, spellID, ready } for
-- every spell you don't know yet, sorted by level.
function S:Upcoming()
    local list, seen = {}, {}
    local lvl = playerLevel()
    local data = self:TrainerData()
    if data then
        for _, sp in ipairs(data.spells) do
            local k = Book.Key(sp.name, sp.rank)
            if not seen[k] and not Book:Knows(sp.name, sp.rank) then
                seen[k] = true
                seen[sp.name] = true
                list[#list + 1] = { name = sp.name, rank = sp.rank, level = sp.level or 0,
                    cost = sp.cost, icon = sp.icon, ready = (sp.level or 0) <= lvl }
            end
        end
    end
    for _, f in ipairs(Book:Get().future) do
        if f.name and not seen[f.name] then
            seen[f.name] = true
            list[#list + 1] = { name = f.name, level = f.level or 0, icon = f.icon,
                spellID = f.spellID, ready = (f.level or 0) > 0 and f.level <= lvl }
        end
    end
    table.sort(list, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        if a.name ~= b.name then return a.name < b.name end
        return (Book.RankNumber(a.rank) or 0) < (Book.RankNumber(b.rank) or 0)
    end)
    return list
end

-- Level the spell `name` is first taught at, if known (used by Class Guides).
function S:LevelFor(name)
    local data = self:TrainerData()
    if data then
        local best
        for _, sp in ipairs(data.spells) do
            if sp.name == name and (not best or sp.level < best) then best = sp.level end
        end
        if best then return best end
    end
    for _, f in ipairs(Book:Get().future) do
        if f.name == name and f.level and f.level > 0 then return f.level end
    end
end

-- Rows for Widgets.ScrollList.
function S:BuildRows(levelsAhead)
    local rows = {}
    local lvl = playerLevel()
    local list = self:Upcoming()
    local maxLevel = (levelsAhead and levelsAhead > 0) and (lvl + levelsAhead) or math.huge

    local function itemRow(sp)
        local parts = {}
        if sp.rank then parts[#parts + 1] = sp.rank end
        if sp.cost then parts[#parts + 1] = self:FormatMoney(sp.cost) end
        return { kind = "item", icon = sp.icon, spellID = sp.spellID, dim = not sp.ready,
            title = sp.name, body = table.concat(parts, "  -  ") }
    end

    local ready, readyCost = {}, 0
    for _, sp in ipairs(list) do
        if sp.ready then ready[#ready + 1] = sp; readyCost = readyCost + (sp.cost or 0) end
    end
    if #ready > 0 then
        rows[#rows + 1] = { kind = "header", text = "|cff55ff55Ready to train now|r" }
        if readyCost > 0 then
            rows[#rows + 1] = { kind = "text", text = "Visit your class trainer. Total cost: " .. self:FormatMoney(readyCost) }
        end
        for _, sp in ipairs(ready) do rows[#rows + 1] = itemRow(sp) end
    end

    local currentLevel
    for _, sp in ipairs(list) do
        if not sp.ready and sp.level <= maxLevel then
            if sp.level ~= currentLevel then
                currentLevel = sp.level
                local label = sp.level > 0 and ("Level " .. sp.level) or "Later"
                if sp.level == lvl + 1 then label = label .. "  |cffffd100(next level)|r" end
                rows[#rows + 1] = { kind = "header", text = label }
            end
            rows[#rows + 1] = itemRow(sp)
        end
    end

    if #rows == 0 then
        if not self:TrainerData() then
            rows[#rows + 1] = { kind = "text", text =
                "Visit your |cffffd100class trainer|r once and this list fills in with every spell " ..
                "you'll learn, the level it unlocks at, and what it costs. " ..
                "It's remembered for all your characters of the same class." }
        else
            rows[#rows + 1] = { kind = "text", text = "You know every spell your trainer teaches. Nice!" }
        end
    end
    return rows
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
ST:On("TRAINER_SHOW", function() S:CaptureTrainer() end)

ST:On("PLAYER_LEVEL_UP", function(_, newLevel)
    if not S.db or not S.db.notifyLevelUp then return end
    local data = S:TrainerData()
    if not data then return end
    local names = {}
    for _, sp in ipairs(data.spells) do
        if sp.level == newLevel then
            names[#names + 1] = sp.name .. (sp.rank and (" (" .. sp.rank .. ")") or "")
        end
    end
    if #names > 0 then
        ST:Print("Level %d! New at your trainer: %s", newLevel, table.concat(names, ", "))
    end
end)

S:Command("tab", "- show/hide the Upcoming Spells tab on your spellbook", function()
    ST:ToggleSetting(S.db, "spellbookTab", "Spellbook tab")
end)
S:Command("list", "- print spells ready to train", function()
    local n = 0
    for _, sp in ipairs(S:Upcoming()) do
        if sp.ready then
            n = n + 1
            ST:Print("  %s%s - %s", sp.name, sp.rank and (" (" .. sp.rank .. ")") or "", S:FormatMoney(sp.cost))
        end
    end
    if n == 0 then ST:Print("nothing to train right now") end
end)
