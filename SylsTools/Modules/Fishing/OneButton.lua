-- Syl's Tools > Fishing: One-key cast & reel
--
-- One key the player chooses. While "fishing mode" is on:
--   * not fishing -> the key clicks a secure button that casts Fishing   (1 press = 1 cast)
--   * fishing     -> the key is bound to INTERACTTARGET (soft-targeted bobber)
--                    (1 press = 1 interaction)
-- The addon only decides WHICH action a key performs; the player decides WHEN.
-- Bindings and secure attributes can only change out of combat, so in combat
-- the overrides are dropped and the key reverts to its normal binding.

local _, ns = ...
local ST = (ns and ns.ST) or SylsTools
local F = ns.Fishing
local API = ST.API

local OneButton = { active = false, boundAs = nil }
F.OneButton = OneButton

local owner = CreateFrame("Frame", "SylsToolsFishingBindingOwner", UIParent)
local castButton
local softStash = ST:NewCVarStash()

local function buildButton()
    if castButton then return castButton end
    castButton = CreateFrame("Button", "SylsToolsFishingCastButton", UIParent, "SecureActionButtonTemplate")
    castButton:SetSize(1, 1)
    castButton:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 100) -- off-screen; used via binding only
    castButton:RegisterForClicks("AnyUp", "AnyDown")
    castButton:SetAttribute("type", "spell")
    return castButton
end


function OneButton:WantActive()
    local c = F.cdb
    if not c or not c.key then return false end
    if c.modeManual then return true end
    return c.modeAuto and F:PoleEquipped()
end

function OneButton:IsActive() return self.active end

local function applySoftTarget(on)
    if on and F.db.softTarget then
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
    local key = F.cdb.key
    if API.InCombat() or not key then return end
    if OneButton.boundAs == as then return end
    ClearOverrideBindings(owner)
    if as == "cast" then
        buildButton():SetAttribute("spell", F:SpellName())
        SetOverrideBindingClick(owner, true, key, "SylsToolsFishingCastButton", "LeftButton")
    elseif as == "reel" then
        SetOverrideBinding(owner, true, key, "INTERACTTARGET")
    end
    OneButton.boundAs = as
end

function OneButton:UpdateSoftTarget()
    applySoftTarget(self.active)
end

function OneButton:Refresh()
    if API.InCombat() then return end -- PLAYER_REGEN_ENABLED will call us again
    local want = self:WantActive()
    if want then
        if not self.active then applySoftTarget(true) end
        self.active = true
        bind(F.State:IsFishing() and "reel" or "cast")
    elseif self.active then
        self.active = false
        clearBindings()
        applySoftTarget(false)
    end
    ST:Fire("ST_MODE_CHANGED", self.active)
end

ST:On("ST_READY", function() OneButton:Refresh() end)
ST:On("PLAYER_ENTERING_WORLD", function() OneButton:Refresh() end)
ST:On("PLAYER_EQUIPMENT_CHANGED", function(_, slot)
    if slot == 16 or slot == 17 or slot == nil then OneButton:Refresh() end
end)
ST:On("PLAYER_REGEN_DISABLED", function()
    -- Entering combat: give the key back immediately. ClearOverrideBindings is
    -- still allowed at this point (lockdown begins after this event).
    if OneButton.active then clearBindings() end
end)
ST:On("PLAYER_REGEN_ENABLED", function()
    OneButton.boundAs = nil
    OneButton:Refresh()
end)
ST:On("ST_FISHING_START", function()
    if OneButton.active then bind("reel") end
end)
ST:On("ST_FISHING_STOP", function()
    if OneButton.active then bind("cast") end
end)
ST:On("PLAYER_LOGOUT", function() applySoftTarget(false) end)

-- Returns true on success. key = nil/"" clears it.
function OneButton:SetKey(key)
    if API.InCombat() then
        ST:Print("can't change keys in combat")
        return false
    end
    key = key and key:upper() or nil
    if key == "" or key == "NONE" then key = nil end
    clearBindings()
    F.cdb.key = key
    self:Refresh()
    return true
end

function OneButton:SetForced(on)
    if API.InCombat() then
        ST:Print("can't change modes in combat")
        return false
    end
    F.cdb.modeManual = on and true or false
    self:Refresh()
    return true
end

F:Command("key", "<KEY> - set the one-key cast & reel key (e.g. F, BUTTON4). 'none' to clear", function(arg)
    if not arg or arg == "" then
        return ST:Print("current key: %s", F.cdb.key or "none")
    end
    if OneButton:SetKey(arg) then
        ST:Print("one-key fishing key: %s", F.cdb.key or "none")
    end
end)

F:Command("mode", "- force fishing mode on/off (normally follows your equipped pole)", function()
    if OneButton:SetForced(not F.cdb.modeManual) then
        ST:Print("Forced fishing mode: %s", F.cdb.modeManual and "on" or "off")
    end
end)
