local _, ns = ...
local AlertManager = {}
ns.AlertManager = AlertManager
local placeholderPool  = CreateFramePool("Frame", nil)
local placeholders = {}

local releasePlaceholders = function()
    wipe(placeholders)
    placeholderPool:ReleaseAll()
end

local createPlaceholderFrameForCDMChild = function(child)
    if not child.cooldownID or not child.Icon then return end
    local placeholder = placeholderPool:Acquire()
    placeholder.cooldownID = child.cooldownID
    placeholder:ClearAllPoints()
    placeholder:Show()
    placeholder:SetAllPoints(child)
    placeholder:SetFrameStrata(child:GetFrameStrata())
    placeholder:SetFrameLevel(1000)
    placeholders[placeholder.cooldownID] = placeholder
    placeholder:SetScript("OnSizeChanged", function(self)
        ns.GlowManager.RecreatePlaceholderGlows(self.cooldownID)
    end)
    return placeholder
end

ns.AlertManager.GetPlaceholderFrame = function(cooldownID, child)
    local placeholder = placeholders[cooldownID]
    if not placeholder then
        return createPlaceholderFrameForCDMChild(child)
    end

    return placeholder
end

ns.AlertManager.CreateAll = function()
    releasePlaceholders()
    ns.IconManager.CreateAll()
    ns.CooldownTextManager.CreateAll()
    ns.BuffTextManager.CreateAll()
    ns.BorderManager.CreateAll()
    ns.GlowManager.CreateAll()
    ns.IconManager.CreateAll()
end