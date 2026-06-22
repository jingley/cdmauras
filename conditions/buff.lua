-------------------------------------------------------------------------------
--  Buff Condition
--  Processes CDMA_ON_COOLDOWN and CDMA_OFF_COOLDOWN events from the engine and notifies active based on negate.
-- i.e. if negate is true then CDMA_ON_COOLDOWN triggers active condition. Else CDMA_OFF_COOLDOWN triggers active
-------------------------------------------------------------------------------
local _, ns = ...
local Buff = {}
ns.Buff = Buff

local CDMA_AURA_ADD = function(self, auraData)
    if auraData.cooldownID ~= self.triggeringCooldownID then return end
    self.alert:UpdateConditions(self, not self.negate)
end

local CDMA_AURA_REMOVE = function(self, cooldownID)
    if cooldownID ~= self.triggeringCooldownID then return end
    self.alert:UpdateConditions(self, self.negate)
end

function Buff:Initialize(option, alert)
    self.triggeringCooldownID = option.cooldownID
    self.negate = option.negate or false
    self.alert = alert

    ns.Engine.API.RegisterInternalMessage("CDMA_AURA_ADD", CDMA_AURA_ADD, self)
    ns.Engine.API.RegisterInternalMessage("CDMA_AURA_REMOVE", CDMA_AURA_REMOVE, self)
    local aura = ns.Engine.API.GetAura(self.triggeringCooldownID)
    if aura then
        CDMA_AURA_ADD(self, aura)
    else
        CDMA_AURA_REMOVE(self, self.triggeringCooldownID)
    end
end

function Buff:Destroy()
    self.triggeringCooldownID = nil
    self.negate = nil
    self.alert:UpdateConditions(self, false)
    self.alert = nil
    ns.Engine.API.UnregisterAllInternalMessages(self)
end