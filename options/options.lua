local _, ns = ...
local Options = {}
ns.Options = Options

ns.defaults = {
    profile = {
        Global = {
            cooldownTexts = {},
            buffTexts = {},
            glows = {},
            borders = {},
            icons = {},
            spellNames = {},
        }
    }
}

local HandleCDMACommand = function(input)
    local function PrintHelp()
        ns.Utils.Print("Usage:")
        ns.Utils.Print("  /ca can be used in place of /cdma")
        ns.Utils.Print("  /cdma help (or /cdma h) -> Show this help")
        ns.Utils.Print("  /cdma reset (or /cdma r) -> Recreate alerts without a reload")
        ns.Utils.Print("Notes:")
        ns.Utils.Print("  Reset can be used incombat (or not) in any case where alerts don't seem quite right. Please report the issue but utilize this command to resume normal operations.")
        ns.Utils.Print("Condition Limits (per alert):")
        ns.Utils.Print("  Max 1 Power condition or Buff Duration condition on an alert")
        ns.Utils.Print("  Stacks (Border only): no limit — multiple conditions allowed, triggers when any is satisfied")
    end

    if not ns.Addon.initialized then
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

local RegisterSlashCommands = function()
    SLASH_CDMAURAS1 = "/cdma"
    SLASH_CDMAURAS2 = "/ca"
    SlashCmdList.CDMAURAS = function(input)
        local trimmedInput = (input and input:match("^%s*(.-)%s*$")) or ""
        HandleCDMACommand(trimmedInput)
    end
end

Options.RegisterOptions = function()
    local panel = CreateFrame("Frame", "CDMAurasOptionsPanel", UIParent)
    panel.name = "CDMAuras"
    
    -- Add a simple title to your panel
    panel.title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    panel.title:SetPoint("TOPLEFT", 15, -15)
    panel.title:SetText("CDMAuras")

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    RegisterSlashCommands()
end