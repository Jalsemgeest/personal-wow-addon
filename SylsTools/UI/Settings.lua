-- Syl's Tools: page in Blizzard's own Options > AddOns panel.
--
-- Why this exists: WoW Forever's Gamepad UI cursor can only reach frames the
-- client builds itself. Custom addon windows (including ours) aren't reachable
-- with a controller, but Settings pages built with the *vertical layout*
-- (Settings.Register* + initializers) are. So every setting a controller player
-- needs lives here too, including a native keybinding row so a pad button can
-- be bound to "Fishing: Cast / Reel".
--
-- Every step is pcall-guarded: if an API differs on this client, that row is
-- skipped and the rest of the addon is unaffected.

local _, ns = ...
local ST = (ns and ns.ST) or SylsTools
local API = ST.API

local SettingsPage = { rows = 0, failed = 0 }
ST.SettingsPage = SettingsPage

local category, layout

local function try(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then
        SettingsPage.rows = SettingsPage.rows + 1
        return res
    end
    SettingsPage.failed = SettingsPage.failed + 1
end

local function addInitializer(init)
    if not init then return end
    if layout and layout.AddInitializer then
        layout:AddInitializer(init)
    elseif Settings.RegisterInitializer then
        Settings.RegisterInitializer(category, init)
    end
end

local function header(text)
    if not CreateSettingsListSectionHeaderInitializer then return end
    try(function() addInitializer(CreateSettingsListSectionHeaderInitializer(text)) end)
end

local function checkbox(key, label, tooltip, get, set)
    try(function()
        local setting = Settings.RegisterProxySetting(category, "SylsTools_" .. key,
            Settings.VarType.Boolean, label, get() and true or false,
            function() return get() and true or false end,
            function(v) set(v and true or false); ST:Fire("ST_SETTINGS_CHANGED") end)
        Settings.CreateCheckbox(category, setting, tooltip)
    end)
end

local function slider(key, label, tooltip, min, max, step, get, set, fmt)
    try(function()
        local setting = Settings.RegisterProxySetting(category, "SylsTools_" .. key,
            Settings.VarType.Number, label, get(), get,
            function(v) set(v); ST:Fire("ST_SETTINGS_CHANGED") end)
        local options = Settings.CreateSliderOptions(min, max, step)
        if MinimalSliderWithSteppersMixin and options.SetLabelFormatter then
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, fmt)
        end
        Settings.CreateSlider(category, setting, options, tooltip)
    end)
end

local function button(label, buttonText, tooltip, onClick)
    if not CreateSettingsButtonInitializer then return end
    try(function() addInitializer(CreateSettingsButtonInitializer(label, buttonText, onClick, tooltip, true)) end)
end

local function keybinding(action)
    if not (CreateKeybindingEntryInitializer and C_KeyBindings and C_KeyBindings.GetBindingIndex) then return end
    try(function()
        local index = C_KeyBindings.GetBindingIndex(action)
        if index then addInitializer(CreateKeybindingEntryInitializer(index, true)) end
    end)
end

function SettingsPage:Build()
    if category or not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
    local ok, cat, lay = pcall(Settings.RegisterVerticalLayoutCategory, ST.title)
    if not ok or not cat then return end
    category, layout = cat, lay
    if not layout and SettingsPanel and SettingsPanel.GetLayout then
        local ok2, l = pcall(SettingsPanel.GetLayout, SettingsPanel, category)
        if ok2 then layout = l end
    end

    button("Syl's Tools window", "Open", "Opens the full Syl's Tools window (best with mouse & keyboard).",
        function() if ST.UI then ST.UI:Show() end end)

    -- Fishing -----------------------------------------------------------
    local F = ST:GetModule("fishing")
    if F then
        header("Fishing")
        keybinding(F.OneButton and F.OneButton.GAME_BINDING or "CLICK SylsToolsFishingCastButton:LeftButton")
        button("Fishing pole", "Swap", "Equips your fishing pole, or puts your weapons back on.",
            function() F.Gear:Toggle() end)
        checkbox("fishing_autorestore", "Re-equip weapons when done fishing",
            "After you stop fishing and don't cast again for the time below, your weapons go back on.",
            function() return F.cdb.autoRestore end, function(v) F.Gear:SetAutoRestore(v) end)
        slider("fishing_delay", "Wait after last cast", "Seconds before your weapons go back on.",
            10, 600, 10, function() return F.cdb.restoreDelay end, function(v) F.Gear:SetDelay(v) end,
            function(v) return string.format("%ds", v) end)
        checkbox("fishing_hud", "Show fishing HUD while casting", nil,
            function() return F.db.alert.enabled end, function(v) F.db.alert.enabled = v end)
        checkbox("fishing_flash", "Flash screen when cast expires", nil,
            function() return F.db.alert.flashOnExpire end, function(v) F.db.alert.flashOnExpire = v end)
        checkbox("fishing_softtarget", "Show icon over the bobber",
            "Uses the game's soft-target icon so the bobber is easy to spot (and reachable with the interact button).",
            function() return F.db.softTarget end,
            function(v) F.db.softTarget = v; F.OneButton:UpdateSoftTarget() end)
        checkbox("fishing_sound", "Boost splash sound while fishing", nil,
            function() return F.db.sound.focus end,
            function(v) F.db.sound.focus = v; if not v then F.Alert:RestoreSound() end end)
    end

    -- Upcoming Spells -----------------------------------------------------
    local S = ST:GetModule("spells")
    if S then
        header("Upcoming Spells")
        checkbox("spells_tab", "Show a tab on my spellbook", nil,
            function() return S.db.spellbookTab end, function(v) S.db.spellbookTab = v end)
        checkbox("spells_notify", "Tell me what's new when I level up", nil,
            function() return S.db.notifyLevelUp end, function(v) S.db.notifyLevelUp = v end)
    end

    -- Class Guides --------------------------------------------------------
    local G = ST:GetModule("guides")
    if G then
        header("Class Guides")
        checkbox("guides_hide", "Only show abilities I have", nil,
            function() return G.db.hideUnknown end, function(v) G.db.hideUnknown = v end)
    end

    pcall(Settings.RegisterAddOnCategory, category)
end

function SettingsPage:Open()
    if not category or not Settings or not Settings.OpenToCategory then return false end
    local id = category.GetID and category:GetID() or category.ID
    return pcall(Settings.OpenToCategory, id) and true or false
end

function SettingsPage:Category() return category end

ST:On("ST_READY", function() SettingsPage:Build() end)
