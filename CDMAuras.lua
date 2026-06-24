local addonName, ns = ...
local CDMAuras = {
    initialized = false,
    cdmSettingsOpen = false,
}
ns.Addon = CDMAuras
local addonEventListener = CreateFrame("Frame", nil)
ns.settingsCategory = Settings.RegisterVerticalLayoutCategory(addonName)

local MergeDefaults
MergeDefaults = function(target, defaults)
    for key, value in pairs(defaults or {}) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            MergeDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local InitializeDB = function()
    if type(CDMAurasDB) ~= "table" then
        CDMAurasDB = {}
    end

    MergeDefaults(CDMAurasDB, ns.defaults)

    CDMAuras.db = {
        profile = CDMAurasDB.profile,
    }
    ns.db = CDMAuras.db
end

local RegisterSlashCommands = function()
    SLASH_CDMAURAS1 = "/cdma"
    SLASH_CDMAURAS2 = "/ca"
    SlashCmdList.CDMAURAS = function(input)
        local trimmedInput = (input and input:match("^%s*(.-)%s*$")) or ""
        CDMAuras:HandleCDMACommand(trimmedInput)
    end
end

local SetupEngineAndAlerts = function()
    ns.CDMUtils.RefreshCDMChildren()
    ns.Engine.API:StartEngine()
    ns.AlertManager.CreateAll()
end

function CDMAuras.BuildOrRefresh()
    C_Timer.After(1, function()
		SetupEngineAndAlerts()
	end)
end

local NotifyListeners = function ()
    if not CDMAuras.initialized then
        C_Timer.After(1, function()
            CDMAuras.BuildOrRefresh()
            ns.Engine.API.SendInternalMessage("CDMA_INIT")
            CDMAuras.initialized = true
        end)
    end
end

local ToggleDebugCvars = function(login, logout)
    --used to test addon restrictions, but I don't want to screw with people's cvars permanently
    local db = ns.Utils.GetDB(true)
    if not db.debug then return end
    if login then
        db.addonChallengeModeRestrictionsForced = db.addonChallengeModeRestrictionsForced or C_CVar.GetCVar("addonChallengeModeRestrictionsForced")
        db.addonCombatRestrictionsForced= db.addonCombatRestrictionsForced or C_CVar.GetCVar("addonCombatRestrictionsForced")
        db.addonEncounterRestrictionsForced = db.addonEncounterRestrictionsForced or C_CVar.GetCVar("addonEncounterRestrictionsForced")
        db.addonMapRestrictionsForced = db.addonMapRestrictionsForced or C_CVar.GetCVar("addonMapRestrictionsForced")
    end

    if not logout then
        C_CVar.SetCVar("addonChallengeModeRestrictionsForced", "1")
        C_CVar.SetCVar("addonCombatRestrictionsForced", "1")
        C_CVar.SetCVar("addonEncounterRestrictionsForced", "1")
        C_CVar.SetCVar("addonMapRestrictionsForced", "1")
    else
        C_CVar.SetCVar("addonChallengeModeRestrictionsForced", (db.addonChallengeModeRestrictionsForced or "0"))
        C_CVar.SetCVar("addonCombatRestrictionsForced", (db.addonCombatRestrictionsForced or "0"))
        C_CVar.SetCVar("addonEncounterRestrictionsForced", (db.addonEncounterRestrictionsForced or "0"))
        C_CVar.SetCVar("addonMapRestrictionsForced", (db.addonMapRestrictionsForced or "0"))
        db.addonChallengeModeRestrictionsForced = nil
        db.addonCombatRestrictionsForced= nil
        db.addonEncounterRestrictionsForced = nil
        db.addonMapRestrictionsForced = nil
    end

end

function CDMAuras:PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
    if isInitialLogin or isReloadingUi then
        ToggleDebugCvars(isInitialLogin)
        if CooldownViewerSettings then
            local layoutMgr = CooldownViewerSettings:GetLayoutManager()
            if layoutMgr and layoutMgr.NotifyListeners then
                hooksecurefunc(layoutMgr, "NotifyListeners", NotifyListeners)
            end

        end
        EventRegistry:RegisterCallback("CooldownViewerSettings.OnHide", function()
            self.cdmSettingsOpen = false
            CDMAuras.BuildOrRefresh()
        end)
        EventRegistry:RegisterCallback("CooldownViewerSettings.OnShow", function()
            self.cdmSettingsOpen = true
            CDMAuras.BuildOrRefresh()
        end)
        EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function()
            if not self.cdmSettingsOpen then return end
            ns.CDMUtils.RefreshCDMChildren()
        end)
    end
end

function CDMAuras:LIVE_CHANGE()
    CDMAuras.BuildOrRefresh()
    ns.Engine.API.SendInternalMessage("CDMA_INIT")
end

function CDMAuras:PLAYER_LOGOUT()
    ToggleDebugCvars(false, true)
end

function CDMAuras:OnEvent(event, ...)
    if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED" then
        CDMAuras:LIVE_CHANGE()
    elseif event == "PLAYER_ENTERING_WORLD" then
        CDMAuras:PLAYER_ENTERING_WORLD(...)
    elseif event == "PLAYER_LOGOUT" then
        CDMAuras:PLAYER_LOGOUT()
    end
end

function CDMAuras:OnInitialize()
    InitializeDB()
    if ns.CDMOptions and ns.CDMOptions.SetupMenu then
        ns.CDMOptions.SetupMenu()
    end
    addonEventListener:RegisterEvent("PLAYER_ENTERING_WORLD")
    addonEventListener:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    addonEventListener:RegisterEvent("TRAIT_CONFIG_UPDATED")
    addonEventListener:RegisterEvent("PLAYER_LOGOUT")
    RegisterSlashCommands()
end

function CDMAuras:HandleCDMACommand(input)
    local function PrintHelp()
        ns.Utils.Print("Usage:")
        ns.Utils.Print("  /ca can be used in place of /cdma")
        ns.Utils.Print("  /cdma help (or /cdma h) -> Show this help")
        ns.Utils.Print("  /cdma reset (or /cdma r) -> Recreate alerts without a reload")
        ns.Utils.Print("Notes:")
        ns.Utils.Print("  Reset can be used incombat (or not) in any case where alerts don't seem quite right. Please report the issue but utilize this command to resume normal operations.")
        ns.Utils.Print("Condition Limits (per alert):")
        ns.Utils.Print("  Max 1 Power condition | Max 1 Buff Duration condition")
        ns.Utils.Print("  Stacks (Border only): no limit — multiple conditions allowed, triggers when any is satisfied")
    end

    if not CDMAuras.initialized then
        ns.Utils.Print("CDMAAuras has not fully initialized. Please try the command again in a moment. If you are seeing this message not directly after login/reload, there is an issue occuring.")
    elseif input == "r" or input == "reset" then
        ns.AlertManager.CreateAll()
        ns.Utils.Print("CDMAuras alerts reset.")
    elseif input == "d" or input == "debug" then
        local db = ns.Utils.GetDB(true)
        db.debug = not db.debug
        ns.Utils.Print("CDMAuras debug " .. (db.debug and "enabled." or "disabled.") .. " CVARs will be changed on next reload.")
    else
        PrintHelp()
    end
end


addonEventListener:RegisterEvent("ADDON_LOADED")
addonEventListener:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName == addonName then
            addonEventListener:UnregisterEvent("ADDON_LOADED")
            CDMAuras:OnInitialize()
        end
        return
    end

    CDMAuras:OnEvent(event, ...)
end)