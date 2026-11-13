-- Syl's Tools: spellbook scanner shared by modules.
-- Builds a snapshot of what the player knows, plus any "future" spells the
-- client lists in the spellbook. Supports both the modern C_SpellBook API and
-- the older global API. Read-only.

local _, ns = ...
local ST = (ns and ns.ST) or SylsTools
local API = ST.API

local Book = { snapshot = nil }
ST.Spellbook = Book

local function key(name, rank)
    return (name or "") .. "|" .. (rank or "")
end
Book.Key = key

-- Rank text ("Rank 3") -> 3. Empty/other -> nil.
function Book.RankNumber(rank)
    return rank and tonumber(tostring(rank):match("(%d+)")) or nil
end

local function newSnapshot()
    return {
        names = {},     -- [name] = highest rank number known (0 if unranked)
        ranks = {},     -- ["name|Rank 2"] = true
        ids = {},       -- [spellID] = true
        future = {},    -- { { spellID, name, icon, level } }
    }
end

local function addKnown(s, name, rank, spellID)
    if not name or API.IsSecret(name) then return end
    local n = Book.RankNumber(rank) or 0
    if (s.names[name] or -1) < n then s.names[name] = n end
    s.ranks[key(name, rank)] = true
    if spellID then s.ids[spellID] = true end
end

local function levelLearned(spellID)
    if not spellID then return end
    if C_Spell and C_Spell.GetSpellLevelLearned then return C_Spell.GetSpellLevelLearned(spellID) end
    if GetSpellLevelLearned then return GetSpellLevelLearned(spellID) end
end

local function scanModern(s)
    local SB = C_SpellBook
    local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
    local T = Enum and Enum.SpellBookItemType or {}
    for line = 1, SB.GetNumSpellBookSkillLines() do
        local info = SB.GetSpellBookSkillLineInfo(line)
        if info and not info.shouldHide then
            local offset, count = info.itemIndexOffset or 0, info.numSpellBookItems or 0
            for slot = offset + 1, offset + count do
                local item = SB.GetSpellBookItemInfo(slot, bank)
                if item then
                    local _, subName = nil, nil
                    if SB.GetSpellBookItemName then _, subName = SB.GetSpellBookItemName(slot, bank) end
                    if item.itemType == T.FutureSpell then
                        table.insert(s.future, { spellID = item.spellID, name = item.name,
                            icon = item.iconID, level = levelLearned(item.spellID) })
                    elseif item.itemType == T.Spell or item.itemType == nil then
                        addKnown(s, item.name, subName, item.spellID)
                    end
                end
            end
        end
    end
end

local function scanClassic(s)
    local bookType = BOOKTYPE_SPELL or "spell"
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, count = GetSpellTabInfo(tab)
        for slot = (offset or 0) + 1, (offset or 0) + (count or 0) do
            local name, rank
            if GetSpellBookItemName then
                name, rank = GetSpellBookItemName(slot, bookType)
            elseif GetSpellName then
                name, rank = GetSpellName(slot, bookType)
            end
            local kind, spellID
            if GetSpellBookItemInfo then kind, spellID = GetSpellBookItemInfo(slot, bookType) end
            if kind == "FUTURESPELL" then
                local icon = GetSpellBookItemTexture and GetSpellBookItemTexture(slot, bookType)
                table.insert(s.future, { spellID = spellID, name = name, icon = icon, level = levelLearned(spellID) })
            elseif name then
                addKnown(s, name, rank, spellID)
            end
        end
    end
end

function Book:Scan()
    local s = newSnapshot()
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        scanModern(s)
    elseif GetNumSpellTabs then
        scanClassic(s)
    end
    self.snapshot = s
    ST:Fire("ST_SPELLBOOK_SCANNED")
    return s
end

function Book:Get()
    return self.snapshot or self:Scan()
end

-- Is a spell known? `spell` is a spellID or name; `rank` (optional) is rank text.
-- Ranked spells count as known if any rank >= the requested one is known.
function Book:Knows(spell, rank)
    local s = self:Get()
    local name = spell
    if type(spell) == "number" then
        if s.ids[spell] then return true end
        if IsPlayerSpell and IsPlayerSpell(spell) then return true end
        name = API.GetSpellName(spell)
    end
    if not name then return false end
    local known = s.names[name]
    if known == nil then return false end
    local want = Book.RankNumber(rank)
    return want == nil or known >= want
end

ST:On("SPELLS_CHANGED", function() Book.snapshot = nil end)
ST:On("LEARNED_SPELL_IN_TAB", function() Book.snapshot = nil end)
ST:On("PLAYER_LEVEL_UP", function() Book.snapshot = nil end)
