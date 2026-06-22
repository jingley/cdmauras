-------------------------------------------------------------------------------
--  Border Alert
--  A colored border drawn on top of a CDM action button placeholder.
--  When stacks conditions are present the border frame is still created (so
--  Stacks conditions can parent their StatusBar overlays to it), but the
--  border's own texture, mask, and vertex colour are skipped — the status
--  bars owned by each Stacks condition are the sole visual in that case.
-------------------------------------------------------------------------------
local _, ns = ...
local Border = {}
ns.Border = Border

local framePool = ns.Utils.GetFramePool(Border, "_framePool")

function Border:NotifyConditionsActiveChanged()
    local border = self.border
    if not border then return end
    if self.isConditionsActive then
        border:Show()
    else
        border:Hide()
    end
end

function Border:SetupBorderTexture(parent, statusBar)
    local texture = parent.texture
    if not texture and not statusBar then
        texture = parent:CreateTexture()
        parent.texture = texture
    end
    if statusBar then
        parent:SetStatusBarTexture(self.textureFile)
        parent.texture = parent:GetStatusBarTexture()
        texture = parent.texture
    else
        texture:SetTexture(self.textureFile)
    end
    texture:SetAllPoints(parent)
    texture:Show()

    if self.applyMask then
        ns.Utils.ApplyDefaultMaskTexture(parent, parent.texture)
    else
        ns.Utils.AddCDMMaskTexture(parent, parent.texture, self.sourceIcon)
    end
    local r, g, b, a = self.borderColor[1], self.borderColor[2], self.borderColor[3], self.borderColor[4] or 1
    parent.texture:SetVertexColor(r, g, b, a)
end

function Border:SetupBorderFrame()
    local border = framePool:Acquire()
    local texture = border.texture
    if not texture then
        texture = border:CreateTexture()
        border.texture = texture
    end
    self:SetupBorderTexture(border)
    border:SetAllPoints(self.placeholder)
    border:SetParent(self.placeholder)
    border:SetAlpha(1)
    border:SetSize(self.placeholder:GetSize())
    border:SetFrameStrata(border:GetParent():GetFrameStrata())
    border:SetFrameLevel(border:GetParent():GetFrameLevel() + self.frameLevel)
    self.border = border
end

local ClearTexture = function(texture)
    if texture then
        texture:Hide()
        texture:ClearAllPoints()
        if texture.SetVertexColor then
            texture:SetVertexColor(1, 1, 1, 1)
        end
    end
end

function Border:Initialize(option, source)
    self.placeholder = ns.AlertManager.GetPlaceholderFrame(source.cooldownID, source)
    self.cooldownID = source.cooldownID
    self.key = option.borderKey
    self.type = "border"
    self.borderColor = option.color
    self.applyMask = option.applyMask
    self.sourceIcon = source.Icon
    self.anyCondition = option.anyCondition
    self.frameLevel = option.frameLevel
    local textureFile = option.borderTexturePath
        or ("Interface\\AddOns\\CDMAuras\\media\\alerts\\Border"
            .. tostring(tonumber(option.borderSize) or 1)
            .. ((option.borderShape == "Round") and "Round" or "Square")
            .. ((option.borderBlur == true) and "Blur" or "")
            .. ".tga")
    self.textureFile = textureFile
    self:SetupBorderFrame()
    self:InitializeConditional(option)
    if self.unlockedConditionCount == 0 or (not self.anyCondition and self.secretConditionCount > 0) then
        ClearTexture(self.border.texture)
    end
end

function Border:Destroy()
    ns.Engine.API.UnregisterAllInternalMessages(self)
    if self.border then
        framePool:Release(self.border)
    end
    self:DestroyConditional()
    self.border = nil
    self.cooldownID = nil
    self.frameLevel = nil
    self.key = nil
    self.stacks = nil
    self.borderColor = nil
    self.applyMask = nil
    self.sourceIcon = nil
    self.textureFile = nil
    self.placeholder = nil
    self.initialized = nil
end