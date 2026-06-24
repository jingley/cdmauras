local _, ns = ...
local BuffTextManager = {}
ns.BuffTextManager = BuffTextManager
local wipe = wipe
local buffTexts = {}
local shownTexts = {}
local managerFrame = CreateFrame("Frame", "Buff Text Grouped Anchor", UIParent)
ns.BuffTextManagerFrame = managerFrame

local GROW_DIRECTIONS = {
    { text = "Up", value = "UP" },
    { text = "Down", value = "DOWN" },
}

local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local DEFAULT_FONT_SIZE = 18
local DEFAULT_GROW_DIR = "UP"
local DEFAULT_MAX_VISIBLE_ALERTS = 5
local DEFAULT_COLOR = { r = 1, g = 0, b = 0, a = 1 }
local PREVIEW_TEXT = "Buff Name Missing"

local previewFontString = managerFrame:CreateFontString(nil, "OVERLAY")
previewFontString:Hide()

local function GetSetting(layoutName, key, default)
    return ns.EditModeUtils.GetLayoutSetting(managerFrame.editModeName, layoutName, key, default)
end

local function SetSetting(layoutName, key, value)
    ns.EditModeUtils.SetLayoutSetting(managerFrame.editModeName, layoutName, key, value)
end

BuffTextManager.SetupCenterAdjustments = function(fontString)
    if not fontString or issecretvalue(fontString:GetStringWidth()) then
        return
    end

    local managerWidth = managerFrame:GetWidth()
    local width = fontString:GetStringWidth()
    local offset = ((managerWidth - width) * 0.5)
    fontString.managerXOffset = offset
end

local function GetColor()
    local c = GetSetting(nil, "color", DEFAULT_COLOR)
    return c.r or 1, c.g or 0, c.b or 0, c.a or 1
end

BuffTextManager.ApplyFontStyleToText = function(fontString)
    if not fontString then
        return
    end

    local fontSize = GetSetting(nil, "fontSize", DEFAULT_FONT_SIZE)
    local font = GetSetting(nil, "font", DEFAULT_FONT)

    fontString.fontSize = fontSize
    local success = fontString:SetFont(font, fontSize, "OUTLINE")
    if not success and font ~= DEFAULT_FONT then
        fontString:SetFont(DEFAULT_FONT, fontSize, "OUTLINE")
    end
    fontString:SetTextColor(GetColor())
    fontString:SetJustifyH("LEFT")
end

local function ApplyPreviewStyle()
    BuffTextManager.ApplyFontStyleToText(previewFontString)
    previewFontString:SetText(PREVIEW_TEXT)
    previewFontString:ClearAllPoints()
    previewFontString:SetPoint("CENTER", managerFrame, "CENTER", 0, 0)

    managerFrame:SetWidth(previewFontString:GetStringWidth())
    managerFrame:SetHeight(previewFontString:GetStringHeight())
    BuffTextManager.SetupCenterAdjustments(previewFontString)
end

local function GetMaxVisibleAlerts()
    local maxVisible = tonumber(GetSetting(nil, "maxVisibleAlerts", DEFAULT_MAX_VISIBLE_ALERTS)) or DEFAULT_MAX_VISIBLE_ALERTS
    if maxVisible < 0 then
        maxVisible = 0
    end
    return math.floor(maxVisible)
end

local function UpdateAlphaForBuffTexts(editMode)
    for _, buffText in ipairs(buffTexts) do
        local fontString = buffText and buffText.fontString
        if fontString then
            fontString:SetAlpha(editMode and 0 or 1)
        end
    end
end

local function PreviewInEditMode(editMode)
    UpdateAlphaForBuffTexts(editMode)
    if editMode then
        ApplyPreviewStyle()
        previewFontString:Show()
    else
        previewFontString:Hide()
    end
end

local function OnLayoutChanged()
    if not managerFrame.editModeName then
        return
    end

    ApplyPreviewStyle()

    for _, buffText in ipairs(buffTexts) do
        if buffText and buffText.fontString then
            local text = buffText.fontString:GetText()
            BuffTextManager.ApplyFontStyleToText(buffText.fontString)
            buffText.fontString:SetText(text)
            BuffTextManager.SetupCenterAdjustments(buffText.fontString)
        end
    end

    BuffTextManager.UpdatePositions()
end

local function BuildEditModeSettings()
    local SettingType = ns.EditModeUtils.SettingType
    return {
        {
            name = "Font Size",
            kind = SettingType.Slider,
            default = DEFAULT_FONT_SIZE,
            minValue = 8,
            maxValue = 48,
            valueStep = 1,
            allowInput = true,
            formatter = function(v) return tostring(v) end,
            get = function(layout) return GetSetting(layout, "fontSize", DEFAULT_FONT_SIZE) end,
            set = function(layout, value)
                SetSetting(layout, "fontSize", value)
                OnLayoutChanged()
            end,
        },
        {
            name = "Font",
            kind = SettingType.Dropdown,
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
                OnLayoutChanged()
            end,
        },
        {
            name = "Grow Direction",
            kind = SettingType.Dropdown,
            default = DEFAULT_GROW_DIR,
            values = GROW_DIRECTIONS,
            get = function(layout) return GetSetting(layout, "growDirection", DEFAULT_GROW_DIR) end,
            set = function(layout, value)
                SetSetting(layout, "growDirection", value)
                BuffTextManager.UpdatePositions()
            end,
        },
        {
            name = "Max Number of Visible Alerts",
            kind = SettingType.Slider,
            default = DEFAULT_MAX_VISIBLE_ALERTS,
            minValue = 1,
            maxValue = 20,
            valueStep = 1,
            allowInput = true,
            formatter = function(v) return tostring(v) end,
            get = function(layout) return GetSetting(layout, "maxVisibleAlerts", DEFAULT_MAX_VISIBLE_ALERTS) end,
            set = function(layout, value)
                SetSetting(layout, "maxVisibleAlerts", value)
                BuffTextManager.UpdatePositions()
            end,
        },
        {
            name    = "Color",
            kind    = SettingType.Color,
            default = DEFAULT_COLOR,
            get = function(layout) return GetSetting(layout, "color", DEFAULT_COLOR) end,
            set = function(layout, value)
                SetSetting(layout, "color", value)
                OnLayoutChanged()
            end,
        },
    }
end

local function SetupManagerFrame()
    if managerFrame.editModeName then
        return
    end

    managerFrame:ClearAllPoints()
    managerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -110)
    managerFrame:SetSize(150, 20)
    managerFrame.editModeName = managerFrame:GetName()

    ns.EditModeUtils.SetupEditModeAnchor(
        managerFrame,
        BuildEditModeSettings(),
        PreviewInEditMode,
        { x = 0, y = -110 },
        OnLayoutChanged
    )
end

local function GetNextUnusedText()
    for _, buffText in ipairs(buffTexts) do
        if buffText.cooldownID == nil then
            return buffText
        end
    end
end

local function GetBuffTextByCooldownID(cooldownID)
    for _, buffText in ipairs(buffTexts) do
        if buffText.cooldownID == cooldownID then
            return buffText
        end
    end
end

BuffTextManager.UpdateShownText = function(buffText, shown)
    if not buffText then
        return
    end

    if shown then
        if not tContains(shownTexts, buffText) then
            tinsert(shownTexts, buffText)
        end
    else
        for i = #shownTexts, 1, -1 do
            if shownTexts[i] == buffText then
                table.remove(shownTexts, i)
            end
        end
        if buffText.fontString then
            buffText.fontString:SetShown(false)
            buffText.fontString:ClearAllPoints()
        end
    end

    BuffTextManager.UpdatePositions()
end

BuffTextManager.UpdatePositions = function()
    local growDir = managerFrame.editModeName
        and GetSetting(nil, "growDirection", DEFAULT_GROW_DIR)
        or DEFAULT_GROW_DIR
    local growUp = growDir ~= "DOWN"
    local maxVisible = GetMaxVisibleAlerts()

    local previousFrame
    local visibleCount = 0
    local textsToRemove = {}

    for index, buffText in ipairs(shownTexts) do
        local fontString = buffText and buffText.fontString
        if fontString and buffText.cooldownID then
            fontString:ClearAllPoints()
            if visibleCount < maxVisible then
                visibleCount = visibleCount + 1
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
                        fontString:SetPoint("BOTTOMLEFT", managerFrame, "BOTTOMLEFT", fontString.managerXOffset or 0, 0)
                    else
                        fontString:SetPoint("TOPLEFT", managerFrame, "TOPLEFT", fontString.managerXOffset or 0, 0)
                    end
                end
                fontString:SetShown(true)
                previousFrame = fontString
            else
                fontString:SetShown(false)
            end
        else
            tinsert(textsToRemove, index)
        end
    end

    for i = #textsToRemove, 1, -1 do
        table.remove(shownTexts, textsToRemove[i])
    end
end

BuffTextManager.Initialize = function(option, cooldownID)
    local source = ns.CDMUtils.GetBuff(cooldownID)
    if not source then
        return
    end

    local buffText = GetNextUnusedText()
    if not buffText then
        buffText = CreateFromMixins(ns.BuffText)
        tinsert(buffTexts, buffText)
    end

    buffText:Initialize(option, cooldownID)
end

BuffTextManager.Destroy = function(cooldownID)
    local buffText = GetBuffTextByCooldownID(cooldownID)
    if buffText then
        buffText:Destroy()
    end
end

BuffTextManager.DestroyAll = function()
    for _, buffText in ipairs(buffTexts) do
        buffText:Destroy()
    end
    wipe(shownTexts)
end

BuffTextManager.CreateAll = function()
    SetupManagerFrame()
    ApplyPreviewStyle()

    if buffTexts[1] then
        BuffTextManager.DestroyAll()
    end

    local db = ns.Utils.GetDB()
    for cooldownID, option in pairs(db.buffTexts or {}) do
        BuffTextManager.Initialize(option, cooldownID)
    end
end
