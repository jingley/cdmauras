-------------------------------------------------------------------------------
--  Always True Condition
--  Techncially will be false during destroy function to prevent orphaned activation.
-------------------------------------------------------------------------------
local _, ns = ...
local Always = {}
ns.Always = Always

function Always:Initialize(option, alert)
    self.alert = alert
    self.alert:UpdateConditions(self, true)
end

function Always:Destroy()
    self.alert:UpdateConditions(self, false)
    self.alert = nil
end
