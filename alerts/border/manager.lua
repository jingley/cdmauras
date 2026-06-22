local _, ns = ...
local BorderManager = {}
ns.BorderManager = BorderManager
local borders = {}
local highestBorderLevel = 0
BorderManager.key = "_CDMA_Border_%s_%s"

local GetNextUnusedBorder = function()
    for _, border in ipairs(borders) do
        if border.cooldownID == nil then
            return border
        end
    end
end

local HasCreatedBorder = function ()
    return borders[1]
end

BorderManager.GetBorder = function (cooldownID, options)
    for index, border in ipairs(borders) do
        if border.cooldownID == cooldownID and options and options.borderKey and border.key == options.borderKey then
            return border, index
        end
    end
end

BorderManager.Initialize = function(cooldownID, option)
    local source = ns.CDMUtils.GetCDMSourceByID(cooldownID)
    if source and option.cooldownID and option.name then
        local border = GetNextUnusedBorder()
        if not border then
            border = CreateFromMixins(ns.ConditionalMixin.Meta, ns.Border)
            tinsert(borders, border)
        end
        border:Initialize(option, source)
    end
end

BorderManager.Update = function(cooldownID, option)
    local currentBorder = BorderManager.Destroy(cooldownID, option)
    if currentBorder then
        BorderManager.Initialize(cooldownID, option)
    end
end

BorderManager.Destroy = function(cooldownID, option)
    local border, index = BorderManager.GetBorder(cooldownID, option)
    if border then
        border:Destroy()
        return true
    end
end

BorderManager.DestroyAll = function()
    for _, border in ipairs(borders) do
        border:Destroy()
    end
end

BorderManager.CreateAll = function()
    if HasCreatedBorder() then
        BorderManager.DestroyAll()
    end
    for cooldownID, options in pairs(ns.Utils.GetDB().borders) do
        for _, option in ipairs(options) do
            BorderManager.Initialize(cooldownID, option)
        end
    end
end