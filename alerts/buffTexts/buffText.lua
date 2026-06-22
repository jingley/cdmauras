-------------------------------------------------------------------------------
--  Buff Text Alert
--  Displays a missing-buff text alert and reuses a pooled FontString per alert slot.
-------------------------------------------------------------------------------
local _, ns = ...
local BuffText = {}
ns.BuffText = BuffText
local FALLBACK_MISSING_TEXT = "Buff Name Missing"

local function GetMissingText(cooldownID)
    local db = ns.Utils and ns.Utils.GetDB and ns.Utils.GetDB()
    local spellNames = db and db.spellNames
    local name = spellNames and spellNames[cooldownID]
    if type(name) == "string" and name ~= "" then
        name = name:gsub("^Buff:%s*", "")
        if name ~= "" then
            return string.format("%s Missing", name)
        end
    end

    return FALLBACK_MISSING_TEXT
end

function BuffText:Show()
    if not self.fontString then
        return
    end

    self.fontString:SetText(GetMissingText(self.cooldownID))
    ns.BuffTextManager.SetupCenterAdjustments(self.fontString)
    ns.BuffTextManager.UpdateShownText(self, true)
end

function BuffText:Hide()
    if not self.fontString then
        return
    end

    ns.BuffTextManager.UpdateShownText(self, false)
end

local function CDMA_AURA_ADD(self, auraData)
    if not auraData or auraData.cooldownID ~= self.cooldownID then
        return
    end
    self:Hide()
end

local function CDMA_AURA_REMOVE(self, cooldownID)
    if cooldownID ~= self.cooldownID then
        return
    end
    self:Show()
end

function BuffText:Initialize(option, cooldownID)
    self.cooldownID = cooldownID
    self.option = option

    if not self.fontString then
        self.fontString = ns.BuffTextManagerFrame:CreateFontString(nil, "OVERLAY")
        self.fontString:SetShown(false)
    end

    ns.BuffTextManager.ApplyFontStyleToText(self.fontString)
    self.fontString:SetText(GetMissingText(self.cooldownID))
    ns.BuffTextManager.SetupCenterAdjustments(self.fontString)
    self.fontString:ClearAllPoints()
    self.fontString:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self.fontString:SetShown(false)

    ns.Engine.API.RegisterInternalMessage("CDMA_AURA_ADD", CDMA_AURA_ADD, self)
    ns.Engine.API.RegisterInternalMessage("CDMA_AURA_REMOVE", CDMA_AURA_REMOVE, self)

    local aura = ns.Engine.API.GetAura(self.cooldownID)
    if aura then
        self:Hide()
    else
        self:Show()
    end
end

function BuffText:Destroy()
    ns.Engine.API.UnregisterAllInternalMessages(self)
    self:Hide()

    if self.fontString then
        self.fontString:SetShown(false)
        self.fontString:ClearAllPoints()
        self.fontString:ClearText()
    end

    self.cooldownID = nil
    self.option = nil
end
