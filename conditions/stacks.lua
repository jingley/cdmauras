-------------------------------------------------------------------------------
--  Stacks Condition
--  Processes CDMA_AURA_ADD, CDMA_AURA_UPDATE, CDMA_AURA_REMOVE events from the engine.
--  Each instance owns and manages its own StatusBar overlay, parented to the
--  alert's border frame so it inherits show/hide from condition state.
--  This design allows multiple Stacks conditions (OR) to independently layer
--  separate status bars on top of the same border in the future.
-------------------------------------------------------------------------------
local _, ns = ...
local Stacks = {}
ns.Stacks = Stacks

local statusBarPool = ns.Utils.GetStatusBarPool(Stacks, "_statusBarPool")

local CDMA_AURA_ADD_OR_UPDATE = function(self, auraData)
    if auraData.cooldownID == self.triggeringCooldownID then
        self.statusBar:SetValue(auraData.applications)
    end
end

local CDMA_AURA_REMOVE = function(self, cooldownID)
    if cooldownID ~= self.triggeringCooldownID then return end
    self.statusBar:SetValue(0)
end

function Stacks:Initialize(option, alert)
    if not alert then return end
    self.triggeringCooldownID = option.cooldownID
    self.alert = alert
    self.threshold = option.threshold

    local bar = statusBarPool:Acquire()
    alert:SetupBorderTexture(bar, true)
    bar:SetAllPoints(alert.placeholder)
    bar:SetParent(alert.placeholder)
    bar:SetAlpha(1)
    bar:SetFrameStrata(alert.border:GetFrameStrata())
    bar:SetFrameLevel(alert.border:GetFrameLevel() + 1)
    bar:Show()

    if option.operator == ">" then
        bar:SetMinMaxValues(self.threshold, self.threshold + 0.5)
    else
        bar:SetMinMaxValues(self.threshold - 0.5, self.threshold)
    end
    bar:SetValue(0)
    self.statusBar = bar

    --  With UpdateStacksAlpha the same handler is safe to use for both ADD and UPDATE
    -- since it is idempotent (no incrementing counter to corrupt on repeated calls).
    ns.Engine.API.RegisterInternalMessage("CDMA_AURA_ADD", CDMA_AURA_ADD_OR_UPDATE, self)
    ns.Engine.API.RegisterInternalMessage("CDMA_AURA_UPDATE", CDMA_AURA_ADD_OR_UPDATE, self)
    ns.Engine.API.RegisterInternalMessage("CDMA_AURA_REMOVE", CDMA_AURA_REMOVE, self)
    local aura = ns.Engine.API.GetAura(self.triggeringCooldownID)
    if aura then
        CDMA_AURA_ADD_OR_UPDATE(self, aura)
    else
        CDMA_AURA_REMOVE(self, self.triggeringCooldownID)
    end
end

function Stacks:ApplyAlpha(alpha)
    if not self.statusBar then return end
    self.statusBar:SetAlpha(alpha)
end

function Stacks:Destroy()
    if self.statusBar then
        self.statusBar:SetValue(0)
        statusBarPool:Release(self.statusBar)
        self.statusBar = nil
    end
    self.triggeringCooldownID = nil
    self.alert = nil
    self.threshold = nil
    ns.Engine.API.UnregisterAllInternalMessages(self)
end