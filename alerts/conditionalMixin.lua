local _, ns = ...
local ConditionalMixin = {}
ns.ConditionalMixin = ConditionalMixin

local ConditionalMixinMeta = {}
ConditionalMixinMeta.__index = ConditionalMixinMeta
ConditionalMixin.Meta = ConditionalMixinMeta

function ConditionalMixinMeta:InitializeConditional(options)
    self.anyCondition = options.anyCondition
    self.conditions = {}
    self.isConditionsActive = nil
    self.lockedConditionCount = 0
    self.unlockedConditionCount = 0
    self.lockedTrueCount = 0
    self.unlockedTrueCount = 0
    self.secretConditionCount = 0
    self:SetupConditions(options)
end

function ConditionalMixinMeta:DestroyConditions()
    if not self.conditions then return end
    for _, condition in ipairs(self.conditions) do
        condition:Destroy()
    end
end

function ConditionalMixinMeta:DestroyConditional()
    ns.Engine.API.UnregisterAllInternalMessages(self)
    self:DestroyConditions()
    self.source = nil
    self.isConditionsActive = nil
    self.lockedConditionCount = nil
    self.unlockedConditionCount = nil
    self.lockedTrueCount = nil
    self.unlockedTrueCount = nil
    self.alphaControl = nil
    self.secretConditionCount = nil
    self.hasStacksConditions = nil
    self.realConditionsActive = nil
    self.conditions = nil
    self:NotifyConditionsActiveChanged()
end

function ConditionalMixinMeta:SetupConditions(options)
    if options.conditions then
        for _, conditionOptions in ipairs(options.conditions) do
            local condition
            if conditionOptions.type == "buff" then
                condition = CreateFromMixins(ns.Buff)
            elseif conditionOptions.type == "cooldown" then
                condition = CreateFromMixins(ns.Cooldown)
            elseif conditionOptions.type == "always" then
                condition = CreateFromMixins(ns.Always)
            elseif conditionOptions.type == "power" then
                condition = CreateFromMixins(ns.Power)
                condition.isSecretCondition = true
            elseif conditionOptions.type == "stacks" then
                condition = CreateFromMixins(ns.Stacks)
                condition.isStacksCondition = true
            elseif conditionOptions.type == "buffDuration" then
                condition = CreateFromMixins(ns.BuffDuration)
                condition.isSecretCondition = true
            elseif conditionOptions.type == "target" then
                condition = CreateFromMixins(ns.Target)
            elseif conditionOptions.type == "lastSpellCast" then
                condition = CreateFromMixins(ns.LastSpellCast)
            elseif conditionOptions.type == "spellOverlay" then
                condition = CreateFromMixins(ns.SpellOverlay)
            end
            if condition then
                condition.isLocked = conditionOptions._locked == true
                if condition.isSecretCondition then
                    self.secretConditionCount = self.secretConditionCount + 1
                elseif condition.isStacksCondition then
                    self.secretConditionCount = self.secretConditionCount + 1
                    self.hasStacksConditions = true
                else
                    if condition.isLocked then
                        self.lockedConditionCount = self.lockedConditionCount + 1
                    else
                        self.unlockedConditionCount = self.unlockedConditionCount + 1
                    end
                end
                condition:Initialize(conditionOptions, self)
                table.insert(self.conditions, condition)
            end
        end
        self:NotifyAlphaChanges()
        self:NotifyConditionsActiveChanged()
    end
end

function ConditionalMixinMeta:NotifyConditionsActiveChanged()
     --downstream mixins implement this and call it
end

function ConditionalMixinMeta:UpdateConditions(condition, active)
    if condition == nil then return end

    local previousConditionsActive = self.isConditionsActive
    local increment = active and 1 or -1

    if condition.isLocked then
        self.lockedTrueCount = self.lockedTrueCount + increment
    else
        self.unlockedTrueCount = self.unlockedTrueCount + increment
    end

    if self.lockedTrueCount < 0 then self.lockedTrueCount = 0 end
    if self.unlockedTrueCount < 0 then self.unlockedTrueCount = 0 end

    local previousLockedSatisfied = self.lockedSatisfied
    self.isConditionsActive = self:CalculateIsConditionsActive()

    if previousConditionsActive ~= self.isConditionsActive then
        self:NotifyAlphaChanges()
        self:NotifyConditionsActiveChanged()
    elseif previousLockedSatisfied ~= self.lockedSatisfied then
        self:NotifyAlphaChanges()
    end
end

function ConditionalMixinMeta:CalculateIsConditionsActive()
    if self.lockedConditionCount == 0 and self.unlockedConditionCount == 0 and self.secretConditionCount == 0 then
        return false
    end

    self.lockedSatisfied = self.lockedConditionCount == 0 or self.lockedTrueCount == self.lockedConditionCount
    if not self.lockedSatisfied then
        return false
    end

    if self.anyCondition then
        self.realConditionsActive = self.unlockedTrueCount > 0
        if self.type == "border" then
            return self.realConditionsActive
        else
            return self.realConditionsActive or self.secretConditionCount > 0
        end
    else
        self.realConditionsActive = self.unlockedTrueCount == self.unlockedConditionCount
        return self.realConditionsActive
    end
end

function ConditionalMixinMeta:UpdatePowerAlpha(alpha)
    self.previousPowerAlpha = alpha
    return self:NotifyAlphaChanges()
end

function ConditionalMixinMeta:NotifyAlphaChanges()
    if not self.conditions or self.secretConditionCount == 0 then return end
    local alpha = self.previousPowerAlpha == nil and 1 or self.previousPowerAlpha
    if not self.lockedSatisfied then
        alpha = 0
    elseif self.anyCondition then
        if self.realConditionsActive then
            alpha = 1
        end
    else
        if not self.realConditionsActive then
            alpha = 0
        end
    end
    for _, cond in ipairs(self.conditions) do
        if cond.isStacksCondition then
            if self.lockedSatisfied then
                cond:ApplyAlpha(self.anyCondition and 1 or alpha)
            else
                cond:ApplyAlpha(0)
            end
        elseif cond.isSecretCondition then
            if not self.anyCondition and self.hasStacksConditions then
                cond:ApplyAlpha(0)
            else
                cond:ApplyAlpha(alpha)
            end
           
        end
    end
end