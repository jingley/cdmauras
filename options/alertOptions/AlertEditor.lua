local _, ns = ...

---@diagnostic disable: undefined-global

local AlertEditor = {}
ns.AlertEditor = AlertEditor
local Theme = ns.Theme

local FRAME_WIDTH = 320
local FRAME_HEIGHT = 600
local TAB_TOP_Y = -28
local TAB_LEFT_X = 4
local TAB_SPACING = 4
local BOTTOM_PAD = 136
local FIELD_W    = 280   -- shared width: dropdowns, name inputs, and 2-col grids
local TAB_BUTTON_WIDTH = 120
local TAB_BUTTON_HEIGHT = 24
local DEFAULT_ALERT_COLOR = { 1, 0.7882353663444519, 0.1372549086809158, 1 }

local PREVIEW_GLOW_KEY   = "_CDMA_EditorPreview"
local BORDER_MEDIA_ROOT  = "Interface\\AddOns\\CDMAuras\\media\\alerts\\"
local BORDER_TEXTURE_PATH = BORDER_MEDIA_ROOT .. "Border1Square.tga"

--- Build the texture file path from shape/size/blur fields on an alert.
local function GetBorderTexturePath(alert)
    local size  = tostring(tonumber(alert and alert.borderSize)  or 1)
    local shape = (alert and alert.borderShape == "Round") and "Round" or "Square"
    local blur  = (alert and alert.borderBlur  == true)   and "Blur"  or ""
    return BORDER_MEDIA_ROOT .. "Border" .. size .. shape .. blur .. ".tga"
end

local frame = nil
local currentAlert = nil
local isNewAlert = false
local tabButtons = {}
local tabHosts = {}
local activeTabID = nil
local tabIndexByID = {}

-- Alert clipboard — module-scoped, survives across menu opens.
-- Accessible from cdmOptions.lua via ns.AlertClipboard.
ns.AlertClipboard = ns.AlertClipboard or {}

local function GetDB()
    return ns.Utils and ns.Utils.GetDB and ns.Utils.GetDB()
end

local function Trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return value:gsub("^%s+", ""):gsub("%s+$", "")
end

local function DeepCopyColor(source)
    if type(source) ~= "table" then
        return { DEFAULT_ALERT_COLOR[1], DEFAULT_ALERT_COLOR[2], DEFAULT_ALERT_COLOR[3], DEFAULT_ALERT_COLOR[4] }
    end
    return {
        source[1] or DEFAULT_ALERT_COLOR[1],
        source[2] or DEFAULT_ALERT_COLOR[2],
        source[3] or DEFAULT_ALERT_COLOR[3],
        source[4] or DEFAULT_ALERT_COLOR[4],
    }
end

-- Deep-copy an alert object so in-editor mutations don't touch the DB entry.
-- conditions rows are individually copied; color is cloned; all other
-- values are primitives and copied directly.
local function DeepCopyAlert(alert)
    if type(alert) ~= "table" then return {} end
    local copy = {}
    for k, v in pairs(alert) do
        if k == "conditions" and type(v) == "table" then
            local conds = {}
            for i, cond in ipairs(v) do
                local c = {}
                for ck, cv in pairs(cond) do c[ck] = cv end
                conds[i] = c
            end
            copy.conditions = conds
        elseif k == "color" and type(v) == "table" then
            copy.color = DeepCopyColor(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function CreateDefaultAlwaysCondition()
    return { type = "always" }
end

--- Returns true when the cooldownID belongs to a buff source (systemIndex 3/4).
local function IsBuffSource(cooldownID)
    return cooldownID ~= nil
        and ns.CDMUtils and ns.CDMUtils.GetBuff
        and ns.CDMUtils.GetBuff(cooldownID) ~= nil
end

--- Returns the display name for a cooldownID, checking buffs then spells.
local function GetCooldownName(cooldownID)
    if not cooldownID or not ns.CDMUtils then return nil end
    local entry = (ns.CDMUtils.GetBuff  and ns.CDMUtils.GetBuff(cooldownID))
               or (ns.CDMUtils.GetSpell and ns.CDMUtils.GetSpell(cooldownID))
    return entry and entry.name
end

--- Build the mandatory locked "Has Buff" condition for buff-type alerts.
local function CreateLockedBuffCondition(cooldownID)
    return { type = "buff", cooldownID = cooldownID, negate = false, _locked = true }
end

local function SetDefaultGlowFields(glow)
    glow.glowType = glow.glowType or "pixel"
    if glow.glowType == "pixel" then
        glow.pixel_number    = glow.pixel_number    or 8
        glow.pixel_frequency = glow.pixel_frequency or 0.2
        glow.pixel_thickness = glow.pixel_thickness or 2
        glow.pixel_length    = glow.pixel_length    or 3
        glow.pixel_frameLevel = glow.pixel_frameLevel or 5
        if glow.pixel_x      == nil then glow.pixel_x      = 0     end
        if glow.pixel_y      == nil then glow.pixel_y      = 0     end
        if glow.pixel_border == nil then glow.pixel_border = true end
    elseif glow.glowType == "proc" then
        glow.proc_startAnim = glow.proc_startAnim or false
        glow.proc_duration = glow.proc_duration or 1
        glow.proc_frameLevel = glow.proc_frameLevel or 5
    end
end

local function InferAlertType(alert)
    if type(alert) ~= "table" then
        return "border"
    end
    if alert._editorType == "border" or alert._editorType == "glow" then
        return alert._editorType
    end
    if alert.borderKey then
        return "border"
    end
    if alert.glowKey then
        return "glow"
    end
    return "border"
end

local function EnsureAlertDefaults(alert, alertType)
    if type(alert) ~= "table" then
        return
    end

    alert.cooldownID = alert.cooldownID
    -- For buff sources, ensure the mandatory locked "Has Buff" condition
    -- is always present as the first condition.  For other sources default
    -- to the generic "Always" condition.
    if not alert.conditions then
        if IsBuffSource(alert.cooldownID) then
            alert.conditions = { CreateLockedBuffCondition(alert.cooldownID) }
        else
            alert.conditions = { CreateDefaultAlwaysCondition() }
        end
    else
        -- Guard: if the alert is for a buff source but the locked condition
        -- was somehow lost (e.g. imported data), re-inject it at position 1.
        if IsBuffSource(alert.cooldownID) then
            local hasLocked = false
            for _, c in ipairs(alert.conditions) do
                if c._locked then hasLocked = true; break end
            end
            if not hasLocked then
                table.insert(alert.conditions, 1, CreateLockedBuffCondition(alert.cooldownID))
            end
        end
    end
    if alert.anyCondition == nil then
        alert.anyCondition = false
    end
    alert.color = alert.color or DeepCopyColor(nil)

    if alertType == "border" then
        alert.frameLevel  = tonumber(alert.frameLevel) or 1
        alert.borderShape = alert.borderShape or "Square"
        alert.borderSize  = tonumber(alert.borderSize) or 1
        if alert.borderBlur  == nil then alert.borderBlur  = false end
        if alert.applyMask   == nil then alert.applyMask   = false end
    else
        SetDefaultGlowFields(alert)
    end
end

local function GetSettingsAnchor()
    return CooldownViewerSettings
end

local function PositionFrame()
    if not frame then
        return
    end

    local anchor = GetSettingsAnchor()
    if anchor then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 45, 0)
    end
end

local function StopPreview()
    if not frame or not frame.previewTarget then return end
    local target = frame.previewTarget
    local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)
    if LCG then
        LCG.PixelGlow_Stop(target, PREVIEW_GLOW_KEY)
        LCG.ProcGlow_Stop(target, PREVIEW_GLOW_KEY)
    end
    if frame.previewBorderTexture then
        frame.previewBorderTexture:Hide()
    end
end

local function UpdatePreview()
    if not frame or not frame.previewTarget then return end
    if not currentAlert or type(currentAlert) ~= "table" then
        StopPreview()
        return
    end

    local alertType = InferAlertType(currentAlert)
    local color     = currentAlert.color or DEFAULT_ALERT_COLOR
    local r = color[1] or 1
    local g = color[2] or 1
    local b = color[3] or 1
    local a = color[4] or 1

    StopPreview()

    local target = frame.previewTarget
    local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

    if alertType == "glow" and LCG then
        local glowType = currentAlert.glowType or "pixel"
        if glowType == "pixel" then
            LCG.PixelGlow_Start(
                target,
                { r, g, b, a },
                currentAlert.pixel_number    or 8,
                currentAlert.pixel_frequency or 0.2,
                currentAlert.pixel_length    or 3,
                currentAlert.pixel_thickness or 2,
                currentAlert.pixel_x         or 0,
                currentAlert.pixel_y         or 0,
                currentAlert.pixel_border    or false,
                PREVIEW_GLOW_KEY,
                currentAlert.pixel_frameLevel or 5
            )
        elseif glowType == "proc" then
            LCG.ProcGlow_Start(target, {
                color      = { r, g, b, a },
                duration   = currentAlert.proc_duration   or 1,
                startAnim  = currentAlert.proc_startAnim  or false,
                frameLevel = currentAlert.proc_frameLevel or 5,
                key        = PREVIEW_GLOW_KEY,
            })
        end
    elseif alertType == "border" then
        if frame.previewBorderTexture then
            frame.previewBorderTexture:SetTexture(GetBorderTexturePath(currentAlert))
            frame.previewBorderTexture:SetVertexColor(r, g, b, a)
            -- Apply or remove the mask on the preview texture.
            local previewTarget = frame.previewTarget
            if currentAlert.applyMask then
                ns.Utils.ApplyDefaultMaskTexture(previewTarget, frame.previewBorderTexture)
            else
                -- Remove the mask if it was previously applied.
                if previewTarget._cdmaMaskTexture then
                    frame.previewBorderTexture:RemoveMaskTexture(previewTarget._cdmaMaskTexture)
                end
            end
            frame.previewBorderTexture:Show()
        end
    end
end

local function RefreshAddButton()
    if not frame or not frame.addBtn then return end
    local nameEmpty = not currentAlert
        or type(currentAlert) ~= "table"
        or Trim(currentAlert.name or "") == ""
    frame.addBtn:SetButtonEnabled(not nameEmpty)
    -- Tooltip on the disabled button so the user knows why.
    if nameEmpty then
        frame.addBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Enter a name to save this alert.", 1, 0.6, 0.6, true)
            GameTooltip:Show()
        end)
        frame.addBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    else
        frame.addBtn:SetScript("OnEnter", nil)
        frame.addBtn:SetScript("OnLeave", nil)
    end
end

local function CloseFrame()
    StopPreview()
    if frame then
        frame:Hide()
    end
end

local function ClearHostWidgets(host)
    if not host or not host._cdmWidgets then
        return
    end

    for _, widget in ipairs(host._cdmWidgets) do
        if widget then
            widget:Hide()
        end
    end

    wipe(host._cdmWidgets)
end

local function TrackWidget(host, widget)
    host._cdmWidgets = host._cdmWidgets or {}
    host._cdmWidgets[#host._cdmWidgets + 1] = widget
    return widget
end

local function CreateStyledButton(parent, width, height, text, options)
    options = options or {}

    local btn = Theme.CreateButton(parent, width, height, text, {
        kind    = options.kind,
        enabled = options.enabled,
        onClick = options.onClick,
    })

    -- Tab buttons: expose _cdmaRefreshPrimaryTheme so SelectTab can update the
    -- selected highlight without rebuilding the button.
    if options.getSelected ~= nil then
        local getSelected = options.getSelected
        function btn:_cdmaRefreshPrimaryTheme()
            if getSelected() then
                Theme.ApplyBackdrop(self, "header")
                if self._cdmLabel then
                    self._cdmLabel:SetTextColor(1, 1, 1, 1)
                end
            else
                Theme.ApplyBackdrop(self, "panel")
                if self._cdmLabel then
                    self._cdmLabel:SetTextColor(0.88, 0.98, 0.93, 1)
                end
            end
        end

        -- Theme.CreateButton uses SetScript, so its Refresh runs before these
        -- HookScript callbacks. Re-assert the selected backdrop after each
        -- state change so the active tab stays highlighted.
        btn:HookScript("OnEnter",   function(self) self:_cdmaRefreshPrimaryTheme() end)
        btn:HookScript("OnLeave",   function(self) self:_cdmaRefreshPrimaryTheme() end)
        btn:HookScript("OnMouseUp", function(self) self:_cdmaRefreshPrimaryTheme() end)
    end

    return btn
end

local function CreateDropdown(parent, labelText, valueProvider, options, onValueChanged, enabled)
    local function FindLabel(value)
        for _, option in ipairs(options or {}) do
            if option.value == value then return option.label end
        end
        return "Select"
    end

    local dropdown = TrackWidget(parent, Theme.CreateDropdown(
        parent,
        labelText,
        FindLabel(valueProvider()),
        function(self)
            if not MenuUtil or not MenuUtil.CreateContextMenu then return end
            MenuUtil.CreateContextMenu(self, function(_, root)
                for _, option in ipairs(options) do
                    root:CreateRadio(option.label, function()
                        return valueProvider() == option.value
                    end, function()
                        if onValueChanged then onValueChanged(option.value) end
                        self:SetValueText(FindLabel(valueProvider()))
                    end)
                end
            end)
        end,
        { enabled = enabled ~= false, height = 46 }
    ))

    return dropdown
end

local function CreateLabeledEditBox(host, anchor, label, value, onCommit, options)
    options = options or {}

    local row, _, input = Theme.CreateLabeledInput(host, label, value or "", {
        inputWidth  = options.inputWidth  or 180,
        inputHeight = options.inputHeight or 20,
        rowWidth    = options.rowWidth    or FIELD_W,
        rowHeight   = options.rowHeight   or 46,
        setter = function(v)
            if v == "" then return false end
            onCommit(v)
        end,
    })

    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, options.yOffset or -10)
    TrackWidget(host, row)

    return row, input
end

local function GetNextKeyIndex(list, keyField)
    local maxIndex = 0
    for _, item in ipairs(list or {}) do
        local key = item and item[keyField]
        if type(key) == "string" then
            local keyIndex = tonumber(key:match("_(%d+)$"))
            if keyIndex and keyIndex > maxIndex then
                maxIndex = keyIndex
            end
        end
    end
    return maxIndex + 1
end

local function BuildPersistedAlertFromDraft(draft)
    local cooldownID = draft.cooldownID
    local alertType = InferAlertType(draft)
    local db = GetDB()

    if not db or cooldownID == nil then
        return nil
    end

    if alertType == "border" then
        db.borders = db.borders or {}
        db.borders[cooldownID] = db.borders[cooldownID] or {}

        local list = db.borders[cooldownID]
        local keyIndex = GetNextKeyIndex(list, "borderKey")
        local borderKey = string.format(ns.BorderManager.key, cooldownID, keyIndex)
        local name = Trim(draft.name)
        if name == "" then
            name = ns.Utils.GetDefaultBorderName({ borderKey = borderKey })
        end

        local option = {
            cooldownID = cooldownID,
            borderKey = borderKey,
            keyIndex = keyIndex,
            name = name,
            frameLevel = tonumber(draft.frameLevel) or 1,
            borderShape = draft.borderShape or "Square",
            borderSize  = tonumber(draft.borderSize) or 1,
            borderBlur  = draft.borderBlur == true,
            applyMask   = draft.applyMask  == true,
            color = DeepCopyColor(draft.color),
            anyCondition = draft.anyCondition == true,
            conditions = draft.conditions or (IsBuffSource(cooldownID) and { CreateLockedBuffCondition(cooldownID) } or { CreateDefaultAlwaysCondition() }),
        }

        list[#list + 1] = option
        return option, "border"
    end

    db.glows = db.glows or {}
    db.glows[cooldownID] = db.glows[cooldownID] or {}

    local list = db.glows[cooldownID]
    local keyIndex = GetNextKeyIndex(list, "glowKey")
    local glowKey = string.format(ns.GlowManager.key, cooldownID, keyIndex)
    local name = Trim(draft.name)
    if name == "" then
        name = ns.Utils.GetDefaultGlowName({ glowKey = glowKey })
    end

    local option = {
        cooldownID = cooldownID,
        glowKey = glowKey,
        keyIndex = keyIndex,
        name = name,
        color = DeepCopyColor(draft.color),
        anyCondition = draft.anyCondition == true,
        conditions = draft.conditions or (IsBuffSource(cooldownID) and { CreateLockedBuffCondition(cooldownID) } or { CreateDefaultAlwaysCondition() }),
        glowType = draft.glowType or "pixel",
        pixel_frequency = draft.pixel_frequency,
        pixel_thickness = draft.pixel_thickness,
        pixel_length    = draft.pixel_length,
        pixel_frameLevel = draft.pixel_frameLevel,
        pixel_x         = draft.pixel_x,
        pixel_y         = draft.pixel_y,
        pixel_border    = draft.pixel_border,
        proc_startAnim = draft.proc_startAnim,
        proc_duration = draft.proc_duration,
        proc_frameLevel = draft.proc_frameLevel,
    }

    SetDefaultGlowFields(option)
    list[#list + 1] = option
    return option, "glow"
end

-- ---------------------------------------------------------------------------
-- Reusable themed color picker row
-- Creates a labeled container (same style as CreateLabeledInput) with a color
-- swatch. Clicking opens WoW's ColorPickerFrame, themed to match the addon.
-- Preset swatch buttons are injected into the picker for the four stock colors.
-- onChange(colorTable) is called live while dragging and on OK.
-- Returns the container frame so callers can anchor it like any other row.
-- ---------------------------------------------------------------------------

local COLOR_PRESETS = {
    { 1, 0.7882353663444519, 0.1372549086809158, 1 },   -- yellow
    { 1, 0,    0,    1 },                                -- red
    { 0, 1,    0,    1 },                                -- green
    { 0, 0.45, 1,    1 },                                -- blue
}

local function SkinColorPickerFrame(presets, onPresetPicked)
    if not ColorPickerFrame then return end

    -- Dark backdrop overlay (idempotent)
    if not ColorPickerFrame._cdmaOptBg then
        local bg = CreateFrame("Frame", nil, ColorPickerFrame, "BackdropTemplate")
        bg:SetPoint("TOPLEFT",     ColorPickerFrame, "TOPLEFT",     2,  -2)
        bg:SetPoint("BOTTOMRIGHT", ColorPickerFrame, "BOTTOMRIGHT", -2,  2)
        bg:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets   = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        bg:SetFrameLevel(0)
        ColorPickerFrame._cdmaOptBg = bg
    end
    ColorPickerFrame._cdmaOptBg:SetBackdropColor(0.05, 0.07, 0.09, 0.96)
    ColorPickerFrame._cdmaOptBg:SetBackdropBorderColor(0.24, 0.60, 0.52, 0.95)

    if ColorPickerFrame.Border  then ColorPickerFrame.Border:SetAlpha(0)  end
    if ColorPickerFrame.Header  then ColorPickerFrame.Header:Hide()       end

    -- Footer buttons
    local function SkinBtn(btn)
        if not btn or btn._cdmaOptSkinned then return end
        for _, k in ipairs({ "Left", "Middle", "Right", "NormalTexture", "PushedTexture", "HighlightTexture" }) do
            if btn[k] then btn[k]:SetAlpha(0) end
        end
        local f = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        f:SetAllPoints(btn)
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1, insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        f:SetFrameLevel(btn:GetFrameLevel() - 1)
        btn._cdmaOptBg = f
        local lbl = btn.Text or (btn.GetFontString and btn:GetFontString())
        local function Apply(hover)
            f:SetBackdropColor(hover and 0.05 or 0.03, hover and 0.22 or 0.16, hover and 0.18 or 0.13, hover and 0.92 or 0.82)
            f:SetBackdropBorderColor(hover and 0.24 or 0.18, hover and 0.60 or 0.45, hover and 0.52 or 0.38, 0.95)
            if lbl then lbl:SetTextColor(hover and 1 or 0.82, hover and 1 or 0.96, hover and 1 or 0.90, 1) end
        end
        btn:HookScript("OnEnter", function() Apply(true)  end)
        btn:HookScript("OnLeave", function() Apply(false) end)
        Apply(false)
        btn._cdmaOptSkinned = true
    end
    if ColorPickerFrame.Footer then
        SkinBtn(ColorPickerFrame.Footer.OkayButton)
        SkinBtn(ColorPickerFrame.Footer.CancelButton)
    end

    -- Preset swatch column (recreated each open to bind correct callbacks)
    if not ColorPickerFrame._cdmaOptPresets then
        local c = CreateFrame("Frame", nil, ColorPickerFrame)
        c:SetPoint("TOPRIGHT", ColorPickerFrame, "TOPRIGHT", -8, -28)
        c:SetFrameStrata(ColorPickerFrame:GetFrameStrata())
        c:SetFrameLevel(ColorPickerFrame:GetFrameLevel() + 40)
        c._btns = {}
        ColorPickerFrame._cdmaOptPresets = c
    end
    local container = ColorPickerFrame._cdmaOptPresets
    container:SetFrameLevel(ColorPickerFrame:GetFrameLevel() + 40)

    local BW, BH, GAP = 18, 18, 4
    for i, color in ipairs(presets or {}) do
        local btn = container._btns[i]
        if not btn then
            btn = CreateFrame("Button", nil, container, "BackdropTemplate")
            btn:RegisterForClicks("LeftButtonUp")
            btn:SetFrameLevel(container:GetFrameLevel() + 1)
            btn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1, insets = { left = 0, right = 0, top = 0, bottom = 0 },
            })
            local sw = btn:CreateTexture(nil, "ARTWORK")
            sw:SetPoint("TOPLEFT",     btn, "TOPLEFT",     1, -1)
            sw:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
            btn._sw = sw
            btn:HookScript("OnEnter", function(self) self:SetBackdropBorderColor(0.30, 0.70, 0.60, 1) end)
            btn:HookScript("OnLeave", function(self) self:SetBackdropBorderColor(0.18, 0.45, 0.38, 0.95) end)
            btn:SetBackdropBorderColor(0.18, 0.45, 0.38, 0.95)
            container._btns[i] = btn
        end
        btn:ClearAllPoints()
        btn:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -((i - 1) * (BH + GAP)))
        btn:SetSize(BW, BH)
        local r, g, b, a = color[1], color[2], color[3], color[4] or 1
        btn._sw:SetColorTexture(r, g, b, a)
        btn:SetScript("OnClick", function() if onPresetPicked then onPresetPicked({ r, g, b, a }) end end)
        btn:Show()
    end
    for i = #presets + 1, #container._btns do container._btns[i]:Hide() end
    container:SetSize(BW, math.max(1, #presets * (BH + GAP) - GAP))
    container:Show()
end

--- Create a themed color row that opens WoW's ColorPickerFrame.
--- @param host         Frame   (parent, should be tracked)
--- @param anchorFrame  Frame   (SetPoint TOPLEFT anchor)
--- @param colorTable   table   { r, g, b, a }
--- @param onChange     function(colorTable)  called live + on OK
--- @return Frame  (the container row, same height as CreateLabeledInput with rowHeight=46)
local function CreateColorRow(host, anchorFrame, colorTable, onChange)
    local container = CreateFrame("Frame", nil, host, "BackdropTemplate")
    container:SetSize(FIELD_W, 46)
    container:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -8)

    -- Same panel backdrop as CreateLabeledInput
    container:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    container:SetBackdropColor(0.06, 0.07, 0.09, 0.96)
    container:SetBackdropBorderColor(0.18, 0.22, 0.26, 0.95)
    container:EnableMouse(true)
    container:HookScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.26, 0.62, 0.53, 1)
    end)
    container:HookScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.18, 0.22, 0.26, 0.95)
    end)

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -5)
    label:SetText("Color")
    label:SetTextColor(0.52, 0.86, 0.75, 1)

    -- Swatch button
    local swatchBtn = CreateFrame("Button", nil, container, "BackdropTemplate")
    swatchBtn:SetSize(22, 22)
    swatchBtn:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 8, 6)
    swatchBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    swatchBtn:SetBackdropColor(0.06, 0.08, 0.09, 1)
    swatchBtn:SetBackdropBorderColor(0.22, 0.26, 0.30, 0.95)

    local swatch = swatchBtn:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT",     swatchBtn, "TOPLEFT",     1, -1)
    swatch:SetPoint("BOTTOMRIGHT", swatchBtn, "BOTTOMRIGHT", -1,  1)

    local function RefreshSwatch()
        local c = colorTable
        swatch:SetColorTexture(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
    end
    RefreshSwatch()

    swatchBtn:HookScript("OnEnter", function(self) self:SetBackdropBorderColor(0.26, 0.62, 0.53, 1) end)
    swatchBtn:HookScript("OnLeave", function(self) self:SetBackdropBorderColor(0.22, 0.26, 0.30, 0.95) end)

    -- Hex label next to swatch
    local hexLabel = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hexLabel:SetPoint("LEFT",   swatchBtn, "RIGHT", 6,  0)
    hexLabel:SetPoint("BOTTOM", swatchBtn, "BOTTOM", 0, 0)
    hexLabel:SetTextColor(0.88, 0.98, 0.93, 1)
    local function RefreshHex()
        local c = colorTable
        hexLabel:SetText(string.format("%02X%02X%02X",
            math.floor((c[1] or 1) * 255),
            math.floor((c[2] or 1) * 255),
            math.floor((c[3] or 1) * 255)))
    end
    RefreshHex()

    local function OnColorChanged(r, g, b, a)
        colorTable[1] = r
        colorTable[2] = g
        colorTable[3] = b
        colorTable[4] = a or colorTable[4] or 1
        RefreshSwatch()
        RefreshHex()
        if onChange then onChange(colorTable) end
    end

    local function OpenPicker()
        if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
        local c   = colorTable
        local ir  = c[1] or 1
        local ig  = c[2] or 1
        local ib  = c[3] or 1
        local ia  = c[4] or 1

        local function ApplyFromPicker()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            OnColorChanged(r or ir, g or ig, b or ib, ia)
        end
        ColorPickerFrame._cdmaApplyFromPicker = ApplyFromPicker

        SkinColorPickerFrame(COLOR_PRESETS, function(presetColor)
            local r = presetColor[1] or ir
            local g = presetColor[2] or ig
            local b = presetColor[3] or ib
            OnColorChanged(r, g, b, ia)
            if ColorPickerFrame.Content and ColorPickerFrame.Content.ColorPicker
                and ColorPickerFrame.Content.ColorPicker.SetColorRGB then
                ColorPickerFrame.Content.ColorPicker:SetColorRGB(r, g, b)
            end
            if ColorPickerFrame._cdmaApplyFromPicker then
                ColorPickerFrame._cdmaApplyFromPicker()
            end
        end)

        ColorPickerFrame:SetupColorPickerAndShow({
            r            = ir,
            g            = ig,
            b            = ib,
            hasOpacity   = false,
            swatchFunc   = ApplyFromPicker,
            cancelFunc   = function() OnColorChanged(ir, ig, ib, ia) end,
        })
    end

    swatchBtn:SetScript("OnClick", OpenPicker)
    container:SetScript("OnMouseDown", OpenPicker)

    TrackWidget(host, container)
    return container
end

local function RenderBorderSection(host, alert)
    local colW = math.floor((FIELD_W - 4) / 2)

    local subtitle = TrackWidget(host, host:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
    subtitle:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -10)
    subtitle:SetText("Border settings")

    -- Row 1: Border Name (full width) ------------------------------------
    local currentName = Trim(alert.name)
    local nameRow = CreateLabeledEditBox(host, subtitle, "Border Name", currentName, function(value)
        alert.name = value
        RefreshAddButton()
    end)

    -- Row 2: Shape (left) | Outline / Size (right) -----------------------
    local shapeOptions = {
        { value = "Square", label = "Square" },
        { value = "Round",  label = "Round"  },
    }
    local shapeDD = CreateDropdown(host, "Shape", function()
        return alert.borderShape or "Square"
    end, shapeOptions, function(value)
        alert.borderShape = value
        UpdatePreview()
    end)
    shapeDD:SetPoint("TOPLEFT", nameRow, "BOTTOMLEFT", 0, -8)
    shapeDD:SetWidth(colW)
    TrackWidget(host, shapeDD)

    local sizeOptions = {
        { value = 1, label = "Thin"   },
        { value = 2, label = "Medium" },
        { value = 3, label = "Thick"  },
    }
    local sizeDD = CreateDropdown(host, "Outline", function()
        return tonumber(alert.borderSize) or 1
    end, sizeOptions, function(value)
        alert.borderSize = value
        UpdatePreview()
    end)
    sizeDD:SetPoint("TOPLEFT", shapeDD, "TOPRIGHT", 4, 0)
    sizeDD:SetWidth(colW)
    TrackWidget(host, sizeDD)

    -- Row 3: Blur toggle (full width) ------------------------------------
    local blurToggle = Theme.CreateToggle(host, FIELD_W, 46, "Blur",
        alert.borderBlur == true,
        function(checked)
            alert.borderBlur = checked
            UpdatePreview()
        end)
    blurToggle:SetPoint("TOPLEFT", shapeDD, "BOTTOMLEFT", 0, -8)
    TrackWidget(host, blurToggle)

    -- Row 4: Apply Mask toggle (full width) ------------------------------
    local maskToggle = Theme.CreateToggle(host, FIELD_W, 46, "Use Blizzard Default Mask",
        alert.applyMask == true,
        function(checked)
            alert.applyMask = checked
            UpdatePreview()
        end)
    maskToggle:SetPoint("TOPLEFT", blurToggle, "BOTTOMLEFT", 0, -8)
    TrackWidget(host, maskToggle)

    -- Row 5: Color (full width) ------------------------------------------
    local colorRow = CreateColorRow(host, maskToggle, alert.color, function()
        UpdatePreview()
    end)

    -- Row 6: Frame Level (half width) ------------------------------------
    local levelRow = Theme.CreateLabeledInput(host, "Frame Level",
        tostring(tonumber(alert.frameLevel) or 1), {
        rowWidth = colW, rowHeight = 46,
        getter = function() return tostring(tonumber(alert.frameLevel) or 1) end,
        setter = function(v)
            local n = tonumber(v)
            if n and n >= 1 then
                alert.frameLevel = math.floor(n)
            else
                return false
            end
        end,
    })
    levelRow:SetPoint("TOPLEFT", colorRow, "BOTTOMLEFT", 0, -8)
    TrackWidget(host, levelRow)
end

local function RenderGlowSection(host, alert)
    local colW = math.floor((FIELD_W - 4) / 2)

    local subtitle = TrackWidget(host, host:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
    subtitle:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -10)
    subtitle:SetText("Glow settings")

    local currentName = Trim(alert.name)
    local nameRow = CreateLabeledEditBox(host, subtitle, "Glow Name", currentName, function(value)
        alert.name = value
        RefreshAddButton()
    end)

    -- Glow style dropdown ---------------------------------------------------
    local glowTypeOptions = {
        { value = "pixel", label = "Pixel" },
        { value = "proc",  label = "Proc"  },
    }

    local glowTypeDropdown = CreateDropdown(host, "Glow Style", function()
        return alert.glowType or "pixel"
    end, glowTypeOptions, function(value)
        alert.glowType = value
        SetDefaultGlowFields(alert)
        AlertEditor.Refresh()
    end)
    glowTypeDropdown:SetPoint("TOPLEFT", nameRow, "BOTTOMLEFT", 0, -8)
    glowTypeDropdown:SetWidth(colW)

    -- Color picker sits to the right of the glow style dropdown.
    -- CreateColorRow anchors BOTTOMLEFT of anchorFrame; we override that to sit
    -- beside the dropdown instead.
    local glowColorRow = CreateColorRow(host, glowTypeDropdown, alert.color, function()
        UpdatePreview()
    end)
    glowColorRow:SetWidth(colW)
    glowColorRow:ClearAllPoints()
    glowColorRow:SetPoint("TOPLEFT", glowTypeDropdown, "TOPRIGHT", 4, 0)

    -- Helper: number input in a half-width cell ------------------------------
    -- Anchors relative to glowTypeDropdown (left column baseline)
    local function NumInput(anchorRow, anchorSide, labelText, getter, setter, isFloat)
        local row = Theme.CreateLabeledInput(host, labelText,
            tostring(getter()), {
            rowWidth = colW, rowHeight = 46,
            getter = function() return tostring(getter()) end,
            setter = function(v)
                local n = tonumber(v)
                if n then
                    setter(isFloat and n or math.floor(n))
                    UpdatePreview()
                else
                    return false
                end
            end,
        })
        if anchorSide == "right" then
            row:SetPoint("TOPLEFT", anchorRow, "TOPRIGHT", 4, 0)
        else
            row:SetPoint("TOPLEFT", anchorRow, "BOTTOMLEFT", 0, -8)
        end
        TrackWidget(host, row)
        return row
    end

    -- Per-type fields --------------------------------------------------------
    if (alert.glowType or "pixel") == "pixel" then
        -- Row 1: Number (left) | Frequency (right)
        local r1left = NumInput(glowTypeDropdown, "left",
            "Particles",
            function() return alert.pixel_number    or 8   end,
            function(v) alert.pixel_number    = math.max(1, v) end)

        NumInput(r1left, "right",
            "Frequency",
            function() return alert.pixel_frequency or 0.2 end,
            function(v) alert.pixel_frequency = v          end, true)

        -- Row 2: Thickness (left) | Length (right)
        local r2left = NumInput(r1left, "left",
            "Thickness",
            function() return alert.pixel_thickness or 2   end,
            function(v) alert.pixel_thickness = math.max(1, v) end)

        NumInput(r2left, "right",
            "Length",
            function() return alert.pixel_length    or 3   end,
            function(v) alert.pixel_length    = math.max(1, v) end)

        -- Row 3: Frame Level (left) | X Offset (right)
        local r3left = NumInput(r2left, "left",
            "Frame Level",
            function() return alert.pixel_frameLevel or 5  end,
            function(v) alert.pixel_frameLevel = math.max(1, v) end)

        NumInput(r3left, "right",
            "X Offset",
            function() return alert.pixel_x or 0 end,
            function(v) alert.pixel_x = v        end, true)

        -- Row 4: Y Offset (left) | Border toggle (right via full-width toggle)
        local r4left = NumInput(r3left, "left",
            "Y Offset",
            function() return alert.pixel_y or 0 end,
            function(v) alert.pixel_y = v        end, true)

        local borderToggle = Theme.CreateToggle(host, colW, 46,
            "Border",
            alert.pixel_border == true,
            function(checked)
                alert.pixel_border = checked
                UpdatePreview()
            end)
        borderToggle:SetPoint("TOPLEFT", r4left, "TOPRIGHT", 4, 0)
        TrackWidget(host, borderToggle)

    else -- proc
        -- Row 1: Duration (left) | Frame Level (right)
        local r1left = NumInput(glowTypeDropdown, "left",
            "Duration (s)",
            function() return alert.proc_duration   or 1   end,
            function(v) alert.proc_duration   = math.max(0.1, v) end, true)

        NumInput(r1left, "right",
            "Frame Level",
            function() return alert.proc_frameLevel or 5   end,
            function(v) alert.proc_frameLevel = math.max(1, v) end)

        -- Row 2: Start Animation toggle (full width)
        local toggle = Theme.CreateToggle(host, FIELD_W, 34,
            "Start Animation",
            alert.proc_startAnim == true,
            function(checked)
                alert.proc_startAnim = checked
                UpdatePreview()
            end)
        toggle:SetPoint("TOPLEFT", r1left, "BOTTOMLEFT", 0, -8)
        TrackWidget(host, toggle)
    end
end

local function RenderAlertTab(host)
    ClearHostWidgets(host)

    if type(currentAlert) ~= "table" then
        local message = TrackWidget(host, host:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
        message:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -8)
        message:SetText("No alert selected.")
        return
    end

    local alertType = InferAlertType(currentAlert)
    EnsureAlertDefaults(currentAlert, alertType)
    currentAlert._editorType = alertType

    if alertType == "border" then
        RenderBorderSection(host, currentAlert)
    else
        RenderGlowSection(host, currentAlert)
    end
    RefreshAddButton()
    UpdatePreview()
end

local TAB_DEFS = {
    {
        id = "alert",
        label = "Alert",
        render = function(host)
            RenderAlertTab(host)
        end,
    },
    {
        id = "conditions",
        label = "Conditions",
        render = function(host)
            if ns.ConditionEditor and ns.ConditionEditor.RenderInHost then
                ns.ConditionEditor.RenderInHost(host, currentAlert)
            end
        end,
    },
}

local function HideAllTabContent()
    for _, host in pairs(tabHosts) do
        if host then
            host:Hide()
        end
    end
end

local function SelectTab(tabID)
    if not frame then
        return
    end

    local tabIndex = tabIndexByID[tabID]
    if not tabIndex then
        return
    end

    activeTabID = tabID
    HideAllTabContent()

    -- Show preview panel only on the Alert tab; give Conditions the full height.
    local isAlertTab = (tabID == "alert")
    if frame.previewHost then
        frame.previewHost:SetShown(isAlertTab)
    end
    if frame.content then
        frame.content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4,
            isAlertTab and BOTTOM_PAD or 40)
    end
    if not isAlertTab then
        StopPreview()
    end

    for _, button in pairs(tabButtons) do
        if button and button._cdmaRefreshPrimaryTheme then
            button:_cdmaRefreshPrimaryTheme()
        end
    end

    local host = tabHosts[tabID]
    if host then
        host:Show()
    end

    for _, tab in ipairs(TAB_DEFS) do
        if tab.id == tabID and type(tab.render) == "function" and host then
            tab.render(host)
            break
        end
    end
end

local function BuildFrame()
    local TITLE_H   = 30   -- height of the themed title bar
    local TABS_Y    = -(TITLE_H + 4)                      -- tabs row top  (-34)
    local CONTENT_Y = TABS_Y - TAB_BUTTON_HEIGHT - 4      -- content top   (-62)

    local f = CreateFrame("Frame", "CDMAuras_AlertEditor", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(false)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetToplevel(true)
    Theme.ApplyBackdrop(f, "panel")

    -- Title bar ---------------------------------------------------------------
    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, 0)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(TITLE_H)
    Theme.ApplyBackdrop(titleBar, "header")

    -- Accent stripe on the left edge of the title
    local titleAccent = titleBar:CreateTexture(nil, "ARTWORK")
    titleAccent:SetPoint("TOPLEFT",    titleBar, "TOPLEFT",    0, 0)
    titleAccent:SetPoint("BOTTOMLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    titleAccent:SetWidth(3)
    titleAccent:SetColorTexture(0.30, 0.86, 0.70, 1)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT",  titleBar, "LEFT",  10, 0)
    titleText:SetPoint("RIGHT", titleBar, "RIGHT", -28, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(false)
    titleText:SetText("CDMAuras Alert Editor")
    titleText:SetTextColor(0.88, 0.98, 0.93, 1)
    f.TitleText = titleText

    local closeBtn = Theme.CreateButton(f, 22, 22, "×", { onClick = CloseFrame })
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -4, 0)
    f.CloseButton = closeBtn

    -- Tab row -----------------------------------------------------------------
    local tabsRow = CreateFrame("Frame", nil, f)
    tabsRow:SetPoint("TOPLEFT",  f, "TOPLEFT",  TAB_LEFT_X, TABS_Y)
    tabsRow:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16,        TABS_Y)
    tabsRow:SetHeight(TAB_BUTTON_HEIGHT)

    local previousButton
    for index, tab in ipairs(TAB_DEFS) do
        local btn = CreateStyledButton(tabsRow, TAB_BUTTON_WIDTH, TAB_BUTTON_HEIGHT, tab.label, {
            getSelected = function()
                return activeTabID == tab.id
            end,
        })

        if index == 1 then
            btn:SetPoint("TOPLEFT", tabsRow, "TOPLEFT", 0, 0)
        else
            btn:SetPoint("LEFT", previousButton, "RIGHT", TAB_SPACING, 0)
        end

        btn:SetScript("OnClick", function()
            SelectTab(tab.id)
        end)

        tabButtons[tab.id] = btn
        tabIndexByID[tab.id] = index
        previousButton = btn
    end

    -- Content area ------------------------------------------------------------
    local content = CreateFrame("Frame", nil, f, "BackdropTemplate")
    content:SetPoint("TOPLEFT",     f, "TOPLEFT",     4,  CONTENT_Y)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, BOTTOM_PAD)
    f.content = content
    Theme.ApplyBackdrop(content, "panel")

    for _, tab in ipairs(TAB_DEFS) do
        local host = CreateFrame("Frame", nil, content, "BackdropTemplate")
        host:SetAllPoints(content)
        host:Hide()
        Theme.ApplyBackdrop(host, "inset")
        tabHosts[tab.id] = host
    end

    -- Preview section ---------------------------------------------------------
    local previewHost = CreateFrame("Frame", nil, f, "BackdropTemplate")
    previewHost:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",   4, 40)
    previewHost:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 40)
    previewHost:SetHeight(88)
    Theme.ApplyBackdrop(previewHost, "inset")

    local previewLabel = previewHost:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    previewLabel:SetPoint("TOPLEFT", previewHost, "TOPLEFT", 8, -6)
    previewLabel:SetText("Preview")
    previewLabel:SetTextColor(0.52, 0.86, 0.75, 1)

    local previewTarget = CreateFrame("Frame", nil, previewHost, "BackdropTemplate")
    previewTarget:SetSize(64, 64)
    previewTarget:SetPoint("CENTER", previewHost, "CENTER", 0, -4)
    previewTarget:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    previewTarget:SetBackdropColor(0.08, 0.10, 0.12, 1)
    previewTarget:SetBackdropBorderColor(0.22, 0.26, 0.30, 0.8)

    local previewBorderTexture = previewTarget:CreateTexture(nil, "OVERLAY")
    previewBorderTexture:SetAllPoints(previewTarget)
    previewBorderTexture:SetTexture(BORDER_TEXTURE_PATH)
    previewBorderTexture:Hide()

    f.previewTarget        = previewTarget
    f.previewBorderTexture = previewBorderTexture
    f.previewHost          = previewHost

    -- Bottom action buttons ---------------------------------------------------
    local addBtn = CreateStyledButton(f, 110, 26, "Add Alert")
    addBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    addBtn:SetScript("OnClick", function()
        AlertEditor.OnAddAlert()
    end)
    f.addBtn = addBtn

    local cancelBtn = CreateStyledButton(f, 80, 26, "Cancel")
    cancelBtn:SetPoint("RIGHT", addBtn, "LEFT", -6, 0)
    cancelBtn:SetScript("OnClick", CloseFrame)
    f.cancelBtn = cancelBtn

    if CooldownViewerSettings then
        CooldownViewerSettings:HookScript("OnHide", function()
            CloseFrame()
        end)
    end

    f:Hide()
    return f
end

function AlertEditor.Open(alertObject)
    if not frame then
        frame = BuildFrame()
    end

    currentAlert = alertObject
    isNewAlert = AlertEditor.IsNewAlert(alertObject)

    if isNewAlert then
        frame._originalAlertRef = nil
        currentAlert._cdmaPaste = nil   -- paste flag: must not reach the DB
        if frame.TitleText then
            local n = GetCooldownName(currentAlert.cooldownID)
            frame.TitleText:SetText(n and ("New Alert: " .. n) or "New CDMAuras Alert")
        end
        frame.addBtn:SetButtonText("Add Alert")
    else
        -- Work on a deep copy so edits don't persist until Save is clicked.
        frame._originalAlertRef = alertObject
        currentAlert = DeepCopyAlert(alertObject)
        if frame.TitleText then
            local n = GetCooldownName(currentAlert.cooldownID)
            frame.TitleText:SetText(n and ("Edit Alert: " .. n) or "Edit CDMAuras Alert")
        end
        frame.addBtn:SetButtonText("Save Alert")
    end

    EnsureAlertDefaults(currentAlert, InferAlertType(currentAlert))
    activeTabID = "alert"
    AlertEditor.Refresh()
    RefreshAddButton()
    PositionFrame()
    frame:Show()
    SelectTab("alert")
end

function AlertEditor.Close()
    CloseFrame()
end

function AlertEditor.IsVisible()
    return frame and frame:IsShown()
end

function AlertEditor.OnAddAlert()
    if type(currentAlert) ~= "table" or currentAlert.cooldownID == nil then
        CloseFrame()
        return
    end

    if Trim(currentAlert.name or "") == "" then
        return
    end

    if isNewAlert then
        local persisted, alertType = BuildPersistedAlertFromDraft(currentAlert)
        if persisted then
            if alertType == "border" and ns.BorderManager and ns.BorderManager.Initialize then
                ns.BorderManager.Initialize(persisted.cooldownID, persisted)
            elseif alertType == "glow" and ns.GlowManager and ns.GlowManager.Initialize then
                ns.GlowManager.Initialize(persisted.cooldownID, persisted)
            end
        end
    else
        -- Copy all edited fields back to the original DB entry, then update.
        local orig = frame and frame._originalAlertRef
        if orig then
            for k, v in pairs(currentAlert) do orig[k] = v end
        end
        local target = orig or currentAlert
        local alertType = InferAlertType(target)
        if alertType == "border" and ns.BorderManager and ns.BorderManager.Update then
            ns.BorderManager.Update(target.cooldownID, target)
        elseif alertType == "glow" and ns.GlowManager and ns.GlowManager.Update then
            ns.GlowManager.Update(target.cooldownID, target)
        end
    end

    CloseFrame()
    if AlertEditor.onSaved then
        AlertEditor.onSaved()
    end
end

function AlertEditor.Refresh()
    if not frame then
        return
    end
    SelectTab(activeTabID or "alert")
    UpdatePreview()
end

function AlertEditor.GetFrame()
    return frame
end

function AlertEditor.GetAlertObject()
    return currentAlert
end

function AlertEditor.IsNewAlert(alertObject)
    if type(alertObject) ~= "table" then
        return false
    end
    -- Paste drafts carry clipboard fields but must still open as a new unsaved alert.
    if alertObject._cdmaPaste then return true end
    local keyCount = 0
    for _ in pairs(alertObject) do
        keyCount = keyCount + 1
    end
    if keyCount == 1 and alertObject.cooldownID ~= nil then
        return true
    end
    -- Also treat { cooldownID, _editorType } as a new alert (type was pre-set by caller).
    if keyCount == 2 and alertObject.cooldownID ~= nil and alertObject._editorType ~= nil then
        return true
    end
    return false
end

--- Copy an alert to the clipboard, stripping identity fields and locked conditions.
--- The recipient spell's locked conditions are rebuilt by EnsureAlertDefaults on paste.
function AlertEditor.CopyToClipboard(alert)
    if type(alert) ~= "table" then return end
    local copy = DeepCopyAlert(alert)
    -- Strip identity / naming fields so the paste opens as a brand-new alert.
    copy.name        = nil
    copy.borderKey   = nil
    copy.glowKey     = nil
    copy.keyIndex    = nil
    copy.cooldownID  = nil
    copy._editorType = nil
    copy._cdmaPaste  = nil
    -- Strip locked conditions; EnsureAlertDefaults rebuilds them for the target spell.
    if type(copy.conditions) == "table" then
        local filtered = {}
        for _, c in ipairs(copy.conditions) do
            if not c._locked then
                filtered[#filtered + 1] = c
            end
        end
        copy.conditions = #filtered > 0 and filtered or nil
    end
    ns.AlertClipboard.data      = copy
    ns.AlertClipboard.alertType = InferAlertType(alert)
    ns.Utils.Print("Alert copied to clipboard. Use New Alert to Paste it on a Spell/Buff.")
end

--- Open the AlertEditor pre-populated with the clipboard contents.
--- The user must supply a name; locked conditions are rebuilt from the target cooldownID.
function AlertEditor.PasteFromClipboard(cooldownID)
    if not ns.AlertClipboard.data then return end
    local draft = DeepCopyAlert(ns.AlertClipboard.data)
    draft.cooldownID  = cooldownID
    draft._editorType = ns.AlertClipboard.alertType
    draft._cdmaPaste  = true   -- signals IsNewAlert to treat this as a new alert
    AlertEditor.Open(draft)
end
