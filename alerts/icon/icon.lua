-------------------------------------------------------------------------------
--  Custom Icon Alert
--  This is a WIP. Currently allows static change of an icon. I want to add conditionals for this (probably in a no guarantees manner)
--  It's currently factored to be able to handle this, but the logic needs more thought for dealing with multiple icons in case of conflict.
-------------------------------------------------------------------------------
local _, ns = ...
local Icon = {}
ns.Icon = Icon

local HookIconSetTexture = function(source, icon)
    if source._cdmaSetTextureHooked then
        return
    end

    hooksecurefunc(source, "RefreshSpellTexture", function(self)
        if icon.cooldownID ~= source.cooldownID  then return end
        icon:NotifyConditionsActiveChanged()
    end)

    source._cdmaSetTextureHooked = true
end

function Icon:Initialize(option, source)
    self.cooldownID = source.cooldownID
    self.key = option and option.iconKey
    self.source = source
    self._cdmaTextureID = nil

    HookIconSetTexture(source, self)

    -- iconTextureID is a numeric FileID from C_Spell.GetSpellTexture.
    -- SetTexture() accepts numeric FileIDs from non-protected addon APIs safely.
    if option and option.iconTextureID then
        self._cdmaTextureID = option.iconTextureID
    end

    self:InitializeConditional(option)
end

function Icon:NotifyConditionsActiveChanged()
    if self.isConditionsActive then
        self:Show()
    else
        self:Hide()
    end
end

function Icon:Show()
    if self._cdmaTextureID then
        self.iconChanged = true
        self.source:GetIconTexture():SetTexture(self._cdmaTextureID)
    end
end

function Icon:Hide()
    if self.iconChanged and self.source and self.source.RefreshSpellTexture then
        self.iconChanged = false
        self.source:RefreshSpellTexture()
    end
end

function Icon:Destroy()
    self:DestroyConditional()
    self:Hide()
    self.cooldownID = nil
    self.key = nil
    self.source = nil
    self.iconChanged = nil
    self.alphaControl = nil
    self._cdmaTextureID = nil
end
