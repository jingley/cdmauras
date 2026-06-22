local _, ns = ...
local EditModeUtils = {}
ns.EditModeUtils = EditModeUtils
local EditMode = LibStub("LibEQOLEditMode-1.0")
local categorySetup = false

EditModeUtils.SettingType = EditMode.SettingType

local GetLayoutTable = function(layoutName, editModeName)
    local db = ns.Utils.GetDB()
    local layoutKey = layoutName or EditModeUtils.GetActiveLayoutName()
    db.layouts = db.layouts or {}
    db.layouts[layoutKey] = db.layouts[layoutKey] or {}
    db.layouts[layoutKey][editModeName] = db.layouts[layoutKey][editModeName] or {}
    return db.layouts[layoutKey][editModeName]
end

local ApplyFramePosition = function(frame, point, x, y)
    if not frame then
        return
    end
    frame:ClearAllPoints()
    frame:SetPoint(point or "CENTER", UIParent, point or "CENTER", x or 0, y or 0)
end

EditModeUtils.GetLayoutSetting = function(editModeName, layoutName, key, default)
	local db = ns.Utils.GetDB()
	local layoutKey = layoutName or EditModeUtils.GetActiveLayoutName()
	db.layouts = db.layouts or {}
    local layoutData = db.layouts[layoutKey]
    local frameData = layoutData and layoutData[editModeName]
    local frameSettings = frameData and frameData["settings"]
    if frameSettings and frameSettings[key] ~= nil then
        return frameSettings[key]
	end
	return default
end

EditModeUtils.SetLayoutSetting = function(editModeName, layoutName, key, value)
	local db = ns.Utils.GetDB()
	local layoutKey = layoutName or EditModeUtils.GetActiveLayoutName()
	db.layouts = db.layouts or {}
	db.layouts[layoutKey] = db.layouts[layoutKey] or {}
	db.layouts[layoutKey][editModeName] = db.layouts[layoutKey][editModeName] or {}
    db.layouts[layoutKey][editModeName]["settings"] = db.layouts[layoutKey][editModeName]["settings"] or {}
	db.layouts[layoutKey][editModeName]["settings"][key] = value
end

EditModeUtils.GetFramePosition = function(editModeName, layoutName, defaults)
    local layout = GetLayoutTable(layoutName, editModeName)
    return layout.point or "CENTER", layout.x or (defaults and defaults.x or 0), layout.y or (defaults and defaults.y or 0)
end

EditModeUtils.SetFramePosition = function(frame, layoutName, point, x, y, defaults)
    if not frame then
        return
    end
    local layout = GetLayoutTable(layoutName, frame.editModeName)
    layout.point = point or layout.point or "CENTER"
    layout.x = x ~= nil and x or (layout.x or (defaults and defaults.x or 0))
    layout.y = y ~= nil and y or (layout.y or (defaults and defaults.y or 0))
    ApplyFramePosition(frame, layout.point, layout.x, layout.y)
end

local SaveFramePosition = function(editModeName, layoutName, framePosition)
    local layout = GetLayoutTable(layoutName, editModeName)
    layout.point = framePosition.point
    layout.x = framePosition.x
    layout.y = framePosition.y
end

local SetInitialPosition = function(frame, defaults)
    defaults = defaults or {x = 0, y = 0}
	local editModeName = frame.editModeName
    local layoutName = EditModeUtils.GetActiveLayoutName()
    local layout = GetLayoutTable(layoutName, editModeName)
    ApplyFramePosition(frame, layout.point or "CENTER", layout.x or defaults.x, layout.y or defaults.y)
end

EditModeUtils.GetActiveLayoutName = function()
	local layoutInfo = EditModeManagerFrame:GetActiveLayoutInfo()
    if layoutInfo then
        return layoutInfo.layoutName
    end

    return EditMode:GetActiveLayoutName() or "_Global"
end


EditModeUtils.SetupEditModeAnchor = function(frame, settings, previewFunc, defaultOffsets, onLayoutChanged)
    if frame and not frame.editModeSetup then
        local defaults = defaultOffsets or {}
        local positionSettings = {
            {
                name = "X Offset",
                kind = EditModeUtils.SettingType.Slider,
                default = defaults.x or 0,
                minValue = -2000,
                maxValue = 2000,
                valueStep = 1,
                allowInput = true,
                formatter = function(value)
				return tostring(value)
                end,
                get = function(layoutName)
				local _, x = EditModeUtils.GetFramePosition(frame.editModeName, layoutName, defaults)
				return x
                end,
                set = function(layoutName, value)
				local point, _, y = EditModeUtils.GetFramePosition(frame.editModeName, layoutName, defaults)
				EditModeUtils.SetFramePosition(frame, layoutName, point, value, y, defaults)
                end,
            },
            {
                name = "Y Offset",
                kind = EditModeUtils.SettingType.Slider,
                default = defaults.y or 0,
                minValue = -2000,
                maxValue = 2000,
                valueStep = 1,
                allowInput = true,
                formatter = function(value)
				return tostring(value)
                end,
                get = function(layoutName)
				local _, _, y = EditModeUtils.GetFramePosition(frame.editModeName, layoutName, defaults)
				return y
                end,
                set = function(layoutName, value)
				local point, x = EditModeUtils.GetFramePosition(frame.editModeName, layoutName, defaults)
				EditModeUtils.SetFramePosition(frame, layoutName, point, x, value, defaults)
                end,
            },
        }

        local combinedSettings = positionSettings
        EditMode:AddFrame(frame, function(...)
            local _, layoutName, point, x, y = ...
			local framePosition = {point = point, x = x, y = y}
			SaveFramePosition(frame.editModeName, layoutName, framePosition)
            ApplyFramePosition(frame, point, x, y)
            if EditMode.internal and EditMode.internal.RefreshSettingValues then
                EditMode.internal:RefreshSettingValues(positionSettings)
            end
        end, { point = "CENTER",
                x = defaults.x or 0,
                y = defaults.y or 0,
                enableOverlayToggle = true, overlayToggleEnabled  = true, allowDrag = true, dragEnabled = true})
        if settings and #settings > 0 then
            for _, row in ipairs(settings) do
                table.insert(combinedSettings, row)
            end
        end
        EditMode:AddFrameSettings(frame, combinedSettings)
        frame.editModeSetup = true
        EditMode:RegisterCallback("layout", function()
            SetInitialPosition(frame, defaults)
            if type(onLayoutChanged) == "function" then
                onLayoutChanged(frame)
            end
        end)
        if type(previewFunc) == "function" then
            EditMode:RegisterCallback("enter", function()
                previewFunc(true)
            end)
            EditMode:RegisterCallback("exit", function()
                previewFunc(false)
            end)
        end
        ns.Engine.API.RegisterInternalMessage("CDMA_INIT", SetInitialPosition, frame, defaults)
		SetInitialPosition(frame, defaults)
        if not categorySetup then
            EditMode:AddManagerCategory({
                id = "CDM Auras",
                label = "CDM Auras",
                sort = "label",
            })
            EditMode:SetManagerTogglePanelMaxHeight(500)
            categorySetup = true
        end

        EditMode:AddManagerCheckbox({
            id = frame.editModeName,
            label = frame.editModeName,
            category = "CDM Auras",
            frames = frame,
        })
    end
end

local LayoutRenamed = function (oldName, newName)
    local db = ns.Utils.GetDB()
    local layout = db.layouts[oldName]
    if layout then
        db.layouts[oldName] = nil
        db.layouts[newName] = layout
    end
end

local LayoutDeleted = function (_, deletedLayoutName)
    local db = ns.Utils.GetDB()
    local layout = db.layouts[deletedLayoutName]
    if layout then
        db.layouts[deletedLayoutName] = nil
    end
end

EditMode:RegisterCallback("layoutrenamed", LayoutRenamed)
EditMode:RegisterCallback("layoutdeleted", LayoutDeleted)
