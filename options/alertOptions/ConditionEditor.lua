local _, ns = ...
---@diagnostic disable: undefined-global

-------------------------------------------------------------------------------
-- ConditionEditor
-- Renders the Conditions tab inside AlertEditor.
--
-- Layout (inside the tab host frame):
--   [Header bar]  "Conditions"  +  "Match: Any | All" toggle button
--   [Scroll list] one row per condition in alertObject.conditions
--   [Action row]  "+ Add" dropdown  +  "– Remove" button
--   [Scroll editor] fields for the currently-selected condition
-------------------------------------------------------------------------------

local ConditionEditor = {}
ns.ConditionEditor = ConditionEditor

local Theme = ns.Theme

-- ---------------------------------------------------------------------------
-- Palette  (matches AlertEditor / Theme.lua)
-- ---------------------------------------------------------------------------
local C_PANEL_BG    = { 0.06, 0.07, 0.09, 0.96 }
local C_PANEL_EDGE  = { 0.18, 0.22, 0.26, 0.95 }
local C_HOVER_BG    = { 0.09, 0.11, 0.14, 0.98 }
local C_HOVER_EDGE  = { 0.26, 0.62, 0.53, 1    }
local C_ACTIVE_BG   = { 0.08, 0.30, 0.22, 0.95 }
local C_ACTIVE_EDGE = { 0.24, 0.62, 0.53, 1    }
local C_HEADER_BG   = { 0.03, 0.16, 0.13, 0.82 }
local C_HEADER_EDGE = { 0.18, 0.45, 0.38, 0.95 }
local C_INSET_BG    = { 0.04, 0.05, 0.07, 0.72 }
local C_INSET_EDGE  = { 0.13, 0.15, 0.18, 0.90 }
local C_ACCENT      = { 0.30, 0.86, 0.70, 1    }
local C_TEXT_NORMAL = { 0.88, 0.98, 0.93, 1    }
local C_TEXT_LABEL  = { 0.52, 0.86, 0.75, 1    }
local C_TEXT_SUBTLE = { 0.64, 0.69, 0.74, 1    }

-- Stacks-section colours  (muted warm bronze — distinct from green, not aggressive)
local C_STACKS_ACCENT      = { 0.82, 0.68, 0.38, 1    }
local C_STACKS_ACTIVE_BG   = { 0.14, 0.11, 0.06, 0.95 }
local C_STACKS_ACTIVE_EDGE = { 0.62, 0.50, 0.26, 1    }
local C_STACKS_HOVER_BG    = { 0.10, 0.09, 0.05, 0.98 }
local C_STACKS_HOVER_EDGE  = { 0.46, 0.36, 0.18, 1    }
local C_STACKS_HDR_BG      = { 0.07, 0.06, 0.04, 0.88 }
local C_STACKS_HDR_EDGE    = { 0.30, 0.24, 0.10, 0.90 }

-- ---------------------------------------------------------------------------
-- Layout constants
-- ---------------------------------------------------------------------------
local ROW_H    = 38    -- condition list row height
local DIVIDER_H = 24   -- stacks section header height
local PAD     = 6
local FIELD_W = 268   -- field width inside the editor scroll area

-- ---------------------------------------------------------------------------
-- Condition type definitions
-- ---------------------------------------------------------------------------
local CONDITION_DEFS = {
    { type = "always",       label = "Always"        },
    { type = "buff",         label = "Buff"          },
    { type = "cooldown",     label = "Cooldown"      },
    { type = "buffDuration", label = "Buff Duration" },
    { type = "power",        label = "Power"         },
    { type = "stacks",       label = "Stacks"        },
}

-- Operators for range-capable conditions (power, buffDuration).
-- "between" is a synthetic operator stored as operator=">" + operator2="<".
local RANGE_OPERATOR_OPTIONS = {
    { value = ">=",      label = ">= (at least)"       },
    { value = ">",       label = "> (more than)"       },
    { value = "<=",      label = "<= (at most)"        },
    { value = "<",       label = "< (less than)"       },
    { value = "between", label = "between  (low < x < high)" },
}

local STACKS_OPERATOR_OPTIONS = {
    { value = ">=", label = ">= (at least)" },
    { value = ">",  label = "> (more than)"  },
}

-- ---------------------------------------------------------------------------
-- Shared helpers
-- ---------------------------------------------------------------------------

local function SetBD(f, bg, edge)
    if not f or not f.SetBackdrop then return end
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    f:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4])
end

local function GetTypeLabel(condType)
    for _, d in ipairs(CONDITION_DEFS) do
        if d.type == condType then return d.label end
    end
    return condType or "Unknown"
end

-- ---------------------------------------------------------------------------
-- Data-entry helpers  (buff list, spell list, power map)
-- ---------------------------------------------------------------------------

local function GetBuffEntries()
    local entries = {}
    local buffs = ns.CDMUtils and ns.CDMUtils.GetBuffs and ns.CDMUtils.GetBuffs() or {}
    for _, b in ipairs(buffs) do
        entries[#entries + 1] = {
            value = b.cooldownID,
            label = string.format("%s (%s)", b.name or "Unknown", tostring(b.cooldownID)),
        }
    end
    return entries
end

local function GetSpellEntries()
    local entries = {}
    local spells = ns.CDMUtils and ns.CDMUtils.GetSpells and ns.CDMUtils.GetSpells() or {}
    for _, s in ipairs(spells) do
        entries[#entries + 1] = {
            value = s.cooldownID,
            label = string.format("%s (%s)", s.name or tostring(s.cooldownID), tostring(s.cooldownID)),
        }
    end
    return entries
end

local function GetPowerEntries()
    local entries = {}
    local powerMap = (ns.Utils and ns.Utils.GetUnitPowerMap and ns.Utils.GetUnitPowerMap()) or {}
    local keys = {}
    for k in pairs(powerMap) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        entries[#entries + 1] = {
            value = k,                                              -- numeric Enum.PowerType
            label = string.format("%s  (%d)", powerMap[k], k),
            eventName = powerMap[k],                                -- e.g. "MANA"
        }
    end
    return entries
end

local function FindEntryLabel(entries, value, fallback)
    for _, e in ipairs(entries or {}) do
        if e.value == value then return e.label end
    end
    return fallback or "?"
end

-- ---------------------------------------------------------------------------
-- Condition summary (used for list rows)
-- ---------------------------------------------------------------------------

local function GetConditionSummary(cond)
    if not cond then return "" end
    local t = cond.type

    if t == "always" then
        return "Always active"

    elseif t == "buff" then
        local buffEntries = GetBuffEntries()
        local name = FindEntryLabel(buffEntries, cond.cooldownID,
            cond.cooldownID and tostring(cond.cooldownID) or "?")
        return (cond.negate and "Missing: " or "Has: ") .. name

    elseif t == "cooldown" then
        local spellEntries = GetSpellEntries()
        local name = FindEntryLabel(spellEntries, cond.cooldownID,
            cond.cooldownID and tostring(cond.cooldownID) or "?")
        return (cond.negate and "Off cooldown: " or "On cooldown: ") .. name

    elseif t == "buffDuration" then
        local buffEntries = GetBuffEntries()
        local name = FindEntryLabel(buffEntries, cond.cooldownID,
            cond.cooldownID and tostring(cond.cooldownID) or "?")
        if cond.operator == "between" then
            return string.format("%s  %ss < dur < %ss", name,
                tostring(cond.thresholdLow or 0), tostring(cond.threshold or 0))
        end
        return string.format("%s  dur %s %ss", name, cond.operator or ">=", tostring(cond.threshold or 0))

    elseif t == "power" then
        local powerEntries = GetPowerEntries()
        local name = FindEntryLabel(powerEntries, cond.triggeringPowerType, "Power")
        local pct = math.floor(((cond.threshold or 0.4) * 100) + 0.5)
        if cond.operator == "between" then
            local lo = math.floor(((cond.thresholdLow or 0) * 100) + 0.5)
            return string.format("%s  %d%% < power < %d%%", name, lo, pct)
        end
        return string.format("%s  %s %d%%", name, cond.operator or ">=", pct)

    elseif t == "stacks" then
        local buffEntries = GetBuffEntries()
        local name = FindEntryLabel(buffEntries, cond.cooldownID,
            cond.cooldownID and tostring(cond.cooldownID) or "?")
        return string.format("%s  stacks %s %d", name, cond.operator or ">", tonumber(cond.threshold) or 1)
    end

    return ""
end

-- ---------------------------------------------------------------------------
-- Module state  (reset / updated on each RenderInHost call)
-- ---------------------------------------------------------------------------
local selectedIndex     = 1
local activeAlertObject = nil
local activeHost        = nil
local listContent       = nil   -- scroll child for the condition list
local editorContent     = nil   -- scroll child for the field editor

-- Forward declarations
local RebuildListRows
local RebuildEditorFields

-- ---------------------------------------------------------------------------
-- Scroll section factory
-- ---------------------------------------------------------------------------
local function BuildScrollSection(parent, yTop, sectionH)
    local outer = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    outer:SetPoint("TOPLEFT",  parent, "TOPLEFT",  PAD, yTop)
    outer:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, yTop)
    outer:SetHeight(sectionH)
    SetBD(outer, C_INSET_BG, C_INSET_EDGE)

    -- Scroll frame sits inside outer; right edge reserved for scroll bar
    local sf = CreateFrame("ScrollFrame", nil, outer, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     outer, "TOPLEFT",     1,   -1)
    sf:SetPoint("BOTTOMRIGHT", outer, "BOTTOMRIGHT", -18,  1)

    local content = CreateFrame("Frame", nil, sf)
    content:SetPoint("TOPLEFT", sf, "TOPLEFT")
    content:SetWidth(sf:GetWidth() > 0 and sf:GetWidth() or FIELD_W)
    content:SetHeight(1)
    sf:SetScrollChild(content)
    sf:HookScript("OnSizeChanged", function(self, w) content:SetWidth(w) end)

    Theme.ApplyScrollBar(sf)

    return outer, sf, content
end

-- ---------------------------------------------------------------------------
-- List section – condition rows
-- ---------------------------------------------------------------------------

function RebuildListRows(alertObject)
    if not listContent then return end

    if not listContent._rowPool then listContent._rowPool = {} end
    for _, row in ipairs(listContent._rowPool) do row:Hide() end

    local conditions = (alertObject and alertObject.conditions) or {}

    -- Partition conditions into three buckets so each section renders
    -- distinctly.  selectedIndex still maps to the flat array throughout.
    local lockedEntries  = {}   -- required / locked (always must be true)
    local regularEntries = {}   -- subject to the Any / All match toggle
    local stacksEntries  = {}   -- stacks OR group (amber section)
    for i, cond in ipairs(conditions) do
        if cond.type == "stacks" then
            stacksEntries[#stacksEntries + 1] = { idx = i, cond = cond }
        elseif cond._locked then
            lockedEntries[#lockedEntries + 1] = { idx = i, cond = cond }
        else
            regularEntries[#regularEntries + 1] = { idx = i, cond = cond }
        end
    end

    local yOff      = 0
    local rowPoolIdx = 0

    local function AcquireRow()
        rowPoolIdx = rowPoolIdx + 1
        local row = listContent._rowPool[rowPoolIdx]
        if not row then
            row = CreateFrame("Frame", nil, listContent, "BackdropTemplate")
            row._accent = row:CreateTexture(nil, "ARTWORK")
            row._accent:SetPoint("TOPLEFT",    row, "TOPLEFT",    0, 0)
            row._accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
            row._accent:SetWidth(3)
            row._typeLbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row._typeLbl:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -5)
            row._summaryLbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row._summaryLbl:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 10, 5)
            row._summaryLbl:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            row._summaryLbl:SetJustifyH("LEFT")
            row._summaryLbl:SetWordWrap(false)
            row:EnableMouse(true)
            listContent._rowPool[rowPoolIdx] = row
        end
        return row
    end

    local function RenderConditionRow(arrayIdx, cond, isStacks)
        local isLocked = cond._locked == true
        if isLocked then return end

        local row = AcquireRow()
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",  listContent, "TOPLEFT",  0, -yOff)
        row:SetPoint("TOPRIGHT", listContent, "TOPRIGHT", 0, -yOff)
        row:SetHeight(ROW_H)

        local isSelected = (arrayIdx == selectedIndex) and not isLocked

        -- Background + accent stripe
        if isSelected then
            if isStacks then
                SetBD(row, C_STACKS_ACTIVE_BG, C_STACKS_ACTIVE_EDGE)
                row._accent:SetColorTexture(C_STACKS_ACCENT[1], C_STACKS_ACCENT[2], C_STACKS_ACCENT[3], 1)
            else
                SetBD(row, C_ACTIVE_BG, C_ACTIVE_EDGE)
                row._accent:SetColorTexture(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 1)
            end
        elseif isLocked then
            SetBD(row, { 0.04, 0.05, 0.07, 0.70 }, { 0.24, 0.26, 0.28, 0.80 })
            row._accent:SetColorTexture(0.55, 0.55, 0.58, 0.9)
        else
            SetBD(row, C_PANEL_BG, C_PANEL_EDGE)
            if isStacks then
                row._accent:SetColorTexture(C_STACKS_ACCENT[1], C_STACKS_ACCENT[2], C_STACKS_ACCENT[3], 0.30)
            else
                row._accent:SetColorTexture(0, 0, 0, 0)
            end
        end

        -- Labels
        local typeText = GetTypeLabel(cond.type) .. (isLocked and "  [Ignores match setting, always required for activation.]" or "")
        row._typeLbl:SetText(typeText)
        if isLocked then
            row._typeLbl:SetTextColor(C_TEXT_SUBTLE[1], C_TEXT_SUBTLE[2], C_TEXT_SUBTLE[3], 1)
        elseif isStacks then
            row._typeLbl:SetTextColor(C_STACKS_ACCENT[1], C_STACKS_ACCENT[2], C_STACKS_ACCENT[3], 1)
        else
            row._typeLbl:SetTextColor(C_TEXT_LABEL[1], C_TEXT_LABEL[2], C_TEXT_LABEL[3], 1)
        end
        row._summaryLbl:SetText(GetConditionSummary(cond))
        if isLocked then
            row._summaryLbl:SetTextColor(C_TEXT_SUBTLE[1], C_TEXT_SUBTLE[2], C_TEXT_SUBTLE[3], 0.70)
        else
            row._summaryLbl:SetTextColor(C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3], 0.80)
        end

        -- Interaction
        local idx = arrayIdx
        if isLocked then
            row:SetScript("OnMouseDown", nil)
            row:SetScript("OnEnter",     nil)
            row:SetScript("OnLeave",     nil)
        else
            row:SetScript("OnMouseDown", function()
                selectedIndex = idx
                RebuildListRows(alertObject)
                RebuildEditorFields(alertObject)
            end)
            if isStacks then
                row:SetScript("OnEnter", function(self)
                    if idx ~= selectedIndex then SetBD(self, C_STACKS_HOVER_BG, C_STACKS_HOVER_EDGE) end
                end)
                row:SetScript("OnLeave", function(self)
                    if idx ~= selectedIndex then SetBD(self, C_PANEL_BG, C_PANEL_EDGE) end
                end)
            else
                row:SetScript("OnEnter", function(self)
                    if idx ~= selectedIndex then SetBD(self, C_HOVER_BG, C_HOVER_EDGE) end
                end)
                row:SetScript("OnLeave", function(self)
                    if idx ~= selectedIndex then SetBD(self, C_PANEL_BG, C_PANEL_EDGE) end
                end)
            end
        end

        row:Show()
        yOff = yOff + ROW_H + 2
    end

    -- Locked (required) rows — no header needed; they sit at the top and
    -- the [required] badge + grey colouring already identify them.
    for _, entry in ipairs(lockedEntries) do
        RenderConditionRow(entry.idx, entry.cond, false)
    end

    -- "Match: Any/All" divider — only appears when there are both locked
    -- conditions above AND regular conditions below, making the boundary
    -- and the scope of the toggle unambiguous.
    if false and #lockedEntries > 0 and #regularEntries > 0 then
        if not listContent._matchDivider then
            local d = CreateFrame("Frame", nil, listContent, "BackdropTemplate")
            d._accent = d:CreateTexture(nil, "ARTWORK")
            d._accent:SetPoint("TOPLEFT",    d, "TOPLEFT",    0, 0)
            d._accent:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 0, 0)
            d._accent:SetWidth(3)
            d._label = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            d._label:SetPoint("LEFT",  d, "LEFT",  10, 0)
            d._label:SetPoint("RIGHT", d, "RIGHT", -8, 0)
            d._label:SetJustifyH("LEFT")
            listContent._matchDivider = d
        end
        local md = listContent._matchDivider
        md:ClearAllPoints()
        md:SetPoint("TOPLEFT",  listContent, "TOPLEFT",  0, -yOff)
        md:SetPoint("TOPRIGHT", listContent, "TOPRIGHT", 0, -yOff)
        md:SetHeight(DIVIDER_H)
        SetBD(md, C_HEADER_BG, C_HEADER_EDGE)
        md._accent:SetColorTexture(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 1)
        local matchMode = (alertObject and alertObject.anyCondition) and "Any" or "All"
        md._label:SetText("Match: " .. matchMode)
        md._label:SetTextColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.90)
        md:Show()
        yOff = yOff + DIVIDER_H + 2
    elseif listContent._matchDivider then
        listContent._matchDivider:Hide()
    end

    -- Regular (match-gated) conditions
    for _, entry in ipairs(regularEntries) do
        RenderConditionRow(entry.idx, entry.cond, false)
    end

    -- Stacks section: amber divider header + stacks rows
    if #stacksEntries > 0 then
        -- Create the divider lazily; it lives on listContent so it's fresh
        -- each time RenderInHost recreates the scroll section.
        if not listContent._stacksDivider then
            local d = CreateFrame("Frame", nil, listContent, "BackdropTemplate")
            d._accent = d:CreateTexture(nil, "ARTWORK")
            d._accent:SetPoint("TOPLEFT",    d, "TOPLEFT",    0, 0)
            d._accent:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 0, 0)
            d._accent:SetWidth(3)
            d._label = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            d._label:SetPoint("LEFT",  d, "LEFT",  10, 0)
            d._label:SetPoint("RIGHT", d, "RIGHT", -8, 0)
            d._label:SetJustifyH("LEFT")
            listContent._stacksDivider = d
        end
        local div = listContent._stacksDivider
        div:ClearAllPoints()
        div:SetPoint("TOPLEFT",  listContent, "TOPLEFT",  0, -yOff)
        div:SetPoint("TOPRIGHT", listContent, "TOPRIGHT", 0, -yOff)
        div:SetHeight(DIVIDER_H)
        SetBD(div, C_STACKS_HDR_BG, C_STACKS_HDR_EDGE)
        div._accent:SetColorTexture(C_STACKS_ACCENT[1], C_STACKS_ACCENT[2], C_STACKS_ACCENT[3], 1)
        div._label:SetText("Stacks Conditions — Behaves as a single group activating when any stack threshold is met.")
        div._label:SetTextColor(C_STACKS_ACCENT[1], C_STACKS_ACCENT[2], C_STACKS_ACCENT[3], 0.90)
        div:Show()
        yOff = yOff + DIVIDER_H + 2

        for _, entry in ipairs(stacksEntries) do
            RenderConditionRow(entry.idx, entry.cond, true)
        end
    elseif listContent._stacksDivider then
        listContent._stacksDivider:Hide()
    end

    -- Empty placeholder
    if not listContent._placeholder then
        local ph = listContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        ph:SetPoint("CENTER", listContent, "CENTER", 0, 0)
        ph:SetText("No conditions.  Click + Add to create one.")
        ph:SetTextColor(C_TEXT_SUBTLE[1], C_TEXT_SUBTLE[2], C_TEXT_SUBTLE[3], 1)
        listContent._placeholder = ph
    end

    if #conditions == 0 then
        listContent._placeholder:Show()
        listContent:SetHeight(40)
    else
        listContent._placeholder:Hide()
        listContent:SetHeight(math.max(1, yOff))
    end
end

-- ---------------------------------------------------------------------------
-- Editor section – fields for the selected condition
-- ---------------------------------------------------------------------------

function RebuildEditorFields(alertObject)
    if not editorContent then return end

    if not editorContent._fieldPool then editorContent._fieldPool = {} end
    for _, w in ipairs(editorContent._fieldPool) do w:Hide() end
    wipe(editorContent._fieldPool)

    local conditions = (alertObject and alertObject.conditions) or {}
    local cond       = conditions[selectedIndex]
    local yOff       = PAD

    local function Track(w)
        editorContent._fieldPool[#editorContent._fieldPool + 1] = w
        w:Show()
        return w
    end

    -- Locked condition: show info message, no editable fields.
    if cond and cond._locked then
        local ph = Track(editorContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
        ph:SetPoint("TOPLEFT", editorContent, "TOPLEFT", PAD, -yOff)
        ph:SetText("This condition is required and cannot be edited or removed.")
        ph:SetTextColor(C_TEXT_SUBTLE[1], C_TEXT_SUBTLE[2], C_TEXT_SUBTLE[3], 1)
        editorContent:SetHeight(40)
        return
    end

    if not cond then
        local ph = Track(editorContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
        ph:SetPoint("CENTER", editorContent, "CENTER", 0, 0)
        ph:SetText("Select a condition above to edit it.")
        ph:SetTextColor(C_TEXT_SUBTLE[1], C_TEXT_SUBTLE[2], C_TEXT_SUBTLE[3], 1)
        editorContent:SetHeight(40)
        return
    end

    -- -----------------------------------------------------------------------
    -- Field helpers
    -- -----------------------------------------------------------------------

    local function NextPoint()
        local y = yOff
        return function(w)
            w:SetPoint("TOPLEFT", editorContent, "TOPLEFT", PAD, -y)
            yOff = yOff + 46 + 8
        end
    end

    local function AddNumInput(labelText, getter, setter, isFloat)
        local place = NextPoint()
        local row = Track(Theme.CreateLabeledInput(editorContent, labelText, tostring(getter()), {
            rowWidth  = FIELD_W,
            rowHeight = 46,
            getter = function() return tostring(getter()) end,
            setter = function(v)
                local n = tonumber(v)
                if n == nil then return false end
                setter(isFloat and n or math.floor(n))
                RebuildListRows(alertObject)
            end,
        }))
        place(row)
        return row
    end

    local function AddToggle(labelText, getter, setter)
        local place = NextPoint()
        local tog = Track(Theme.CreateToggle(editorContent, FIELD_W, 46, labelText, getter(),
            function(checked)
                setter(checked)
                RebuildListRows(alertObject)
            end))
        place(tog)
        return tog
    end

    -- Generic searchable dropdown backed by an entries table.
    -- Entries: { value, label }.  getter/setter work on cond fields.
    local function AddSearchDropdown(labelText, entries, getter, setter)
        local place = NextPoint()
        local function CurLabel() return FindEntryLabel(entries, getter(), "Select") end
        local dd
        dd = Track(Theme.CreateDropdown(editorContent, labelText, CurLabel(),
            function(self)
                if not MenuUtil or not MenuUtil.CreateContextMenu then return end
                MenuUtil.CreateContextMenu(self, function(_, root)
                    for _, e in ipairs(entries) do
                        local ev = e.value
                        root:CreateRadio(e.label,
                            function() return getter() == ev end,
                            function()
                                setter(ev)
                                if dd and dd.SetValueText then dd:SetValueText(CurLabel()) end
                                RebuildListRows(alertObject)
                            end)
                    end
                end)
            end,
            { height = 46 }))
        dd:SetWidth(FIELD_W)
        place(dd)
        return dd
    end

    -- Operator dropdown for range-capable conditions.
    -- When "between" is chosen an extra "Low threshold" row appears below.
    local function AddRangeOperator(highLabel, lowLabel, opGetter, opSetter,
                                    highGetter, highSetter,
                                    lowGetter,  lowSetter, isFloat)
        -- operator row
        local opPlace = NextPoint()
        local function CurOpLabel()
            for _, o in ipairs(RANGE_OPERATOR_OPTIONS) do
                if o.value == opGetter() then return o.label end
            end
            return RANGE_OPERATOR_OPTIONS[1].label
        end
        local opDD
        opDD = Track(Theme.CreateDropdown(editorContent, "Operator", CurOpLabel(),
            function(self)
                if not MenuUtil or not MenuUtil.CreateContextMenu then return end
                MenuUtil.CreateContextMenu(self, function(_, root)
                    for _, o in ipairs(RANGE_OPERATOR_OPTIONS) do
                        local ov = o.value
                        root:CreateRadio(o.label,
                            function() return opGetter() == ov end,
                            function()
                                opSetter(ov)
                                if opDD and opDD.SetValueText then opDD:SetValueText(CurOpLabel()) end
                                RebuildListRows(alertObject)
                                -- Re-render so the low-threshold row appears/disappears
                                RebuildEditorFields(alertObject)
                            end)
                    end
                end)
            end,
            { height = 46 }))
        opDD:SetWidth(FIELD_W)
        opPlace(opDD)

        -- High / single threshold
        AddNumInput(highLabel, highGetter, highSetter, isFloat)

        -- Low threshold (only shown for "between")
        if opGetter() == "between" then
            AddNumInput(lowLabel, lowGetter, lowSetter, isFloat)
        end
    end

    -- -----------------------------------------------------------------------
    -- Per-type fields
    -- -----------------------------------------------------------------------
    local t = cond.type

    if t == "always" then
        local info = Track(editorContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
        info:SetPoint("TOPLEFT", editorContent, "TOPLEFT", PAD, -yOff)
        info:SetText("This condition is always active.  No fields to configure.")
        info:SetTextColor(C_TEXT_SUBTLE[1], C_TEXT_SUBTLE[2], C_TEXT_SUBTLE[3], 1)
        yOff = yOff + 20

    elseif t == "buff" then
        local buffEntries = GetBuffEntries()
        AddSearchDropdown("Buff", buffEntries,
            function() return cond.cooldownID end,
            function(v) cond.cooldownID = v end)
        AddToggle("Negate  (active when buff is NOT present)",
            function() return cond.negate == true end,
            function(v) cond.negate = v end)

    elseif t == "cooldown" then
        local spellEntries = GetSpellEntries()
        AddSearchDropdown("Spell", spellEntries,
            function() return cond.cooldownID end,
            function(v) cond.cooldownID = v end)
        AddToggle("Negate  (active when NOT on cooldown)",
            function() return cond.negate == true end,
            function(v) cond.negate = v end)

    elseif t == "buffDuration" then
        local buffEntries = GetBuffEntries()
        AddSearchDropdown("Buff", buffEntries,
            function() return cond.cooldownID end,
            function(v) cond.cooldownID = v end)
        AddRangeOperator(
            "Threshold (seconds)",  "Low threshold (seconds)",
            function() return cond.operator or ">=" end,
            function(v) cond.operator = v end,
            function() return cond.threshold or 0 end,
            function(v) cond.threshold = math.max(0, v) end,
            function() return cond.thresholdLow or 0 end,
            function(v) cond.thresholdLow = math.max(0, v) end,
            true)

    elseif t == "power" then
        local powerEntries = GetPowerEntries()
        AddSearchDropdown("Power type", powerEntries,
            function() return cond.triggeringPowerType end,
            function(v)
                cond.triggeringPowerType = v
                -- Derive eventPowerType automatically from the map
                local pm = ns.Utils and ns.Utils.GetUnitPowerMap and ns.Utils.GetUnitPowerMap() or {}
                cond.eventPowerType = pm[v] or cond.eventPowerType
            end)
        AddRangeOperator(
            "Threshold  (0–1,  e.g. 0.5 = 50%)",  "Low threshold  (0–1)",
            function() return cond.operator or ">=" end,
            function(v) cond.operator = v end,
            function() return cond.threshold or 0.4 end,
            function(v)
                cond.threshold  = math.max(0, math.min(1, v))
                cond.threshhold = cond.threshold   -- keep legacy field in sync
            end,
            function() return cond.thresholdLow or 0 end,
            function(v) cond.thresholdLow = math.max(0, math.min(1, v)) end,
            true)

    elseif t == "stacks" then
        local warn = Track(editorContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
        warn:SetPoint("TOPLEFT", editorContent, "TOPLEFT", PAD, -yOff)
        warn:SetWidth(FIELD_W)
        warn:SetJustifyH("LEFT")
        warn:SetText("|cFFFFCC44\u26a0|r  Only buffs that track stack counts are supported.\nBuffs without stacks will not activate this condition.")
        warn:SetTextColor(C_STACKS_ACCENT[1], C_STACKS_ACCENT[2], C_STACKS_ACCENT[3], 1)
        yOff = yOff + warn:GetStringHeight() + 10
        local buffEntries = GetBuffEntries()
        AddSearchDropdown("Buff", buffEntries,
            function() return cond.cooldownID end,
            function(v) cond.cooldownID = v end)
        -- Operator: >= / > only
        local place = NextPoint()
        local function CurOpLabel()
            for _, o in ipairs(STACKS_OPERATOR_OPTIONS) do
                if o.value == (cond.operator or ">=") then return o.label end
            end
            return STACKS_OPERATOR_OPTIONS[1].label
        end
        local opDD
        opDD = Track(Theme.CreateDropdown(editorContent, "Operator", CurOpLabel(),
            function(self)
                if not MenuUtil or not MenuUtil.CreateContextMenu then return end
                MenuUtil.CreateContextMenu(self, function(_, root)
                    for _, o in ipairs(STACKS_OPERATOR_OPTIONS) do
                        local ov = o.value
                        root:CreateRadio(o.label,
                            function() return (cond.operator or ">=") == ov end,
                            function()
                                cond.operator = ov
                                if opDD and opDD.SetValueText then opDD:SetValueText(CurOpLabel()) end
                                RebuildListRows(alertObject)
                            end)
                    end
                end)
            end,
            { height = 46 }))
        opDD:SetWidth(FIELD_W)
        place(opDD)

        AddNumInput("Stack threshold",
            function() return cond.threshold or 1 end,
            function(v) cond.threshold = math.max(1, math.floor(v)) end)
    end

    editorContent:SetHeight(math.max(1, yOff + PAD))
end

-- ---------------------------------------------------------------------------
-- Public: RenderInHost
-- Called by AlertEditor each time the Conditions tab is shown.
-- ---------------------------------------------------------------------------

function ConditionEditor.RenderInHost(host, alertObject)
    if not host then return end

    activeHost        = host
    activeAlertObject = alertObject

    -- Clamp selected index to valid range
    local conditions = (alertObject and alertObject.conditions) or {}
    if selectedIndex < 1 or selectedIndex > math.max(1, #conditions) then
        selectedIndex = 1
    end

    -- Hide direct children left over from the previous render
    for _, child in ipairs({ host:GetChildren() }) do
        child:Hide()
    end

    -- Measure host (fallback if layout hasn't run yet)
    local hostH = host:GetHeight()
    if hostH < 20 then hostH = 400 end

    -- Section height math
    local HEADER_H  = 28
    local ACTIONS_H = 32
    local GAP       = 4
    local usable    = hostH - HEADER_H - ACTIONS_H - GAP * 2
    local listH     = math.floor(usable * 0.45)
    local editH     = usable - listH

    -- -------------------------------------------------------------------------
    -- Header bar
    -- -------------------------------------------------------------------------
    local header = CreateFrame("Frame", nil, host, "BackdropTemplate")
    header:SetPoint("TOPLEFT",  host, "TOPLEFT",  0, 0)
    header:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 0)
    header:SetHeight(HEADER_H)
    SetBD(header, { 0.06, 0.08, 0.10, 0.96 }, { 0.18, 0.22, 0.26, 0.95 })

    local titleAccent = header:CreateTexture(nil, "ARTWORK")
    titleAccent:SetPoint("TOPLEFT",    header, "TOPLEFT",    0, 0)
    titleAccent:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    titleAccent:SetWidth(3)
    titleAccent:SetColorTexture(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 1)
    titleAccent:Hide()

    local titleLbl = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleLbl:SetPoint("LEFT", header, "LEFT", 10, 0)
    titleLbl:SetText("Conditions")
    titleLbl:SetTextColor(C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3], 1)

    -- "Match: Any | All" button (right side of header)
    local anyAllBtn
    anyAllBtn = Theme.CreateButton(header, 44, 20, "", {
        onClick = function()
            if alertObject then
                alertObject.anyCondition = not alertObject.anyCondition
                anyAllBtn:SetButtonText(alertObject.anyCondition and "Any" or "All")
                RebuildListRows(alertObject)
            end
        end,
    })
    anyAllBtn:SetPoint("RIGHT", header, "RIGHT", -PAD, 0)
    anyAllBtn:SetButtonText((alertObject and alertObject.anyCondition) and "Any" or "All")

    local matchPfxLbl = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    matchPfxLbl:SetPoint("RIGHT", anyAllBtn, "LEFT", -4, 0)
    matchPfxLbl:SetText("Match:")
    matchPfxLbl:SetTextColor(C_TEXT_LABEL[1], C_TEXT_LABEL[2], C_TEXT_LABEL[3], 1)

    -- -------------------------------------------------------------------------
    -- Condition list scroll section
    -- -------------------------------------------------------------------------
    local listOuter, _lSF, lContent = BuildScrollSection(host, -HEADER_H, listH)
    listContent              = lContent
    listContent._rowPool     = {}
    listContent._placeholder = nil

    -- -------------------------------------------------------------------------
    -- Action row  (+ Add  /  – Remove)
    -- -------------------------------------------------------------------------
    local actionRow = CreateFrame("Frame", nil, host, "BackdropTemplate")
    actionRow:SetPoint("TOPLEFT",  listOuter, "BOTTOMLEFT",  0, -GAP)
    actionRow:SetPoint("TOPRIGHT", listOuter, "BOTTOMRIGHT", 0, -GAP)
    actionRow:SetHeight(ACTIONS_H)
    SetBD(actionRow, { 0.04, 0.05, 0.07, 0.70 }, { 0.12, 0.15, 0.18, 0.80 })

    -- Returns true if alertObject already has a "secret" condition
    -- (buffDuration or power). Only one of these is allowed at a time because
    -- they both drive the alpha curve and only one can own it.
    local function HasSecretCondition()
        if not alertObject or not alertObject.conditions then return false end
        for _, c in ipairs(alertObject.conditions) do
            if c.type == "buffDuration" or c.type == "power" then
                return true
            end
        end
        return false
    end

    -- Stacks conditions are border-only and have their own dedicated button.
    -- Check both the persisted borderKey and the draft _editorType so new
    -- alerts (which don't have a borderKey yet) are handled correctly.
    local isBorderAlert = alertObject and (alertObject.borderKey ~= nil or alertObject._editorType == "border")

    local SECRET_TYPES = { buffDuration = true, power = true }

    local addBtn = Theme.CreateButton(actionRow, 72, 24, "+ Add", {
        onClick = function(self)
            if not MenuUtil or not MenuUtil.CreateContextMenu then return end
            local hasSecret = HasSecretCondition()
            MenuUtil.CreateContextMenu(self, function(_, root)
                for _, def in ipairs(CONDITION_DEFS) do
                    local dtype    = def.type
                    local isSecret = SECRET_TYPES[dtype]
                    -- Stacks has its own dedicated button; skip it here.
                    if dtype == "stacks" then
                        -- skip
                    else
                        local elem = root:CreateButton(def.label, function()
                            if not alertObject then return end
                            alertObject.conditions = alertObject.conditions or {}
                            local newCond = { type = dtype }
                            if dtype == "buff" or dtype == "cooldown" then
                                newCond.cooldownID = alertObject.cooldownID or nil
                                newCond.negate     = false
                            elseif dtype == "buffDuration" then
                                newCond.cooldownID   = alertObject.cooldownID or nil
                                newCond.operator     = ">="
                                newCond.threshold    = 1
                                newCond.thresholdLow = 0
                            elseif dtype == "power" then
                                local pe = GetPowerEntries()
                                local firstPower = pe[1] and pe[1].value or 0
                                local pm = ns.Utils and ns.Utils.GetUnitPowerMap and ns.Utils.GetUnitPowerMap() or {}
                                newCond.triggeringPowerType = firstPower
                                newCond.eventPowerType      = pm[firstPower] or "MANA"
                                newCond.operator            = ">="
                                newCond.threshold           = 0.4
                                newCond.thresholdLow        = 0
                            end
                            alertObject.conditions[#alertObject.conditions + 1] = newCond
                            selectedIndex = #alertObject.conditions
                            RebuildListRows(alertObject)
                            RebuildEditorFields(alertObject)
                        end)
                        if isSecret and hasSecret and elem then
                            elem:SetEnabled(false)
                        end
                    end
                end
            end)
        end,
    })
    addBtn:SetPoint("LEFT", actionRow, "LEFT", PAD, 0)

    -- Dedicated Stacks button — border alerts only, no limit on count.
    -- Multiple stacks conditions act as an OR group: the border triggers when
    -- any one of them is satisfied.
    local stacksBtn = Theme.CreateButton(actionRow, 80, 24, "+ Stacks", {
        onClick = function()
            if not alertObject then return end
            alertObject.conditions = alertObject.conditions or {}
            alertObject.conditions[#alertObject.conditions + 1] = {
                type       = "stacks",
                cooldownID = alertObject.cooldownID or nil,
                operator   = ">=",
                threshold  = 1,
            }
            selectedIndex = #alertObject.conditions
            RebuildListRows(alertObject)
            RebuildEditorFields(alertObject)
        end,
    })
    stacksBtn:SetPoint("LEFT", addBtn, "RIGHT", PAD, 0)
    if not isBorderAlert then
        stacksBtn:Hide()
    end

    local remBtn = Theme.CreateButton(actionRow, 80, 24, "– Remove", {
        onClick = function()
            if not alertObject or not alertObject.conditions then return end
            local conds = alertObject.conditions
            -- Never allow removal of locked conditions.
            if conds[selectedIndex] and conds[selectedIndex]._locked then return end
            if selectedIndex >= 1 and selectedIndex <= #conds then
                table.remove(conds, selectedIndex)
                selectedIndex = math.max(1, math.min(selectedIndex, #conds))
                RebuildListRows(alertObject)
                RebuildEditorFields(alertObject)
            end
        end,
    })
    remBtn:SetPoint("RIGHT", actionRow, "RIGHT", -PAD, 0)

    -- -------------------------------------------------------------------------
    -- Field editor scroll section
    -- -------------------------------------------------------------------------
    local editorTopY = -(HEADER_H + listH + ACTIONS_H + GAP * 2)
    local _edOuter, _eSF, eContent = BuildScrollSection(host, editorTopY, editH)
    editorContent            = eContent
    editorContent._fieldPool = {}

    -- -------------------------------------------------------------------------
    -- Initial fill
    -- -------------------------------------------------------------------------
    RebuildListRows(alertObject)
    RebuildEditorFields(alertObject)
end

-- ---------------------------------------------------------------------------
-- Compatibility stubs  (kept so callers don't break)
-- ---------------------------------------------------------------------------
function ConditionEditor.Open()  end

function ConditionEditor.Close()
    activeHost = nil
end

function ConditionEditor.IsVisible()
    return activeHost ~= nil and activeHost:IsShown() or false
end

function ConditionEditor.GetFrame()
    return activeHost
end

function ConditionEditor.Reposition() end

function ConditionEditor.Refresh()
    if activeHost and activeHost:IsShown() then
        RebuildListRows(activeAlertObject)
        RebuildEditorFields(activeAlertObject)
    end
end
