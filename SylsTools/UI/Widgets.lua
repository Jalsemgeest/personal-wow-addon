-- Syl's Tools: small widget kit shared by every module page.
-- Only stock Blizzard templates that exist on the modern client are used.

local _, ns = ...
local ST = (ns and ns.ST) or SylsTools
local API = ST.API

local W = {}
ST.Widgets = W

W.COLOR_ACCENT = { 0.71, 0.55, 1.0 }

function W.Header(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetText(text)
    fs:SetJustifyH("LEFT")
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetColorTexture(1, 1, 1, 0.15)
    line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -3)
    line:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    fs.line = line
    return fs
end

function W.Label(parent, text, font, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    if width then fs:SetWidth(width) end
    fs:SetText(text or "")
    return fs
end

function W.Button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 120, 24)
    b:SetText(text)
    b:SetScript("OnClick", function(self, ...) onClick(self, ...) end)
    return b
end

function W.SetTooltip(frame, title, body)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        if body then GameTooltip:AddLine(body, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Checkbox bound to get()/set(value).
function W.Check(parent, label, get, set, tooltip)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    cb.label:SetText(label)
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        ST:Fire("ST_SETTINGS_CHANGED")
    end)
    function cb:Refresh() self:SetChecked(get() and true or false) end
    if tooltip then W.SetTooltip(cb, label, tooltip) end
    return cb
end

-- "- value +" stepper.
function W.Stepper(parent, label, get, set, step, format)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(240, 24)
    f.label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.label:SetPoint("LEFT", 4, 0)
    f.label:SetText(label)
    local minus = W.Button(f, "-", 24, function() set(get() - step) f:Refresh() end)
    local plus = W.Button(f, "+", 24, function() set(get() + step) f:Refresh() end)
    f.value = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    plus:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    f.value:SetPoint("RIGHT", plus, "LEFT", -6, 0)
    f.value:SetWidth(44)
    minus:SetPoint("RIGHT", f.value, "LEFT", -6, 0)
    function f:Refresh() self.value:SetText(string.format(format or "%d", get())) end
    return f
end

-- Square item slot with icon + tooltip.
function W.ItemSlot(parent, size, caption, emptyIcon)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.border = b:CreateTexture(nil, "OVERLAY")
    b.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    b.border:SetPoint("TOPLEFT", -size * 0.32, size * 0.32)
    b.border:SetPoint("BOTTOMRIGHT", size * 0.32, -size * 0.32)
    b.caption = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.caption:SetPoint("TOP", b, "BOTTOM", 0, -4)
    b.caption:SetText(caption or "")
    b.emptyIcon = emptyIcon
    function b:SetItem(link)
        self.link = link
        local icon = link and API.GetItemIcon(link)
        self.icon:SetTexture(icon or self.emptyIcon)
        self.icon:SetDesaturated(not link)
        self.icon:SetAlpha(link and 1 or 0.5)
    end
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.link then
            GameTooltip:SetHyperlink(self.link)
        else
            GameTooltip:SetText(caption or "", 1, 1, 1)
            GameTooltip:AddLine("Empty", 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetItem(nil)
    return b
end

-- Click, then press a key, mouse button 3-5, or controller button to bind. Esc cancels.
local MODIFIERS = { LSHIFT = 1, RSHIFT = 1, LCTRL = 1, RCTRL = 1, LALT = 1, RALT = 1, UNKNOWN = 1 }
function W.KeyBind(parent, width, get, set)
    local b = W.Button(parent, "", width or 120, function() end)
    b:RegisterForClicks("AnyUp")
    local function label()
        b:SetText(b.capturing and "|cffffd100Press a key or button...|r"
            or ("Key: " .. (API.KeyText(get()) or "|cff888888not set|r")))
    end
    local function stop()
        b.capturing = false
        b:EnableKeyboard(false)
        if b.EnableGamePadButton then b:EnableGamePadButton(false) end
        label()
    end
    local function finish(key)
        stop()
        set(key)
        label()
    end
    b:SetScript("OnClick", function(self, button)
        if self.capturing then
            if button == "LeftButton" or button == "RightButton" then return stop() end
            return finish((button:gsub("^Button", "BUTTON")))
        end
        if API.InCombat() then return ST:Print("can't change keys in combat") end
        self.capturing = true
        self:EnableKeyboard(true)
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
        -- Controller buttons arrive as PAD1, PADDDOWN, PADLTRIGGER, ... and are
        -- bindable exactly like keyboard keys.
        if self.EnableGamePadButton then self:EnableGamePadButton(true) end
        label()
    end)
    b:SetScript("OnGamePadButtonDown", function(self, button)
        if not self.capturing then return end
        finish(button)
    end)
    b:SetScript("OnKeyDown", function(self, key)
        if not self.capturing or MODIFIERS[key] then return end
        if key == "ESCAPE" then return stop() end
        local mods = (IsAltKeyDown and IsAltKeyDown() and "ALT-" or "")
            .. (IsControlKeyDown and IsControlKeyDown() and "CTRL-" or "")
            .. (IsShiftKeyDown and IsShiftKeyDown() and "SHIFT-" or "")
        finish(mods .. key)
    end)
    b:SetScript("OnHide", stop)
    function b:Refresh() if not self.capturing then label() end end
    label()
    return b
end

---------------------------------------------------------------------------
-- Scrollable list of rows. Rows are plain tables:
--   { kind = "header", text = "..." }
--   { kind = "item", icon = tex, title = "...", body = "...", dim = bool,
--     spellID = id (tooltip), tooltip = "..." }
--   { kind = "text", text = "..." }   -- wrapped paragraph
---------------------------------------------------------------------------
function W.ScrollList(parent, width)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(width, 10)
    scroll:SetScrollChild(child)
    scroll.child, scroll.width, scroll.pool = child, width, {}

    local function rowFrame(i)
        local r = scroll.pool[i]
        if r then return r end
        r = CreateFrame("Button", nil, child)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(26, 26)
        r.icon:SetPoint("TOPLEFT", 2, -3)
        r.title = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        r.title:SetJustifyH("LEFT")
        r.body = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.body:SetJustifyH("LEFT")
        r.body:SetJustifyV("TOP")
        r.body:SetSpacing(2)
        r:SetScript("OnEnter", function(self)
            local d = self.data
            if not d or not (d.spellID or d.tooltip) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if d.spellID and GameTooltip.SetSpellByID then
                GameTooltip:SetSpellByID(d.spellID)
            else
                GameTooltip:SetText(d.title or "", 1, 1, 1)
            end
            if d.tooltip then GameTooltip:AddLine(d.tooltip, nil, nil, nil, true) end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        scroll.pool[i] = r
        return r
    end

    local function textHeight(fs, fallbackLines)
        local h = fs.GetStringHeight and fs:GetStringHeight()
        if type(h) ~= "number" or h <= 0 then h = 13 * (fallbackLines or 1) end
        return h
    end

    function scroll:SetRows(rows)
        self.rows = rows
        local y = 0
        for i, d in ipairs(rows) do
            local r = rowFrame(i)
            r.data = d
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
            r:SetWidth(width)
            r.title:ClearAllPoints()
            r.body:ClearAllPoints()
            local h
            if d.kind == "header" then
                r.icon:Hide()
                r.body:Hide()
                r.title:SetFontObject("GameFontNormalLarge")
                r.title:SetPoint("TOPLEFT", 0, -8)
                r.title:SetWidth(width)
                r.title:SetText(d.text)
                r.title:Show()
                h = 30
            elseif d.kind == "text" then
                r.icon:Hide()
                r.title:Hide()
                r.body:SetPoint("TOPLEFT", 2, -2)
                r.body:SetWidth(width - 4)
                r.body:SetText(d.text)
                r.body:Show()
                h = textHeight(r.body, 2) + 8
            else
                r.icon:SetTexture(d.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                r.icon:SetDesaturated(d.dim and true or false)
                r.icon:SetAlpha(d.dim and 0.6 or 1)
                r.icon:Show()
                r.title:SetFontObject(d.dim and "GameFontDisable" or "GameFontNormal")
                r.title:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, 0)
                r.title:SetWidth(width - 40)
                r.title:SetText(d.title or "")
                r.title:Show()
                r.body:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -2)
                r.body:SetWidth(width - 40)
                r.body:SetText(d.body or "")
                r.body:SetShown(d.body ~= nil and d.body ~= "")
                h = math.max(32, 3 + textHeight(r.title) + (d.body and (textHeight(r.body, 2) + 4) or 0) + 6)
            end
            r:SetHeight(h)
            r:Show()
            y = y + h
        end
        for i = #rows + 1, #self.pool do self.pool[i]:Hide() end
        child:SetHeight(math.max(y, 10))
    end
    return scroll
end
