-------------------------------------------------------------------------------
--  Condition for Spell Overlay Glow
-------------------------------------------------------------------------------
local _, ns = ...
local SpellOverlay = {}
ns.SpellOverlay = SpellOverlay

local CDMA_SPELL_OVERLAY_SHOW = function(self, cooldownID)
    if not self.alert or cooldownID ~= self.triggeringCooldownID or (self.isActive == not self.negate) then return end
    self.isActive = not self.negate
    self.alert:UpdateConditions(self, self.isActive)
end

local CDMA_SPELL_OVERLAY_HIDE = function(self, cooldownID)
    if not self.alert or cooldownID ~= self.triggeringCooldownID or (self.isActive == self.negate) then return end
    self.isActive = self.negate
    self.alert:UpdateConditions(self, self.isActive)
end

function SpellOverlay:Initialize(options, alert)
    self.alert  = alert
    self.negate = options.negate == true
    self.triggeringCooldownID = options.cooldownID
    ns.Engine.API.RegisterInternalMessage("CDMA_SPELL_OVERLAY_SHOW", CDMA_SPELL_OVERLAY_SHOW, self)
    ns.Engine.API.RegisterInternalMessage("CDMA_SPELL_OVERLAY_HIDE", CDMA_SPELL_OVERLAY_HIDE, self)
    local overlayed = ns.Engine.API.RegisterSpellActivationOverlay(self.triggeringCooldownID)
    if overlayed then
        CDMA_SPELL_OVERLAY_SHOW(self, self.triggeringCooldownID)
    else
        CDMA_SPELL_OVERLAY_HIDE(self, self.triggeringCooldownID)
    end
end

function SpellOverlay:Destroy()
    self.negate = nil
    CDMA_SPELL_OVERLAY_HIDE(self, self.triggeringCooldownID)
    ns.Engine.API.UnregisterSpellActivationOverlay(self.triggeringCooldownID)
    self.triggeringCooldownID = nil
    self.isActive = nil
    self.alert = nil
end
