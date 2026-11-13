-- Syl's Tools > Fishing: Alert / HUD
-- * Large "watch the bobber" HUD with a cast countdown while fishing.
-- * Full-screen flash (Alert:Flash) for "recast" and, if one is found, a bite signal.
-- * Splash-sound focus: louder SFX, quieter music, sound in background. Restored after.
-- * Event probe: logs every client event during a Fishing channel so we can learn
--   whether the client emits anything at bite time (DESIGN.md section 3, tier C).
-- Nothing here performs a game action.

local _, ns = ...
local ST = (ns and ns.ST) or SylsTools
local F = ns.Fishing

local Alert = {}
F.Alert = Alert

local soundStash = ST:NewCVarStash()
local restoreToken = 0
local SOUND_RESTORE_DELAY = 30 -- seconds idle before restoring sound settings

---------------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------------
local hud, bar, title, sub, timeText

local function keyLabel()
    local key = F.cdb and F.cdb.key
    if key and F.OneButton and F.OneButton:IsActive() then return key end
    local bound = GetBindingKey and GetBindingKey("INTERACTTARGET")
    return bound or "Interact"
end

local function buildHUD()
    if hud then return end
    hud = CreateFrame("Frame", "SylsToolsFishingHUD", UIParent)
    hud:SetSize(420, 96)
    hud:SetFrameStrata("HIGH")
    hud:SetClampedToScreen(true)
    hud:SetMovable(true)
    hud:EnableMouse(false)
    hud:RegisterForDrag("LeftButton")
    hud:SetScript("OnDragStart", hud.StartMoving)
    hud:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        F.db.alert.point = { point, "UIParent", relPoint, x, y }
    end)

    local bg = hud:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.55)

    title = hud:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("WATCH THE BOBBER")

    sub = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    sub:SetPoint("TOP", title, "BOTTOM", 0, -6)

    bar = CreateFrame("StatusBar", nil, hud)
    bar:SetPoint("BOTTOMLEFT", 12, 10)
    bar:SetPoint("BOTTOMRIGHT", -12, 10)
    bar:SetHeight(14)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.2, 0.8, 1.0)
    bar:SetMinMaxValues(0, 1)

    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetColorTexture(1, 1, 1, 0.12)

    timeText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeText:SetPoint("CENTER")

    hud:SetScript("OnUpdate", function()
        local F = F.State
        local dur = F:Duration()
        local rem = F:Remaining()
        bar:SetValue(dur > 0 and rem / dur or 0)
        timeText:SetFormattedText("%.1fs", rem)
    end)
    hud:Hide()
end

function Alert:ApplyPosition()
    if not hud then return end
    local p = F.db.alert.point
    hud:ClearAllPoints()
    hud:SetPoint(p[1], UIParent, p[3], p[4], p[5])
    hud:SetScale(F.db.alert.scale or 1)
end

function Alert:ShowHUD()
    if not F.db.alert.enabled then return end
    buildHUD()
    self:ApplyPosition()
    sub:SetFormattedText("Press |cffffd100%s|r when it splashes", keyLabel())
    hud:Show()
end

function Alert:HideHUD()
    if hud and not self.unlocked then hud:Hide() end
end

function Alert:ToggleUnlock()
    buildHUD()
    self.unlocked = not self.unlocked
    hud:EnableMouse(self.unlocked)
    if self.unlocked then
        self:ApplyPosition()
        sub:SetText("Drag me, then /syl fishing move again")
        hud:Show()
    else
        hud:Hide()
    end
    ST:Print("HUD %s", self.unlocked and "unlocked" or "locked")
end

---------------------------------------------------------------------------
-- Full-screen flash
---------------------------------------------------------------------------
local flash, flashText
local FLASH_TIME = 1.2

function Alert:Flash(text, r, g, b)
    if not flash then
        flash = CreateFrame("Frame", "SylsToolsFlash", UIParent)
        flash:SetAllPoints(UIParent)
        flash:SetFrameStrata("FULLSCREEN_DIALOG")
        flash:EnableMouse(false)
        flash.tex = flash:CreateTexture(nil, "BACKGROUND")
        flash.tex:SetAllPoints()
        flash.tex:SetTexture("Interface\\FullScreenTextures\\LowHealth")
        flash.tex:SetBlendMode("ADD")
        flashText = flash:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        flashText:SetPoint("CENTER", 0, 120)
        flashText:SetScale(2.5)
        flash:SetScript("OnUpdate", function(self, elapsed)
            self.t = self.t + elapsed
            local p = self.t / FLASH_TIME
            if p >= 1 then self:Hide() return end
            -- two pulses
            self:SetAlpha(math.abs(math.sin(p * math.pi * 2)))
        end)
    end
    flash.tex:SetVertexColor(r or 0.2, g or 0.8, b or 1.0)
    flashText:SetText(text or "")
    flash.t = 0
    flash:Show()
end

-- Hook for a future in-client bite signal (DESIGN.md section 3, tier C).
function Alert:Bite()
    self:Flash("REEL IN!", 0.2, 1.0, 0.3)
end

---------------------------------------------------------------------------
-- Sound focus
---------------------------------------------------------------------------
function Alert:FocusSound()
    local s = F.db.sound
    if not s.focus then return end
    restoreToken = restoreToken + 1
    soundStash:Set("Sound_EnableAllSound", 1)
    soundStash:Set("Sound_EnableSFX", 1)
    soundStash:Set("Sound_MasterVolume", s.master)
    soundStash:Set("Sound_SFXVolume", s.sfx)
    soundStash:Set("Sound_MusicVolume", s.music)
    soundStash:Set("Sound_AmbienceVolume", s.ambience)
    if s.background then soundStash:Set("Sound_EnableSoundWhenGameIsInBG", 1) end
end

function Alert:RestoreSound()
    soundStash:Restore()
end

local function scheduleSoundRestore()
    if not soundStash:IsActive() then return end
    restoreToken = restoreToken + 1
    local token = restoreToken
    if C_Timer and C_Timer.After then
        C_Timer.After(SOUND_RESTORE_DELAY, function()
            if token == restoreToken and not F.State:IsFishing() then
                Alert:RestoreSound()
            end
        end)
    else
        Alert:RestoreSound()
    end
end

---------------------------------------------------------------------------
-- Event probe
---------------------------------------------------------------------------
local probe
local PROBE_IGNORE = {
    -- extremely chatty, never fishing-related
    COMBAT_LOG_EVENT_UNFILTERED = true, UPDATE_MOUSEOVER_UNIT = true,
    CURSOR_CHANGED = true, MODIFIER_STATE_CHANGED = true,
    UNIT_POWER_FREQUENT = true, UNIT_POWER_UPDATE = true,
    CHAT_MSG_CHANNEL = true, CHAT_MSG_ADDON = true, CHAT_MSG_ADDON_LOGGED = true,
    WORLD_CURSOR_TOOLTIP_UPDATE = true,
}

local function argString(...)
    local out = {}
    for i = 1, math.min(select("#", ...), 5) do
        local v = select(i, ...)
        if issecretvalue and issecretvalue(v) then v = "<secret>" end
        out[#out + 1] = tostring(v)
    end
    return table.concat(out, ", ")
end

local function probeStart()
    if not F.db.probe then return end
    if not probe then
        probe = CreateFrame("Frame")
        probe:SetScript("OnEvent", function(self, event, ...)
            if PROBE_IGNORE[event] then return end
            local t = GetTime() - (F.State.startTime or GetTime())
            local line = string.format("+%.2fs %s (%s)", t, event, argString(...))
            table.insert(F.db.probeLog, line)
            if #F.db.probeLog > 2000 then table.remove(F.db.probeLog, 1) end
            ST:Print("|cff999999probe|r %s", line)
        end)
    end
    F.db.probeLog = F.db.probeLog or {}
    table.insert(F.db.probeLog, "---- cast at " .. date("%H:%M:%S") .. " ----")
    probe:RegisterAllEvents()
end

local function probeStop()
    if probe then probe:UnregisterAllEvents() end
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------
ST:On("ST_FISHING_START", function()
    Alert:ShowHUD()
    Alert:FocusSound()
    probeStart()
end)

ST:On("ST_FISHING_STOP", function(_, reason)
    Alert:HideHUD()
    probeStop()
    if reason == "expired" and F.db.alert.flashOnExpire then
        Alert:Flash("Recast!", 1.0, 0.8, 0.2)
    end
    scheduleSoundRestore()
end)

ST:On("ST_FISH_ESCAPED", function()
    Alert:Flash("Got away...", 1.0, 0.3, 0.3)
end)

ST:On("PLAYER_LOGOUT", function()
    -- never leave a player's sound settings modified
    Alert:RestoreSound()
end)

F:Command("hud", "- toggle the fishing HUD", function()
    ST:ToggleSetting(F.db.alert, "enabled", "Fishing HUD")
end)
F:Command("move", "- unlock/lock the HUD to drag it", function()
    Alert:ToggleUnlock()
end)
F:Command("scale", "<0.5-2> - HUD scale", function(arg)
    local n = tonumber(arg)
    if not n or n < 0.5 or n > 2 then return ST:Print("usage: /hl scale 1.2") end
    F.db.alert.scale = n
    Alert:ApplyPosition()
    ST:Print("HUD scale %.2f", n)
end)
F:Command("sound", "- toggle splash-sound focus while fishing", function()
    if not ST:ToggleSetting(F.db.sound, "focus", "Sound focus") then Alert:RestoreSound() end
end)
F:Command("flash", "- preview the full-screen alert", function()
    Alert:Bite()
end)
F:Command("probe", "[clear] - toggle the bite event probe (developer tool)", function(arg)
    if arg == "clear" then
        F.db.probeLog = {}
        return ST:Print("probe log cleared")
    end
    ST:ToggleSetting(F.db, "probe", "Event probe")
    if F.db.probe then
        ST:Print("Cast, watch for the splash, and note the +time of any event near it. Log saved in SylsToolsDB.modules.fishing.probeLog.")
    end
end)
