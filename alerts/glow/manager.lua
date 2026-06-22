local _, ns = ...
local GlowManager = {}
ns.GlowManager = GlowManager
local glows = {}
ns.GlowManager.shownSpellAlerts = {}
GlowManager.key = "_CDMA_Glow_%s_%s"

local HasCreatedGlow = function ()
    return glows[1]
end

local GetNextUnusedGlow = function()
    for _, glow in ipairs(glows) do
        if glow.cooldownID == nil then
            return glow
        end
    end
end

GlowManager.GetGlow = function (cooldownID, options)
    for index, glow in ipairs(glows) do
        if glow.cooldownID == cooldownID and glow.key == options.glowKey  then
            return glow, index
        end
    end
end

GlowManager.Initialize = function(cooldownID, option)
    local source = ns.CDMUtils.GetCDMSourceByID(cooldownID)
    if source and option.cooldownID and option.name then
        local glow = GetNextUnusedGlow()
        if not glow then
            glow = CreateFromMixins(ns.ConditionalMixin.Meta, ns.CustomGlow)
            tinsert(glows, glow)
        end
        glow:Initialize(option, source)
    end
end

GlowManager.Update = function(cooldownID, option)
    local currentGlow = GlowManager.Destroy(cooldownID, option)
    if currentGlow then
        GlowManager.Initialize(cooldownID, option)
    end
end

GlowManager.Destroy = function(cooldownID, option)
    local glow, index = GlowManager.GetGlow(cooldownID, option)
    if glow then
        glow:Destroy()
        return true
    end
end

GlowManager.DestroyAll = function()
    for _, glow in ipairs(glows) do
        glow:Destroy()
    end
end

GlowManager.CreateAll = function()
    if HasCreatedGlow() then
        GlowManager.DestroyAll()
    end
    for cooldownID, options in pairs(ns.Utils.GetDB().glows) do
        for _, option in ipairs(options) do
            GlowManager.Initialize(cooldownID, option)
        end
    end
end