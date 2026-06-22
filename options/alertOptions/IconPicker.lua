local _, ns = ...

---@diagnostic disable: undefined-global

-------------------------------------------------------------------------------
-- AlertOptions Icon Search
--
-- A small spell-ID lookup popup exposed as ns.AlertIconPicker.
--
-- The user types a numeric spell ID; the addon looks up the icon via
-- C_Spell.GetSpellTexture() and the name via C_Spell.GetSpellName().
-- If a valid icon is found it is shown as a preview and saved on OK.
-- If the spell ID is invalid the previous icon is kept unchanged.
--
-- Opening while in combat is blocked with a chat message.
--
-- PUBLIC API
--   ns.AlertIconPicker:Open(initialIconRef, onPick, anchorFrame)
--     initialIconRef  number|nil   currently saved texture FileID, or nil
--     onPick          function(textureID: number)  called only when valid
--     anchorFrame     Frame|nil    position hint
--
--   ns.AlertIconPicker:Close()
-------------------------------------------------------------------------------

local AlertIconPicker = {}
ns.AlertIconPicker = AlertIconPicker

-- ---------------------------------------------------------------------------
-- Palette (matches Theme.lua)
-- ---------------------------------------------------------------------------

local C_BG          = { 0.06, 0.07, 0.09, 0.97 }
local C_EDGE        = { 0.18, 0.22, 0.26, 0.95 }
local C_HEADER_BG   = { 0.03, 0.16, 0.13, 0.92 }
local C_HEADER_EDGE = { 0.18, 0.45, 0.38, 0.95 }
local C_ACCENT      = { 0.30, 0.86, 0.70, 1    }
local C_HOVER_EDGE  = { 0.26, 0.62, 0.53, 1    }
local C_RESET_EDGE  = { 0.75, 0.28, 0.28, 1    }
local C_WARN_TEXT   = { 1.00, 0.72, 0.20, 1    }
local C_TEXT_LABEL  = { 0.52, 0.86, 0.75, 1    }
local C_TEXT_NORMAL = { 0.88, 0.98, 0.93, 1    }
local C_TEXT_SUBTLE = { 0.64, 0.69, 0.74, 1    }

local function BD(frame, bg, edge)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    frame:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4])
end

-- ---------------------------------------------------------------------------
-- Layout constants
-- ---------------------------------------------------------------------------

local POPUP_W      = 290
local HEADER_H     = 28
local PREVIEW_SIZE = 40
local BTN_H        = 24
local BTN_W        = 72
local PAD          = 8

-- Total height: header + pad + input(20) + pad + combatWarn(14) + pad + preview(40) + pad + btn(24) + pad
local COMBAT_WARN_H = 14
local POPUP_H = HEADER_H + PAD + 20 + PAD + COMBAT_WARN_H + PAD + PREVIEW_SIZE + PAD + BTN_H + PAD

-- ---------------------------------------------------------------------------
-- Build the popup frame (called once, lazily)
-- ---------------------------------------------------------------------------

local function BuildFrame()
    local f = CreateFrame("Frame", "CDMAurasIconSearchFrame", UIParent, "BackdropTemplate")
    f:SetSize(POPUP_W, POPUP_H)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetToplevel(true)
    BD(f, C_BG, C_EDGE)

    -- -------------------------------------------------------------------------
    -- Header (draggable)
    -- -------------------------------------------------------------------------
    local header = CreateFrame("Frame", nil, f, "BackdropTemplate")
    header:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, 0)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    header:SetHeight(HEADER_H)
    BD(header, C_HEADER_BG, C_HEADER_EDGE)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)

    local accent = header:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT",    header, "TOPLEFT",    0, 0)
    accent:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(3)
    accent:SetColorTexture(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], C_ACCENT[4])

    local titleText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT",  header, "LEFT",  10, 0)
    titleText:SetPoint("RIGHT", header, "RIGHT", -28, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetText("Set Icon")
    titleText:SetTextColor(C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3], 1)

    local closeBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    BD(closeBtn, C_BG, C_EDGE)
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    local closeLabel = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    closeLabel:SetPoint("CENTER")
    closeLabel:SetText("x")
    closeLabel:SetTextColor(C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3], 1)
    closeBtn:HookScript("OnEnter", function(self) BD(self, C_BG, C_HOVER_EDGE) end)
    closeBtn:HookScript("OnLeave", function(self) BD(self, C_BG, C_EDGE) end)

    -- -------------------------------------------------------------------------
    -- Spell ID input row
    -- -------------------------------------------------------------------------
    local inputY = -(HEADER_H + PAD)

    local inputLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    inputLabel:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, inputY)
    inputLabel:SetText("Spell ID:")
    inputLabel:SetTextColor(C_TEXT_LABEL[1], C_TEXT_LABEL[2], C_TEXT_LABEL[3], 1)

    local inputBox = CreateFrame("EditBox", nil, f, "BackdropTemplate")
    inputBox:SetPoint("LEFT",  inputLabel, "RIGHT",   PAD, 0)
    inputBox:SetPoint("RIGHT", f,          "RIGHT",  -PAD, 0)
    inputBox:SetPoint("TOP",   inputLabel, "TOP",    0,    0)
    inputBox:SetHeight(20)
    inputBox:SetFontObject("GameFontNormal")
    inputBox:SetTextColor(C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3], 1)
    inputBox:SetAutoFocus(false)
    BD(inputBox, { 0.04, 0.05, 0.07, 1 }, C_EDGE)
    inputBox:SetTextInsets(4, 4, 2, 2)

    -- -------------------------------------------------------------------------
    -- Preview row: icon texture + spell name
    -- -------------------------------------------------------------------------
    local previewY = -(HEADER_H + PAD + 20 + PAD)

    -- -------------------------------------------------------------------------
    -- Combat warning banner (shown only when in combat)
    -- -------------------------------------------------------------------------
    local combatWarnY = -(HEADER_H + PAD + 20 + PAD + PREVIEW_SIZE + PAD)

    local combatWarnLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    combatWarnLabel:SetPoint("TOPLEFT",  f, "TOPLEFT",  PAD, combatWarnY)
    combatWarnLabel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, combatWarnY)
    combatWarnLabel:SetJustifyH("LEFT")
    combatWarnLabel:SetText("|cffFFB833Warning:|r Some spells may not return anything while in combat.")
    combatWarnLabel:SetTextColor(C_WARN_TEXT[1], C_WARN_TEXT[2], C_WARN_TEXT[3], 1)
    combatWarnLabel:Hide()
    f._combatWarnLabel = combatWarnLabel

    local previewIcon = f:CreateTexture(nil, "ARTWORK")
    previewIcon:SetSize(PREVIEW_SIZE, PREVIEW_SIZE)
    previewIcon:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, previewY)
    previewIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f._previewIcon = previewIcon

    local spellNameLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    spellNameLabel:SetPoint("LEFT",   previewIcon, "RIGHT",    PAD, 0)
    spellNameLabel:SetPoint("RIGHT",  f,           "RIGHT",   -PAD, 0)
    spellNameLabel:SetPoint("TOP",    previewIcon, "TOP",      0,   0)
    spellNameLabel:SetPoint("BOTTOM", previewIcon, "BOTTOM",   0,   0)
    spellNameLabel:SetJustifyH("LEFT")
    spellNameLabel:SetJustifyV("MIDDLE")
    spellNameLabel:SetWordWrap(false)
    spellNameLabel:SetTextColor(C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3], 1)
    f._spellNameLabel = spellNameLabel

    -- -------------------------------------------------------------------------
    -- Footer buttons: OK / Cancel
    -- -------------------------------------------------------------------------
    local function MakeBtn(labelText, onClick)
        local btn = CreateFrame("Button", nil, f, "BackdropTemplate")
        btn:SetSize(BTN_W, BTN_H)
        BD(btn, C_BG, C_EDGE)
        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("CENTER")
        lbl:SetText(labelText)
        lbl:SetTextColor(C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3], 1)
        btn:SetScript("OnClick", onClick)
        btn:HookScript("OnEnter", function(self)
            -- Always show hover edge; for OK button, the _ready highlight is
            -- already C_HOVER_EDGE so this is a no-op visually.
            BD(self, C_BG, C_HOVER_EDGE)
        end)
        btn:HookScript("OnLeave", function(self)
            if self._ready then
                BD(self, C_BG, C_HOVER_EDGE)  -- keep the "ready" teal highlight
            else
                BD(self, C_BG, C_EDGE)
            end
        end)
        return btn
    end

    local cancelBtn = MakeBtn("Cancel", function() f:Hide() end)
    cancelBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD)

    local resetBtn = MakeBtn("Reset Icon", function()
        local cb = f._onReset
        f:Hide()
        if cb then cb() end
    end)
    resetBtn:SetWidth(BTN_W + 18)   -- a bit wider to fit the label
    resetBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, PAD)
    resetBtn:HookScript("OnEnter", function(self) BD(self, C_BG, C_RESET_EDGE) end)
    resetBtn:HookScript("OnLeave", function(self) BD(self, C_BG, C_EDGE) end)
    f._resetBtn = resetBtn

    local okBtn = MakeBtn("OK", function()
        local textureID = f._pendingTextureID
        local spellID   = f._pendingSpellID
        local cb        = f._onPick
        f:Hide()
        -- Only fire onPick when a valid spell was found.  If nothing valid was
        -- entered the caller retains whatever was previously saved.
        if textureID and cb then
            cb(textureID, spellID)
        end
    end)
    okBtn:SetPoint("RIGHT", cancelBtn, "LEFT", -6, 0)
    f._okBtn = okBtn

    -- -------------------------------------------------------------------------
    -- Spell lookup
    -- -------------------------------------------------------------------------

    local function SetReady(isReady)
        f._okBtn._ready = isReady
        if isReady then
            BD(f._okBtn, C_BG, C_HOVER_EDGE)
        else
            BD(f._okBtn, C_BG, C_EDGE)
        end
    end

    local function Lookup(text)
        text = text and text:gsub("^%s+", ""):gsub("%s+$", "") or ""

        if text == "" then
            f._pendingTextureID = nil
            f._previewIcon:SetTexture(nil)
            f._spellNameLabel:SetText("")
            SetReady(false)
            return
        end

        -- Accept either a numeric spell ID or a spell name string.
        -- Name lookup relies on C_Spell.GetSpellID, which only returns a result
        -- for spells the current character knows (learned, on spellbook, etc.).
        local spellID = tonumber(text)
        local nameWasUsed = false
        if not spellID then
            local spellInfo = C_Spell.GetSpellInfo(text)
            spellID = spellInfo and spellInfo.spellID
            nameWasUsed = true
        end

        if not spellID then
            f._pendingTextureID = nil
            f._previewIcon:SetTexture(nil)
            f._spellNameLabel:SetText(
                "|cffff6666Spell not found.|r\n" ..
                "|cff" ..
                string.format("%02x%02x%02x",
                    math.floor(C_TEXT_SUBTLE[1] * 255),
                    math.floor(C_TEXT_SUBTLE[2] * 255),
                    math.floor(C_TEXT_SUBTLE[3] * 255)) ..
                "Name search only works for spells\n" ..
                "your character knows. Try a spell ID.|r")
            SetReady(false)
            return
        end

        local textureID = C_Spell.GetSpellTexture(spellID)
        local name      = C_Spell.GetSpellName(spellID)

        if textureID and textureID > 0 then
            f._pendingTextureID = textureID
            f._pendingSpellID   = spellID
            f._previewIcon:SetTexture(textureID)
            f._spellNameLabel:SetText(
                (name or ("Spell " .. spellID)) ..
                (nameWasUsed and ("|cff" ..
                    string.format("%02x%02x%02x",
                        math.floor(C_TEXT_SUBTLE[1] * 255),
                        math.floor(C_TEXT_SUBTLE[2] * 255),
                        math.floor(C_TEXT_SUBTLE[3] * 255)) ..
                    "  (ID: " .. spellID .. ")|r") or ""))
            SetReady(true)
        else
            f._pendingTextureID = nil
            f._pendingSpellID   = nil
            f._previewIcon:SetTexture(nil)
            f._spellNameLabel:SetText("|cffff6666Spell not found|r")
            SetReady(false)
        end
    end

    -- Debounced lookup on text change; immediate on Enter.
    local lookupPending = false
    inputBox:SetScript("OnTextChanged", function(self)
        if not lookupPending then
            lookupPending = true
            C_Timer.After(0.4, function()
                lookupPending = false
                Lookup(inputBox:GetText())
            end)
        end
    end)
    inputBox:SetScript("OnEnterPressed", function(self)
        lookupPending = false
        Lookup(self:GetText())
        self:ClearFocus()
    end)
    inputBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        f:Hide()
    end)

    f._inputBox = inputBox
    f._Lookup   = Lookup

    -- -------------------------------------------------------------------------
    -- Combat event wiring
    -- -------------------------------------------------------------------------
    f:SetScript("OnEvent", function(self, event, payload)
        if event == "PLAYER_IN_COMBAT_CHANGED" and self._combatWarnLabel then
            self._combatWarnLabel:SetShown(payload)
        end
    end)

    f:SetScript("OnShow", function(self)
        self:RegisterEvent("PLAYER_IN_COMBAT_CHANGED")
    end)

    f:SetScript("OnHide", function(self)
        self:UnregisterAllEvents()
    end)
    f:Hide()

    return f
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

local searchFrame = nil

--- Open the icon search popup.
--- @param initialIconRef  number|nil   currently saved texture FileID
--- @param onPick          function(textureID: number, spellID: number|nil)
--- @param anchorFrame     Frame|nil
--- @param initialSpellID  number|nil   spell ID to prefill in the search box
--- @param onReset         function|nil  called when the player clicks Reset Icon
function AlertIconPicker:Open(initialIconRef, onPick, anchorFrame, initialSpellID, onReset)
    if not searchFrame then
        searchFrame = BuildFrame()
    end

    -- Show a non-blocking warning when the player opens in combat.
    if searchFrame._combatWarnLabel then
        if InCombatLockdown() then
            searchFrame._combatWarnLabel:Show()
        else
            searchFrame._combatWarnLabel:Hide()
        end
    end

    searchFrame._onPick          = onPick
    searchFrame._onReset         = onReset
    searchFrame._pendingTextureID = nil
    searchFrame._pendingSpellID   = nil

    -- Show the Reset button only when there is actually a saved custom icon.
    if searchFrame._resetBtn then
        if initialIconRef or initialSpellID then
            searchFrame._resetBtn:Show()
        else
            searchFrame._resetBtn:Hide()
        end
    end

    -- If a saved spell ID is provided, prefill the input and run the lookup
    -- immediately so the preview shows the current selection.
    if initialSpellID then
        searchFrame._inputBox:SetText(tostring(initialSpellID))
        searchFrame._Lookup(tostring(initialSpellID))
    else
        -- No saved spell ID: clear the input but still show the current icon
        -- as a read-only preview hint.
        searchFrame._inputBox:SetText("")
        searchFrame._Lookup("")
        if initialIconRef then
            searchFrame._previewIcon:SetTexture(initialIconRef)
            searchFrame._spellNameLabel:SetText(
                "|cff" ..
                string.format("%02x%02x%02x",
                    math.floor(C_TEXT_SUBTLE[1] * 255),
                    math.floor(C_TEXT_SUBTLE[2] * 255),
                    math.floor(C_TEXT_SUBTLE[3] * 255)) ..
                "Current icon -- enter a spell ID to change|r")
        end
    end

    -- Position the popup near the anchor widget if one was provided.
    searchFrame:ClearAllPoints()
    if anchorFrame and anchorFrame.GetObjectType then
        searchFrame:SetPoint("TOPLEFT", anchorFrame, "BOTTOMRIGHT", 0, -4)
    else
        searchFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    searchFrame:Show()
    searchFrame:Raise()
    searchFrame._inputBox:SetFocus()
end

function AlertIconPicker:Close()
    if searchFrame then
        searchFrame:Hide()
    end
end
