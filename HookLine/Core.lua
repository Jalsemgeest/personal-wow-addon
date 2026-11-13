-- HookLine: Core
-- Namespace, event bus, saved variables, slash commands and API shims.
-- Design rule: every game action must come from a player keypress.
-- See DESIGN.md section 2.

local ADDON_NAME, ns = ...
ns = ns or {}

local HL = {}
ns.HL = HL
_G.HookLine = HL -- exposed for /run debugging and other modules

HL.name = ADDON_NAME or "HookLine"
HL.version = "0.1.0"

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------
HL.defaults = {
    global = {
        alert = {
            enabled = true,
            scale = 1.0,
            point = { "CENTER", "UIParent", "CENTER", 0, 180 },
            flashOnExpire = true,
        },
        sound = {
            focus = true,      -- boost SFX / lower music while fishing
            sfx = 1.0,
            master = 1.0,
            music = 0.0,
            ambience = 0.0,
            background = true, -- keep sound on while WoW is in the background
        },
        softTarget = true,     -- manage soft-target interact CVars
        probe = false,         -- event probe (see DESIGN.md section 3, tier C)
        lifetime = { zones = {}, items = {}, totals = { casts = 0, catches = 0, escaped = 0 } },
    },
    char = {
        key = nil,             -- one-button key, e.g. "F"
        modeAuto = true,       -- fishing mode follows "pole equipped"
        modeManual = false,
        savedWeapons = nil,    -- { [16] = itemLink, [17] = itemLink }
        lastSkill = nil,
    },
}

local function deepDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            deepDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end
HL.deepDefaults = deepDefaults

---------------------------------------------------------------------------
-- Printing
---------------------------------------------------------------------------
local PREFIX = "|cff33ccffHookLine|r: "
function HL:Print(fmt, ...)
    local msg = select("#", ...) > 0 and string.format(fmt, ...) or tostring(fmt)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
    else
        print(PREFIX .. msg)
    end
end

---------------------------------------------------------------------------
-- Event bus: WoW events and internal "HL_*" messages share one registry.
---------------------------------------------------------------------------
local handlers = {}
local eventFrame = CreateFrame("Frame")
HL.eventFrame = eventFrame

function HL:On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        if not event:find("^HL_") then
            eventFrame:RegisterEvent(event)
        end
    end
    table.insert(handlers[event], fn)
end

function HL:Fire(event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok then
            HL:Print("|cffff5555error in %s:|r %s", event, tostring(err))
        end
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    HL:Fire(event, ...)
end)

---------------------------------------------------------------------------
-- API shims (modern client first, older globals as fallback)
---------------------------------------------------------------------------
local API = {}
HL.API = API

-- Fishing spell IDs across client generations. Vanilla ranks + modern.
API.FISHING_SPELL_IDS = { 7620, 7731, 7732, 18248, 33095, 51294, 88868, 110410, 131474, 131490, 158743 }
local fishingIDSet = {}
for _, id in ipairs(API.FISHING_SPELL_IDS) do fishingIDSet[id] = true end

function API.GetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellID)
    elseif C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        return info and info.name
    elseif GetSpellInfo then
        return (GetSpellInfo(spellID))
    end
end

function API.FishingSpellName()
    if API._fishingName then return API._fishingName end
    for _, id in ipairs(API.FISHING_SPELL_IDS) do
        local name = API.GetSpellName(id)
        if name and name ~= "" then
            API._fishingName = name
            return name
        end
    end
    return "Fishing"
end

function API.IsFishingSpell(spellID, spellName)
    if spellID and fishingIDSet[spellID] then return true end
    if spellName and spellName == API.FishingSpellName() then return true end
    return false
end

function API.GetContainerNumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag)
    end
    return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end

function API.GetContainerItemLink(bag, slot)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bag, slot)
    end
    return GetContainerItemLink and GetContainerItemLink(bag, slot)
end

-- Returns classID, subclassID for an item link/ID.
function API.GetItemClass(item)
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not fn or not item then return end
    local _, _, _, _, _, classID, subclassID = fn(item)
    return classID, subclassID
end

function API.GetItemLevel(item)
    local fn = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
    if fn and item then
        local lvl = fn(item)
        if lvl then return lvl end
    end
    return 0
end

function API.EquipItem(item, slot)
    local fn = (C_Item and C_Item.EquipItemByName) or EquipItemByName
    if fn then fn(item, slot) end
end

API.WEAPON_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or 2
API.FISHINGPOLE_SUBCLASS = (Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole) or 20

function API.IsFishingPole(item)
    local classID, subclassID = API.GetItemClass(item)
    return classID == API.WEAPON_CLASS and subclassID == API.FISHINGPOLE_SUBCLASS
end

function API.InCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

---------------------------------------------------------------------------
-- CVar helper that remembers originals so we can always restore.
---------------------------------------------------------------------------
function HL:NewCVarStash()
    local stash = { saved = {} }
    function stash:Set(name, value)
        if not (GetCVar and SetCVar) then return end
        local current = GetCVar(name)
        if current == nil then return end -- CVar doesn't exist on this client
        if self.saved[name] == nil then self.saved[name] = current end
        SetCVar(name, tostring(value))
    end
    function stash:Restore()
        if not SetCVar then return end
        for name, value in pairs(self.saved) do SetCVar(name, value) end
        self.saved = {}
    end
    function stash:IsActive() return next(self.saved) ~= nil end
    return stash
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------
HL:On("ADDON_LOADED", function(_, name)
    if name ~= HL.name then return end
    HookLineDB = deepDefaults(HookLineDB or {}, HL.defaults.global)
    HookLineCharDB = deepDefaults(HookLineCharDB or {}, HL.defaults.char)
    HL.db = HookLineDB
    HL.cdb = HookLineCharDB
    HL:Fire("HL_READY")
end)

---------------------------------------------------------------------------
-- Slash commands. Modules register subcommands with HL:Command().
---------------------------------------------------------------------------
local commands, commandOrder = {}, {}
function HL:Command(name, usage, fn)
    commands[name] = { usage = usage, fn = fn }
    table.insert(commandOrder, name)
end

function HL:HandleSlash(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower()
    local entry = cmd and commands[cmd]
    if entry then
        entry.fn(rest or "")
        return
    end
    HL:Print("v%s commands:", HL.version)
    for _, name in ipairs(commandOrder) do
        HL:Print("  /hl %s %s", name, commands[name].usage)
    end
end

SLASH_HOOKLINE1 = "/hookline"
SLASH_HOOKLINE2 = "/hl"
SlashCmdList = SlashCmdList or {}
SlashCmdList.HOOKLINE = function(msg) HL:HandleSlash(msg) end

function HL:ToggleSetting(tbl, key, label)
    tbl[key] = not tbl[key]
    HL:Print("%s: %s", label, tbl[key] and "|cff55ff55on|r" or "|cffff5555off|r")
    return tbl[key]
end
