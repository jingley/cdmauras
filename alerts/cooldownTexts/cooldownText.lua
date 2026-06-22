-------------------------------------------------------------------------------
--  Cooldown Text Alert 
--  These display text alerts on the screen when spells are on CD with their remaining duration.
-------------------------------------------------------------------------------
local _, ns = ...
local CooldownText = {}
ns.CooldownText = CooldownText
local C_Spell, C_Timer, string = C_Spell, C_Timer, string

local RefreshDuration = function(cooldownObject)
	if not cooldownObject then
		return
	end
	if not cooldownObject.duration then
		cooldownObject.duration = C_Spell.GetSpellCooldownDuration(cooldownObject.spellID)
	end
end

function CooldownText:DisableAndHideAlert()
	local cooldownObject = self.cooldownObject
    if not cooldownObject then
        return
    end
    if cooldownObject.ticker then
		cooldownObject.ticker:Cancel()
	end
	cooldownObject.duration = nil
	local fontString = cooldownObject.fontString
	if fontString then
		fontString:SetShown(false)
		ns.CooldownTextManager.UpdateShownText(self, fontString, false)
	end
end

function CooldownText:UpdateCDText(cooldownObject)
	if not cooldownObject then
		return
	end

	RefreshDuration(cooldownObject)
	local duration = cooldownObject.duration

	if duration then
		local remainingDuration = duration:GetRemainingDuration(1)
		local fontString = cooldownObject.fontString
		if not fontString then
			return
		end
		fontString:SetFormattedText("No %s %.1f", cooldownObject.name, remainingDuration)
		if not fontString:IsShown() then
			fontString:SetShown(true)
			ns.CooldownTextManager.UpdateShownText(self, fontString, true)
		end
	end
end

function CooldownText:ActivateTicker()
	local cooldownObject = self.cooldownObject
	if not cooldownObject then
		return
	end

	if cooldownObject.ticker then
		cooldownObject.ticker:Cancel()
	end
	local ticker = C_Timer.NewTicker(0.1, function()
	self:UpdateCDText(cooldownObject) end)
	cooldownObject.ticker = ticker
end

local SetupCenterAdjustments = function(fontString)
	--centering won't be perfect because I don't like the wiggling from the timer changing, but it will be decently close.
	ns.CooldownTextManager.SetupCenterAdjustments(fontString)
end

function CooldownText:Initialize(option, cooldownID)
	self.cooldownID = cooldownID
	local cooldownObject = ns.Engine.API.RegisterCooldownTracking(self.cooldownID)
	self.cooldownObject = cooldownObject
	if cooldownObject then
		self.spellID = cooldownObject.spellID
		local fontString = ns.CooldownTextManagerFrame:CreateFontString(nil, "OVERLAY")
		local editModeName = ns.CooldownTextManagerFrame.editModeName
		local fontSize = ns.EditModeUtils.GetLayoutSetting(editModeName, nil, "fontSize", 16)
		local font = ns.EditModeUtils.GetLayoutSetting(editModeName, nil, "font",     "Fonts\\FRIZQT__.TTF")
		fontString.fontSize = fontSize
		fontString:SetFont(font, fontSize, "OUTLINE")
		fontString:SetTextColor(1, 1, 1, 1)
		fontString:SetTextToFit(string.format("No %s 100s", cooldownObject.name))
		SetupCenterAdjustments(fontString)
		fontString:SetJustifyH("LEFT")
		fontString:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		fontString:SetShown(false)
		cooldownObject.fontString = fontString
		self:InitializeConditional(option)
	end
end

function CooldownText:NotifyConditionsActiveChanged()
    if self.isConditionsActive then
        self:ActivateTicker()
    else
        self:DisableAndHideAlert()
    end
end

function CooldownText:Destroy()
	ns.Engine.API:UnregisterCooldownTracking(self.cooldownID)
    self.cooldownID = nil
	self:DestroyConditional()
	local cooldownObject = self.cooldownObject
	if cooldownObject then
		cooldownObject.duration = nil
		if cooldownObject.ticker then
			cooldownObject.ticker:Cancel()
		end
		cooldownObject.ticker = nil
		if cooldownObject.fontString then
			cooldownObject.fontString:SetShown(false)
			cooldownObject.fontString:ClearAllPoints()
			cooldownObject.fontString:ClearText()
			cooldownObject.fontString = nil
		end
		self.cooldownObject = nil
	end
end