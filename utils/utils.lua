local _, ns = ...
local Utils = {}
ns.Utils = Utils
local C_SpecializationInfo = rawget(_G, "C_SpecializationInfo")
local CreateFramePool = rawget(_G, "CreateFramePool")
local LibStub = rawget(_G, "LibStub")
local GAME_DEFAULT_FONTS = {
    { text = "Friz Quadrata",      value = "Fonts\\FRIZQT__.TTF" },
    { text = "Arial Narrow", value = "Fonts\\ARIALN.TTF" },
    { text = "Morpheus",     value = "Fonts\\MORPHEUS.TTF" },
    { text = "Skurri",       value = "Fonts\\skurri.ttf" },
}
local UnitPowerMap = {
    [0] = "MANA",
    [1] = "RAGE",
    [2] = "FOCUS",
    [3] = "ENERGY",
    [4] = "COMBO_POINTS",
    [5] = "RUNES",
    [6] = "RUNIC_POWER",
    [7] = "SOUL_SHARDS",
    [8] = "LUNAR_POWER",
    [9] = "HOLY_POWER",
    [10] = "ALTERNATE",
    [11] = "MAELSTROM",
    [12] = "CHI",
    [13] = "INSANITY",
    [14] = "BURNING_EMBERS",
    [15] = "DEMONIC_FURY",
    [16] = "ARCANE_CHARGES",
    [17] = "FURY",
    [18] = "PAIN",
    [19] = "ESSENCE",
    [20] = "RUNE_BLOOD",
    [21] = "RUNE_FROST",
    [22] = "RUNE_UNHOLY",
}

local SpecializationsByClass = {
    {
        class = "Death Knight",
        specs = {
            { id = 250, name = "Blood" },
            { id = 251, name = "Frost" },
            { id = 252, name = "Unholy" },
        },
    },
    {
        class = "Demon Hunter",
        specs = {
            { id = 577, name = "Havoc" },
            { id = 581, name = "Vengeance" },
        },
    },
    {
        class = "Druid",
        specs = {
            { id = 102, name = "Balance" },
            { id = 103, name = "Feral" },
            { id = 104, name = "Guardian" },
            { id = 105, name = "Restoration" },
        },
    },
    {
        class = "Evoker",
        specs = {
            { id = 1467, name = "Devastation" },
            { id = 1468, name = "Preservation" },
            { id = 1473, name = "Augmentation" },
        },
    },
    {
        class = "Hunter",
        specs = {
            { id = 253, name = "Beast Mastery" },
            { id = 254, name = "Marksmanship" },
            { id = 255, name = "Survival" },
        },
    },
    {
        class = "Mage",
        specs = {
            { id = 62, name = "Arcane" },
            { id = 63, name = "Fire" },
            { id = 64, name = "Frost" },
        },
    },
    {
        class = "Monk",
        specs = {
            { id = 268, name = "Brewmaster" },
            { id = 270, name = "Mistweaver" },
            { id = 269, name = "Windwalker" },
        },
    },
    {
        class = "Paladin",
        specs = {
            { id = 65, name = "Holy" },
            { id = 66, name = "Protection" },
            { id = 70, name = "Retribution" },
        },
    },
    {
        class = "Priest",
        specs = {
            { id = 256, name = "Discipline" },
            { id = 257, name = "Holy" },
            { id = 258, name = "Shadow" },
        },
    },
    {
        class = "Rogue",
        specs = {
            { id = 259, name = "Assassination" },
            { id = 260, name = "Outlaw" },
            { id = 261, name = "Subtlety" },
        },
    },
    {
        class = "Shaman",
        specs = {
            { id = 262, name = "Elemental" },
            { id = 263, name = "Enhancement" },
            { id = 264, name = "Restoration" },
        },
    },
    {
        class = "Warlock",
        specs = {
            { id = 265, name = "Affliction" },
            { id = 266, name = "Demonology" },
            { id = 267, name = "Destruction" },
        },
    },
    {
        class = "Warrior",
        specs = {
            { id = 71, name = "Arms" },
            { id = 72, name = "Fury" },
            { id = 73, name = "Protection" },
        },
    },
}

local SpecializationLookup = {}

for classIndex, classInfo in ipairs(SpecializationsByClass) do
    for specIndex, specInfo in ipairs(classInfo.specs) do
        SpecializationLookup[specInfo.id] = {
            class = classInfo.class,
            classIndex = classIndex,
            specIndex = specIndex,
            id = specInfo.id,
            name = specInfo.name,
        }
    end
end

Utils.GetUnitPowerMap = function()
    return UnitPowerMap
end

Utils.SpecializationsByClass = SpecializationsByClass

Utils.GetSpecializationsByClass = function()
    return SpecializationsByClass
end

Utils.GetAllSpecializations = function()
    local options = {}
    for _, classInfo in ipairs(SpecializationsByClass) do
        for _, specInfo in ipairs(classInfo.specs) do
            options[#options + 1] = {
                class = classInfo.class,
                id = specInfo.id,
                name = specInfo.name,
            }
        end
    end
    return options
end

Utils.GetSpecializationInfoByID = function(specID)
    return SpecializationLookup[specID]
end

Utils.GetCurrentSpecializationID = function()
    local specializationInfo = C_SpecializationInfo
    if not specializationInfo or not specializationInfo.GetSpecialization or not specializationInfo.GetSpecializationInfo then
        return nil
    end

    local specIndex = specializationInfo.GetSpecialization()
    if not specIndex then
        return nil
    end

    local specID = specializationInfo.GetSpecializationInfo(specIndex)
    return specID
end

Utils.GetSpecializationDB = function(specID, createIfMissing)
    local profile = ns.db and ns.db.profile
    if not profile then
        return nil
    end

    if createIfMissing and profile[specID] == nil then
        profile[specID] = {}
    end

    return profile[specID]
end

Utils.GetDB = function(global)
    -- need to be careful I encountered an issue with calling this during a file's load and it causes a confusing error.

    local profile = ns.db.profile
    local globalKey = "Global"

    local specKey = globalKey
    if not global then
        local specID = Utils.GetCurrentSpecializationID()
        if specID then
            specKey = specID
        end
    end

    profile[specKey] = profile[specKey] or {}
    local scopedDB = profile[specKey]

    scopedDB.cooldownTexts = scopedDB.cooldownTexts or {}
    scopedDB.buffTexts = scopedDB.buffTexts or {}
    scopedDB.glows = scopedDB.glows or {}
    scopedDB.borders = scopedDB.borders or {}
    scopedDB.icons = scopedDB.icons or {}
    scopedDB.spellNames = scopedDB.spellNames or {}

    return scopedDB
end

local function ResetPooledFrame(_, frame)
    if not frame then
        return
    end

    if frame._cdmaMaskedTexture and frame._cdmaMaskTexture and frame._cdmaMaskedTexture.RemoveMaskTexture then
        frame._cdmaMaskedTexture:RemoveMaskTexture(frame._cdmaMaskTexture)
    end

    frame._cdmaMaskedTexture = nil

    frame:Hide()
    frame:ClearAllPoints()
    frame:SetParent(nil)
    frame:SetIgnoreParentAlpha(0)
    frame:SetScale(1)
    frame:SetAlpha(1)
    frame.anyCondition = nil

    if frame.texture then
        frame.texture:Hide()
        frame.texture:ClearAllPoints()
        if frame.texture.SetVertexColor then
            frame.texture:SetVertexColor(1, 1, 1, 1)
        end
    end

    if frame._cdmaMaskTexture then
        frame._cdmaMaskTexture:Hide()
        frame._cdmaMaskTexture:ClearAllPoints()
    end
end

Utils.GetFramePool = function(owner, poolKey, parent, template)
    if not owner or not poolKey then
        return nil
    end

    if not owner[poolKey] then
        owner[poolKey] = CreateFramePool("Frame", parent, template, ResetPooledFrame)
    end

    return owner[poolKey]
end

Utils.GetStatusBarPool = function(owner, poolKey, parent, template)
    if not owner or not poolKey then
        return nil
    end

    if not owner[poolKey] then
        owner[poolKey] = CreateFramePool("StatusBar", parent, template, ResetPooledFrame)
    end

    return owner[poolKey]
end

Utils.AddCDMMaskTexture = function(frame, texture, sourceTexture)
    if not frame or not texture or not sourceTexture then
        return
    end

    if frame._cdmaMaskedTexture and frame._cdmaMaskTexture and frame._cdmaMaskedTexture ~= texture and frame._cdmaMaskedTexture.RemoveMaskTexture then
        frame._cdmaMaskedTexture:RemoveMaskTexture(frame._cdmaMaskTexture)
        frame._cdmaMaskedTexture = nil
    end

    if sourceTexture:GetNumMaskTextures() > 1 then
        local sourceMask = sourceTexture:GetMaskTexture(1)
        local mask = frame._cdmaMaskTexture
        if not mask then
            mask = frame:CreateMaskTexture()
            frame._cdmaMaskTexture = mask
        elseif frame._cdmaMaskedTexture and frame._cdmaMaskedTexture ~= texture and frame._cdmaMaskedTexture.RemoveMaskTexture then
            frame._cdmaMaskedTexture:RemoveMaskTexture(mask)
        end

        mask:SetTexture(sourceMask:GetTexture())
        mask:SetTexCoord(sourceMask:GetTexCoord())
        mask:SetAllPoints(frame)
        mask:Show()

        if frame._cdmaMaskedTexture ~= texture then
            texture:AddMaskTexture(mask)
            frame._cdmaMaskedTexture = texture
        end
    elseif frame._cdmaMaskedTexture and frame._cdmaMaskTexture and frame._cdmaMaskedTexture.RemoveMaskTexture then
        frame._cdmaMaskedTexture:RemoveMaskTexture(frame._cdmaMaskTexture)
        frame._cdmaMaskedTexture = nil
        frame._cdmaMaskTexture:Hide()
    end
end

-- Prints a message with a colorful CDMAuras prefix
Utils.Print = function(msg)
    -- |cff00ff98 is a greenish color, |r resets color
    print("|cff00ff98CDMAuras:|r " .. tostring(msg))
end

--- Apply the default Blizzard squircle mask to `texture` on `frame`.
--- This rounds the outer edges the same way the default CDM action-button
--- icons are masked, without needing a sourceTexture to copy from.
Utils.ApplyDefaultMaskTexture = function(frame, texture)
    if not frame or not texture then return end
    local MASK_PATH = 6707800
    local mask = frame._cdmaMaskTexture
    if not mask then
        mask = frame:CreateMaskTexture()
        frame._cdmaMaskTexture = mask
    end
    mask:SetTexture(MASK_PATH, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(frame)
    mask:Show()
    if frame._cdmaMaskedTexture ~= texture then
        texture:AddMaskTexture(mask)
        frame._cdmaMaskedTexture = texture
    end
end

Utils.GetFontOptions = function()
    local options = {}
    local seen = {}

    local function AddFont(label, path, sourceOrder)
        if type(path) ~= "string" or path == "" or seen[path] then
            return
        end
        seen[path] = true
        options[#options + 1] = {
            text = (type(label) == "string" and label ~= "") and label or path,
            value = path,
            _sourceOrder = sourceOrder or 2,
        }
    end

    for _, font in ipairs(GAME_DEFAULT_FONTS) do
        AddFont(font.text, font.value, 1)
    end

    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    if lsm then
        local names = lsm:List("font")
        if type(names) == "table" then
            table.sort(names, function(a, b)
                return tostring(a):lower() < tostring(b):lower()
            end)
            for _, name in ipairs(names) do
                AddFont(name, lsm:Fetch("font", name), 2)
            end
        end
    end

    table.sort(options, function(a, b)
        if a._sourceOrder ~= b._sourceOrder then
            return a._sourceOrder < b._sourceOrder
        end
        return tostring(a.text):lower() < tostring(b.text):lower()
    end)

    for _, option in ipairs(options) do
        option._sourceOrder = nil
    end

    return options
end

Utils.GetDefaultGlowName = function(glow)
    local glowKey = glow and glow.glowKey or ""
    local defaultName = glowKey:gsub("^_CDMA", ""):gsub("_", " ")
    return defaultName:gsub("^%s+", ""):gsub("%s+$", "")
end

Utils.GetDefaultBorderName = function(border)
    local borderKey = border and border.borderKey or ""
    local defaultName = borderKey:gsub("^_CDMA", ""):gsub("_", " ")
    return defaultName:gsub("^%s+", ""):gsub("%s+$", "")
end

Utils.GetDefaultIconName = function(icon)
    local iconKey = icon and icon.iconKey or ""
    local defaultName = iconKey:gsub("^_CDMA", ""):gsub("_", " ")
    return defaultName:gsub("^%s+", ""):gsub("%s+$", "")
end

