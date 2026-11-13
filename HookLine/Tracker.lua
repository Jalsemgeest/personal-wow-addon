-- HookLine: Fishing tracker
-- Session + lifetime stats: casts, catches, escapes, items by zone, skill-ups.
-- Read-only: only observes loot and events.

local _, ns = ...
local HL = (ns and ns.HL) or HookLine
local API = HL.API

local Tracker = {}
HL.Tracker = Tracker

local FISHING_LOOT_WINDOW = 2.0 -- seconds after the channel ends

function Tracker:NewSession()
    self.session = {
        started = nil, casts = 0, catches = 0, escaped = 0,
        items = {},   -- [itemID] = { count = n, link = link }
        skillStart = nil,
    }
end
Tracker:NewSession()

local function itemIDFromLink(link)
    return link and tonumber(link:match("item:(%d+)"))
end
Tracker.ItemIDFromLink = itemIDFromLink

local function zoneNames()
    local zone = (GetRealZoneText and GetRealZoneText()) or "Unknown"
    local sub = (GetSubZoneText and GetSubZoneText()) or ""
    if zone == "" then zone = "Unknown" end
    return zone, sub
end

local function zoneRecord(zone)
    local zones = HL.db.lifetime.zones
    local z = zones[zone]
    if not z then
        z = { catches = 0, casts = 0, items = {}, subzones = {} }
        zones[zone] = z
    end
    return z
end

---------------------------------------------------------------------------
-- Recording
---------------------------------------------------------------------------
function Tracker:RecordCast()
    local s = self.session
    s.started = s.started or GetTime()
    s.casts = s.casts + 1
    local life = HL.db.lifetime
    life.totals.casts = life.totals.casts + 1
    local zone = zoneNames()
    local z = zoneRecord(zone)
    z.casts = z.casts + 1
end

-- items: array of { link = link, count = n }
function Tracker:RecordCatch(items)
    local s, life = self.session, HL.db.lifetime
    s.catches = s.catches + 1
    life.totals.catches = life.totals.catches + 1
    local zone, sub = zoneNames()
    local z = zoneRecord(zone)
    z.catches = z.catches + 1
    if sub ~= "" then z.subzones[sub] = (z.subzones[sub] or 0) + 1 end

    for _, it in ipairs(items) do
        local id = itemIDFromLink(it.link)
        if id then
            local n = it.count or 1
            local si = s.items[id] or { count = 0, link = it.link }
            si.count = si.count + n
            s.items[id] = si
            z.items[id] = (z.items[id] or 0) + n
            local li = life.items[id] or { count = 0, link = it.link }
            li.count = li.count + n
            li.link = it.link
            life.items[id] = li
        end
    end
    HL:Fire("HL_CATCH", items)
end

function Tracker:RecordEscape()
    self.session.escaped = self.session.escaped + 1
    HL.db.lifetime.totals.escaped = HL.db.lifetime.totals.escaped + 1
end

---------------------------------------------------------------------------
-- Skill
---------------------------------------------------------------------------
function Tracker:GetFishingSkill()
    if GetProfessions and GetProfessionInfo then
        local _, _, _, fishing = GetProfessions()
        if fishing then
            local _, _, rank, maxRank = GetProfessionInfo(fishing)
            if rank then return rank, maxRank end
        end
    end
    if GetNumSkillLines and GetSkillLineInfo then
        local fishName = API.FishingSpellName()
        for i = 1, GetNumSkillLines() do
            local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
            if not isHeader and name == fishName then return rank, maxRank end
        end
    end
end

function Tracker:CheckSkill()
    local rank, maxRank = self:GetFishingSkill()
    if not rank then return end
    local last = HL.cdb.lastSkill
    if last and rank > last then
        HL:Print("Fishing skill |cff55ff55%d|r/%d (+%d)", rank, maxRank or 0, rank - last)
    end
    HL.cdb.lastSkill = rank
    self.session.skillStart = self.session.skillStart or rank
end

---------------------------------------------------------------------------
-- Loot detection
---------------------------------------------------------------------------
function Tracker:IsFishingLootNow()
    if IsFishingLoot then return IsFishingLoot() and true or false end
    local F = HL.Fishing
    return F.lastStopReason == "ended" and (GetTime() - (F.lastStop or 0)) <= FISHING_LOOT_WINDOW
end

function Tracker:ReadLoot()
    local items = {}
    for i = 1, (GetNumLootItems and GetNumLootItems() or 0) do
        local link = GetLootSlotLink(i)
        if link then
            local _, _, quantity = GetLootSlotInfo(i)
            items[#items + 1] = { link = link, count = quantity or 1 }
        end
    end
    return items
end

HL:On("HL_FISHING_START", function() Tracker:RecordCast() end)
HL:On("HL_FISH_ESCAPED", function() Tracker:RecordEscape() end)
HL:On("LOOT_OPENED", function()
    if Tracker:IsFishingLootNow() then
        Tracker:RecordCatch(Tracker:ReadLoot())
    end
end)
HL:On("SKILL_LINES_CHANGED", function() Tracker:CheckSkill() end)
HL:On("PLAYER_ENTERING_WORLD", function() Tracker:CheckSkill() end)

---------------------------------------------------------------------------
-- Reporting
---------------------------------------------------------------------------
local function sortedItems(map)
    local list = {}
    for id, v in pairs(map) do
        if type(v) == "table" then
            list[#list + 1] = { id = id, count = v.count, link = v.link }
        else
            list[#list + 1] = { id = id, count = v }
        end
    end
    table.sort(list, function(a, b) return a.count > b.count end)
    return list
end
Tracker.SortedItems = sortedItems

function Tracker:CatchesPerHour()
    local s = self.session
    if not s.started then return 0 end
    local hours = (GetTime() - s.started) / 3600
    if hours < 1 / 60 then return 0 end
    return s.catches / hours
end

local function itemLabel(entry)
    if entry.link then return entry.link end
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(entry.id)
    return name or ("item:" .. entry.id)
end

function Tracker:PrintSession()
    local s = self.session
    local rate = s.casts > 0 and (100 * s.catches / s.casts) or 0
    HL:Print("Session: %d casts, %d catches (%.0f%%), %d got away, %.0f/hr",
        s.casts, s.catches, rate, s.escaped, self:CatchesPerHour())
    local rank, maxRank = self:GetFishingSkill()
    if rank then
        HL:Print("Skill: %d/%d%s", rank, maxRank or 0,
            s.skillStart and rank > s.skillStart and string.format(" (+%d this session)", rank - s.skillStart) or "")
    end
    for i, e in ipairs(sortedItems(s.items)) do
        if i > 10 then break end
        HL:Print("  %dx %s", e.count, itemLabel(e))
    end
end

function Tracker:PrintZone()
    local zone = zoneNames()
    local z = HL.db.lifetime.zones[zone]
    if not z or z.catches == 0 then return HL:Print("No catches recorded in %s yet", zone) end
    HL:Print("%s (lifetime): %d catches from %d casts", zone, z.catches, z.casts)
    for i, e in ipairs(sortedItems(z.items)) do
        if i > 10 then break end
        HL:Print("  %dx %s (%.0f%%)", e.count, itemLabel(e), 100 * e.count / z.catches)
    end
end

HL:Command("stats", "[reset] - session fishing stats", function(arg)
    if arg == "reset" then
        Tracker:NewSession()
        return HL:Print("session reset")
    end
    Tracker:PrintSession()
end)
HL:Command("zone", "- lifetime catches in this zone", function() Tracker:PrintZone() end)
