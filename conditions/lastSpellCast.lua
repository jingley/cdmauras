-------------------------------------------------------------------------------
--  Condition for last spell cast match
-------------------------------------------------------------------------------
local _, ns = ...
local LastSpellCast = {}
ns.LastSpellCast = LastSpellCast

local CDMA_SUCCEEDED_SPELLCAST = function(self, spellID)
    if spellID == self.triggeringSpellID and not self.isActive then
        self.alert:UpdateConditions(self, true)
    elseif spellID ~= self.triggeringSpellID and self.isActive then
        self.alert:UpdateConditions(self, false)
    end
end

function LastSpellCast:Initialize(options, alert)
    self.triggeringSpellID = options.spellID
    self.alert = alert
    ns.Engine.API.RegisterInternalMessage("CDMA_SUCCEEDED_SPELLCAST", CDMA_SUCCEEDED_SPELLCAST, self)
end

function LastSpellCast:Destroy()
    CDMA_SUCCEEDED_SPELLCAST(self, -1)
    self.isActive = nil
    self.alert = nil
end
