-- Syl's Tools > Fishing: Weapon swap
--
-- * Remembers your weapons automatically: whenever your main hand is NOT a
--   fishing pole, the current main/off hand are recorded as "your weapons".
--   So it works whether you equip the pole with Syl's Tools or by hand.
-- * Equip Pole: equips the best fishing pole in your bags.
-- * Restore: re-equips your recorded weapons.
-- * Auto-restore: after you stop fishing and stay idle for `restoreDelay`
--   seconds, your weapons go back on. Casting again cancels the countdown.
--   If you're in combat when it's due, it happens as soon as combat ends.
-- Equipping is done out of combat only. This is gear management (like
-- ItemRack/Outfitter), not gameplay automation.

local _, ns = ...
local ST = (ns and ns.ST) or SylsTools
local F = ns.Fishing
local API = ST.API

local Gear = { restoreAt = nil, pendingAfterCombat = false }
F.Gear = Gear

local MAIN, OFF = 16, 17
Gear.MAIN, Gear.OFF = MAIN, OFF

local timer

local function changed() ST:Fire("ST_GEAR_CHANGED") end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------
local poleCache, poleCacheValid = nil, false
ST:On("BAG_UPDATE_DELAYED", function() poleCacheValid = false end)

function Gear:BestPole()
    if poleCacheValid then return poleCache end
    local best, bestLvl
    for bag = 0, 4 do
        for slot = 1, (API.GetContainerNumSlots(bag) or 0) do
            local link = API.GetContainerItemLink(bag, slot)
            if link and F:IsPole(link) then
                local lvl = API.GetItemLevel(link)
                if not best or lvl > bestLvl then best, bestLvl = link, lvl end
            end
        end
    end
    poleCache, poleCacheValid = best, true
    return best
end

-- The pole currently equipped, or the best one in your bags.
function Gear:Pole()
    local main = GetInventoryItemLink("player", MAIN)
    if main and F:IsPole(main) then return main, true end
    return self:BestPole(), false
end

function Gear:Saved()
    local s = F.cdb.savedWeapons
    if not s then return nil, nil end
    return s[MAIN], s[OFF]
end

-- Seconds until auto-restore, or nil if none is scheduled.
function Gear:RestoreRemaining()
    if self.pendingAfterCombat then return 0 end
    if not self.restoreAt then return nil end
    return math.max(0, self.restoreAt - GetTime())
end

---------------------------------------------------------------------------
-- Tracking your weapons
---------------------------------------------------------------------------
function Gear:Snapshot()
    local main = GetInventoryItemLink("player", MAIN)
    if not main or F:IsPole(main) then return end
    local off = GetInventoryItemLink("player", OFF)
    local s = F.cdb.savedWeapons
    if s and s[MAIN] == main and s[OFF] == off then return end
    F.cdb.savedWeapons = { [MAIN] = main, [OFF] = off }
    changed()
end

---------------------------------------------------------------------------
-- Auto-restore scheduling
---------------------------------------------------------------------------
function Gear:CancelRestore()
    if timer then timer:Cancel() timer = nil end
    local had = self.restoreAt or self.pendingAfterCombat
    self.restoreAt, self.pendingAfterCombat = nil, false
    if had then changed() end
end

function Gear:ScheduleRestore()
    self:CancelRestore()
    if not F.cdb.autoRestore or not F:PoleEquipped() or not self:Saved() then return end
    local delay = F.cdb.restoreDelay or 60
    self.restoreAt = GetTime() + delay
    timer = API.After(delay, function()
        timer = nil
        Gear.restoreAt = nil
        Gear:AutoRestore()
    end)
    changed()
end

function Gear:AutoRestore()
    if F.State:IsFishing() or not F:PoleEquipped() then return changed() end
    if API.InCombat() then
        self.pendingAfterCombat = true
        return changed()
    end
    self.pendingAfterCombat = false
    ST:Print("done fishing - re-equipping your weapons")
    self:Restore()
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
function Gear:EquipPole()
    if API.InCombat() then return ST:Print("can't swap gear in combat") end
    local pole, equipped = self:Pole()
    if equipped then return ST:Print("fishing pole already equipped") end
    if not pole then return ST:Print("no fishing pole found in your bags") end
    self:Snapshot()
    self:CancelRestore()
    API.EquipItem(pole, MAIN)
    ST:Print("equipped %s", pole)
end

function Gear:Restore()
    if API.InCombat() then return ST:Print("can't swap gear in combat") end
    local main, off = self:Saved()
    if not main then return ST:Print("no saved weapons to restore") end
    self:CancelRestore()
    if API.GetItemCount(main) == 0 and GetInventoryItemLink("player", MAIN) ~= main then
        return ST:Print("couldn't find %s in your bags", main)
    end
    API.EquipItem(main, MAIN)
    if off then
        -- Off hand goes on after the main hand (a two-handed pole fills both slots).
        API.After(0.3, function()
            if not API.InCombat() then API.EquipItem(off, OFF) end
        end)
    end
    ST:Print("re-equipped %s%s", main, off and (" + " .. off) or "")
end

function Gear:Toggle()
    if F:PoleEquipped() then self:Restore() else self:EquipPole() end
end

function Gear:SetAutoRestore(on)
    F.cdb.autoRestore = on and true or false
    if not on then self:CancelRestore() end
    changed()
end

function Gear:SetDelay(seconds)
    seconds = math.floor(math.max(10, math.min(600, seconds)))
    F.cdb.restoreDelay = seconds
    if self.restoreAt then self:ScheduleRestore() end
    changed()
    return seconds
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
ST:On("PLAYER_EQUIPMENT_CHANGED", function(_, slot)
    if slot ~= MAIN and slot ~= OFF and slot ~= nil then return end
    poleCacheValid = false -- a pole may have moved between bags and hands
    Gear:Snapshot()
    if not F:PoleEquipped() then Gear:CancelRestore() end
    changed()
end)
ST:On("PLAYER_ENTERING_WORLD", function() Gear:Snapshot() end)
ST:On("ST_FISHING_START", function() Gear:CancelRestore() end)
ST:On("ST_FISHING_STOP", function() Gear:ScheduleRestore() end)
ST:On("PLAYER_REGEN_ENABLED", function()
    if Gear.pendingAfterCombat then Gear:AutoRestore() end
end)

F:Command("gear", "- swap between your fishing pole and your weapons", function()
    Gear:Toggle()
end)
F:Command("autorestore", "[seconds|off] - re-equip weapons after you stop fishing", function(arg)
    if arg == "off" then
        Gear:SetAutoRestore(false)
        return ST:Print("auto-restore off")
    end
    local n = tonumber(arg)
    Gear:SetAutoRestore(true)
    if n then n = Gear:SetDelay(n) end
    ST:Print("auto-restore on: weapons return %ds after you stop fishing", F.cdb.restoreDelay)
end)
