-- Syl's Tools > Fishing: state machine
-- Watches the player's Fishing channel and broadcasts internal messages:
--   ST_FISHING_START (startTime, endTime)   -- seconds, GetTime() clock
--   ST_FISHING_STOP  (reason)               -- "expired" | "ended"
--   ST_FISH_ESCAPED  ()
-- This file only *observes*; it never casts or interacts.

local _, ns = ...
local ST = (ns and ns.ST) or SylsTools
local F = ns.Fishing
local API = ST.API

local State = {
    channeling = false,
    startTime = nil,
    endTime = nil,
    lastStop = 0,      -- GetTime() of the last channel stop
    lastStopReason = nil,
}
F.State = State

local function readChannel()
    if not UnitChannelInfo then return end
    local name, _, _, startMS, endMS, _, _, spellID = UnitChannelInfo("player")
    if API.IsSecret(name) or API.IsSecret(startMS) then return end
    if not name then return end
    return name, startMS and startMS / 1000, endMS and endMS / 1000, spellID
end

function State:IsFishing() return self.channeling end

function State:Remaining()
    if not self.channeling or not self.endTime then return 0 end
    return math.max(0, self.endTime - GetTime())
end

function State:Duration()
    if not (self.startTime and self.endTime) then return 0 end
    return self.endTime - self.startTime
end

ST:On("UNIT_SPELLCAST_CHANNEL_START", function(_, unit, _, spellID)
    if unit ~= "player" then return end
    local name, startT, endT, chSpellID = readChannel()
    if not F:IsFishingSpell(spellID or chSpellID, name) then return end
    State.channeling = true
    State.startTime = startT or GetTime()
    State.endTime = endT or (State.startTime + 20)
    ST:Fire("ST_FISHING_START", State.startTime, State.endTime)
end)

ST:On("UNIT_SPELLCAST_CHANNEL_STOP", function(_, unit)
    if unit ~= "player" or not State.channeling then return end
    local now = GetTime()
    -- If we reached (nearly) the end of the channel, nothing was reeled in.
    local reason = (State.endTime and now >= State.endTime - 0.35) and "expired" or "ended"
    State.channeling = false
    State.lastStop = now
    State.lastStopReason = reason
    ST:Fire("ST_FISHING_STOP", reason)
end)

-- "Your fish got away!" comes through the errors frame.
local function onUIMessage(_, _, message)
    if type(message) ~= "string" or API.IsSecret(message) then return end
    if ERR_FISH_ESCAPED and message == ERR_FISH_ESCAPED then
        ST:Fire("ST_FISH_ESCAPED")
    end
end
ST:On("UI_ERROR_MESSAGE", onUIMessage)
ST:On("UI_INFO_MESSAGE", onUIMessage)
