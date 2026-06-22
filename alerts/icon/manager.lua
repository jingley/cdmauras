local _, ns = ...
local IconManager = {}
ns.IconManager = IconManager
local icons = {}
IconManager.key = "_CDMA_Icon_%s_%s"

local GetNextUnusedIcon = function()
    for _, icon in ipairs(icons) do
        if icon.cooldownID == nil then
            return icon
        end
    end
end

local HasCreatedIcon = function()
    return icons[1]
end

IconManager.GetIcon = function(cooldownID, option)
    for index, icon in ipairs(icons) do
        if icon.cooldownID == cooldownID and icon.key == option.iconKey then
            return icon, index
        end
    end
end

IconManager.Initialize = function(cooldownID, option)
    local source = ns.CDMUtils.GetCDMSourceByID(cooldownID)
    local hasCustomTexture = option and (option.spellID or option.iconTextureID)
    if source and source.Icon and option and option.iconKey and hasCustomTexture then
        local icon = GetNextUnusedIcon()
        if not icon then
            icon = CreateFromMixins(ns.ConditionalMixin.Meta, ns.Icon)
            tinsert(icons, icon)
        end
        icon:Initialize(option, source)
    end
end

IconManager.Update = function(cooldownID, option)
    local currentIcon = IconManager.Destroy(cooldownID, option)
    if currentIcon then
        IconManager.Initialize(cooldownID, option)
    elseif option and (option.spellID or option.iconTextureID) then
        IconManager.Initialize(cooldownID, option)
    end
end

IconManager.Destroy = function(cooldownID, option)
    if not option then
        return
    end
    local icon = IconManager.GetIcon(cooldownID, option)
    if icon then
        icon:Destroy()
        return true
    end
end

IconManager.DestroyAll = function()
    for _, icon in ipairs(icons) do
        icon:Destroy()
    end
end

IconManager.ResetAll = IconManager.DestroyAll

IconManager.CreateAll = function()
    if HasCreatedIcon() then
        IconManager.DestroyAll()
    end
    ns.Utils.GetDB().icons = ns.Utils.GetDB().icons or {}
    for cooldownID, options in pairs(ns.Utils.GetDB().icons) do
        for _, option in ipairs(options) do
            IconManager.Initialize(cooldownID, option)
        end
    end
end