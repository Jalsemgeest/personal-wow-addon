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

-- The command shown in Game Menu > Key Bindings > AddOns > Syl's Tools (Bindings.xml).
OneButton.GAME_BINDING = "CLICK SylsToolsFishingCastButton:LeftButton"

local owner = CreateFrame("Frame", "SylsToolsFishingBindingOwner", UIParent)
local softStash = ST:NewCVarStash()

-- Created at load so the Key Bindings entry works from the first frame.
local castButton = CreateFrame("Button", "SylsToolsFishingCastButton", UIParent, "SecureActionButtonTemplate")
castButton:SetSize(1, 1)
castButton:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 100) -- off-screen; used via key bindings only
castButton:RegisterForClicks("AnyUp", "AnyDown")
castButton:SetAttribute("type", "spell")
castButton:SetAttribute("spell", "Fishing")

local function updateSpell()
    if not API.InCombat() then castButton:SetAttribute("spell", F:SpellName()) end
end

-- Keys bound to "Fishing: Cast / Reel" in the game's own Key Bindings menu.
function OneButton:GameKeys()
    if not GetBindingKey then return {} end
    return { GetBindingKey(self.GAME_BINDING) }
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

-- Apply override bindings for the current state. Out of combat only.
--   not fishing: the Syl's Tools key (if fishing mode is on) clicks the cast button.
--                Game-menu keys already click it through their normal binding.
--   fishing:     the Syl's Tools key AND the game-menu keys become INTERACTTARGET (reel).
local function applyBindings()
    if API.InCombat() then return end
    local fishing = F.State:IsFishing()
    local custom = OneButton.active and F.cdb.key or nil
    local keys = {}
    if custom then keys[#keys + 1] = custom end
    if fishing then
        for _, k in ipairs(OneButton:GameKeys()) do
            if k ~= custom then keys[#keys + 1] = k end
        end
    end
    local signature = (fishing and "reel:" or "cast:") .. table.concat(keys, ",")
    if OneButton.boundAs == signature then return end
    ClearOverrideBindings(owner)
    if fishing then
        for _, k in ipairs(keys) do SetOverrideBinding(owner, true, k, "INTERACTTARGET") end
    elseif custom then
        updateSpell()
        SetOverrideBindingClick(owner, true, custom, "SylsToolsFishingCastButton", "LeftButton")
    end
    OneButton.boundAs = signature
end

function OneButton:UpdateSoftTarget()
    applySoftTarget(self.active)
end

function OneButton:Refresh()
    if API.InCombat() then return end -- PLAYER_REGEN_ENABLED will call us again
    updateSpell()
    local want = self:WantActive()
    if want and not self.active then applySoftTarget(true) end
    if not want and self.active then applySoftTarget(false) end
    self.active = want and true or false
    applyBindings()
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
ST:On("ST_FISHING_START", applyBindings)
ST:On("ST_FISHING_STOP", applyBindings)
ST:On("UPDATE_BINDINGS", function() OneButton.boundAs = nil; applyBindings() end)
ST:On("SPELLS_CHANGED", updateSpell)
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
