-- Syl's Tools > Fishing: module definition, defaults and fishing-specific helpers.

local _, ns = ...
local ST = (ns and ns.ST) or SylsTools
local API = ST.API

local F = ST:NewModule("fishing", {
    title = "Fishing",
    icon = "Interface\\Icons\\Trade_Fishing",
    defaults = {
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
        probe = false,         -- event probe (DESIGN.md section 3, tier C)
        lifetime = { zones = {}, items = {}, totals = { casts = 0, catches = 0, escaped = 0 } },
    },
    charDefaults = {
        key = nil,             -- one-key cast & reel key, e.g. "F"
        modeAuto = true,       -- fishing mode follows "pole equipped"
        modeManual = false,
        savedWeapons = nil,    -- { [16] = link, [17] = link } - last non-pole weapons
        autoRestore = true,    -- re-equip weapons after you stop fishing
        restoreDelay = 60,     -- seconds idle after the last cast ends
        lastSkill = nil,
    },
})
ns.Fishing = F

F.SPELL_IDS = { 7620, 7731, 7732, 18248, 33095, 51294, 88868, 110410, 131474, 131490, 158743 }
local idSet = {}
for _, id in ipairs(F.SPELL_IDS) do idSet[id] = true end

function F:SpellName()
    if self._spellName then return self._spellName end
    for _, id in ipairs(self.SPELL_IDS) do
        local name = API.GetSpellName(id)
        if name and name ~= "" then
            self._spellName = name
            return name
        end
    end
    return "Fishing"
end

function F:IsFishingSpell(spellID, spellName)
    if spellID and idSet[spellID] then return true end
    if spellName and spellName == self:SpellName() then return true end
    return false
end

F.WEAPON_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or 2
F.POLE_SUBCLASS = (Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole) or 20

function F:IsPole(item)
    local classID, subclassID = API.GetItemClass(item)
    return classID == self.WEAPON_CLASS and subclassID == self.POLE_SUBCLASS
end

function F:PoleEquipped()
    local link = GetInventoryItemLink and GetInventoryItemLink("player", 16)
    return link ~= nil and self:IsPole(link)
end
