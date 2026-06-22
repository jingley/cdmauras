local _, ns = ...

---@diagnostic disable: undefined-global

-------------------------------------------------------------------------------
-- Theme
-- Shared visual utility library for CDMAuras alert option UI.
--
-- PALETTE
--   All colours are { r, g, b, a } arrays. The palette is defined once at the
--   top of this file. Every component in this file reads from those constants
--   so changing a colour here changes it everywhere.
--
-- PUBLIC API  (accessed via ns.Theme)
--   FontString helpers
--     Theme.TrackFontString(fontString, owner?)
--       Registers fontString for auto-truncation tooltip on its owner.
--
--   Backdrop helpers
--     Theme.ApplyBackdrop(frame, style?)
--       Paints a solid backdrop on frame. style = "panel"|"header"|"inset" (default "panel").
--
--   Scrollbar
--     Theme.ApplyScrollBar(scrollFrame)
--       Skins the ScrollBar child of a WoW ScrollFrame.
--
--   Input box
--     Theme.ApplyInputBox(editBox)
--       Skins an EditBox (InputBoxTemplate or bare) with focus/hover states.
--       Returns the editBox for chaining.
--
--   Labeled input row
--     row, label, input = Theme.CreateLabeledInput(parent, labelText, valueText, options?)
--       options.rowWidth, options.rowHeight, options.inputHeight
--       Clicking anywhere in the bordered container focuses the input.
--
--   Button
--     button = Theme.CreateButton(parent, width, height, text, options?)
--       options.enabled (bool, default true)
--       options.onClick (function)
--       options.kind = "normal"|"header" (default "normal")
--
--   Toggle (checkbox-style button)
--     toggle = Theme.CreateToggle(parent, width, height, text, checked, onToggle, options?)
--       options.enabled (bool, default true)
--       options.kind = "normal"|"header" (default "normal")
--       toggle:SetChecked(bool)  – update checked state externally
--
--   Dropdown button
--     dropdown = Theme.CreateDropdown(parent, labelText, valueText, onClick, options?)
--       options.enabled (bool, default true)
--       dropdown:SetValueText(text) – update displayed value
--       dropdown:SetEnabled(bool)   – enable/disable
--
--   Action row (labelled panel row with optional buttons)
--     row = Theme.CreateActionRow(parent, anchorFrame, titleText, descriptionText?, options?)
--       options.buttons = { { text, width?, onClick } }
--       options.onLeftClick, options.onRightClick
--       options.isSelected (bool)
--
--   Header bar (clickable section header with accent stripe)
--     header = Theme.CreateHeader(parent, anchorFrame, titleText, options?)
--       options.onClick
--       options.onRightClick (function receiving rootDescription)
--       options.rightText    (small right-hand label)
--       options.expandable   (bool – shows [+]/[-] arrow, expects options.isExpanded)
--       options.withToggle   (bool – shows checkbox on right edge)
--       options.checked, options.onToggle (used when withToggle = true)
--       options.enabled      (bool, default true)
--       options.width        (number, default fills parent)
--       options.frameName    (global name, optional)
--       header:SetExpanded(bool)
--       header:SetChecked(bool)   (only when withToggle = true)
-------------------------------------------------------------------------------

local Theme = {}
ns.Theme = Theme

-- ---------------------------------------------------------------------------
-- Palette
-- ---------------------------------------------------------------------------

-- Normal interactive surface
local C_PANEL_BG          = { 0.06, 0.07, 0.09, 0.96 }
local C_PANEL_EDGE        = { 0.18, 0.22, 0.26, 0.95 }

-- Hover state (normal surface)
local C_HOVER_BG          = { 0.09, 0.11, 0.14, 0.98 }
local C_HOVER_EDGE        = { 0.26, 0.62, 0.53, 1    }

-- Active / focused state
local C_ACTIVE_BG         = { 0.08, 0.11, 0.12, 0.98 }
local C_ACTIVE_EDGE       = { 0.30, 0.78, 0.62, 1    }

-- Disabled state
local C_DISABLED_BG       = { 0.05, 0.06, 0.07, 0.80 }
local C_DISABLED_EDGE     = { 0.14, 0.16, 0.18, 0.85 }

-- Header / section-header surface (darker teal tint)
local C_HEADER_BG         = { 0.03, 0.16, 0.13, 0.82 }
local C_HEADER_EDGE       = { 0.18, 0.45, 0.38, 0.95 }
local C_HEADER_HOVER_BG   = { 0.05, 0.22, 0.18, 0.92 }
local C_HEADER_HOVER_EDGE = { 0.24, 0.60, 0.52, 1    }

-- Inset content area (barely visible tint)
local C_INSET_BG          = { 0.04, 0.05, 0.07, 0.72 }
local C_INSET_EDGE        = { 0.13, 0.15, 0.18, 0.90 }

-- Accent stripe colour (left edge of header bars)
local C_ACCENT            = { 0.30, 0.86, 0.70, 1    }

-- Checked / active checkbox tint
local C_CHECK_BG          = { 0.08, 0.30, 0.22, 0.95 }
local C_CHECK_EDGE        = { 0.24, 0.62, 0.53, 1    }
local C_CHECK_MARK        = { 0.52, 0.92, 0.80, 1    }

-- Text colours
local C_TEXT_NORMAL       = { 0.88, 0.98, 0.93, 1    }
local C_TEXT_LABEL        = { 0.52, 0.86, 0.75, 1    }
local C_TEXT_SUBTLE       = { 0.64, 0.69, 0.74, 1    }
local C_TEXT_DISABLED     = { 0.44, 0.56, 0.52, 1    }
local C_TEXT_HOVER        = { 1,    1,    1,    1    }

-- ---------------------------------------------------------------------------
-- Internal: backdrop factory
-- ---------------------------------------------------------------------------

-- Creates/updates the WoW backdrop on `frame` from two colour arrays.
-- `hideEdge` removes the 1-px border entirely (useful for inset backgrounds).
local function SetBackdrop(frame, bg, edge, hideEdge)
    if not frame then return end
    if not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = not hideEdge and "Interface\\Buttons\\WHITE8X8" or nil,
        edgeSize = not hideEdge and 1 or nil,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    if not hideEdge then
        frame:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4])
    end
end

-- Selects the right pair of bg/edge colours for a given style + state.
-- style   = "panel" | "header"
-- state   = "normal" | "hover" | "active" | "disabled"
local function StyleColors(style, state)
    if state == "disabled" then
        return C_DISABLED_BG, C_DISABLED_EDGE
    end
    if style == "header" then
        if state == "hover"  then return C_HEADER_HOVER_BG, C_HEADER_HOVER_EDGE end
        return C_HEADER_BG, C_HEADER_EDGE
    end
    if state == "hover"  then return C_HOVER_BG,  C_HOVER_EDGE  end
    if state == "active" then return C_ACTIVE_BG, C_ACTIVE_EDGE end
    return C_PANEL_BG, C_PANEL_EDGE
end

-- ---------------------------------------------------------------------------
-- Public: ApplyBackdrop
-- ---------------------------------------------------------------------------

--- Paint a themed backdrop onto `frame`.
--- @param frame   Frame
--- @param style   "panel"|"header"|"inset"  (default "panel")
function Theme.ApplyBackdrop(frame, style)
    if not frame then return end
    style = style or "panel"
    if style == "inset" then
        SetBackdrop(frame, C_INSET_BG, C_INSET_EDGE)
    elseif style == "header" then
        SetBackdrop(frame, C_HEADER_BG, C_HEADER_EDGE)
    else
        SetBackdrop(frame, C_PANEL_BG, C_PANEL_EDGE)
    end
end

-- ---------------------------------------------------------------------------
-- Internal: truncation tooltip for FontStrings
-- ---------------------------------------------------------------------------

-- Registers `fontString` on `owner` so that when the owner is hovered and the
-- fontstring is truncated (IsTruncated()), a GameTooltip shows the full text.
-- Only one OnEnter/OnLeave hook is installed per owner regardless of how many
-- fontstrings are registered.
local function RegisterFontStringTooltip(fontString, owner)
    owner = owner or (fontString.GetParent and fontString:GetParent())
    if not owner then return end

    fontString:SetWordWrap(false)

    -- Per-owner provider list
    if not owner._cdmFontProviders then
        owner._cdmFontProviders = {}
    end
    -- Avoid double-registration
    for _, p in ipairs(owner._cdmFontProviders) do
        if p == fontString then return end
    end
    owner._cdmFontProviders[#owner._cdmFontProviders + 1] = fontString

    if owner._cdmFontTooltipHooked then return end
    owner._cdmFontTooltipHooked = true

    owner:HookScript("OnEnter", function(self)
        if not GameTooltip then return end
        local providers = self._cdmFontProviders
        if not providers then return end

        for _, fs in ipairs(providers) do
            -- Only show tooltip when text is actually cut off
            if fs.IsTruncated and fs:IsTruncated() then
                local text = fs:GetText()
                if text and text ~= "" then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:ClearLines()
                    GameTooltip:AddLine(text, 1, 1, 1, true)
                    GameTooltip:Show()
                    return
                end
            end
        end
    end)

    owner:HookScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

-- ---------------------------------------------------------------------------
-- Public: TrackFontString
-- ---------------------------------------------------------------------------

--- Register a font string so it shows a tooltip on its owner when truncated.
--- Sets wordWrap = false automatically.
--- @param fontString FontString
--- @param owner      Frame|nil  (defaults to fontString:GetParent())
function Theme.TrackFontString(fontString, owner)
    if not fontString then return end
    RegisterFontStringTooltip(fontString, owner)
end

-- ---------------------------------------------------------------------------
-- Public: ApplyScrollBar
-- ---------------------------------------------------------------------------

--- Skin the ScrollBar child of a standard WoW ScrollFrame.
--- Hides the up/down arrow buttons and replaces the thumb with a thin teal bar.
--- @param scrollFrame ScrollFrame
function Theme.ApplyScrollBar(scrollFrame)
    local scrollBar = scrollFrame and scrollFrame.ScrollBar
    if not scrollBar then return end

    -- Slim, teal thumb texture
    local thumb = scrollBar.ThumbTexture
                  or (scrollBar.GetThumbTexture and scrollBar:GetThumbTexture())
    if thumb then
        thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
        thumb:SetVertexColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.85)
        thumb:SetWidth(5)
    end

    -- Hide arrow buttons; keep them functional so scroll math still works
    local function HideArrow(btn)
        if not btn then return end
        btn:Hide()
        if not btn._cdmShowBlocked then
            btn:SetScript("OnShow", function(self) self:Hide() end)
            btn._cdmShowBlocked = true
        end
    end
    HideArrow(scrollBar.ScrollUpButton)
    HideArrow(scrollBar.ScrollDownButton)

    -- Auto-hide the scrollbar itself when not scrollable
    local function RefreshVisibility()
        local canUp   = scrollBar.ScrollUpButton   and scrollBar.ScrollUpButton:IsEnabled()
        local canDown = scrollBar.ScrollDownButton and scrollBar.ScrollDownButton:IsEnabled()
        scrollBar:SetShown(canUp or canDown or false)
    end

    if not scrollBar._cdmVisibilityHooked then
        scrollBar:HookScript("OnMinMaxChanged", RefreshVisibility)
        if scrollBar.ScrollUpButton then
            scrollBar.ScrollUpButton:HookScript("OnEnable",  RefreshVisibility)
            scrollBar.ScrollUpButton:HookScript("OnDisable", RefreshVisibility)
        end
        if scrollBar.ScrollDownButton then
            scrollBar.ScrollDownButton:HookScript("OnEnable",  RefreshVisibility)
            scrollBar.ScrollDownButton:HookScript("OnDisable", RefreshVisibility)
        end
        scrollBar._cdmVisibilityHooked = true
    end

    -- Hover highlight on the thumb
    if not scrollBar._cdmHoverHooked then
        scrollBar:HookScript("OnEnter", function()
            if thumb then thumb:SetVertexColor(C_ACTIVE_EDGE[1], C_ACTIVE_EDGE[2], C_ACTIVE_EDGE[3], 1) end
        end)
        scrollBar:HookScript("OnLeave", function()
            if thumb then thumb:SetVertexColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.85) end
        end)
        scrollBar._cdmHoverHooked = true
    end

    RefreshVisibility()
end

-- ---------------------------------------------------------------------------
-- Public: ApplyInputBox
-- ---------------------------------------------------------------------------

--- Skin an EditBox so it uses the CDMA panel palette.
--- Supports hover, focus, and disabled states.
--- Hides the default InputBoxTemplate chrome (Left/Middle/Right).
--- @param editBox EditBox
--- @return EditBox  (the same box, for chaining)
function Theme.ApplyInputBox(editBox)
    if not editBox then return editBox end
    if editBox._cdmInputApplied then return editBox end
    editBox._cdmInputApplied = true

    -- Hide Blizzard template chrome
    if editBox.Left   then editBox.Left:SetAlpha(0) end
    if editBox.Middle then editBox.Middle:SetAlpha(0) end
    if editBox.Right  then editBox.Right:SetAlpha(0) end

    -- Skin frame drawn *behind* the editBox
    local skin = CreateFrame("Frame", nil, editBox, "BackdropTemplate")
    skin:SetPoint("TOPLEFT",     editBox, "TOPLEFT",     -2,  2)
    skin:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT",  2, -2)
    skin:SetFrameLevel(math.max(0, editBox:GetFrameLevel() - 1))

    local hover  = false
    local focus  = false

    local function Refresh()
        local enabled = not editBox.IsEnabled or editBox:IsEnabled()
        if not enabled then
            SetBackdrop(skin, C_DISABLED_BG, C_DISABLED_EDGE)
            editBox:SetTextColor(C_TEXT_DISABLED[1], C_TEXT_DISABLED[2], C_TEXT_DISABLED[3], C_TEXT_DISABLED[4])
            return
        end
        if focus then
            SetBackdrop(skin, C_ACTIVE_BG, C_ACTIVE_EDGE)
            editBox:SetTextColor(C_TEXT_HOVER[1], C_TEXT_HOVER[2], C_TEXT_HOVER[3], C_TEXT_HOVER[4])
            return
        end
        if hover then
            SetBackdrop(skin, C_HOVER_BG, C_HOVER_EDGE)
            editBox:SetTextColor(C_TEXT_HOVER[1], C_TEXT_HOVER[2], C_TEXT_HOVER[3], C_TEXT_HOVER[4])
            return
        end
        SetBackdrop(skin, C_PANEL_BG, C_PANEL_EDGE)
        editBox:SetTextColor(C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3], C_TEXT_NORMAL[4])
    end

    editBox:HookScript("OnEnter",          function() hover = true;  Refresh() end)
    editBox:HookScript("OnLeave",          function() hover = false; Refresh() end)
    editBox:HookScript("OnEditFocusGained",function() focus = true;  Refresh() end)
    editBox:HookScript("OnEditFocusLost",  function() focus = false; Refresh() end)
    editBox:HookScript("OnEnable",         function()                Refresh() end)
    editBox:HookScript("OnDisable",        function()                Refresh() end)

    Refresh()
    return editBox
end

-- ---------------------------------------------------------------------------
-- Public: CreateLabeledInput
-- ---------------------------------------------------------------------------

--- Create a small label + input box row, both skinned with the panel theme.
--- The returned `row` frame should be positioned by the caller.
---
--- @param parent    Frame
--- @param labelText string
--- @param valueText string
--- @param options   table|nil
---   options.inputWidth   number    (default 180)
---   options.inputHeight  number    (default 20)
---   options.rowWidth     number    (default 220)
---   options.rowHeight    number    (default 46)
---   options.getter       function  () → string; called on reset. When nil the
---                                  last successfully committed text is used.
---   options.setter       function  (text: string) called with trimmed text on
---                                  Enter. Return false to reject (resets text).
---                                  When provided, Escape and focus-loss also
---                                  reset the displayed text automatically.
--- @return row Frame, label FontString, input EditBox
function Theme.CreateLabeledInput(parent, labelText, valueText, options)
    options = options or {}
    local rowW = options.rowWidth    or 220
    local rowH = options.rowHeight   or 46
    local inpH = options.inputHeight or 20

    local getter = options.getter  -- function() → string
    local setter = options.setter  -- function(text) → false means reject

    -- Single bordered container – clicking anywhere focuses the input,
    -- mirroring the dropdown layout (label top-left, value bottom-left).
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetSize(rowW, rowH)
    container:EnableMouse(true)

    local focus      = false
    local savedValue = valueText or ""

    local function GetResetValue()
        return getter and getter() or savedValue
    end


    -- Small teal category label (top-left, like the dropdown)
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -5)
    label:SetText(labelText or "")
    label:SetTextColor(C_TEXT_LABEL[1], C_TEXT_LABEL[2], C_TEXT_LABEL[3], C_TEXT_LABEL[4])
    RegisterFontStringTooltip(label, container)

    -- Bare EditBox anchored to the bottom of the container (no Blizzard chrome)
    local input = CreateFrame("EditBox", nil, container)
    input:SetAutoFocus(false)
    input:SetFontObject("GameFontNormal")
    input:SetPoint("BOTTOMLEFT",  container, "BOTTOMLEFT",  8, 6)
    input:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -8, 6)
    input:SetHeight(inpH)
    input:SetTextColor(C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3], C_TEXT_NORMAL[4])
    input:SetText(valueText or "")
    input:SetCursorPosition(0)

    local function Refresh()
        -- IsMouseOver covers the full container bounds (including label and input
        -- as children) so hover is always accurate even when focus is lost without
        -- the mouse physically leaving.
        local isHovered = container:IsMouseOver() or input:IsMouseOver()
        if focus then
            SetBackdrop(container, C_ACTIVE_BG, C_ACTIVE_EDGE)
        elseif isHovered then
            SetBackdrop(container, C_HOVER_BG, C_HOVER_EDGE)
        else
            SetBackdrop(container, C_PANEL_BG, C_PANEL_EDGE)
        end
    end

    -- Clicking anywhere in the container focuses the input
    container:SetScript("OnMouseDown", function() input:SetFocus() end)

    container:HookScript("OnEnter", Refresh)
    container:HookScript("OnLeave", Refresh)

    input:HookScript("OnEnter", Refresh)
    input:HookScript("OnLeave", Refresh)

    input:HookScript("OnEditFocusGained", function()
        focus = true
        input:SetTextColor(C_TEXT_HOVER[1], C_TEXT_HOVER[2], C_TEXT_HOVER[3], C_TEXT_HOVER[4])
        Refresh()
    end)
    if setter then
        input:SetScript("OnEnterPressed", function(self)
            local text = (self:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if text == "" or setter(text) == false then
                self:SetText(GetResetValue())
            else
                savedValue = getter and getter() or text
                self:SetText(savedValue)
            end
            self:ClearFocus()
        end)
        input:SetScript("OnEscapePressed", function(self)
            self:SetText(GetResetValue())
            self:ClearFocus()
        end)
    end

    input:HookScript("OnEditFocusLost", function()
        focus = false
        input:SetTextColor(C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3], C_TEXT_NORMAL[4])
        if setter then
            input:SetText(GetResetValue())
        end
        Refresh()
    end)

    Refresh()
    return container, label, input
end

-- ---------------------------------------------------------------------------
-- Internal: shared button state driver
-- ---------------------------------------------------------------------------

-- Drives backdrop colour + optional label colour for a themed button/row
-- based on (style, state) pairs.
-- `labelColor` is only set when provided.
local function RefreshButtonState(frame, labelFontString, style, hover, pressed, disabled)
    local state = "normal"
    if disabled        then state = "disabled"
    elseif pressed     then state = "active"
    elseif hover       then state = "hover"
    end

    local bg, edge = StyleColors(style, state)
    SetBackdrop(frame, bg, edge)

    if labelFontString then
        if disabled then
            labelFontString:SetTextColor(C_TEXT_DISABLED[1], C_TEXT_DISABLED[2], C_TEXT_DISABLED[3], C_TEXT_DISABLED[4])
        elseif hover or pressed then
            labelFontString:SetTextColor(C_TEXT_HOVER[1], C_TEXT_HOVER[2], C_TEXT_HOVER[3], C_TEXT_HOVER[4])
        else
            labelFontString:SetTextColor(C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3], C_TEXT_NORMAL[4])
        end
    end
end

-- ---------------------------------------------------------------------------
-- Internal: checkbox sub-frame
-- ---------------------------------------------------------------------------

local function CreateCheckbox(parent)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetSize(16, 16)
    SetBackdrop(box, C_PANEL_BG, C_PANEL_EDGE)

    local mark = box:CreateTexture(nil, "OVERLAY")
    mark:SetAllPoints(box)
    mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    mark:SetVertexColor(C_CHECK_MARK[1], C_CHECK_MARK[2], C_CHECK_MARK[3], C_CHECK_MARK[4])
    mark:Hide()

    -- Refresh the checkbox visual from the current checked/enabled booleans
    function box:Refresh(isChecked, isEnabled)
        if isEnabled then
            if isChecked then
                SetBackdrop(self, C_CHECK_BG, C_CHECK_EDGE)
                mark:SetVertexColor(C_CHECK_MARK[1], C_CHECK_MARK[2], C_CHECK_MARK[3], 1)
                mark:Show()
            else
                SetBackdrop(self, C_PANEL_BG, C_PANEL_EDGE)
                mark:Hide()
            end
        else
            -- Disabled tint
            SetBackdrop(self, C_DISABLED_BG, C_DISABLED_EDGE)
            if isChecked then
                mark:SetVertexColor(C_CHECK_MARK[1], C_CHECK_MARK[2], C_CHECK_MARK[3], 0.50)
                mark:Show()
            else
                mark:Hide()
            end
        end
    end

    return box
end

-- ---------------------------------------------------------------------------
-- Public: CreateButton
-- ---------------------------------------------------------------------------

--- Create a themed backdrop button.
---
--- @param parent  Frame
--- @param width   number
--- @param height  number
--- @param text    string
--- @param options table|nil
---   options.enabled  bool      (default true)
---   options.onClick  function
---   options.kind     "normal"|"header"  (default "normal")
--- @return Button
function Theme.CreateButton(parent, width, height, text, options)
    options = options or {}
    local style   = options.kind == "header" and "header" or "panel"
    local enabled = options.enabled ~= false

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:RegisterForClicks("LeftButtonUp")

    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("CENTER")
    lbl:SetText(text or "")
    RegisterFontStringTooltip(lbl, btn)
    btn._cdmLabel = lbl

    local hover, pressed = false, false

    local function Refresh()
        RefreshButtonState(btn, lbl, style, hover, pressed, not enabled)
    end

    btn:SetScript("OnEnter",    function() hover   = true;  pressed = false; Refresh() end)
    btn:SetScript("OnLeave",    function() hover   = false; pressed = false; Refresh() end)
    btn:SetScript("OnMouseDown",function() if enabled then pressed = true  end; Refresh() end)
    btn:SetScript("OnMouseUp",  function() pressed = false; Refresh() end)
    if options.onClick then
        btn:SetScript("OnClick", function() if enabled then options.onClick() end end)
    end

    --- Enable or disable this button.
    function btn:SetButtonEnabled(value)
        enabled = value and true or false
        Refresh()
    end

    --- Update the label text.
    function btn:SetButtonText(newText)
        lbl:SetText(newText or "")
    end

    Refresh()
    return btn
end

-- ---------------------------------------------------------------------------
-- Public: CreateToggle
-- ---------------------------------------------------------------------------

--- Create a themed toggle (row button with a checkbox on the right edge).
---
--- @param parent    Frame
--- @param width     number
--- @param height    number
--- @param text      string
--- @param checked   bool
--- @param onToggle  function(newChecked: bool)
--- @param options   table|nil
---   options.enabled  bool             (default true)
---   options.kind     "normal"|"header" (default "normal")
--- @return Button  (has :SetChecked(bool) method)
function Theme.CreateToggle(parent, width, height, text, checked, onToggle, options)
    options = options or {}
    local style   = options.kind == "header" and "header" or "panel"
    local enabled = options.enabled ~= false
    local isChecked = checked and true or false

    local toggle = CreateFrame("Button", nil, parent, "BackdropTemplate")
    toggle:SetSize(width, height)
    toggle:RegisterForClicks("LeftButtonUp")

    local lbl = toggle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("LEFT",  toggle, "LEFT",  8, 0)
    lbl:SetPoint("RIGHT", toggle, "RIGHT", -32, 0)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(text or "")
    RegisterFontStringTooltip(lbl, toggle)

    local box = CreateCheckbox(toggle)
    box:SetPoint("RIGHT", toggle, "RIGHT", -8, 0)

    local hover = false

    local function Refresh()
        RefreshButtonState(toggle, lbl, style, hover, false, not enabled)
        box:Refresh(isChecked, enabled)
    end

    toggle:SetScript("OnEnter", function() hover = true;  Refresh() end)
    toggle:SetScript("OnLeave", function() hover = false; Refresh() end)
    toggle:SetScript("OnShow",  function() Refresh() end)
    toggle:SetScript("OnClick", function()
        if not enabled then return end
        isChecked = not isChecked
        Refresh()
        if onToggle then onToggle(isChecked) end
    end)
    -- Defer first paint one frame so frame level is settled
    toggle:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        Refresh()
    end)

    --- Programmatically update the checked state without firing onToggle.
    function toggle:SetChecked(value)
        isChecked = value and true or false
        Refresh()
    end

    --- Enable or disable the toggle.
    function toggle:SetToggleEnabled(value)
        enabled = value and true or false
        Refresh()
    end

    Refresh()
    return toggle
end

-- ---------------------------------------------------------------------------
-- Public: CreateDropdown
-- ---------------------------------------------------------------------------

--- Create a themed dropdown trigger button (label above, value + arrow below).
--- The caller is responsible for opening the actual menu via onClick.
---
--- @param parent    Frame
--- @param labelText string   (small teal label at the top)
--- @param valueText string   (the currently selected value shown in the button)
--- @param onClick   function(self)  – called when the button is clicked; open your context menu here
--- @param options   table|nil
---   options.enabled  bool (default true)
---   options.height   number (default 34)
--- @return Button  (has :SetValueText(text) and :SetDropdownEnabled(bool) methods)
function Theme.CreateDropdown(parent, labelText, valueText, onClick, options)
    options = options or {}
    local enabled = options.enabled ~= false

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(options.height or 34)
    btn:RegisterForClicks("LeftButtonUp")

    -- Small teal category label (top-left)
    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", btn, "TOPLEFT", 8, -5)
    lbl:SetText(labelText or "")
    lbl:SetTextColor(C_TEXT_LABEL[1], C_TEXT_LABEL[2], C_TEXT_LABEL[3], C_TEXT_LABEL[4])
    RegisterFontStringTooltip(lbl, btn)

    -- Selected value (bottom-left, stretching away from arrow)
    local val = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    val:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 8, 6)
    val:SetPoint("RIGHT", btn, "RIGHT", -20, 0)
    val:SetJustifyH("LEFT")
    val:SetText(valueText or "")
    RegisterFontStringTooltip(val, btn)

    -- Chevron arrow (right edge)
    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrow:SetPoint("RIGHT", btn, "RIGHT", -7, 0)
    arrow:SetText("|TInterface\\WorldStateFrame\\DownArrow:12:12:0:0|t")

    local hover = false

    local function Refresh()
        if not enabled then
            SetBackdrop(btn, C_DISABLED_BG, C_DISABLED_EDGE)
            val:SetTextColor(C_TEXT_DISABLED[1], C_TEXT_DISABLED[2], C_TEXT_DISABLED[3], C_TEXT_DISABLED[4])
            arrow:SetAlpha(0.40)
            return
        end
        if hover then
            SetBackdrop(btn, C_HOVER_BG, C_HOVER_EDGE)
            val:SetTextColor(C_TEXT_HOVER[1], C_TEXT_HOVER[2], C_TEXT_HOVER[3], C_TEXT_HOVER[4])
        else
            SetBackdrop(btn, C_PANEL_BG, C_PANEL_EDGE)
            val:SetTextColor(C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3], C_TEXT_NORMAL[4])
        end
        arrow:SetAlpha(1)
    end

    btn:SetScript("OnEnter", function() hover = true;  Refresh() end)
    btn:SetScript("OnLeave", function() hover = false; Refresh() end)
    btn:SetScript("OnClick", function(self)
        if enabled and onClick then onClick(self) end
    end)

    --- Update the displayed value text.
    function btn:SetValueText(text)
        val:SetText(text or "")
    end

    --- Enable or disable the dropdown.
    function btn:SetDropdownEnabled(value)
        enabled = value and true or false
        Refresh()
    end

    Refresh()
    return btn
end

-- ---------------------------------------------------------------------------
-- Public: CreateActionRow
-- ---------------------------------------------------------------------------

--- Create a labelled panel row (used in lists). Optionally has action buttons
--- on the right side, or left/right-click handlers.
---
--- @param parent          Frame
--- @param anchorFrame     Frame  (row is placed below this)
--- @param titleText       string
--- @param descriptionText string|nil
--- @param options         table|nil
---   options.buttons      = { { text, width?, onClick } }
---   options.onLeftClick  function
---   options.onRightClick function(rootDescription)  (opens a context menu)
---   options.isSelected   bool
---   options.yGap         number (vertical gap below anchor, default 6)
--- @return Frame  (has :SetSelected(bool) method)
function Theme.CreateActionRow(parent, anchorFrame, titleText, descriptionText, options)
    options = options or {}

    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetPoint("TOPLEFT",  anchorFrame, "BOTTOMLEFT", 0, -(options.yGap or 6))
    row:SetPoint("TOPRIGHT", parent,      "TOPRIGHT",   0, 0)
    row:SetHeight(34)
    SetBackdrop(row, C_INSET_BG, C_INSET_EDGE)

    local hasClick = options.onLeftClick or options.onRightClick
    row:EnableMouse(hasClick and true or false)

    -- Title
    local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -8)
    title:SetPoint("RIGHT",   row, "RIGHT",  -84, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetText(titleText or "")
    title:SetTextColor(0.94, 0.95, 0.96, 1)
    RegisterFontStringTooltip(title, row)

    -- Optional sub-description
    local desc
    if descriptionText and descriptionText ~= "" then
        desc = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
        desc:SetPoint("RIGHT",   row,   "RIGHT",     -84, 0)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(false)
        desc:SetText(descriptionText)
        desc:SetTextColor(C_TEXT_SUBTLE[1], C_TEXT_SUBTLE[2], C_TEXT_SUBTLE[3], C_TEXT_SUBTLE[4])
        RegisterFontStringTooltip(desc, row)

        -- Grow row height to accommodate two lines
        local titleH = math.max(title:GetStringHeight() or 0, 12)
        local descH  = math.max(desc:GetStringHeight()  or 0, 0)
        row:SetHeight(math.max(34, math.ceil(8 + titleH + 2 + descH + 8)))
    end

    -- Shared hover/select visuals
    local isSelected = options.isSelected and true or false

    local function ApplyNormal()
        SetBackdrop(row, C_INSET_BG, C_INSET_EDGE)
        title:SetTextColor(0.94, 0.95, 0.96, 1)
        if desc then desc:SetTextColor(C_TEXT_SUBTLE[1], C_TEXT_SUBTLE[2], C_TEXT_SUBTLE[3], C_TEXT_SUBTLE[4]) end
    end

    local function ApplySelected()
        SetBackdrop(row, C_ACTIVE_BG, C_ACTIVE_EDGE)
        title:SetTextColor(C_TEXT_HOVER[1], C_TEXT_HOVER[2], C_TEXT_HOVER[3], C_TEXT_HOVER[4])
        if desc then desc:SetTextColor(0.82, 0.88, 0.92, 1) end
    end

    if hasClick then
        row:SetScript("OnEnter", function()
            if isSelected then ApplySelected() else
                SetBackdrop(row, C_HOVER_BG, C_HOVER_EDGE)
                title:SetTextColor(C_TEXT_HOVER[1], C_TEXT_HOVER[2], C_TEXT_HOVER[3], C_TEXT_HOVER[4])
                if desc then desc:SetTextColor(0.82, 0.88, 0.92, 1) end
            end
        end)
        row:SetScript("OnLeave", function()
            if isSelected then ApplySelected() else ApplyNormal() end
            if GameTooltip then GameTooltip:Hide() end
        end)
        row:SetScript("OnMouseUp", function(self, btn)
            if btn == "LeftButton"  and options.onLeftClick  then options.onLeftClick()  end
            if btn == "RightButton" and options.onRightClick then
                if MenuUtil and MenuUtil.CreateContextMenu then
                    MenuUtil.CreateContextMenu(self, function(_, root) options.onRightClick(root) end)
                end
            end
        end)
    end

    -- Right-side action buttons
    if options.buttons then
        local rightAnchor
        for i = #options.buttons, 1, -1 do
            local bd  = options.buttons[i]
            local btn = Theme.CreateButton(row, bd.width or 72, 22, bd.text or "")
            if bd.onClick then btn:SetScript("OnClick", bd.onClick) end
            if rightAnchor then
                btn:SetPoint("RIGHT", rightAnchor, "LEFT", -4, 0)
            else
                btn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            end
            btn:SetPoint("CENTERX", row, "CENTERY", 0, 0)
            rightAnchor = btn
        end
    end

    --- Programmatically toggle the selected visual state.
    function row:SetSelected(value)
        isSelected = value and true or false
        if isSelected then ApplySelected() else ApplyNormal() end
    end

    if isSelected then ApplySelected() else ApplyNormal() end
    return row
end

-- ---------------------------------------------------------------------------
-- Public: CreateHeader
-- ---------------------------------------------------------------------------

--- Create a themed section-header bar with a left accent stripe.
--- Supports four modes, selected via options flags:
---   plain clickable  – options.onClick
---   expandable       – options.expandable + options.isExpanded + options.onToggle
---   with checkbox    – options.withToggle + options.checked + options.onToggle
---   (plain + right-click context menu) – options.onRightClick
---
--- @param parent      Frame
--- @param anchorFrame Frame  (header is placed below this)
--- @param titleText   string
--- @param options     table|nil
---   options.onClick        function
---   options.onRightClick   function(rootDescription)
---   options.rightText      string     (small label on the right)
---   options.expandable     bool
---   options.isExpanded     bool
---   options.withToggle     bool
---   options.checked        bool
---   options.onToggle       function(newChecked?)
---   options.enabled        bool  (default true)
---   options.yGap           number (gap below anchor, default 10)
---   options.width          number (default fills parent)
---   options.frameName      string (global WoW frame name, optional)
--- @return Button  (has :SetExpanded(bool) and :SetChecked(bool) methods)
function Theme.CreateHeader(parent, anchorFrame, titleText, options)
    options = options or {}
    local enabled    = options.enabled ~= false
    local expandable = options.expandable and true or false
    local withToggle = options.withToggle and true or false

    local header = CreateFrame("Button", options.frameName, parent, "BackdropTemplate")
    header:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -(options.yGap or 10))
    if options.width then
        header:SetWidth(options.width)
    else
        header:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    end
    header:SetHeight(28)
    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    SetBackdrop(header, C_HEADER_BG, C_HEADER_EDGE)

    -- Left accent stripe
    local accent = header:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT",    header, "TOPLEFT",    0, 0)
    accent:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(3)
    accent:SetColorTexture(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], C_ACCENT[4])

    -- Expand arrow (only when expandable)
    local arrow
    local isExpanded = options.isExpanded and true or false
    if expandable then
        arrow = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        arrow:SetPoint("LEFT", header, "LEFT", 8, 0)
        arrow:SetText(isExpanded and "[-]" or "[+]")
        arrow:SetTextColor(C_TEXT_LABEL[1], C_TEXT_LABEL[2], C_TEXT_LABEL[3], C_TEXT_LABEL[4])
    end

    -- Title
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if arrow then
        title:SetPoint("LEFT", arrow, "RIGHT", 4, 0)
    else
        title:SetPoint("LEFT", header, "LEFT", 10, 0)
    end
    title:SetPoint("RIGHT", header, "RIGHT", withToggle and -36 or -10, 0)
    title:SetJustifyH("LEFT")
    title:SetText(titleText or "")
    title:SetTextColor(C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3], C_TEXT_NORMAL[4])
    RegisterFontStringTooltip(title, header)

    -- Optional right-hand label (e.g. count)
    if options.rightText ~= nil then
        local rtxt = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rtxt:SetPoint("RIGHT", header, "RIGHT", withToggle and -36 or -8, 0)
        rtxt:SetText(tostring(options.rightText))
        rtxt:SetTextColor(C_TEXT_LABEL[1], C_TEXT_LABEL[2], C_TEXT_LABEL[3], C_TEXT_LABEL[4])
    end

    -- Optional checkbox (withToggle mode)
    local box
    local isChecked = options.checked and true or false
    if withToggle then
        box = CreateCheckbox(header)
        box:SetPoint("RIGHT", header, "RIGHT", -8, 0)
    end

    -- Shared visual refresh
    local function Refresh(isHover)
        if not enabled then
            SetBackdrop(header, C_DISABLED_BG, C_DISABLED_EDGE)
            title:SetTextColor(C_TEXT_DISABLED[1], C_TEXT_DISABLED[2], C_TEXT_DISABLED[3], C_TEXT_DISABLED[4])
            if arrow then arrow:SetTextColor(C_TEXT_DISABLED[1], C_TEXT_DISABLED[2], C_TEXT_DISABLED[3], C_TEXT_DISABLED[4]) end
        elseif isHover then
            SetBackdrop(header, C_HEADER_HOVER_BG, C_HEADER_HOVER_EDGE)
            title:SetTextColor(C_TEXT_HOVER[1], C_TEXT_HOVER[2], C_TEXT_HOVER[3], C_TEXT_HOVER[4])
            if arrow then arrow:SetTextColor(C_TEXT_HOVER[1], C_TEXT_HOVER[2], C_TEXT_HOVER[3], C_TEXT_HOVER[4]) end
        else
            SetBackdrop(header, C_HEADER_BG, C_HEADER_EDGE)
            title:SetTextColor(C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3], C_TEXT_NORMAL[4])
            if arrow then arrow:SetTextColor(C_TEXT_LABEL[1], C_TEXT_LABEL[2], C_TEXT_LABEL[3], C_TEXT_LABEL[4]) end
        end
        if box then box:Refresh(isChecked, enabled) end
    end

    header:SetScript("OnEnter", function() Refresh(true)  end)
    header:SetScript("OnLeave", function() Refresh(false) end)

    header:SetScript("OnClick", function(self, mouseButton)
        if not enabled then return end

        if mouseButton == "RightButton" and options.onRightClick then
            if MenuUtil and MenuUtil.CreateContextMenu then
                MenuUtil.CreateContextMenu(self, function(_, root)
                    options.onRightClick(root)
                end)
            end
            return
        end

        if withToggle and options.onToggle then
            isChecked = not isChecked
            Refresh(false)
            options.onToggle(isChecked)
            return
        end

        if expandable and options.onToggle then
            isExpanded = not isExpanded
            if arrow then arrow:SetText(isExpanded and "[-]" or "[+]") end
            options.onToggle(isExpanded)
            return
        end

        if options.onClick then
            options.onClick()
        end
    end)

    --- Programmatically set the expand state (expandable headers only).
    function header:SetExpanded(value)
        isExpanded = value and true or false
        if arrow then arrow:SetText(isExpanded and "[-]" or "[+]") end
    end

    --- Programmatically set the checked state (withToggle headers only).
    function header:SetChecked(value)
        isChecked = value and true or false
        box:Refresh(isChecked, enabled)
    end

    Refresh(false)
    return header
end
