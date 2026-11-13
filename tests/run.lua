-- Headless tests for HookLine against a mocked WoW API.
-- Run from the repo root:  lua5.1 tests/run.lua

local ADDON_DIR = "HookLine/"

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
        Show = function(self) self._shown = true end,
        Hide = function(self) self._shown = false end,
        IsShown = function(self) return self._shown end,
        GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
        SetText = function(self, t) self._text = t end,
        SetFormattedText = function(self, f, ...) self._text = string.format(f, ...) end,
        GetText = function(self) return self._text end,
        CreateTexture = function() return stub() end,
        CreateFontString = function() return stub() end,
    }
    return setmetatable(obj, {
        __index = function(_, k)
            return methods[k] or function() end
        end,
    })
end

function CreateFrame(_, name, _, template)
    local f = stub()
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
function GetBindingKey() return nil end
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
UIParent = stub()
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) table.insert(W.chat, msg) end }
ERR_FISH_ESCAPED = "Your fish got away!"
C_Timer = { After = function(_, fn) W.timers = W.timers or {}; table.insert(W.timers, fn) end }
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
local toc = assert(io.open(ADDON_DIR .. "HookLine.toc")):read("*a")
for file in toc:gmatch("([%w_]+%.lua)") do
    local chunk = assert(loadfile(ADDON_DIR .. file))
    chunk("HookLine", ns)
end
local HL = ns.HL

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

test("ADDON_LOADED initialises saved variables with defaults", function()
    fire("ADDON_LOADED", "HookLine")
    assert(HookLineDB and HookLineCharDB)
    eq(HL.db.alert.enabled, true)
    eq(HL.db.lifetime.totals.casts, 0)
end)

test("defaults merge keeps existing values", function()
    local t = HL.deepDefaults({ a = 5, sub = { x = 1 } }, { a = 1, b = 2, sub = { x = 9, y = 3 } })
    eq(t.a, 5); eq(t.b, 2); eq(t.sub.x, 1); eq(t.sub.y, 3)
end)

test("fishing spell detection by ID and name", function()
    assert(HL.API.IsFishingSpell(7620))
    assert(HL.API.IsFishingSpell(nil, "Fishing"))
    assert(not HL.API.IsFishingSpell(133, "Fireball"))
end)

test("non-fishing channel is ignored", function()
    W.channel = { name = "Arcane Missiles", startMS = 0, endMS = 5000, spellID = 5143 }
    fire("UNIT_SPELLCAST_CHANNEL_START", "player", "g", 5143)
    eq(HL.Fishing:IsFishing(), false)
    W.channel = nil
end)

test("channel start/stop drives state, HUD, casts and sound focus", function()
    startFishing(20)
    eq(HL.Fishing:IsFishing(), true)
    eq(HL.Tracker.session.casts, 1)
    eq(_G.HookLineHUD:IsShown(), true)
    eq(W.cvars.Sound_MusicVolume, "0")
    eq(W.cvars.Sound_SFXVolume, "1")
    W.time = W.time + 5
    eq(HL.Fishing:Remaining(), 15)
    stopFishing()
    eq(HL.Fishing:IsFishing(), false)
    eq(HL.Fishing.lastStopReason, "ended")
    eq(_G.HookLineHUD:IsShown(), false)
end)

test("sound settings restored after idle timer", function()
    for _, fn in ipairs(W.timers or {}) do fn() end
    W.timers = {}
    eq(W.cvars.Sound_MusicVolume, "0.6")
    eq(W.cvars.Sound_SFXVolume, "0.4")
end)

test("expired cast is detected and flashes Recast", function()
    startFishing(20)
    W.time = W.time + 20
    stopFishing()
    eq(HL.Fishing.lastStopReason, "expired")
    eq(_G.HookLineFlash:IsShown(), true)
end)

test("fish escaped message is counted", function()
    fire("UI_ERROR_MESSAGE", 1, "Your fish got away!")
    eq(HL.Tracker.session.escaped, 1)
end)

test("fishing loot is recorded by zone and item", function()
    startFishing(20)
    W.time = W.time + 3
    stopFishing()
    W.fishingLoot = true
    W.loot = { { link(6303), 1 } }
    fire("LOOT_OPENED", false)
    W.fishingLoot = false
    eq(HL.Tracker.session.catches, 1)
    eq(HL.Tracker.session.items[6303].count, 1)
    local z = HL.db.lifetime.zones["Elwynn Forest"]
    eq(z.catches, 1); eq(z.items[6303], 1); eq(z.subzones["Crystal Lake"], 1)
end)

test("non-fishing loot is ignored", function()
    W.loot = { { link(2000), 1 } }
    fire("LOOT_OPENED", false)
    eq(HL.Tracker.session.catches, 1)
end)

test("one-key: no key means no bindings", function()
    W.equipped[16] = link(6256)
    fire("PLAYER_EQUIPMENT_CHANGED", 16, false)
    eq(next(W.overrides), nil)
end)

test("one-key: key + pole binds cast button, channel swaps to interact", function()
    HL:HandleSlash("key f")
    eq(HL.cdb.key, "F")
    eq(HL.OneButton:IsActive(), true)
    eq(W.overrides.F.kind, "click")
    eq(W.overrides.F.target, "HookLineCastButton")
    eq(_G.HookLineCastButton:GetAttribute("spell"), "Fishing")
    eq(_G.HookLineCastButton:GetAttribute("type"), "spell")
    eq(W.cvars.SoftTargetInteract, "3")
    startFishing(20)
    eq(W.overrides.F.target, "INTERACTTARGET")
    stopFishing()
    eq(W.overrides.F.target, "HookLineCastButton")
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
    eq(W.overrides.F.target, "HookLineCastButton")
end)

test("one-key: unequipping pole leaves fishing mode and restores CVars", function()
    W.equipped[16] = link(2000)
    fire("PLAYER_EQUIPMENT_CHANGED", 16, false)
    eq(HL.OneButton:IsActive(), false)
    eq(W.overrides.F, nil)
    eq(W.cvars.SoftTargetInteract, "1")
end)

test("gear: equips best pole and remembers weapons, then restores", function()
    W.equipped[16] = link(2000)
    W.equipped[17] = link(2001)
    W.bags[0] = { [1] = link(6256), [5] = link(6365) }
    W.equipCalls = {}
    HL:HandleSlash("gear")
    eq(W.equipCalls[1].item, link(6365), "best pole")
    eq(HL.cdb.savedWeapons[16], link(2000))
    eq(HL.cdb.savedWeapons[17], link(2001))
    W.equipCalls = {}
    HL:HandleSlash("gear")
    for _, fn in ipairs(W.timers or {}) do fn() end
    W.timers = {}
    eq(W.equipCalls[1].item, link(2000)); eq(W.equipCalls[1].slot, 16)
    eq(W.equipCalls[2].item, link(2001)); eq(W.equipCalls[2].slot, 17)
    eq(HL.cdb.savedWeapons, nil)
end)

test("gear: refuses in combat", function()
    W.combat = true
    W.equipCalls = {}
    HL:HandleSlash("gear")
    eq(#W.equipCalls, 0)
    W.combat = false
end)

test("slash help and stats do not error", function()
    HL:HandleSlash("")
    HL:HandleSlash("stats")
    HL:HandleSlash("zone")
    HL:HandleSlash("probe")
    startFishing(20)
    fire("PLAYER_SOFT_INTERACT_CHANGED", "old", "new")
    stopFishing()
    HL:HandleSlash("probe")
    assert(#HL.db.probeLog >= 2, "probe logged events")
end)

test("logout restores every CVar we touched", function()
    HL:HandleSlash("key F")
    W.equipped[16] = link(6256)
    fire("PLAYER_EQUIPMENT_CHANGED", 16, false)
    startFishing(20)
    fire("PLAYER_LOGOUT")
    eq(W.cvars.Sound_MusicVolume, "0.6")
    eq(W.cvars.SoftTargetInteract, "1")
end)

test("no handler errors were printed", function()
    for _, msg in ipairs(W.chat) do
        assert(not msg:find("error in"), msg)
    end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
