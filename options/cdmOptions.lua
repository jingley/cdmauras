local _, ns = ...
local CDMOptions = {}
ns.CDMOptions = CDMOptions

---@diagnostic disable: undefined-global

local iconPickerAnchorProxy = nil

local function GetDB()
    return ns.Utils and ns.Utils.GetDB and ns.Utils.GetDB()
end

local function OpenAlertEditor(alertObject)
    if ns.AlertEditor and ns.AlertEditor.Open then
        ns.AlertEditor.Open(alertObject)
    end
end

local function OpenNewAlertGUI(cooldownID)
    if ns.NewAlertGUI and ns.NewAlertGUI.Open then
        ns.NewAlertGUI.Open(cooldownID)
    end
end

-- Confirmation dialog shown before an alert is permanently deleted.
StaticPopupDialogs["CDMAURAS_CONFIRM_DELETE_ALERT"] = {
    text          = 'Delete alert "%s"?',
    button1       = "Delete",
    button2       = CANCEL,
    OnAccept      = function(self, data)
        if data and data.onDelete then
            data.onDelete()
        end
    end,
    timeout       = 0,
    whileDead     = true,
    hideOnEscape  = true,
    preferredIndex = 3,
}

local function GetPrimaryIconOption(cooldownID)
    local db = GetDB()
    if not db then
        return nil
    end

    local icons = db.icons and db.icons[cooldownID]
    if icons and icons[1] then
        return icons[1]
    end

    return nil
end

local function EnsurePrimaryIconOption(cooldownID)
    local option = GetPrimaryIconOption(cooldownID)
    if option then
        return option
    end

    local db = GetDB()
    if not db then
        return nil
    end

    db.icons = db.icons or {}
    db.icons[cooldownID] = db.icons[cooldownID] or {}

    local keyIndex = 1
    local iconKey = string.format(ns.IconManager.key, cooldownID, keyIndex)
    option = {
        cooldownID = cooldownID,
        keyIndex = keyIndex,
        iconKey = iconKey,
        name = ns.Utils.GetDefaultIconName({ iconKey = iconKey }),
        anyCondition = false,
        conditions = { { type = "always" } },
    }

    table.insert(db.icons[cooldownID], 1, option)
    return option
end

local function BuildCustomizeIconLabel(cooldownID)
    local option = GetPrimaryIconOption(cooldownID)
    if option and option.iconTextureID then
        local textureID = option.iconSpellID and C_Spell.GetSpellTexture(option.iconSpellID)
        if textureID and textureID > 0 then
            return "Change Icon  |T" .. textureID .. ":16:16|t"
        end
        -- Spell texture not available (e.g. unknown to this character); fall
        -- back to the plain-text label that was already there.
        return "Change Icon  [custom - " .. (option.iconSpellID or "?") .. "]"
    end
    return "Change Icon [default]"
end

local function GetOrCreateIconPickerAnchorProxy()
    if iconPickerAnchorProxy then
        return iconPickerAnchorProxy
    end

    local proxy = CreateFrame("Frame", nil, UIParent)
    proxy:SetSize(1, 1)
    proxy:Hide()
    iconPickerAnchorProxy = proxy
    return proxy
end

local function CaptureAnchorPositionFromWidget(widget)
    if not widget or not widget.GetTop or not widget.GetLeft then
        return nil
    end

    local left = widget:GetLeft()
    local top = widget:GetTop()
    if not left or not top then
        return nil
    end

    local widgetScale = widget.GetEffectiveScale and widget:GetEffectiveScale() or 1
    local uiScale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if uiScale == 0 then
        uiScale = 1
    end

    local x = left * widgetScale / uiScale
    local y = top * widgetScale / uiScale

    local proxy = GetOrCreateIconPickerAnchorProxy()
    proxy:ClearAllPoints()
    proxy:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    proxy:Show()
    return proxy
end

local function EnableTextAlert(cooldownID, isBuff)
    local db = GetDB()
    if not db then
        return
    end

    local bucket = isBuff and "buffTexts" or "cooldownTexts"
    db[bucket] = db[bucket] or {}

    if db[bucket][cooldownID] then
        return
    end

    local option = {
        cooldownID = cooldownID,
        anyCondition = false,
        conditions = { { type = "cooldown",  cooldownID = cooldownID} },
    }

    db[bucket][cooldownID] = option

    if isBuff and ns.BuffTextManager and ns.BuffTextManager.Initialize then
        ns.BuffTextManager.CreateAll()
    elseif (not isBuff) and ns.CooldownTextManager and ns.CooldownTextManager.Initialize then
        ns.CooldownTextManager.CreateAll()
    end
end

local function DisableTextAlert(cooldownID, isBuff)
    local db = GetDB()
    if not db then
        return
    end

    local bucket = isBuff and "buffTexts" or "cooldownTexts"
    if db[bucket] then
        db[bucket][cooldownID] = nil
    end

    if isBuff and ns.BuffTextManager and ns.BuffTextManager.Destroy then
        ns.BuffTextManager.Destroy(cooldownID)
    elseif (not isBuff) and ns.CooldownTextManager and ns.CooldownTextManager.Destroy then
        ns.CooldownTextManager.Destroy(cooldownID)
    end
end

local function BuildAlertGroups(cooldownID)
    local db = GetDB()
    if type(db) ~= "table" then
        return {}
    end

    local groups = {}

    local borders = db.borders and db.borders[cooldownID]
    local borderEntries = {}
    if borders and #borders > 0 then
        table.sort(borders, function(a, b)
            return (a.frameLevel or 0) < (b.frameLevel or 0)
        end)
        for index, option in ipairs(borders) do
            local optionIndex = index
            local optionValue = option
            local label = optionValue.name or ("Border " .. tostring(optionIndex))
            borderEntries[#borderEntries + 1] = {
                text = label,
                alert = optionValue,
                onDelete = function()
                    if ns.BorderManager and ns.BorderManager.Destroy then
                        ns.BorderManager.Destroy(cooldownID, optionValue)
                    end
                    table.remove(borders, optionIndex)
                    if #borders == 0 then
                        db.borders[cooldownID] = nil
                    end
                end,
                onCopy = function()
                    if ns.AlertEditor and ns.AlertEditor.CopyToClipboard then
                        ns.AlertEditor.CopyToClipboard(optionValue)
                    end
                end,
            }
        end
    end
    groups[#groups + 1] = { title = "Borders", entries = borderEntries }

    local glows = db.glows and db.glows[cooldownID]
    local glowEntries = {}
    if glows and #glows > 0 then
        for index, option in ipairs(glows) do
            local optionIndex = index
            local optionValue = option
            local label = optionValue.name or ("Glow " .. tostring(optionIndex))
            glowEntries[#glowEntries + 1] = {
                text = label,
                alert = optionValue,
                onDelete = function()
                    if ns.GlowManager and ns.GlowManager.Destroy then
                        ns.GlowManager.Destroy(cooldownID, optionValue)
                    end
                    table.remove(glows, optionIndex)
                    if #glows == 0 then
                        db.glows[cooldownID] = nil
                    end
                end,
                onCopy = function()
                    if ns.AlertEditor and ns.AlertEditor.CopyToClipboard then
                        ns.AlertEditor.CopyToClipboard(optionValue)
                    end
                end,
            }
        end
    end
    groups[#groups + 1] = { title = "Glows", entries = glowEntries }

    return groups
end

local function AttachEditDeleteButtons(elementDescription, onEdit, onDelete, onCopy, alertName)
    if not elementDescription or not elementDescription.AddInitializer then
        return
    end

    elementDescription:AddInitializer(function(button, _, menu)
        if not MenuTemplates then
            return
        end

        local editButton = MenuTemplates.AttachAutoHideGearButton and MenuTemplates.AttachAutoHideGearButton(button)
        if editButton then
            if MenuTemplates.SetUtilityButtonTooltipText then
                MenuTemplates.SetUtilityButtonTooltipText(editButton, "Edit")
            end
            if MenuTemplates.SetUtilityButtonAnchor and MenuVariants and MenuVariants.GearButtonAnchor then
                MenuTemplates.SetUtilityButtonAnchor(editButton, MenuVariants.GearButtonAnchor, button)
            end
            if MenuTemplates.SetUtilityButtonClickHandler then
                MenuTemplates.SetUtilityButtonClickHandler(editButton, function()
                    onEdit()
                    if menu and menu.Close then
                        menu:Close()
                    end
                end)
            end
        end

        local deleteButton = MenuTemplates.AttachAutoHideCancelButton and MenuTemplates.AttachAutoHideCancelButton(button)
        if deleteButton then
            if MenuTemplates.SetUtilityButtonTooltipText then
                MenuTemplates.SetUtilityButtonTooltipText(deleteButton, "Delete")
            end
            if MenuTemplates.SetUtilityButtonAnchor and MenuVariants and MenuVariants.CancelButtonAnchor then
                MenuTemplates.SetUtilityButtonAnchor(deleteButton, MenuVariants.CancelButtonAnchor, editButton or button)
            end
            if MenuTemplates.SetUtilityButtonClickHandler then
                MenuTemplates.SetUtilityButtonClickHandler(deleteButton, function()
                    if menu and menu.Close then menu:Close() end
                    StaticPopup_Show("CDMAURAS_CONFIRM_DELETE_ALERT", alertName, nil, { onDelete = onDelete })
                end)
            end
        end

        -- Copy button: AttachUtilityButton gives us the auto-hide behaviour;
        -- we then swap the texture for the desired atlas icon and anchor manually.
        if onCopy then
            local copyButton = MenuTemplates.AttachUtilityButton
                               and MenuTemplates.AttachUtilityButton(button, "")
            if copyButton then
                if copyButton.Texture then
                    copyButton.Texture:SetAtlas("Gamepad_Ltr_View_32", false)
                end
                copyButton:ClearAllPoints()
                copyButton:SetPoint("RIGHT", deleteButton or button, "LEFT", -4, 0)
                if MenuTemplates.SetUtilityButtonTooltipText then
                    MenuTemplates.SetUtilityButtonTooltipText(copyButton, "Copy settings")
                end
                if MenuTemplates.SetUtilityButtonClickHandler then
                    MenuTemplates.SetUtilityButtonClickHandler(copyButton, function()
                        onCopy()
                    end)
                end
            end
        end
    end)
end

local function AddBuffOrCooldownTextToggle(rootDescription, cooldownID, isBuff, onChange)
    local db = GetDB()
    if not db then
        return
    end

    local bucket = isBuff and "buffTexts" or "cooldownTexts"
    local label = isBuff and "Buff Missing Text" or "Cooldown Text"

    if rootDescription.CreateCheckbox then
        rootDescription:CreateCheckbox(
            label,
            function()
                return db[bucket] and db[bucket][cooldownID] ~= nil
            end,
            function()
                -- Do not rely on the isChecked argument; the menu system passes
                -- the pre-click state, which would invert the intended action.
                if db[bucket] and db[bucket][cooldownID] then
                    DisableTextAlert(cooldownID, isBuff)
                else
                    EnableTextAlert(cooldownID, isBuff)
                end
                if onChange then onChange() end
            end
        )
    else
        local enabled = db[bucket] and db[bucket][cooldownID] ~= nil
        local fallbackLabel = (enabled and "Disable " or "Enable ") .. label
        rootDescription:CreateButton(fallbackLabel, function()
            if enabled then
                DisableTextAlert(cooldownID, isBuff)
            else
                EnableTextAlert(cooldownID, isBuff)
            end
            if onChange then onChange() end
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Alert badge helpers (top-left overlay on CooldownViewerSettings list items)
-- ---------------------------------------------------------------------------

local BADGE_SIZE  = 16
local BADGE_ATLAS = "adventureguide-microbutton-alert"

-- Badges keyed by cooldownID; avoids touching Blizzard-owned item frames.
local settingsBadges = {}

local function GetAlertCount(cooldownID)
    local db = GetDB()
    if not db then return 0 end
    local count = 0
    if db.cooldownTexts and db.cooldownTexts[cooldownID] then count = count + 1 end
    if db.buffTexts     and db.buffTexts[cooldownID]     then count = count + 1 end
    local icons   = db.icons   and db.icons[cooldownID]
    local borders = db.borders and db.borders[cooldownID]
    local glows   = db.glows   and db.glows[cooldownID]
    if icons and next(icons) then count = count + #icons   end
    if borders and next(borders) then count = count + #borders end
    if glows and next(glows)then count = count + #glows   end
    return count
end

local function RefreshSettingsItemBadges()
    if not CooldownViewerSettings or not CooldownViewerSettings.categoryPool then return end

    -- Hide all existing badges first; we'll re-anchor them below.
    for _, badge in pairs(settingsBadges) do
        badge:Hide()
    end

    for category in CooldownViewerSettings.categoryPool:EnumerateActive() do
        if category.itemPool then
            for item in category.itemPool:EnumerateActive() do
                local cooldownID = item.cooldownID
                if cooldownID and GetAlertCount(cooldownID) > 0 then
                    local badge = settingsBadges[cooldownID]
                    if not badge then
                        badge = CreateFrame("Frame", nil, UIParent)
                        badge:SetSize(BADGE_SIZE, BADGE_SIZE)
                        local tex = badge:CreateTexture(nil, "OVERLAY")
                        tex:SetAllPoints(badge)
                        tex:SetAtlas(BADGE_ATLAS)
                        settingsBadges[cooldownID] = badge
                    end
                    badge:ClearAllPoints()
                    badge:SetPoint("TOPLEFT", item, "TOPLEFT", 0, 0)
                    badge:SetParent(item)
                    badge:Raise()
                    badge:Show()
                end
            end
        end
    end
end

function CDMOptions.SetupMenu()
    if CDMOptions.menuSetup then
        return
    end

    Menu.ModifyMenu("MENU_COOLDOWN_SETTINGS_ITEM", function(owner, rootDescription, contextData)
        local cooldownID = owner and owner.cooldownID
        if cooldownID == nil and type(contextData) == "table" then
            cooldownID = contextData.cooldownID
        end

        if cooldownID == nil then
            return
        end

        local isBuff = ns.CDMUtils and ns.CDMUtils.GetBuff and ns.CDMUtils.GetBuff(cooldownID)

        rootDescription:CreateDivider()
        rootDescription:CreateTitle("|cff4DDBB3CDMAuras Settings|r")
        rootDescription:CreateButton("|A:communities-icon-addgroupplus:16:16|a New Alert", function()
            OpenNewAlertGUI(cooldownID)
        end)
        AddBuffOrCooldownTextToggle(rootDescription, cooldownID, isBuff and true or false, RefreshSettingsItemBadges)

        local iconButtonAnchor = nil
        local customizeIconRow = rootDescription:CreateButton(BuildCustomizeIconLabel(cooldownID), function()
            if not ns.AlertIconPicker then
                return
            end

            -- Only read existing data for prefill; do NOT create a DB entry yet.
            local existing       = GetPrimaryIconOption(cooldownID)
            local initialRef     = existing and existing.iconTextureID
            local initialSpellID = existing and existing.iconSpellID
            local anchorProxy    = CaptureAnchorPositionFromWidget(owner)

            ns.AlertIconPicker:Open(initialRef, function(textureID, spellID)
                -- User confirmed a valid texture — create or update the option now.
                local option = EnsurePrimaryIconOption(cooldownID)
                if not option then return end
                option.iconTextureID = textureID
                option.iconSpellID   = spellID

                if ns.IconManager and ns.IconManager.Update then
                    ns.IconManager.Update(cooldownID, option)
                end
                RefreshSettingsItemBadges()
            end, anchorProxy, initialSpellID, function()
                -- Remove the primary icon option entirely from the DB.
                local db = GetDB()
                if db and db.icons and db.icons[cooldownID] then
                    table.remove(db.icons[cooldownID], 1)
                    if #db.icons[cooldownID] == 0 then
                        db.icons[cooldownID] = nil
                    end
                end
                if ns.IconManager and ns.IconManager.Update then
                    ns.IconManager.Update(cooldownID, nil)
                end
                RefreshSettingsItemBadges()
            end)
        end)

        if customizeIconRow and customizeIconRow.AddInitializer then
            customizeIconRow:AddInitializer(function(button)
                iconButtonAnchor = button
            end)
        end

        local groups = BuildAlertGroups(cooldownID)

        for _, group in ipairs(groups) do
            if #group.entries > 0 then
                rootDescription:CreateDivider()
                rootDescription:CreateTitle("|cff85DBBF" .. group.title .. "|r")
                for _, entry in ipairs(group.entries) do
                    local row = rootDescription:CreateButton(entry.text, function()
                        OpenAlertEditor(entry.alert)
                    end)

                    AttachEditDeleteButtons(
                        row,
                        function()
                            OpenAlertEditor(entry.alert)
                        end,
                        function()
                            entry.onDelete()
                            RefreshSettingsItemBadges()
                        end,
                        entry.onCopy,
                        entry.text
                    )
                end
            end
        end

         rootDescription:CreateDivider()
    end)

    CDMOptions.menuSetup = true

    if ns.AlertEditor then
        ns.AlertEditor.onSaved = RefreshSettingsItemBadges
    end

    if CooldownViewerSettings and CooldownViewerSettings.RefreshLayout then
        hooksecurefunc(CooldownViewerSettings, "RefreshLayout", function()
            RefreshSettingsItemBadges()
        end)
    end
end
