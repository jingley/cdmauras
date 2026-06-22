local _, ns = ...
local CDMUtils = {}
ns.CDMUtils = CDMUtils
local cdmViewers = {
    _G["EssentialCooldownViewer"],
    _G["UtilityCooldownViewer"],
    _G["BuffIconCooldownViewer"],
    _G["BuffBarCooldownViewer"],
}

local RefreshCooldownID = function (source)
    if not source.cooldownID and source.cooldownInfo then
        source.cooldownID = source.cooldownInfo.cooldownID
    end
    if not source.cooldownID and source.Icon then
        source.cooldownID = source.Icon.cooldownID
    end
    source.sourceID = source.cooldownID
end

local GetNameFromDB = function(cooldownID)
    local db = ns.Utils and ns.Utils.GetDB and ns.Utils.GetDB()
    local spellNames = db and db.spellNames
    local entry = spellNames and spellNames[cooldownID]
    if type(entry) ~= "string" or entry == "" then
        return nil, nil
    end

    local entryType, name = entry:match("^(%a+):%s*(.+)$")
    if type(name) == "string" and name ~= "" then
        return entryType, name
    end

    return nil, entry
end

CDMUtils.GetCDMSourceByID = function(sourceID)
    if sourceID == nil then return end
    for _, viewer in ipairs(cdmViewers) do
		for source in viewer.itemFramePool:EnumerateActive() do
			if source.cooldownID == sourceID then
                return source
            end
		end
	end
end

CDMUtils.RefreshCDMChildren = function ()
    local db = ns.Utils and ns.Utils.GetDB and ns.Utils.GetDB()
    if type(db) == "table" then
        db.spellNames = db.spellNames or {}
    end

    for _, viewer in ipairs(cdmViewers) do
        if not cdmViewers.isRefreshHooked then
            hooksecurefunc(viewer, "RefreshLayout", function()
                if ns.Addon.initialized then
                    ns.AlertManager.CreateAll()
                end
            end)
        end
		for source in viewer.itemFramePool:EnumerateActive() do
            RefreshCooldownID(source)
            local cooldownInfo = source.cooldownInfo
			if source.cooldownID and cooldownInfo then
                local spellID = cooldownInfo.overrideSpellID or cooldownInfo.spellID
                local spellInfo = spellID and C_Spell.GetSpellInfo(spellID)
                local name = spellInfo and spellInfo.name

                if db and source.cooldownID and type(name) == "string" and name ~= "" then
                    local type = (viewer.systemIndex == 3 or viewer.systemIndex == 4) and "Buff" or "Spell"
                    db.spellNames[source.cooldownID] = type .. ": " .. name
                end

                if source.Applications then
                    source.Applications:SetFrameLevel(5000)
                    if not source.isApplicaitonsHooked then
                        hooksecurefunc(source.Applications, "SetFrameLevel", function(self, frameLevel)
                            if frameLevel ~= 5000 then
                                self:SetFrameLevel(5000)
                            end
                        end)
                        source.isApplicaitonsHooked = true
                    end
                end
			end
		end
	end
end

CDMUtils.GetBuffCooldownIDByAuraInstanceID = function(auraInstanceID)
    for _, viewer in ipairs(cdmViewers) do
        if viewer.systemIndex == 3 or viewer.systemIndex == 4 then
            for source in viewer.itemFramePool:EnumerateActive() do
                local _, name = GetNameFromDB(source.cooldownID)
                if source.auraInstanceID and source.auraInstanceID == auraInstanceID and name then
                    return source.cooldownID
                end
            end
		end
	end
end

CDMUtils.GetBuff = function(cooldownID)
    for _, viewer in ipairs(cdmViewers) do
        if viewer.systemIndex == 3 or viewer.systemIndex == 4 then
            for source in viewer.itemFramePool:EnumerateActive() do
                local _, name = GetNameFromDB(source.cooldownID)
                if source.cooldownID == cooldownID and name then
                    return {cooldownID = source.cooldownID, name = name}
                end
            end
		end
	end
end

CDMUtils.GetSpell = function(cooldownID)
    for _, viewer in ipairs(cdmViewers) do
        if viewer.systemIndex == 1 or viewer.systemIndex == 2 then
            for source in viewer.itemFramePool:EnumerateActive() do
                local _, name = GetNameFromDB(source.cooldownID)
                if source.cooldownID == cooldownID and name then
                    return {cooldownID = source.cooldownID, name = name}
                end
            end
		end
	end
end

CDMUtils.GetBuffs = function()
    local buffs = {}

    for _, viewer in ipairs(cdmViewers) do
        if viewer.systemIndex == 3 or viewer.systemIndex == 4 then
            for source in viewer.itemFramePool:EnumerateActive() do
                local _, name = GetNameFromDB(source.cooldownID)
                if name then
                   tinsert(buffs, {cooldownID = source.cooldownID, name = name})
                end
            end
		end
	end

    return buffs
end

CDMUtils.GetSpells = function()
    local spells = {}

    for _, viewer in ipairs(cdmViewers) do
        if viewer.systemIndex == 1 or viewer.systemIndex == 2 then
            for source in viewer.itemFramePool:EnumerateActive() do
                local _, name = GetNameFromDB(source.cooldownID)
                if name then
                   tinsert(spells, {cooldownID = source.cooldownID, name = name})
                end
            end
		end
	end

    return spells
end

CDMUtils.ProcessCdmViewerChildren = function(func, ...)
    for _, viewer in ipairs(cdmViewers) do
		for source in viewer.itemFramePool:EnumerateActive() do
            RefreshCooldownID(source)
			func(source, ...)
		end
	end
end

CDMUtils.ProcessCdmViewers = function(func, viewersToProcess, ...)
    if not viewersToProcess then
        viewersToProcess = {1, 2, 3, 4}
    end
	for _, viewer in ipairs(cdmViewers) do
        if tContains(viewersToProcess, viewer.systemIndex) then
		    func(viewer, ...)
        end
	end
end

CDMUtils.GetSpellID = function(source)
    if source then
        local cooldownInfo = source.cooldownInfo
        if cooldownInfo then
            return cooldownInfo.overrideSpellID or cooldownInfo.spellID
        end
    end
end