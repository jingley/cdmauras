-------------------------------------------------------------------------------
--  Engine for all logic
--  Built myself hooked into the CDM and certain events to pass only necessary information for processing to alerts. I also didn't want multiple frames listening for blizz events
-------------------------------------------------------------------------------
local _, ns = ...
local Engine = {}
ns.Engine = Engine
local API = {}
Engine.API = API
local events = {}
local contextIndex = {}
local aurasCache = {}
local auraInstanceIDCache = {}
local cooldownCache = {}
local GetAuraDuration, hooksecurefunc, table, C_Spell, GetAuraDataByAuraInstanceID = C_UnitAuras.GetAuraDuration, hooksecurefunc, table, C_Spell, C_UnitAuras.GetAuraDataByAuraInstanceID
local trackedCooldowns = {}
local spellIDToCooldownIDMap = {}
local registeredForSpellUpdate = {}
local eventFrame = CreateFrame("Frame", nil)
local emptyAura = {}
local targetAuras = {}

-- Start helper functions
local BuildAuraData = function(cooldownID, auraInstanceID, unit)
	local auraData = aurasCache[cooldownID] or {new = true}
	if auraData.new then
		auraData.new = false
		aurasCache[cooldownID] = auraData
	end
	auraData.unit = auraData.unit or unit
	if auraData.unit == "target" and not targetAuras[cooldownID] then
		targetAuras[cooldownID] = true
	end

	auraData.auraInstanceID = auraInstanceID
	if auraInstanceID and unit then
		local realData = GetAuraDataByAuraInstanceID(unit, auraInstanceID)
		if realData then
			auraData.applications = realData.applications
			auraData.hasBuff = true
			auraData.cooldownID = cooldownID
			auraData.duration = GetAuraDuration(unit, auraInstanceID)
			return auraData
		end
	end
	return emptyAura
end
-- End helper functions

-- Start Event Handlers
local CDMA_AURA_UPDATE = function(cooldownID, auraInstanceID, auraDataUnit)
	local auraData = BuildAuraData(cooldownID, auraInstanceID, auraDataUnit)
	API.SendInternalMessage("CDMA_AURA_UPDATE", auraData)
end

local CDMA_AURA_REMOVE = function(cooldownID)
	if cooldownID then
		local currentAura = aurasCache[cooldownID]
		if not currentAura then return end
		auraInstanceIDCache[currentAura.auraInstanceID] = nil
		aurasCache[cooldownID] = nil
		targetAuras[cooldownID] = nil
		API.SendInternalMessage("CDMA_AURA_REMOVE", cooldownID)
	end
end

local CDMA_AURA_ADD = function(cooldownID, auraInstanceID, auraDataUnit)
	auraInstanceIDCache[auraInstanceID] = cooldownID
	local auraData = BuildAuraData(cooldownID, auraInstanceID, auraDataUnit)
	API.SendInternalMessage("CDMA_AURA_ADD", auraData)
end

local UnregisterAuraInstanceIDItemFrame = function(_, _, itemFrame)
	CDMA_AURA_REMOVE(itemFrame.cooldownID)
end

local RegisterAuraInstanceIDItemFrame = function(_, auraInstanceID, itemFrame)
	if auraInstanceID then
		CDMA_AURA_ADD(itemFrame.cooldownID, auraInstanceID, itemFrame.auraDataUnit)
	end
end

local NotifySpellOnCooldown = function(spellID)
	local cooldownID = spellIDToCooldownIDMap[spellID]
	if cooldownID then
		local spellCooldown = C_Spell.GetSpellCooldown(spellID)
		if spellCooldown then
			if spellCooldown.isActive and spellCooldown.isEnabled and not spellCooldown.isOnGCD then
				API.SendInternalMessage("CDMA_ON_COOLDOWN", cooldownID)
			else
				if not tContains(registeredForSpellUpdate, spellID) then
					tinsert(registeredForSpellUpdate, spellID)
				end
				eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
			end
		end
	end
end

local NotifySpellOffCooldown = function(cooldownID)
	API.SendInternalMessage("CDMA_OFF_COOLDOWN", cooldownID)
end

local HookChargeGained = function(source)
	if source.TriggerChargeGainedAlert and not source.chargeGainedHooked then
		hooksecurefunc(source, "TriggerChargeGainedAlert", function(self, ...)
			local cooldownObject = trackedCooldowns[source.cooldownID]
			if not cooldownObject then return end
			NotifySpellOffCooldown(cooldownObject.cooldownID)
		end)
		source.chargeGainedHooked = true
	end
end

local HookAvailable = function(source)
	if source.TriggerAvailableAlert and not source.availableHooked then
		hooksecurefunc(source, "TriggerAvailableAlert", function(self, ...)
			local cooldownObject = trackedCooldowns[source.cooldownID]
			if not cooldownObject then return end
			NotifySpellOffCooldown(cooldownObject.cooldownID)
		end)
		source.availableHooked = true
	end
end

local SetupCooldownTracker = function(source)
	local cooldownID = source.cooldownID
	local cooldownInfo = source.cooldownInfo
	if cooldownInfo then
		local spellID = cooldownInfo.overrideSpellID or cooldownInfo.spellID
		local name = C_Spell.GetSpellInfo(spellID).name
		local cooldownObject = {cooldownID = cooldownID, spellID = spellID, name = name}
		HookAvailable(source)
		HookChargeGained(source)
		cooldownCache[cooldownID] = cooldownObject
	end
end

local HookAndScanChild = function(source)
	SetupCooldownTracker(source)
	local cooldownID = source.cooldownID
	if source.auraInstanceID and source.auraDataUnit then
		local auraData = BuildAuraData(cooldownID, source.auraInstanceID, source.auraDataUnit)
		API.SendInternalMessage("CDMA_AURA_ADD", auraData)
	end
end

local RefreshActiveFramesForTargetChange = function(self)
	--this is in case the auraInstanceID gets stale during a target change. I've not seen this happen though, seems now remove and add get called first on target change. keeping around for safety.
	for itemFrame in self.itemFramePool:EnumerateActive() do
		local cooldownID, auraInstanceID, unit = itemFrame.cooldownID, itemFrame.auraInstanceID, itemFrame.auraDataUnit
		if unit == "target" and auraInstanceID then
			local auraData = aurasCache[cooldownID]
			if auraData and auraData.auraInstanceID ~= auraInstanceID then
				auraInstanceIDCache[auraData.auraInstanceID] = nil
				auraInstanceIDCache[auraInstanceID] = cooldownID
				CDMA_AURA_UPDATE(cooldownID, auraInstanceID, unit)
			end
		end
	end
end

local HookViewer = function(viewer)
	if not viewer._cdmaViewerHooked then
		hooksecurefunc(viewer, "RegisterAuraInstanceIDItemFrame", RegisterAuraInstanceIDItemFrame)
		hooksecurefunc(viewer, "UnregisterAuraInstanceIDItemFrame", UnregisterAuraInstanceIDItemFrame)
		hooksecurefunc(viewer, "RefreshActiveFramesForTargetChange", RefreshActiveFramesForTargetChange)
		viewer._cdmaViewerHooked = true
	end
end

local RemoveSpellIDFromRegisteredUpdateTable = function(spellID)
	for index, spell in ipairs(registeredForSpellUpdate) do
		if spellID == spell then
			table.remove(registeredForSpellUpdate, index)
        	break
		end
	end
end

local SPELL_UPDATE_COOLDOWN = function(_, spellID)
	local cooldownID = spellIDToCooldownIDMap[spellID]
	if not cooldownID then return end
	local spellCooldown = C_Spell.GetSpellCooldown(spellID)
		if spellCooldown and spellCooldown.isEnabled and spellCooldown.isActive and spellCooldown.isOnGCD == false then
			RemoveSpellIDFromRegisteredUpdateTable(spellID)
			if not registeredForSpellUpdate[1] then
				eventFrame:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
			end
			API.SendInternalMessage("CDMA_ON_COOLDOWN", cooldownID)
		end
end

--todo do only send power updates for power we have alerts reading
local UNIT_POWER_UPDATE = function(_, unit, powerType)
	if unit ~= "player" then return end
    API.SendInternalMessage("CDMA_UNIT_POWER_UPDATE", unit, powerType)
end

local UNIT_SPELLCAST_START = function(_, unit, _, spellID)
	if unit ~= "player" then return end
    API.SendInternalMessage("CDMA_START_SPELLCAST", spellID)
end

local UNIT_SPELLCAST_STOP = function(_, unit, _, spellID)
	if unit ~= "player" then return end
    API.SendInternalMessage("CDMA_STOP_SPELLCAST", spellID)
end

local UNIT_SPELLCAST_SUCCEEDED = function(_, unit, _, spellID)
	if unit ~= "player" then return end
	NotifySpellOnCooldown(spellID)
	API.SendInternalMessage("CDMA_SUCCEEDED_SPELLCAST", spellID)
end

local UNIT_AURA = function(_, unit, updateInfo)
	if unit == "target" and not next(targetAuras) then
		--we have no active target auras we're tracking skip this. could maybe not listen for target UNIT_AURA like this, but for now this.
		return
	end
	if not updateInfo.updatedAuraInstanceIDs then return end
	for _, auraInstanceID in ipairs(updateInfo.updatedAuraInstanceIDs) do
		local cooldownID = auraInstanceIDCache[auraInstanceID]
		if cooldownID then
			local aura = aurasCache[cooldownID]
			if aura.unit == unit then
				CDMA_AURA_UPDATE(cooldownID, auraInstanceID, unit)
			end
		end
	end
end
-- End Event Handlers

-- Start Exposed API
function API:StartEngine()
	ns.CDMUtils.ProcessCdmViewerChildren(HookAndScanChild)
	ns.CDMUtils.ProcessCdmViewers(HookViewer, {3, 4})
	eventFrame:UnregisterAllEvents()
	eventFrame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
	eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
	eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
	eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	eventFrame:RegisterUnitEvent("UNIT_AURA", "player", "target")
	eventFrame:SetScript("OnEvent", function(self, event, ...)
		if event == "UNIT_AURA" then
			UNIT_AURA(event, ...)
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
			UNIT_SPELLCAST_SUCCEEDED(event, ...)
		elseif event == "SPELL_UPDATE_COOLDOWN" then
			SPELL_UPDATE_COOLDOWN(event, ...)
		elseif event == "UNIT_SPELLCAST_START" then
			UNIT_SPELLCAST_START(event, ...)
		elseif event == "UNIT_SPELLCAST_STOP" then
			UNIT_SPELLCAST_STOP(event, ...)
		elseif event == "UNIT_POWER_UPDATE" then
			UNIT_POWER_UPDATE(event, ...)
		end
	end)
end

API.RegisterCooldownTracking = function(cooldownID)
    local cooldownObject = cooldownCache[cooldownID]
	if cooldownObject then
		trackedCooldowns[cooldownID] = cooldownObject
		spellIDToCooldownIDMap[cooldownObject.spellID] = cooldownID
		return trackedCooldowns[cooldownID]
	end
end

API.UnregisterCooldownTracking = function(cooldownID)
    local cooldownObject = cooldownCache[cooldownID]
	if cooldownObject then
		trackedCooldowns[cooldownID] = nil
		spellIDToCooldownIDMap[cooldownObject.spellID] = nil
	end
end

API.GetAura = function(cooldownID)
    return aurasCache[cooldownID]
end

API.GetAuraDuration = function(cooldownID)
    local aura = aurasCache[cooldownID]
	if aura then
		return aura.duration
	end
end

API.IsSpellOnCooldown = function(cooldownID)
	local cooldownObject = trackedCooldowns[cooldownID]
	if cooldownObject then
		local spellCooldown = C_Spell.GetSpellCooldown(cooldownObject.spellID)
		if spellCooldown then
			if spellCooldown.isActive and spellCooldown.isEnabled and not spellCooldown.isOnGCD then
				return true
			end
		end
	end
end

-- Start Internal Event Publishing
API.RegisterInternalMessage = function(event, func, frame)
    if not events[event] then events[event] = {} end
    local listener = {f = func, c = frame, event = event, i = #events[event] + 1}
    events[event][listener.i] = listener
    if frame then
        if not contextIndex[frame] then contextIndex[frame] = {} end
        table.insert(contextIndex[frame], listener)
    end
    return listener.i
end

API.UnregisterAllInternalMessages = function(frame)
	if not frame then
		return
	end
	local listeners = contextIndex[frame]
	if not listeners then
		return
	end
	for i = 1, #listeners do
		local listener = listeners[i]
		local list = events[listener.event]
		if list then
			local index = listener.i
			local last = list[#list]
			if last then
				list[index] = last
				last.i = index
				list[#list] = nil
			end
			if #list == 0 then
				events[listener.event] = nil
			end
		end
	end
	contextIndex[frame] = nil
end

API.SendInternalMessage = function(event, ...)
    local listeners = events[event]
    if listeners then
        for i = 1, #listeners do
            local listener = listeners[i]
            if listener then
                listener.f(listener.c, ...)
            end
        end
    end
end
-- End Internal Event Publishing
-- End Exposed API
