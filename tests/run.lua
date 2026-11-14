-- Headless tests for Syl's Tools against a mocked WoW API.
-- Run from the repo root:  lua5.1 tests/run.lua

local ADDON_DIR = "SylsTools/"

---------------------------------------------------------------------------
-- Mock WoW environment
---------------------------------------------------------------------------
local W = {
    time = 1000,
    combat = false,
    cvars = {},
    overrides = {},         -- [key] = { kind = "click"|"command", target = ... }
    equipped = {},          -- [slot] = link
    bags = {},              -- [bag] = { [slot] = link }
    equipCalls = {},
    chat = {},
    channel = nil,          -- { name, startMS, endMS, spellID }
    fishingLoot = false,
    loot = {},              -- { { link, qty } }
    zone = "Elwynn Forest", subzone = "Crystal Lake",
    frames = {},
}
_G.W = W

local function stub()
    local obj = { _scripts = {}, _attrs = {}, _events = {}, _shown = false }
    local methods = {
        SetScript = function(self, name, fn) self._scripts[name] = fn end,
        GetScript = function(self, name) return self._scripts[name] end,
        RegisterEvent = function(self, e) self._events[e] = true end,
        UnregisterEvent = function(self, e) self._events[e] = nil end,
        RegisterAllEvents = function(self) self._all = true end,
        UnregisterAllEvents = function(self) self._all = false; self._events = {} end,
        SetAttribute = function(self, k, v) self._attrs[k] = v end,
        GetAttribute = function(self, k) return self._attrs[k] end,
        Show = function(self)
            if self._shown then return end
            self._shown = true
            if self._scripts.OnShow then self._scripts.OnShow(self) end
            for _, fn in ipairs(self._hooks and self._hooks.OnShow or {}) do fn(self) end
        end,
        Hide = function(self)
            if not self._shown then return end
            self._shown = false
            if self._scripts.OnHide then self._scripts.OnHide(self) end
            for _, fn in ipairs(self._hooks and self._hooks.OnHide or {}) do fn(self) end
        end,
        SetShown = function(self, v) if v then self:Show() else self:Hide() end end,
        HookScript = function(self, name, fn)
            self._hooks = self._hooks or {}
            self._hooks[name] = self._hooks[name] or {}
            table.insert(self._hooks[name], fn)
        end,
        IsShown = function(self) return self._shown end,
        GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
        SetText = function(self, t) self._text = t end,
        SetFormattedText = function(self, f, ...) self._text = string.format(f, ...) end,
        GetText = function(self) return self._text end,
        SetChecked = function(self, v) self._checked = v end,
        GetChecked = function(self) return self._checked end,
        IsKeyboardEnabled = function(self) return self._kb end,
        EnableKeyboard = function(self, v) self._kb = v end,
        Click = function(self, button) if self._scripts.OnClick then self._scripts.OnClick(self, button or "LeftButton") end end,
        CreateTexture = function() return stub() end,
        CreateFontString = function() return stub() end,
    }
    return setmetatable(obj, {
        __index = function(_, k)
            if methods[k] then return methods[k] end
            -- unknown WoW widget methods (Capitalized) are no-ops; plain fields stay nil
            if type(k) == "string" and k:match("^%u") then return function() end end
        end,
    })
end

function CreateFrame(_, name, parent, template)
    local f = stub()
    f._parent = parent
    f._name = name
    f._template = template
    table.insert(W.frames, f)
    if name then _G[name] = f end
    return f
end

function GetTime() return W.time end
function InCombatLockdown() return W.combat end
function GetCVar(name) return W.cvars[name] end
function SetCVar(name, value) W.cvars[name] = tostring(value) end
function ClearOverrideBindings() W.overrides = {} end
function SetOverrideBindingClick(_, _, key, button) W.overrides[key] = { kind = "click", target = button } end
function SetOverrideBinding(_, _, key, command) W.overrides[key] = { kind = "command", target = command } end
function GetBindingKey(command)
    if command == "CLICK SylsToolsFishingCastButton:LeftButton" and W.gameKeys then return unpack(W.gameKeys) end
end
function GetInventoryItemLink(_, slot) return W.equipped[slot] end
function UnitChannelInfo()
    local c = W.channel
    if not c then return nil end
    return c.name, "", "", c.startMS, c.endMS, true, false, c.spellID
end
function GetRealZoneText() return W.zone end
function GetSubZoneText() return W.subzone end
function IsFishingLoot() return W.fishingLoot end
function GetNumLootItems() return #W.loot end
function GetLootSlotLink(i) return W.loot[i][1] end
function GetLootSlotInfo(i) return "tex", "name", W.loot[i][2] end
function date() return "12:00:00" end
unpack = unpack or table.unpack
UIParent = stub()
-- Player / spellbook / trainer
W.class, W.level = "WARRIOR", 12
W.spellbook = {}      -- { { name, rank, id } }
W.trainer = {}        -- { { name, rank, category, level, cost } }
W.trainerFilters = { available = 1, unavailable = nil, used = nil }
W.talentPoints = { 0, 0, 5 }
function UnitClass() return W.class:sub(1, 1) .. W.class:sub(2):lower(), W.class end
function UnitLevel() return W.level end
function GetNumSpellTabs() return 1 end
function GetSpellTabInfo() return "General", "tex", 0, #W.spellbook end
function GetSpellBookItemName(slot) local e = W.spellbook[slot]; return e[1], e[2] end
function GetSpellBookItemInfo(slot) return "SPELL", W.spellbook[slot][3] end
function GetSpellTexture(id) return "icon" .. tostring(id) end
local function visibleTrainer()
    local out = {}
    for _, t in ipairs(W.trainer) do
        local cat = t[3]
        if cat == "header" or W.trainerFilters[cat] then out[#out + 1] = t end
    end
    return out
end
function GetNumTrainerServices() return #visibleTrainer() end
function GetTrainerServiceInfo(i) local t = visibleTrainer()[i]; return t[1], t[2], t[3] end
function GetTrainerServiceLevelReq(i) return visibleTrainer()[i][4] end
function GetTrainerServiceCost(i) return visibleTrainer()[i][5] end
function GetTrainerServiceIcon(i) return "tex:" .. visibleTrainer()[i][1] end
function GetTrainerServiceTypeFilter(f) return W.trainerFilters[f] end
function SetTrainerServiceTypeFilter(f, v) W.trainerFilters[f] = (v == 1) and 1 or nil end
function IsTradeskillTrainer() return W.tradeskillTrainer end
function GetNumTalentTabs() return 3 end
function GetTalentTabInfo() error("guides must not read talents") end
function time() return 1700000000 end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) table.insert(W.chat, msg) end }
ERR_FISH_ESCAPED = "Your fish got away!"
W.timers = {}
C_Timer = { After = function(delay, fn) table.insert(W.timers, { at = W.time + delay, fn = fn }) end }
-- Advance the clock, running due timers.
local function advance(seconds)
    W.time = W.time + seconds
    local due, keep = {}, {}
    for _, t in ipairs(W.timers) do
        if t.at <= W.time then due[#due + 1] = t else keep[#keep + 1] = t end
    end
    W.timers = keep
    for _, t in ipairs(due) do t.fn() end
end
local function runAllTimers()
    while #W.timers > 0 do
        local list = W.timers
        W.timers = {}
        for _, t in ipairs(list) do t.fn() end
    end
end
GameTooltip = setmetatable({}, { __index = function() return function() end end })
UISpecialFrames = {}
function IsShiftKeyDown() return W.shift end
function IsAltKeyDown() return false end
function IsControlKeyDown() return false end
C_Spell = { GetSpellName = function(id) if id == 7620 then return "Fishing" end end }
C_Container = {
    GetContainerNumSlots = function(bag) return W.bags[bag] and 16 or 0 end,
    GetContainerItemLink = function(bag, slot) return W.bags[bag] and W.bags[bag][slot] end,
}
-- Items: id 6256 = Fishing Pole (weapon/20), 6365 Strong Fishing Pole, 2000 sword, 2001 shield
local ITEMS = {
    [6256] = { 2, 20, 5 }, [6365] = { 2, 20, 15 }, [2000] = { 2, 7, 20 }, [2001] = { 4, 6, 20 },
    [6303] = { 7, 8, 1 },
}
C_Item = {
    GetItemInfoInstant = function(link)
        local id = tonumber(tostring(link):match("item:(%d+)"))
        local d = ITEMS[id]
        if not d then return end
        return id, nil, nil, nil, nil, d[1], d[2]
    end,
    GetDetailedItemLevelInfo = function(link)
        local id = tonumber(tostring(link):match("item:(%d+)"))
        return ITEMS[id] and ITEMS[id][3] or 0
    end,
    GetItemCount = function(item) return W.counts and W.counts[item] or 1 end,
    EquipItemByName = function(item, slot)
        table.insert(W.equipCalls, { item = item, slot = slot })
        W.equipped[slot] = item
    end,
}
Enum = { ItemClass = { Weapon = 2 }, ItemWeaponSubclass = { Fishingpole = 20 } }

local function link(id) return "|cffffffff|Hitem:" .. id .. "::::|h[item " .. id .. "]|h|r" end

---------------------------------------------------------------------------
-- Load addon
---------------------------------------------------------------------------
local ns = {}
local toc = assert(io.open(ADDON_DIR .. "SylsTools.toc")):read("*a")
for file in toc:gmatch("([%w_\\/]+%.lua)") do
    local chunk = assert(loadfile(ADDON_DIR .. file:gsub("\\", "/")))
    chunk("SylsTools", ns)
end
local ST = ns.ST
local F = ST:GetModule("fishing")

local function fire(event, ...)
    for _, f in ipairs(W.frames) do
        if (f._events[event] or f._all) and f._scripts.OnEvent then
            f._scripts.OnEvent(f, event, ...)
        end
    end
end

local function startFishing(duration)
    duration = duration or 20
    W.channel = { name = "Fishing", startMS = W.time * 1000, endMS = (W.time + duration) * 1000, spellID = 7620 }
    fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 7620)
end
local function stopFishing()
    W.channel = nil
    fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "guid", 7620)
end

---------------------------------------------------------------------------
-- Tiny test runner
---------------------------------------------------------------------------
local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("ok   " .. name)
    else
        failed = failed + 1
        print("FAIL " .. name .. "\n     " .. tostring(err))
    end
end
local function eq(a, b, msg)
    if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

---------------------------------------------------------------------------
-- Tests
---------------------------------------------------------------------------
W.cvars = {
    Sound_EnableAllSound = "1", Sound_EnableSFX = "1", Sound_MasterVolume = "0.5",
    Sound_SFXVolume = "0.4", Sound_MusicVolume = "0.6", Sound_AmbienceVolume = "0.6",
    Sound_EnableSoundWhenGameIsInBG = "0",
    SoftTargetInteract = "1", SoftTargetInteractArc = "0", SoftTargetInteractRange = "10",
    SoftTargetIconGameObject = "0", SoftTargetIconInteract = "0",
}
local function equip(slot, id) W.equipped[slot] = id and link(id) or nil; fire("PLAYER_EQUIPMENT_CHANGED", slot, false) end

test("ADDON_LOADED initialises suite + module saved variables", function()
    fire("ADDON_LOADED", "SylsTools")
    assert(SylsToolsDB and SylsToolsCharDB)
    eq(F.db, SylsToolsDB.modules.fishing)
    eq(F.cdb, SylsToolsCharDB.modules.fishing)
    eq(F.db.alert.enabled, true)
    eq(F.cdb.autoRestore, true)
    eq(F.cdb.restoreDelay, 60)
end)

test("defaults merge keeps existing values", function()
    local t = ST.deepDefaults({ a = 5, sub = { x = 1 } }, { a = 1, b = 2, sub = { x = 9, y = 3 } })
    eq(t.a, 5); eq(t.b, 2); eq(t.sub.x, 1); eq(t.sub.y, 3)
end)

test("fishing spell detection by ID and name", function()
    assert(F:IsFishingSpell(7620))
    assert(F:IsFishingSpell(nil, "Fishing"))
    assert(not F:IsFishingSpell(133, "Fireball"))
end)

test("non-fishing channel is ignored", function()
    W.channel = { name = "Arcane Missiles", startMS = 0, endMS = 5000, spellID = 5143 }
    fire("UNIT_SPELLCAST_CHANNEL_START", "player", "g", 5143)
    eq(F.State:IsFishing(), false)
    W.channel = nil
end)

test("channel start/stop drives state, HUD, casts and sound focus", function()
    startFishing(20)
    eq(F.State:IsFishing(), true)
    eq(F.Tracker.session.casts, 1)
    eq(_G.SylsToolsFishingHUD:IsShown(), true)
    eq(W.cvars.Sound_MusicVolume, "0")
    eq(W.cvars.Sound_SFXVolume, "1")
    W.time = W.time + 5
    eq(F.State:Remaining(), 15)
    stopFishing()
    eq(F.State:IsFishing(), false)
    eq(F.State.lastStopReason, "ended")
    eq(_G.SylsToolsFishingHUD:IsShown(), false)
end)

test("sound settings restored after idle timer", function()
    advance(31)
    eq(W.cvars.Sound_MusicVolume, "0.6")
    eq(W.cvars.Sound_SFXVolume, "0.4")
end)

test("expired cast is detected and flashes Recast", function()
    startFishing(20)
    W.time = W.time + 20
    stopFishing()
    eq(F.State.lastStopReason, "expired")
    eq(_G.SylsToolsFlash:IsShown(), true)
end)

test("fish escaped message is counted", function()
    fire("UI_ERROR_MESSAGE", 1, "Your fish got away!")
    eq(F.Tracker.session.escaped, 1)
end)

test("fishing loot is recorded by zone and item", function()
    startFishing(20)
    W.time = W.time + 3
    stopFishing()
    W.fishingLoot = true
    W.loot = { { link(6303), 1 } }
    fire("LOOT_OPENED", false)
    W.fishingLoot = false
    eq(F.Tracker.session.catches, 1)
    eq(F.Tracker.session.items[6303].count, 1)
    local z = F.db.lifetime.zones["Elwynn Forest"]
    eq(z.catches, 1); eq(z.items[6303], 1); eq(z.subzones["Crystal Lake"], 1)
end)

test("non-fishing loot is ignored", function()
    W.loot = { { link(2000), 1 } }
    fire("LOOT_OPENED", false)
    eq(F.Tracker.session.catches, 1)
end)

-- Gear --------------------------------------------------------------------
test("gear: weapons are remembered automatically when equipped", function()
    runAllTimers()
    equip(16, 2000)
    equip(17, 2001)
    eq(F.cdb.savedWeapons[16], link(2000))
    eq(F.cdb.savedWeapons[17], link(2001))
end)

test("gear: equipping a pole by hand keeps the remembered weapons", function()
    W.equipped[17] = nil
    equip(16, 6256)
    eq(F.cdb.savedWeapons[16], link(2000))
    eq(F.cdb.savedWeapons[17], link(2001))
    equip(16, 2000); equip(17, 2001)
end)

test("gear: Equip Pole picks the best pole and keeps weapons", function()
    W.bags[0] = { [1] = link(6256), [5] = link(6365) }
    fire("BAG_UPDATE_DELAYED")
    W.equipCalls = {}
    ST:HandleSlash("fishing gear")
    eq(W.equipCalls[1].item, link(6365), "best pole")
    eq(W.equipCalls[1].slot, 16)
    W.equipped[17] = nil
    fire("PLAYER_EQUIPMENT_CHANGED", 16, false)
    eq(F.cdb.savedWeapons[16], link(2000))
    eq(F.cdb.savedWeapons[17], link(2001))
end)

test("gear: auto-restore after idle delay, off hand second", function()
    startFishing(20)
    W.time = W.time + 4
    stopFishing()
    local rem = F.Gear:RestoreRemaining()
    eq(rem, 60)
    W.equipCalls = {}
    advance(59)
    eq(#W.equipCalls, 0, "not yet")
    advance(1)
    eq(W.equipCalls[1].item, link(2000)); eq(W.equipCalls[1].slot, 16)
    advance(0.3)
    eq(W.equipCalls[2].item, link(2001)); eq(W.equipCalls[2].slot, 17)
    eq(F.Gear:RestoreRemaining(), nil)
end)

test("gear: casting again cancels the auto-restore countdown", function()
    equip(16, 6365); W.equipped[17] = nil
    startFishing(20); W.time = W.time + 2; stopFishing()
    advance(30)
    startFishing(20)
    eq(F.Gear:RestoreRemaining(), nil)
    W.equipCalls = {}
    advance(40)
    eq(#W.equipCalls, 0, "cancelled timer must not fire")
    W.time = W.time + 1; stopFishing()
    eq(F.Gear:RestoreRemaining(), 60)
end)

test("gear: auto-restore in combat waits until combat ends", function()
    fire("PLAYER_REGEN_DISABLED"); W.combat = true
    W.equipCalls = {}
    advance(61)
    eq(#W.equipCalls, 0)
    eq(F.Gear.pendingAfterCombat, true)
    W.combat = false; fire("PLAYER_REGEN_ENABLED")
    eq(W.equipCalls[1].item, link(2000))
    runAllTimers()
end)

test("gear: auto-restore off means no countdown", function()
    ST:HandleSlash("fishing autorestore off")
    equip(16, 6365); W.equipped[17] = nil
    startFishing(20); W.time = W.time + 2; stopFishing()
    eq(F.Gear:RestoreRemaining(), nil)
    ST:HandleSlash("fishing autorestore 90")
    eq(F.cdb.autoRestore, true)
    eq(F.cdb.restoreDelay, 90)
    F.Gear:SetDelay(5)
    eq(F.cdb.restoreDelay, 10, "clamped")
    F.Gear:SetDelay(60)
end)

test("gear: manual restore and combat refusal", function()
    W.combat = true
    W.equipCalls = {}
    ST:HandleSlash("fishing gear")
    eq(#W.equipCalls, 0)
    W.combat = false
    ST:HandleSlash("fishing gear")
    eq(W.equipCalls[1].item, link(2000))
    runAllTimers()
    eq(W.equipped[17], link(2001))
end)

-- One-key -----------------------------------------------------------------
test("one-key: no key means no bindings", function()
    equip(16, 6256)
    eq(next(W.overrides), nil)
end)

test("one-key: key + pole binds cast button, channel swaps to interact", function()
    ST:HandleSlash("fishing key f")
    eq(F.cdb.key, "F")
    eq(F.OneButton:IsActive(), true)
    eq(W.overrides.F.kind, "click")
    eq(W.overrides.F.target, "SylsToolsFishingCastButton")
    eq(_G.SylsToolsFishingCastButton:GetAttribute("spell"), "Fishing")
    eq(_G.SylsToolsFishingCastButton:GetAttribute("type"), "spell")
    eq(W.cvars.SoftTargetInteract, "3")
    startFishing(20)
    eq(W.overrides.F.target, "INTERACTTARGET")
    stopFishing()
    eq(W.overrides.F.target, "SylsToolsFishingCastButton")
end)

test("one-key: turning off bobber icon restores soft-target CVars", function()
    F.db.softTarget = false
    F.OneButton:UpdateSoftTarget()
    eq(W.cvars.SoftTargetInteract, "1")
    F.db.softTarget = true
    F.OneButton:UpdateSoftTarget()
    eq(W.cvars.SoftTargetInteract, "3")
end)

test("one-key: combat releases the key, and it returns after combat", function()
    fire("PLAYER_REGEN_DISABLED")
    W.combat = true
    eq(W.overrides.F, nil)
    startFishing(20) -- must not try to bind in combat
    eq(W.overrides.F, nil)
    stopFishing()
    W.combat = false
    fire("PLAYER_REGEN_ENABLED")
    eq(W.overrides.F.target, "SylsToolsFishingCastButton")
    runAllTimers()
end)

test("one-key: unequipping pole leaves fishing mode and restores CVars", function()
    equip(16, 2000)
    eq(F.OneButton:IsActive(), false)
    eq(W.overrides.F, nil)
    eq(W.cvars.SoftTargetInteract, "1")
end)

-- UI ----------------------------------------------------------------------
test("ui: /syl opens the window on the fishing page", function()
    ST:HandleSlash("")
    eq(ST.UI:IsShown(), true)
    eq(ST.UI.selected, "fishing")
    assert(F.Panel.page, "panel built")
    eq(F.Panel.page:IsShown(), true)
    ST:HandleSlash("")
    eq(ST.UI:IsShown(), false)
    ST:HandleSlash("fishing")
    eq(ST.UI:IsShown(), true)
end)

test("ui: weapon slots and swap button reflect state", function()
    equip(16, 2000); equip(17, 2001)
    F.Panel:Refresh()
    eq(F.Panel.mainSlot.link, link(2000))
    eq(F.Panel.offSlot.link, link(2001))
    eq(F.Panel.poleSlot.link, link(6365))
    eq(F.Panel.swapButton:GetText(), "Equip Fishing Pole")
    W.equipCalls = {}
    F.Panel.swapButton:Click()
    eq(W.equipCalls[1].item, link(6365))
    W.equipped[17] = nil
    fire("PLAYER_EQUIPMENT_CHANGED", 16, false)
    F.Panel:Refresh()
    eq(F.Panel.swapButton:GetText(), "Re-equip My Weapons")
    eq(F.Panel.mainSlot.link, link(2000), "still shows remembered weapon")
    startFishing(20); W.time = W.time + 2; stopFishing()
    F.Panel:RefreshStatus()
    assert(F.Panel.gearStatus:GetText():find("Re%-equipping weapons in"), F.Panel.gearStatus:GetText())
end)

test("ui: auto-restore checkbox and stepper", function()
    local cb = F.Panel.autoCheck
    cb:SetChecked(false); cb:Click()
    eq(F.cdb.autoRestore, false)
    eq(F.Gear:RestoreRemaining(), nil, "unchecking cancels countdown")
    cb:SetChecked(true); cb:Click()
    eq(F.cdb.autoRestore, true)
    F.Panel.delay:Refresh()
    eq(F.Panel.delay.value:GetText(), "60s")
end)

test("ui: key capture sets the one-key binding", function()
    local kb = F.Panel.keyButton
    kb:Click()
    eq(kb.capturing, true)
    W.shift = true
    kb:GetScript("OnKeyDown")(kb, "G")
    W.shift = false
    eq(F.cdb.key, "SHIFT-G")
    eq(W.overrides["SHIFT-G"].target, "SylsToolsFishingCastButton")
    kb:Click()
    kb:GetScript("OnKeyDown")(kb, "ESCAPE")
    eq(F.cdb.key, "SHIFT-G", "escape cancels")
    kb:Click(); kb:Click("Button4")
    eq(F.cdb.key, "BUTTON4")
end)

test("ui: stats show the session", function()
    F.Panel:Refresh()
    assert(F.Panel.stats:GetText():find("Catches"), "stats text")
    assert(F.Panel.items:GetText():find("item 6303"), F.Panel.items:GetText())
end)

test("slash help, stats and probe do not error", function()
    ST:HandleSlash("help")
    ST:HandleSlash("fishing stats")
    ST:HandleSlash("fishing zone")
    ST:HandleSlash("fishing probe")
    startFishing(20)
    fire("PLAYER_SOFT_INTERACT_CHANGED", "old", "new")
    stopFishing()
    ST:HandleSlash("fishing probe")
    assert(#F.db.probeLog >= 2, "probe logged events")
    SylsTools_OnAddonCompartmentClick()
end)

test("logout restores every CVar we touched", function()
    equip(16, 6256)
    startFishing(20)
    fire("PLAYER_LOGOUT")
    eq(W.cvars.Sound_MusicVolume, "0.6")
    eq(W.cvars.SoftTargetInteract, "1")
end)

-- Game key binding ------------------------------------------------------
test("game keybinding reels while fishing even without a Syl's Tools key", function()
    stopFishing() -- previous test left a cast running
    ST:HandleSlash("fishing key none")
    W.gameKeys = { "G" }
    fire("UPDATE_BINDINGS")
    eq(W.overrides.G, nil, "normal binding handles casting")
    startFishing(20)
    eq(W.overrides.G.target, "INTERACTTARGET")
    stopFishing()
    eq(W.overrides.G, nil)
    eq(_G["BINDING_NAME_CLICK SylsToolsFishingCastButton:LeftButton"], "Fishing: Cast / Reel")
    W.gameKeys = nil
    fire("UPDATE_BINDINGS")
end)

-- Spellbook + Upcoming Spells --------------------------------------------
local Spells = ST:GetModule("spells")
local Guides = ST:GetModule("guides")

test("spellbook: knows spells by name and rank", function()
    W.spellbook = {
        { "Heroic Strike", "Rank 2", 284 }, { "Battle Shout", "Rank 1", 6673 }, { "Charge", "Rank 1", 100 },
        { "Rend", "Rank 1", 772 }, { "Thunder Clap", "Rank 1", 6343 }, { "Defensive Stance", "", 71 },
        { "Sunder Armor", "Rank 1", 7386 }, { "Taunt", "", 355 }, { "Bloodrage", "", 2687 },
    }
    fire("SPELLS_CHANGED")
    local B = ST.Spellbook
    assert(B:Knows("Heroic Strike"))
    assert(B:Knows("Heroic Strike", "Rank 1"), "lower rank counts")
    assert(not B:Knows("Heroic Strike", "Rank 3"))
    assert(B:Knows("Defensive Stance"))
    assert(B:Knows(6673), "by id")
    assert(not B:Knows("Revenge"))
end)

test("upcoming: trainer capture records every service and restores filters", function()
    W.trainer = {
        { "Warrior", "", "header", 0, 0 },
        { "Heroic Strike", "Rank 2", "used", 8, 60 },
        { "Overpower", "Rank 1", "available", 12, 100 },
        { "Shield Bash", "Rank 1", "available", 12, 100 },
        { "Revenge", "Rank 1", "unavailable", 14, 200 },
        { "Demoralizing Shout", "Rank 1", "unavailable", 14, 200 },
        { "Heroic Strike", "Rank 3", "unavailable", 16, 300 },
        { "Execute", "Rank 1", "unavailable", 24, 1000 },
    }
    fire("TRAINER_SHOW")
    local data = SylsToolsDB.modules.spells.trainer.WARRIOR
    eq(#data.spells, 7)
    eq(W.trainerFilters.available, 1)
    eq(W.trainerFilters.unavailable, nil, "filters restored")
    eq(W.trainerFilters.used, nil)
end)

test("upcoming: tradeskill trainers are ignored", function()
    W.tradeskillTrainer = true
    W.trainer = { { "Fishing", "", "available", 5, 10 } }
    fire("TRAINER_SHOW")
    eq(#SylsToolsDB.modules.spells.trainer.WARRIOR.spells, 7)
    W.tradeskillTrainer = nil
end)

test("upcoming: ready, next level and later grouping", function()
    local up = Spells:Upcoming()
    eq(up[1].name, "Overpower"); eq(up[1].ready, true)
    eq(up[2].name, "Shield Bash"); eq(up[2].ready, true)
    eq(up[3].level, 14)
    for _, sp in ipairs(up) do assert(not (sp.name == "Heroic Strike" and sp.rank == "Rank 2"), "known rank hidden") end
    local rows = Spells:BuildRows(10)
    assert(rows[1].text:find("Ready to train now"), rows[1].text)
    assert(rows[2].text:find("Total cost"), "cost line")
    local foundNext, foundExecute = false, false
    for _, r in ipairs(rows) do
        if r.kind == "header" and r.text:find("Level 14") and r.text:find("next level") == nil then end
        if r.kind == "header" and r.text:find("Level 13") then error("no level 13 header expected") end
        if r.title == "Execute" then foundExecute = true end
        if r.kind == "header" and r.text:find("Level 14") then foundNext = true end
    end
    assert(foundNext, "level 14 header")
    eq(foundExecute, false, "level 24 is beyond 10 levels ahead")
    local all = Spells:BuildRows(0)
    local hasExecute = false
    for _, r in ipairs(all) do if r.title == "Execute" then hasExecute = true end end
    assert(hasExecute, "show all levels")
    eq(Spells:LevelFor("Revenge"), 14)
end)

test("upcoming: level-up message lists new spells", function()
    W.chat = {}
    fire("PLAYER_LEVEL_UP", 14)
    local found = false
    for _, m in ipairs(W.chat) do if m:find("Level 14!") and m:find("Revenge") then found = true end end
    assert(found, "level-up notice")
end)

test("upcoming: spellbook tab attaches and toggles a side panel", function()
    _G.SpellBookFrame = CreateFrame("Frame", "SpellBookFrame")
    fire("ADDON_LOADED", "Blizzard_SpellBook")
    SpellBookFrame:Show()
    local tab = _G.SylsToolsSpellbookTab
    assert(tab and tab:IsShown(), "tab shown with spellbook")
    tab:Click()
    local panel = _G.SylsToolsUpcomingSpellsPanel
    eq(panel:IsShown(), true)
    SpellBookFrame:Hide()
    eq(tab:IsShown(), false); eq(panel:IsShown(), false)
    SpellBookFrame:Show()
    eq(panel:IsShown(), true, "reopens with the spellbook")
    Spells.db.spellbookTab = false
    ST:Fire("ST_SETTINGS_CHANGED")
    eq(tab:IsShown(), false)
    Spells.db.spellbookTab = true
    ST:Fire("ST_SETTINGS_CHANGED")
    eq(tab:IsShown(), true)
    SpellBookFrame:Hide()
end)

test("upcoming: window page builds", function()
    ST.UI:Show("spells")
    eq(ST.UI.selected, "spells")
    assert(Spells.Panel.list.rows and #Spells.Panel.list.rows > 0)
    assert(Spells.Panel.info:GetText():find("class trainer"))
end)

-- Class guides --------------------------------------------------------------
test("guides: default to the first role, abilities reflect spellbook only", function()
    eq(Guides:Current().key, "tank")
    local rows = Guides:BuildRows(Guides:Current())
    local byName = {}
    for _, r in ipairs(rows) do
        if r.kind == "item" then byName[r.title:match("^([^|]-)%s*$") or r.title:match("^(.-)  ")] = r end
    end
    local def = byName["Defensive Stance"]
    assert(def and not def.dim, "known ability bright")
    local rev = byName["Revenge"]
    assert(rev and rev.dim, "unknown ability dim")
    local revRow
    for _, r in ipairs(rows) do if r.title and r.title:find("^Revenge") then revRow = r end end
    assert(revRow.title:find("unlocks at level 14"), revRow.title)
    local slam
    for _, r in ipairs(rows) do if r.title and r.title:find("^Shield Slam") then slam = r end end
    assert(slam.title:find("talent"), slam.title)
    assert(rows[2].text:find("You have %d+ of the %d+ abilities"), rows[2].text)
end)

test("guides: hide unknown, choose dps, other class message", function()
    Guides.db.hideUnknown = true
    for _, r in ipairs(Guides:BuildRows(Guides:Current())) do
        assert(not r.dim, "hidden: " .. tostring(r.title))
    end
    Guides.db.hideUnknown = false
    Guides:Choose("dps")
    eq(Guides:Current().key, "dps")
    W.class = "MAGE"
    local rows = Guides:BuildRows(Guides:Current())
    assert(rows[1].text:find("no guide for your class"), rows[1].text)
    W.class = "WARRIOR"
end)

test("guides: window page builds with role buttons", function()
    ST.UI:Show("guides")
    eq(ST.UI.selected, "guides")
    local P = Guides.Panel
    eq(P.buttons[1]:IsShown(), true)
    eq(P.buttons[2]:IsShown(), true)
    P.buttons[1]:Click()
    eq(Guides:Current().key, "tank")
    assert(#P.list.rows > 10)
end)

test("no handler errors were printed", function()
    for _, msg in ipairs(W.chat) do
        assert(not msg:find("error in"), msg)
    end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
