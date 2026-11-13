-- HookLine: Weapon swap
-- /hl gear toggles between your fishing pole and the weapons you had on.
-- Runs only on an explicit player command, out of combat.

local _, ns = ...
local HL = (ns and ns.HL) or HookLine
local API = HL.API

local Gear = {}
HL.Gear = Gear

local MAIN, OFF = 16, 17

local function bestPoleInBags()
    local best, bestLvl
    for bag = 0, 4 do
        for slot = 1, (API.GetContainerNumSlots(bag) or 0) do
            local link = API.GetContainerItemLink(bag, slot)
            if link and API.IsFishingPole(link) then
                local lvl = API.GetItemLevel(link)
                if not best or lvl > bestLvl then best, bestLvl = link, lvl end
            end
        end
    end
    return best
end
Gear.BestPoleInBags = bestPoleInBags

function Gear:EquipPole()
    if API.InCombat() then return HL:Print("can't swap gear in combat") end
    local main = GetInventoryItemLink("player", MAIN)
    if main and API.IsFishingPole(main) then return HL:Print("fishing pole already equipped") end
    local pole = bestPoleInBags()
    if not pole then return HL:Print("no fishing pole found in your bags") end
    HL.cdb.savedWeapons = {
        [MAIN] = main,
        [OFF] = GetInventoryItemLink("player", OFF),
    }
    API.EquipItem(pole, MAIN)
    HL:Print("equipped %s", pole)
end

function Gear:RestoreWeapons()
    if API.InCombat() then return HL:Print("can't swap gear in combat") end
    local saved = HL.cdb.savedWeapons
    if not saved or not saved[MAIN] then
        return HL:Print("no saved weapons to restore")
    end
    API.EquipItem(saved[MAIN], MAIN)
    if saved[OFF] then
        -- Off-hand must go on after the main hand (two-handed pole occupies both).
        if C_Timer and C_Timer.After then
            C_Timer.After(0.3, function()
                if not API.InCombat() then API.EquipItem(saved[OFF], OFF) end
            end)
        else
            API.EquipItem(saved[OFF], OFF)
        end
    end
    HL:Print("restored %s%s", saved[MAIN], saved[OFF] and (" + " .. saved[OFF]) or "")
    HL.cdb.savedWeapons = nil
end

function Gear:Toggle()
    local main = GetInventoryItemLink("player", MAIN)
    if main and API.IsFishingPole(main) then
        self:RestoreWeapons()
    else
        self:EquipPole()
    end
end

HL:Command("gear", "- swap between your fishing pole and your weapons", function()
    Gear:Toggle()
end)
