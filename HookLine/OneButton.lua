-- HookLine: One-key cast & reel
--
-- One key the player chooses. While "fishing mode" is on:
--   * not fishing -> the key clicks a secure button that casts Fishing   (1 press = 1 cast)
--   * fishing     -> the key is bound to INTERACTTARGET (soft-targeted bobber)
--                    (1 press = 1 interaction)
-- The addon only decides WHICH action a key performs; the player decides WHEN.
-- Bindings and secure attributes can only change out of combat, so in combat
-- the overrides are dropped and the key reverts to its normal binding.

local _, ns = ...
local HL = (ns and ns.HL) or HookLine
local API = HL.API

local OneButton = { active = false, boundAs = nil }
HL.OneButton = OneButton

local owner = CreateFrame("Frame", "HookLineBindingOwner", UIParent)
local castButton
local softStash = HL:NewCVarStash()

local function buildButton()
    if castButton then return castButton end
    castButton = CreateFrame("Button", "HookLineCastButton", UIParent, "SecureActionButtonTemplate")
    castButton:SetSize(1, 1)
    castButton:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 100) -- off-screen; used via binding only
    castButton:RegisterForClicks("AnyUp", "AnyDown")
    castButton:SetAttribute("type", "spell")
    return castButton
end

local function poleEquipped()
    local link = GetInventoryItemLink and GetInventoryItemLink("player", 16)
    return link and API.IsFishingPole(link) or false
end
OneButton.PoleEquipped = poleEquipped

function OneButton:WantActive()
    local c = HL.cdb
    if not c or not c.key then return false end
    if c.modeManual then return true end
    return c.modeAuto and poleEquipped()
end

function OneButton:IsActive() return self.active end

local function applySoftTarget(on)
    if not HL.db.softTarget then return end
    if on then
        softStash:Set("SoftTargetInteract", 3)       -- always soft-target interactables
        softStash:Set("SoftTargetInteractArc", 2)    -- wide arc
        softStash:Set("SoftTargetInteractRange", 30) -- reach the bobber
        softStash:Set("SoftTargetIconGameObject", 1) -- icon over the bobber
        softStash:Set("SoftTargetIconInteract", 1)
    else
        softStash:Restore()
    end
end

local function clearBindings()
    ClearOverrideBindings(owner)
    OneButton.boundAs = nil
end

-- Bind the key to "cast" or "reel". Out of combat only.
local function bind(as)
    local key = HL.cdb.key
    if API.InCombat() or not key then return end
    if OneButton.boundAs == as then return end
    ClearOverrideBindings(owner)
    if as == "cast" then
        buildButton():SetAttribute("spell", API.FishingSpellName())
        SetOverrideBindingClick(owner, true, key, "HookLineCastButton", "LeftButton")
    elseif as == "reel" then
        SetOverrideBinding(owner, true, key, "INTERACTTARGET")
    end
    OneButton.boundAs = as
end

function OneButton:Refresh()
    if API.InCombat() then return end -- PLAYER_REGEN_ENABLED will call us again
    local want = self:WantActive()
    if want then
        if not self.active then applySoftTarget(true) end
        self.active = true
        bind(HL.Fishing:IsFishing() and "reel" or "cast")
    elseif self.active then
        self.active = false
        clearBindings()
        applySoftTarget(false)
    end
    HL:Fire("HL_MODE_CHANGED", self.active)
end

HL:On("HL_READY", function() OneButton:Refresh() end)
HL:On("PLAYER_ENTERING_WORLD", function() OneButton:Refresh() end)
HL:On("PLAYER_EQUIPMENT_CHANGED", function(_, slot)
    if slot == 16 or slot == 17 or slot == nil then OneButton:Refresh() end
end)
HL:On("PLAYER_REGEN_DISABLED", function()
    -- Entering combat: give the key back immediately. ClearOverrideBindings is
    -- still allowed at this point (lockdown begins after this event).
    if OneButton.active then clearBindings() end
end)
HL:On("PLAYER_REGEN_ENABLED", function()
    OneButton.boundAs = nil
    OneButton:Refresh()
end)
HL:On("HL_FISHING_START", function()
    if OneButton.active then bind("reel") end
end)
HL:On("HL_FISHING_STOP", function()
    if OneButton.active then bind("cast") end
end)
HL:On("PLAYER_LOGOUT", function() applySoftTarget(false) end)

HL:Command("key", "<KEY> - set the one-key cast & reel key (e.g. F, BUTTON4). 'none' to clear", function(arg)
    if API.InCombat() then return HL:Print("can't change keys in combat") end
    arg = (arg or ""):upper()
    if arg == "" then
        return HL:Print("current key: %s", HL.cdb.key or "none")
    end
    clearBindings()
    HL.cdb.key = (arg ~= "NONE") and arg or nil
    HL:Print("one-key fishing key: %s", HL.cdb.key or "none")
    OneButton:Refresh()
end)

HL:Command("mode", "- force fishing mode on/off (normally follows your equipped pole)", function()
    if API.InCombat() then return HL:Print("can't change modes in combat") end
    HL:ToggleSetting(HL.cdb, "modeManual", "Forced fishing mode")
    OneButton:Refresh()
end)
