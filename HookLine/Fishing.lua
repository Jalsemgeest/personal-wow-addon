-- HookLine: Fishing state machine
-- Watches the player's Fishing channel and broadcasts internal messages:
--   HL_FISHING_START (startTime, endTime)   -- seconds, GetTime() clock
--   HL_FISHING_STOP  (reason)               -- "expired" | "ended"
--   HL_FISH_ESCAPED  ()
-- This module only *observes*; it never casts or interacts.

local _, ns = ...
local HL = (ns and ns.HL) or HookLine
local API = HL.API

local Fishing = {
    channeling = false,
    startTime = nil,
    endTime = nil,
    lastStop = 0,      -- GetTime() of the last channel stop
    lastStopReason = nil,
}
HL.Fishing = Fishing

local function isSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

local function readChannel()
    if not UnitChannelInfo then return end
    local name, _, _, startMS, endMS, _, _, spellID = UnitChannelInfo("player")
    if isSecret(name) or isSecret(startMS) then return end
    if not name then return end
    return name, startMS and startMS / 1000, endMS and endMS / 1000, spellID
end

function Fishing:IsFishing() return self.channeling end

function Fishing:Remaining()
    if not self.channeling or not self.endTime then return 0 end
    return math.max(0, self.endTime - GetTime())
end

function Fishing:Duration()
    if not (self.startTime and self.endTime) then return 0 end
    return self.endTime - self.startTime
end

HL:On("UNIT_SPELLCAST_CHANNEL_START", function(_, unit, _, spellID)
    if unit ~= "player" then return end
    local name, startT, endT, chSpellID = readChannel()
    if not API.IsFishingSpell(spellID or chSpellID, name) then return end
    Fishing.channeling = true
    Fishing.startTime = startT or GetTime()
    Fishing.endTime = endT or (Fishing.startTime + 20)
    HL:Fire("HL_FISHING_START", Fishing.startTime, Fishing.endTime)
end)

HL:On("UNIT_SPELLCAST_CHANNEL_STOP", function(_, unit)
    if unit ~= "player" or not Fishing.channeling then return end
    local now = GetTime()
    -- If we reached (nearly) the end of the channel, nothing was reeled in.
    local reason = (Fishing.endTime and now >= Fishing.endTime - 0.35) and "expired" or "ended"
    Fishing.channeling = false
    Fishing.lastStop = now
    Fishing.lastStopReason = reason
    HL:Fire("HL_FISHING_STOP", reason)
end)

-- "Your fish got away!" / "No fish are hooked." come through the errors frame.
local function onUIMessage(_, _, message)
    if type(message) ~= "string" or isSecret(message) then return end
    if ERR_FISH_ESCAPED and message == ERR_FISH_ESCAPED then
        HL:Fire("HL_FISH_ESCAPED")
    end
end
HL:On("UI_ERROR_MESSAGE", onUIMessage)
HL:On("UI_INFO_MESSAGE", onUIMessage)
