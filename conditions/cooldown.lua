-------------------------------------------------------------------------------
--  Cooldown Condition
--  Processes CDMA_ON_COOLDOWN and CDMA_OFF_COOLDOWN events from the engine and notifies active based on negate.
-- i.e. if negate is true then CDMA_ON_COOLDOWN triggers active condition. Else CDMA_OFF_COOLDOWN triggers active
-------------------------------------------------------------------------------
local _, ns = ...
local Cooldown = {}
ns.Cooldown = Cooldown

local CDMA_ON_COOLDOWN = function(self, cooldownID)
    if cooldownID ~= self.triggeringCooldownID then return end
    self.alert:UpdateConditions(self, not self.negate)
end

local CDMA_OFF_COOLDOWN = function(self, cooldownID)
    if cooldownID ~= self.triggeringCooldownID then return end
    self.alert:UpdateConditions(self, self.negate)
end

function Cooldown:Initialize(option, alert)
    self.triggeringCooldownID = option.cooldownID
    self.negate = option.negate or false
    self.alert = alert
    ns.Engine.API.RegisterCooldownTracking(self.triggeringCooldownID)
    ns.Engine.API.RegisterInternalMessage("CDMA_ON_COOLDOWN", CDMA_ON_COOLDOWN, self)
    ns.Engine.API.RegisterInternalMessage("CDMA_OFF_COOLDOWN", CDMA_OFF_COOLDOWN, self)
    if ns.Engine.API.IsSpellOnCooldown(option.cooldownID) then
        self.alert:UpdateConditions(self, not self.negate)
    else
        self.alert:UpdateConditions(self, self.negate)
    end
end

function Cooldown:Destroy()
    self.triggeringCooldownID = nil
    self.negate = nil
    self.alert:UpdateConditions(self, false)
    self.alert = nil
    ns.Engine.API.UnregisterAllInternalMessages(self)
end