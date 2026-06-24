local _, ns = ...
local CooldownTextManager = {}
ns.CooldownTextManager = CooldownTextManager
local wipe = wipe
local cooldownTexts = {}
local shownTexts = {}
local managerFrame = CreateFrame("Frame", "Cooldown Text Grouped Anchor", UIParent)
ns.CooldownTextManagerFrame = managerFrame

local GROW_DIRECTIONS = {
    { text = "Up",   value = "UP" },
    { text = "Down", value = "DOWN" },
}
local DEFAULT_FONT            = "Fonts\\FRIZQT__.TTF"
local DEFAULT_FONT_SIZE       = 20
local DEFAULT_GROW_DIR        = "UP"
local DEFAULT_COLOR           = { r = 1, g = 1, b = 1, a = 1 }
local DEFAULT_UPDATE_INTERVAL = 1
local DEFAULT_PRECISION       = "whole"
local PRECISION_OPTIONS       = {
    { text = "Whole number  (e.g. 5)",        value = "whole"   },
    { text = "1 decimal place  (e.g. 4.7)",   value = "decimal" },
}
local PREVIEW_TEXT = "No Cooldown Spell 10"

local previewFontString = ns.CooldownTextManagerFrame:CreateFontString(nil, "OVERLAY")
previewFontString:Hide()

CooldownTextManager.SetupCenterAdjustments = function(fontString)
    --centering isn't perfect because I dind't like the frame wiggling as the timer counted down. So this is an estimate off an assumed max width.
    if not issecretvalue(fontString:GetStringWidth()) then
        local managerWidth = managerFrame:GetWidth()
        local width = fontString:GetStringWidth()
        local offset = ((managerWidth - width) * 0.5)
        fontString.managerXOffset = offset
    end
end

local GetSetting = function(layoutName, key, default)
    return ns.EditModeUtils.GetLayoutSetting(managerFrame.editModeName, layoutName, key, default)
end

local SetSetting = function(layoutName, key, value)
    ns.EditModeUtils.SetLayoutSetting(managerFrame.editModeName, layoutName, key, value)
end

local GetColor = function()
    local c = GetSetting(nil, "color", DEFAULT_COLOR)
    return c.r or 1, c.g or 1, c.b or 1, c.a or 1
end

local ApplyPreviewStyle = function()
    local fontSize = GetSetting(nil, "fontSize", DEFAULT_FONT_SIZE)
    local font = GetSetting(nil, "font", DEFAULT_FONT)
    previewFontString.fontSize = fontSize
    local success = previewFontString:SetFont(font, fontSize, "OUTLINE")
    if not success and font ~= DEFAULT_FONT then
        previewFontString:SetFont(DEFAULT_FONT, fontSize, "OUTLINE")
    end
    previewFontString:SetTextColor(GetColor())
    previewFontString:SetText(PREVIEW_TEXT)
    previewFontString:SetJustifyH("LEFT")
    previewFontString:ClearAllPoints()
    previewFontString:SetPoint("CENTER", managerFrame, "CENTER", 0, 0)
    managerFrame:SetWidth(previewFontString:GetStringWidth())
    managerFrame:SetHeight(previewFontString:GetStringHeight())
    CooldownTextManager.SetupCenterAdjustments(previewFontString)
end

local BuildEditModeSettings = function()
    local SettingType = ns.EditModeUtils.SettingType
    return {
        {
            name      = "Font Size",
            kind      = SettingType.Slider,
            default   = DEFAULT_FONT_SIZE,
            minValue  = 8,
            maxValue  = 48,
            valueStep = 1,
            allowInput = true,
            formatter = function(v) return tostring(v) end,
            get = function(layout) return GetSetting(layout, "fontSize", DEFAULT_FONT_SIZE) end,
            set = function(layout, value)
                SetSetting(layout, "fontSize", value)
                ApplyPreviewStyle()
            end,
        },
        {
            name    = "Font",
            kind    = SettingType.Dropdown,
            default = DEFAULT_FONT,
            generator = function(_, rootDescription, data)
                for _, font in ipairs(ns.Utils.GetFontOptions()) do
                    rootDescription:CreateRadio(font.text, function(option)
                        local editMode = LibStub and LibStub("LibEQOLEditMode-1.0", true)
                        local activeLayout = editMode and editMode:GetActiveLayoutName() or nil
                        return data.get(activeLayout) == option.value
                    end, function(option)
                        local editMode = LibStub and LibStub("LibEQOLEditMode-1.0", true)
                        local activeLayout = editMode and editMode:GetActiveLayoutName() or nil
                        data.set(activeLayout, option.value)
                    end, font)
                end
            end,
            get = function(layout) return GetSetting(layout, "font", DEFAULT_FONT) end,
            set = function(layout, value)
                SetSetting(layout, "font", value)
                ApplyPreviewStyle()
            end,
        },
        {
            name    = "Grow Direction",
            kind    = SettingType.Dropdown,
            default = DEFAULT_GROW_DIR,
            values  = GROW_DIRECTIONS,
            get = function(layout) return GetSetting(layout, "growDirection", DEFAULT_GROW_DIR) end,
            set = function(layout, value)
                SetSetting(layout, "growDirection", value)
            end,
        },
        {
            name    = "Color",
            kind    = SettingType.Color,
            default = DEFAULT_COLOR,
            get = function(layout) return GetSetting(layout, "color", DEFAULT_COLOR) end,
            set = function(layout, value)
                SetSetting(layout, "color", value)
                ApplyPreviewStyle()
            end,
        },
        {
            name      = "Update Interval (seconds)",
            kind      = SettingType.Slider,
            default   = DEFAULT_UPDATE_INTERVAL,
            minValue  = 0.1,
            maxValue  = 5,
            valueStep = 0.1,
            allowInput = true,
            tooltip   = "How often each cooldown text refreshes. Lower values are smoother but increase CPU usage per spell on cooldown.",
            formatter = function(v) return string.format("%.1f", v) end,
            get = function(layout) return GetSetting(layout, "updateInterval", DEFAULT_UPDATE_INTERVAL) end,
            set = function(layout, value)
                SetSetting(layout, "updateInterval", math.max(0.1, value))
            end,
        },
        {
            name    = "Display Precision",
            kind    = SettingType.Dropdown,
            default = DEFAULT_PRECISION,
            values  = PRECISION_OPTIONS,
            get = function(layout) return GetSetting(layout, "precision", DEFAULT_PRECISION) end,
            set = function(layout, value)
                SetSetting(layout, "precision", value)
            end,
        },
    }
end

local GetNextUnusedText = function()
    for _, cooldownText in ipairs(cooldownTexts) do
        if cooldownText.cooldownID == nil then
            return cooldownText
        end
    end
end

local UpdateAlphaForCooldownTexts = function(editMode)
    for _, cooldownText in ipairs(cooldownTexts) do
        if cooldownText.cooldownObject then
            local fontString = cooldownText.cooldownObject.fontString
            if fontString then
                fontString:SetAlpha(editMode and 0 or 1)
            end
        end
    end
end

local PreviewInEditMode = function (editMode)
    UpdateAlphaForCooldownTexts(editMode)
    if editMode then
        ApplyPreviewStyle()
        previewFontString:Show()
    else
        previewFontString:Hide()
    end
end

local OnLayoutChanged = function()
    if not managerFrame.editModeName then return end
    ApplyPreviewStyle()
    CooldownTextManager.CreateAll()
end

local SetupManagerFrame = function ()
    if not managerFrame.editModeName then
        managerFrame:ClearAllPoints()
        managerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        managerFrame:SetSize(150, 20)
        managerFrame.editModeName = managerFrame:GetName()
        ns.EditModeUtils.SetupEditModeAnchor(managerFrame, BuildEditModeSettings(), PreviewInEditMode, { x = 0, y = 60 }, OnLayoutChanged)
    end
end

local GetCooldownTextByCooldownID = function (cooldownID)
    for index, cooldownText in ipairs(cooldownTexts) do
        if cooldownText.cooldownID == cooldownID then
            return cooldownText, index
        end
    end
end

CooldownTextManager.UpdateShownText = function(cooldownText, fontString, shown)
    fontString:ClearAllPoints()
    if shown and not tContains(shownTexts, cooldownText) then
        tinsert(shownTexts, cooldownText)
    end
    CooldownTextManager.UpdatePositions()
end

CooldownTextManager.UpdatePositions = function ()
    local growDir = managerFrame.editModeName
        and GetSetting(nil, "growDirection", DEFAULT_GROW_DIR)
        or DEFAULT_GROW_DIR
    local growUp = growDir ~= "DOWN"

    local previousFrame
    local textsToRemove = {}
    for index, cooldownText in ipairs(shownTexts) do
        local fontString = cooldownText.cooldownObject and cooldownText.cooldownObject.fontString
        if fontString and fontString:IsShown() then
            fontString:ClearAllPoints()
            if previousFrame then
                local previousOffset = previousFrame.managerXOffset or 0
                local currentOffset = fontString.managerXOffset or 0
                local xOffset = currentOffset - previousOffset
                if growUp then
                    fontString:SetPoint("BOTTOMLEFT", previousFrame, "TOPLEFT", xOffset, 5)
                else
                    fontString:SetPoint("TOPLEFT", previousFrame, "BOTTOMLEFT", xOffset, -5)
                end
            else
                if growUp then
                    fontString:SetPoint("BOTTOMLEFT", managerFrame, "BOTTOMLEFT", fontString.managerXOffset, 0)
                else
                    fontString:SetPoint("TOPLEFT", managerFrame, "TOPLEFT", fontString.managerXOffset, 0)
                end
            end
            previousFrame = fontString
        else
            tinsert(textsToRemove, index)
        end
    end

    for _, removalIndex in ipairs(textsToRemove) do
        table.remove(shownTexts, removalIndex)
    end
end

CooldownTextManager.Initialize = function(option, cooldownID)
    local source = ns.CDMUtils.GetCDMSourceByID(cooldownID)
    if source then
        local cooldownText = GetNextUnusedText()
        if not cooldownText then
            cooldownText = CreateFromMixins(ns.ConditionalMixin.Meta, ns.CooldownText)
            tinsert(cooldownTexts, cooldownText)
        end
        cooldownText:Initialize(option, cooldownID)
    end
end

CooldownTextManager.Destroy = function(cooldownID)
    local cooldownText, _ = GetCooldownTextByCooldownID(cooldownID)
    if cooldownText then
        cooldownText:Destroy()
    end
end

CooldownTextManager.DestroyAll = function()
    for _, cooldownText in ipairs(cooldownTexts) do
        cooldownText:Destroy()
    end
    wipe(shownTexts)
end

CooldownTextManager.CreateAll = function()
    SetupManagerFrame()
    ApplyPreviewStyle()
    if cooldownTexts[1] then
        CooldownTextManager.DestroyAll()
    end
    for cooldownID, option in pairs(ns.Utils.GetDB().cooldownTexts) do
        CooldownTextManager.Initialize(option, cooldownID)
    end
end

