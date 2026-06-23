local _, ns = ...

---@diagnostic disable: undefined-global

local NewAlertGUI = {}
ns.NewAlertGUI = NewAlertGUI

local Theme = ns.Theme

local FRAME_WIDTH = 280
local FRAME_HEIGHT = 150
local TITLE_H     = 28
local BTN_W       = 120
local BTN_H       = 34
local BTN_GAP     = 12

local frame = nil

local function Close()
    if frame then frame:Hide() end
end

local function BuildFrame()
    local f = CreateFrame("Frame", "CDMAuras_NewAlertGUI", UIParent, "BackdropTemplate")
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
    titleText:SetText("New CDMAuras Alert")
    titleText:SetTextColor(0.88, 0.98, 0.93, 1)
    f.titleText = titleText

    local closeBtn = Theme.CreateButton(f, 22, 22, "×", { onClick = Close })
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -4, 0)

    -- Prompt label ------------------------------------------------------------
    local promptLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    promptLabel:SetPoint("TOP", f, "TOP", 0, -(TITLE_H + 18))
    promptLabel:SetText("Choose an alert type:")
    promptLabel:SetJustifyH("CENTER")
    promptLabel:SetTextColor(0.88, 0.98, 0.93, 0.85)

    -- Type buttons ------------------------------------------------------------
    local borderBtn = Theme.CreateButton(f, BTN_W, BTN_H,
        "|A:communities-icon-addgroupplus:16:16|a  New Border")
    borderBtn:SetPoint("CENTER", f, "CENTER", -(BTN_W / 2 + BTN_GAP / 2), -6)
    borderBtn:SetScript("OnClick", function()
        local id = f._cooldownID
        Close()
        if ns.AlertEditor and ns.AlertEditor.Open then
            ns.AlertEditor.Open({ cooldownID = id, _editorType = "border" })
        end
    end)

    local glowBtn = Theme.CreateButton(f, BTN_W, BTN_H,
        "|A:communities-icon-addgroupplus:16:16|a  New Glow")
    glowBtn:SetPoint("CENTER", f, "CENTER", BTN_W / 2 + BTN_GAP / 2, -6)
    glowBtn:SetScript("OnClick", function()
        local id = f._cooldownID
        Close()
        if ns.AlertEditor and ns.AlertEditor.Open then
            ns.AlertEditor.Open({ cooldownID = id, _editorType = "glow" })
        end
    end)

    -- Paste button — shown/hidden dynamically in Open() based on clipboard state.
    local pasteButton = Theme.CreateButton(f, BTN_W, BTN_H, "Paste Copied")
    pasteButton:SetPoint("TOP", f, "CENTER", 0, (-1 * (BTN_H)))
    pasteButton:SetScript("OnClick", function()
        local id = f._cooldownID
        Close()
        if ns.AlertEditor and ns.AlertEditor.PasteFromClipboard then
            ns.AlertEditor.PasteFromClipboard(id)
        end
    end)
    pasteButton:Hide()
    f.pasteButton = pasteButton

    f:Hide()
    return f
end

local function PositionFrame()
    if not frame then return end
    local anchor = CooldownViewerSettings
    if anchor then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 45, 0)
    else
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    end
end

function NewAlertGUI.Open(cooldownID)
    if not frame then
        frame = BuildFrame()
    end
    frame._cooldownID = cooldownID
    -- Update paste button visibility based on current clipboard state.
    if frame.pasteButton then
        local clip = ns.AlertClipboard
        if clip and clip.data and clip.alertType then
            local pasteLabel = "Paste Copied "
                .. (clip.alertType == "border" and "Border" or "Glow")
            frame.pasteButton:SetButtonText(pasteLabel)
            frame.pasteButton:Show()
        else
            frame.pasteButton:Hide()
        end
    end
    if frame.titleText then
        local entry = ns.CDMUtils and (
            (ns.CDMUtils.GetBuff  and ns.CDMUtils.GetBuff(cooldownID))
         or (ns.CDMUtils.GetSpell and ns.CDMUtils.GetSpell(cooldownID))
        )
        local spellName = entry and entry.name
        frame.titleText:SetText(spellName and ("New Alert: " .. spellName) or "New CDMAuras Alert")
    end
    PositionFrame()
    frame:Show()
end

function NewAlertGUI.Close()
    Close()
end
