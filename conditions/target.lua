-------------------------------------------------------------------------------
--  Condition for has target
-------------------------------------------------------------------------------
local _, ns = ...
local Target = {}
ns.Target = Target

local CDMA_TARGET_CHANGED = function(self, hasTarget)
    local shouldBeActive = self.negate and not hasTarget or (not self.negate and hasTarget)
    if shouldBeActive then
        if not self.isActive then
            self.alert:UpdateConditions(self, true)
        end
    else
        if self.isActive then
            self.alert:UpdateConditions(self, false)
        end
    end
end

function Target:Initialize(options, alert)
    self.alert  = alert
    self.negate = options.negate == true
    ns.Engine.API.RegisterInternalMessage("CDMA_TARGET_CHANGED", CDMA_TARGET_CHANGED, self)
end

function Target:Destroy()
    CDMA_TARGET_CHANGED(self, false)
    self.isActive = nil
    self.alert = nil
end
