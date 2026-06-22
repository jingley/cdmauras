-------------------------------------------------------------------------------
--  BuffDuration threshold condition
--  This is another special condition because it has to be concerned about secret values
--  This condition uses both true/false condition and controls the alpha of the frame. Only 1 secret condition can be used.
-------------------------------------------------------------------------------
local _, ns = ...
local BuffDuration = {}
ns.BuffDuration = BuffDuration
local C_CurveUtil, C_Timer = C_CurveUtil, C_Timer

local framePool = ns.Utils.GetFramePool(BuffDuration, "_framePool")

local BuildAlphaCurve = function(operator, option)
    local threshold = tonumber(option.threshhold) or tonumber(option.threshold) or 0
    if threshold < 0 then threshold = 0 end
    local thresholdLow = tonumber(option.thresholdLow) or 0
    if thresholdLow < 0 then thresholdLow = 0 end
    local epsilon = 0.0001
    local lower = math.max(0, threshold - epsilon)
    local upper = threshold + epsilon
    local alphaCurve = C_CurveUtil.CreateCurve()
    alphaCurve:SetType(1)

    if operator == "between" then
        local low = math.max(0, thresholdLow or 0)
        local high = math.max(0, threshold)
        if low > high then low, high = high, low end
        alphaCurve:AddPoint(0,            0)
        alphaCurve:AddPoint(low,           0)
        alphaCurve:AddPoint(low + epsilon, 1)
        alphaCurve:AddPoint(high - epsilon, 1)
        alphaCurve:AddPoint(high,           0)
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

local CDMA_AURA_ADD = function(self, auraData)
    if self.triggeringCooldownID ~= auraData.cooldownID then return end
    local ticker = self.ticker
	if ticker then
		self.ticker:Cancel()
	end
    self.duration = auraData.duration
    self.ticker = C_Timer.NewTicker(0.1, function ()
        if not self.duration or not self.alert then
            self.ticker:Cancel()
            return
        end
        local alpha = self.duration:EvaluateRemainingDuration(self.alphaCurve)
        self.alert:UpdatePowerAlpha(alpha)
    end)

    local alpha = self.duration:EvaluateRemainingDuration(self.alphaCurve)
    self.alert:UpdatePowerAlpha(alpha)
end

local CDMA_AURA_UPDATE = function(self, auraData)
    if self.triggeringCooldownID ~= auraData.cooldownID then return end
    self.duration = auraData.duration
end

local CDMA_AURA_REMOVE = function(self, cooldownID)
    if self.triggeringCooldownID ~= cooldownID then return end
    if self.ticker then
		self.ticker:Cancel()
	end
    self.alert:UpdatePowerAlpha(0)
    self.duration = nil
end

function BuffDuration:ApplyAlpha(alpha)
    if not self.border then return end
    self.border:SetAlpha(alpha)
end

function BuffDuration:SetupBuffDurationFrame()
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

function BuffDuration:Initialize(option, alert)
    self.triggeringCooldownID = option.cooldownID
    self.alert = alert
    if alert.type == "border" then
        self:SetupBuffDurationFrame()
        self.pooled = true
    else
        self.border = self.alert.alphaFrame
    end
    
    self.alphaCurve = BuildAlphaCurve(option.operator or option.thresholdType or ">=", option)
    ns.Engine.API.RegisterInternalMessage("CDMA_AURA_UPDATE", CDMA_AURA_UPDATE, self)
    ns.Engine.API.RegisterInternalMessage("CDMA_AURA_REMOVE", CDMA_AURA_REMOVE, self)

    local aura = ns.Engine.API.GetAura(self.triggeringCooldownID)
    if aura then
        CDMA_AURA_ADD(self, aura)
    else
        CDMA_AURA_REMOVE(self, self.triggeringCooldownID)
    end
    ns.Engine.API.RegisterInternalMessage("CDMA_AURA_ADD", CDMA_AURA_ADD, self)
end

function BuffDuration:Destroy()
    if self.ticker then
        self.ticker:Cancel()
    end
    if self.border then
        self.border:SetAlpha(0)
        if self.pooled then
            framePool:Release(self.border)
            self.pooled = nil
        end
    end
    self.triggeringCooldownID = nil
    self.ticker = nil
    self.alphaCurve = nil
    self.alert = nil
    self.alphaControl = nil
    self.duration = nil
    ns.Engine.API.UnregisterAllInternalMessages(self)
end