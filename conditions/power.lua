-------------------------------------------------------------------------------
--  Power threshold condition
--  This is another special condition because it has to be concerned about secret values
--  Rather than using true/false condition this controls the alpha of the frame. Only 1 such condition can be used.
-------------------------------------------------------------------------------
local _, ns = ...
local Power = {}
ns.Power = Power
local UnitPowerPercent = UnitPowerPercent

local framePool = ns.Utils.GetFramePool(Power, "_framePool")

local BuildAlphaCurve = function(operator, option)
    local threshold = tonumber(option.threshhold) or tonumber(option.threshold) or 0.4
    if threshold < 0 then
        threshold = 0
    elseif threshold > 1 then
        threshold = 1
    end
    local thresholdLow = tonumber(option.thresholdLow) or 0
    if thresholdLow < 0 then thresholdLow = 0
    elseif thresholdLow > 1 then thresholdLow = 1 end
    local epsilon = 0.0001
    local lower = math.max(0, threshold - epsilon)
    local upper = math.min(1, threshold + epsilon)
    local alphaCurve = C_CurveUtil.CreateCurve()
    alphaCurve:SetType(1)

    if operator == "between" then
        local low  = math.max(0, math.min(1, thresholdLow or 0))
        local high  = math.max(0, math.min(1, threshold))
        if low > high then low, high = high, low end
        alphaCurve:AddPoint(0,              0)
        alphaCurve:AddPoint(low,             0)
        alphaCurve:AddPoint(low + epsilon,   1)
        alphaCurve:AddPoint(high - epsilon,   1)
        alphaCurve:AddPoint(high,             0)
    elseif operator == ">" then
        alphaCurve:AddPoint(0, 0)
        alphaCurve:AddPoint(threshold, 0)
        alphaCurve:AddPoint(upper, 1)
    elseif operator == "<" then
        alphaCurve:AddPoint(0, 1)
        alphaCurve:AddPoint(lower, 1)
        alphaCurve:AddPoint(threshold, 0)
    elseif operator == "<=" then
        alphaCurve:AddPoint(0, 1)
        alphaCurve:AddPoint(threshold, 1)
        alphaCurve:AddPoint(upper, 0)
    elseif operator == "=" then
        alphaCurve:AddPoint(0, 0)
        alphaCurve:AddPoint(lower, 0)
        alphaCurve:AddPoint(threshold, 1)
        alphaCurve:AddPoint(upper, 0)
    else
        alphaCurve:AddPoint(0, 0)
        alphaCurve:AddPoint(lower, 0)
        alphaCurve:AddPoint(threshold, 1)
    end

    return alphaCurve
end

local CDMA_UNIT_POWER_UPDATE = function(self, _, powerType)
    if powerType ~= self.eventPowerType then return end
    local alpha = UnitPowerPercent("player", self.triggeringPowerType, false, self.alphaCurve)
    self.alert:UpdatePowerAlpha(alpha)
end

function Power:ApplyAlpha(alpha)
    if not self.border then return end
    self.border:SetAlpha(alpha)
end

function Power:SetupPowerFrame()
    local border = framePool:Acquire()
    local texture = border.texture
    if not texture then
        texture = border:CreateTexture()
        border.texture = texture
    end
    local placeholder = self.alert.placeholder
    border:SetAllPoints(placeholder)
    border:SetParent(placeholder)
    border:SetSize(placeholder:GetSize())
    border:SetFrameStrata(border:GetParent():GetFrameStrata())
    border:SetFrameLevel(border:GetParent():GetFrameLevel() + self.alert.frameLevel)
    border:Show()
    self.alert:SetupBorderTexture(border)
    self.border = border
end

function Power:Initialize(option, alert)
    self.triggeringPowerType = tonumber(option.triggeringPowerType) or tonumber(option.powerType)
    self.eventPowerType = option.eventPowerType
    self.alert = alert
    if alert.type == "border" then
        self:SetupPowerFrame()
        self.pooled = true
    else
        self.border = self.alert.alphaFrame
    end
    self.alphaCurve = BuildAlphaCurve(option.operator or option.thresholdType or ">=", option)
    ns.Engine.API.RegisterInternalMessage("CDMA_UNIT_POWER_UPDATE", CDMA_UNIT_POWER_UPDATE, self)
    local alpha = UnitPowerPercent("player", self.triggeringPowerType, false, self.alphaCurve)
    self.alert:UpdatePowerAlpha(alpha)
end

function Power:Destroy()
    self.triggeringPowerType = nil
    self.eventPowerType = nil
    if self.border then
        self.border:SetAlpha(0)
        if self.pooled then
            framePool:Release(self.border)
            self.pooled = nil
        end
    end
    self.alphaCurve = nil
    self.border = nil
    ns.Engine.API.UnregisterAllInternalMessages(self)
end