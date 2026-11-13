-- Syl's Tools: Core
-- Namespace, event bus, module registry, saved variables, slash commands, API shims.
-- Suite-wide rule: every game action comes from a player keypress or click.
-- See DESIGN.md section 2.

local ADDON_NAME, ns = ...
ns = ns or {}

local ST = {}
ns.ST = ST
_G.SylsTools = ST -- exposed for /run debugging

ST.name = ADDON_NAME or "SylsTools"
ST.title = "Syl's Tools"
ST.version = "0.3.0"

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
ST.deepDefaults = deepDefaults

---------------------------------------------------------------------------
-- Printing
---------------------------------------------------------------------------
local PREFIX = "|cffb48cffSyl's Tools|r: "
function ST:Print(fmt, ...)
    local msg = select("#", ...) > 0 and string.format(fmt, ...) or tostring(fmt)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
    else
        print(PREFIX .. msg)
    end
end

---------------------------------------------------------------------------
-- Event bus: WoW events and internal "ST_*" messages share one registry.
---------------------------------------------------------------------------
local handlers = {}
local eventFrame = CreateFrame("Frame")
ST.eventFrame = eventFrame

function ST:On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        if not event:find("^ST_") then
            -- Unknown events throw on modern clients; skip ones this client lacks.
            pcall(eventFrame.RegisterEvent, eventFrame, event)
        end
    end
    table.insert(handlers[event], fn)
end

function ST:Fire(event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok then
            ST:Print("|cffff5555error in %s:|r %s", event, tostring(err))
        end
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    ST:Fire(event, ...)
end)

---------------------------------------------------------------------------
-- Module registry
--   local M = ST:NewModule("fishing", { title = "Fishing", icon = ..., defaults = {...}, charDefaults = {...} })
--   M.db / M.cdb are ready when "ST_READY" fires.
--   M:BuildPanel(parent) builds the module's page in the main window.
--   M:Command(name, usage, fn) adds "/syl <module> <name>".
---------------------------------------------------------------------------
ST.modules, ST.moduleOrder = {}, {}

function ST:NewModule(key, info)
    local m = info or {}
    m.key = key
    m.title = m.title or key
    m.commands, m.commandOrder = {}, {}
    function m:Command(name, usage, fn)
        self.commands[name] = { usage = usage, fn = fn }
        table.insert(self.commandOrder, name)
    end
    self.modules[key] = m
    table.insert(self.moduleOrder, key)
    return m
end

function ST:GetModule(key) return self.modules[key] end

---------------------------------------------------------------------------
-- API shims (modern client first, older globals as fallback)
---------------------------------------------------------------------------
local API = {}
ST.API = API

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

function API.GetSpellIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spellID) end
    if GetSpellTexture then return GetSpellTexture(spellID) end
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

function API.GetItemClass(item)
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not fn or not item then return end
    local _, _, _, _, _, classID, subclassID = fn(item)
    return classID, subclassID
end

function API.GetItemIcon(item)
    if not item then return end
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if fn then
        local _, _, _, _, icon = fn(item)
        if icon then return icon end
    end
    return GetItemIcon and GetItemIcon(item)
end

function API.GetItemLevel(item)
    local fn = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
    if fn and item then
        local lvl = fn(item)
        if lvl then return lvl end
    end
    return 0
end

function API.GetItemCount(item)
    local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
    return fn and item and fn(item) or 0
end

function API.EquipItem(item, slot)
    local fn = (C_Item and C_Item.EquipItemByName) or EquipItemByName
    if fn then fn(item, slot) end
end

function API.ItemIDFromLink(link)
    return link and tonumber(tostring(link):match("item:(%d+)"))
end

function API.InCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

function API.IsSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

-- Run fn after `delay` seconds; returns a handle with :Cancel().
function API.After(delay, fn)
    local handle = { cancelled = false }
    function handle:Cancel() self.cancelled = true end
    local function run() if not handle.cancelled then fn() end end
    if C_Timer and C_Timer.After then C_Timer.After(delay, run) else run() end
    return handle
end

---------------------------------------------------------------------------
-- CVar helper that remembers originals so we can always restore.
---------------------------------------------------------------------------
function ST:NewCVarStash()
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
ST.defaults = {
    global = { ui = { point = { "CENTER", "UIParent", "CENTER", 0, 0 }, lastModule = nil }, modules = {} },
    char = { modules = {} },
}

ST:On("ADDON_LOADED", function(_, name)
    if name ~= ST.name then return end
    SylsToolsDB = deepDefaults(SylsToolsDB or {}, ST.defaults.global)
    SylsToolsCharDB = deepDefaults(SylsToolsCharDB or {}, ST.defaults.char)
    ST.db, ST.cdb = SylsToolsDB, SylsToolsCharDB
    for _, key in ipairs(ST.moduleOrder) do
        local m = ST.modules[key]
        ST.db.modules[key] = deepDefaults(ST.db.modules[key] or {}, m.defaults or {})
        ST.cdb.modules[key] = deepDefaults(ST.cdb.modules[key] or {}, m.charDefaults or {})
        m.db, m.cdb = ST.db.modules[key], ST.cdb.modules[key]
    end
    ST:Fire("ST_READY")
end)

---------------------------------------------------------------------------
-- Slash commands
--   /syl                 open the window
--   /syl <module> [cmd]  module commands (no cmd = open that module's page)
---------------------------------------------------------------------------
function ST:Toggle(moduleKey)
    if ST.UI then ST.UI:Toggle(moduleKey) end
end

local function printHelp()
    ST:Print("v%s - /syl opens the window. Module commands:", ST.version)
    for _, key in ipairs(ST.moduleOrder) do
        local m = ST.modules[key]
        for _, name in ipairs(m.commandOrder) do
            ST:Print("  /syl %s %s %s", key, name, m.commands[name].usage)
        end
    end
end

function ST:HandleSlash(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "" then return ST:Toggle() end
    local first, rest = msg:match("^(%S+)%s*(.*)$")
    first = first:lower()
    if first == "help" then return printHelp() end
    local m = ST.modules[first]
    if not m then return printHelp() end
    local cmd, args = rest:match("^(%S+)%s*(.*)$")
    local entry = cmd and m.commands[cmd:lower()]
    if entry then return entry.fn(args or "") end
    if cmd then return printHelp() end
    ST:Toggle(first)
end

SLASH_SYLSTOOLS1 = "/syl"
SLASH_SYLSTOOLS2 = "/sylstools"
SlashCmdList = SlashCmdList or {}
SlashCmdList.SYLSTOOLS = function(msg) ST:HandleSlash(msg) end

-- Game Menu > Key Bindings labels (entries live in Bindings.xml).
BINDING_HEADER_SYLSTOOLS = "Syl's Tools"
_G["BINDING_NAME_CLICK SylsToolsFishingCastButton:LeftButton"] = "Fishing: Cast / Reel"

-- Minimap "addon compartment" entry (modern client).
function SylsTools_OnAddonCompartmentClick() ST:Toggle() end

function ST:ToggleSetting(tbl, key, label)
    tbl[key] = not tbl[key]
    ST:Print("%s: %s", label, tbl[key] and "|cff55ff55on|r" or "|cffff5555off|r")
    ST:Fire("ST_SETTINGS_CHANGED")
    return tbl[key]
end
